package handler

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	"infar/services/order/api/internal/logic"
	"infar/services/order/api/internal/svc"
	"infar/services/order/api/internal/types"
)

// 新增資料
// @Summary CreateHandler
// @Description 執行 CreateHandler 動作
// @Tags Order
// @Accept json
// @Produce json
// @Param body body types.CreateReq true "建立參數"
// @Success 200 {object} types.Response
// @Router /v1/order/create [post]
func CreateHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CreateReq
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		l := logic.NewCreateLogic(r.Context(), svcCtx)
		resp, err := l.Create(&req)
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
