package streaming

import (
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateKafkaAndZookeeper(chart cdk8s.Chart) {
	// ZK
	zkLabel := map[string]*string{"app": jsii.String("zookeeper")}
	k8s.NewKubeService(chart, jsii.String("zookeeper-svc"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("zookeeper"), Namespace: jsii.String("infra")},
		Spec:     &k8s.ServiceSpec{Ports: &[]*k8s.ServicePort{{Name: jsii.String("client"), Port: jsii.Number(2181), TargetPort: k8s.IntOrString_FromNumber(jsii.Number(2181))}}, Selector: &zkLabel},
	})

	k8s.NewKubeDeployment(chart, jsii.String("zookeeper-deploy"), &k8s.KubeDeploymentProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("zookeeper"), Namespace: jsii.String("infra")},
		Spec: &k8s.DeploymentSpec{
			Replicas: jsii.Number(1),
			Selector: &k8s.LabelSelector{MatchLabels: &zkLabel},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{Labels: &zkLabel},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{Name: jsii.String("zookeeper"), Image: jsii.String("zookeeper:3.8.3"), Env: &[]*k8s.EnvVar{{Name: jsii.String("ALLOW_ANONYMOUS_LOGIN"), Value: jsii.String("yes")}}, Ports: &[]*k8s.ContainerPort{{ContainerPort: jsii.Number(2181)}}}},
				},
			},
		},
	})

	// Kafka
	kLabel := map[string]*string{"app": jsii.String("kafka")}
	anno := map[string]*string{
		"prometheus.io/scrape":           jsii.String("true"),
		"prometheus.io/port":             jsii.String("4191"),
		"prometheus.io/path":             jsii.String("/metrics"),
		"config.linkerd.io/opaque-ports": jsii.String("9092,2181"),
	}

	k8s.NewKubeService(chart, jsii.String("kafka-svc"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("kafka-service"), Namespace: jsii.String("infra")},
		Spec:     &k8s.ServiceSpec{Ports: &[]*k8s.ServicePort{{Name: jsii.String("broker"), Port: jsii.Number(9092), TargetPort: k8s.IntOrString_FromNumber(jsii.Number(9092))}}, Selector: &kLabel},
	})

	k8s.NewKubeStatefulSet(chart, jsii.String("kafka-sts"), &k8s.KubeStatefulSetProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("kafka"), Namespace: jsii.String("infra"), Annotations: &anno},
		Spec: &k8s.StatefulSetSpec{
			ServiceName: jsii.String("kafka"),
			Replicas:    jsii.Number(1),
			Selector:    &k8s.LabelSelector{MatchLabels: &kLabel},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{Labels: &kLabel},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("kafka"),
						Image: jsii.String("wurstmeister/kafka:2.13-2.8.1"),
						Ports: &[]*k8s.ContainerPort{{ContainerPort: jsii.Number(9092)}},
						Env: &[]*k8s.EnvVar{
							{Name: jsii.String("KAFKA_BROKER_ID"), Value: jsii.String("1")},
							{Name: jsii.String("KAFKA_ZOOKEEPER_CONNECT"), Value: jsii.String("zookeeper:2181")},
							{Name: jsii.String("KAFKA_LISTENERS"), Value: jsii.String("PLAINTEXT://0.0.0.0:9092")},
							{Name: jsii.String("KAFKA_ADVERTISED_LISTENERS"), Value: jsii.String("PLAINTEXT://kafka-service.infra.svc.cluster.local:9092")},
							{Name: jsii.String("KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"), Value: jsii.String("1")},
						},
						VolumeMounts: &[]*k8s.VolumeMount{{Name: jsii.String("data"), MountPath: jsii.String("/kafka")}},
					}},
				},
			},
			VolumeClaimTemplates: &[]*k8s.KubePersistentVolumeClaimProps{{
				Metadata: &k8s.ObjectMeta{Name: jsii.String("data")},
				Spec:     &k8s.PersistentVolumeClaimSpec{AccessModes: &[]*string{jsii.String("ReadWriteOnce")}, Resources: &k8s.ResourceRequirements{Requests: &map[string]k8s.Quantity{"storage": k8s.Quantity_FromString(jsii.String("2Gi"))}}},
			}},
		},
	})
}
