package config

import (
	"github.com/zeromicro/go-zero/core/stores/redis"
	"github.com/zeromicro/go-zero/rest"
	"github.com/zeromicro/go-zero/zrpc"
)

type Config struct {
	rest.RestConf
	Auth struct {
		AccessSecret string
		AccessExpire int64
	}
	OrderRpc     zrpc.RpcClientConf
	UserRpc      zrpc.RpcClientConf
	KqPusherConf struct {
		Brokers []string
		Topic   string
		// 🚀 優化：生產者批次發送參數
		ChunkSize     int `json:",optional,default=1024"`
		FlushInterval int `json:",optional,default=100"` // ms
	}
	Redis redis.RedisConf
}
