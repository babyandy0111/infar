#!/bin/bash

# ==========================================
# Infar 基礎設施全自動設定 (專業冪等自癒版)
# ==========================================
cd "$(dirname "$0")" || exit 1

echo "🚀 開始同步 K8s 基礎設施狀態..."

# ==========================================
# 0. 依賴檢查
# ==========================================
echo "0. 檢查系統依賴..."
minikube addons enable ingress > /dev/null
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
go run main.go || exit 1

echo "4. 更新 Helm Repos..."
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo update > /dev/null

echo "5. 同步基礎設施狀態 (Declarative Apply)..."
# 使用 Server-Side Apply 確保幂等性與大型 CRD 相容
# 此處依賴 Go 代碼中已關閉 Test Hooks，因此不會再產生幽靈 Pod
kubectl apply --server-side --force-conflicts -f dist/infar-infra.k8s.yaml

# ==========================================
# 6. 後續自動化設定
# ==========================================
echo "6. 匯入 Grafana 戰情室..."
./import-dashboard.sh

echo "7. 更新本機 /etc/hosts..."
TARGET_IP="127.0.0.1"
if ! grep -q "argocd.local" /etc/hosts; then
    echo "🌐 更新 /etc/hosts (需要密碼)..."
    echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
fi

echo "✅ 基礎設施狀態已達最新且自動優化完成！"
echo "👉 ArgoCD URL: http://argocd.local"
echo "👉 Grafana URL: http://grafana.local"
echo "👉 Flink UI:   http://flink.local"
echo "👉 儀表板狀況: linkerd viz dashboard"
