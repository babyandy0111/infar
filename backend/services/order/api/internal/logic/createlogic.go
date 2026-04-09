package logic

import (
	"context"
	"fmt"

	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"
	"infar/services/user/rpc/userclient"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// 新增資料
func NewCreateLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateLogic {
	return &CreateLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateLogic) Create(req *types.CreateReq) (resp *types.Response, err error) {
	// 1. 跨服務調用：調用 User RPC 驗證用戶是否存在
	userRes, err := l.svcCtx.UserRpc.UserInfo(l.ctx, &userclient.UserInfoRequest{
		Id: int64(req.UserId),
	})

	if err != nil {
		l.Logger.Errorf("🚨 跨服務調用失敗，用戶驗證不通過: %v", err)
		return &types.Response{
			Msg: fmt.Sprintf("錯誤: 找不到 UserId 為 %d 的用戶！", req.UserId),
		}, nil
	}

	l.Logger.Infof("✅ 跨服務調用成功！用戶暱稱: %s, 準備為其建立訂單: %s", userRes.Nickname, req.OrderNo)

	return &types.Response{
		Msg: fmt.Sprintf("跨服務驗證成功！歡迎 %s 建立訂單 %s", userRes.Nickname, req.OrderNo),
	}, nil
}
