package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 刪除資料
func NewDeleteLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteLogic {
	return &DeleteLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteLogic) Delete(req *types.DeleteReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 Delete 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.Delete(l.ctx, &order.DeleteReq{
			// Id: req.Id,
		})
		if err != nil {
			return nil, err
		}
		return &types.Response{Msg: rpcResp.Msg}, nil
	*/

	// TODO: 請實作具體轉發邏輯或解除上述註解
	return
}
