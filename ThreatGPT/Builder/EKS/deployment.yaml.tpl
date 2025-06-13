apiVersion: apps/v1
kind: Deployment
metadata:
  name: threatgpt
spec:
  replicas: 2
  selector:
    matchLabels:
      app: threatgpt
  template:
    metadata:
      labels:
        app: threatgpt
    spec:
      containers:
      - name: threatgpt
        image: ${AWS_USER}.dkr.ecr.eu-north-1.amazonaws.com/threatgpt:latest
        ports:
        - containerPort: 8501
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: openai-secret
              key: api-key
