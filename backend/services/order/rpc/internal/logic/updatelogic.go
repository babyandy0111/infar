package logic

import (
	"context"

	"infar/services/order/rpc/internal/svc"
	"infar/services/order/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateLogic {
	return &UpdateLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 2. 更新
func (l *UpdateLogic) Update(in *pb.UpdateReq) (*pb.Response, error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	/*
		// TODO: 1. 檢查是否存在
		// existing, err := l.svcCtx.OrdersModel.FindOne(l.ctx, in.Id)
		// if err != nil {
		// 	return nil, err
		// }
		// TODO: 2. 執行更新
		// existing.Data = in.Data
		// err = l.svcCtx.OrdersModel.Update(l.ctx, existing)
		// if err != nil {
		// 	return nil, err
		// }
		return &pb.Response{Msg: "更新成功"}, nil
	*/

	// TODO: 請實作具體業務邏輯或解除上述註解
	return &pb.Response{}, nil
}
