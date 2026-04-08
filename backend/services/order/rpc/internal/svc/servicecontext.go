package svc

import (
	_ "github.com/lib/pq"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
	"infar/services/order/model"
	"infar/services/order/rpc/internal/config"
)

type ServiceContext struct {
	Config      config.Config
	OrdersModel model.OrdersModel
}

func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{Config: c, OrdersModel: model.NewOrdersModel(conn, c.CacheRedis)}
}
