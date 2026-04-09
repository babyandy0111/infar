apiVersion: v1
kind: ConfigMap
metadata:
  name: {{.Name}}-conf
  namespace: {{.Namespace}}
data:
  {{.Name}}.yaml: |
    Name: {{.Name}}
    Host: 0.0.0.0
    Port: {{.Port}}
    Auth:
      AccessSecret: infar-secret-2026
      AccessExpire: 86400
    # 這裡的名稱會在腳本中處理，或是維持通用
    OrderRpc:
      Endpoints:
        - order-rpc-svc.{{.Namespace}}.svc.cluster.local:9090
    UserRpc:
      Endpoints:
        - user-rpc-svc.{{.Namespace}}.svc.cluster.local:9090

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
