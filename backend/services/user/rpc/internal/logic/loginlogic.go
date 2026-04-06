package logic

import (
	"context"
	"errors"

	"infar/services/user/model"
	"infar/services/user/rpc/internal/svc"
	"infar/services/user/rpc/pb"

	"github.com/zeromicro/go-zero/core/logx"
	"golang.org/x/crypto/bcrypt"
)

type LoginLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
	return &LoginLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *LoginLogic) Login(in *pb.LoginRequest) (*pb.LoginResponse, error) {
	// 1. 根據 Provider 和 Account 尋找使用者
	userInfo, err := l.svcCtx.UsersModel.FindOneByProviderAccount(l.ctx, in.Provider, in.Account)
	if err != nil {
		if errors.Is(err, model.ErrNotFound) {
			return nil, errors.New("帳號或密碼錯誤")
		}
		l.Logger.Errorf("資料庫查詢失敗: %v", err)
		return nil, errors.New("系統錯誤")
	}

	// 2. 檢查使用者狀態
	if !userInfo.IsActive {
		return nil, errors.New("帳號已被停用")
	}

	// 3. 密碼驗證 (比對 Bcrypt Hash)
	err = bcrypt.CompareHashAndPassword([]byte(userInfo.PasswordHash), []byte(in.Password))
	if err != nil {
		return nil, errors.New("帳號或密碼錯誤")
	}

	// 注意：我們在 RPC 層只負責認證，不負責發送 JWT。
	// JWT 的簽發應該放在對外的 API Gateway 層。
	// 所以 RPC 登入成功後，只回傳 User ID 給 API 層。

	return &pb.LoginResponse{
		Id: userInfo.Id,
	}, nil
}
