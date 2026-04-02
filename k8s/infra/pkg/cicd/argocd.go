package cicd

import (
	"log"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"golang.org/x/crypto/bcrypt"
)

func CreateArgoCD(chart cdk8s.Chart, adminPassword string) {
	// 將明文密碼透過 Bcrypt 加密 (ArgoCD 要求)
	hash, err := bcrypt.GenerateFromPassword([]byte(adminPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("無法加密 ArgoCD 密碼: %v", err)
	}
	adminHash := string(hash)

	cdk8s.NewHelm(chart, jsii.String("argocd"), &cdk8s.HelmProps{
		Chart:       jsii.String("argo/argo-cd"),
		Version:     jsii.String("9.4.17"),
		Namespace:   jsii.String("argocd"),
		ReleaseName: jsii.String("argocd"),
		Values: &map[string]interface{}{
			"fullnameOverride": "argocd",
			"nameOverride":     "argocd",
			"redis": map[string]interface{}{
				"secret": map[string]interface{}{
					"createInitJob": false,
				},
			},
			"server": map[string]interface{}{
				"service": map[string]interface{}{
					"type": "NodePort",
				},
				"extraArgs": []*string{
					jsii.String("--insecure"),
				},
				"ingress": map[string]interface{}{
					"enabled":          true,
					"ingressClassName": "nginx",
					"hostname":         "argocd.local",
					"paths": []*string{
						jsii.String("/"),
					},
					"pathType": "Prefix",
					"annotations": map[string]interface{}{
						"kubernetes.io/ingress.class": "nginx",
					},
				},
			},
			"configs": map[string]interface{}{
				"secret": map[string]interface{}{
					"argocdServerAdminPassword": adminHash,
					"createSecret":              true,
				},
			},
		},
	})
}
