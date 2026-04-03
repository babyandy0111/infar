#!/bin/bash

# ==========================================
# Infar 基礎設施深度清理腳本 (安全詢問版)
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
    linkerd viz uninstall 2>/dev/null | kubectl delete -f - 2>/dev/null
    linkerd uninstall 2>/dev/null | kubectl delete -f - 2>/dev/null
    kubectl delete namespace linkerd linkerd-viz --ignore-not-found --grace-period=0 --force > /dev/null 2>&1
fi
echo "✅ Linkerd 已移除。"

# ==========================================
# 3. 移除 cdk8s 產生的基礎設施
# ==========================================
echo "3. 移除 cdk8s 產出的基礎設施資源..."
if [ -d "dist" ] && [ "$(ls -A dist)" ]; then
    kubectl delete -f dist/ --ignore-not-found 2>/dev/null
fi
echo "✅ cdk8s 資源已卸載。"

# ==========================================
# 4. 強制移除命名空間
# ==========================================
echo "4. 強制移除命名空間與殘餘 Secrets..."
kubectl delete namespace infra argocd observability --ignore-not-found --grace-period=0 --force > /dev/null 2>&1
echo "✅ 命名空間已移除。"

# ==========================================
# 5. 安全清理持久化資料 (PVC) - 詢問模式
# ==========================================
echo ""
read -p "❓ 是否要刪除所有持久化資料卷 (PVC)? [y/N]: " cleanup_pvc
if [[ "$cleanup_pvc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚨 正在刪除所有 PVC... (這會清除所有資料庫資料)"
    kubectl delete pvc --all -A --ignore-not-found > /dev/null 2>&1
    echo "✅ 磁碟空間已完全釋放。"
else
    echo "ℹ️ 已保留持久化資料卷 (下次安裝將自動沿用資料)。"
fi

echo -e "\n✨ 環境清理完成！現在您可以重新執行 ./setup.sh 測試安裝流程。"
