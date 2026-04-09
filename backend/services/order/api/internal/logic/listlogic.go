package logic

import (
	"context"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 分頁列表
func NewListLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLogic {
	return &ListLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListLogic) List(req *types.ListReq) (resp *types.Response, err error) {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 List 方法

	/*
		rpcResp, err := l.svcCtx.OrderRpc.List(l.ctx, &order.ListReq{
			// Page: req.Page,
			// PageSize: req.PageSize,
			// Keyword: req.Keyword,
		})
		if err != nil {
			return nil, err
		}
		return &types.Response{Data: rpcResp}, nil
	*/

	// TODO: 請實作具體轉發邏輯或解除上述註解
	return
}
