package svc

import (
	// INFAR_API_SVC_IMPORTS
)

type ServiceContext struct {
	// INFAR_API_SVC_FIELDS
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		// INFAR_API_SVC_INJECT
	}
}
