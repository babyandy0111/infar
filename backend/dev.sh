#!/bin/bash

# ==============================================================
# Infar Backend 智慧型開發啟動神器 (防彈全動態版)
# 作用：啟動前自動清理舊程序，自動偵測服務並啟動，退出時優雅關閉。
# ==============================================================

# 取得當前腳本的 Process Group ID (PGID)
PGID=$(ps -o pgid= $$ | grep -o '[0-9]*')

# 設定 Trap：當按下 Ctrl+C 或腳本退出時，對整個 Process Group 發送 KILL 訊號
trap 'echo -e "\n🛑 收到中止訊號，正在秒殺所有服務..."; kill -9 -$PGID 2>/dev/null; echo "✅ 所有服務已強制停止！"; exit' SIGINT SIGTERM EXIT

echo "========================================="
echo "🚀 啟動 Infar Backend 智慧開發環境"
echo "========================================="

# 0. 暴力清理防禦機制 (防止 Port 被舊程序咬死)
echo "🧹 正在清理舊的開發程序與佔用埠口..."
# 殺掉 9090, 8888 以及未來可能增加的慣用埠口
lsof -ti:9090,8888,9091,8889 2>/dev/null | xargs kill -9 2>/dev/null
# 殺掉任何正在跑的 go run 實例 (確保沒孤兒進程)
pkill -f "go run services" 2>/dev/null
sleep 1

# 1. 檢查並恢復基礎設施通道
echo "🔍 檢查基礎設施連線..."
for port in 5432 6379; do
    if ! nc -z 127.0.0.1 $port 2>/dev/null; then
        if [ "$port" == "5432" ]; then
            echo "   👉 自動恢復 Postgres 通道 (5432)..."
            kubectl port-forward svc/postgres 5432:5432 -n infra > /dev/null 2>&1 &
        else
            echo "   👉 自動恢復 Redis 通道 (6379)..."
            kubectl port-forward svc/redis-master 6379:6379 -n infra > /dev/null 2>&1 &
        fi
    fi
done
echo "✅ 基礎設施連線就緒！"
echo "-----------------------------------------"

export PATH=$PATH:$(go env GOPATH)/bin

# 2. 掃描並啟動服務
SERVICES_DIR="services"
count=0

for service_path in "$SERVICES_DIR"/*; do
    if [ -d "$service_path" ]; then
        service_name=$(basename "$service_path")
        
        # --- 啟動 RPC 服務 ---
        if [ -d "$service_path/rpc" ]; then
            rpc_main=$(find "$service_path/rpc" -maxdepth 1 -name "*.go" | head -n 1)
            # 優先找與服務同名的 yaml，排除 pb.yaml
            rpc_conf=$(find "$service_path/rpc/etc" -name "$service_name.yaml" -o \( -name "*.yaml" ! -name "pb.yaml" \) | head -n 1)
            if [ -f "$rpc_main" ] && [ -f "$rpc_conf" ]; then
                echo "📦 偵測到 RPC 服務: [$service_name] -> 啟動中..."
                go run "$rpc_main" -f "$rpc_conf" &
                ((count++))
            fi
        fi

        # --- 啟動 API 服務 ---
        if [ -d "$service_path/api" ]; then
            api_main=$(find "$service_path/api" -maxdepth 1 -name "*.go" | head -n 1)
            api_conf=$(find "$service_path/api/etc" -name "$service_name-api.yaml" -o -name "*.yaml" | head -n 1)
            if [ -f "$api_main" ] && [ -f "$api_conf" ]; then
                echo "🌐 偵測到 API 服務: [$service_name] -> 正在產生 Swagger..."
                (cd "$service_path/api" && swag init -q -g $(basename "$api_main") --parseDependency --parseInternal > /dev/null 2>&1)
                
                echo "🌐 偵測到 API 服務: [$service_name] -> 啟動中..."
                go run "$api_main" -f "$api_conf" &
                ((count++))
            fi
        fi
    fi
done

echo "-----------------------------------------"
echo "🎉 成功動態啟動了 $count 個服務模組！"
echo "💡 提示：隨時按下 [Ctrl + C] 即可安全停止所有服務"
echo "========================================="

wait
