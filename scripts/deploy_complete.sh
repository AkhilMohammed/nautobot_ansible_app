#!/bin/bash

# Complete Deployment Script for Nautobot with Azure Managed Services
# Usage: ./deploy_complete.sh <environment> <action>
# Example: ./deploy_complete.sh dev deploy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <environment> <action>"
    echo "Environments: dev, test, prod"
    echo "Actions: plan, deploy, destroy, update-ansible"
    exit 1
fi

ENVIRONMENT=$1
ACTION=$2

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT"
    echo "Valid environments: dev, test, prod"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|deploy|destroy|update-ansible)$ ]]; then
    log_error "Invalid action: $ACTION"
    echo "Valid actions: plan, deploy, destroy, update-ansible"
    exit 1
fi

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
INVENTORY_DIR="$PROJECT_ROOT/inventory/vm"
GROUP_VARS_DIR="$PROJECT_ROOT/group_vars"

log_info "Starting deployment for $ENVIRONMENT environment..."
log_info "Project root: $PROJECT_ROOT"

# Check if .env file exists
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    log_warning ".env file not found. Creating template..."
    cat > "$PROJECT_ROOT/.env" << EOF
# Azure Service Principal Credentials
export ARM_CLIENT_ID="<service-principal-app-id>"
export ARM_CLIENT_SECRET="<service-principal-password>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"

# Database Password (minimum 8 characters, alphanumeric + special chars)
export TF_VAR_db_admin_password="<strong-password>"

# SSH Public Key Path
export TF_VAR_ssh_public_key_path="$HOME/.ssh/id_rsa.pub"
EOF
    log_error "Please update .env file with your Azure credentials and rerun"
    exit 1
fi

# Load environment variables
log_info "Loading environment variables..."
source "$PROJECT_ROOT/.env"

# Verify required variables
if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ] || [ -z "$ARM_SUBSCRIPTION_ID" ] || [ -z "$ARM_TENANT_ID" ]; then
    log_error "Azure credentials not set in .env file"
    exit 1
fi

if [ -z "$TF_VAR_db_admin_password" ]; then
    log_error "Database password not set in .env file"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    log_info "Initializing Terraform..."
    terraform init -backend-config="backend-${ENVIRONMENT}.hcl"
fi

# Execute action
case $ACTION in
    plan)
        log_info "Planning Terraform deployment for $ENVIRONMENT..."
        terraform plan \
            -var-file="environments/${ENVIRONMENT}.tfvars" \
            -var="environment=${ENVIRONMENT}" \
            -out="tfplan-${ENVIRONMENT}"
        
        log_success "Terraform plan completed. Review above output."
        log_info "To apply: $0 $ENVIRONMENT deploy"
        ;;
        
    deploy)
        log_info "Deploying infrastructure for $ENVIRONMENT..."
        
        # Check if plan exists
        if [ ! -f "tfplan-${ENVIRONMENT}" ]; then
            log_warning "Plan file not found. Creating plan first..."
            terraform plan \
                -var-file="environments/${ENVIRONMENT}.tfvars" \
                -var="environment=${ENVIRONMENT}" \
                -out="tfplan-${ENVIRONMENT}"
        fi
        
        # Apply Terraform
        log_info "Applying Terraform changes..."
        terraform apply "tfplan-${ENVIRONMENT}"
        
        log_success "Infrastructure deployed successfully!"
        
        # Generate Ansible inventory
        log_info "Generating Ansible inventory and variables..."
        cd "$PROJECT_ROOT"
        python3 scripts/terraform_to_ansible.py "$ENVIRONMENT"
        
        log_success "Ansible integration completed!"
        
        # Check if vault.yml exists
        VAULT_FILE="$GROUP_VARS_DIR/${ENVIRONMENT}/vault.yml"
        if [ ! -f "$VAULT_FILE" ]; then
            log_warning "Vault file not found: $VAULT_FILE"
            log_info "Please create and encrypt vault file:"
            echo ""
            echo "  1. cp $GROUP_VARS_DIR/${ENVIRONMENT}/vault_template.yml $VAULT_FILE"
            echo "  2. Edit $VAULT_FILE with real secrets"
            echo "  3. ansible-vault encrypt $VAULT_FILE"
            echo ""
        fi
        
        # Display next steps
        echo ""
        log_success "Infrastructure deployment complete!"
        echo ""
        echo "Next steps:"
        echo "==========="
        echo "1. Review generated files:"
        echo "   - Inventory: inventory/vm/${ENVIRONMENT}_dynamic.yml"
        echo "   - Variables: group_vars/${ENVIRONMENT}/terraform.yml"
        echo ""
        echo "2. Configure secrets (if not done):"
        echo "   - Update: group_vars/${ENVIRONMENT}/vault.yml"
        echo "   - Encrypt: ansible-vault encrypt group_vars/${ENVIRONMENT}/vault.yml"
        echo ""
        echo "3. Test connectivity:"
        echo "   ansible all -i inventory/vm/${ENVIRONMENT}_dynamic.yml -m ping --ask-vault-pass"
        echo ""
        echo "4. Deploy Nautobot application:"
        echo "   ansible-playbook -i inventory/vm/${ENVIRONMENT}_dynamic.yml playbooks/deploy_vm_all.yml --ask-vault-pass"
        echo ""
        
        # Display outputs
        cd "$TERRAFORM_DIR"
        echo "Infrastructure Details:"
        echo "======================"
        terraform output load_balancer_public_ip
        terraform output load_balancer_fqdn
        terraform output postgresql_server_fqdn
        terraform output redis_hostname
        ;;
        
    destroy)
        log_warning "This will DESTROY all infrastructure for $ENVIRONMENT!"
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        
        if [ "$confirm" != "yes" ]; then
            log_info "Destroy cancelled."
            exit 0
        fi
        
        log_info "Destroying infrastructure for $ENVIRONMENT..."
        terraform destroy \
            -var-file="environments/${ENVIRONMENT}.tfvars" \
            -var="environment=${ENVIRONMENT}"
        
        log_success "Infrastructure destroyed."
        
        # Clean up generated files
        log_info "Cleaning up generated Ansible files..."
        rm -f "$INVENTORY_DIR/${ENVIRONMENT}_dynamic.yml"
        rm -f "$GROUP_VARS_DIR/${ENVIRONMENT}/terraform.yml"
        
        log_success "Cleanup complete."
        ;;
        
    update-ansible)
        log_info "Updating Ansible inventory and variables from Terraform..."
        cd "$PROJECT_ROOT"
        python3 scripts/terraform_to_ansible.py "$ENVIRONMENT"
        log_success "Ansible files updated!"
        ;;
        
    *)
        log_error "Unknown action: $ACTION"
        exit 1
        ;;
esac

log_success "Operation completed successfully!"
