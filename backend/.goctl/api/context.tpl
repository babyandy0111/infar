package svc

import (
	{{.configImport}}
	"infar/services/INFAR_SERVICE_NAME/rpc/INFAR_CLIENT_DIR_NAME"
	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config config.Config
	INFAR_CAP_SERVICE_NAME_RPCCLIENT INFAR_CLIENT_DIR_NAME.INFAR_CAP_SERVICE_NAME
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config: c,
		INFAR_CAP_SERVICE_NAME_RPCCLIENT: INFAR_CLIENT_DIR_NAME.NewINFAR_CAP_SERVICE_NAME(zrpc.MustNewClient(c.INFAR_CAP_SERVICE_NAME_RPCCONF)),
	}
}
