#!/bin/bash

# ==========================================
# 驗證 K8s 基礎設施 (相容 macOS Bash 3.2)
# ==========================================
echo "🔍 開始驗證基礎設施狀態..."

# 定義要檢查的服務清單 "服務名稱:Namespace"
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
    local label=$1
    local ns=$2
    printf "   - 檢查 %-15s 在 %-13s namespace: " "$label" "$ns"
    
    # 嘗試三種常見的 K8s 標籤命名慣例 (包含 Flink 的 component)
    if kubectl wait --for=condition=Ready pod -l "app.kubernetes.io/name=$label" -n "$ns" --timeout=15s &> /dev/null || \
       kubectl wait --for=condition=Ready pod -l "app=$label" -n "$ns" --timeout=15s &> /dev/null || \
       kubectl wait --for=condition=Ready pod -l "component=${label#*-}" -n "$ns" --timeout=15s &> /dev/null; then
        echo "✅ PASS"
    else
        echo "⏳ 仍在初始化或超時"
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
REDIS_POD=$(kubectl get pods -n infra -l app.kubernetes.io/name=redis -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
if [ ! -z "$REDIS_POD" ]; then
    # 使用動態獲取的 REDIS_PASS 登入
    MODULES=$(kubectl exec -n infra "$REDIS_POD" -- redis-cli -a "$REDIS_PASS" MODULE LIST 2>/dev/null)
    if echo "$MODULES" | grep -qiE "search|ft"; then
        echo "✅ PASS (RediSearch 已載入)"
    else
        echo "❌ FAIL (未偵測到 RediSearch 模組)"
        echo "模組清單: $MODULES"
    fi
else
    echo "❌ FAIL (找不到 Redis Pod)"
fi

# 檢查 PostgreSQL
printf "   - 驗證 PostgreSQL 連線:       "
POSTGRES_POD=$(kubectl get pods -n infra -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
if [ ! -z "$POSTGRES_POD" ]; then
    # 使用動態獲取的 PG_PASS 登入
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
# 我們手刻的 YAML 標籤是 app=kafka
KAFKA_POD=$(kubectl get pods -n infra -l app=kafka -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
if [ ! -z "$KAFKA_POD" ]; then
    # 使用 kafka-topics.sh 來測試是否能跟 Kafka Broker 通訊
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

# macOS + Docker 版的 Minikube 必須透過 127.0.0.1 加上 Tunnel 才能存取 Ingress
TARGET_IP="127.0.0.1"

# 測試 ArgoCD Ingress
printf "   - 測試 argocd.local:          "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "argocd.local:80:$TARGET_IP" http://argocd.local)
if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "307" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

# 測試 Grafana Ingress
printf "   - 測試 grafana.local:         "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "grafana.local:80:$TARGET_IP" http://grafana.local)
if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "302" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

# 測試 Flink Ingress
printf "   - 測試 flink.local:           "
HTTP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" --resolve "flink.local:80:$TARGET_IP" http://flink.local)
# Flink 的 UI 預設回傳 200
if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ PASS (狀態碼: $HTTP_STATUS)"
else
    echo "❌ FAIL (狀態碼: $HTTP_STATUS)"
fi

echo "-------------------------------------------------------"
echo "🌐 基礎設施網址概況:"
echo "ArgoCD URL:   http://argocd.local"
echo "Grafana URL:  http://grafana.local"
echo "Flink UI:     http://flink.local"
echo "-------------------------------------------------------"
echo "💡 提示 1: ArgoCD 登入帳號為 admin, 密碼為 admin123"
echo "💡 提示 2: Grafana 登入帳號為 admin, 密碼為 admin"
echo "💡 提示 3: 請確保您已將以下內容加入本機的 /etc/hosts :"
echo "          $TARGET_IP argocd.local grafana.local flink.local"
