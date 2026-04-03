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
        echo "   - 正在啟動 GCP 必要 API..."
        gcloud services enable compute.googleapis.com container.googleapis.com sqladmin.googleapis.com redis.googleapis.com servicenetworking.googleapis.com cloudresourcemanager.googleapis.com > /dev/null
    fi

    TF_DIR="../terraform/$INFAR_CLOUD_PROVIDER"
    
    if [ ! -d "$TF_DIR" ]; then
        echo "❌ 找不到對應的 Terraform 目錄: $TF_DIR"
        exit 1
    fi

    pushd "$TF_DIR" > /dev/null
    
    echo "   - 正在初始化與同步雲端資源..."
    terraform init -upgrade > /dev/null
    terraform apply -auto-approve || exit 1
    
    echo "   - 正在自動抓取雲端資源 Endpoint..."
    export DB_ENDPOINT=$(terraform output -raw db_endpoint)
    export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    
    echo "   - 更新 K8s 叢集連線憑證..."
    if [ "$INFAR_CLOUD_PROVIDER" == "gcp" ]; then
        gcloud components install gke-gcloud-auth-plugin --quiet > /dev/null 2>&1
    fi
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

# ==========================================
# 1. 建立與設定 Namespaces
# ==========================================
echo "1. 建立與設定 Namespaces..."
for ns in infra argocd observability linkerd-viz; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    
    # 🚀 關鍵架構決策：只有 local 環境才啟用 Linkerd 自動注入
    if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
        kubectl label namespace "$ns" linkerd.io/inject=enabled --overwrite > /dev/null
    else
        # 雲端環境移除標籤，避免啟動失敗
        kubectl label namespace "$ns" linkerd.io/inject- > /dev/null 2>&1
    fi
done

# ==========================================
# 2. 安裝/檢查 Service Mesh (Linkerd) - 僅限 Local
# ==========================================
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "2. 檢查 Service Mesh 狀態 (僅 Local 啟用)..."
    export PATH=$PATH:$HOME/.linkerd2/bin
    if ! kubectl get namespace linkerd &> /dev/null; then
        echo "📦 正在安裝 Linkerd Service Mesh..."
        kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml > /dev/null
        linkerd install --crds | kubectl apply -f -
        linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -
        
        echo "   - 等待 Linkerd 控制平面啟動..."
        linkerd check --wait 5m
        
        echo "   - 安裝 Linkerd Viz 視覺化擴展..."
        linkerd viz install | kubectl apply -f -
    fi
else
    echo "2. 跳過 Service Mesh 安裝 (雲端環境使用原生 Cloud Monitoring)..."
fi

# ==========================================
# 3. 狀態同步 (IaC Apply)
# ==========================================
echo "3. 生成 K8s YAML 並執行同步 (cdk8s)..."
go run main.go || exit 1

helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null
helm repo add argo https://argoproj.github.io/argo-helm > /dev/null
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
helm repo update > /dev/null

kubectl apply --server-side --force-conflicts -f dist/

# ==========================================
# 4. 後續自動化設定
# ==========================================
# 只有 local 環境才需要匯入戰情室 (雲端環境 Grafana 將被閹割或移除)
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "4. 匯入 Grafana 戰情室..."
    ./import-dashboard.sh

    echo "5. 更新本機 /etc/hosts..."
    TARGET_IP="127.0.0.1"
    if ! grep -q "argocd.local" /etc/hosts; then
        echo "🌐 更新 /etc/hosts (需要密碼)..."
        echo "$TARGET_IP argocd.local grafana.local flink.local" | sudo tee -a /etc/hosts > /dev/null
    fi
else
    echo "4. 跳過戰情室匯入與 hosts 更新 (雲端環境配置)..."
fi

echo "✅ 基礎設施 [$INFAR_CLOUD_PROVIDER] 已全自動同步完成！"

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "👉 ArgoCD URL: http://argocd.local (請確保已執行 minikube tunnel)"
else
    echo "👉 雲端環境部署完成！請等待 Cloud LoadBalancer 建立。"
    echo "🔍 取得 ArgoCD 外部網址: kubectl get ingress argocd-server -n argocd"
    echo "🔍 取得 Flink 外部網址:  kubectl get ingress flink-ui -n infra"
fi
