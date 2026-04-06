package logic

import (
	"context"
	"errors"

	"infar/services/user/model"
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
	// 1. 查詢使用者帳號資訊
	userInfo, err := l.svcCtx.UsersModel.FindOne(l.ctx, in.Id)
	if err != nil {
		if errors.Is(err, model.ErrNotFound) {
			return nil, errors.New("使用者不存在")
		}
		return nil, err
	}

	// 2. 查詢角色權限
	roles, err := l.svcCtx.UserRolesModel.FindRolesByUserId(l.ctx, in.Id)
	if err != nil {
		l.Logger.Errorf("查詢角色失敗: %v", err)
		// 角色查詢失敗不一定要中斷，可以給空陣列
		roles = []string{}
	}

	// 3. 查詢詳細 Profile 資料
	var nickname, name, phone, address string
	var age int32
	profile, err := l.svcCtx.UserProfilesModel.FindOneByUserId(l.ctx, in.Id)
	if err == nil {
		nickname = profile.Nickname.String
		name = profile.Name.String
		age = int32(profile.Age.Int64)
		phone = profile.Phone.String
		address = profile.Address.String
	} else if !errors.Is(err, model.ErrNotFound) {
		l.Logger.Errorf("查詢 Profile 失敗: %v", err)
	}

	return &pb.UserInfoResponse{
		Id:       userInfo.Id,
		Account:  userInfo.Account,
		Provider: userInfo.Provider,
		Roles:    roles,
		Nickname: nickname,
		Name:     name,
		Age:      age,
		Phone:    phone,
		Address:  address,
	}, nil
}
