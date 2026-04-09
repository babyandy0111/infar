#!/bin/bash
set -e

# ==============================================================
# Infar 微服務智能生產線 v8.0 (全面統一命名標準版)
# ==============================================================
# 新標準：API 統一叫 *-api.yaml，RPC 統一叫 *-rpc.yaml

SERVICE_NAME=$1
TABLE_NAME=$2
PORT_ID=$3
DOCKER_USER="babyandy0111"
DB_URL="postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable"

if [ -z "$SERVICE_NAME" ] || [ -z "$TABLE_NAME" ] || [ -z "$PORT_ID" ]; then
    echo "❌ 錯誤: 使用方式 -> ./gen_service.sh [服務名] [資料表名] [Port後三碼]"
    echo "範例: ./gen_service.sh order orders 889"
    exit 1
fi

API_PORT="8$PORT_ID"
RPC_PORT="9$PORT_ID"
ROOT_DIR=$(pwd)
BASE_DIR="$ROOT_DIR/services/$SERVICE_NAME"
GOCTL_HOME="$ROOT_DIR/.goctl"
CAP_SERVICE_NAME=$(echo "$SERVICE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
CAP_TABLE_NAME=$(echo "$TABLE_NAME" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
MODEL_INTERFACE="${CAP_TABLE_NAME}Model"

echo "🔍 [0/5] 環境檢查與精準清場 (Port: API $API_PORT / RPC $RPC_PORT)..."
export PATH=$PATH:$(go env GOPATH)/bin:/usr/local/bin
mkdir -p $BASE_DIR/{api/desc,api/docker,api/k8s,rpc/pb,rpc/docker,rpc/k8s,model}

# 1. 資料庫欄位解析
echo "🧬 [1/5] 從資料庫提取欄位資訊..."
COLUMNS=$(psql "$DB_URL" -t -A -F"," -c "SELECT column_name, udt_name, ordinal_position FROM information_schema.columns WHERE table_name = '$TABLE_NAME' AND table_schema = 'public' ORDER BY ordinal_position;" || echo "")

PROTO_FIELDS_FILE=$(mktemp /tmp/proto_fields.XXXXXX)
API_FIELDS_FILE=$(mktemp /tmp/api_fields.XXXXXX)

if [ -z "$COLUMNS" ]; then
    echo "    string data = 2;" > "$PROTO_FIELDS_FILE"
    echo "    Data string \`json:\"data\"\`" > "$API_FIELDS_FILE"
else
    > "$PROTO_FIELDS_FILE"
    > "$API_FIELDS_FILE"
    while IFS=',' read -r col_name udt_type ordinal; do
        [[ "$col_name" == "id" || "$col_name" == "created_at" || "$col_name" == "updated_at" ]] && continue
        case $udt_type in
            int8|bigint) pt="int64"; gt="int64" ;;
            int4|integer) pt="int32"; gt="int32" ;;
            bool|boolean) pt="bool"; gt="bool" ;;
            float8|numeric|double) pt="double"; gt="float64" ;;
            *) pt="string"; gt="string" ;;
        esac
        camel=$(echo "$col_name" | awk -F_ '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1))substr($i,2)}}1' OFS="")
        echo "    $pt $col_name = $ordinal;" >> "$PROTO_FIELDS_FILE"
        echo "    $camel $gt \`json:\"$col_name\"\`" >> "$API_FIELDS_FILE"
    done <<< "$COLUMNS"
fi

# 2. Model 生成
echo "📂 [2/5] 產生 Model 層..."
goctl model pg datasource -url "$DB_URL" -t "$TABLE_NAME" -dir "$BASE_DIR/model" -c

# 3. RPC 層生成
echo "📦 [3/5] 產出 RPC 定義與代碼..."
PROTO_FILE="$BASE_DIR/rpc/pb/$SERVICE_NAME.proto"
cp "$GOCTL_HOME/rpc_standard.tpl" "$PROTO_FILE"
sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" "$PROTO_FILE"
PROTO_CONTENT=$(cat "$PROTO_FIELDS_FILE")
perl -i -0777 -pe "s/(message CreateReq \{)(.*?)(\})/\$1\n$PROTO_CONTENT\n\$3/s" "$PROTO_FILE"
perl -i -0777 -pe "s/(message UpdateReq \{)(.*?)(\})/\$1\n    int64 id = 1;\n$PROTO_CONTENT\n\$3/s" "$PROTO_FILE"
goctl rpc protoc "$PROTO_FILE" --proto_path="$BASE_DIR/rpc/pb" --go_out="$BASE_DIR/rpc" --go-grpc_out="$BASE_DIR/rpc" --zrpc_out="$BASE_DIR/rpc" -c --home "$GOCTL_HOME"

# 🌟 新標準：統一 RPC 設定檔名與啟動檔名
if [ -f "$BASE_DIR/rpc/pb.go" ]; then
    mv "$BASE_DIR/rpc/pb.go" "$BASE_DIR/rpc/$SERVICE_NAME.go"
fi

if [ -f "$BASE_DIR/rpc/etc/pb.yaml" ]; then
    mv "$BASE_DIR/rpc/etc/pb.yaml" "$BASE_DIR/rpc/etc/$SERVICE_NAME-rpc.yaml"
elif [ -f "$BASE_DIR/rpc/etc/${SERVICE_NAME}.yaml" ]; then
    mv "$BASE_DIR/rpc/etc/${SERVICE_NAME}.yaml" "$BASE_DIR/rpc/etc/$SERVICE_NAME-rpc.yaml"
else
    # 確保設定檔一定存在
    cp "$GOCTL_HOME/rpc/etc.tpl" "$BASE_DIR/rpc/etc/$SERVICE_NAME-rpc.yaml"
fi

# 🌟 核心修復：強制把 order.go 裡面的設定檔路徑寫死為 *-rpc.yaml，保證絕對不會出錯
sed -i '' "s/var configFile = flag.String(\"f\", \".*\", \"the config file\")/var configFile = flag.String(\"f\", \"etc\/$SERVICE_NAME-rpc.yaml\", \"the config file\")/g" "$BASE_DIR/rpc/$SERVICE_NAME.go"

# 確保 order-rpc.yaml 裡面的 Name 屬性正確
sed -i '' "s/Name: .*/Name: $SERVICE_NAME.rpc/g" "$BASE_DIR/rpc/etc/$SERVICE_NAME-rpc.yaml"


# 4. API 層生成
echo "🌐 [4/5] 產出 API 定義與代碼..."
API_DESC="$BASE_DIR/api/desc/$SERVICE_NAME.api"
cp "$GOCTL_HOME/api_standard.tpl" "$API_DESC"
sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" "$API_DESC"
sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" "$API_DESC"
LOWER_SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
sed -i '' "s/INFAR_LOWER_SERVICE_NAME/$LOWER_SERVICE_NAME/g" "$API_DESC"
API_CONTENT=$(cat "$API_FIELDS_FILE")
perl -i -0777 -pe "s/(type CreateReq \{)(.*?)(\})/\$1\n$API_CONTENT\n\$3/s" "$API_DESC"
perl -i -0777 -pe "s/(type UpdateReq \{)(.*?)(\})/\$1\n    Id int64 \`json:\"id\"\`\n$API_CONTENT\n\$3/s" "$API_DESC"
rm -f "$BASE_DIR/api/$SERVICE_NAME.go"
goctl api go -api "$API_DESC" -dir "$BASE_DIR/api" --home "$GOCTL_HOME"

# 確保 API 的設定檔命名為 service-api.yaml
if [ -f "$BASE_DIR/api/etc/${SERVICE_NAME}.yaml" ]; then
    mv "$BASE_DIR/api/etc/${SERVICE_NAME}.yaml" "$BASE_DIR/api/etc/$SERVICE_NAME-api.yaml"
fi
sed -i '' "s/var configFile = flag.String(\"f\", \".*\", \"the config file\")/var configFile = flag.String(\"f\", \"etc\/$SERVICE_NAME-api.yaml\", \"the config file\")/g" "$BASE_DIR/api/$SERVICE_NAME.go"

# 5. Infar 內核注入
echo "💉 [5/5] 執行 Infar 內核注入與運維產出..."
CLIENT_DIR_NAME=$(find "$BASE_DIR/rpc" -mindepth 1 -maxdepth 1 -type d | grep -vE '/(pb|etc|internal|docker|k8s)$' | xargs basename)

# 執行全域標籤替換
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCONF/${CAP_SERVICE_NAME}Rpc/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_CAP_SERVICE_NAME_RPCCLIENT/${CAP_SERVICE_NAME}Rpc/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_CLIENT_DIR_NAME/${CLIENT_DIR_NAME}/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_CAP_SERVICE_NAME/$CAP_SERVICE_NAME/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_SERVICE_NAME/$SERVICE_NAME/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_MODEL_INTERFACE/${MODEL_INTERFACE}/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_MODEL_STRUCT/${CAP_TABLE_NAME}/g" {} +
find "$BASE_DIR" -name "*.go" -type f -exec sed -i '' "s/INFAR_LOWER_SERVICE_NAME/$LOWER_SERVICE_NAME/g" {} +

(cd "$BASE_DIR/api" && swag init -q -g $SERVICE_NAME.go || true)
sed -i '' "/import (/a\\
	_ \"infar/services/$SERVICE_NAME/api/docs\"
" "$BASE_DIR/api/$SERVICE_NAME.go"

# Dockerfile 產生 (注意使用相對路徑)
API_MAIN=$(find "$BASE_DIR/api" -maxdepth 1 -name "*.go" | head -n 1 | sed "s|$ROOT_DIR/||")
RPC_MAIN=$(find "$BASE_DIR/rpc" -maxdepth 1 -name "*.go" | head -n 1 | sed "s|$ROOT_DIR/||")
goctl docker -go "$API_MAIN" -exe "$SERVICE_NAME-api" --port $API_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/api/docker/Dockerfile"
goctl docker -go "$RPC_MAIN" -exe "$SERVICE_NAME-rpc" --port $RPC_PORT --home "$GOCTL_HOME" && mv Dockerfile "$BASE_DIR/rpc/docker/Dockerfile"

# K8s YAML 產生 (動態切換模板)
cp "$GOCTL_HOME/kube/api.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-api" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-api:v1" -port "$API_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/api/k8s/$SERVICE_NAME-api.yaml"
# RPC 部署檔
cp "$GOCTL_HOME/kube/rpc.tpl" "$GOCTL_HOME/kube/deployment.tpl"
goctl kube deploy -name "$SERVICE_NAME-rpc" -namespace app -image "$DOCKER_USER/infar-$SERVICE_NAME-rpc:v1" -port "$RPC_PORT" --home "$GOCTL_HOME" -o "$BASE_DIR/rpc/k8s/$SERVICE_NAME-rpc.yaml"

# 修復本地設定檔 Port
API_YAML=$(find "$BASE_DIR/api/etc" -maxdepth 1 -name "*.yaml" | head -n 1)
RPC_YAML=$(find "$BASE_DIR/rpc/etc" -maxdepth 1 -name "*.yaml" | head -n 1)
if [ -n "$API_YAML" ]; then
    sed -i '' "s/INFAR_API_PORT_PLACEHOLDER/$API_PORT/g" "$API_YAML"
    sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$API_YAML"
    sed -i '' "s/INFAR_RPC_NAME_PLACEHOLDER/${CAP_SERVICE_NAME}Rpc/g" "$API_YAML"
fi
[[ -n "$RPC_YAML" ]] && sed -i '' "s/INFAR_RPC_PORT_PLACEHOLDER/$RPC_PORT/g" "$RPC_YAML"

(cd "$ROOT_DIR" && go mod tidy && go fmt ./...)
echo "========================================="
echo "🎉 Infar 智能工廠 v8.0 完成！"
echo "✅ 已建立新標準：所有 RPC 設定檔與路徑強制統一為 *-rpc.yaml。"
echo "========================================="
