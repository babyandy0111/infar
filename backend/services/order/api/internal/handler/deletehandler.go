package handler

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"infar/services/order/api/internal/logic"
	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"
)

// 刪除資料
// @Summary DeleteHandler
// @Description 執行 DeleteHandler 動作
// @Tags Order
// @Accept json
// @Produce json
// @Param id path int true "流水號"
// @Success 200 {object} types.Response
// @Router /v1/order/delete/{id} [delete]
func DeleteHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.DeleteReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewDeleteLogic(r.Context(), svcCtx)
		resp, err := l.Delete(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
