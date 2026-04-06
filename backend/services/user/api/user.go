package main

import (
	"flag"
	"fmt"
	"net/http"

	"infar/services/user/api/internal/config"
	"infar/services/user/api/internal/handler"
	"infar/services/user/api/internal/svc"

	"github.com/zeromicro/go-zero/core/conf"
	"github.com/zeromicro/go-zero/rest"

	// 🎉 必須引入產生的 docs 套件
	httpSwagger "github.com/swaggo/http-swagger"
	_ "infar/services/user/api/docs"
)

var configFile = flag.String("f", "etc/user-api.yaml", "the config file")

// @title Infar User Service API
// @version 1.0
// @description 這是 Infar 微服務架構中的使用者中心網關。
// @host 127.0.0.1:8888
// @BasePath /
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)

	server := rest.MustNewServer(c.RestConf)
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	// 1. 處理 /swagger 根路徑跳轉到 index.html
	server.AddRoute(rest.Route{
		Method: http.MethodGet,
		Path:   "/swagger",
		Handler: func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "/swagger/index.html", http.StatusMovedPermanently)
		},
	})

	// 2. 處理 Swagger 靜態資源 (使用 WrapHandler)
	server.AddRoute(rest.Route{
		Method:  http.MethodGet,
		Path:    "/swagger/:any", // go-zero 使用 :any 來匹配
		Handler: httpSwagger.WrapHandler,
	})

	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	server.Start()
}
