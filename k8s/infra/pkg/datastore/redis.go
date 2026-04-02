package datastore

import (
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateRedis(chart cdk8s.Chart) {
	label := map[string]*string{"app": jsii.String("redis")}

	k8s.NewKubeService(chart, jsii.String("redis-service"), &k8s.KubeServiceProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("redis-master"), Namespace: jsii.String("infra")},
		Spec: &k8s.ServiceSpec{
			Ports:    &[]*k8s.ServicePort{{Name: jsii.String("redis"), Port: jsii.Number(6379), TargetPort: k8s.IntOrString_FromNumber(jsii.Number(6379))}},
			Selector: &label,
		},
	})

	k8s.NewKubeStatefulSet(chart, jsii.String("redis-stack"), &k8s.KubeStatefulSetProps{
		Metadata: &k8s.ObjectMeta{Name: jsii.String("redis"), Namespace: jsii.String("infra"), Labels: &label},
		Spec: &k8s.StatefulSetSpec{
			ServiceName: jsii.String("redis-master"),
			Replicas:    jsii.Number(1),
			Selector:    &k8s.LabelSelector{MatchLabels: &label},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{
					Labels: &label,
					Annotations: &map[string]*string{
						"linkerd.io/inject":              jsii.String("enabled"),
						"config.linkerd.io/opaque-ports": jsii.String("6379"),
					},
				},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{{
						Name:  jsii.String("redis"),
						Image: jsii.String("redis/redis-stack-server:7.2.0-v6"),
						Env: &[]*k8s.EnvVar{
							{Name: jsii.String("REDIS_PASSWORD"), ValueFrom: &k8s.EnvVarSource{SecretKeyRef: &k8s.SecretKeySelector{Name: jsii.String("infra-secrets"), Key: jsii.String("redis-password")}}},
							{Name: jsii.String("REDIS_ARGS"), Value: jsii.String("--requirepass $(REDIS_PASSWORD)")},
						},
						Ports:        &[]*k8s.ContainerPort{{ContainerPort: jsii.Number(6379), Name: jsii.String("redis")}},
						VolumeMounts: &[]*k8s.VolumeMount{{Name: jsii.String("redis-data"), MountPath: jsii.String("/data")}},
					}},
				},
			},
			VolumeClaimTemplates: &[]*k8s.KubePersistentVolumeClaimProps{{
				Metadata: &k8s.ObjectMeta{Name: jsii.String("redis-data")},
				Spec: &k8s.PersistentVolumeClaimSpec{
					AccessModes: &[]*string{jsii.String("ReadWriteOnce")},
					Resources:   &k8s.ResourceRequirements{Requests: &map[string]k8s.Quantity{"storage": k8s.Quantity_FromString(jsii.String("2Gi"))}},
				},
			}},
		},
	})
}
