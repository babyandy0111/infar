package cicd

import (
	"log"
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"golang.org/x/crypto/bcrypt"
)

func CreateArgoCD(chart cdk8s.Chart, password string) {
	// 1. 將密碼加密 (ArgoCD 需要 bcrypt)
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("無法加密 ArgoCD 密碼: %v", err)
	}
	adminHash := string(hash)

	// 2. 環境判斷
	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	isGCP := env == "gcp"

	// 3. 雲端適配設定
	ingressClassName := "nginx"
	var host *string

	if isGCP {
		ingressClassName = "gce"
		host = nil // 雲端環境不綁定網域，直接認 IP
	} else {
		host = jsii.String("argocd.local")
	}

	// 4. 建立 ArgoCD Helm Chart
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
					"ingressClassName": ingressClassName,
					"hostname":         host,
					"annotations": map[string]interface{}{
						"kubernetes.io/ingress.class": nil, // 強制拔除預設的 nginx 標籤
					},
					"paths": []*string{
						jsii.String("/"),
					},
					"pathType": "Prefix",
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
