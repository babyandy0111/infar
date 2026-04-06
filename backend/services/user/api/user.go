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

	_ "infar/services/user/api/docs"

	httpSwagger "github.com/swaggo/http-swagger"
)

var configFile = flag.String("f", "etc/user-api.yaml", "the config file")

// @title			Infar User Service API
// @version		1.0
// @description	這是 Infar 微服務架構中的使用者中心網關。
// @host			127.0.0.1:8888
// @BasePath		/

// @securityDefinitions.apikey	ApiKeyAuth
// @in							header
// @name						Authorization
// @description				直接填入 JWT Token (例如: eyJhbGci...)
func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)

	server := rest.MustNewServer(c.RestConf)
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	server.AddRoute(rest.Route{
		Method: http.MethodGet,
		Path:   "/swagger",
		Handler: func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "/swagger/index.html", http.StatusMovedPermanently)
		},
	})

	server.AddRoute(rest.Route{
		Method:  http.MethodGet,
		Path:    "/swagger/:any",
		Handler: httpSwagger.WrapHandler,
	})

	fmt.Printf("Starting server at %s:%d...\n", c.Host, c.Port)
	server.Start()
}
