#!/bin/bash
# Complete deployment script: Terraform + Ansible
# This script orchestrates the full deployment of Nautobot infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Nautobot Complete Deployment${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print step
print_step() {
    echo -e "\n${GREEN}▶ $1${NC}\n"
}

# Function to print error
print_error() {
    echo -e "\n${RED}✗ $1${NC}\n"
}

# Function to print success
print_success() {
    echo -e "\n${GREEN}✓ $1${NC}\n"
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install Terraform."
    exit 1
fi

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found. Please install Azure CLI."
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    print_error "Ansible not found. Please install Ansible."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    print_error "Python3 not found. Please install Python3."
    exit 1
fi

# Check Azure login
print_step "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run: az login"
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
print_success "Logged in to Azure subscription: $SUBSCRIPTION"

# Check Terraform directory
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Check terraform.tfvars
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    print_error "terraform.tfvars not found in $TERRAFORM_DIR"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and customize it."
    exit 1
fi

# Deploy Infrastructure with Terraform
print_step "Step 1: Deploying Azure infrastructure with Terraform..."
cd "$TERRAFORM_DIR"

# Initialize Terraform
print_step "Initializing Terraform..."
terraform init -upgrade

# Validate configuration
print_step "Validating Terraform configuration..."
terraform validate

# Plan
print_step "Planning Terraform changes..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "$(echo -e ${YELLOW}Do you want to apply these changes? [y/N]:${NC} )" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Deployment cancelled by user"
    exit 1
fi

# Apply
print_step "Applying Terraform changes (this may take 10-15 minutes)..."
terraform apply tfplan

print_success "Terraform deployment completed!"

# Get outputs
print_step "Getting Terraform outputs..."
LB_PUBLIC_IP=$(terraform output -raw lb_public_ip)
echo "Load Balancer IP: $LB_PUBLIC_IP"

# Update Ansible Inventory
print_step "Step 2: Updating Ansible inventory from Terraform..."
cd "$PROJECT_ROOT"
python3 scripts/update_inventory_from_terraform.py --environment "$ENVIRONMENT"

print_success "Ansible inventory updated!"

# Wait for VMs to be ready
print_step "Waiting for VMs to complete cloud-init (60 seconds)..."
sleep 60

# Test connectivity
print_step "Step 3: Testing connectivity to all hosts..."
if ansible -i "inventory/vm/${ENVIRONMENT}.yml" all -m ping; then
    print_success "All hosts are reachable!"
else
    print_error "Some hosts are not reachable. Check your SSH keys and network configuration."
    echo "You can manually test: ansible -i inventory/vm/${ENVIRONMENT}.yml all -m ping"
    exit 1
fi

# Deploy with Ansible
print_step "Step 4: Deploying Nautobot application with Ansible..."
read -p "$(echo -e ${YELLOW}Proceed with Ansible deployment? [y/N]:${NC} )" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Ansible deployment skipped"
    echo "You can manually deploy later with:"
    echo "  ansible-playbook -i inventory/vm/${ENVIRONMENT}.yml playbooks/deploy_vm_all.yml"
    exit 0
fi

# Run Ansible playbook
ansible-playbook \
    -i "inventory/vm/${ENVIRONMENT}.yml" \
    playbooks/deploy_vm_all.yml \
    -e "deploy_env=${ENVIRONMENT}"

# Final status
print_step "Step 5: Deployment Summary"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "Environment:    ${BLUE}${ENVIRONMENT}${NC}"
echo -e "Load Balancer:  ${BLUE}${LB_PUBLIC_IP}${NC}"
echo -e "Nautobot URL:   ${BLUE}https://${LB_PUBLIC_IP}${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Access Nautobot: https://${LB_PUBLIC_IP}"
echo "   (Accept the self-signed certificate warning)"
echo ""
echo "2. Create a superuser (SSH to any web VM):"
echo "   az vmss list-instance-connection-info \\"
echo "     --resource-group rg-nautobot-${ENVIRONMENT} \\"
echo "     --name vmss-nautobot-web-${ENVIRONMENT}"
echo ""
echo "3. Monitor deployment:"
echo "   - Azure Portal: Resource Group 'rg-nautobot-${ENVIRONMENT}'"
echo "   - Logs: SSH to VMs and check /opt/nautobot/logs/"
echo ""
echo "4. Scale web or worker tier:"
echo "   az vmss scale --name vmss-nautobot-web-${ENVIRONMENT} --new-capacity 3 --resource-group rg-nautobot-${ENVIRONMENT}"
echo ""
echo -e "${GREEN}========================================${NC}\n"

print_success "All done! 🎉"
