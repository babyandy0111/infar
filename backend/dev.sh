#!/bin/bash

# ==============================================================
# Infar Backend 本地開發啟動神器
# 作用：一鍵啟動所有微服務，並在退出時自動清理，絕不殘留！
# ==============================================================

# 設定 Trap：當按下 Ctrl+C (SIGINT) 或腳本退出時，自動殺掉所有背景子程序
trap 'echo -e "\n🛑 正在優雅關閉所有服務..."; kill $(jobs -p) 2>/dev/null; wait; echo "✅ 服務已完全停止，Port 已釋放！"; exit' SIGINT SIGTERM EXIT

echo "========================================="
echo "🚀 啟動 Infar Backend 本地開發環境"
echo "========================================="

# 1. 檢查並恢復資料庫通道
echo "🔍 檢查基礎設施連線..."
if ! nc -z 127.0.0.1 5432 2>/dev/null; then
    echo "   👉 自動恢復 Postgres 通道 (5432)..."
    kubectl port-forward svc/postgres 5432:5432 -n infra > /dev/null 2>&1 &
fi
if ! nc -z 127.0.0.1 6379 2>/dev/null; then
    echo "   👉 自動恢復 Redis 通道 (6379)..."
    kubectl port-forward svc/redis-master 6379:6379 -n infra > /dev/null 2>&1 &
fi

echo "✅ 基礎設施連線就緒！"
echo "-----------------------------------------"

# 2. 啟動微服務
echo "📦 [1/2] 正在啟動 User RPC 服務 (Port: 9090)..."
go run services/user/rpc/user.go -f services/user/rpc/etc/user.yaml &
RPC_PID=$!

# 等待 RPC 稍微啟動一下
sleep 2

echo "🌐 [2/2] 正在啟動 User API 網關 (Port: 8888)..."
go run services/user/api/user.go -f services/user/api/etc/user-api.yaml &
API_PID=$!

echo "-----------------------------------------"
echo "🎉 所有服務已啟動並在前景執行中！"
echo "💡 提示：隨時按下 [Ctrl + C] 即可安全停止所有服務"
echo "========================================="

# 讓腳本卡在這裡等待，並將背景程序的輸出導向到終端機
wait
