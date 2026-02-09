#!/bin/bash
# Quick Setup Script for On-Premises Deployment
# This script will guide you through the configuration

set -e

echo "========================================="
echo "Nautobot On-Premises Setup Wizard"
echo "========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "ansible.cfg" ]; then
    echo "❌ Error: Please run this script from the nautobot_ansible_app directory"
    exit 1
fi

echo "Step 1: Configure VM Inventory"
echo "-------------------------------"
echo "Edit the file: inventory/vm/onprem.yml"
echo ""
echo "Replace these values:"
echo "  - All IP addresses (192.168.1.XX) with your actual VM IPs"
echo "  - 'your_username' with your SSH username"
echo ""
read -p "Press Enter when you've edited the inventory file..."

echo ""
echo "Step 2: Setup Vault with Passwords"
echo "-----------------------------------"
if [ ! -f "group_vars/onprem/vault.yml" ]; then
    echo "Creating vault file from example..."
    cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml
    echo "✅ Created group_vars/onprem/vault.yml"
else
    echo "⚠️  Vault file already exists"
fi

echo ""
echo "Edit the file: group_vars/onprem/vault.yml"
echo "Add your passwords and secrets"
echo ""
read -p "Press Enter when you've edited the vault file..."

echo ""
echo "Step 3: Generate Nautobot Secret Key"
echo "-------------------------------------"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "GENERATE_YOUR_OWN_SECRET_KEY")
echo "Generated secret key: $SECRET_KEY"
echo "Add this to vault_nautobot_secret_key in group_vars/onprem/vault.yml"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "Step 4: Encrypt Vault File"
echo "--------------------------"
read -p "Enter a vault password (you'll need this for deployments): " -s VAULT_PASS
echo ""
echo "$VAULT_PASS" > .vault_pass
chmod 600 .vault_pass
ansible-vault encrypt group_vars/onprem/vault.yml --vault-password-file .vault_pass
echo "✅ Vault file encrypted"

echo ""
echo "Step 5: Update Database and Redis IPs"
echo "--------------------------------------"
echo "Edit the file: group_vars/onprem/nautobot.yml"
echo ""
echo "Update these lines:"
echo "  - Line ~28: PostgreSQL VM IP"
echo "  - Line ~35: Redis VM IP"
echo "  - Lines ~45-47: Web node IPs in allowed_hosts"
echo ""
read -p "Press Enter when you've edited nautobot.yml..."

echo ""
echo "Step 6: Test Connectivity"
echo "-------------------------"
echo "Testing connection to all VMs..."
if ansible -i inventory/vm/onprem.yml all -m ping --vault-password-file .vault_pass; then
    echo "✅ All VMs are reachable!"
else
    echo "❌ Some VMs are not reachable. Please check:"
    echo "   - IP addresses in inventory/vm/onprem.yml"
    echo "   - SSH credentials"
    echo "   - Network connectivity"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Deploy infrastructure:"
echo "   ansible-playbook -i inventory/vm/onprem.yml playbooks/deploy_onprem_all.yml --tags 'postgres,redis' --vault-password-file .vault_pass"
echo ""
echo "2. Deploy Nautobot:"
echo "   ansible-playbook -i inventory/vm/onprem.yml playbooks/deploy_onprem_all.yml --tags 'nautobot' --vault-password-file .vault_pass"
echo ""
echo "3. Setup GitLab Runner:"
echo "   ansible-playbook -i inventory/vm/onprem.yml playbooks/setup_gitlab_runner.yml --vault-password-file .vault_pass"
echo ""
echo "For detailed instructions, see: ONPREM_SETUP_GUIDE.md"
