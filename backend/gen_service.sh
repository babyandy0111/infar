#!/bin/bash
set -e

# ==============================================================
# Infar 微服務生產線 (v3.0 純淨腳手架版)
# 作用：自動建置目錄、產生模板代碼、配置運維檔。
# 注意：本腳本不再自動注入 DI，需由開發者手動完成以掌握架構。
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

echo "🔍 [0/4] 檢查環境依賴..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin
goctl env check --install --force > /dev/null 2>&1

mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. Model
echo "📂 [1/4] 產生 Model 層..."
DB_URL="postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable"
goctl model pg datasource -url "$DB_URL" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 2. RPC (模板驅動)
echo "📦 [2/4] 產生 RPC 服務..."
if [ ! -f "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" ]; then
    goctl rpc -o "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
    sed -i '' "s/package .*/package pb;/g" "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
fi
goctl rpc protoc "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" --home "$GOCTL_HOME"
rm -f "$BASE_DIR/rpc/pb.go" "$BASE_DIR/rpc/etc/pb.yaml"

# 3. API (模板驅動)
echo "🌐 [3/4] 產生 API 網關..."
if [ ! -f "$BASE_DIR/api/desc/$SERVICE_NAME.api" ]; then
    goctl api template -o "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/title: \/\/ TODO.*/title: "Infar Service API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/desc: \/\/ TODO.*/desc: "Microservice API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
fi

# 🚨 修正：只有在檔案不存在時才由 goctl 產生，防止覆蓋手動注入的代碼
goctl api go -api "$BASE_DIR/api/desc/$SERVICE_NAME.api" -dir "$BASE_DIR/api" --home "$GOCTL_HOME"

# 4. 運維生成 (模板驅動)
echo "🐳 [4/4] 更新 Docker 與 K8s 配置..."
# 只有在 Dockerfile 不存在時才產生
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

# 只有在 K8s YAML 不存在時才產生
if [ ! -f "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml" ]; then
    cp "$GOCTL_HOME/kube/rpc.tpl" "$GOCTL_HOME/kube/deployment.tpl"
    goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"
fi

if [ ! -f "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml" ]; then
    cp "$GOCTL_HOME/kube/api.tpl" "$GOCTL_HOME/kube/deployment.tpl"
    goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"
fi

echo "========================================="
echo "🎉 服務 [$SERVICE_NAME] 腳手架建置完成！"
echo "========================================="
echo "🚨 請務必按照 README.md 的 [3.2.1 依賴注入指南] 完成以下動作："
echo "   1. 在 rpc/internal/config/config.go 加入 DataSource/CacheRedis"
echo "   2. 在 rpc/internal/svc/servicecontext.go 注入 Model"
echo "   3. 在 api/internal/config/config.go 加入 Auth/${CAP_SERVICE_NAME}Rpc"
echo "   4. 在 api/internal/svc/servicecontext.go 注入 RPC Client"
echo "   5. 在 api/$SERVICE_NAME.go 加入 Swagger docs 引用"
echo "   6. 執行 go mod tidy"
echo "========================================="
