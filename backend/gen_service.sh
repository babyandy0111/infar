#!/bin/bash
set -e

# ==============================================================
# Infar 微服務生產線 (v3.0 模板精準驅動版)
# 作用：全自動建置目錄、套用模板、依賴注入、配置運維檔。
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

# 命名處理
CAP_SERVICE_NAME=$(echo "$SERVICE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
CAP_TABLE_NAME=$(echo "$TABLE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
MODEL_INTERFACE="${CAP_TABLE_NAME}Model"

echo "🔍 [0/6] 檢查環境與精準清場..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin

# 🚨 精準清場：刪除「絕對由工具產生」的目錄/檔案
rm -rf "$BASE_DIR/rpc/pb"/*.go
rm -rf "$BASE_DIR/rpc/${SERVICE_NAME}client"
rm -rf "$BASE_DIR/rpc/$SERVICE_NAME" 
rm -rf "$BASE_DIR/api/internal/types"/*.go
rm -f "$BASE_DIR/api/internal/handler/routes.go"
mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. Model 層
echo "📂 [1/6] 產生 Model 層..."
DB_URL="postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable"
goctl model pg datasource -url "$DB_URL" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 2. RPC 層 (模板驅動 + 精準注入)
echo "📦 [2/6] 產生 RPC 服務 (依賴 .goctl 模板)..."
if [ ! -f "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" ]; then
    goctl rpc -o "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
    sed -i '' "s/package .*/package pb;/g" "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
fi
# 🚨 加入 -c 參數，確保 goctl 強制產出客戶端代碼 (預設名稱為 service_name+client)
goctl rpc protoc "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" -c --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" --home "$GOCTL_HOME"
rm -f "$BASE_DIR/rpc/pb.go"
if [ -f "$BASE_DIR/rpc/etc/pb.yaml" ]; then
    mv "$BASE_DIR/rpc/etc/pb.yaml" "$BASE_DIR/rpc/etc/$SERVICE_NAME.yaml"
fi

# 💉 執行 RPC DI 手術
# 將 Placeholder 替換為實際代碼 (注意換行符號的處理)
if grep -q "INFAR_RPC_CONFIG_FIELDS" "$BASE_DIR/rpc/internal/config/config.go"; then
    sed -i '' "s/\/\/ INFAR_RPC_CONFIG_IMPORTS/\"github.com\/zeromicro\/go-zero\/core\/stores\/cache\"/g" "$BASE_DIR/rpc/internal/config/config.go"
    sed -i '' "s/\/\/ INFAR_RPC_CONFIG_FIELDS/DataSource string\n\tCacheRedis cache.CacheConf/g" "$BASE_DIR/rpc/internal/config/config.go"
fi

if grep -q "INFAR_RPC_SVC_FIELDS" "$BASE_DIR/rpc/internal/svc/servicecontext.go"; then
    sed -i '' "s/\/\/ INFAR_RPC_SVC_IMPORTS/\"infar\/services\/$SERVICE_NAME\/model\"\n\t\"github.com\/zeromicro\/go-zero\/core\/stores\/sqlx\"\n\t_ \"github.com\/lib\/pq\"/g" "$BASE_DIR/rpc/internal/svc/servicecontext.go"
    sed -i '' "s/\/\/ INFAR_RPC_SVC_FIELDS/$MODEL_INTERFACE model.$MODEL_INTERFACE/g" "$BASE_DIR/rpc/internal/svc/servicecontext.go"
    sed -i '' "s/\/\/ INFAR_RPC_SVC_PRE_INJECT/conn := sqlx.NewSqlConn(\"postgres\", c.DataSource)/g" "$BASE_DIR/rpc/internal/svc/servicecontext.go"
    sed -i '' "s/\/\/ INFAR_RPC_SVC_INJECT/$MODEL_INTERFACE: model.New$MODEL_INTERFACE(conn, c.CacheRedis),/g" "$BASE_DIR/rpc/internal/svc/servicecontext.go"
fi

# 3. API 層 (模板驅動 + 精準注入)
echo "🌐 [3/6] 產生 API 網關 (依賴 .goctl 模板)..."
if [ ! -f "$BASE_DIR/api/desc/$SERVICE_NAME.api" ]; then
    goctl api template -o "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/title: \/\/ TODO.*/title: "Infar Service API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/desc: \/\/ TODO.*/desc: "Microservice API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
fi
rm -f "$BASE_DIR/api/$SERVICE_NAME.go"
goctl api go -api "$BASE_DIR/api/desc/$SERVICE_NAME.api" -dir "$BASE_DIR/api" --home "$GOCTL_HOME"

# 💉 修正 Swagger docs 引入
sed -i '' "/import (/a\\
	_ \"infar/services/$SERVICE_NAME/api/docs\"
" "$BASE_DIR/api/$SERVICE_NAME.go"

# 📚 自動補齊 Swagger Docs
echo "📚 [3.5/6] 產生初始 Swagger Docs..."
(cd "$BASE_DIR/api" && swag init -q -g $SERVICE_NAME.go)

# 💉 執行 API DI 手術
if grep -q "INFAR_API_CONFIG_FIELDS" "$BASE_DIR/api/internal/config/config.go"; then
    sed -i '' "s/\/\/ INFAR_API_CONFIG_IMPORTS/\"github.com\/zeromicro\/go-zero\/zrpc\"/g" "$BASE_DIR/api/internal/config/config.go"
    sed -i '' "s/\/\/ INFAR_API_CONFIG_FIELDS/Auth struct { AccessSecret string; AccessExpire int64 }\n\t${CAP_SERVICE_NAME}Rpc zrpc.RpcClientConf/g" "$BASE_DIR/api/internal/config/config.go"
fi

# 修正不穩定的 context.tpl 替換
if grep -q "INFAR_API_SVC_FIELDS" "$BASE_DIR/api/internal/svc/servicecontext.go"; then
    # 注意換行與縮排，確保 Go 語法正確
    sed -i '' "s/\/\/ INFAR_API_SVC_IMPORTS/\"infar\/services\/$SERVICE_NAME\/api\/internal\/config\"\n\t\"infar\/services\/$SERVICE_NAME\/rpc\/${SERVICE_NAME}client\"\n\t\"github.com\/zeromicro\/go-zero\/zrpc\"/g" "$BASE_DIR/api/internal/svc/servicecontext.go"
    sed -i '' "s/\/\/ INFAR_API_SVC_FIELDS/Config config.Config\n\t${CAP_SERVICE_NAME}Rpc ${SERVICE_NAME}client.${CAP_SERVICE_NAME}/g" "$BASE_DIR/api/internal/svc/servicecontext.go"
    sed -i '' "s/\/\/ INFAR_API_SVC_INJECT/Config: c,\n\t\t${CAP_SERVICE_NAME}Rpc: ${SERVICE_NAME}client.New${CAP_SERVICE_NAME}(zrpc.MustNewClient(c.${CAP_SERVICE_NAME}Rpc)),/g" "$BASE_DIR/api/internal/svc/servicecontext.go"
fi

# 4. 運維與配置 (純淨生成)
echo "🐳 [4/6] 更新 Docker 與 K8s 配置..."
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
if [ ! -f "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml" ]; then
    cp "$GOCTL_HOME/kube/rpc.tpl" "$GOCTL_HOME/kube/deployment.tpl"
    goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"
fi
if [ ! -f "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml" ]; then
    cp "$GOCTL_HOME/kube/api.tpl" "$GOCTL_HOME/kube/deployment.tpl"
    goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"
fi

# YAML 模板變數替換
echo "⚙️  [5/6] 同步 YAML 配置檔 (模板驅動)..."
sed -i '' "s/INFAR_RPC_NAME_PLACEHOLDER/${CAP_SERVICE_NAME}Rpc/g" "$BASE_DIR/api/etc/$SERVICE_NAME-api.yaml"
sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$BASE_DIR/api/etc/$SERVICE_NAME-api.yaml"
sed -i '' "s/INFAR_API_PORT_PLACEHOLDER/$API_PORT/g" "$BASE_DIR/api/etc/$SERVICE_NAME-api.yaml"
# 注意 RPC 的設定檔名通常會預設為 service_name.yaml
sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$BASE_DIR/rpc/etc/$SERVICE_NAME.yaml"
sed -i '' "s/Name: pb.rpc/Name: $SERVICE_NAME.rpc/g" "$BASE_DIR/rpc/etc/$SERVICE_NAME.yaml"

echo "🧹 [6/6] 整理套件依賴..."
(cd "$ROOT_DIR" && go mod tidy)

echo "========================================="
echo "🎉 Infar 服務工廠 v3.1 (全模板版) 正式交付！"
echo "✅ 已將 YAML 設定檔徹底模板化，移除所有硬編碼。"
echo "========================================="
