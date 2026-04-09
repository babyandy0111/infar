package handler

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"infar/services/order/api/internal/logic"
	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"
)

// 狀態切換
// @Summary UpdateStatusHandler
// @Description 執行 UpdateStatusHandler 動作
// @Tags Order
// @Accept json
// @Produce json
// @Param body body types.UpdateStatusReq true "狀態更新參數"
// @Success 200 {object} types.Response
// @Router /v1/order/status [patch]
func UpdateStatusHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.UpdateStatusReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewUpdateStatusLogic(r.Context(), svcCtx)
		resp, err := l.UpdateStatus(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
