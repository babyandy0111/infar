package main

import (
	"flag"
	"fmt"
	"net/http"

	{{.importPackages}}

	httpSwagger "github.com/swaggo/http-swagger"
)

var configFile = flag.String("f", "etc/{{.serviceName}}.yaml", "the config file")

func main() {
	flag.Parse()

	var c config.Config
	conf.MustLoad(*configFile, &c)

	server := rest.MustNewServer(c.RestConf, rest.WithCors())
	defer server.Stop()

	ctx := svc.NewServiceContext(c)
	handler.RegisterHandlers(server, ctx)

	server.AddRoute(rest.Route{
		Method:  http.MethodGet,
		Path:    "/swagger",
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
