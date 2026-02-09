#!/bin/bash
# ONE-TIME SETUP: SSH Key Distribution
# This script should be run ONCE to distribute the CI SSH key to all VMs
# Can be run manually or added as a GitHub Actions workflow_dispatch

set -e

echo "============================================="
echo "  ONE-TIME SETUP: SSH Key Distribution"  
echo "============================================="
echo ""
echo "This script will distribute the CI SSH public key"
echo "to all target VMs for automated deployments."
echo ""

# Get the public key
PUBKEY_FILE="$HOME/.ssh/ansible-ci.pub"

if [ ! -f "$PUBKEY_FILE" ]; then
    echo "❌ Public key not found at $PUBKEY_FILE"
    echo ""
    echo "Please ensure the CI SSH key is generated first:"
    echo "  ssh-keygen -t ed25519 -f ~/.ssh/ansible-ci -N ''"
    exit 1
fi

PUBKEY=$(cat "$PUBKEY_FILE")

echo "📋 Public Key:"
echo "   $PUBKEY"
echo ""

# List of target VMs (excluding the runner itself at .102)
VMS="172.17.152.103 172.17.152.104 172.17.152.105 172.17.152.106 172.17.152.107 172.17.152.108 172.17.152.109"

echo "🎯 Target VMs:"
for vm in $VMS; do
    echo "   - $vm"
done  
echo ""

echo "============================================="
echo "  DEPLOYMENT OPTIONS"
echo "============================================="
echo ""
echo "Choose your deployment method:"
echo ""
echo "1. AUTOMATED: Run SSH commands (requires SSH access)"
echo "2. MANUAL: Get commands to run on each VM"
echo ""
read -p "Select option (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Attempting automated deployment..."
        echo ""
        
        for vm in $VMS; do
            echo -n "Deploying to $vm... "
            
            # Try to deploy using ssh (will prompt for password if needed)
            if ssh -o StrictHostKeyChecking=no ubuntu@$vm \
                "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null; then
                echo "✅"
            else
                echo "❌ (may need password - try manual method)"
            fi
        done
        ;;
        
    2)
        echo ""
        echo "============================================="
        echo "  MANUAL DEPLOYMENT COMMANDS"
        echo "============================================="
        echo ""
        echo "Run these commands on EACH target VM:"
        echo ""
        echo "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        echo "echo '$PUBKEY' >> ~/.ssh/authorized_keys"
        echo "chmod 600 ~/.ssh/authorized_keys"
        echo ""
        echo "Or copy-paste this one-liner on each VM:"
        echo ""
        echo "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        echo ""
        ;;
        
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "============================================="
echo "  VERIFICATION"
echo "============================================="
echo ""
echo "Testing SSH key access to all VMs..."
echo ""

for vm in $VMS; do
    echo -n "Testing $vm... "
    if ssh -i ~/.ssh/ansible-ci -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           -o BatchMode=yes ubuntu@$vm "echo ok" >/dev/null 2>&1; then
        echo "✅ SSH key works"
    else
        echo "❌ SSH key not working"
    fi
done

echo ""
echo "============================================="
echo "  SETUP COMPLETE"
echo "============================================="
echo ""
echo "The CI/CD pipeline will now be able to deploy"
echo "to VMs where SSH key access is working."
echo ""
