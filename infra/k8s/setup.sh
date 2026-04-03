#!/bin/bash

# ==========================================
# Infar 基礎設施全自動設定 (多環境支援版)
# ==========================================
cd "$(dirname "$0")" || exit 1

# 預設環境為 local，可帶入參數: ./setup.sh aws|gcp|local
INFAR_CLOUD_PROVIDER=${1:-local}
export INFAR_CLOUD_PROVIDER=$INFAR_CLOUD_PROVIDER

echo "🚀 開始同步 K8s 基礎設施狀態 (目標環境: $INFAR_CLOUD_PROVIDER)..."

# ==========================================
# 0. 依賴檢查
# ==========================================
echo "0. 檢查系統依賴..."
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    minikube addons enable ingress > /dev/null
fi
export PATH=$PATH:$HOME/.linkerd2/bin

# ==========================================
# 1. 基礎設施命名空間與標籤
# ==========================================
echo "1. 建立與設定 Namespaces..."
for ns in infra argocd observability linkerd-viz; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    kubectl label namespace "$ns" linkerd.io/inject=enabled --overwrite > /dev/null
done

# ==========================================
# 2. 安裝/檢查 Service Mesh (Linkerd)
# ==========================================
echo "2. 安裝 Linkerd Service Mesh..."
if ! kubectl get namespace linkerd &> /dev/null; then
    echo "📦 正在安裝 Linkerd Service Mesh 控制平面..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
    linkerd install --crds | kubectl apply -f -
    linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
    linkerd viz install | kubectl apply -f -
fi

# ==========================================
# 3. 狀態同步 (IaC Apply)
# ==========================================
echo "3. 生成 K8s YAML (cdk8s)..."
# Go 程式碼會讀取 INFAR_CLOUD_PROVIDER 環境變數來決定產生哪些資源
go run main.go || exit 1

echo "4. 更新 Helm Repos..."
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo update > /dev/null

echo "5. 同步基礎設施狀態 (Declarative Apply)..."
# 使用 Server-Side Apply 確保幂等性
kubectl apply --server-side --force-conflicts -f dist/

# ==========================================
# 6. 後續自動化設定
# ==========================================
echo "6. 匯入 Grafana 戰情室..."
./import-dashboard.sh

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "7. 更新本機 /etc/hosts..."
    TARGET_IP="127.0.0.1"
    if ! grep -q "argocd.local" /etc/hosts; then
        echo "🌐 正在更新 /etc/hosts (需要您的密碼)..."
        echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
    fi
else
    echo "7. 跳過本機 hosts 更新 (非 local 環境)..."
fi

echo "✅ 基礎設施狀態已達最新 (環境: $INFAR_CLOUD_PROVIDER)！"
echo "👉 ArgoCD URL: http://argocd.local"
echo "👉 Grafana URL: http://grafana.local"
echo "👉 Flink UI:   http://flink.local"
echo "👉 儀表板狀況: linkerd viz dashboard"
