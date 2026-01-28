#!/bin/bash
# Complete Deployment Script for Azure Cloud Shell
# No Service Principal Required - Uses your user credentials

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Nautobot Azure Deployment from Cloud Shell                ║"
echo "║  No Service Principal Required!                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
SUBSCRIPTION_ID="21d6c80f-f009-47c2-8488-91b2ede27f69"
LOCATION="eastus"
ENV="dev"
DB_PASSWORD="NautobotDB$(date +%s)!"
STORAGE_ACCOUNT="tfstate$(date +%s | tail -c 6)"

echo "📋 Configuration:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Location: $LOCATION"
echo "  Environment: $ENV"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo ""

# Step 1: Verify login
echo "🔐 Step 1: Verifying Azure login..."
az account show
az account set --subscription $SUBSCRIPTION_ID
echo "✅ Logged in as: $(az account show --query user.name -o tsv)"
echo ""

# Step 2: Create Terraform state storage
echo "📦 Step 2: Creating Terraform state storage..."
az group create --name terraform-state-rg --location $LOCATION --output table
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group terraform-state-rg \
  --location $LOCATION \
  --sku Standard_LRS \
  --output table

STORAGE_KEY=$(az storage account keys list \
  --resource-group terraform-state-rg \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)

az storage container create \
  --name tfstate \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY
echo "✅ Storage account created: $STORAGE_ACCOUNT"
echo ""

# Step 3: Install Terraform
echo "🔧 Step 3: Installing Terraform..."
if ! command -v terraform &> /dev/null; then
    cd ~
    wget -q https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
    unzip -q terraform_1.7.0_linux_amd64.zip
    mkdir -p ~/bin
    mv terraform ~/bin/
    export PATH=$PATH:~/bin
    rm terraform_1.7.0_linux_amd64.zip
fi
terraform version
echo "✅ Terraform installed"
echo ""

# Step 4: Clone or use existing code
echo "📥 Step 4: Preparing code..."
if [ -d "~/nautobot_ansible_app" ]; then
    echo "Code already exists, updating..."
    cd ~/nautobot_ansible_app
    git pull || true
else
    echo "Please upload your code to Cloud Shell or clone from Git"
    echo "Run: git clone <your-repo-url> ~/nautobot_ansible_app"
    echo "Then run this script again"
    exit 1
fi
echo ""

# Step 5: Configure Terraform backend
echo "⚙️  Step 5: Configuring Terraform..."
cd ~/nautobot_ansible_app/terraform

cat > backend-dev.hcl << EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "$STORAGE_ACCOUNT"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
access_key           = "$STORAGE_KEY"
EOF

# Create SSH key if needed
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N "" -q
fi

echo "✅ Configuration complete"
echo ""

# Step 6: Initialize Terraform
echo "🏗️  Step 6: Initializing Terraform..."
terraform init -backend-config=backend-dev.hcl
echo "✅ Terraform initialized"
echo ""

# Step 7: Plan
echo "📋 Step 7: Planning deployment..."
terraform plan \
  -var-file=environments/dev.tfvars \
  -var="db_admin_password=$DB_PASSWORD" \
  -var="ssh_public_key_path=$HOME/.ssh/id_rsa.pub" \
  -out=tfplan
echo "✅ Plan created"
echo ""

# Step 8: Apply
echo "🚀 Step 8: Deploying infrastructure..."
echo "This will take 15-20 minutes..."
terraform apply tfplan

# Step 9: Save outputs
echo "📊 Step 9: Saving outputs..."
terraform output -json > /tmp/terraform_outputs.json
terraform output > /tmp/terraform_outputs.txt

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  🎉 DEPLOYMENT COMPLETE!                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Infrastructure Details:"
echo "=========================="
cat /tmp/terraform_outputs.txt
echo ""
echo "🔐 IMPORTANT - Save These Credentials:"
echo "======================================"
echo "Database Password: $DB_PASSWORD"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Storage Key: $STORAGE_KEY"
echo ""
echo "💾 Outputs saved to:"
echo "  - /tmp/terraform_outputs.json"
echo "  - /tmp/terraform_outputs.txt"
echo ""
echo "📝 Next Steps:"
echo "1. Download the outputs file for your records"
echo "2. Run Ansible to deploy the application"
echo "3. Access Nautobot at the Load Balancer IP shown above"
echo ""
echo "💰 Cost Estimate: ~$4/day (~$28 for 7 days)"
echo ""
