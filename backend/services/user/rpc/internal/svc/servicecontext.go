package svc

import (
	"infar/services/user/model"
	"infar/services/user/rpc/internal/config"

	_ "github.com/lib/pq"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

type ServiceContext struct {
	Config     config.Config
	UsersModel model.UsersModel
}

func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{
		Config:     c,
		UsersModel: model.NewUsersModel(conn, c.CacheRedis),
	}
}
