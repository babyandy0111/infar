package handler

import (
	"net/http"

	"infar/services/user/api/internal/logic"
	"infar/services/user/api/internal/svc"
	"infar/services/user/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// LoginHandler 處理使用者登入
//
//	@Summary		使用者登入 (獲取 JWT)
//	@Description	驗證帳號、密碼與 Provider，成功後核發 JWT Token 用於後續 API 存取。
//	@Tags			Auth
//	@Accept			json
//	@Produce		json
//	@Param			request	body		types.LoginReq	true	"登入資訊"
//	@Success		200		{object}	types.LoginRes	"登入成功回傳"
//	@Failure		500		{object}	string			"伺服器或資料庫錯誤"
//	@Router			/user/login [post]
func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LoginReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewLoginLogic(r.Context(), svcCtx)
		resp, err := l.Login(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
