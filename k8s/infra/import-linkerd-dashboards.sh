#!/bin/bash
echo "📦 正在從 Linkerd 官方下載並匯入 Grafana Dashboards..."

# 建立一個暫存目錄存放下載的 JSON
mkdir -p /tmp/linkerd-dashboards
cd /tmp/linkerd-dashboards

# 核心 Dashboards 清單 (Linkerd 官方 GitHub)
DASHBOARDS=(
  "top-line"
  "namespace"
  "deployment"
  "pod"
  "service"
)

# 逐一下載 JSON 檔案
for db in "${DASHBOARDS[@]}"; do
  echo "   - 下載 $db.json..."
  curl -sSL -o "${db}.json" "https://raw.githubusercontent.com/linkerd/linkerd2/main/grafana/dashboards/${db}.json"
  
  # 替換 Data Source 為我們的 Prometheus 名稱 (預設為 Prometheus)
  sed -i '' 's/${datasource}/Prometheus/g' "${db}.json"
done

# 將這些 JSON 打包成 Kubernetes ConfigMap 放入 observability namespace
echo "🚀 建立 ConfigMap 匯入 Grafana..."
kubectl create configmap linkerd-grafana-dashboards \
  -n observability \
  --from-file=. \
  --dry-run=client -o yaml | kubectl apply -f -

# 為 ConfigMap 加上標籤，讓 Grafana 的 Sidecar (如果有開的話) 自動發現它
# 或者我們稍後修改 grafana values yaml 來掛載這個 ConfigMap
kubectl label configmap linkerd-grafana-dashboards grafana_dashboard=1 -n observability --overwrite

echo "✅ 匯入完成！"
cd - > /dev/null
rm -rf /tmp/linkerd-dashboards
