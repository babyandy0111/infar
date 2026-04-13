package streaming

import (
	"os"

	"infar-infra/imports/k8s"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
)

func CreateFlink(chart cdk8s.Chart) {
	jmLabel := map[string]*string{"app": jsii.String("flink"), "component": jsii.String("jobmanager")}
	tmLabel := map[string]*string{"app": jsii.String("flink"), "component": jsii.String("taskmanager")}
	jobLabel := map[string]*string{"app": jsii.String("flink"), "component": jsii.String("sql-runner")}

	flinkImage := jsii.String("babyandy0111/infar-flink:v1")
	pullPolicy := jsii.String("Always")

	// 1. JobManager Service
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

	// 2. JobManager Deployment
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
						Name:            jsii.String("jobmanager"),
						Image:           flinkImage,
						ImagePullPolicy: pullPolicy,
						Args:            &[]*string{jsii.String("jobmanager")},
						Resources: &k8s.ResourceRequirements{
							Requests: &map[string]k8s.Quantity{
								"cpu":    k8s.Quantity_FromString(jsii.String("500m")),
								"memory": k8s.Quantity_FromString(jsii.String("1Gi")),
							},
							Limits: &map[string]k8s.Quantity{
								"cpu":    k8s.Quantity_FromString(jsii.String("1")),
								"memory": k8s.Quantity_FromString(jsii.String("2Gi")),
							},
						},
						Ports: &[]*k8s.ContainerPort{
							{ContainerPort: jsii.Number(6123)},
							{ContainerPort: jsii.Number(8081)},
						},
						Env: &[]*k8s.EnvVar{
							{
								Name:  jsii.String("JOB_MANAGER_RPC_ADDRESS"),
								Value: jsii.String("flink-jobmanager.infra.svc.cluster.local"),
							},
							{
								Name:  jsii.String("TASK_MANAGER_NUMBER_OF_TASK_SLOTS"),
								Value: jsii.String("4"),
							},
						},
					}},
				},
			},
		},
	})

	// 3. TaskManager Deployment
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
						Name:            jsii.String("taskmanager"),
						Image:           flinkImage,
						ImagePullPolicy: pullPolicy,
						Args:            &[]*string{jsii.String("taskmanager")},
						Resources: &k8s.ResourceRequirements{
							Requests: &map[string]k8s.Quantity{
								"cpu":    k8s.Quantity_FromString(jsii.String("1")),
								"memory": k8s.Quantity_FromString(jsii.String("2Gi")),
							},
							Limits: &map[string]k8s.Quantity{
								"cpu":    k8s.Quantity_FromString(jsii.String("2")),
								"memory": k8s.Quantity_FromString(jsii.String("4Gi")),
							},
						},
						Env: &[]*k8s.EnvVar{
							{
								Name:  jsii.String("JOB_MANAGER_RPC_ADDRESS"),
								Value: jsii.String("flink-jobmanager.infra.svc.cluster.local"),
							},
							{
								Name:  jsii.String("TASK_MANAGER_NUMBER_OF_TASK_SLOTS"),
								Value: jsii.String("4"),
							},
						},
					}},
				},
			},
		},
	})

	// 🚀 4. 自動任務啟動器 (SQL Runner Job) - 增強版
	k8s.NewKubeJob(chart, jsii.String("flink-sql-runner"), &k8s.KubeJobProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("flink-sql-runner"), Namespace: jsii.String("infra")},
		Spec: &k8s.JobSpec{
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{Labels: &jobLabel},
				Spec: &k8s.PodSpec{
					RestartPolicy: jsii.String("OnFailure"),
					Containers: &[]*k8s.Container{{
						Name:            jsii.String("sql-runner"),
						Image:           flinkImage,
						ImagePullPolicy: pullPolicy,
						Env: &[]*k8s.EnvVar{
							{
								Name:  jsii.String("FLINK_PROPERTIES"),
								Value: jsii.String("jobmanager.rpc.address: flink-jobmanager.infra.svc.cluster.local\nrest.address: flink-jobmanager.infra.svc.cluster.local"),
							},
						},
						Command: &[]*string{
							jsii.String("sh"),
							jsii.String("-c"),
							jsii.String(`
								echo "⏳ Waiting for Flink JobManager..."
								until curl -s http://flink-jobmanager:8081/overview; do sleep 5; done
								echo "🚀 Flink is up! Attempting to submit Order Processor SQL..."
								
								# 強制設定 SQL Client 連線位址
								echo "rest.address: flink-jobmanager.infra.svc.cluster.local" >> /opt/flink/conf/flink-conf.yaml
								
								# 💡 加入重試機制，直到 SQL 提交成功 (避免資料庫連線尚未就緒的瞬時錯誤)
								MAX_RETRIES=5
								COUNT=0
								until ./bin/sql-client.sh -f /opt/flink/jobs/order_processor.sql || [ $COUNT -eq $MAX_RETRIES ]; do
									echo "⚠️  Submit failed, retrying in 10s... ($((COUNT+1))/$MAX_RETRIES)"
									sleep 10
									COUNT=$((COUNT+1))
								done
								
								if [ $COUNT -eq $MAX_RETRIES ]; then
									echo "❌ Failed to submit SQL after $MAX_RETRIES attempts."
									exit 1
								fi
								echo "✅ SQL submitted successfully!"
							`),
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

	// 5. Ingress
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
