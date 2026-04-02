package datastore

import (
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
)

func CreatePostgreSQL(chart cdk8s.Chart) {
	cdk8s.NewHelm(chart, jsii.String("postgres"), &cdk8s.HelmProps{
		Chart:     jsii.String("bitnami/postgresql"),
		Version:   jsii.String("18.5.14"),
		Namespace: jsii.String("infra"),
		Values: &map[string]interface{}{
			"auth": map[string]interface{}{
				"database":       "infar_db",
				"username":       "admin",
				"existingSecret": "infra-secrets",
				"secretKeys": map[string]interface{}{
					"adminPasswordKey": "postgresql-password",
					"userPasswordKey":  "postgresql-password",
				},
			},
			"architecture": "standalone",
			"primary": map[string]interface{}{
				"podAnnotations": map[string]interface{}{
					"config.linkerd.io/opaque-ports": "5432",
				},
			},
		},
	})
}
