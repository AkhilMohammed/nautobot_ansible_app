#!/bin/bash

# ==============================================================================
# GitHub Actions Self-Hosted Runner Setup Script
# For machine: 172.17.152.102
# ==============================================================================

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   GitHub Actions Self-Hosted Runner Setup                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as correct user (not root)
if [ "$EUID" -eq 0 ]; then 
   echo "❌ Don't run as root. Run as ubuntu user:"
   echo "   ssh ubuntu@172.17.152.102"
   exit 1
fi

echo "📋 Step 1: Installing Prerequisites..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update and install dependencies
sudo apt-get update -qq
sudo apt-get install -y curl wget git jq

echo "✅ Prerequisites installed"
echo ""

echo "📋 Step 2: Creating Runner Directory..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create runner directory
mkdir -p ~/actions-runner
cd ~/actions-runner

echo "✅ Directory created: ~/actions-runner"
echo ""

echo "📋 Step 3: Downloading GitHub Actions Runner..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Download the latest runner package
RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

echo "✅ Runner downloaded and extracted"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  ACTION REQUIRED: Configure the Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Go to: https://github.com/AkhilMohammed/nautobot_ansible_app/settings/actions/runners/new"
echo ""
echo "2. Copy the TOKEN from that page (starts with 'A...')"
echo ""
echo "3. Run this command with YOUR token:"
echo ""
echo "   ./config.sh --url https://github.com/AkhilMohammed/nautobot_ansible_app \\"
echo "     --token YOUR_TOKEN_HERE \\"
echo "     --name runner-102 \\"
echo "     --work _work \\"
echo "     --labels self-hosted,Linux,X64,runner-102"
echo ""
echo "4. Press Enter for all other questions (accept defaults)"
echo ""
echo "5. Start the runner:"
echo "   ./run.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "OR for automatic startup (run as a service):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "After config.sh completes:"
echo "   sudo ./svc.sh install"
echo "   sudo ./svc.sh start"
echo "   sudo ./svc.sh status"
echo ""
echo "This will run the runner automatically on boot."
echo ""

echo "✅ Setup script complete! Follow the steps above to configure."
