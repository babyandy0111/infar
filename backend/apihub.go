package main

import (
	"fmt"
	"gopkg.in/yaml.v2"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Config struct {
	Name string `yaml:"Name"`
	Port int    `yaml:"Port"`
}

type ServiceInfo struct {
	Name string
	URL  string
}

func getServices() []ServiceInfo {
	var services []ServiceInfo
	root := "services"

	entries, err := os.ReadDir(root)
	if err != nil {
		return services
	}

	for _, entry := range entries {
		if entry.IsDir() {
			serviceName := entry.Name()
			// 尋找 API 設定檔
			etcDir := filepath.Join(root, serviceName, "api", "etc")
			yamlFiles, _ := filepath.Glob(filepath.Join(etcDir, "*.yaml"))

			for _, yamlFile := range yamlFiles {
				// 排除 pb.yaml 或其他非主要設定檔
				if strings.Contains(yamlFile, "pb.yaml") {
					continue
				}

				data, err := os.ReadFile(yamlFile)
				if err != nil {
					continue
				}

				var c Config
				if err := yaml.Unmarshal(data, &c); err == nil && c.Port > 0 {
					name := c.Name
					if name == "" {
						name = strings.Title(serviceName) + " Service"
					}
					services = append(services, ServiceInfo{
						Name: name,
						URL:  fmt.Sprintf("http://127.0.0.1:%d/swagger/doc.json", c.Port),
					})
				}
			}
		}
	}

	sort.Slice(services, func(i, j int) bool {
		return services[i].Name < services[j].Name
	})

	return services
}

func main() {
	port := 8000

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		services := getServices()

		// 動態生成 JS 陣列字串
		var urlsJS []string
		for _, s := range services {
			urlsJS = append(urlsJS, fmt.Sprintf(`{url: "%s", name: "%s"}`, s.URL, s.Name))
		}
		urlsList := strings.Join(urlsJS, ",\n          ")

		html := fmt.Sprintf(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Infar Unified API Hub</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" >
    <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"> </script>
    <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"> </script>
    <script>
    window.onload = function() {
      const ui = SwaggerUIBundle({
        urls: [
          %s
        ],
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "StandaloneLayout"
      })
      window.ui = ui
    }
    </script>
</body>
</html>
`, urlsList)

		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(html))
	})

	fmt.Printf("🚀 Infar API Hub (Dynamic) is running at http://127.0.0.1:%d\n", port)
	if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
		panic(err)
	}
}
