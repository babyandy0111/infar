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
	isLocal := env == "" || env == "local"
	isAWS := env == "aws"
	isGCP := env == "gcp"

	// 根據環境動態生成 Ingress 與 Service 設定
	var ingressValues map[string]interface{}
	var serviceType string
	var serviceAnnotations map[string]interface{}

	if isLocal {
		// 🏠 Local 模式：保留 NodePort 與漂亮的虛擬網域 (Nginx Ingress)
		serviceType = "NodePort"
		serviceAnnotations = map[string]interface{}{}
		ingressValues = map[string]interface{}{
			"enabled":          true,
			"ingressClassName": jsii.String("nginx"),
			"hostname":         jsii.String("argocd.local"),
			"paths":            []*string{jsii.String("/")},
			"pathType":         "Prefix",
		}
	} else if isAWS {
		// ☁️ AWS 模式：強制使用 NLB 並針對 Fargate 進行 IP 模式對接
		serviceType = "LoadBalancer"
		serviceAnnotations = map[string]interface{}{
			"service.beta.kubernetes.io/aws-load-balancer-type":            jsii.String("nlb"),
			"service.beta.kubernetes.io/aws-load-balancer-scheme":          jsii.String("internet-facing"),
			"service.beta.kubernetes.io/aws-load-balancer-nlb-target-type": jsii.String("ip"),
			// 強制 Health Check 設定，解決 "一直轉圈圈" 的問題
			"service.beta.kubernetes.io/aws-load-balancer-healthcheck-port":     jsii.String("8080"),
			"service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol": jsii.String("HTTP"),
			"service.beta.kubernetes.io/aws-load-balancer-healthcheck-path":     jsii.String("/healthz"),
		}
		ingressValues = map[string]interface{}{
			"enabled": false,
		}
	} else if isGCP {
		// ☁️ GCP 模式：使用 GCP 外部負載均衡器
		serviceType = "LoadBalancer"
		serviceAnnotations = map[string]interface{}{
			"cloud.google.com/load-balancer-type": jsii.String("External"),
		}
		ingressValues = map[string]interface{}{
			"enabled": false,
		}
	} else {
		// 預設雲端模式：基本的 LoadBalancer
		serviceType = "LoadBalancer"
		serviceAnnotations = map[string]interface{}{}
		ingressValues = map[string]interface{}{
			"enabled": false,
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
					"type":        serviceType,
					"annotations": serviceAnnotations,
				},
				"extraArgs": []*string{
					jsii.String("--insecure"),
				},
				"ingress": ingressValues,
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
