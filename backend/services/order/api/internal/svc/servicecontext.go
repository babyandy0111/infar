package svc

import (
	"infar/services/order/api/internal/config"
	"infar/services/order/rpc/order"
	"infar/services/user/rpc/userclient"

	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config   config.Config
	OrderRpc order.Order
	UserRpc  userclient.User
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config:   c,
		OrderRpc: order.NewOrder(zrpc.MustNewClient(c.OrderRpc)),
		UserRpc:  userclient.NewUser(zrpc.MustNewClient(c.UserRpc)),
	}
}
