#!/bin/bash
set -e

# ==============================================================
# Infar 微服務生產線 (v2.1 雙模板智慧驅動版)
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

echo "🔍 [0/6] 檢查環境與模板系統..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin
mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. Model
echo "📂 [1/6] 產生 Model 層..."
goctl model pg datasource -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 2. RPC (使用 rpc.tpl)
echo "📦 [2/6] 產生 RPC 服務 (模板驅動)..."
if [ ! -f "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" ]; then
    goctl rpc -o "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
    sed -i '' "s/package .*/package pb;/g" "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
fi
goctl rpc protoc "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" --home "$GOCTL_HOME"
rm -f "$BASE_DIR/rpc/pb.go" "$BASE_DIR/rpc/etc/pb.yaml"

# 3. API (使用 api.tpl)
echo "🌐 [3/6] 產生 API 網關 (模板驅動)..."
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

# 4. 自動化依賴注入 (DI)
echo "⚙️  [4/6] 執行依賴注入自動化..."
cat <<EOF > "$BASE_DIR/rpc/internal/svc/servicecontext.go"
package svc
import ( "infar/services/$SERVICE_NAME/model"; "infar/services/$SERVICE_NAME/rpc/internal/config"; "github.com/zeromicro/go-zero/core/stores/sqlx"; _ "github.com/lib/pq" )
type ServiceContext struct { Config config.Config; $MODEL_INTERFACE model.$MODEL_INTERFACE }
func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{ Config: c, $MODEL_INTERFACE: model.New$MODEL_INTERFACE(conn, c.CacheRedis) }
}
EOF
cat <<EOF > "$BASE_DIR/api/internal/svc/servicecontext.go"
package svc
import ( "infar/services/$SERVICE_NAME/api/internal/config"; "infar/services/$SERVICE_NAME/rpc/${SERVICE_NAME}client"; "github.com/zeromicro/go-zero/zrpc" )
type ServiceContext struct { Config config.Config; ${CAP_SERVICE_NAME}Rpc ${SERVICE_NAME}client.${CAP_SERVICE_NAME} }
func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{ Config: c, ${CAP_SERVICE_NAME}Rpc: ${SERVICE_NAME}client.New${CAP_SERVICE_NAME}(zrpc.MustNewClient(c.${CAP_SERVICE_NAME}Rpc)) }
}
EOF

# 5. 運維生成 (100% 模板驅動)
echo "🐳 [5/6] 產生 Docker 與 K8s 配置..."
rm -f Dockerfile 
RPC_MAIN=$(find "$BASE_DIR/rpc" -maxdepth 1 -name "*.go" | head -n 1)
goctl docker -go "$RPC_MAIN" -exe "$SERVICE_NAME-rpc" --port $RPC_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/rpc/docker/Dockerfile"
rm -f Dockerfile
API_MAIN=$(find "$BASE_DIR/api" -maxdepth 1 -name "*.go" | head -n 1)
goctl docker -go "$API_MAIN" -exe "$SERVICE_NAME-api" --port $API_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/api/docker/Dockerfile"

# 🚀 雙模版切換魔法
echo "   👉 切換 RPC 模板..."
cp "$GOCTL_HOME/kube/rpc.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"

echo "   👉 切換 API 模板..."
cp "$GOCTL_HOME/kube/api.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"

# 6. 最後同步
echo "⚙️  [6/6] 配置同步與依賴整理..."
cat <<EOF > "$BASE_DIR/rpc/etc/$SERVICE_NAME.yaml"
Name: $SERVICE_NAME.rpc
ListenOn: 0.0.0.0:$RPC_PORT
DataSource: host=127.0.0.1 port=5432 user=infar_admin password=InfarDbPass123 dbname=infar_db sslmode=disable
CacheRedis: [ { Host: 127.0.0.1:6379, Pass: InfarDbPass123, Type: node } ]
EOF
cat <<EOF > "$BASE_DIR/api/etc/$SERVICE_NAME-api.yaml"
Name: $SERVICE_NAME-api
Host: 0.0.0.0
Port: $API_PORT
Auth: { AccessSecret: infar-secret-2026, AccessExpire: 86400 }
${CAP_SERVICE_NAME}Rpc: { Endpoints: [ 127.0.0.1:$RPC_PORT ] }
EOF

(cd "$ROOT_DIR" && go mod tidy)
echo "========================================="
echo "🎉 Infar 智慧雙模生產線 v2.1 完成！"
echo "✅ 100% 透過 .tpl 模板產出，符合 GitOps 規範。"
echo "========================================="
