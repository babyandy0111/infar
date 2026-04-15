package datastore

import (
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
	"os"
)

func CreateElasticsearch(chart cdk8s.Chart) {
	label := map[string]*string{"app": jsii.String("elasticsearch")}

	// 1. Elasticsearch Service
	k8s.NewKubeService(chart, jsii.String("es-svc"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("elasticsearch-service"),
			Namespace: jsii.String("infra"),
		},
		Spec: &k8s.ServiceSpec{
			Ports: &[]*k8s.ServicePort{
				{Name: jsii.String("http"), Port: jsii.Number(9200)},
			},
			Selector: &label,
		},
	})

	// 2. Elasticsearch StatefulSet (Single Node)
	k8s.NewKubeStatefulSet(chart, jsii.String("es-sts"), &k8s.KubeStatefulSetProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("elasticsearch"),
			Namespace: jsii.String("infra"),
		},
		Spec: &k8s.StatefulSetSpec{
			Replicas:    jsii.Number(1),
			ServiceName: jsii.String("elasticsearch-service"),
			Selector:    &k8s.LabelSelector{MatchLabels: &label},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{
					Labels: &label,
					Annotations: &map[string]*string{
						"prometheus.io/scrape": jsii.String("true"),
						"prometheus.io/port":   jsii.String("9200"),
					},
				},
				Spec: &k8s.PodSpec{
					InitContainers: &[]*k8s.Container{
						{
							Name:    jsii.String("fix-permissions"),
							Image:   jsii.String("busybox"),
							Command: &[]*string{jsii.String("sh"), jsii.String("-c"), jsii.String("chown -R 1000:1000 /usr/share/elasticsearch/data")},
							VolumeMounts: &[]*k8s.VolumeMount{
								{Name: jsii.String("data"), MountPath: jsii.String("/usr/share/elasticsearch/data")},
							},
						},
						{
							Name:            jsii.String("increase-vm-max-map"),
							Image:           jsii.String("busybox"),
							Command:         &[]*string{jsii.String("sh"), jsii.String("-c"), jsii.String("sysctl -w vm.max_map_count=262144 || true")},
							SecurityContext: &k8s.SecurityContext{Privileged: jsii.Bool(true)},
						},
					},
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("elasticsearch"),
						Image: jsii.String("elasticsearch:7.17.21"),
						Ports: &[]*k8s.ContainerPort{
							{ContainerPort: jsii.Number(9200)},
						},
						Env: &[]*k8s.EnvVar{
							{Name: jsii.String("discovery.type"), Value: jsii.String("single-node")},
							{Name: jsii.String("ES_JAVA_OPTS"), Value: jsii.String("-Xms512m -Xmx512m")},
							{Name: jsii.String("xpack.security.enabled"), Value: jsii.String("false")},
						},
						VolumeMounts: &[]*k8s.VolumeMount{
							{Name: jsii.String("data"), MountPath: jsii.String("/usr/share/elasticsearch/data")},
						},
					}},
				},
			},
			VolumeClaimTemplates: &[]*k8s.KubePersistentVolumeClaimProps{
				{
					Metadata: &k8s.ObjectMeta{Name: jsii.String("data")},
					Spec: &k8s.PersistentVolumeClaimSpec{
						AccessModes: &[]*string{jsii.String("ReadWriteOnce")},
						Resources: &k8s.ResourceRequirements{
							Requests: &map[string]k8s.Quantity{"storage": k8s.Quantity_FromString(jsii.String("5Gi"))},
						},
					},
				},
			},
		},
	})

	// 3. Ingress for elasticsearch.local
	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	isLocal := env == "" || env == "local"

	if isLocal {
		k8s.NewKubeIngress(chart, jsii.String("elasticsearch-ing"), &k8s.KubeIngressProps{
			Metadata: &k8s.ObjectMeta{
				Name:      jsii.String("elasticsearch-ui"),
				Namespace: jsii.String("infra"),
				Annotations: &map[string]*string{
					"kubernetes.io/ingress.class": jsii.String("nginx"),
				},
			},
			Spec: &k8s.IngressSpec{
				IngressClassName: jsii.String("nginx"),
				Rules: &[]*k8s.IngressRule{{
					Host: jsii.String("elasticsearch.local"),
					Http: &k8s.HttpIngressRuleValue{
						Paths: &[]*k8s.HttpIngressPath{{
							Path:     jsii.String("/"),
							PathType: jsii.String("Prefix"),
							Backend: &k8s.IngressBackend{
								Service: &k8s.IngressServiceBackend{
									Name: jsii.String("elasticsearch-service"),
									Port: &k8s.ServiceBackendPort{Number: jsii.Number(9200)},
								},
							},
						}},
					},
				}},
			},
		})
	}
}
