package logic

import (
	"context"

	"infar/services/user/api/internal/svc"
	"infar/services/user/api/internal/types"
	"infar/services/user/rpc/userclient"

	"github.com/zeromicro/go-zero/core/logx"
)

type RegisterLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewRegisterLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RegisterLogic {
	return &RegisterLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RegisterLogic) Register(req *types.RegisterReq) (resp *types.RegisterRes, err error) {
	res, err := l.svcCtx.UserRpc.Register(l.ctx, &userclient.RegisterRequest{
		Account:  req.Account,
		Password: req.Password,
		Provider: req.Provider,
	})
	if err != nil {
		return nil, err
	}
	l.Logger.Infof("API received registered user ID: %d", res.Id)

	return &types.RegisterRes{
		Id: res.Id,
	}, nil
}
