#!/bin/bash
##########################################################################################
# QUICK K3S TEST ON UBUNTU 25.10
##########################################################################################
# Purpose: Test if K3s can run on Ubuntu 25.10 kernel 6.17.0-12
# Run this on the master node to see if K3s will work before full deployment
##########################################################################################

set -e

MASTER_IP="172.17.152.109"

echo "=========================================="
echo "  Testing K3s on Ubuntu 25.10"
echo "=========================================="
echo "Master: $MASTER_IP"
echo "K3s Version: v1.35.0+k3s3 (latest stable)"
echo "=========================================="
echo ""

# Clean any existing K3s
echo "1. Cleaning any existing K3s installation..."
ssh ubuntu@$MASTER_IP "sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true"
sleep 2

# Install latest K3s with maximum timeouts
echo "2. Installing K3s v1.35.0+k3s3..."
ssh ubuntu@$MASTER_IP "export INSTALL_K3S_VERSION='v1.35.0+k3s3' && \
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb \
  --disable local-storage \
  --kube-apiserver-arg='--default-not-ready-toleration-seconds=60' \
  --kube-apiserver-arg='--default-unreachable-toleration-seconds=60' \
  --kube-apiserver-arg='--request-timeout=300s' \
  --kube-controller-manager-arg='--node-monitor-grace-period=60s'"

echo "3. Waiting 30 seconds for K3s to initialize..."
sleep 30

# Check service status
echo "4. Checking K3s service status..."
ssh ubuntu@$MASTER_IP "sudo systemctl status k3s --no-pager | head -20"

echo ""
echo "5. Checking K3s logs (last 30 lines)..."
ssh ubuntu@$MASTER_IP "sudo journalctl -u k3s -n 30 --no-pager"

echo ""
echo "6. Testing API server connectivity..."
for i in {1..60}; do
  if ssh ubuntu@$MASTER_IP "curl -k https://127.0.0.1:6443/livez 2>&1" | grep -q "ok"; then
    echo "✅ API server is responding!"
    break
  fi
  if ssh ubuntu@$MASTER_IP "curl -k https://127.0.0.1:6443/readyz 2>&1" | grep -q "ok"; then
    echo "✅ API server is ready!"
    break
  fi
  if [ $((i % 10)) -eq 0 ]; then
    echo "Still waiting... (attempt $i/60)"
  fi
  sleep 3
done

echo ""
echo "7. Checking node status..."
ssh ubuntu@$MASTER_IP "sudo kubectl get nodes" || echo "❌ kubectl failed"

echo ""
echo "8. Checking pods..."
ssh ubuntu@$MASTER_IP "sudo kubectl get pods -A" || echo "❌ kubectl get pods failed"

echo ""
echo "=========================================="
echo "  Test Complete"  
echo "=========================================="
echo ""
echo "If you see 'API server is responding' and nodes Ready:"
echo "  ✅ K3s works on Ubuntu 25.10 - proceed with full deployment"
echo ""
echo "If you see crash loops or API failures:"
echo "  ❌ K3s incompatible - need to downgrade OS to Ubuntu 22.04 LTS"
echo ""
echo "=========================================="
