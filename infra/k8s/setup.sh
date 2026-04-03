#!/bin/bash

# ==========================================
# Infar 基礎設施全自動設定 (真實雲端對接版)
# ==========================================
cd "$(dirname "$0")" || exit 1

# 預設環境為 local，可帶入參數: ./setup.sh aws|gcp|local
INFAR_CLOUD_PROVIDER=${1:-local}
export INFAR_CLOUD_PROVIDER=$INFAR_CLOUD_PROVIDER

# 讀取 .env 檔案並將變數匯出
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 將 .env 變數轉換為 Terraform 識別的格式
export TF_VAR_project_id=$GCP_PROJECT_ID
export TF_VAR_region=$GCP_REGION
if [ "$INFAR_CLOUD_PROVIDER" == "aws" ]; then
    export TF_VAR_region=$AWS_REGION
    export TF_VAR_cluster_name=$AWS_CLUSTER_NAME
fi

echo "🚀 開始同步 K8s 基礎設施狀態 (目標環境: $INFAR_CLOUD_PROVIDER)..."

# ==========================================
# 0. 雲端基礎設施建置 (Terraform)
# ==========================================
if [ "$INFAR_CLOUD_PROVIDER" != "local" ]; then
    echo "☁️ 0. [雲端模式] 啟動 Terraform 基礎設施引擎 ($INFAR_CLOUD_PROVIDER)..."

    # GCP 專屬 API 預先開啟
    if [ "$INFAR_CLOUD_PROVIDER" == "gcp" ]; then
        echo "   - 正在啟動 GCP 必要 API (Compute, GKE, SQL, Redis)..."
        gcloud services enable compute.googleapis.com \
                               container.googleapis.com \
                               sqladmin.googleapis.com \
                               redis.googleapis.com \
                               cloudresourcemanager.googleapis.com > /dev/null
    fi

    TF_DIR="../terraform/$INFAR_CLOUD_PROVIDER"
    
    if [ ! -d "$TF_DIR" ]; then
        echo "❌ 找不到對應的 Terraform 目錄: $TF_DIR"
        exit 1
    fi

    pushd "$TF_DIR" > /dev/null
    
    echo "   - 正在初始化與同步雲端資源 (這可能需要 15~20 分鐘)..."
    terraform init -upgrade > /dev/null
    terraform apply -auto-approve || exit 1
    
    echo "   - 正在自動抓取雲端資源 Endpoint..."
    # 真實獲取 Terraform 輸出的 Endpoint 並注入環境變數給 cdk8s
    export DB_ENDPOINT=$(terraform output -raw db_endpoint)
    export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    
    # 自動切換 kubectl 到雲端叢集
    echo "   - 更新 K8s 叢集連線憑證..."
    CONF_CMD=$(terraform output -raw configure_kubectl)
    eval "$CONF_CMD"
    
    echo "----------------------------------------"
    echo "🌐 雲端連線資訊 (已成功抓取):"
    echo "   - Postgres: $DB_ENDPOINT"
    echo "   - Redis:    $REDIS_ENDPOINT"
    echo "----------------------------------------"
    
    popd > /dev/null
else
    echo "💻 0. [本機模式] 檢查系統依賴..."
    minikube addons enable ingress > /dev/null
fi
export PATH=$PATH:$HOME/.linkerd2/bin

# ==========================================
# 1. 建立與設定 Namespaces
# ==========================================
echo "1. 建立與設定 Namespaces..."
for ns in infra argocd observability linkerd-viz; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    kubectl label namespace "$ns" linkerd.io/inject=enabled --overwrite > /dev/null
done

# ==========================================
# 2. 安裝/檢查 Service Mesh (Linkerd)
# ==========================================
echo "2. 檢查 Service Mesh 狀態..."
if ! kubectl get namespace linkerd &> /dev/null; then
    echo "📦 正在安裝 Linkerd Service Mesh..."
    kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
    linkerd install --crds | kubectl apply -f -
    linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
    linkerd viz install | kubectl apply -f -
fi

# ==========================================
# 3. 狀態同步 (IaC Apply)
# ==========================================
echo "3. 生成 K8s YAML 並執行同步 (cdk8s)..."
go run main.go || exit 1

# 更新 Helm Repos 
helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

# 套用資源
kubectl apply --server-side --force-conflicts -f dist/

# ==========================================
# 4. 後續自動化設定
# ==========================================
echo "4. 匯入 Grafana 戰情室..."
./import-dashboard.sh

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "5. 更新本機 /etc/hosts..."
    TARGET_IP="127.0.0.1"
    if ! grep -q "argocd.local" /etc/hosts; then
        echo "🌐 更新 /etc/hosts (需要密碼)..."
        echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
    fi
else
    echo "5. 跳過本機 hosts 更新 (雲端環境使用 Ingress 網址)..."
fi

echo "✅ 基礎設施 [$INFAR_CLOUD_PROVIDER] 已全自動同步完成！"

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "👉 ArgoCD URL: http://argocd.local (請確保已執行 minikube tunnel)"
else
    echo "👉 雲端環境部署完成！請等待 Cloud LoadBalancer (ALB/Ingress) 建立。"
    echo "🔍 取得 ArgoCD 外部網址: kubectl get ingress argocd-server -n argocd"
    echo "🔍 取得 Grafana 外部網址: kubectl get ingress grafana -n observability"
fi
