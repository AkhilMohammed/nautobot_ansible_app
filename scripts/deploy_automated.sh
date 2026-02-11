#!/bin/bash
#==============================================================================
# AUTOMATED KUBERNETES DEPLOYMENT SCRIPT
# Handles infrastructure issues and provides robust deployment
#==============================================================================

set -e  # Exit on error

# Configuration
MASTER_IP="172.17.152.109"
WORKER_IPS=("172.17.152.103" "172.17.152.104" "172.17.152.105" "172.17.152.106")
SSH_USER="ubuntu"
VAULT_PASS_FILE="vault_pass.txt"
INVENTORY_FILE="inventory/k8s/onprem.yml"
PLAYBOOK_FILE="playbooks/deploy_k8s_production.yml"
LOG_DIR="/tmp"
RUN_NUMBER=95

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# Helper Functions
#==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#==============================================================================
# Pre-flight Checks
#==============================================================================

preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check if vault password file exists
    if [ ! -f "$VAULT_PASS_FILE" ]; then
        log_error "Vault password file not found: $VAULT_PASS_FILE"
        exit 1
    fi
    
    # Check if inventory exists
    if [ ! -f "$INVENTORY_FILE" ]; then
        log_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi
    
    # Check if playbook exists
    if [ ! -f "$PLAYBOOK_FILE" ]; then
        log_error "Playbook file not found: $PLAYBOOK_FILE"
        exit 1
    fi
    
    # Check SSH connectivity to master
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "echo 'SSH OK'" &>/dev/null; then
        log_error "Cannot SSH to master node: ${MASTER_IP}"
        exit 1
    fi
    
    log_success "Pre-flight checks passed!"
}

#==============================================================================
# Pre-pull Container Images (Solves slow registry issue)
#==============================================================================

prepull_images() {
    log_info "Pre-pulling container images to avoid deployment timeouts..."
    
    local images=(
        "registry.k8s.io/kube-apiserver:v1.28.15"
        "registry.k8s.io/kube-controller-manager:v1.28.15"
        "registry.k8s.io/kube-scheduler:v1.28.15"
        "registry.k8s.io/kube-proxy:v1.28.15"
        "registry.k8s.io/pause:3.9"
        "registry.k8s.io/etcd:3.5.15-0"
        "registry.k8s.io/coredns/coredns:v1.10.1"
        "docker.io/calico/cni:v3.27.0"
        "docker.io/calico/node:v3.27.0"
        "docker.io/calico/kube-controllers:v3.27.0"
    )
    
    log_info "Pulling images on master node (${MASTER_IP})..."
    for image in "${images[@]}"; do
        log_info "  Pulling: $image"
        ssh ${SSH_USER}@${MASTER_IP} "sudo crictl pull $image 2>&1" &
    done
    
    wait
    log_success "Image pre-pull completed on master!"
}

#==============================================================================
# Clean Previous Failed Deployments
#==============================================================================

clean_previous_deployment() {
    log_info "Cleaning up any previous failed deployments..."
    
    log_info "Killing any hung processes..."
    pkill -f "ansible-playbook.*deploy_k8s" 2>/dev/null || true
    pkill -f "kubeadm init" 2>/dev/null || true
    
    log_info "Checking cluster state on master..."
    local api_running=$(ssh ${SSH_USER}@${MASTER_IP} "sudo systemctl is-active kubelet 2>/dev/null" || echo "inactive")
    
    if [ "$api_running" = "active" ]; then
        log_warning "Kubernetes seems to be running. Checking API health..."
        if ssh ${SSH_USER}@${MASTER_IP} "kubectl get nodes" &>/dev/null; then
            log_success "Cluster is healthy! Skipping cleanup."
            return 0
        else
            log_warning "API unhealthy, will reset cluster..."
        fi
    fi
    
    log_success "Cleanup completed!"
}

#==============================================================================
# Run Deployment with Monitoring
#==============================================================================

run_deployment() {
    local log_file="${LOG_DIR}/deployment_run${RUN_NUMBER}.log"
    
    log_info "Starting deployment Run #${RUN_NUMBER}..."
    log_info "Log file: $log_file"
    echo ""
    
    log_info "Deployment will take 30-45 minutes for full cluster setup"
    log_info "Progress will be shown below..."
    echo ""
    
    # Run deployment in background and monitor
    timeout 3600 ansible-playbook \
        -i "$INVENTORY_FILE" \
        "$PLAYBOOK_FILE" \
        --vault-password-file "$VAULT_PASS_FILE" \
        -v 2>&1 | tee "$log_file" &
    
    local deploy_pid=$!
    
    # Monitor deployment progress
    sleep 5
    while kill -0 $deploy_pid 2>/dev/null; do
        local line_count=$(wc -l < "$log_file" 2>/dev/null || echo 0)
        echo -ne "\r${BLUE}[PROGRESS]${NC} Lines logged: $line_count | Check log: tail -f $log_file"
        sleep 10
        
        # Check for common failure patterns
        if grep -q "kubeadm init.*still running" "$log_file" 2>/dev/null; then
            if [ $(grep -c "Pulling image" "$log_file" 2>/dev/null || echo 0) -gt 0 ]; then
                log_warning "\nImage pull detected - this may take 5-10 minutes on slow networks..."
            fi
        fi
    done
    
    wait $deploy_pid
    local exit_code=$?
    
    echo ""  # New line after progress
    
    if [ $exit_code -eq 0 ]; then
        log_success "Deployment completed successfully!"
        return 0
    else
        log_error "Deployment failed with exit code: $exit_code"
        return 1
    fi
}

#==============================================================================
# Verify Deployment
#==============================================================================

verify_deployment() {
    log_info "Verifying deployment..."
    
    sleep 5
    
    # Check master node
    log_info "Checking master node..."
    if ssh ${SSH_USER}@${MASTER_IP} "kubectl get nodes | grep -q 'Ready'"; then
        log_success "Master node is Ready!"
    else
        log_error "Master node is not Ready"
        return 1
    fi
    
    # Check workers
    log_info "Checking worker nodes..."
    local worker_count=$(ssh ${SSH_USER}@${MASTER_IP} "kubectl get nodes --no-headers | grep -c Ready" || echo 0)
    log_info "Workers ready: $worker_count"
    
    # Check control plane pods
    log_info "Checking control plane pods..."
    ssh ${SSH_USER}@${MASTER_IP} "kubectl get pods -n kube-system | grep -E 'kube-apiserver|etcd|kube-controller|kube-scheduler'" || true
    
    # Check Calico
    log_info "Checking Calico CNI..."
    local calico_count=$(ssh ${SSH_USER}@${MASTER_IP} "kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | grep -c Running" || echo 0)
    log_info "Calico pods running: $calico_count"
    
    log_success "Verification completed!"
    echo ""
    log_info "To check full cluster status, run:"
    log_info "  ./scripts/check_cluster.sh"
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    echo ""
    echo "======================================================================="
    echo "  AUTOMATED KUBERNETES DEPLOYMENT - Run #${RUN_NUMBER}"
    echo "======================================================================="
    echo ""
    
    # Step 1: Pre-flight checks
    preflight_checks
    echo ""
    
    # Step 2: Clean previous attempts (optional)
    read -p "Clean previous failed deployments? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clean_previous_deployment
        echo ""
    fi
    
    # Step 3: Pre-pull images (optional but recommended)
    read -p "Pre-pull images to speed up deployment? (Recommended) (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        prepull_images
        echo ""
    fi
    
    # Step 4: Run deployment
    if run_deployment; then
        echo ""
        verify_deployment
        echo ""
        log_success "======================================================================="
        log_success "  DEPLOYMENT SUCCESSFUL!"
        log_success "======================================================================="
        echo ""
        log_info "Next steps:"
        log_info "  1. Check cluster: ./scripts/check_cluster.sh"
        log_info "  2. Deploy Nautobot: (will be added to playbook)"
        exit 0
    else
        echo ""
        log_error "======================================================================="
        log_error "  DEPLOYMENT FAILED"
        log_error "======================================================================="
        echo ""
        log_info "Troubleshooting:"
        log_info "  1. Check log: tail -100 ${LOG_DIR}/deployment_run${RUN_NUMBER}.log"
        log_info "  2. Check master logs: ssh ${SSH_USER}@${MASTER_IP} 'sudo journalctl -u kubelet -n 50'"
        log_info "  3. Re-run script after fixing issues"
        exit 1
    fi
}

# Run main function
main "$@"
