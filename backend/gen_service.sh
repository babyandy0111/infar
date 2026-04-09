#!/bin/bash
set -e

# ==============================================================
# Infar 微服務生產線 (v6.0 模板 Flag 替換版)
# ==============================================================

SERVICE_NAME=$1
TABLE_NAME=$2
API_PORT=$3
RPC_PORT=$4
DOCKER_USER="babyandy0111"

if [ -z "$SERVICE_NAME" ] || [ -z "$TABLE_NAME" ]; then
    echo "❌ 錯誤: 請提供服務名稱與資料表名稱"
    exit 1
fi

API_PORT=${API_PORT:-8889}
RPC_PORT=${RPC_PORT:-9091}
ROOT_DIR=$(pwd)
BASE_DIR="$ROOT_DIR/services/$SERVICE_NAME"
GOCTL_HOME="$ROOT_DIR/.goctl"

CAP_SERVICE_NAME=$(echo "$SERVICE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
CAP_TABLE_NAME=$(echo "$TABLE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
MODEL_INTERFACE="${CAP_TABLE_NAME}Model"

echo "🔍 [0/4] 檢查環境與精準清場..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin

# 清理舊檔案，確保重新產生
rm -rf "$BASE_DIR/rpc/pb"/*.go
rm -rf "$BASE_DIR/rpc/${SERVICE_NAME}client"
rm -rf "$BASE_DIR/api/internal/types"/*.go
mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. Model
echo "📂 [1/4] 產生 Model 層 ($TABLE_NAME -> $MODEL_INTERFACE)..."
goctl model pg datasource -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 2. RPC
echo "📦 [2/4] 產生 RPC 層..."
PROTO_FILE="$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
if [ ! -f "$PROTO_FILE" ]; then
    # 使用標準規格模板
    cp "$GOCTL_HOME/rpc_standard.tpl" "$PROTO_FILE"
    sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" "$PROTO_FILE"
fi
goctl rpc protoc "$PROTO_FILE" --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" -c --home "$GOCTL_HOME"
rm -f "$BASE_DIR/rpc/pb.go" "$BASE_DIR/rpc/etc/pb.yaml"

# 💉 替換 RPC 內核 Flag
RPC_SVC_FILE="$BASE_DIR/rpc/internal/svc/servicecontext.go"
sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" "$RPC_SVC_FILE"
sed -i '' "s/INFAR_MODEL_INTERFACE/$MODEL_INTERFACE/g" "$RPC_SVC_FILE"

# 3. API
echo "🌐 [3/4] 產生 API 層..."
API_DESC="$BASE_DIR/api/desc/$SERVICE_NAME.api"
if [ ! -f "$API_DESC" ]; then
    # 使用標準規格模板
    cp "$GOCTL_HOME/api_standard.tpl" "$API_DESC"
    sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" "$API_DESC"
    sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" "$API_DESC"
    LOWER_SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
    sed -i '' "s/INFAR_LOWER_SERVICE_NAME/$LOWER_SERVICE_NAME/g" "$API_DESC"
fi
# 移除 main 檔案以便 goctl 重新根據模板產生
rm -f "$BASE_DIR/api/$SERVICE_NAME.go"
goctl api go -api "$API_DESC" -dir "$BASE_DIR/api" --home "$GOCTL_HOME"

# 🧠 動態尋找真正的 RPC Client 資料夾名稱 (可能是 order 或 orderclient)
# 它會是 rpc/ 目錄下除了 pb, etc, internal, docker, k8s 以外的唯一一個目錄
CLIENT_DIR_NAME=$(find "$BASE_DIR/rpc" -mindepth 1 -maxdepth 1 -type d | grep -vE '/(pb|etc|internal|docker|k8s)$' | xargs basename)

# 💉 替換 API 內核 Flag
API_CONFIG_FILE="$BASE_DIR/api/internal/config/config.go"
API_SVC_FILE="$BASE_DIR/api/internal/svc/servicecontext.go"

# 修正 Config 取代
sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCONF/${CAP_SERVICE_NAME}Rpc/g" "$API_CONFIG_FILE"

# 修正 Context 取代 (由長到短，避免子字串覆蓋)
sed -i '' "s/INFAR_CLIENT_DIR_NAME/${CLIENT_DIR_NAME}/g" "$API_SVC_FILE" # 使用動態解析出來的資料夾名
sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCLIENT/${CAP_SERVICE_NAME}Rpc/g" "$API_SVC_FILE"
sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCONF/${CAP_SERVICE_NAME}Rpc/g" "$API_SVC_FILE"
sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" "$API_SVC_FILE"
sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" "$API_SVC_FILE"

# 🧠 注入 Logic 層與 Handler 層的實體名稱 (Model & Client & Swagger)
# 注入 Logic
find "$BASE_DIR/api/internal/logic" -name "*.go" -type f -exec sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCLIENT/${CAP_SERVICE_NAME}Rpc/g" {} +
find "$BASE_DIR/api/internal/logic" -name "*.go" -type f -exec sed -i '' "s/INFAR_CLIENT_DIR_NAME/${CLIENT_DIR_NAME}/g" {} +
find "$BASE_DIR/api/internal/logic" -name "*.go" -type f -exec sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" {} +

# 注入 Handler (Swagger Annotations)
find "$BASE_DIR/api/internal/handler" -name "*.go" -type f -exec sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" {} +
find "$BASE_DIR/api/internal/handler" -name "*.go" -type f -exec sed -i '' "s/INFAR_LOWER_SERVICE_NAME/$LOWER_SERVICE_NAME/g" {} +
find "$BASE_DIR/api/internal/handler" -name "*.go" -type f -exec sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" {} +

# RPC Logic 處理 (注入 Model)
# CAP_TABLE_NAME 通常對應 Struct 名稱 (例如 Orders)
find "$BASE_DIR/rpc/internal/logic" -name "*.go" -type f -exec sed -i '' "s/INFAR_MODEL_INTERFACE/${MODEL_INTERFACE}/g" {} +
find "$BASE_DIR/rpc/internal/logic" -name "*.go" -type f -exec sed -i '' "s/INFAR_MODEL_STRUCT/${CAP_TABLE_NAME}/g" {} +

# 📚 Swagger 初始化
(cd "$BASE_DIR/api" && swag init -q -g $SERVICE_NAME.go)
# 注入 Swagger 導引
sed -i '' "/import (/a\\
	_ \"infar/services/$SERVICE_NAME/api/docs\"
" "$BASE_DIR/api/$SERVICE_NAME.go"

# 4. 運維與配置
echo "🐳 [4/4] 更新運維配置與 YAML..."
if [ ! -f "$BASE_DIR/rpc/docker/Dockerfile" ]; then
    rm -f Dockerfile
    RPC_MAIN=$(find "$BASE_DIR/rpc" -maxdepth 1 -name "*.go" | head -n 1)
    goctl docker -go "$RPC_MAIN" -exe "$SERVICE_NAME-rpc" --port $RPC_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/rpc/docker/Dockerfile"
fi
if [ ! -f "$BASE_DIR/api/docker/Dockerfile" ]; then
    rm -f Dockerfile
    API_MAIN=$(find "$BASE_DIR/api" -maxdepth 1 -name "*.go" | head -n 1)
    goctl docker -go "$API_MAIN" -exe "$SERVICE_NAME-api" --port $API_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/api/docker/Dockerfile"
fi
cp "$GOCTL_HOME/kube/rpc.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"
cp "$GOCTL_HOME/kube/api.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"

# ⚙️ 設定檔佔位符替換
RPC_YAML=$(find "$BASE_DIR/rpc/etc" -maxdepth 1 -name "*.yaml" | head -n 1)
[[ -n "$RPC_YAML" ]] && sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$RPC_YAML"
API_YAML=$(find "$BASE_DIR/api/etc" -maxdepth 1 -name "*.yaml" | head -n 1)
if [ -n "$API_YAML" ]; then
    sed -i '' "s/INFAR_RPC_NAME_PLACEHOLDER/${CAP_SERVICE_NAME}Rpc/g" "$API_YAML"
    sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$API_YAML"
    sed -i '' "s/INFAR_API_PORT_PLACEHOLDER/$API_PORT/g" "$API_YAML"
fi

(cd "$ROOT_DIR" && go mod tidy && go fmt ./...)

echo "========================================="
echo "🎉 Infar 服務工廠 v6.0 (純淨 Flag 驅動) 完成！"
echo "✅ 100% 透過 .tpl 模板產出，腳本僅負責替換 Flag。"
echo "========================================="
