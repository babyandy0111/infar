{{if .hasComment}}{{.comment}}{{end}}
func (l *{{.logicName}}) {{.method}} ({{if .hasReq}}in {{.request}}{{if .stream}},stream {{.streamBody}}{{end}}{{else}}stream {{.streamBody}}{{end}}) ({{if .hasReply}}{{.response}},{{end}} error) {
	// 💡 Infar Auto-Generated RPC Logic Scaffolding
	// 這裡負責核心業務邏輯與資料庫互動

	{{if eq .method "Create"}}
	/*
	// TODO: 1. 執行新增 (Model.Insert)
	// _, err := l.svcCtx.INFAR_MODEL_INTERFACE.Insert(l.ctx, &model.INFAR_MODEL_STRUCT{
	// 	// 欄位: in.Data,
	// })
	// if err != nil {
	// 	return nil, err
	// }
	return &{{.responseType}}{Msg: "建立成功"}, nil
	*/
	{{else if eq .method "Update"}}
	/*
	// TODO: 1. 檢查是否存在
	// existing, err := l.svcCtx.INFAR_MODEL_INTERFACE.FindOne(l.ctx, in.Id)
	// if err != nil {
	// 	return nil, err
	// }
	// TODO: 2. 執行更新
	// existing.Data = in.Data
	// err = l.svcCtx.INFAR_MODEL_INTERFACE.Update(l.ctx, existing)
	// if err != nil {
	// 	return nil, err
	// }
	return &{{.responseType}}{Msg: "更新成功"}, nil
	*/
	{{else if eq .method "Delete"}}
	/*
	// TODO: 1. 執行刪除
	// err := l.svcCtx.INFAR_MODEL_INTERFACE.Delete(l.ctx, in.Id)
	// if err != nil {
	// 	return nil, err
	// }
	return &{{.responseType}}{Msg: "刪除成功"}, nil
	*/
	{{else if eq .method "Get"}}
	/*
	// TODO: 1. 執行查詢
	// res, err := l.svcCtx.INFAR_MODEL_INTERFACE.FindOne(l.ctx, in.Id)
	// if err != nil {
	// 	return nil, err
	// }
	return &{{.responseType}}{
		// Data: res.Data,
	}, nil
	*/
	{{else if eq .method "List"}}
	/*
	// TODO: 1. 實作分頁查詢 (需要在 model 層擴充 FindAll 方法)
	// list, err := l.svcCtx.INFAR_MODEL_INTERFACE.FindAll(l.ctx, in.Page, in.PageSize, in.Keyword)
	// if err != nil {
	// 	return nil, err
	// }
	return &{{.responseType}}{
		Total: 0,
		List: []string{}, // list,
	}, nil
	*/
	{{else if eq .method "UpdateStatus"}}
	/*
	// TODO: 1. 執行狀態更新 (建議在 model 層擴充 UpdateStatus 方法)
	return &{{.responseType}}{Msg: "狀態更新成功"}, nil
	*/
	{{end}}

	// TODO: 請實作具體業務邏輯或解除上述註解
	return {{if .hasReply}}&{{.responseType}}{},{{end}} nil
}
