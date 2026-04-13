#!/bin/bash
# 取得 Grafana 密碼
# 動態抓取 Grafana 的 Secret 名稱
GRAFANA_SECRET_NAME=$(kubectl get secret -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
GRAFANA_PASS=$(kubectl get secret --namespace observability "$GRAFANA_SECRET_NAME" -o jsonpath="{.data.admin-password}" | base64 --decode)

# 準備完整的 7 大維度 JSON
cat << 'JSON_EOF' > /tmp/infar-dashboard.json
{
  "dashboard": {
    "uid": "infar-microservices-war-room",
    "title": "Infar - Microservices War Room",
    "timezone": "browser",
    "refresh": "5s",
    "schemaVersion": 30,
    "panels": [
      {
        "type": "stat",
        "title": "Infra Active Connections",
        "gridPos": { "h": 5, "w": 8, "x": 0, "y": 0 },
        "targets": [
          {
            "expr": "sum(tcp_open_total{namespace=\"infra\"}) - sum(tcp_close_total{namespace=\"infra\"})",
            "legendFormat": "Active Connections",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ],
        "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
      },
      {
        "type": "stat",
        "title": "TCP Connection Rate (ops/s)",
        "gridPos": { "h": 5, "w": 8, "x": 8, "y": 0 },
        "targets": [
          {
            "expr": "sum(rate(tcp_open_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "Conn Rate",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ],
        "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
      },
      {
        "type": "stat",
        "title": "Network Throughput (Total)",
        "gridPos": { "h": 5, "w": 8, "x": 16, "y": 0 },
        "targets": [
          {
            "expr": "sum(rate(tcp_read_bytes_total{namespace=\"infra\"}[1m])) + sum(rate(tcp_write_bytes_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "Throughput",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ],
        "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
      },
      {
        "type": "timeseries",
        "title": "TCP Open Rate by Pod",
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 5 },
        "targets": [
          {
            "expr": "sum by (pod) (rate(tcp_open_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "{{pod}}",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Throughput by Pod (Read)",
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 5 },
        "targets": [
          {
            "expr": "sum by (pod) (rate(tcp_read_bytes_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "{{pod}}",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "TCP Connections by Pod",
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 13 },
        "targets": [
          {
            "expr": "sum by (pod) (rate(tcp_open_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "{{pod}}",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ]
      },
      {
        "type": "timeseries",
        "title": "Network Throughput",
        "gridPos": { "h": 8, "w": 12, "x": 12, "y": 13 },
        "targets": [
          {
            "expr": "sum by (pod) (rate(tcp_read_bytes_total{namespace=\"infra\"}[1m]))",
            "legendFormat": "{{pod}} - Read",
            "datasource": {"uid": "Linkerd-Prometheus"}
          }
        ]
      }
    ],
    "version": 0
  },
  "folderId": 0,
  "overwrite": true
}
JSON_EOF

# 確保 Grafana Pod 已經啟動且 API 可以呼叫
echo "等待 Grafana API 就緒..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n observability --timeout=60s > /dev/null

# 開啟臨時通道
GRAFANA_SVC=$(kubectl get svc -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward svc/"$GRAFANA_SVC" 3000:80 -n observability > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5

# 匯入
echo "🚀 正在將 7 大維度戰情室匯入 Grafana..."
curl -s -X POST -H "Content-Type: application/json" -u "admin:${GRAFANA_PASS}" -d @/tmp/infar-dashboard.json http://127.0.0.1:3000/api/dashboards/db > /dev/null

# 關閉通道與清理
kill $PORT_FORWARD_PID
rm /tmp/infar-dashboard.json
echo "✅ 戰情室匯入完成！"
