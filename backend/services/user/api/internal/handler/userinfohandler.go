package handler

import (
	"net/http"

	"infar/services/user/api/internal/logic"
	"infar/services/user/api/internal/svc"
	"infar/services/user/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// UserInfoHandler 取得使用者資訊
//
//	@Summary		使用者資料查詢
//	@Description	透過 JWT Token 自動辨識身分，回傳帳戶資訊與權限角色。
//	@Tags			User
//	@Produce		json
//	@Security		ApiKeyAuth
//	@Success		200		{object}	types.UserInfoRes	"查詢成功回傳"
//	@Failure		401		{object}	string			"未授權"
//	@Failure		500		{object}	string			"伺服器錯誤"
//	@Router			/user/info [get]
func UserInfoHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UserInfoReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewUserInfoLogic(r.Context(), svcCtx)
		resp, err := l.UserInfo(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
