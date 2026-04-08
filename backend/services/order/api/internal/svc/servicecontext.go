// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package svc

import (
	"infar/services/order/api/internal/config"
	"infar/services/order/rpc/orderclient"

	"github.com/zeromicro/go-zero/zrpc"
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
