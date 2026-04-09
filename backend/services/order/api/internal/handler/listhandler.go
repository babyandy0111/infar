package handler

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"infar/services/order/api/internal/logic"
	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"
)

// 分頁列表
// @Summary ListHandler
// @Description 執行 ListHandler 動作
// @Tags Order
// @Accept json
// @Produce json
// @Param page query int false "頁碼" default(1)
// @Param pageSize query int false "每頁筆數" default(20)
// @Param keyword query string false "關鍵字"
// @Success 200 {object} types.Response
// @Router /v1/order/list [get]
func ListHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.ListReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewListLogic(r.Context(), svcCtx)
		resp, err := l.List(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
