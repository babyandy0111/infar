package logic

import (
	"context"

	"infar/services/order/rpc/internal/svc"
	"infar/services/order/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListLogic {
	return &ListLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 5. 分頁列表
func (l *ListLogic) List(in *pb.ListReq) (*pb.ListResponse, error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	/*
		// TODO: 1. 實作分頁查詢 (需要在 model 層擴充 FindAll 方法)
		// list, err := l.svcCtx.OrdersModel.FindAll(l.ctx, in.Page, in.PageSize, in.Keyword)
		// if err != nil {
		// 	return nil, err
		// }
		return &pb.ListResponse{
			Total: 0,
			List: []string{}, // list,
		}, nil
	*/

	// TODO: 請實作具體業務邏輯或解除上述註解
	return &pb.ListResponse{}, nil
}
