package logic

import (
	"context"

	"infar/services/order/rpc/internal/svc"
	"infar/services/order/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteLogic {
	return &DeleteLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 3. 刪除
func (l *DeleteLogic) Delete(in *pb.DeleteReq) (*pb.Response, error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	/*
		// TODO: 1. 執行刪除
		// err := l.svcCtx.OrdersModel.Delete(l.ctx, in.Id)
		// if err != nil {
		// 	return nil, err
		// }
		return &pb.Response{Msg: "刪除成功"}, nil
	*/

	// TODO: 請實作具體業務邏輯或解除上述註解
	return &pb.Response{}, nil
}
