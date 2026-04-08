apiVersion: v1
kind: ConfigMap
metadata:
  name: {{.Name}}-conf
  namespace: {{.Namespace}}
data:
  {{.Name}}.yaml: |
    Name: {{.Name}}
    ListenOn: 0.0.0.0:{{.Port}}
    DataSource: host=postgres.infra.svc.cluster.local port=5432 user=infar_admin password=InfarDbPass123 dbname=infar_db sslmode=disable
    CacheRedis:
      - Host: redis-master.infra.svc.cluster.local:6379
        Pass: InfarDbPass123
        Type: node

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{.Name}}
  namespace: {{.Namespace}}
  labels:
    app: {{.Name}}
spec:
  replicas: {{.Replicas}}
  selector:
    matchLabels:
      app: {{.Name}}
  template:
    metadata:
      labels:
        app: {{.Name}}
      annotations:
        infar.io/config-last-updated: "20260406"
    spec:
      containers:
      - name: {{.Name}}
        image: {{.Image}}
        ports:
        - containerPort: {{.Port}}
        volumeMounts:
        - name: config
          mountPath: /app/etc
      volumes:
      - name: config
        configMap:
          name: {{.Name}}-conf

---
apiVersion: v1
kind: Service
metadata:
  name: {{.Name}}-svc
  namespace: {{.Namespace}}
spec:
  ports:
  - port: {{.Port}}
    targetPort: {{.Port}}
  selector:
    app: {{.Name}}
