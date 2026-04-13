package datastore

import (
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateClickHouse(chart cdk8s.Chart) {
	label := map[string]*string{"app": jsii.String("clickhouse")}

	// 1. ClickHouse Service
	k8s.NewKubeService(chart, jsii.String("clickhouse-svc"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("clickhouse"),
			Namespace: jsii.String("infra"),
		},
		Spec: &k8s.ServiceSpec{
			Ports: &[]*k8s.ServicePort{
				{Name: jsii.String("http"), Port: jsii.Number(8123)},
				{Name: jsii.String("tcp"), Port: jsii.Number(9000)},
			},
			Selector: &label,
		},
	})

	// 2. ClickHouse StatefulSet
	k8s.NewKubeStatefulSet(chart, jsii.String("clickhouse-sts"), &k8s.KubeStatefulSetProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("clickhouse"),
			Namespace: jsii.String("infra"),
		},
		Spec: &k8s.StatefulSetSpec{
			Replicas:    jsii.Number(1),
			ServiceName: jsii.String("clickhouse"),
			Selector:    &k8s.LabelSelector{MatchLabels: &label},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{Labels: &label},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("clickhouse"),
						Image: jsii.String("clickhouse/clickhouse-server:24.3"),
						Ports: &[]*k8s.ContainerPort{
							{ContainerPort: jsii.Number(8123)},
							{ContainerPort: jsii.Number(9000)},
						},
						Env: &[]*k8s.EnvVar{
							{Name: jsii.String("CLICKHOUSE_DB"), Value: jsii.String("infar_iot")},
							{Name: jsii.String("CLICKHOUSE_USER"), Value: jsii.String("infar_admin")},
							{
								Name: jsii.String("CLICKHOUSE_PASSWORD"),
								ValueFrom: &k8s.EnvVarSource{
									SecretKeyRef: &k8s.SecretKeySelector{
										Name: jsii.String("infra-secrets"),
										Key:  jsii.String("clickhouse-password"),
									},
								},
							},
						},
					}},
				},
			},
		},
	})

	// 3. Ingress for ClickHouse.local
	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	isLocal := env == "" || env == "local"

	if isLocal {
		k8s.NewKubeIngress(chart, jsii.String("clickhouse-ing"), &k8s.KubeIngressProps{
			Metadata: &k8s.ObjectMeta{
				Name:      jsii.String("clickhouse-ui"),
				Namespace: jsii.String("infra"),
				Annotations: &map[string]*string{
					"kubernetes.io/ingress.class": jsii.String("nginx"),
				},
			},
			Spec: &k8s.IngressSpec{
				IngressClassName: jsii.String("nginx"),
				Rules: &[]*k8s.IngressRule{{
					Host: jsii.String("clickhouse.local"),
					Http: &k8s.HttpIngressRuleValue{
						Paths: &[]*k8s.HttpIngressPath{{
							Path:     jsii.String("/"),
							PathType: jsii.String("Prefix"),
							Backend: &k8s.IngressBackend{
								Service: &k8s.IngressServiceBackend{
									Name: jsii.String("clickhouse"),
									Port: &k8s.ServiceBackendPort{Number: jsii.Number(8123)},
								},
							},
						}},
					},
				}},
			},
		})
	}
}
