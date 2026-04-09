package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateStatusLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 狀態切換
func NewUpdateStatusLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateStatusLogic {
	return &UpdateStatusLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateStatusLogic) UpdateStatus(req *types.UpdateStatusReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 UpdateStatus 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.UpdateStatus(l.ctx, &order.UpdateStatusReq{
			// Id: req.Id,
			// Status: req.Status,
		})
		if err != nil {
			return nil, err
		}
		return &types.Response{Msg: rpcResp.Msg}, nil
	*/

	// TODO: 請實作具體轉發邏輯或解除上述註解
	return
}
