package logic

import (
	"context"

	"infar/services/order/rpc/internal/svc"
	"infar/services/order/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetLogic {
	return &GetLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 4. 取得單筆
func (l *GetLogic) Get(in *pb.GetReq) (*pb.Response, error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	/*
		// TODO: 1. 執行查詢
		// res, err := l.svcCtx.OrdersModel.FindOne(l.ctx, in.Id)
		// if err != nil {
		// 	return nil, err
		// }
		return &pb.Response{
			// Data: res.Data,
		}, nil
	*/

	// TODO: 請實作具體業務邏輯或解除上述註解
	return &pb.Response{}, nil
}
