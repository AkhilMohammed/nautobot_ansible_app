# Deploy from Azure Cloud Shell

## 1. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/nautobot_key -N ""
cat ~/.ssh/nautobot_key.pub
```

Copy the public key output.

## 2. Clone Repository

```bash
git clone https://akhiltaj0496@dev.azure.com/akhiltaj0496/Nautobot/_git/Nautobot
cd Nautobot/terraform
```

## 3. Set Environment Variables

```bash
export ARM_CLIENT_ID="<your-service-principal-app-id>"
export ARM_CLIENT_SECRET="<your-service-principal-password>"
export ARM_SUBSCRIPTION_ID="9b5bcc59-580a-4bd3-b729-4c4fd52e2682"
export ARM_TENANT_ID="4e0f0e10-1f5c-40b9-844c-daff47c7a6cf"
export TF_VAR_db_admin_password="YourSecurePassword123!"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/nautobot_key.pub)"
```

## 4. Create Backend Config

```bash
cat > backend-dev.hcl << EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstate87003"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
EOF
```

## 5. Deploy Infrastructure

```bash
# Initialize
terraform init -backend-config=backend-dev.hcl

# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars -auto-approve
```

## 6. Get Outputs

```bash
terraform output -json > outputs.json
terraform output load_balancer_public_ip
```

## 7. Save Private Key

Download your private key for later SSH access:

```bash
cat ~/.ssh/nautobot_key
```

Copy and save this securely on your local machine.
