package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 新增資料
func NewCreateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateLogic {
	return &CreateLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateLogic) Create(req *types.CreateReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 Create 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.Create(l.ctx, &order.CreateReq{
			// TODO: 1. 映射 API 請求欄位到 RPC 請求
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
