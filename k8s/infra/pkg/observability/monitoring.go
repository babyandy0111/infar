package observability

import (
	"github.com/aws/jsii-runtime-go"
	"github.com/cdk8s-team/cdk8s-core-go/cdk8s/v2"
	"infar-infra/imports/k8s"
)

func CreateMonitoring(chart cdk8s.Chart) {
	// 1. Prometheus
	cdk8s.NewHelm(chart, jsii.String("prometheus"), &cdk8s.HelmProps{
		Chart:     jsii.String("prometheus-community/prometheus"),
		Version:   jsii.String("25.27.0"),
		Namespace: jsii.String("observability"),
		Values: &map[string]interface{}{
			"server":       map[string]interface{}{"persistentVolume": map[string]interface{}{"enabled": false}},
			"alertmanager": map[string]interface{}{"enabled": false},
			"pushgateway":  map[string]interface{}{"enabled": false},
		},
	})

	// 2. Loki
	cdk8s.NewHelm(chart, jsii.String("loki"), &cdk8s.HelmProps{
		Chart:     jsii.String("grafana/loki"),
		Version:   jsii.String("6.55.0"),
		Namespace: jsii.String("observability"),
		Values: &map[string]interface{}{
			"loki": map[string]interface{}{
				"auth_enabled": false,
				"commonConfig": map[string]interface{}{"replication_factor": 1},
				"storage":      map[string]interface{}{"type": "filesystem"},
				"schemaConfig": map[string]interface{}{
					"configs": []interface{}{
						map[string]interface{}{
							"from": "2024-04-01", "store": "tsdb", "object_store": "filesystem", "schema": "v13",
							"index": map[string]interface{}{"prefix": "index_", "period": "24h"},
						},
					},
				},
			},
			"singleBinary":   map[string]interface{}{"replicas": 1},
			"deploymentMode": "SingleBinary",
			"backend":        map[string]interface{}{"replicas": 0},
			"read":           map[string]interface{}{"replicas": 0},
			"write":          map[string]interface{}{"replicas": 0},
			"chunksCache":    map[string]interface{}{"enabled": false},
			"resultsCache":   map[string]interface{}{"enabled": false},
		},
	})

	// 3. Promtail
	cdk8s.NewHelm(chart, jsii.String("promtail"), &cdk8s.HelmProps{
		Chart:     jsii.String("grafana/promtail"),
		Version:   jsii.String("6.17.1"),
		Namespace: jsii.String("observability"),
		Values: &map[string]interface{}{
			"config": map[string]interface{}{
				"clients": []interface{}{
					map[string]interface{}{"url": "http://loki-gateway.observability.svc.cluster.local:3100/loki/api/v1/push"},
				},
			},
		},
	})

	// 4. Grafana
	cdk8s.NewHelm(chart, jsii.String("grafana"), &cdk8s.HelmProps{
		Chart:     jsii.String("grafana/grafana"),
		Version:   jsii.String("10.5.15"),
		Namespace: jsii.String("observability"),
		Values: &map[string]interface{}{
			"adminPassword":            "admin",
			"service":                  map[string]interface{}{"type": "NodePort"},
			"persistence":              map[string]interface{}{"enabled": true, "size": "2Gi"},
			"podSecurityContext":       map[string]interface{}{"runAsUser": 472, "runAsGroup": 472, "fsGroup": 472},
			"containerSecurityContext": map[string]interface{}{"runAsUser": 472, "runAsGroup": 472},
			"initChownData":            map[string]interface{}{"enabled": false},
			"ingress": map[string]interface{}{
				"enabled": true, "hosts": []*string{jsii.String("grafana.local")}, "ingressClassName": "nginx",
			},
			"datasources": map[string]interface{}{
				"datasources.yaml": map[string]interface{}{
					"apiVersion": 1,
					"datasources": []interface{}{
						map[string]interface{}{"name": "Loki", "type": "loki", "access": "proxy", "url": "http://loki-gateway.observability.svc.cluster.local", "isDefault": true},
						map[string]interface{}{"name": "Prometheus", "type": "prometheus", "access": "proxy", "url": "http://prometheus-server.observability.svc.cluster.local"},
						map[string]interface{}{"name": "Linkerd-Prometheus", "type": "prometheus", "uid": "Linkerd-Prometheus", "access": "proxy", "url": "http://prometheus.linkerd-viz.svc.cluster.local:9090"},
					},
				},
			},
			"dashboardProviders": map[string]interface{}{
				"dashboardproviders.yaml": map[string]interface{}{
					"apiVersion": 1,
					"providers": []interface{}{
						map[string]interface{}{"name": "Infar", "orgId": 1, "folder": "Infar Custom", "type": "file", "options": map[string]interface{}{"path": "/var/lib/grafana/dashboards/infar"}},
					},
				},
			},
			"dashboardsConfigMaps": map[string]interface{}{
				"infar": "infar-warroom-v2", // 關鍵修正：名稱必須匹配
			},
		},
	})

	// 5. Linkerd Auth Policy (解決 403)
	serverObj := cdk8s.NewApiObject(chart, jsii.String("linkerd-server"), &cdk8s.ApiObjectProps{
		ApiVersion: jsii.String("policy.linkerd.io/v1beta3"),
		Kind:       jsii.String("Server"),
		Metadata:   &cdk8s.ApiObjectMetadata{Name: jsii.String("prometheus-admin"), Namespace: jsii.String("linkerd-viz")},
	})
	serverObj.AddJsonPatch(cdk8s.JsonPatch_Add(jsii.String("/spec"), map[string]interface{}{
		"podSelector": map[string]interface{}{"matchLabels": map[string]interface{}{"component": "prometheus"}}, // 修正標籤
		"port":        9090, "proxyProtocol": "HTTP/1",
	}))

	authObj := cdk8s.NewApiObject(chart, jsii.String("linkerd-auth-policy"), &cdk8s.ApiObjectProps{
		ApiVersion: jsii.String("policy.linkerd.io/v1alpha1"),
		Kind:       jsii.String("AuthorizationPolicy"),
		Metadata:   &cdk8s.ApiObjectMetadata{Name: jsii.String("allow-grafana-from-observability"), Namespace: jsii.String("linkerd-viz")},
	})
	authObj.AddJsonPatch(cdk8s.JsonPatch_Add(jsii.String("/spec"), map[string]interface{}{
		"targetRef":                  map[string]interface{}{"group": "policy.linkerd.io", "kind": "Server", "name": "prometheus-admin"},
		"requiredAuthenticationRefs": []interface{}{map[string]interface{}{"name": "any-unauthenticated", "kind": "NetworkAuthentication", "group": "policy.linkerd.io"}},
	}))

	netAuthObj := cdk8s.NewApiObject(chart, jsii.String("linkerd-network-auth"), &cdk8s.ApiObjectProps{
		ApiVersion: jsii.String("policy.linkerd.io/v1alpha1"),
		Kind:       jsii.String("NetworkAuthentication"),
		Metadata:   &cdk8s.ApiObjectMetadata{Name: jsii.String("any-unauthenticated"), Namespace: jsii.String("linkerd-viz")},
	})
	netAuthObj.AddJsonPatch(cdk8s.JsonPatch_Add(jsii.String("/spec"), map[string]interface{}{
		"networks": []interface{}{map[string]interface{}{"cidr": "0.0.0.0/0"}, map[string]interface{}{"cidr": "::/0"}},
	}))
}

func CreateDashboards(chart cdk8s.Chart) {
	jsonContent := `
{
  "title": "Infar - Microservices War Room",
  "timezone": "browser",
  "refresh": "5s",
  "schemaVersion": 30,
  "panels": [
	{
	  "type": "stat",
	  "title": "Infra Active Connections",
	  "gridPos": { "h": 5, "w": 8, "x": 0, "y": 0 },
	  "targets": [
		{
		  "expr": "sum(tcp_open_total{namespace=\"infra\"}) - sum(tcp_close_total{namespace=\"infra\"})",
		  "legendFormat": "Active Connections",
		  "datasource": "Linkerd-Prometheus"
		}
	  ],
	  "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
	},
	{
	  "type": "stat",
	  "title": "TCP Connection Rate (ops/s)",
	  "gridPos": { "h": 5, "w": 8, "x": 8, "y": 0 },
	  "targets": [
		{
		  "expr": "sum(rate(tcp_open_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "Conn Rate",
		  "datasource": "Linkerd-Prometheus"
		}
	  ],
	  "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
	},
	{
	  "type": "stat",
	  "title": "Network Throughput (Total)",
	  "gridPos": { "h": 5, "w": 8, "x": 16, "y": 0 },
	  "targets": [
		{
		  "expr": "sum(rate(tcp_read_bytes_total{namespace=\"infra\"}[1m])) + sum(rate(tcp_write_bytes_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "Throughput",
		  "datasource": "Linkerd-Prometheus"
		}
	  ],
	  "options": { "colorMode": "value", "graphMode": "area", "reduceOptions": { "calcs": ["lastNotNull"], "values": false } }
	},
	{
	  "type": "timeseries",
	  "title": "TCP Open Rate by Pod",
	  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 5 },
	  "targets": [
		{
		  "expr": "sum by (pod) (rate(tcp_open_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "{{pod}}",
		  "datasource": "Linkerd-Prometheus"
		}
	  ]
	},
	{
	  "type": "timeseries",
	  "title": "Throughput by Pod (Read)",
	  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 5 },
	  "targets": [
		{
		  "expr": "sum by (pod) (rate(tcp_read_bytes_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "{{pod}}",
		  "datasource": "Linkerd-Prometheus"
		}
	  ]
	},
	{
	  "type": "timeseries",
	  "title": "TCP Connections by Pod",
	  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 13 },
	  "targets": [
		{
		  "expr": "sum by (pod) (rate(tcp_open_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "{{pod}}",
		  "datasource": "Linkerd-Prometheus"
		}
	  ]
	},
	{
	  "type": "timeseries",
	  "title": "Network Throughput",
	  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 13 },
	  "targets": [
		{
		  "expr": "sum by (pod) (rate(tcp_read_bytes_total{namespace=\"infra\"}[1m]))",
		  "legendFormat": "{{pod}} - Read",
		  "datasource": "Linkerd-Prometheus"
		}
	  ]
	}
  ]
}`
	k8s.NewKubeConfigMap(chart, jsii.String("infar-dashboard"), &k8s.KubeConfigMapProps{
		Metadata: &k8s.ObjectMeta{
			Name:      jsii.String("infar-warroom-v2"), // 關鍵修正：與 Grafana values 一致
			Namespace: jsii.String("observability"),
			Labels:    &map[string]*string{"grafana_dashboard": jsii.String("1")},
		},
		Data: &map[string]*string{"infar-overview.json": jsii.String(jsonContent)},
	})
}
