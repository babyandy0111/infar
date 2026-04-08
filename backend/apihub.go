package main

import (
	"fmt"
	"net/http"
)

func main() {
	port := 8000
	// 這裡列出目前專案中所有的服務與其對應的 Swagger JSON 位址
	html := `
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
          {url: "http://127.0.0.1:8888/swagger/doc.json", name: "User Service"},
          {url: "http://127.0.0.1:8889/swagger/doc.json", name: "Order Service"}
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
`

	fmt.Printf("🚀 Infar API Hub is running at http://127.0.0.1:%d\n", port)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(html))
	})

	if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
		panic(err)
	}
}
