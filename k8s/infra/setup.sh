#!/bin/bash

# ==========================================
# 確保腳本在自身的目錄下執行
# ==========================================
cd "$(dirname "$0")" || exit 1

echo "🚀 開始設定 K8s 基礎設施 (cdk8s)..."

# ==========================================
# 0. 依賴檢查：helm, linkerd
# ==========================================
echo "0. 檢查系統依賴與啟動 Addons..."
minikube addons enable ingress > /dev/null

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

# ==========================================
# 1. 建立基礎設施專用的 Namespaces
# ==========================================
echo "1. 建立 Namespaces..."
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace linkerd-viz --dry-run=client -o yaml | kubectl apply -f -

# 強制標記 infra 允許 Linkerd 注入
kubectl label namespace infra linkerd.io/inject=enabled --overwrite

# ==========================================
# 2. 安裝 Service Mesh (Linkerd)
# ==========================================
echo "2. 安裝 Linkerd Service Mesh..."
export PATH=$PATH:$HOME/.linkerd2/bin
if ! kubectl get namespace linkerd &> /dev/null; then
    echo "   - 補齊 Gateway API CRDs (Linkerd 依賴)..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
    
    echo "   - 安裝 Linkerd CRDs 與 Control Plane (請耐心等候)..."
    linkerd install --crds | kubectl apply -f -
    linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
    
    echo "   - 安裝 Linkerd Viz 視覺化擴展..."
    linkerd viz install | kubectl apply -f -
    
    # 等待控制平面就緒
    linkerd check --wait 5m
else
    echo "   - Linkerd 已安裝。"
fi

# ==========================================
# 3. 生成 cdk8s 設定檔 (基礎設施即代碼)
# ==========================================
echo "3. 正在透過 cdk8s (Go) 與 .env 動態產生 K8s 設定檔..."
go run main.go
if [ $? -ne 0 ]; then
    echo "❌ cdk8s 產出失敗，請檢查 main.go 或 .env 設定。"
    exit 1
fi

# ==========================================
# 4. 加入 Helm Repositories
# ==========================================
echo "4. 準備 Helm Repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

# ==========================================
# 5. 部署所有基礎設施 (Server-Side Apply)
# ==========================================
echo "5. 部署所有基礎設施 (IaC)..."
# 使用 server-side 避免 ArgoCD 等超大 CRD 觸發 "metadata.annotations: Too long" 錯誤
kubectl apply --server-side --force-conflicts -f dist/infar-infra.k8s.yaml

# ==========================================
# 6. 自動匯入自製的 7 大維度 Grafana 戰情室
# ==========================================
echo "6. 正在匯入 Infar 專屬戰情室儀表板..."
./import-dashboard.sh

# ==========================================
# 7. 自動更新本機 /etc/hosts 檔案
# ==========================================
echo "7. 更新本機 /etc/hosts (需要 sudo 權限)..."
TARGET_IP="127.0.0.1"
if grep -q "argocd.local" /etc/hosts; then
    sudo sed -i '' -e "/argocd.local/s/^[0-9.]*/$TARGET_IP/" /etc/hosts
    if ! grep -q "flink.local" /etc/hosts; then
        sudo sed -i '' -e "s/argocd.local/argocd.local flink.local/" /etc/hosts
    fi
else
    echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
fi

echo "✅ 所有基礎設施與網路設定已完成！"
echo "👉 您的密碼請參閱 .env 檔案中的設定。"
echo "👉 ArgoCD URL: http://argocd.local"
echo "👉 Grafana URL: http://grafana.local"
echo "👉 Flink UI:   http://flink.local"
echo "💡 若瀏覽器無法連線，請開啟新終端機執行: minikube tunnel"
echo "💡 查看微服務流量拓撲，請輸入指令: linkerd viz dashboard"
