package logic

import (
	{{.imports}}
)

type {{.logic}} struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

{{if .hasDoc}}{{.doc}}{{end}}
func New{{.logic}}(ctx context.Context, svcCtx *svc.ServiceContext) *{{.logic}} {
	return &{{.logic}}{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *{{.logic}}) {{.function}}({{.request}}) {{.responseType}} {
	// 💡 Infar Auto-Generated API Logic Scaffolding
	// 這裡負責呼叫 RPC 層的 {{.function}} 方法

	{{if eq .function "Create"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.Create(l.ctx, &INFAR_CLIENT_DIR_NAME.CreateReq{
		// TODO: 1. 映射 API 請求欄位到 RPC 請求
		// Data: req.Data,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Msg: rpcResp.Msg}, nil
	*/
	{{else if eq .function "Update"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.Update(l.ctx, &INFAR_CLIENT_DIR_NAME.UpdateReq{
		// TODO: 1. 映射 API 請求欄位到 RPC 請求
		// Id: req.Id,
		// Data: req.Data,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Msg: rpcResp.Msg}, nil
	*/
	{{else if eq .function "Delete"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.Delete(l.ctx, &INFAR_CLIENT_DIR_NAME.DeleteReq{
		// Id: req.Id,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Msg: rpcResp.Msg}, nil
	*/
	{{else if eq .function "Get"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.Get(l.ctx, &INFAR_CLIENT_DIR_NAME.GetReq{
		// Id: req.Id,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Data: rpcResp}, nil
	*/
	{{else if eq .function "List"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.List(l.ctx, &INFAR_CLIENT_DIR_NAME.ListReq{
		// Page: req.Page,
		// PageSize: req.PageSize,
		// Keyword: req.Keyword,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Data: rpcResp}, nil
	*/
	{{else if eq .function "UpdateStatus"}}
	/*
	rpcResp, err := l.svcCtx.INFAR_CAP_SERVICE_NAME_RPCCLIENT.UpdateStatus(l.ctx, &INFAR_CLIENT_DIR_NAME.UpdateStatusReq{
		// Id: req.Id,
		// Status: req.Status,
	})
	if err != nil {
		return nil, err
	}
	return &types.Response{Msg: rpcResp.Msg}, nil
	*/
	{{end}}
	
	// TODO: 請實作具體轉發邏輯或解除上述註解
	{{.returnString}}
}
