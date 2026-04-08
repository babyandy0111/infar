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
        infar.io/config-last-updated: "2026-04-06-init"
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
