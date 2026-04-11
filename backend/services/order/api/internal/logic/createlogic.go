package logic

import (
	"context"
	"encoding/json"
	"strconv"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// Lua 腳本：原子性扣減庫存
// KEYS[1]: 庫存 Key (例如 stock:1)
// ARGV[1]: 扣減數量 (通常是 1)
const luaScript = `
local stock = tonumber(redis.call("get", KEYS[1]))
if (not stock or stock <= 0) then
    return -1
end
redis.call("decrby", KEYS[1], ARGV[1])
return 1
`

// 新增資料 (秒殺版本)
func NewCreateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateLogic {
	return &CreateLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateLogic) Create(req *types.CreateReq) (resp *types.Response, err error) {
	// 🚀 高併發第一道防線：Redis 預扣庫存
	// 在實際應用中，req.UserId 應該是商品 ID，這裡我們模擬商品 ID 為 1
	productId := 1
	stockKey := "stock:" + strconv.Itoa(productId)

	// 執行 Lua 腳本 (確保原子性)
	res, err := l.svcCtx.BizRedis.EvalCtx(l.ctx, luaScript, []string{stockKey}, "1")
	if err != nil {
		l.Logger.Errorf("🚨 Redis 執行庫存扣減失敗: %v", err)
		return nil, err
	}

	// 判斷庫存結果
	code := res.(int64)
	if code == -1 {
		return &types.Response{
			Code: 400,
			Msg:  "抱歉！商品已售罄 (庫存不足)",
		}, nil
	}

	// 🚀 高併發第二道防線：Kafka 削峰填谷
	// 庫存預扣成功，將訂單資訊丟入 Kafka 異步處理
	orderMsg := map[string]interface{}{
		"user_id":    req.UserId,
		"product_id": productId,
		"amount":     req.Amount,
		"order_no":   req.OrderNo,
	}
	msgBytes, _ := json.Marshal(orderMsg)

	// 修復：KqPusher.Push 需要傳入 Context
	err = l.svcCtx.KqPusher.Push(l.ctx, string(msgBytes))
	if err != nil {
		l.Logger.Errorf("🚨 Kafka 推送失敗: %v", err)
		// 這裡可以考慮回滾 Redis 庫存，或是記錄日誌手動處理
		return nil, err
	}

	l.Logger.Infof("✅ 秒殺成功！庫存已預扣，訂單 %s 已進入隊列非同步處理中", req.OrderNo)

	return &types.Response{
		Code: 200,
		Msg:  "搶購成功！訂單正在後台處理中...",
		Data: orderMsg,
	}, nil
}
