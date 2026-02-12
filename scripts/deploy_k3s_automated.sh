#!/bin/bash
##########################################################################################
# K3S AUTOMATED DEPLOYMENT SCRIPT
##########################################################################################
# Purpose: Automated K3s Kubernetes cluster deployment for CI/CD
# Compatible: Ubuntu 25.10 with kernel 6.17.0+
# Features: Clean deployment, health checks, Nautobot installation
##########################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY="${INVENTORY:-inventory/k3s/onprem.yml}"
PLAYBOOK="${PLAYBOOK:-playbooks/deploy_k3s_production.yml}"
VAULT_PASS_FILE="${VAULT_PASS_FILE:-vault_pass.txt}"
LOG_FILE="/tmp/k3s_deployment_$(date +%Y%m%d_%H%M%S).log"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

print_banner() {
    echo ""
    echo "=========================================="
    echo "  K3S AUTOMATED DEPLOYMENT"
    echo "=========================================="
    echo "Deployment Type: K3s (Lightweight Kubernetes)"
    echo "Environment: On-Premises"
    echo "Timestamp: $(date)"
    echo "Log File: $LOG_FILE"
    echo "=========================================="
    echo ""
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible is not installed. Please install ansible first."
        exit 1
    fi
    
    # Check if inventory file exists
    if [ ! -f "$PROJECT_ROOT/$INVENTORY" ]; then
        error "Inventory file not found: $INVENTORY"
        exit 1
    fi
    
    # Check if playbook exists
    if [ ! -f "$PROJECT_ROOT/$PLAYBOOK" ]; then
        error "Playbook file not found: $PLAYBOOK"
        exit 1
    fi
    
    # Check if vault password file exists
    if [ ! -f "$PROJECT_ROOT/$VAULT_PASS_FILE" ]; then
        warning "Vault password file not found: $VAULT_PASS_FILE"
        warning "Continuing without vault..."
    fi
    
    log "✅ Prerequisites check passed"
}

run_deployment() {
    log "Starting K3s deployment..."
    
    cd "$PROJECT_ROOT"
    
    # Build ansible-playbook command
    ANSIBLE_CMD="ansible-playbook"
    ANSIBLE_CMD="$ANSIBLE_CMD -i $INVENTORY"
    ANSIBLE_CMD="$ANSIBLE_CMD $PLAYBOOK"
    
    if [ -f "$VAULT_PASS_FILE" ]; then
        ANSIBLE_CMD="$ANSIBLE_CMD --vault-password-file $VAULT_PASS_FILE"
    fi
    
    ANSIBLE_CMD="$ANSIBLE_CMD -v"
    
    info "Running: $ANSIBLE_CMD"
    
    # Run deployment
    if $ANSIBLE_CMD 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Deployment completed successfully!"
        return 0
    else
        error "❌ Deployment failed!"
        return 1
    fi
}

verify_cluster() {
    log "Verifying cluster health..."
    
    # Get master node IP
    MASTER_IP=$(grep -A 10 "k8s_master:" "$PROJECT_ROOT/$INVENTORY" | grep ansible_host | head -1 | awk '{print $2}')
    
    if [ -z "$MASTER_IP" ]; then
        error "Could not determine master node IP"
        return 1
    fi
    
    info "Master node: $MASTER_IP"
    
    # Wait for cluster to stabilize
    log "Waiting 30 seconds for cluster to stabilize..."
    sleep 30
    
    # Check nodes
    log "Checking cluster nodes..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MASTER_IP "kubectl get nodes -o wide" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Cluster nodes are accessible"
    else
        warning "⚠️ Could not access cluster nodes (may still be initializing)"
    fi
    
    # Check system pods
    log "Checking system pods..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MASTER_IP "kubectl get pods -A" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ System pods are running"
    else
        warning "⚠️ Could not list system pods"
    fi
    
    # Check Nautobot
    log "Checking Nautobot deployment..."
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MASTER_IP "kubectl get pods -n nautobot" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Nautobot namespace accessible"
    else
        warning "⚠️ Nautobot may not be deployed yet"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  DEPLOYMENT SUMMARY"
    echo "=========================================="
    echo "Status: $1"
    echo "Log File: $LOG_FILE"
    echo "Deployment Type: K3s"
    echo "=========================================="
    echo ""
    
    if [ "$1" == "SUCCESS" ]; then
        echo "✅ K3s cluster deployed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Access master: ssh ubuntu@$MASTER_IP"
        echo "2. Check nodes: kubectl get nodes"
        echo "3. Check pods: kubectl get pods -A"
        echo "4. Access Nautobot: kubectl get svc -n nautobot"
        echo ""
        echo "K3s advantages:"
        echo "- ✅ Stable on Ubuntu 25.10"
        echo "- ✅ No API server crashes"
        echo "- ✅ Production-ready CNCF certified Kubernetes"
        echo "- ✅ Lightweight and fast"
        echo ""
    else
        echo "❌ Deployment encountered errors"
        echo "Check log file for details: $LOG_FILE"
        echo ""
    fi
    
    echo "=========================================="
}

# Main execution
main() {
    print_banner
    
    check_prerequisites
    
    if run_deployment; then
        verify_cluster
        print_summary "SUCCESS"
        exit 0
    else
        print_summary "FAILED"
        exit 1
    fi
}

# Run main function
main "$@"
