#!/bin/bash

# ==========================================
# 驗證 K8s 基礎設施 (相容 macOS Bash 3.2)
# ==========================================
echo "🔍 開始驗證基礎設施狀態..."

# 定義要檢查的關鍵字清單 "關鍵字:Namespace"
SERVICES=(
    "postgresql:infra"
    "redis:infra"
    "zookeeper:infra"
    "kafka:infra"
    "flink-jobmanager:infra"
    "flink-taskmanager:infra"
    "argocd-server:argocd"
    "loki:observability"
    "grafana:observability"
)

# ==========================================
# 1. 檢查 Pods 狀態 (Ready Check)
# ==========================================
echo "1. 檢查 Pods 是否已準備就緒 (Ready)..."

check_ready() {
    local keyword=$1
    local ns=$2
    printf "   - 檢查 %-15s 在 %-13s namespace: " "$keyword" "$ns"
    
    # 使用模糊匹配尋找 Pod 名稱包含關鍵字且狀態為 Running/Ready 的 Pod
    # 這樣可以避開 cdk8s 生成的隨機 Hash 名稱問題
    POD_STATUS=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "$keyword" | grep -v "test" | awk '{print $3}' | head -n 1)
    
    if [ "$POD_STATUS" == "Running" ]; then
        # 進一步檢查 Ready 欄位 (例如 1/1 或 2/2)
        READY_STATUS=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "$keyword" | grep -v "test" | awk '{print $2}' | head -n 1)
        # 只要第一個數字等於第二個數字 (1/1, 2/2) 就代表 Ready
        CURRENT=$(echo $READY_STATUS | cut -d/ -f1)
        TOTAL=$(echo $READY_STATUS | cut -d/ -f2)
        if [ "$CURRENT" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
            echo "✅ PASS"
        else
            echo "⏳ 仍在初始化 ($READY_STATUS)"
        fi
    else
        echo "⏳ 仍在等待中 (狀態: ${POD_STATUS:-找不到 Pod})"
    fi
}

for item in "${SERVICES[@]}"; do
    service="${item%%:*}"
    ns="${item##*:}"
    check_ready "$service" "$ns"
done

# ==========================================
# 2. 功能性檢查 (Deep Check)
# ==========================================
echo ""
echo "2. 執行深度功能檢查..."

# 獲取動態密碼
PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" 2>/dev/null | base64 --decode)
REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 --decode)

# 檢查 Redis RediSearch 模組
printf "   - 驗證 Redis RediSearch 模組: "
REDIS_POD=$(kubectl get pods -n infra --no-headers | grep "redis" | grep "Running" | awk '{print $1}' | head -n 1)
if [ ! -z "$REDIS_POD" ]; then
    MODULES=$(kubectl exec -n infra "$REDIS_POD" -c redis -- redis-cli -a "$REDIS_PASS" MODULE LIST 2>/dev/null)
    if echo "$MODULES" | grep -qiE "search|ft"; then
        echo "✅ PASS (RediSearch 已載入)"
    else
        echo "❌ FAIL (未偵測到 RediSearch 模組)"
    fi
else
    echo "❌ FAIL (找不到 Redis Pod)"
fi

# 檢查 PostgreSQL
printf "   - 驗證 PostgreSQL 連線:       "
POSTGRES_POD=$(kubectl get pods -n infra --no-headers | grep "postgres" | grep "Running" | awk '{print $1}' | head -n 1)
if [ ! -z "$POSTGRES_POD" ]; then
    if kubectl exec -n infra "$POSTGRES_POD" -c postgresql -- env PGPASSWORD="$PG_PASS" pg_isready -U admin &> /dev/null; then
        echo "✅ PASS (資料庫已就緒)"
    else
        echo "❌ FAIL (資料庫無回應)"
    fi
else
    echo "❌ FAIL (找不到 PostgreSQL Pod)"
fi

# 檢查 Kafka Broker
printf "   - 驗證 Kafka Broker 運作:     "
KAFKA_POD=$(kubectl get pods -n infra --no-headers | grep "kafka" | grep "Running" | awk '{print $1}' | head -n 1)
if [ ! -z "$KAFKA_POD" ]; then
    if kubectl exec -n infra "$KAFKA_POD" -c kafka -- /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka-service:9092 &> /dev/null; then
        echo "✅ PASS (Broker 連線正常)"
    else
        echo "❌ FAIL (Broker 拒絕連線或未啟動)"
    fi
else
    echo "❌ FAIL (找不到 Kafka Pod)"
fi

# ==========================================
# 3. 服務存取資訊 (Ingress)
# ==========================================
echo ""
echo "3. Ingress 網路存取測試:"
TARGET_IP="127.0.0.1"

printf "   - 測試 argocd.local:          "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "argocd.local:80:$TARGET_IP" http://argocd.local)
if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "307" ] || [ "$HTTP_STATUS" == "302" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

printf "   - 測試 grafana.local:         "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "grafana.local:80:$TARGET_IP" http://grafana.local)
if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "302" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

printf "   - 測試 flink.local:           "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "flink.local:80:$TARGET_IP" http://flink.local)
if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

echo "-------------------------------------------------------"
echo "💡 提示: 若 Ingress 測試 FAIL，請確保已執行 minikube tunnel"
