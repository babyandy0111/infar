package logic

import (
	"context"

	"infar/services/order/rpc/internal/svc"
	"infar/services/order/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateLogic {
	return &CreateLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 1. 新增
func (l *CreateLogic) Create(in *pb.CreateReq) (*pb.Response, error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	/*
		// TODO: 1. 執行新增 (Model.Insert)
		// _, err := l.svcCtx.OrdersModel.Insert(l.ctx, &model.Orders{
		// 	// 欄位: in.Data,
		// })
		// if err != nil {
		// 	return nil, err
		// }
		return &pb.Response{Msg: "建立成功"}, nil
	*/

	// TODO: 請實作具體業務邏輯或解除上述註解
	return &pb.Response{}, nil
}
