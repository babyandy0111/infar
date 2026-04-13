#!/bin/bash

# ==========================================
# Infar 基礎設施多環境清理腳本
# ==========================================
cd "$(dirname "$0")" || exit 1

# 預設環境為 local，支援 aws, gcp
INFAR_CLOUD_PROVIDER=${1:-local}

echo "🧹 開始清理 [$INFAR_CLOUD_PROVIDER] K8s 基礎設施環境..."

# 讀取 .env 檔案（為了獲取 Terraform 變數）
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    export TF_VAR_project_id=$GCP_PROJECT_ID
    export TF_VAR_region=$GCP_REGION
    export TF_VAR_db_user=$DB_USER
    export TF_VAR_db_password=$DB_PASSWORD
    export TF_VAR_db_name=$DB_NAME

    if [ "$INFAR_CLOUD_PROVIDER" == "aws" ]; then
        export TF_VAR_region=$AWS_REGION
        export TF_VAR_cluster_name=$AWS_CLUSTER_NAME
    fi
fi

# ==========================================
# 1. 移除 K8s 應用層資源 (無論哪種環境都需要)
# ==========================================
echo "1. 移除 K8s 內部的應用程式與監控堆疊..."

# 移除 Service Mesh (Linkerd)
export PATH=$PATH:$HOME/.linkerd2/bin
if command -v linkerd &> /dev/null; then
    linkerd viz uninstall 2>/dev/null | kubectl delete -f - 2>/dev/null
    linkerd uninstall 2>/dev/null | kubectl delete -f - 2>/dev/null
fi

# 依照編號反向刪除 cdk8s 資源
if [ -d "dist" ] && [ "$(ls -A dist)" ]; then
    # 反向排序確保依賴正確 (04 -> 01)
    ls -r dist/*.yaml | xargs -n 1 kubectl delete --ignore-not-found -f 2>/dev/null
fi

# 強制移除核心命名空間
kubectl delete namespace infra argocd observability linkerd linkerd-viz --ignore-not-found --grace-period=0 --force > /dev/null 2>&1
echo "✅ K8s 應用層資源已卸載。"

# ==========================================
# 2. 環境特定清理邏輯
# ==========================================
if [ "$INFAR_CLOUD_PROVIDER" == "local" ]; then
    echo "2. [Local 模式] 清理本機網路與資料..."
    
    # 防呆：確保在 local 模式下操作的是 minikube
    if kubectl config get-contexts minikube >/dev/null 2>&1; then
        kubectl config use-context minikube >/dev/null
    fi
    # 關閉所有資料庫與訊息隊列通道
    pkill -f "port-forward" > /dev/null 2>&1
    
    # 清理 /etc/hosts
    sudo sed -i '' '/argocd.local/d' /etc/hosts
    sudo sed -i '' '/grafana.local/d' /etc/hosts
    sudo sed -i '' '/flink.local/d' /etc/hosts
    sudo sed -i '' '/clickhouse.local/d' /etc/hosts
    echo "   ✅ /etc/hosts 已回復純淨。"

    # 詢問是否刪除 PVC
    echo ""
    read -p "❓ 是否要刪除本機持久化資料卷 (PVC)? [y/N]: " cleanup_pvc
    if [[ "$cleanup_pvc" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "   🚨 正在刪除本機 PVC..."
        kubectl delete pvc --all -A --ignore-not-found > /dev/null 2>&1
        echo "   ✅ 磁碟空間已完全釋放。"
    fi

else
    echo "2. [$INFAR_CLOUD_PROVIDER 模式] 執行雲端基礎設施銷毀 (Terraform)..."
    TF_DIR="../terraform/$INFAR_CLOUD_PROVIDER"
    
    if [ ! -d "$TF_DIR" ]; then
        echo "❌ 找不到對應的 Terraform 目錄: $TF_DIR"
    else
        echo "🚨 注意：這將會永久刪除雲端上的 VPC、叢集與資料庫！"
        read -p "⚠️ 確定要執行 terraform destroy 嗎? [y/N]: " confirm_destroy
        if [[ "$confirm_destroy" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            pushd "$TF_DIR" > /dev/null
            # 🚀 強化銷毀：帶入必要變數
            export TF_VAR_db_user=$DB_USER
            export TF_VAR_db_password=$DB_PASSWORD
            export TF_VAR_db_name=$DB_NAME
            terraform destroy -auto-approve
            popd > /dev/null
            echo "✅ 雲端基礎設施已成功銷毀。"
        else
            echo "ℹ️ 已跳過 Terraform 銷毀流程。"
        fi
    fi
fi

echo -e "\n✨ [$INFAR_CLOUD_PROVIDER] 環境清理完成！"
