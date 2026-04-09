package svc

import (
	"github.com/zeromicro/go-zero/zrpc"
	"infar/services/order/api/internal/config"
	"infar/services/order/rpc/order"
)

type ServiceContext struct {
	Config   config.Config
	OrderRpc order.Order
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config:   c,
		OrderRpc: order.NewOrder(zrpc.MustNewClient(c.OrderRpc)),
	}
}
