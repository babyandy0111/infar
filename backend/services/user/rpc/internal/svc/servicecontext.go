package svc

import (
	"infar/services/user/model"
	"infar/services/user/rpc/internal/config"

	_ "github.com/lib/pq"
	"github.com/zeromicro/go-zero/core/stores/redis"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

type ServiceContext struct {
	Config            config.Config
	UsersModel        model.UsersModel
	UserRolesModel    model.UserRolesModel
	UserProfilesModel model.UserProfilesModel
	BizRedis          *redis.Redis
}

func NewServiceContext(c config.Config) *ServiceContext {
	conn := sqlx.NewSqlConn("postgres", c.DataSource)
	return &ServiceContext{
		Config:            c,
		UsersModel:        model.NewUsersModel(conn, c.CacheRedis),
		UserRolesModel:    model.NewUserRolesModel(conn, c.CacheRedis),
		UserProfilesModel: model.NewUserProfilesModel(conn, c.CacheRedis),
		// 使用 Config 裡的第一個 Cache 節點當作 BizRedis (為了使用 MGET)
		BizRedis: redis.MustNewRedis(redis.RedisConf{
			Host: c.CacheRedis[0].Host,
			Pass: c.CacheRedis[0].Pass,
			Type: "node",
		}),
	}
}
