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
export TF_VAR_db_user=$DB_USER
export TF_VAR_db_password=$DB_PASSWORD
export TF_VAR_db_name=$DB_NAME

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
    
    # 🚀 強化：預覽變更 (Plan) 並請求確認
    echo "   - 正在產生變更預覽 (Terraform Plan)..."
    terraform plan -out=tfplan
    
    echo ""
    echo "⚠️  以上是 [$INFAR_CLOUD_PROVIDER] 環境即將執行的基礎設施變更。"
    read -p "❓ 確定要執行這些變更嗎? (yes/no): " confirm_plan
    
    if [ "$confirm_plan" == "yes" ]; then
        echo "   - 正在套用變更 (Terraform Apply)..."
        terraform apply tfplan || exit 1
    else
        echo "❌ 使用者取消執行，腳本結束。"
        exit 0
    fi
    rm tfplan
    
    echo "   - 正在自動抓取雲端資源 Endpoint..."
    export DB_ENDPOINT=$(terraform output -raw db_endpoint)
    export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    # 自動切換 kubectl 到雲端叢集
    echo "   - 更新 K8s 叢集連線憑證..."
    # 確保安裝 GKE 插件 (針對 Mac 使用者)
    if [ "$INFAR_CLOUD_PROVIDER" == "gcp" ]; then
        gcloud components install gke-gcloud-auth-plugin --quiet > /dev/null 2>&1
        export USE_GKE_GCLOUD_AUTH_PLUGIN=True
    fi
    
    # 執行 Terraform 輸出的認證指令 (gcloud 或 aws eks)
    CONF_CMD=$(terraform output -raw configure_kubectl)
    echo "   - 執行: $CONF_CMD"
    eval "$CONF_CMD" > /dev/null

    # AWS 專屬：安裝 Load Balancer Controller (Fargate 必須)
    if [ "$INFAR_CLOUD_PROVIDER" == "aws" ]; then
        echo "   - [AWS] 正在安裝 AWS Load Balancer Controller..."
        LBC_ROLE_ARN=$(terraform output -raw aws_lbc_role_arn)
        helm repo add eks https://aws.github.io/eks-charts > /dev/null 2>&1
        helm repo update eks > /dev/null 2>&1
        helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$TF_VAR_cluster_name \
            --set serviceAccount.create=true \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$LBC_ROLE_ARN \
            --set region=$TF_VAR_region \
            --set vpcId=$(terraform output -raw vpc_id) \
            > /dev/null 2>&1
        echo "   ✅ AWS Load Balancer Controller 已啟動。"
    fi

    echo "----------------------------------------"
    echo "🌐 雲端連線資訊 (已成功抓取):"
    echo "   - Postgres: $DB_ENDPOINT"
    echo "   - Redis:    $REDIS_ENDPOINT"
    echo "----------------------------------------"
    
    popd > /dev/null
else
    echo "💻 0. [本機模式] 檢查系統依賴..."
    
    # 確保 kubectl context 切換至 minikube
    if kubectl config get-contexts minikube >/dev/null 2>&1; then
        echo "   - 切換 kubectl context 至 minikube..."
        kubectl config use-context minikube >/dev/null
    else
        echo "⚠️ 找不到 minikube context，請確認 minikube 已啟動！"
    fi

    minikube addons enable ingress > /dev/null
fi

# ==========================================
# 1. 建立與設定 Namespaces
# ==========================================
echo "1. 建立與設定 Namespaces..."
for ns in infra argocd observability linkerd-viz; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
    
    if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
        kubectl label namespace "$ns" linkerd.io/inject=enabled --overwrite > /dev/null
    else
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
        linkerd check --wait 5m
        linkerd viz install | kubectl apply -f -
    fi
else
    echo "2. 跳過 Service Mesh 安裝 (雲端環境模式)..."
fi

# ==========================================
# 3. 狀態同步 (IaC Apply)
# ==========================================
echo "3. 生成 K8s YAML 並執行同步 (cdk8s)..."
# 🚀 強化：清理舊的 YAML，避免「幽靈資源」殘留
rm -rf dist/*.yaml
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
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "4. 匯入 Grafana 戰情室..."
    ./import-dashboard.sh

    echo "5. 更新本機 /etc/hosts..."
    TARGET_IP="127.0.0.1"
    for domain in argocd.local grafana.local flink.local clickhouse.local elasticsearch.local; do
        if ! grep -q "$domain" /etc/hosts; then
            echo "🌐 為 $domain 更新 /etc/hosts (row password)..."
            echo "$TARGET_IP $domain" | sudo tee -a /etc/hosts > /dev/null
        fi
    done
else
    echo "4. 跳過戰情室匯入與 hosts 更新 (雲端環境配置)..."
fi

echo "✅ 基礎設施 [$INFAR_CLOUD_PROVIDER] 已全自動同步完成！"

echo "5. 🚀 建立本機資料庫與訊息隊列捷徑 (Port-Forward)..."
# 🚀 強化清理：殺掉所有佔用 5432, 6379, 8123, 9200 或 9092 的本機進程 (包含之前的舊通道)
pkill -f "port-forward" > /dev/null 2>&1
lsof -ti:5432 | xargs kill -9 > /dev/null 2>&1
lsof -ti:6379 | xargs kill -9 > /dev/null 2>&1
lsof -ti:8123 | xargs kill -9 > /dev/null 2>&1
lsof -ti:9200 | xargs kill -9 > /dev/null 2>&1
lsof -ti:9092 | xargs kill -9 > /dev/null 2>&1

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    kubectl port-forward svc/postgres 5432:5432 -n infra > /dev/null 2>&1 &
    kubectl port-forward svc/redis-master 6379:6379 -n infra > /dev/null 2>&1 &
    kubectl port-forward svc/kafka-service 9092:9092 -n infra > /dev/null 2>&1 &
    kubectl port-forward svc/clickhouse 8123:8123 -n infra > /dev/null 2>&1 &
    kubectl port-forward svc/elasticsearch-service 9200:9200 -n infra > /dev/null 2>&1 &
    echo "   ✅ PostgreSQL (5432)、Redis (6379)、Kafka (9092)、ClickHouse (8123) 與 Elasticsearch (9200) 已透過 Service 在背景連通。"
else
    echo "   - 正在等待雲端跳板機 (Jump Pod) 啟動..."
    kubectl wait --for=condition=available deployment/jump -n infra --timeout=60s > /dev/null 2>&1
    echo "   - 正在建立雲端跳板通道..."
    kubectl port-forward deployment/jump 5432:5432 -n infra > /dev/null 2>&1 &
    kubectl port-forward deployment/jump 6379:6379 -n infra > /dev/null 2>&1 &
    kubectl port-forward deployment/jump 8123:8123 -n infra > /dev/null 2>&1 &
    kubectl port-forward deployment/jump 9200:9200 -n infra > /dev/null 2>&1 &
    echo "   ✅ 雲端資料庫已透過 Jump Pod 在本機 (127.0.0.1) 背景連通。"
fi

if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "👉 ArgoCD URL:        http://argocd.local (請確保已執行 minikube tunnel)"
    echo "👉 Grafana URL:       http://grafana.local"
    echo "👉 Flink URL:         http://flink.local"
    echo "👉 ClickHouse URL:    http://clickhouse.local/play"
    echo "👉 Elasticsearch URL: http://elasticsearch.local"
else
    echo "👉 雲端環境部署完成！請等待 Cloud LoadBalancer 建立。"
    echo "🔍 取得 ArgoCD 外部網址: kubectl get svc argocd-server -n argocd"
fi
