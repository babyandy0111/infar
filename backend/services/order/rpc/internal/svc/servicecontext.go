package svc

import (
	"infar/services/order/model"
	"infar/services/order/rpc/internal/config"

	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

type ServiceContext struct {
	Config      config.Config
	OrdersModel model.OrdersModel // 👈 1. 定義你的 Model
}

func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{
		Config:      c,
		OrdersModel: model.NewOrdersModel(conn, c.CacheRedis), // 👈 2. 注入
	}
}
