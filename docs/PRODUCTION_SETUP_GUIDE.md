# Production Monitoring and TLS Setup Guide

This guide covers installing and configuring cert-manager and Prometheus Operator for production deployment.

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm 3 installed
- MetalLB or cloud load balancer configured

## 1. Install cert-manager

cert-manager automates TLS certificate provisioning and renewal via Let's Encrypt.

```bash
# Install cert-manager using kubectl
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for cert-manager pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Verify installation
kubectl get pods -n cert-manager
```

Expected output:
```
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-7d9f8c6c8b-xxxxx              1/1     Running   0          2m
cert-manager-cainjector-5879c5d96-xxxxx    1/1     Running   0          2m
cert-manager-webhook-7f9f8c6c8b-xxxxx      1/1     Running   0          2m
```

### Create ClusterIssuers

```bash
# Update email in clusterissuer.yaml first!
# Edit: helm/nautobot/clusterissuer.yaml
# Change: admin@example.com to your actual email

# Apply ClusterIssuers
kubectl apply -f helm/nautobot/clusterissuer.yaml

# Verify ClusterIssuers are ready
kubectl get clusterissuer
```

Expected output:
```
NAME                  READY   AGE
letsencrypt-prod      True    30s
letsencrypt-staging   True    30s
```

## 2. Install Prometheus Operator

Prometheus Operator manages Prometheus instances and ServiceMonitors for metrics collection.

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus Operator, Grafana, AlertManager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123 \
  --wait

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l release=prometheus -n monitoring --timeout=600s

# Verify installation
kubectl get pods -n monitoring
```

Expected output (15+ pods):
```
NAME                                                   READY   STATUS    RESTARTS   AGE
prometheus-kube-prometheus-operator-xxxxx              1/1     Running   0          2m
prometheus-kube-state-metrics-xxxxx                    1/1     Running   0          2m
prometheus-prometheus-node-exporter-xxxxx              1/1     Running   0          2m
prometheus-prometheus-kube-prometheus-prometheus-0     2/2     Running   0          2m
alertmanager-prometheus-kube-prometheus-alertmanager-0 2/2     Running   0          2m
prometheus-grafana-xxxxx                               3/3     Running   0          2m
```

### Access Grafana Dashboard

```bash
# Get Grafana service
kubectl get svc -n monitoring | grep grafana

# Port forward Grafana (or expose via LoadBalancer/Ingress)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Grafana at: http://localhost:3000
# Default credentials: admin / admin123
```

## 3. Deploy Nautobot with Production Configuration

```bash
# Commit new monitoring and TLS templates
cd /home/ubuntu/nautobot_ansible_app
git add helm/nautobot/templates/servicemonitor.yaml
git add helm/nautobot/templates/prometheusrule.yaml
git add helm/nautobot/templates/certificate.yaml
git add helm/nautobot/values.yaml
git add helm/nautobot/clusterissuer.yaml
git commit -m "feat: Add production monitoring and TLS support"
git push

# Trigger deployment via pipeline or manually:
# helm upgrade --install nautobot helm/nautobot \
#   -n nautobot \
#   --create-namespace \
#   -f helm/nautobot/values.yaml
```

## 4. Verify Production Setup

### Check TLS Certificate

```bash
# Check Certificate resource
kubectl get certificate -n nautobot

# Check certificate details
kubectl describe certificate nautobot-tls -n nautobot
```

Expected status: `Ready: True`

### Check ServiceMonitor

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n nautobot

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
# Look for "nautobot" target with UP status
```

### Check PrometheusRule

```bash
# Verify PrometheusRule exists
kubectl get prometheusrule -n nautobot

# Check alerts in Prometheus
# Open http://localhost:9090/alerts
# Should see nautobot.rules group
```

## 5. Access Nautobot

### Via LoadBalancer (HTTP)
```bash
# Direct access
curl http://172.17.152.200:8000/
# Should redirect to /login/
```

### Via Ingress (HTTPS)
```bash
# Update /etc/hosts or DNS:
# 172.17.152.201  nautobot.local

# Access via HTTPS
curl https://nautobot.local/
# Should show valid TLS certificate
```

### Browser Access
- **LoadBalancer**: http://172.17.152.200:8000/
- **Ingress HTTPS**: https://nautobot.local/ (after DNS/hosts file update)
- **Credentials**: admin / admin123

## 6. Monitoring Access

### Prometheus
```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090
```

### Grafana
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access: http://localhost:3000
# Login: admin / admin123

# Import Nautobot dashboard (create custom dashboard with metrics):
# - nautobot_http_requests_total
# - nautobot_http_request_duration_seconds
# - container_memory_usage_bytes{namespace="nautobot"}
# - container_cpu_usage_seconds_total{namespace="nautobot"}
```

## 7. Troubleshooting

### cert-manager Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate nautobot-tls -n nautobot

# Check challenge status (during ACME verification)
kubectl get challenge -n nautobot
```

### Prometheus Issues

```bash
# Check Prometheus Operator logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator

# Check if ServiceMonitor is being discovered
kubectl get servicemonitor -A

# Check Prometheus configuration
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- cat /etc/prometheus/config_out/prometheus.env.yaml | grep nautobot
```

### Ingress TLS Issues

```bash
# Check ingress status
kubectl describe ingress nautobot -n nautobot

# Check TLS secret
kubectl get secret nautobot-tls -n nautobot

# Test TLS certificate
echo | openssl s_client -connect nautobot.local:443 -servername nautobot.local 2>/dev/null | openssl x509 -noout -text
```

## Architecture Overview

```
Internet
   │
   ├─[Port 443 HTTPS]──► nginx-ingress (172.17.152.201)
   │                     ├─ TLS termination (cert-manager)
   │                     ├─ Security headers
   │                     └─ Rate limiting
   │
   └─[Port 8000 HTTP]──► LoadBalancer (172.17.152.200)
                         └─ MetalLB
                            │
                            ├─► nautobot-web-0 (health checks enabled)
                            ├─► nautobot-web-1 (health checks enabled)
                            ├─► nautobot-worker-0
                            └─► nautobot-worker-1
                               │
                               ├─► PostgreSQL (StatefulSet)
                               └─► Redis (Deployment)

Monitoring:
   Prometheus Operator
      │
      ├─► ServiceMonitor (scrapes /metrics every 30s)
      ├─► PrometheusRule (7 alert rules)
      └─► Grafana (dashboards)
         └─► AlertManager (notifications)
```

## Security Checklist

- [x] HTTPS enforced with TLS 1.2/1.3 only
- [x] Security headers (X-Frame-Options, XSS-Protection, nosniff)
- [x] Rate limiting (100 RPS per client)
- [x] Health checks enabled (auto-healing)
- [x] Liveness and readiness probes configured
- [x] Automated TLS certificate renewal
- [x] Monitoring and alerting configured
- [ ] Update default admin password (admin123)
- [ ] Configure proper domain name (not nautobot.local)
- [ ] Set up backup strategy for PostgreSQL
- [ ] Configure AlertManager notification channels
- [ ] Review and adjust alert thresholds

## Next Steps

1. **Update domain name**: Change `nautobot.local` to your actual domain in values.yaml
2. **Update email**: Set proper email in clusterissuer.yaml for Let's Encrypt notifications
3. **Change passwords**: Update admin password in Nautobot and Grafana
4. **Configure alerts**: Set up Slack/email notifications in AlertManager
5. **Create dashboards**: Build Grafana dashboards for Nautobot metrics
6. **Test failover**: Kill pods and verify health checks trigger auto-healing
7. **Load testing**: Verify rate limiting and performance under load
8. **Backup setup**: Configure PostgreSQL backups (pg_dump or Velero)
