#!/bin/bash

# ==========================================
# Infar 流量壓力模擬器 (Service Mesh 戰情室專用)
# ==========================================

cd "$(dirname "$0")" || exit 1

echo "🚀 部署強效型流量產生器 (Deployment模式確保 Linkerd 注入)..."

# 使用一個預裝了 curl, redis, postgresql-client 的 Docker 映像檔
# 並且在 spec.template.metadata 強制標記 inject=enabled
cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: infar-load-generator
  namespace: infra
spec:
  replicas: 1
  selector:
    matchLabels:
      app: infar-load-generator
  template:
    metadata:
      labels:
        app: infar-load-generator
      annotations:
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: generator
        # bitnami/os-shell 包含了非常豐富的網路檢測工具 (含 curl)
        # 我們用它啟動後，再補裝特定用戶端工具，確保環境乾淨
        image: bitnami/os-shell:latest
        command: ["/bin/bash", "-c"]
        args: 
          - |
            apt-get update >/dev/null 2>&1
            apt-get install -y curl redis-tools postgresql-client >/dev/null 2>&1
            echo "Tools installed, sleeping..."
            sleep infinity
EOF

echo "⏳ 等待流量產生器啟動並注入 Proxy..."
kubectl wait --for=condition=available deployment/infar-load-generator -n infra --timeout=120s > /dev/null

# 取得 Pod 名稱
GEN_POD=$(kubectl get pod -n infra -l app=infar-load-generator -o jsonpath='{.items[0].metadata.name}')

echo "✅ 產生器已就緒 ($GEN_POD)！開始發射真實的 Mesh 流量... (按下 Ctrl+C 停止)"
echo "------------------------------------------------"

# 取得認證資訊
PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" 2>/dev/null | base64 --decode)
REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" 2>/dev/null | base64 --decode)

count=0
while true; do
  count=$((count+1))
  
  # 1. HTTP 流量 (最佳觀賞效果)：請求 Flink Web UI
  kubectl exec -n infra "$GEN_POD" -c generator -- curl -s -o /dev/null http://flink-jobmanager:8081
  
  # 2. Redis 流量：真實的 PING
  kubectl exec -n infra "$GEN_POD" -c generator -- redis-cli -h redis-master -p 6379 -a "$REDIS_PASS" PING > /dev/null 2>&1
  
  # 3. Postgres 流量：真實的連線探測
  kubectl exec -n infra "$GEN_POD" -c generator -- env PGPASSWORD="$PG_PASS" pg_isready -h infar-infra-postgres-c8f1e7ac-postgresql -p 5432 -U admin > /dev/null 2>&1
  
  # 4. 製造 HTTP 錯誤：請求不存在的 Flink 頁面 (讓 Grafana 顯示 404 錯誤率)
  if [ $((count % 5)) -eq 0 ]; then
    kubectl exec -n infra "$GEN_POD" -c generator -- curl -s -o /dev/null http://flink-jobmanager:8081/not_exist_page
    echo -ne "\r💥 發送了 1 次異常請求...                         "
  fi

  # 每 0.2 秒發送一波，加快資料累積速度
  printf "\r⚡ 已發送第 %d 波混合模擬流量..." "$count"
  sleep 0.2
done
