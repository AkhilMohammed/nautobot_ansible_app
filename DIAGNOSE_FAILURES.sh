#!/bin/bash
#
# DIAGNOSE DEPLOYMENT FAILURES
# Run this to understand why deployments are failing
#
# Usage: ./DIAGNOSE_FAILURES.sh
#

set +e  # Don't exit on errors

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "🔍 DEPLOYMENT FAILURE DIAGNOSTICS"
echo "=========================================="
echo ""

ISSUES_FOUND=0

# Check 1: VM System Clocks
echo -e "${BLUE}[1/6] Checking VM system clocks...${NC}"
echo "---------------------------------------"
MASTER_IP="172.17.152.109"
CURRENT_TIME=$(date +%s)

for ip in 172.17.152.{102..109}; do
    VM_TIME=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$ip "date +%s" 2>/dev/null)
    if [ -n "$VM_TIME" ]; then
        TIME_DIFF=$((VM_TIME - CURRENT_TIME))
        ABS_DIFF=${TIME_DIFF#-}
        
        if [ $ABS_DIFF -gt 60 ]; then
            echo -e "${RED}✗ $ip: Clock skew ${TIME_DIFF}s (>1 minute)${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo -e "${GREEN}✓ $ip: Clock OK (${TIME_DIFF}s)${NC}"
        fi
    else
        echo -e "${RED}✗ $ip: Cannot connect${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done
echo ""

# Check 2: Kubernetes Master Status
echo -e "${BLUE}[2/6] Checking Kubernetes master status...${NC}"
echo "---------------------------------------"
MASTER_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    systemctl is-active kubelet 2>/dev/null
" 2>/dev/null)

if [ "$MASTER_STATUS" = "active" ]; then
    echo -e "${GREEN}✓ Master kubelet is running${NC}"
    
    # Check API server
    API_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
        timeout 5 kubectl get --raw /healthz 2>/dev/null
    " 2>/dev/null)
    
    if [ "$API_STATUS" = "ok" ]; then
        echo -e "${GREEN}✓ API server is healthy${NC}"
    else
        echo -e "${RED}✗ API server is NOT responding${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        
        echo "  Checking API server pod..."
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
            sudo crictl ps | grep kube-apiserver
        " 2>/dev/null || echo -e "${RED}  API server container not running${NC}"
    fi
else
    echo -e "${RED}✗ Master kubelet is NOT running${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 3: Worker Nodes Status
echo -e "${BLUE}[3/6] Checking worker nodes...${NC}"
echo "---------------------------------------"
NODES=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    export KUBECONFIG=/home/ubuntu/.kube/config
    kubectl get nodes 2>/dev/null
" 2>/dev/null)

if [ -n "$NODES" ]; then
    echo "$NODES"
    
    NOT_READY=$(echo "$NODES" | grep -c "NotReady" || true)
    if [ $NOT_READY -gt 0 ]; then
        echo -e "${RED}✗ $NOT_READY nodes are NotReady${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "${RED}✗ Cannot query cluster nodes (API server may be down)${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

# Check 4: Recent Pipeline Failures
echo -e "${BLUE}[4/6] Checking recent pipeline failures...${NC}"
echo "---------------------------------------"
if command -v jq &>/dev/null && command -v curl &>/dev/null; then
    curl -s "https://api.github.com/repos/AkhilMohammed/nautobot_ansible_app/actions/runs?branch=feat/onprem-deployment&per_page=5" | \
        jq -r '.workflow_runs[] | "\(.conclusion // .status): Run #\(.run_number) at \(.created_at)"'
else
    echo "Install jq and curl to check pipeline status"
fi
echo ""

# Check 5: Disk Space on VMs
echo -e "${BLUE}[5/6] Checking disk space on VMs...${NC}"
echo "---------------------------------------"
for ip in 172.17.152.{102..109}; do
    DISK_USED=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$ip "
        df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'
    " 2>/dev/null)
    
    if [ -n "$DISK_USED" ] && [ "$DISK_USED" -gt 85 ]; then
        echo -e "${RED}✗ $ip: ${DISK_USED}% used (>85%)${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    elif [ -n "$DISK_USED" ]; then
        echo -e "${GREEN}✓ $ip: ${DISK_USED}% used${NC}"
    fi
done
echo ""

# Check 6: Recent Errors in Logs
echo -e "${BLUE}[6/6] Checking for common errors in deployment logs...${NC}"
echo "---------------------------------------"
LOG_DIR="/home/ubuntu/nautobot_ansible_app/deployment_logs"
if [ -d "$LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log: $(basename $LATEST_LOG)"
        echo ""
        echo "Common errors found:"
        
        grep -i "fatal:\|ERROR:\|FAILED!" "$LATEST_LOG" 2>/dev/null | tail -10 || echo "No fatal errors in log"
    else
        echo "No deployment logs found"
    fi
else
    echo "No deployment logs directory"
fi
echo ""

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ No critical issues detected${NC}"
    echo ""
    echo "If deployment still fails, check:"
    echo "  - GitHub Actions logs for specific errors"
    echo "  - Network connectivity between VMs"
    echo "  - Firewall rules"
else
    echo -e "${RED}❌ Found $ISSUES_FOUND issue(s)${NC}"
    echo ""
    echo -e "${YELLOW}Recommended actions:${NC}"
    echo ""
    
    # Prioritized recommendations
    echo "1. FIX SYSTEM CLOCKS (if flagged above)"
    echo "   - Check hypervisor/host time"
    echo "   - Enable VM time sync at virtualization layer"
    echo "   - See: URGENT_FIX_INFRASTRUCTURE.md"
    echo ""
    
    echo "2. RESTART MASTER API SERVER (if down)"
    echo "   ssh ubuntu@172.17.152.109"
    echo "   sudo systemctl restart containerd"
    echo "   sudo systemctl restart kubelet"
    echo "   # Wait 2 minutes"
    echo "   kubectl get nodes"
    echo ""
    
    echo "3. CLEAR CLUSTER STATE AND REDEPLOY"
    echo "   # On master"
    echo "   ssh ubuntu@172.17.152.109"
    echo "   sudo kubeadm reset -f"
    echo "   sudo rm -rf /etc/kubernetes /var/lib/etcd ~/.kube"
    echo ""
    echo "   # Then run:"
    echo "   ./EMERGENCY_MANUAL_DEPLOY.sh"
    echo ""
fi

echo "For detailed troubleshooting:"
echo "  - GitHub: https://github.com/AkhilMohammed/nautobot_ansible_app/actions"
echo "  - Logs: $LOG_DIR"
echo ""
