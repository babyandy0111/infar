#!/bin/bash

# ==========================================
# Infar 基礎設施多環境驗證腳本
# ==========================================
INFAR_CLOUD_PROVIDER=${1:-local}

echo "🔍 開始驗證 [$INFAR_CLOUD_PROVIDER] 基礎設施狀態..."

# 定義基礎服務清單 (無論哪種環境都要檢查 Pod 的服務)
CORE_PODS=(
    "flink-jobmanager:infra"
    "flink-taskmanager:infra"
    "argocd.*-server:argocd"
    "loki:observability"
    "grafana:observability"
)

# 定義在 Local 環境才需要檢查 Pod 的服務 (雲端則改為檢查連線)
DB_PODS=(
    "postgres:infra"
    "redis:infra"
    "zookeeper:infra"
    "kafka:infra"
)

# ==========================================
# 1. 檢查 Pods 狀態 (Ready Check)
# ==========================================
echo "1. 檢查核心元件是否已準備就緒 (Ready)..."

check_ready() {
    local keyword=$1
    local ns=$2
    local display_name=$(echo "$keyword" | sed 's/\.\*//g' | sed 's/\\//g')
    printf "   - 檢查 %-15s 在 %-13s namespace: " "$display_name" "$ns"
    
    POD_LINE=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "$keyword" | grep -v "test" | grep -v "dex" | grep -v "repo" | head -n 1)
    POD_STATUS=$(echo "$POD_LINE" | awk '{print $3}')
    
    if [ "$POD_STATUS" == "Running" ]; then
        READY_STATUS=$(echo "$POD_LINE" | awk '{print $2}')
        CURRENT=$(echo $READY_STATUS | cut -d/ -f1)
        TOTAL=$(echo $READY_STATUS | cut -d/ -f2)
        if [ "$CURRENT" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then echo "✅ PASS"; else echo "⏳ 仍在初始化 ($READY_STATUS)"; fi
    else
        echo "⏳ 仍在等待中 (狀態: ${POD_STATUS:-找不到 Pod})"
    fi
}

# 執行核心檢查
for item in "${CORE_PODS[@]}"; do
    check_ready "${item%%:*}" "${item##*:}"
done

# 如果是 local，還要檢查資料庫 Pod
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    for item in "${DB_PODS[@]}"; do
        check_ready "${item%%:*}" "${item##*:}"
    done
else
    echo "   (雲端模式：資料庫由外部託管，跳過 Pod 狀態檢查)"
fi

# ==========================================
# 2. 功能性檢查 (連線測試)
# ==========================================
echo ""
echo "2. 執行深度功能連線檢查..."

# 獲取密碼
PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" 2>/dev/null | base64 --decode)
REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 --decode)

# 驗證 PostgreSQL
printf "   - 驗證 PostgreSQL 連線:       "
if kubectl run verify-pg-tmp --rm -i --restart=Never --image bitnami/postgresql:16 --env PGPASSWORD="$PG_PASS" -- sh -c "pg_isready -h postgres -p 5432 -U admin" > /dev/null 2>&1; then
    echo "✅ PASS (對接正常)"
else
    echo "❌ FAIL (無法建立連線)"
fi

# 驗證 Redis
printf "   - 驗證 Redis 連線:            "
# 使用 redis-cli PING 測試。注意：雲端託管 Redis 可能沒有密碼或密碼不同，這裡先用 local 邏輯嘗試
if kubectl run verify-redis-tmp --rm -i --restart=Never --image redis:7.2-alpine -- sh -c "redis-cli -h redis-master -p 6379 -a $REDIS_PASS PING" 2>/dev/null | grep -q "PONG"; then
    echo "✅ PASS (對接正常)"
else
    echo "❌ FAIL (無法建立連線)"
fi

# ==========================================
# 3. Ingress 網路存取測試
# ==========================================
echo ""
echo "3. 網路入口存取測試 (Ingress):"

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    TARGET_IP="127.0.0.1"
    echo "   (測試模式：使用本地 /etc/hosts 解析)"
else
    # 雲端模式：動態獲取 LoadBalancer 地址
    echo "   🔍 正在抓取雲端 LoadBalancer 地址..."
    LB_ADDRESS=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$LB_ADDRESS" ]; then
        LB_ADDRESS=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    TARGET_IP=$LB_ADDRESS
fi

test_ingress() {
    local domain=$1
    local name=$2
    printf "   - 測試 %-15s: " "$name"
    if [ -z "$TARGET_IP" ]; then
        echo "❌ FAIL (未偵測到 LoadBalancer)"
        return
    fi
    HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "$domain:80:$TARGET_IP" "http://$domain")
    if [[ "$HTTP_STATUS" =~ ^(200|302|307)$ ]]; then echo "✅ PASS ($HTTP_STATUS)"; else echo "❌ FAIL ($HTTP_STATUS)"; fi
}

test_ingress "argocd.local" "ArgoCD"
test_ingress "grafana.local" "Grafana"
test_ingress "flink.local" "Flink UI"

echo "-------------------------------------------------------"
echo "✅ [$INFAR_CLOUD_PROVIDER] 環境驗證程序執行完畢！"
