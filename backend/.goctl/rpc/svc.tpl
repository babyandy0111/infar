package svc

import (
	{{.imports}}
	"infar/services/INFAR_SERVICE_NAME/model"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
	_ "github.com/lib/pq"
)

type ServiceContext struct {
	Config config.Config
	INFAR_MODEL_INTERFACE model.INFAR_MODEL_INTERFACE
}

func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{
		Config: c,
		INFAR_MODEL_INTERFACE: model.NewINFAR_MODEL_INTERFACE(conn, c.CacheRedis),
	}
}
