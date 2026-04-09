package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 更新資料
func NewUpdateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateLogic {
	return &UpdateLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateLogic) Update(req *types.UpdateReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 Update 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.Update(l.ctx, &order.UpdateReq{
			// TODO: 1. 映射 API 請求欄位到 RPC 請求
			// Id: req.Id,
			// Data: req.Data,
		})
		if err != nil {
			return nil, err
		}
		return &types.Response{Msg: rpcResp.Msg}, nil
	*/

	// TODO: 請實作具體轉發邏輯或解除上述註解
	return
}
