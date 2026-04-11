#!/bin/bash

# ==============================================================
# Infar Backend 智慧型開發啟動神器 (v7.2 長生不老連線版)
# ==============================================================

# 開啟作業控制，讓背景任務 (如 port-forward) 擁有獨立的進程組，對 Ctrl+C 免疫
set -m

# 設定 Trap：手動中止時，只關閉微服務，不影響基礎設施通道
trap '
echo -e "\n🛑 收到中止訊號，正在關閉微服務 (保留資料庫連線)..."
pkill -f "go run services" 2>/dev/null || true
pkill -f "apihub.go" 2>/dev/null || true
exit
' SIGINT SIGTERM

echo "========================================="
echo "🚀 啟動 Infar Backend (連線持久化模式)"
echo "========================================="

# 0. 精準清理防禦機制 (只清理微服務，不清理 kubectl)
echo "🧹 正在清理舊程序..."
pkill -f "go run services" 2>/dev/null || true
pkill -f "apihub.go" 2>/dev/null || true # 👈 加入這行，確保舊的 apihub 被殺掉

# 只抓取 8000-9999 之間的 Port
PORTS=$(grep -rE "Port:|ListenOn:" services/*/api/etc services/*/rpc/etc 2>/dev/null | awk -F': ' '{print $NF}' | grep -oE "[0-9]+" | awk '$1 >= 8000 && $1 <= 9999' | sort -u | tr '\n' ',' | sed 's/,$//')
# 將 8000 也加入清理名單
if [ -n "$PORTS" ]; then
    PORTS="$PORTS,8000"
else
    PORTS="8000"
fi

if [ -n "$PORTS" ]; then
    lsof -ti:$PORTS 2>/dev/null | xargs kill -9 2>/dev/null || true
fi

# 1. 恢復基礎設施通道 (使用獨立進程組)
echo "🔍 檢查基礎設施連線..."
for port in 5432 6379 9092; do
    if ! nc -z 127.0.0.1 $port 2>/dev/null; then
        if [ "$port" == "5432" ]; then
            echo "   👉 啟動 Postgres 持久通道 (5432)..."
            # 使用 () & 配合 disown 徹底分離
            (kubectl port-forward svc/postgres 5432:5432 -n infra > /dev/null 2>&1 &)
        elif [ "$port" == "6379" ]; then
            echo "   👉 啟動 Redis 持久通道 (6379)..."
            (kubectl port-forward svc/redis-master 6379:6379 -n infra > /dev/null 2>&1 &)
        elif [ "$port" == "9092" ]; then
            echo "   👉 啟動 Kafka 持久通道 (9092)..."
            (kubectl port-forward svc/kafka-service 9092:9092 -n infra > /dev/null 2>&1 &)
        fi
        sleep 2
    fi
done
echo "✅ 基礎設施連線就緒！"
echo "-----------------------------------------"

export PATH=$PATH:$(go env GOPATH)/bin

# 2. 順序啟動服務
SERVICES_DIR="services"
count=0
for service_path in $(ls -d "$SERVICES_DIR"/* | sort); do
    service_name=$(basename "$service_path")
    
    # 啟動 RPC
    if [ -d "$service_path/rpc" ]; then
        rpc_main=$(find "$service_path/rpc" -maxdepth 1 -name "*.go" | head -n 1)
        rpc_conf=$(find "$service_path/rpc/etc" -name "$service_name.yaml" -o \( -name "*.yaml" ! -name "pb.yaml" \) | head -n 1)
        if [ -f "$rpc_main" ] && [ -f "$rpc_conf" ]; then
            echo "📦 [$service_name] RPC 啟動中..."
            go run "$rpc_main" -f "$rpc_conf" &
            sleep 2
            ((count++))
        fi
    fi

    # 啟動 API
    if [ -d "$service_path/api" ]; then
        api_main=$(find "$service_path/api" -maxdepth 1 -name "*.go" | head -n 1)
        api_conf=$(find "$service_path/api/etc" -name "$service_name-api.yaml" -o -name "*.yaml" | head -n 1)
        if [ -f "$api_main" ] && [ -f "$api_conf" ]; then
            if [ ! -d "$service_path/api/docs" ]; then
                (cd "$service_path/api" && swag init -q -g $(basename "$api_main") > /dev/null 2>&1)
            fi
            echo "🌐 [$service_name] API 啟動中..."
            go run "$api_main" -f "$api_conf" &
            sleep 2
            ((count++))
        fi
    fi
done

# 3. 啟動 API Hub
go run apihub.go &

echo "-----------------------------------------"
echo "🎉 啟動完成！(按 Ctrl+C 停止微服務，通道將保持開啟)"
echo "========================================="

wait
