#!/bin/bash
# Fully Automated SSH Key Deployment
# Uses expect to handle password prompts automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 Fully Automated SSH Key Deployment${NC}"
echo "========================================"

# Check if expect is installed
if ! command -v expect &> /dev/null; then
    echo "📦 Installing expect..."
    sudo apt-get update -qq && sudo apt-get install -y expect >/dev/null 2>&1
    echo -e "${GREEN}✅ expect installed${NC}"
fi

# Ensure SSH key exists
if [ ! -f ~/.ssh/ansible-ci ]; then
    echo "📝 Generating SSH key pair..."
    ssh-keygen -t ed25519 -f ~/.ssh/ansible-ci -N "" -C "ansible-ci"
    chmod 600 ~/.ssh/ansible-ci
    chmod 644 ~/.ssh/ansible-ci.pub
fi

PUBKEY=$(cat ~/.ssh/ansible-ci.pub)
echo -e "${GREEN}✅ SSH key ready${NC}"
echo ""

# Get SSH password from vault
VAULT_FILE="$PROJECT_ROOT/group_vars/all/vault.yml"
VAULT_PASS_FILE="${ANSIBLE_VAULT_PASSWORD_FILE:-$HOME/.vault_pass}"

if [ -f "$VAULT_FILE" ] && [ -f "$VAULT_PASS_FILE" ]; then
    echo "🔓 Decrypting vault to get SSH password..."
    SSH_PASS=$(ansible-vault view "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE" 2>/dev/null | grep "vault_ssh_password:" | cut -d'"' -f2)
    
    if [ -z "$SSH_PASS" ]; then
        echo -e "${YELLOW}⚠️  Could not extract SSH password from vault${NC}"
        echo -e "${YELLOW}⚠️  Will test SSH key access only${NC}"
        USE_PASSWORD=0
    else
        echo -e "${GREEN}✅ SSH password retrieved from vault${NC}"
        USE_PASSWORD=1
    fi
else
    echo -e "${YELLOW}⚠️  Vault file not found, SSH key deployment may require manual intervention${NC}"
    USE_PASSWORD=0
fi

echo ""

# Get list of VMs
VMS=$(grep -oP 'ansible_host:\s+\K[\d.]+' "$PROJECT_ROOT/inventory/k8s/onprem.yml" | sort -u)

echo -e "${BLUE}🎯 Target VMs:${NC}"
echo "$VMS" | while read vm; do echo "   - $vm"; done
echo ""

SUCCESS=0
FAILED=0
SKIPPED=0

# Test and deploy to each VM
for vm in $VMS; do
    # Skip the runner itself
    if [ "$vm" == "172.17.152.102" ]; then
        echo -e "⏭️  ${vm} - Skipped (runner itself)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    echo -n "🔍 ${vm} - "
    
    # Test if SSH key already works
    if ssh -i ~/.ssh/ansible-ci -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           -o BatchMode=yes -o PreferredAuthentications=publickey \
           ubuntu@$vm "echo ok" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SSH key already works${NC}"
        SUCCESS=$((SUCCESS + 1))
        continue
    fi
    
    # Try to deploy key using password
    if [ $USE_PASSWORD -eq 1 ]; then
        echo -n "Deploying key with password... "
        chmod +x "$SCRIPT_DIR/deploy_key_expect.exp"
        
        if "$SCRIPT_DIR/deploy_key_expect.exp" "$SSH_PASS" "$vm" "$PUBKEY" >/dev/null 2>&1; then
            # Verify it worked
            if ssh -i ~/.ssh/ansible-ci -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                   -o BatchMode=yes ubuntu@$vm "echo ok" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Key deployed successfully${NC}"
                SUCCESS=$((SUCCESS + 1))
            else
                echo -e "${RED}❌ Key deployment failed (verification failed)${NC}"
                FAILED=$((FAILED + 1))
            fi
        else
            echo -e "${RED}❌ Password authentication failed${NC}"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${YELLOW}⚠️  No password available, manual deployment needed${NC}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "========================================"
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "   ${GREEN}Success: $SUCCESS${NC}"
echo -e "   ${RED}Failed:  $FAILED${NC}"
echo -e "   ${YELLOW}Skipped: $SKIPPED${NC}"
echo""

if [ $FAILED -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some VMs still need manual key deployment${NC}"
    echo ""
    echo "Run this command on each failed VM:"
    echo -e "${BLUE}echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys${NC}"
    echo ""
fi

# Exit 0 even if some failed - don't block the pipeline
exit 0
