package cicd

import (
	"log"
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"golang.org/x/crypto/bcrypt"
)

func CreateArgoCD(chart cdk8s.Chart, password string) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("無法加密 ArgoCD 密碼: %v", err)
	}
	adminHash := string(hash)

	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	isGCP := env == "gcp"

	// 根據環境動態生成 Ingress 設定
	var ingressValues map[string]interface{}
	if isGCP {
		// 🚀 GCP 雲端極限設定：解決 GCE Health Check 失敗問題
		ingressValues = map[string]interface{}{
			"enabled":          true,
			"ingressClassName": jsii.String("gce"),
			"hosts":            []interface{}{}, // 徹底移除預設的 example.com
			"https":            false,           // 雲端內部強迫走 HTTP
			"annotations": map[string]interface{}{
				"kubernetes.io/ingress.class": nil,
			},
			"paths":    []*string{jsii.String("/")},
			"pathType": "Prefix",
		}
	} else {
		// 🏠 Local 模式：保留漂亮的虛擬網域
		ingressValues = map[string]interface{}{
			"enabled":          true,
			"ingressClassName": jsii.String("nginx"),
			"hostname":         jsii.String("argocd.local"),
			"paths":            []*string{jsii.String("/")},
			"pathType":         "Prefix",
		}
	}

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
				"ingress": ingressValues, // 🚀 注入動態生成的環境設定
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
