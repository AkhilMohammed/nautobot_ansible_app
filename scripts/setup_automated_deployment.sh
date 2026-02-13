#!/bin/bash
# ==============================================================================
# AUTOMATED NAUTOBOT DEPLOYMENT - CUSTOMER SETUP SCRIPT
# ==============================================================================
# This script configures the CI/CD pipeline for automatic deployments
# Run once to setup, then all future deployments are automatic
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   🚀 NAUTOBOT K8S AUTOMATED DEPLOYMENT - SETUP WIZARD           ║
║                                                                  ║
║   This wizard will configure automatic deployment pipeline       ║
║   for your Nautobot Kubernetes infrastructure                   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to prompt user
prompt() {
    echo -e "${YELLOW}$1${NC}"
    read -p "> " response
    echo "$response"
}

# Check prerequisites
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Checking Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for required tools
command -v git >/dev/null 2>&1 || { print_error "git is not installed. Please install git."; exit 1; }
command -v ssh >/dev/null 2>&1 || { print_error "ssh is not installed. Please install openssh."; exit 1; }

print_status "Prerequisites check passed"

# Determine CI/CD platform
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Select CI/CD Platform"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Which CI/CD platform are you using?"
echo "1) Azure DevOps"
echo "2) GitHub Actions"
echo "3) Both"
echo ""
CICD_PLATFORM=$(prompt "Enter choice (1-3)")

# Gather configuration information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Gather Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get Kubernetes master IP
K8S_MASTER_IP=$(prompt "Enter your Kubernetes master node IP address")

# Get SSH key location
DEFAULT_SSH_KEY="$HOME/.ssh/id_rsa"
echo ""
print_info "SSH key is needed to access Kubernetes nodes"
SSH_KEY_PATH=$(prompt "Enter SSH private key path (default: $DEFAULT_SSH_KEY)")
SSH_KEY_PATH=${SSH_KEY_PATH:-$DEFAULT_SSH_KEY}

if [ ! -f "$SSH_KEY_PATH" ]; then
    print_error "SSH key not found at: $SSH_KEY_PATH"
    exit 1
fi

print_status "SSH key found"

# Extract kubeconfig from master node
echo ""
print_info "Extracting kubeconfig from Kubernetes master..."

ssh -o StrictHostKeyChecking=no ubuntu@$K8S_MASTER_IP "cat ~/.kube/config" > /tmp/kubeconfig.yaml 2>/dev/null || {
    print_error "Failed to extract kubeconfig from master node"
    print_warning "Make sure you can SSH to ubuntu@$K8S_MASTER_IP"
    exit 1
}

print_status "Kubeconfig extracted successfully"

# Setup Azure DevOps
if [ "$CICD_PLATFORM" == "1" ] || [ "$CICD_PLATFORM" == "3" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "STEP 4a: Azure DevOps Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_info "You need to create a Variable Group in Azure DevOps"
    echo ""
    echo "Steps to configure Azure DevOps:"
    echo ""
    echo "1. Go to Azure DevOps → Pipelines → Library"
    echo "2. Click '+ Variable group'"
    echo "3. Name it: nautobot-k8s-secrets"
    echo "4. Add these variables:"
    echo ""
    echo "   Variable Name          | Value (click 'Show/Hide' to see)"
    echo "   ─────────────────────────────────────────────────────────"
    echo "   SSH_PRIVATE_KEY        | (copy from below)"
    echo "   KUBECONFIG_CONTENT     | (copy from below)"
    echo "   GRAFANA_PASSWORD       | admin123 (change this!)"
    echo "   LETSENCRYPT_EMAIL      | your-email@company.com"
    echo ""
    echo "5. Click 'Save'"
    echo ""
    
    print_warning "Press Enter when ready to see the secret values..."
    read
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SSH_PRIVATE_KEY (copy this entire content):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$SSH_KEY_PATH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "KUBECONFIG_CONTENT (copy this entire content):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat /tmp/kubeconfig.yaml
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_warning "After adding all variables, press Enter to continue..."
    read
    
    # Create/update Azure pipeline file
    echo ""
    print_info "Setting up Azure pipeline..."
    
    if [ -f "azure-pipelines-automated.yml" ]; then
        print_status "Pipeline file already exists: azure-pipelines-automated.yml"
    fi
    
    echo ""
    echo "To activate the pipeline:"
    echo "1. Go to Azure DevOps → Pipelines"
    echo "2. Click 'New pipeline'"
    echo "3. Select your repository"
    echo "4. Choose 'Existing Azure Pipelines YAML file'"
    echo "5. Select: azure-pipelines-automated.yml"
    echo "6. Click 'Run'"
    echo ""
fi

# Setup GitHub Actions
if [ "$CICD_PLATFORM" == "2" ] || [ "$CICD_PLATFORM" == "3" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "STEP 4b: GitHub Actions Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_info "You need to add Repository Secrets in GitHub"
    echo ""
    echo "Steps to configure GitHub Actions:"
    echo ""
    echo "1. Go to GitHub → Your Repository → Settings → Secrets and variables → Actions"
    echo "2. Click 'New repository secret'"
    echo "3. Add these secrets:"
    echo ""
    echo "   Secret Name            | Value"
    echo "   ─────────────────────────────────────────────────────────"
    echo "   SSH_PRIVATE_KEY        | (copy from below)"
    echo "   KUBECONFIG             | (copy from below)"
    echo "   GRAFANA_PASSWORD       | admin123 (change this!)"
    echo "   LETSENCRYPT_EMAIL      | your-email@company.com"
    echo ""
    
    print_warning "Press Enter when ready to see the secret values..."
    read
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SSH_PRIVATE_KEY:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$SSH_KEY_PATH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "KUBECONFIG:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat /tmp/kubeconfig.yaml
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_warning "After adding all secrets, press Enter to continue..."
    read
    
    if [ -d ".github/workflows" ] && [ -f ".github/workflows/deploy-nautobot.yml" ]; then
        print_status "GitHub workflow already exists: .github/workflows/deploy-nautobot.yml"
    fi
fi

# Create example configuration
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Configuration Example"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat > /tmp/nautobot-config-example.yml << 'EOF'
# Example configuration for group_vars/dev/nautobot.yml
# Edit this file to trigger automatic deployment

nautobot_version: "2.1.0"
nautobot_image: "networktocode/nautobot"

# Scaling configuration
web_replicas: 2
worker_replicas: 2
scheduler_replicas: 1

# Database configuration
postgres_db: "nautobot"
postgres_user: "nautobot"
postgres_password: "changeme"  # Use Azure Key Vault for production

# Redis configuration
redis_password: "changeme"  # Use Azure Key Vault for production

# Nautobot superuser
nautobot_superuser_username: "admin"
nautobot_superuser_email: "admin@example.com"
nautobot_superuser_password: "admin123"  # Change this!

# Nautobot configuration
nautobot_config:
  ALLOWED_HOSTS:
    - "*"
  TIME_ZONE: "UTC"
  PLUGINS:
    - "nautobot_golden_config"
    - "nautobot_device_lifecycle_mgmt"
  
  # Add any additional Nautobot settings here
EOF

print_status "Example configuration created at: /tmp/nautobot-config-example.yml"
echo ""
print_info "To deploy, edit group_vars/dev/nautobot.yml with your configuration"
echo ""

# Create quick reference
cat > AUTOMATED_DEPLOYMENT.md << 'EOF'
# Automated Nautobot Deployment - Quick Reference

## 🚀 How to Deploy

### Method 1: Automatic (Recommended)
1. Edit `group_vars/dev/nautobot.yml` with your configuration
2. Commit and push to your repository:
   ```bash
   git add group_vars/dev/nautobot.yml
   git commit -m "Update Nautobot configuration"
   git push origin main
   ```
3. Pipeline automatically triggers and deploys!
4. Watch the pipeline progress in Azure DevOps or GitHub Actions
5. Access your Nautobot instance at the URL shown in pipeline output

### Method 2: Manual Trigger
Azure DevOps:
- Go to Pipelines → Select pipeline → Run pipeline

GitHub Actions:
- Go to Actions → Deploy Nautobot to Kubernetes → Run workflow

## 📝 Configuration Files

- `group_vars/dev/nautobot.yml` - Development environment
- `group_vars/test/nautobot.yml` - Test/Staging environment
- `group_vars/prod/nautobot.yml` - Production environment

## 🔄 Deployment Flow

```
Edit Config → Push to Git → Pipeline Triggers → Deploy K8s → Deploy Nautobot → Health Checks → Done!
```

## 📊 Pipeline Stages

1. **Initialize & Validate** - Validate configuration files
2. **Deploy Cluster** - Setup Kubernetes cluster (if needed)
3. **Deploy Nautobot** - Deploy/update Nautobot application
4. **Validate** - Run health checks and verify deployment

## 🔐 Secrets Required

Azure DevOps (Variable Group: `nautobot-k8s-secrets`):
- `SSH_PRIVATE_KEY` - SSH key for node access
- `KUBECONFIG_CONTENT` - Kubernetes config file
- `GRAFANA_PASSWORD` - Grafana admin password (prod only)
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt certificates (prod only)

GitHub Actions (Repository Secrets):
- `SSH_PRIVATE_KEY` - SSH key for node access
- `KUBECONFIG` - Kubernetes config file
- `GRAFANA_PASSWORD` - Grafana admin password (prod only)
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt certificates (prod only)

## 🎯 Environment Mapping

- `main` branch → Production (`prod`)
- `staging` branch → Test (`test`)
- `develop` branch → Development (`dev`)

## 🧪 Testing Changes

1. Create a feature branch
2. Make changes to configuration
3. Push and create Pull Request
4. Pipeline runs validation (no deployment)
5. After approval, merge to target branch
6. Automatic deployment to environment

## 📈 Monitoring

Production deployments include:
- Prometheus metrics collection
- Grafana dashboards
- Automated backups (daily at 2 AM)
- Auto-scaling (3-10 replicas)
- Network policies
- TLS certificates (Let's Encrypt)

## 🆘 Troubleshooting

### Pipeline Fails at "Check Cluster Status"
- Verify SSH_PRIVATE_KEY is correct
- Check inventory file has correct master IP
- Ensure master node is accessible

### Pipeline Fails at "Deploy with Helm"
- Check KUBECONFIG is valid
- Verify namespace exists
- Check Helm chart syntax: `helm lint helm/nautobot`

### Application Not Accessible
- Check LoadBalancer IP: `kubectl get svc -n ingress-nginx`
- Verify pods are running: `kubectl get pods -n nautobot`
- Check ingress: `kubectl get ingress -n nautobot`

## 📚 Additional Resources

- [Production Checklist](PRODUCTION_CHECKLIST.md)
- [K8s Deployment Guide](K8S_CICD_DEPLOYMENT_GUIDE.md)
- [Architecture Diagram](ARCHITECTURE_DIAGRAM.md)
EOF

print_status "Quick reference guide created: AUTOMATED_DEPLOYMENT.md"

# Final summary
echo ""
echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ✅ SETUP COMPLETE!                                            ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Configure your CI/CD secrets (see above)"
echo ""
echo "2. Edit your configuration file:"
echo "   vi group_vars/dev/nautobot.yml"
echo ""
echo "3. Commit and push to trigger deployment:"
echo "   git add group_vars/dev/nautobot.yml"
echo "   git commit -m 'Initial Nautobot configuration'"
echo "   git push origin main"
echo ""
echo "4. Watch the pipeline deploy automatically!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_status "Configuration saved:"
echo "   - Example config: /tmp/nautobot-config-example.yml"
echo "   - Quick reference: ./AUTOMATED_DEPLOYMENT.md"
echo ""
print_info "Need help? Check AUTOMATED_DEPLOYMENT.md for troubleshooting"
echo ""

# Cleanup
rm -f /tmp/kubeconfig.yaml

print_status "Setup wizard complete! 🎉"
echo ""
