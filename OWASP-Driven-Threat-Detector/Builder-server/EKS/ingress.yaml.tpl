# *.tpl because Terraform will insert public subnet addresses in line 11
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
 name: threatgpt-ingress
 annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
  alb.ingress.kubernetes.io/subnets: ${SUBNET_1}, ${SUBNET_2}
  alb.ingress.kubernetes.io/healthcheck-path: /health
  external-dns.alpha.kubernetes.io/hostname: ${MY_DOMAIN}
spec:
 rules:
  - host: myowaspproject3v401.com
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: threatgpt-service
              port:
                number: 80