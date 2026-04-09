package svc

import (
	{{.imports}}
	// INFAR_RPC_SVC_IMPORTS
)

type ServiceContext struct {
	Config config.Config
	// INFAR_RPC_SVC_FIELDS
}

func NewServiceContext(c config.Config) *ServiceContext {
	// INFAR_RPC_SVC_PRE_INJECT
	return &ServiceContext{
		Config: c,
		// INFAR_RPC_SVC_INJECT
	}
}
