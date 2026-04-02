package main

import (
	"encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"github.com/joho/godotenv"
	"infar-infra/imports/k8s"

	// 引入我們自己寫的模組
	"infar-infra/pkg/cicd"
	"infar-infra/pkg/datastore"
	"infar-infra/pkg/observability"
	"infar-infra/pkg/streaming"
)

func NewInfarInfra(scope constructs.Construct, id string, props *cdk8s.ChartProps) cdk8s.Chart {
	chart := cdk8s.NewChart(scope, jsii.String(id), props)

	// 1. 讀取環境變數
	_ = godotenv.Load(".env")
	dbPass := os.Getenv("DB_PASSWORD")
	redisPass := os.Getenv("REDIS_PASSWORD")
	argocdPass := os.Getenv("ARGOCD_ADMIN_PASSWORD") // 將被 bcrypt 加密

	if dbPass == "" || redisPass == "" {
		log.Fatal("錯誤：.env 中缺少必須的資料庫密碼設定 (DB_PASSWORD 或 REDIS_PASSWORD)！")
	}

	// 2. 定義基礎命名空間與注入標籤
	namespaces := []string{"infra", "argocd", "observability"}
	for _, ns := range namespaces {
		labels := map[string]*string{"project": jsii.String("infar")}
		if ns == "infra" {
			labels["linkerd.io/inject"] = jsii.String("enabled")
		}
		k8s.NewKubeNamespace(chart, jsii.String(ns+"-ns"), &k8s.KubeNamespaceProps{
			Metadata: &k8s.ObjectMeta{Name: jsii.String(ns), Labels: &labels},
		})
	}

	// 3. 建立 K8s Secret (安全管理密碼)
	k8s.NewKubeSecret(chart, jsii.String("infra-secrets"), &k8s.KubeSecretProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("infra-secrets"),
			Namespace: jsii.String("infra"),
		},
		Data: &map[string]*string{
			"postgresql-password": jsii.String(base64.StdEncoding.EncodeToString([]byte(dbPass))),
			"redis-password":      jsii.String(base64.StdEncoding.EncodeToString([]byte(redisPass))),
		},
	})

	// ==========================================
	// 呼叫模組建立資源
	// ==========================================

	// DataStore (PostgreSQL, Redis)
	datastore.CreatePostgreSQL(chart)
	datastore.CreateRedis(chart)

	// Streaming (Kafka, Zookeeper, Flink)
	streaming.CreateKafkaAndZookeeper(chart)
	streaming.CreateFlink(chart)

	// Observability (PLG, Prometheus, Linkerd Auth, Dashboards)
	observability.CreateMonitoring(chart)
	observability.CreateDashboards(chart)

	// CI/CD (ArgoCD)
	cicd.CreateArgoCD(chart, argocdPass)

	return chart
}

func main() {
	app := cdk8s.NewApp(nil)
	fmt.Println("🚀 正在根據環境變數產生 Infar K8s 設定檔 (cdk8s)...")

	NewInfarInfra(app, "infar-infra", &cdk8s.ChartProps{
		Labels: &map[string]*string{"project": jsii.String("infar")},
	})

	app.Synth()
	fmt.Println("✅ 設定檔產生完成！請至 dist/ 目錄查看。")
}
