#!/bin/bash
# Production Infrastructure Setup Script
# Installs MetalLB, Nginx Ingress, Prometheus, Grafana, and SonarQube

set -e

MASTER_NODE="172.17.152.109"
METALLB_IP_RANGE="172.17.152.200-172.17.152.205"

echo "🚀 Setting up Production Infrastructure..."
echo "==========================================="

# 1. Install MetalLB
echo ""
echo "📦 Installing MetalLB Load Balancer..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo "⏳ Waiting for MetalLB pods to be ready..."
sleep 20
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=180s

echo "⚙️  Configuring MetalLB IP Address Pool..."
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

echo "✅ MetalLB installed successfully!"

# 2. Check Nginx Ingress Controller
echo ""
echo "📦 Checking Nginx Ingress Controller..."
if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  echo "✅ Nginx Ingress already installed"
else
  echo "⚙️  Installing Nginx Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
  
  echo "⏳ Waiting for Nginx Ingress to be ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s
  
  echo "✅ Nginx Ingress installed successfully!"
fi

# 3. Patch Nginx Ingress to use LoadBalancer
echo ""
echo "⚙️  Configuring Nginx Ingress with LoadBalancer..."
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"type": "LoadBalancer"}}'

# 4. Check Prometheus & Grafana
echo ""
echo "📊 Checking Prometheus & Grafana..."
if kubectl get namespace monitoring >/dev/null 2>&1; then
  echo "✅ Prometheus stack already installed"
  
  # Patch Grafana to use LoadBalancer
  echo "⚙️  Exposing Grafana via LoadBalancer..."
  kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
  
  # Patch Prometheus to use LoadBalancer
  echo "⚙️  Exposing Prometheus via LoadBalancer..."
  kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
else
  echo "❌ Prometheus stack not found - will be installed by playbook"
fi

# 5. Install SonarQube
echo ""
echo "📦 Installing SonarQube..."
kubectl create namespace sonarqube --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-data
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-extensions
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-logs
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  type: LoadBalancer
  ports:
    - port: 9000
      targetPort: 9000
      protocol: TCP
      name: http
  selector:
    app: sonarqube
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      initContainers:
        - name: sysctl
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              sysctl -w vm.max_map_count=524288
              sysctl -w fs.file-max=131072
          securityContext:
            privileged: true
      containers:
        - name: sonarqube
          image: sonarqube:10.3-community
          ports:
            - containerPort: 9000
              name: http
          env:
            - name: SONAR_JDBC_URL
              value: "jdbc:h2:tcp://localhost:9092/sonar"
            - name: SONAR_JDBC_USERNAME
              value: "sonar"
            - name: SONAR_JDBC_PASSWORD
              value: "sonar"
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
          volumeMounts:
            - name: sonarqube-data
              mountPath: /opt/sonarqube/data
            - name: sonarqube-extensions
              mountPath: /opt/sonarqube/extensions
            - name: sonarqube-logs
              mountPath: /opt/sonarqube/logs
          livenessProbe:
            httpGet:
              path: /api/system/status
              port: 9000
            initialDelaySeconds: 120
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
          readinessProbe:
            httpGet:
              path: /api/system/status
              port: 9000
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
      volumes:
        - name: sonarqube-data
          persistentVolumeClaim:
            claimName: sonarqube-data
        - name: sonarqube-extensions
          persistentVolumeClaim:
            claimName: sonarqube-extensions
        - name: sonarqube-logs
          persistentVolumeClaim:
            claimName: sonarqube-logs
EOF

echo "✅ SonarQube deployed successfully!"

# Wait for services to get external IPs
echo ""
echo "⏳ Waiting for LoadBalancer IPs to be assigned..."
sleep 30

# Display all services
echo ""
echo "=========================================="
echo "🎉 Production Infrastructure Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Service Endpoints:"
echo "--------------------"
echo ""

echo "🌐 Nautobot:"
NAUTOBOT_IP=$(kubectl get svc nautobot -n nautobot -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo "   URL: http://${NAUTOBOT_IP}:8000"
echo "   Credentials: admin / admin"
echo ""

echo "🔧 Nginx Ingress:"
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo "   HTTP:  http://${INGRESS_IP}"
echo "   HTTPS: https://${INGRESS_IP}"
echo ""

echo "📊 Grafana:"
GRAFANA_IP=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
GRAFANA_PASS=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode || echo "Not found")
echo "   URL: http://${GRAFANA_IP}"
echo "   Credentials: admin / ${GRAFANA_PASS}"
echo ""

echo "🔍 Prometheus:"
PROM_IP=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo "   URL: http://${PROM_IP}:9090"
echo ""

echo "🐛 SonarQube:"
SONAR_IP=$(kubectl get svc sonarqube -n sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
echo "   URL: http://${SONAR_IP}:9000"
echo "   Default Credentials: admin / admin (change on first login)"
echo ""

echo "=========================================="
echo "✅ All services are configured!"
echo "=========================================="
