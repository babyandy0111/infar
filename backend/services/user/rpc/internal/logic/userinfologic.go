package logic

import (
	"context"

	"infar/services/user/rpc/internal/svc"
	"infar/services/user/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
)

type UserInfoLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UserInfoLogic {
	return &UserInfoLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UserInfoLogic) UserInfo(in *pb.UserInfoRequest) (*pb.UserInfoResponse, error) {
	userInfo, err := l.svcCtx.UsersModel.FindOne(l.ctx, in.Id)
	if err != nil {
		return nil, err
	}

	roles, err := l.svcCtx.UserRolesModel.FindRolesByUserId(l.ctx, in.Id)
	if err != nil {
		return nil, err
	}

	return &pb.UserInfoResponse{
		Id:       userInfo.Id,
		Account:  userInfo.Account,
		Provider: userInfo.Provider,
		Roles:    roles,
	}, nil
}
