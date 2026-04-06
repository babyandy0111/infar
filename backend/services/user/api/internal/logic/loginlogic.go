package logic

import (
	"context"
	"time"

	"infar/services/user/api/internal/svc"
	"infar/services/user/api/internal/types"
	"infar/services/user/rpc/userclient"

	"github.com/golang-jwt/jwt/v4"
	"github.com/zeromicro/go-zero/core/logx"
)

type LoginLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
	return &LoginLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LoginLogic) Login(req *types.LoginReq) (resp *types.LoginRes, err error) {
	// 1. 調用內部 RPC 服務進行認證
	res, err := l.svcCtx.UserRpc.Login(l.ctx, &userclient.LoginRequest{
		Account:  req.Account,
		Password: req.Password,
		Provider: req.Provider,
	})
	if err != nil {
		return nil, err
	}

	// 2. 認證成功，簽發 JWT Token
	now := time.Now().Unix()
	accessExpire := l.svcCtx.Config.Auth.AccessExpire
	jwtToken, err := l.getJwtToken(l.svcCtx.Config.Auth.AccessSecret, now, accessExpire, res.Id)
	if err != nil {
		return nil, err
	}

	return &types.LoginRes{
		Id:    res.Id,
		Token: jwtToken,
	}, nil
}

func (l *LoginLogic) getJwtToken(secretKey string, iat, seconds, userId int64) (string, error) {
	claims := make(jwt.MapClaims)
	claims["exp"] = iat + seconds // 過期時間
	claims["iat"] = iat           // 簽發時間
	claims["userId"] = userId     // 自定義資訊 (我們的 User ID)

	token := jwt.New(jwt.SigningMethodHS256)
	token.Claims = claims
	return token.SignedString([]byte(secretKey))
}
