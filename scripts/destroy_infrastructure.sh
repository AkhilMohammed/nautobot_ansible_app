#!/bin/bash
# Destroy Infrastructure Script
# Use this to tear down all Azure resources

set -e

ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}DESTROY NAUTOBOT INFRASTRUCTURE${NC}"
echo -e "${RED}Environment: $ENVIRONMENT${NC}"
echo -e "${RED}========================================${NC}\n"

echo -e "${YELLOW}WARNING: This will DELETE all resources!${NC}"
echo -e "${YELLOW}This action CANNOT be undone!${NC}\n"

# Double confirmation
read -p "$(echo -e ${RED}Type the environment name to confirm [$ENVIRONMENT]:${NC} )" CONFIRM_ENV
if [ "$CONFIRM_ENV" != "$ENVIRONMENT" ]; then
    echo "Environment name mismatch. Aborting."
    exit 1
fi

read -p "$(echo -e ${RED}Type 'yes' to destroy all resources:${NC} )" CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Navigate to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
terraform init

# Destroy
echo -e "\n${RED}Destroying infrastructure...${NC}\n"
terraform destroy -auto-approve

echo -e "\n${RED}Infrastructure destroyed!${NC}\n"
