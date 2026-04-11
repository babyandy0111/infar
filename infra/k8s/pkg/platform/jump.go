package platform

import (
	"os"

	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateJumpPod(chart cdk8s.Chart) {
	env := os.Getenv("INFAR_CLOUD_PROVIDER")
	if env == "" || env == "local" {
		return
	}

	dbEndpoint := os.Getenv("DB_ENDPOINT")
	redisEndpoint := os.Getenv("REDIS_ENDPOINT")

	label := map[string]*string{"app": jsii.String("jump")}

	// 建立 Jump Pod (極簡穩定版 5.0)
	k8s.NewKubeDeployment(chart, jsii.String("jump-dep"), &k8s.KubeDeploymentProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("jump"),
			Namespace: jsii.String("infra"),
		},
		Spec: &k8s.DeploymentSpec{
			Replicas: jsii.Number(1),
			Selector: &k8s.LabelSelector{MatchLabels: &label},
			Template: &k8s.PodTemplateSpec{
				Metadata: &k8s.ObjectMeta{Labels: &label},
				Spec: &k8s.PodSpec{
					Containers: &[]*k8s.Container{
						{
							Name:  jsii.String("postgres"),
							Image: jsii.String("alpine/socat:latest"),
							Args: &[]*string{
								jsii.String("-d"), jsii.String("-d"),
								jsii.String("TCP4-LISTEN:5432,fork,reuseaddr"),
								jsii.String("TCP4:" + dbEndpoint + ":5432"),
							},
							Ports: &[]*k8s.ContainerPort{{ContainerPort: jsii.Number(5432)}},
						},
						{
							Name:  jsii.String("redis"),
							Image: jsii.String("alpine/socat:latest"),
							Args: &[]*string{
								jsii.String("-d"), jsii.String("-d"),
								jsii.String("TCP4-LISTEN:6379,fork,reuseaddr"),
								jsii.String("TCP4:" + redisEndpoint + ":6379"),
							},
							Ports: &[]*k8s.ContainerPort{{ContainerPort: jsii.Number(6379)}},
						},
					},
				},
			},
		},
	})
}
