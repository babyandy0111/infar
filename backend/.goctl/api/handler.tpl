package {{.PkgName}}

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"
	{{.ImportPackages}}
)

{{if .HasDoc}}{{.Doc}}{{end}}
// @Summary {{.HandlerName}}
// @Description 執行 {{.HandlerName}} 動作
// @Tags INFAR_CAP_SERVICE_NAME
// @Accept json
// @Produce json
{{if eq .HandlerName "CreateHandler"}}// @Param body body types.{{.RequestType}} true "建立參數"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/create [post]
{{else if eq .HandlerName "UpdateStatusHandler"}}// @Param body body types.{{.RequestType}} true "狀態更新參數"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/status [patch]
{{else if eq .HandlerName "UpdateHandler"}}// @Param body body types.{{.RequestType}} true "更新參數"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/update [put]
{{else if eq .HandlerName "DeleteHandler"}}// @Param id path int true "流水號"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/delete/{id} [delete]
{{else if eq .HandlerName "ListHandler"}}// @Param page query int false "頁碼" default(1)
// @Param pageSize query int false "每頁筆數" default(20)
// @Param keyword query string false "關鍵字"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/list [get]
{{else if eq .HandlerName "GetHandler"}}// @Param id path int true "流水號"
// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/get/{id} [get]
{{else}}// @Success 200 {object} types.Response
// @Router /v1/INFAR_LOWER_SERVICE_NAME/{{.HandlerName}} [get]
{{end -}}
func {{.HandlerName}}(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		{{if .HasRequest}}var req types.{{.RequestType}}
		if err := httpx.Parse(r, &req); err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
			return
		}

		{{end}}l := {{.LogicName}}.New{{.LogicType}}(r.Context(), svcCtx)
		{{if .HasResp}}resp, {{end}}err := l.{{.Call}}({{if .HasRequest}}&req{{end}})
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			{{if .HasResp}}httpx.OkJsonCtx(r.Context(), w, resp){{else}}httpx.Ok(w){{end}}
		}
	}
}
