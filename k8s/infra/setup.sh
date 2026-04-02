#!/bin/bash

# ==========================================
# Infar 基礎設施全自動設定 (冪等宣告式版本)
# ==========================================
cd "$(dirname "$0")" || exit 1

echo "🚀 開始設定 K8s 基礎設施 (cdk8s)..."

# ==========================================
# 0. 依賴檢查
# ==========================================
minikube addons enable ingress > /dev/null

if ! command -v helm &> /dev/null; then
    echo "❌ 找不到 helm，請先安裝 Helm (例如: brew install helm)。"
    exit 1
fi

if ! command -v linkerd &> /dev/null; then
    echo "⚠️ 找不到 linkerd CLI，開始自動安裝..."
    curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
else
    export PATH=$PATH:$HOME/.linkerd2/bin
fi

# ==========================================
# 1. 建立基礎設施專用的 Namespaces
# ==========================================
echo "1. 建立與設定 Namespaces..."
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace linkerd-viz --dry-run=client -o yaml | kubectl apply -f -

# 透過 Namespace 標籤啟用自動注入 (Auto-injection)
kubectl label namespace infra linkerd.io/inject=enabled --overwrite
kubectl label namespace argocd linkerd.io/inject=enabled --overwrite
kubectl label namespace observability linkerd.io/inject=enabled --overwrite

# ==========================================
# 2. 安裝 Service Mesh (Linkerd)
# ==========================================
echo "2. 安裝 Linkerd Service Mesh..."
if ! kubectl get namespace linkerd &> /dev/null; then
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
    linkerd install --crds | kubectl apply -f -
    linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
    linkerd viz install | kubectl apply -f -
    linkerd check --wait 5m
fi

# ==========================================
# 3. 生成 cdk8s 設定檔
# ==========================================
echo "3. 生成 K8s YAML (cdk8s)..."
go run main.go || exit 1

# ==========================================
# 4. 加入 Helm Repositories
# ==========================================
echo "4. 更新 Helm Repos..."
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

# ==========================================
# 5. 部署基礎設施 (Server-Side Apply)
# ==========================================
echo "5. 同步基礎設施狀態 (Declarative Apply)..."
# 回歸純 Apply，依賴 Namespace 的 Auto-injection 來處理 Proxy
kubectl apply --server-side --force-conflicts -f dist/infar-infra.k8s.yaml

# ==========================================
# 6. 自動匯入自製戰情室
# ==========================================
echo "6. 匯入 Grafana 戰情室..."
./import-dashboard.sh

# ==========================================
# 7. 更新本機 /etc/hosts (需要 sudo)
# ==========================================
echo "7. 更新 /etc/hosts..."
TARGET_IP="127.0.0.1"
if grep -q "argocd.local" /etc/hosts; then
    sudo sed -i '' -e "/argocd.local/s/^[0-9.]*/$TARGET_IP/" /etc/hosts
    if ! grep -q "flink.local" /etc/hosts; then
        sudo sed -i '' -e "s/argocd.local/argocd.local flink.local/" /etc/hosts
    fi
else
    echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
fi

echo "✅ 基礎設施狀態已同步完成！"
echo "👉 ArgoCD URL: http://argocd.local"
echo "👉 Grafana URL: http://grafana.local"
echo "👉 Flink UI:   http://flink.local"
