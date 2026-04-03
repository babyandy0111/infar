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

func NewInfarDatastore(scope constructs.Construct, id string, props *cdk8s.ChartProps) cdk8s.Chart {
	chart := cdk8s.NewChart(scope, jsii.String(id), props)
	_ = godotenv.Load(".env")
	dbPass := os.Getenv("DB_PASSWORD")
	redisPass := os.Getenv("REDIS_PASSWORD")

	if dbPass == "" || redisPass == "" {
		log.Fatal("錯誤：.env 中缺少必須的資料庫密碼設定 (DB_PASSWORD 或 REDIS_PASSWORD)！")
	}

	// 建立 K8s Secret (安全管理密碼)
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

	datastore.CreatePostgreSQL(chart)
	datastore.CreateRedis(chart)
	return chart
}

func NewInfarStreaming(scope constructs.Construct, id string, props *cdk8s.ChartProps) cdk8s.Chart {
	chart := cdk8s.NewChart(scope, jsii.String(id), props)
	streaming.CreateKafkaAndZookeeper(chart)
	streaming.CreateFlink(chart)
	return chart
}

func NewInfarObservability(scope constructs.Construct, id string, props *cdk8s.ChartProps) cdk8s.Chart {
	chart := cdk8s.NewChart(scope, jsii.String(id), props)
	observability.CreateMonitoring(chart)
	observability.CreateDashboards(chart)
	return chart
}

func NewInfarCicd(scope constructs.Construct, id string, props *cdk8s.ChartProps) cdk8s.Chart {
	chart := cdk8s.NewChart(scope, jsii.String(id), props)
	_ = godotenv.Load(".env")
	argocdPass := os.Getenv("ARGOCD_ADMIN_PASSWORD")
	cicd.CreateArgoCD(chart, argocdPass)
	return chart
}

func main() {
	app := cdk8s.NewApp(nil)
	fmt.Println("🚀 正在根據環境變數產生 Infar K8s 設定檔 (多檔模式)...")

	commonProps := &cdk8s.ChartProps{
		Labels: &map[string]*string{"project": jsii.String("infar")},
	}

	NewInfarDatastore(app, "01-datastore", commonProps)
	// 🚀 架構輕量化決策：暫停部署巨型串流模組 (Kafka, Flink)，改以 Redis Stream 取代
	// NewInfarStreaming(app, "02-streaming", commonProps)
	NewInfarObservability(app, "03-observability", commonProps)
	NewInfarCicd(app, "04-cicd", commonProps)

	app.Synth()
	fmt.Println("✅ 設定檔產生完成！請至 dist/ 目錄查看分類的 YAML 檔案。")
}
