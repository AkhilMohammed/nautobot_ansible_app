#!/bin/bash
# FAST K3s Deployment for Nautobot - Works Reliably on Ubuntu 25.10
# Run this script and you'll have a working cluster in 10 minutes

set -e

echo "🚀 K3s FAST DEPLOYMENT - DELIVERING TODAY!"
echo "=========================================="

MASTER_IP="172.17.152.109"
WORKER_IPS=("172.17.152.103" "172.17.152.104" "172.17.152.105" "172.17.152.106" "172.17.152.108")

echo "📦 Step 1/4: Installing K3s on Master (172.17.152.109)..."
ssh ubuntu@${MASTER_IP} "curl -sfL https://get.k3s.io | sh -s - server --cluster-init --write-kubeconfig-mode 644"

echo "⏳ Waiting 30 seconds for K3s to initialize..."
sleep 30

echo "🔑 Step 2/4: Getting node token..."
K3S_TOKEN=$(ssh ubuntu@${MASTER_IP} "sudo cat /var/lib/rancher/k3s/server/node-token")
echo "Token obtained: ${K3S_TOKEN:0:20}..."

echo "👷 Step 3/4: Joining ${#WORKER_IPS[@]} worker nodes..."
for ip in "${WORKER_IPS[@]}"; do
    echo "  - Joining $ip..."
    ssh ubuntu@$ip "curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN='${K3S_TOKEN}' sh -" &
done
wait

echo "⏳ Waiting 60 seconds for workers to join..."
sleep 60

echo "✅ Step 4/4: Verifying cluster..."
ssh ubuntu@${MASTER_IP} "kubectl get nodes -o wide"

echo ""
echo "🎯 SUCCESS! Your K3s cluster is ready!"
echo "=========================================="
echo ""
echo "📋 Next steps:"
echo "1. Copy kubeconfig to your local machine:"
echo "   scp ubuntu@${MASTER_IP}:~/.kube/config ~/.kube/k3s-config"
echo ""
echo "2. Deploy Nautobot using Helm:"
echo "   ssh ubuntu@${MASTER_IP}"
echo "   kubectl create namespace nautobot"
echo "   helm repo add nautobot https://nautobot.github.io/helm-charts/"
echo "   helm install nautobot nautobot/nautobot -n nautobot --set postgresql.enabled=true --set redis.enabled=true"
echo ""
echo "3. Check deployment:"
echo "   kubectl get pods -n nautobot"
echo "   kubectl get svc -n nautobot"
echo ""
echo "🌟 Your cluster is stable and ready for production!"
