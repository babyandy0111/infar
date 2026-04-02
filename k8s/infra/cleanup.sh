#!/bin/bash

# ==========================================
# 確保腳本在自身的目錄下執行
# ==========================================
cd "$(dirname "$0")" || exit 1

echo "🧹 開始清理 K8s 基礎設施環境..."

# ==========================================
# 1. 移除 Ingress 網域與本機 hosts 設定 (需要 sudo)
# ==========================================
echo "1. 清理本機 /etc/hosts 紀錄..."
sudo sed -i '' '/argocd.local/d' /etc/hosts
sudo sed -i '' '/grafana.local/d' /etc/hosts
sudo sed -i '' '/flink.local/d' /etc/hosts
echo "✅ /etc/hosts 已回復純淨。"

# ==========================================
# 2. 移除 Service Mesh (Linkerd)
# ==========================================
echo "2. 徹底解除 Linkerd Service Mesh..."
export PATH=$PATH:$HOME/.linkerd2/bin
if command -v linkerd &> /dev/null; then
    linkerd viz uninstall | kubectl delete -f - 2>/dev/null
    linkerd uninstall | kubectl delete -f - 2>/dev/null
    # 強制刪除 namespace 殘骸
    kubectl delete namespace linkerd linkerd-viz --ignore-not-found --grace-period=0 --force
fi
echo "✅ Linkerd 已移除。"

# ==========================================
# 3. 移除 cdk8s 產生的基礎設施
# ==========================================
echo "3. 移除 cdk8s 產出的基礎設施資源 (包含 Helm 轉換的資源)..."
if [ -f "dist/infar-infra.k8s.yaml" ]; then
    kubectl delete -f dist/infar-infra.k8s.yaml --ignore-not-found
else
    echo "⚠️ 找不到 dist/infar-infra.k8s.yaml，跳過基於檔案的刪除。"
    # 如果找不到檔案，我們 fallback 到刪除整個 Namespace，這樣最乾淨
    kubectl delete namespace infra argocd observability --ignore-not-found
fi
echo "✅ cdk8s 資源已卸載。"

# ==========================================
# 4. (選用) 移除舊版原生 YAML 資源 (如果有的話)
# ==========================================
echo "4. 檢查並移除舊版原生 YAML 資源..."
kubectl delete -f manifests/redis-stack.yaml --ignore-not-found 2>/dev/null
kubectl delete -f manifests/kafka-dev.yaml --ignore-not-found 2>/dev/null
kubectl delete -f manifests/flink-dev.yaml --ignore-not-found 2>/dev/null
kubectl delete -f manifests/flink-ingress.yaml --ignore-not-found 2>/dev/null
kubectl delete -f manifests/infar-dashboard.yaml --ignore-not-found 2>/dev/null
kubectl delete -f manifests/linkerd-viz-auth.yaml --ignore-not-found 2>/dev/null
echo "✅ 舊版資源已清理。"

# ==========================================
# 5. 清理 Namespace 與 Secrets
# ==========================================
echo "5. 移除命名空間與 Secrets..."
kubectl delete namespace infra argocd observability --ignore-not-found
echo "✅ 命名空間已移除。"

# ==========================================
# 6. 選項：清理持久化資料 (PVC)
# ==========================================
read -p "❓ 是否要刪除所有持久化資料 (PVC)? 資料一旦刪除將無法救回 [y/N]: " cleanup_pvc
if [[ "$cleanup_pvc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚨 正在刪除所有 PVC..."
    kubectl delete pvc --all -A
    echo "✅ 磁碟空間已完全釋放。"
else
    echo "ℹ️ 已保留持久化資料。"
fi

echo -e "\n✨ 環境清理完成！現在您可以重新執行 ./setup.sh 測試安裝流程。"
