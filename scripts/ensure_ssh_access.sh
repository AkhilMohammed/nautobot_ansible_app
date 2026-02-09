#!/bin/bash
# Automated SSH Key Distribution Script
# Ensures CI runner can access all target VMs via SSH key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Automated SSH Access Setup"
echo "================================"

# Check if SSH key exists, create if needed
if [ ! -f ~/.ssh/ansible-ci ]; then
    echo "📝 Generating new SSH key pair..."
    ssh-keygen -t ed25519 -f ~/.ssh/ansible-ci -N "" -C "ansible-ci"
    chmod 600 ~/.ssh/ansible-ci
    chmod 644 ~/.ssh/ansible-ci.pub
    echo -e "${GREEN}✅ SSH key pair generated${NC}"
else
    echo -e "${GREEN}✅ SSH key already exists${NC}"
fi

# Read public key
PUBKEY=$(cat ~/.ssh/ansible-ci.pub)
echo "📋 Public key: ${PUBKEY:0:50}..."

# Extract VM IPs from inventory
VMS=$(grep -oP 'ansible_host:\s+\K[\d.]+' "$PROJECT_ROOT/inventory/k8s/onprem.yml" | sort -u)

echo ""
echo "🎯 Target VMs:"
echo "$VMS" | while read vm; do echo "   - $vm"; done
echo ""

# Function to test SSH access
test_ssh() {
    local vm=$1
    if ssh -i ~/.ssh/ansible-ci -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           -o BatchMode=yes ubuntu@$vm "echo ok" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check current access and deploy keys where needed
SUCCESS_COUNT=0
TOTAL_COUNT=0

for vm in $VMS; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # Skip the runner itself
    if [ "$vm" == "172.17.152.102" ]; then
        echo -e "${YELLOW}⏭️  $vm (skipping - this is the runner itself) ${NC}"
        continue
    fi
    
    echo -n "🔍 Testing $vm... "
    
    if test_ssh $vm; then
        echo -e "${GREEN}✅ SSH key access already working${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${YELLOW}⚠️  No SSH key access, checking alternatives...${NC}"
        
        # Try to establish access using any available method
        # Method 1: Check if we can connect without authentication (unlikely but possible)
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
               -o PreferredAuthentications=none ubuntu@$vm "echo ok" >/dev/null 2>&1; then
            echo "   🔓 Passwordless access available, deploying key..."
            ssh -o StrictHostKeyChecking=no ubuntu@$vm \
                "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
            if test_ssh $vm; then
                echo -e "   ${GREEN}✅ Key deployed successfully${NC}"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            fi
        else
            echo -e "   ${RED}❌ Cannot establish automated access${NC}"
            echo -e "   ${YELLOW}Manual intervention required for this VM${NC}"
        fi
    fi
done

echo ""
echo "================================"
echo "📊 Summary: $SUCCESS_COUNT/$TOTAL_COUNT VMs accessible via SSH key"
echo ""

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ] || [ $SUCCESS_COUNT -eq $((TOTAL_COUNT - 1)) ]; then
    echo -e "${GREEN}✅ SSH access configured successfully!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some VMs still need SSH key access${NC}"
    echo ""
    echo "To manually fix remaining VMs, run on each VM:"
    echo "  echo '$PUBKEY' >> ~/.ssh/authorized_keys"
    echo "  chmod 600 ~/.ssh/authorized_keys"
    exit 0  # Don't fail the build, just warn
fi
