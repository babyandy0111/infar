package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 取得單筆資料
func NewGetLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetLogic {
	return &GetLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetLogic) Get(req *types.GetReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 Get 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.Get(l.ctx, &order.GetReq{
			// Id: req.Id,
		})
		if err != nil {
			return nil, err
		}
		return &types.Response{Data: rpcResp}, nil
	*/

	// TODO: 請實作具體轉發邏輯或解除上述註解
	return
}
