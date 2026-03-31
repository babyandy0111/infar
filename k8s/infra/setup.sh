#!/bin/bash

# ==========================================
# 確保腳本在自身的目錄下執行
# ==========================================
cd "$(dirname "$0")" || exit 1

# ==========================================
# 基礎設定
# ==========================================
ARGOCD_ADMIN_PASSWORD="admin123"

echo "🚀 開始設定 K8s 基礎設施 (Helm Repositories)..."

# ==========================================
# 依賴檢查：Python, bcrypt, helm
# ==========================================
echo "0. 檢查系統依賴與啟動 Addons..."
minikube addons enable ingress

if ! command -v helm &> /dev/null; then
    echo "❌ 找不到 helm，請先安裝 Helm (例如: brew install helm)。"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ 找不到 python3，請先安裝 Python3。"
    exit 1
fi

if ! python3 -c "import bcrypt" &> /dev/null; then
    echo "⚠️ 找不到 Python bcrypt 模組，開始自動安裝..."
    pip3 install bcrypt
    if [ $? -ne 0 ]; then
        echo "❌ 安裝 bcrypt 失敗，請手動檢查環境。"
        exit 1
    fi
    echo "✅ bcrypt 安裝完成。"
else
    echo "✅ bcrypt 已安裝。"
fi

# 動態產生 ArgoCD 的 Bcrypt 雜湊值
echo "🔄 正在產生 ArgoCD 管理員密碼雜湊..."
ARGOCD_ADMIN_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b\"$ARGOCD_ADMIN_PASSWORD\", bcrypt.gensalt()).decode())")

# 使用一個臨時檔來安全傳遞密碼
TEMP_ARGOCD_VALUES=$(mktemp)
cat <<EOF > "$TEMP_ARGOCD_VALUES"
configs:
  secret:
    argocdServerAdminPassword: "$ARGOCD_ADMIN_HASH"
EOF

# ==========================================
# 加入 Helm Repositories
# ==========================================
echo "1. 加入 Helm Repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# ==========================================
# 建立基礎設施專用的 Namespaces
# ==========================================
echo "2. 建立 Namespaces..."
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# ==========================================
# 部署服務 (固定版本號，確保穩定性與消除 Rolling Tag 警告)
# ==========================================
echo "3. 部署 PostgreSQL..."
helm upgrade --install postgresql bitnami/postgresql --version 18.5.14 -n infra -f helm-values/postgresql.yaml

echo "4. 部署 Redis (with RediSearch)..."
kubectl apply -f manifests/redis-stack.yaml

echo "5. 部署 ArgoCD..."
helm upgrade --install argocd argo/argo-cd --version 9.4.17 -n argocd -f helm-values/argocd.yaml -f "$TEMP_ARGOCD_VALUES"

echo "6. 部署 PLG Stack (Loki + Promtail + Grafana)..."
helm upgrade --install loki grafana/loki --version 6.55.0 -n observability -f helm-values/loki.yaml
helm upgrade --install promtail grafana/promtail --version 6.17.1 -n observability -f helm-values/promtail.yaml
helm upgrade --install grafana grafana/grafana --version 10.5.15 -n observability -f helm-values/grafana.yaml

# 清理臨時檔案
rm -f "$TEMP_ARGOCD_VALUES"

# ==========================================
# 自動更新本機 /etc/hosts 檔案
# ==========================================
echo "7. 更新本機 /etc/hosts 網路設定 (需要 sudo 權限)..."

# 在 macOS + Docker Driver 下，Ingress 必須透過 tunnel 導向 127.0.0.1
TARGET_IP="127.0.0.1"

# 檢查是否已存在相關網域紀錄
if grep -q "argocd.local" /etc/hosts; then
    echo "   - 發現現有紀錄，正在更新 IP 為 $TARGET_IP..."
    sudo sed -i '' -e "/argocd.local/s/^[0-9.]*/$TARGET_IP/" /etc/hosts
else
    echo "   - 新增網域紀錄指向 $TARGET_IP..."
    echo "$TARGET_IP argocd.local grafana.local" | sudo tee -a /etc/hosts > /dev/null
fi
echo "✅ /etc/hosts 更新完成！"

echo "✅ 所有基礎設施與網路設定已完成！"
echo "👉 ArgoCD URL: http://argocd.local (帳號: admin, 密碼: ${ARGOCD_ADMIN_PASSWORD})"
echo "👉 Grafana URL: http://grafana.local (帳號: admin, 密碼: admin)"
echo "👉 觀察進度: kubectl get pods -A"
echo "💡 若瀏覽器無法連線，請開啟新終端機執行: minikube tunnel"
