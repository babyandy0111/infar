#!/bin/bash

# ==========================================
# Infar 流量壓力模擬器 (Service Mesh 戰情室專用)
# ==========================================

cd "$(dirname "$0")" || exit 1

echo "🚀 檢查並啟動流量產生器 (load-generator) 中..."
# 建立一個帶有 Linkerd Sidecar 的測試 Pod
kubectl run load-generator -n infra --image=curlimages/curl --labels="linkerd.io/inject=enabled" --restart=Never -- sleep infinity > /dev/null 2>&1

# 等待 Pod 準備就緒 (包含 Sidecar 啟動)
kubectl wait --for=condition=ready pod/load-generator -n infra --timeout=60s > /dev/null 2>&1

echo "🚀 開始模擬跨服務的 Mesh 流量... (按下 Ctrl+C 停止)"
echo "------------------------------------------------"

count=0
while true; do
  count=$((count+1))
  
  # 1. 模擬 Redis 流量 (使用 TCP 協定測試)
  kubectl exec -n infra load-generator -c load-generator -- curl -s --connect-timeout 1 telnet://redis-master:6379 <<< "PING" > /dev/null 2>&1
  
  # 2. 模擬 PostgreSQL 流量 (TCP 連線)
  kubectl exec -n infra load-generator -c load-generator -- curl -s --connect-timeout 1 telnet://infar-infra-postgres-c8f1e7ac-postgresql:5432 > /dev/null 2>&1
  
  # 3. 每 10 次模擬一次 Kafka 流量 (TCP 連線)
  if [ $((count % 10)) -eq 0 ]; then
    kubectl exec -n infra load-generator -c load-generator -- curl -s --connect-timeout 1 telnet://kafka-service:9092 > /dev/null 2>&1
  fi

  # 4. 每 20 次刻意製造一次錯誤請求 (強制發送 HTTP 到 Redis Port 會產生連線拒絕或斷線，Linkerd 會捕捉到錯誤率)
  if [ $((count % 20)) -eq 0 ]; then
    echo -ne "\n⚠️ 製造一次網路層錯誤 (HTTP Request to TCP Port)...\n"
    kubectl exec -n infra load-generator -c load-generator -- curl -s --max-time 1 http://redis-master:6379/wrong_request > /dev/null 2>&1
  fi

  # 每 0.5 秒發送一波
  printf "\r已發送第 %d 波模擬流量 (Mesh 流量)..." "$count"
  sleep 0.5
done
