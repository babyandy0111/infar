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
# 0. 依賴檢查：Python, bcrypt, helm, linkerd
# ==========================================
echo "0. 檢查系統依賴與啟動 Addons..."
minikube addons enable ingress

if ! command -v helm &> /dev/null; then
    echo "❌ 找不到 helm，請先安裝 Helm (例如: brew install helm)。"
    exit 1
fi

if ! command -v linkerd &> /dev/null; then
    echo "⚠️ 找不到 linkerd CLI，開始自動安裝..."
    curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
    echo "✅ linkerd CLI 安裝完成。"
else
    echo "✅ linkerd CLI 已安裝。"
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ 找不到 python3，請先安裝 Python3。"
    exit 1
fi

if ! python3 -c "import bcrypt" &> /dev/null; then
    echo "⚠️ 找不到 Python bcrypt 模組，開始自動安裝..."
    pip3 install bcrypt
    echo "✅ bcrypt 安裝完成。"
fi

# ==========================================
# 1. 建立基礎設施專用的 Namespaces 與 Service Mesh
# ==========================================
echo "1. 建立 Namespaces..."
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# 標記 infra namespace 讓 Linkerd 自動注入 Sidecar (實現 Service Mesh)
kubectl label namespace infra linkerd.io/inject=enabled --overwrite

# ==========================================
# 2. 建立動態 Secrets (安全管理)
# ==========================================
echo "2. 初始化 Secrets (安全管理)..."
if ! kubectl get secret infra-secrets -n infra &> /dev/null; then
    echo "   - 產生高強度隨機密碼並建立 infra-secrets..."
    PG_PASS=$(openssl rand -base64 12)
    REDIS_PASS=$(openssl rand -base64 12)
    kubectl create secret generic infra-secrets -n infra \
        --from-literal=postgresql-password="$PG_PASS" \
        --from-literal=redis-password="$REDIS_PASS"
else
    PG_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.postgresql-password}" | base64 --decode)
    REDIS_PASS=$(kubectl get secret infra-secrets -n infra -o jsonpath="{.data.redis-password}" | base64 --decode)
fi

# 動態產生 ArgoCD 的 Bcrypt 雜湊值
ARGOCD_ADMIN_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b\"$ARGOCD_ADMIN_PASSWORD\", bcrypt.gensalt()).decode())")
TEMP_ARGOCD_VALUES=$(mktemp)
cat <<EOF > "$TEMP_ARGOCD_VALUES"
configs:
  secret:
    argocdServerAdminPassword: "$ARGOCD_ADMIN_HASH"
EOF

# ==========================================
# 3. 安裝 Service Mesh (Linkerd)
# ==========================================
echo "3. 安裝 Linkerd Service Mesh..."
export PATH=$PATH:$HOME/.linkerd2/bin
if ! kubectl get namespace linkerd &> /dev/null; then
    echo "   - 補齊 Gateway API CRDs (Linkerd 依賴)..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
    
    echo "   - 安裝 Linkerd CRDs 與 Control Plane (請耐心等候)..."
    linkerd install --crds | kubectl apply -f -
    # Minikube Docker Driver 必須開啟 proxyInit.runAsRoot
    linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
    
    echo "   - 安裝 Linkerd Viz 視覺化擴展..."
    linkerd viz install | kubectl apply -f -
    
    echo "   - 套用 Grafana 存取授權 (解決 403 錯誤)..."
    kubectl apply -f manifests/linkerd-viz-auth.yaml
    
    # 等待控制平面就緒
    linkerd check --wait 5m
else
    echo "   - Linkerd 已安裝。"
fi

# ==========================================
# 4. 準備 Grafana Dashboards (Infar 專屬)
# ==========================================
echo "4. 套用 Infar 專屬儀表板設定..."
kubectl apply -f manifests/infar-dashboard.yaml

# ==========================================
# 5. 部署服務
# ==========================================
echo "5. 部署基礎設施..."
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

helm upgrade --install postgresql bitnami/postgresql --version 18.5.14 -n infra -f helm-values/postgresql.yaml
kubectl apply -f manifests/redis-stack.yaml

echo "   - 部署 Kafka (原生開發用版本)..."
kubectl apply -f manifests/kafka-dev.yaml

echo "   - 部署 Flink (原生開發用版本)..."
kubectl apply -f manifests/flink-dev.yaml
kubectl apply -f manifests/flink-ingress.yaml

helm upgrade --install argocd argo/argo-cd --version 9.4.17 -n argocd -f helm-values/argocd.yaml -f "$TEMP_ARGOCD_VALUES"
helm upgrade --install loki grafana/loki --version 6.55.0 -n observability -f helm-values/loki.yaml
helm upgrade --install promtail grafana/promtail --version 6.17.1 -n observability -f helm-values/promtail.yaml
helm upgrade --install grafana grafana/grafana --version 10.5.15 -n observability -f helm-values/grafana.yaml
helm upgrade --install prometheus prometheus-community/prometheus --version 25.27.0 -n observability --set server.persistentVolume.enabled=false --set alertmanager.enabled=false --set pushgateway.enabled=false

# ==========================================
# 6. 自動更新本機 /etc/hosts
# ==========================================
echo "6. 更新本機 /etc/hosts (需要 sudo 權限)..."
TARGET_IP="127.0.0.1"
if grep -q "argocd.local" /etc/hosts; then
    sudo sed -i '' -e "/argocd.local/s/^[0-9.]*/$TARGET_IP/" /etc/hosts
    if ! grep -q "flink.local" /etc/hosts; then
        sudo sed -i '' -e "s/argocd.local/argocd.local flink.local/" /etc/hosts
    fi
else
    echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
fi

rm -f "$TEMP_ARGOCD_VALUES"
echo "✅ 所有基礎設施與網路設定已完成！"
echo "👉 ArgoCD URL: http://argocd.local (帳號: admin, 密碼: ${ARGOCD_ADMIN_PASSWORD})"
echo "👉 Grafana URL: http://grafana.local (帳號: admin, 密碼: admin)"
echo "🔐 PostgreSQL 自動產生密碼: $PG_PASS"
echo "🔐 Redis 自動產生密碼: $REDIS_PASS"
echo "💡 若瀏覽器無法連線，請開啟新終端機執行: minikube tunnel"
echo "💡 查看微服務流量拓撲，請輸入指令: linkerd viz dashboard"
