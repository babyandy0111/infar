package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/segmentio/kafka-go"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

type OrderMsg struct {
	UserID    int     `json:"user_id"`
	ProductID int     `json:"product_id"`
	Amount    float64 `json:"amount"`
	OrderNo   string  `json:"order_no"`
}

func main() {
	fmt.Println("🚀 啟動 Order Consumer (Kafka -> PostgreSQL)...")

	// 1. 初始化資料庫連線
	conn := sqlx.NewSqlConn("postgres", "postgres://infar_admin:InfarDbPass123@127.0.0.1:5432/infar_db?sslmode=disable")

	// 2. 初始化 Kafka Reader
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:   []string{"127.0.0.1:9092"},
		Topic:     "order-create",
		GroupID:   "order-consumer-group",
		Partition: 0,
		MinBytes:  10e3, // 10KB
		MaxBytes:  10e6, // 10MB
	})

	for {
		m, err := r.FetchMessage(context.Background())
		if err != nil {
			log.Printf("讀取訊息失敗: %v", err)
			continue
		}

		var msg OrderMsg
		if err := json.Unmarshal(m.Value, &msg); err != nil {
			log.Printf("解析訊息失敗: %v", err)
			continue
		}

		fmt.Printf("📦 收到訂單: %s (User: %d, Amount: %.2f)\n", msg.OrderNo, msg.UserID, msg.Amount)

		// 3. 落盤到 PostgreSQL
		query := `INSERT INTO orders (user_id, order_no, amount, status) VALUES ($1, $2, $3, $4)`
		_, err = conn.ExecCtx(context.Background(), query, msg.UserID, msg.OrderNo, msg.Amount, 1)

		if err != nil {
			log.Printf("❌ 落盤失敗: %v", err)
			// 在真實環境應該有 Retry 或是 DLQ 機制
		} else {
			log.Printf("✅ 訂單 %s 已成功落盤至資料庫", msg.OrderNo)
			// 確認處理成功後才 Commit Offset
			r.CommitMessages(context.Background(), m)
		}
	}
}
