#!/bin/bash

# ==========================================
# 驗證 K8s 基礎設施 (相容 macOS Bash 3.2)
# ==========================================
echo "🔍 開始驗證基礎設施狀態..."

# 定義要檢查的關鍵字清單 "關鍵字:Namespace"
SERVICES=(
    "postgres:infra"
    "redis:infra"
    "zookeeper:infra"
    "kafka:infra"
    "flink-jobmanager:infra"
    "flink-taskmanager:infra"
    "argocd.*-server:argocd"
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
    # 格式化輸出名稱 (去掉正則表達式符號)
    local display_name=$(echo "$keyword" | sed 's/\.\*//g' | sed 's/\\//g')
    printf "   - 檢查 %-15s 在 %-13s namespace: " "$display_name" "$ns"
    
    # 使用 grep -E 模糊匹配，並排除不需要的 Pod
    POD_LINE=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -E "$keyword" | grep -v "test" | grep -v "dex" | grep -v "repo" | head -n 1)
    
    POD_STATUS=$(echo "$POD_LINE" | awk '{print $3}')
    
    if [ "$POD_STATUS" == "Running" ]; then
        READY_STATUS=$(echo "$POD_LINE" | awk '{print $2}')
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

PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" 2>/dev/null | base64 --decode)
REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 --decode)

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
