package handler

import (
	"net/http"

	"infar/services/user/api/internal/logic"
	"infar/services/user/api/internal/svc"
	"infar/services/user/api/internal/types"

	"github.com/zeromicro/go-zero/rest/httpx"
)

// RegisterHandler 處理使用者註冊
//
//	@Summary		使用者註冊
//	@Description	提供帳號、密碼與登入提供商 (Provider) 資訊，建立全新的使用者帳號。
//	@Tags			Auth
//	@Accept			json
//	@Produce		json
//	@Param			request	body		types.RegisterReq	true	"註冊資訊"
//	@Success		200		{object}	types.RegisterRes	"註冊成功回傳"
//	@Failure		500		{object}	string			"伺服器或資料庫錯誤"
//	@Router			/user/register [post]
func RegisterHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.RegisterReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewRegisterLogic(r.Context(), svcCtx)
		resp, err := l.Register(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
