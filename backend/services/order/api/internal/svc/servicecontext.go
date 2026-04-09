package svc

import (
	"github.com/zeromicro/go-zero/zrpc"
	"infar/services/order/api/internal/config"
	"infar/services/order/rpc/orderclient"
)

type ServiceContext struct {
	Config   config.Config
	OrderRpc orderclient.Order
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config:   c,
		OrderRpc: orderclient.NewOrder(zrpc.MustNewClient(c.OrderRpc)),
	}
}
