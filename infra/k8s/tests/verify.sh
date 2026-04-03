#!/bin/bash

# ==========================================
# Infar 基礎設施多環境驗證腳本 (動態獲取版)
# ==========================================
INFAR_CLOUD_PROVIDER=${1:-local}

echo "🔍 開始驗證 [$INFAR_CLOUD_PROVIDER] 基礎設施狀態..."

# 定義核心服務 Pod 檢查
CORE_PODS=(
    "argocd.*-server:argocd"
    "postgres:infra"
    "redis:infra"
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

for item in "${CORE_PODS[@]}"; do check_ready "${item%%:*}" "${item##*:}"; done

# ==========================================
# 2. 🔑 動態獲取連線資訊 (拒絕硬編碼)
# ==========================================
echo ""
echo "2. 正在從叢集動態檢索連線資訊..."

# 獲取密碼 (Secret)
PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" 2>/dev/null | base64 --decode)
REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 --decode)

# 獲取 PostgreSQL 資料庫名稱與帳號 (從 StatefulSet 環境變數抓取)
# 使用 JSONPATH 尋找名為 POSTGRES_DATABASE 和 POSTGRES_USER 的 env 值
PG_DB_NAME=$(kubectl get statefulset postgres -n infra -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="POSTGRES_DATABASE")].value}' 2>/dev/null)
PG_USER=$(kubectl get statefulset postgres -n infra -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="POSTGRES_USER")].value}' 2>/dev/null)

# 如果抓不到 (例如是 ExternalName 模式)，則顯示為 N/A
PG_DB_NAME=${PG_DB_NAME:-"infar_db (fallback)"}
PG_USER=${PG_USER:-"admin (fallback)"}

# ==========================================
# 3. 功能性檢查 (連線測試)
# ==========================================
echo "3. 執行深度功能連線檢查..."

# 測試 PostgreSQL (不分環境，皆透過 127.0.0.1 測試)
printf "   - 驗證 PostgreSQL 連線:       "
if command -v pg_isready &> /dev/null; then
    if pg_isready -h 127.0.0.1 -p 5432 -U "$PG_USER" > /dev/null 2>&1; then
        echo "✅ PASS"
    else
        echo "❌ FAIL (無法建立連線，請確認 setup.sh 通道已開啟)"
    fi
else
    echo "⚠️ SKIP (本機未安裝 pg_isready 工具)"
fi

# 測試 Redis (不分環境，皆透過 127.0.0.1 測試)
printf "   - 驗證 Redis 連線:            "
if command -v redis-cli &> /dev/null; then
    if redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASS" PING 2>/dev/null | grep -q "PONG"; then
        echo "✅ PASS"
    else
        echo "❌ FAIL (無法建立連線，請確認 setup.sh 通道已開啟)"
    fi
else
    echo "⚠️ SKIP (本機未安裝 redis-cli 工具)"
fi

# ==========================================
# 4. Ingress 網路存取測試
# ==========================================
echo ""
echo "4. 網路入口存取測試 (Ingress):"

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    TARGET_IP="127.0.0.1"
else
    # 雲端模式：改從 Service 的 LoadBalancer 中擷取 IP
    LB_ADDRESS=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$LB_ADDRESS" ]; then LB_ADDRESS=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); fi
    TARGET_IP=$LB_ADDRESS
fi

test_ingress() {
    local domain=$1
    local name=$2
    printf "   - 測試 %-15s: " "$name"
    if [ -z "$TARGET_IP" ]; then echo "⏳ 等待 IP..."; return; fi
    HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "$domain:80:$TARGET_IP" "http://$domain")
    if [[ "$HTTP_STATUS" =~ ^(200|302|307)$ ]]; then echo "✅ PASS ($HTTP_STATUS)"; else echo "❌ FAIL ($HTTP_STATUS)"; fi
}

test_ingress "argocd.local" "ArgoCD"
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    test_ingress "grafana.local" "Grafana"
fi

# ==========================================
# 5. 🔑 開發者連線指南
# ==========================================
echo ""
echo "-------------------------------------------------------"
echo "🔐 [Infar] 開發者工具連線清單 (資訊由叢集即時提供):"
echo ""
echo "📍 資料庫通道 (透過 127.0.0.1 直達，通道已由 setup.sh 自動開啟):"
echo "   - PostgreSQL: 127.0.0.1:5432 (User: $PG_USER, DB: $PG_DB_NAME, Pass: $PG_PASS)"
echo "   - Redis:      127.0.0.1:6379 (Pass: $REDIS_PASS)"
echo ""
echo "💡 若要手動關閉背景通道，請執行："
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "   pkill -f \"port-forward svc/postgres\" && pkill -f \"port-forward svc/redis-master\""
else
    echo "   pkill -f \"port-forward deployment/jump\""
fi
echo "-------------------------------------------------------"
echo "✅ [$INFAR_CLOUD_PROVIDER] 環境驗證程序執行完畢！"
