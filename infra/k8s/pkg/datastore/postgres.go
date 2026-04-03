package datastore

import (
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreatePostgreSQL(chart cdk8s.Chart) {
	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	dbUser := os.Getenv("DB_USER")
	dbName := os.Getenv("DB_NAME")

	// Fallback 預設值
	if dbUser == "" {
		dbUser = "admin"
	}
	if dbName == "" {
		dbName = "infar_db"
	}

	// 1. 雲端環境邏輯：建立對應外部 RDS 的橋樑
	if env != "" && env != "local" {
		endpoint := os.Getenv("DB_ENDPOINT")
		if endpoint == "" {
			endpoint = "rds-postgres.internal.aws"
		}

		k8s.NewKubeService(chart, jsii.String("postgres-cloud-svc"), &k8s.KubeServiceProps{
			Metadata: &k8s.ObjectMeta{
				Name:      jsii.String("postgres"),
				Namespace: jsii.String("infra"),
			},
			Spec: &k8s.ServiceSpec{
				Type:         jsii.String("ExternalName"),
				ExternalName: jsii.String(endpoint),
			},
		})
		return
	}

	// 2. 本機環境邏輯：部署 K8s 內部 Pod
	cdk8s.NewHelm(chart, jsii.String("postgres"), &cdk8s.HelmProps{
		Chart:       jsii.String("bitnami/postgresql"),
		Version:     jsii.String("18.5.14"),
		Namespace:   jsii.String("infra"),
		ReleaseName: jsii.String("postgres"),
		Values: &map[string]interface{}{
			"fullnameOverride": "postgres",
			"nameOverride":     "postgres",
			"auth": map[string]interface{}{
				"database":       dbName,
				"username":       dbUser,
				"existingSecret": "infra-secrets",
				"secretKeys": map[string]interface{}{
					"adminPasswordKey": "postgresql-password",
					"userPasswordKey":  "postgresql-password",
				},
			},
			"architecture": "standalone",
			"primary": map[string]interface{}{
				"podAnnotations": map[string]interface{}{
					"linkerd.io/inject":              "enabled",
					"config.linkerd.io/opaque-ports": "5432",
				},
			},
		},
	})
}
