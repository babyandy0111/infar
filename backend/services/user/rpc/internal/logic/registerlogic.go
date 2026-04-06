package logic

import (
	"context"
	"fmt"

	"infar/services/user/model"
	"infar/services/user/rpc/internal/svc"
	"infar/services/user/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
	"golang.org/x/crypto/bcrypt"
)

type RegisterLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRegisterLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RegisterLogic {
	return &RegisterLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RegisterLogic) Register(in *pb.RegisterRequest) (*pb.RegisterResponse, error) {
	_, err := l.svcCtx.UsersModel.FindOneByProviderAccount(l.ctx, in.Provider, in.Account)
	if err == nil {
		return nil, fmt.Errorf("帳號已存在")
	}

	hashPassword, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	newUser := &model.Users{
		Account:      in.Account,
		Provider:     in.Provider,
		PasswordHash: string(hashPassword),
		IsActive:     true,
	}

	newId, err := l.svcCtx.UsersModel.InsertWithId(l.ctx, newUser)
	if err != nil {
		return nil, err
	}
	l.Logger.Infof("RPC registered new user ID: %d", newId)

	return &pb.RegisterResponse{
		Id: newId,
	}, nil
}
