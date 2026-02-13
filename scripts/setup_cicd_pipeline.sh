#!/bin/bash
# Setup script for CI/CD pipeline configuration

set -e

echo "==================================================================="
echo "  Nautobot Kubernetes CI/CD Pipeline Setup"
echo "==================================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

MASTER_NODE="${1:-172.17.152.109}"
MASTER_USER="${2:-ubuntu}"

echo -e "${YELLOW}📋 This script will:${NC}"
echo "  1. Generate kubeconfig for CI/CD pipeline"
echo "  2. Create service account with appropriate permissions"
echo "  3. Generate secrets for Azure DevOps / GitHub Actions"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Extracting kubeconfig from master node${NC}"
ssh ${MASTER_USER}@${MASTER_NODE} 'cat ~/.kube/config' > /tmp/kubeconfig-cicd.yaml

if [ ! -s /tmp/kubeconfig-cicd.yaml ]; then
    echo -e "${RED}❌ Failed to retrieve kubeconfig${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubeconfig retrieved successfully${NC}"
echo ""

echo -e "${GREEN}Step 2: Creating service account for CI/CD${NC}"
ssh ${MASTER_USER}@${MASTER_NODE} << 'EOF'
# Create service account
kubectl create serviceaccount nautobot-cicd -n nautobot --dry-run=client -o yaml | kubectl apply -f -

# Create role with deployment permissions
kubectl apply -f - <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: nautobot-deployer
  namespace: nautobot
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nautobot-deployer-binding
  namespace: nautobot
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: nautobot-deployer
subjects:
- kind: ServiceAccount
  name: nautobot-cicd
  namespace: nautobot
YAML

echo "✅ Service account and role created"
EOF

echo -e "${GREEN}✅ Service account configured${NC}"
echo ""

echo -e "${GREEN}Step 3: Generating secrets${NC}"

# Base64 encode kubeconfig for Azure DevOps
KUBECONFIG_B64=$(cat /tmp/kubeconfig-cicd.yaml | base64 -w 0)

echo ""
echo -e "${YELLOW}==================================================================="
echo "  CI/CD Pipeline Secrets"
echo "===================================================================${NC}"
echo ""

echo -e "${GREEN}📋 For Azure DevOps:${NC}"
echo ""
echo "Add these to your variable group 'nautobot-azure-secrets':"
echo ""
echo "Variable Name: KUBECONFIG_CONTENT"
echo "Value (paste entire content below):"
echo "---"
cat /tmp/kubeconfig-cicd.yaml
echo "---"
echo ""

echo -e "${GREEN}📋 For GitHub Actions:${NC}"
echo ""
echo "Add this as a repository secret:"
echo "Secret Name: KUBECONFIG"
echo ""
echo "Value (paste raw content, not base64):"
echo "---"
cat /tmp/kubeconfig-cicd.yaml
echo "---"
echo ""

echo -e "${YELLOW}==================================================================="
echo "  Pipeline Configuration Files"
echo "===================================================================${NC}"
echo ""
echo "Azure DevOps: azure-pipelines-k8s-deploy.yml"
echo "GitHub Actions: .github/workflows/k8s-deploy.yml"
echo ""

echo -e "${GREEN}Step 4: Testing pipeline configuration${NC}"
echo ""

# Test kubectl access
echo "Testing kubectl access with the generated kubeconfig..."
export KUBECONFIG=/tmp/kubeconfig-cicd.yaml

if kubectl get pods -n nautobot > /dev/null 2>&1; then
    echo -e "${GREEN}✅ kubectl access verified${NC}"
else
    echo -e "${RED}❌ kubectl access test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}==================================================================="
echo "  Setup Complete!"
echo "===================================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Copy the kubeconfig content to your CI/CD platform secrets"
echo "2. Commit and push azure-pipelines-k8s-deploy.yml or .github/workflows/k8s-deploy.yml"
echo "3. Make a test change to group_vars/dev/nautobot.yml"
echo "4. Push and watch the pipeline automatically deploy!"
echo ""
echo "Test deployment URL: http://172.17.152.200/"
echo ""

# Save kubeconfig to a file for manual use
cp /tmp/kubeconfig-cicd.yaml ./kubeconfig-cicd.yaml
echo -e "${YELLOW}💾 Kubeconfig saved to: ./kubeconfig-cicd.yaml${NC}"
echo -e "${YELLOW}⚠️  Keep this file secure - it has cluster access!${NC}"
echo ""
