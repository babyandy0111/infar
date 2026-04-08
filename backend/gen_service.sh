#!/bin/bash
set -e

# ==============================================================
# Infar 微服務生產線 (v2.0 終極修復版)
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

echo "🔍 [0/6] 檢查環境與模板..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin
mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. Model
goctl model pg datasource -url "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 2. RPC
if [ ! -f "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" ]; then
    goctl rpc -o "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
    sed -i '' "s/package .*/package pb;/g" "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
fi
goctl rpc protoc "$BASE_DIR/rpc/pb/$SERVICE_NAME.proto" --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" --home "$GOCTL_HOME"
rm -f "$BASE_DIR/rpc/pb.go" "$BASE_DIR/rpc/etc/pb.yaml"

# 3. API
if [ ! -f "$BASE_DIR/api/desc/$SERVICE_NAME.api" ]; then
    goctl api template -o "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/title: \/\/ TODO.*/title: "Infar Service API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
    sed -i '' 's/desc: \/\/ TODO.*/desc: "Microservice API"/g' "$BASE_DIR/api/desc/$SERVICE_NAME.api"
fi
rm -f "$BASE_DIR/api/$SERVICE_NAME.go"
goctl api go -api "$BASE_DIR/api/desc/$SERVICE_NAME.api" -dir "$BASE_DIR/api" --home "$GOCTL_HOME"
sed -i '' "/import (/a\\
	_ \"infar/services/$SERVICE_NAME/api/docs\"
" "$BASE_DIR/api/$SERVICE_NAME.go"

# 4. 自動化注入 (補齊 Config 結構與 SVC)
echo "⚙️  [4/6] 注入 Config 與依賴..."

# RPC Config & SVC
cat <<EOF > "$BASE_DIR/rpc/internal/config/config.go"
package config
import ("github.com/zeromicro/go-zero/core/stores/cache"; "github.com/zeromicro/go-zero/zrpc")
type Config struct { zrpc.RpcServerConf; DataSource string; CacheRedis cache.CacheConf }
EOF

cat <<EOF > "$BASE_DIR/rpc/internal/svc/servicecontext.go"
package svc
import (
	"infar/services/$SERVICE_NAME/model"
	"infar/services/$SERVICE_NAME/rpc/internal/config"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
	_ "github.com/lib/pq"
)
type ServiceContext struct {
	Config config.Config
	$MODEL_INTERFACE model.$MODEL_INTERFACE
}
func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{
		Config: c,
		$MODEL_INTERFACE: model.New$MODEL_INTERFACE(conn, c.CacheRedis),
	}
}
EOF

# API Config & SVC
cat <<EOF > "$BASE_DIR/api/internal/config/config.go"
package config
import ("github.com/zeromicro/go-zero/rest"; "github.com/zeromicro/go-zero/zrpc")
type Config struct {
	rest.RestConf
	Auth struct { AccessSecret string; AccessExpire int64 }
	${CAP_SERVICE_NAME}Rpc zrpc.RpcClientConf
}
EOF

cat <<EOF > "$BASE_DIR/api/internal/svc/servicecontext.go"
package svc
import (
	"infar/services/$SERVICE_NAME/api/internal/config"
	"infar/services/$SERVICE_NAME/rpc/${SERVICE_NAME}client"
	"github.com/zeromicro/go-zero/zrpc"
)
type ServiceContext struct {
	Config config.Config
	${CAP_SERVICE_NAME}Rpc ${SERVICE_NAME}client.${CAP_SERVICE_NAME}
}
func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config: c,
		${CAP_SERVICE_NAME}Rpc: ${SERVICE_NAME}client.New${CAP_SERVICE_NAME}(zrpc.MustNewClient(c.${CAP_SERVICE_NAME}Rpc)),
	}
}
EOF

# 5. 運維與配置 (Dockerfile & K8s)
echo "🐳 [5/6] 產生運維配置..."
rm -f Dockerfile
RPC_MAIN_FILE=$(find "$BASE_DIR/rpc" -maxdepth 1 -name "*.go" | head -n 1)
goctl docker -go "$RPC_MAIN_FILE" -exe "$SERVICE_NAME-rpc" --port $RPC_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/rpc/docker/Dockerfile"
rm -f Dockerfile
API_MAIN_FILE=$(find "$BASE_DIR/api" -maxdepth 1 -name "*.go" | head -n 1)
goctl docker -go "$API_MAIN_FILE" -exe "$SERVICE_NAME-api" --port $API_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/api/docker/Dockerfile"
goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"
goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"

# 6. 配置最終同步 (YAML)
echo "⚙️  [6/6] 強制同步 YAML 配置檔..."
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
echo "🎉 Infar 服務工廠 v2.0 正式交付！"
echo "========================================="
