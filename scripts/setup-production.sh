#!/bin/bash
# Production Setup Script
# Automates the complete production-ready setup

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

echo "============================================"
echo "  Nautobot K8s Production Setup"
echo "============================================"
echo ""

# Step 1: Check current setup
print_step "Step 1: Checking current deployment"
if kubectl get namespace nautobot &>/dev/null; then
    print_info "Nautobot namespace exists"
    kubectl get pods -n nautobot
    echo ""
    read -p "Upgrade existing deployment? (yes/no): " UPGRADE
    if [ "$UPGRADE" != "yes" ]; then
        echo "Setup cancelled"
        exit 0
    fi
else
    print_info "Fresh installation"
fi

# Step 2: Copy production Helm chart
print_step "Step 2: Syncing Helm chart to master node"
MASTER_IP=$(grep -A5 "onprem-k8s-master" inventory/k8s/onprem.yml | grep ansible_host | awk '{print $2}')
print_info "Master IP: $MASTER_IP"

scp -r helm/nautobot ubuntu@$MASTER_IP:~/nautobot-helm/
print_success "Helm chart synced"

# Step 3: Deploy with pre-install Job
print_step "Step 3: Deploying with pre-install Job"
ansible-playbook \
    -i inventory/k8s/onprem.yml \
    playbooks/deploy_k8s_production.yml \
    --vault-password-file vault_pass.txt \
    -e "target_env=dev" \
    --limit onprem-k8s-master \
    --tags nautobot_deploy

if [ $? -ne 0 ]; then
    echo "Deployment failed"
    exit 1
fi

print_success "Deployment initiated"

# Step 4: Monitor pre-install Job
print_step "Step 4: Monitoring plugin installation"
print_info "Waiting for pre-install Job to complete..."

ssh ubuntu@$MASTER_IP << 'EOF'
set -e

# Wait for Job to start
sleep 10

# Get Job name
JOB_NAME=$(kubectl get jobs -n nautobot -l app.kubernetes.io/component=pre-install --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

if [ -z "$JOB_NAME" ]; then
    echo "Pre-install Job not found (plugins may be disabled)"
    exit 0
fi

echo "Found Job: $JOB_NAME"

# Stream logs
POD_NAME=$(kubectl get pods -n nautobot -l job-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "Streaming logs from $POD_NAME..."
    kubectl logs -n nautobot -f $POD_NAME || true
fi

# Wait for completion
kubectl wait --for=condition=complete --timeout=600s job/$JOB_NAME -n nautobot

echo "✓ Pre-install Job completed successfully!"
EOF

print_success "Plugin installation complete"

# Step 5: Wait for pods
print_step "Step 5: Waiting for pods to be ready"
ssh ubuntu@$MASTER_IP << 'EOF'
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=web -n nautobot --timeout=300s
echo "✓ Web pods ready"

kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=worker -n nautobot --timeout=300s
echo "✓ Worker pods ready"
EOF

print_success "All pods are ready"

# Step 6: Get deployment info
print_step "Step 6: Deployment information"
ssh ubuntu@$MASTER_IP << 'EOF'
echo ""
echo "==> Helm Release:"
helm list -n nautobot

echo ""
echo "==> Pods:"
kubectl get pods -n nautobot

echo ""
echo "==> Services:"
kubectl get svc -n nautobot

echo ""
echo "==> LoadBalancer:"
LB_IP=$(kubectl get svc nautobot -n nautobot -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "URL: http://$LB_IP:8000"

echo ""
echo "==> Installed Plugins:"
kubectl exec -n nautobot deployment/nautobot-web -- pip list | grep nautobot
EOF

print_success "Setup complete!"

echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo "1. Access Nautobot at the URL above"
echo "2. Login with configured credentials"
echo "3. Verify plugins in UI: Plugins → Installed"
echo ""
echo "To add more plugins:"
echo "  - Edit group_vars/dev/nautobot.yml"
echo "  - Push to trigger CI/CD"
echo "  - Or run: ./scripts/deploy-production.sh deploy dev"
echo ""
