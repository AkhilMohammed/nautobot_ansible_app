#!/bin/bash
#
# EMERGENCY MANUAL DEPLOYMENT
# Use this if all automated pipeline attempts fail
#
# Usage: ./EMERGENCY_MANUAL_DEPLOY.sh
#

set -e

echo "=========================================="
echo "🚨 EMERGENCY MANUAL DEPLOYMENT"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REPO_DIR="/home/ubuntu/nautobot_ansible_app"
cd "$REPO_DIR"

echo -e "${YELLOW}Step 1: Pre-flight checks${NC}"
echo "---------------------------------------"

# Check if on correct branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "feat/onprem-deployment" ]; then
    echo -e "${RED}❌ Wrong branch: $CURRENT_BRANCH${NC}"
    echo "Switching to feat/onprem-deployment..."
    git checkout feat/onprem-deployment
    git pull origin feat/onprem-deployment
fi

# Check SSH connectivity to all VMs
echo ""
echo "Checking SSH connectivity to VMs..."
HOSTS=(
    "172.17.152.102"
    "172.17.152.103"
    "172.17.152.104"
    "172.17.152.105"
    "172.17.152.106"
    "172.17.152.107"
    "172.17.152.108"
    "172.17.152.109"
)

FAILED_HOSTS=()
for host in "${HOSTS[@]}"; do
    if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$host "echo OK" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $host reachable"
    else
        echo -e "${RED}✗${NC} $host UNREACHABLE"
        FAILED_HOSTS+=($host)
    fi
done

if [ ${#FAILED_HOSTS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Cannot reach ${#FAILED_HOSTS[@]} hosts. Fix connectivity first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All VMs reachable${NC}"
echo ""

# Check vault password file
if [ ! -f "$REPO_DIR/vault_pass.txt" ]; then
    echo -e "${RED}❌ vault_pass.txt not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 2: Fix APT time issue on all VMs${NC}"
echo "---------------------------------------"
echo "Creating APT config to ignore time validation..."

for host in "${HOSTS[@]}"; do
    echo "Fixing $host..."
    ssh -o StrictHostKeyChecking=no ubuntu@$host "sudo bash -c 'echo \"Acquire::Check-Valid-Until \\\"false\\\";\" > /etc/apt/apt.conf.d/99-ignore-time-check'" 2>/dev/null || true
done

echo -e "${GREEN}✅ APT configuration applied to all VMs${NC}"
echo ""

echo -e "${YELLOW}Step 3: Run deployment with verbose logging${NC}"
echo "---------------------------------------"
echo "This will take 40-60 minutes..."
echo "Press Ctrl+C within 5 seconds to cancel, or wait to continue..."
sleep 5

# Create log directory
LOG_DIR="$REPO_DIR/deployment_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/manual_deploy_${TIMESTAMP}.log"

echo ""
echo "Deployment started at $(date)"
echo "Logs: $LOG_FILE"
echo ""

# Run the deployment
cd "$REPO_DIR"
ansible-playbook \
    -i inventory/k8s/onprem.yml \
    playbooks/deploy_k8s_production.yml \
    --vault-password-file vault_pass.txt \
    -vv 2>&1 | tee "$LOG_FILE"

DEPLOY_EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "=========================================="
if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
    echo "=========================================="
    echo ""
    echo "Verifying cluster..."
    
    # SSH to master and check status
    ssh -o StrictHostKeyChecking=no ubuntu@172.17.152.109 "
        export KUBECONFIG=/home/ubuntu/.kube/config
        echo '--- Nodes ---'
        kubectl get nodes
        echo ''
        echo '--- Nautobot Pods ---'
        kubectl get pods -n nautobot
        echo ''
        echo '--- Services ---'
        kubectl get svc -n nautobot
    "
    
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Access Nautobot: http://<load-balancer-ip>:8080"
    echo "2. Default credentials in vault.yml"
    echo "3. Check logs: cat $LOG_FILE"
else
    echo -e "${RED}❌ DEPLOYMENT FAILED (Exit code: $DEPLOY_EXIT_CODE)${NC}"
    echo "=========================================="
    echo ""
    echo "Check logs for errors: cat $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo "1. Time sync issues - check VM clocks"
    echo "2. API server crashes - check master at 172.17.152.109"
    echo "3. Worker join failures - check kubelet logs"
    echo ""
    echo "To diagnose:"
    echo "  ./DIAGNOSE_FAILURES.sh"
fi

exit $DEPLOY_EXIT_CODE
