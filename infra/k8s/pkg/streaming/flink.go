package streaming

import (
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateFlink(chart cdk8s.Chart) {
	jmLabel := map[string]*string{"app": jsii.String("flink"), "component": jsii.String("jobmanager")}
	tmLabel := map[string]*string{"app": jsii.String("flink"), "component": jsii.String("taskmanager")}

	// 🚀 架構升級：使用我們自建的帶有驅動的 Image
	// 你需要執行: docker build -t babyandy0111/infar-flink:v1 ./infra/docker/flink
	flinkImage := jsii.String("babyandy0111/infar-flink:v1")

	// JobManager Service
	k8s.NewKubeService(chart, jsii.String("flink-jm-svc"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("flink-jobmanager"), Namespace: jsii.String("infra")},
		Spec: &k8s.ServiceSpec{
			Ports: &[]*k8s.ServicePort{
				{Name: jsii.String("rpc"), Port: jsii.Number(6123), TargetPort: k8s.IntOrString_FromNumber(jsii.Number(6123))},
				{Name: jsii.String("ui"), Port: jsii.Number(8081), TargetPort: k8s.IntOrString_FromNumber(jsii.Number(8081))},
			},
			Selector: &jmLabel,
		},
	})

	// JobManager Deployment
	k8s.NewKubeDeployment(chart, jsii.String("flink-jm-dep"), &k8s.KubeDeploymentProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("flink-jobmanager"), Namespace: jsii.String("infra")},
		Spec: &k8s.DeploymentSpec{
			Replicas: jsii.Number(1),
			Selector: &k8s.LabelSelector{MatchLabels: &jmLabel},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{
					Labels: &jmLabel,
					Annotations: &map[string]*string{
						"linkerd.io/inject":              jsii.String("enabled"),
						"config.linkerd.io/opaque-ports": jsii.String("6123"),
						"prometheus.io/scrape":           jsii.String("true"),
						"prometheus.io/port":             jsii.String("4191"),
					},
				},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("jobmanager"),
						Image: flinkImage,
						Args:  &[]*string{jsii.String("jobmanager")},
						Ports: &[]*k8s.ContainerPort{
							{ContainerPort: jsii.Number(6123)},
							{ContainerPort: jsii.Number(8081)},
						},
						Env: &[]*k8s.EnvVar{
							{
								Name:  jsii.String("JOB_MANAGER_RPC_ADDRESS"),
								Value: jsii.String("flink-jobmanager.infra.svc.cluster.local"),
							},
						},
					}},
				},
			},
		},
	})

	// TaskManager Deployment
	k8s.NewKubeDeployment(chart, jsii.String("flink-tm-dep"), &k8s.KubeDeploymentProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("flink-taskmanager"), Namespace: jsii.String("infra")},
		Spec: &k8s.DeploymentSpec{
			Replicas: jsii.Number(1),
			Selector: &k8s.LabelSelector{MatchLabels: &tmLabel},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{
					Labels: &tmLabel,
					Annotations: &map[string]*string{
						"linkerd.io/inject":              jsii.String("enabled"),
						"config.linkerd.io/opaque-ports": jsii.String("6123"),
						"prometheus.io/scrape":           jsii.String("true"),
						"prometheus.io/port":             jsii.String("4191"),
					},
				},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("taskmanager"),
						Image: flinkImage,
						Args:  &[]*string{jsii.String("taskmanager")},
						Env: &[]*k8s.EnvVar{
							{
								Name:  jsii.String("JOB_MANAGER_RPC_ADDRESS"),
								Value: jsii.String("flink-jobmanager.infra.svc.cluster.local"),
							},
						},
					}},
				},
			},
		},
	})

	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	isGCP := env == "gcp"
	isLocal := env == "" || env == "local"

	ingressAnnotations := map[string]*string{}
	if !isGCP {
		ingressAnnotations["kubernetes.io/ingress.class"] = jsii.String("nginx")
	}

	var host *string
	if isLocal {
		host = jsii.String("flink.local")
	} else {
		host = nil
	}

	// Ingress
	k8s.NewKubeIngress(chart, jsii.String("flink-ing"), &k8s.KubeIngressProps{
		Metadata: &k8s.ObjectMeta{
			Name:        jsii.String("flink-ui"),
			Namespace:   jsii.String("infra"),
			Annotations: &ingressAnnotations,
		},
		Spec: &k8s.IngressSpec{
			Rules: &[]*k8s.IngressRule{{
				Host: host,
				Http: &k8s.HttpIngressRuleValue{
					Paths: &[]*k8s.HttpIngressPath{{
						Path:     jsii.String("/"),
						PathType: jsii.String("Prefix"),
						Backend: &k8s.IngressBackend{
							Service: &k8s.IngressServiceBackend{
								Name: jsii.String("flink-jobmanager"),
								Port: &k8s.ServiceBackendPort{Number: jsii.Number(8081)},
							},
						},
					}},
				},
			}},
		},
	})
}
