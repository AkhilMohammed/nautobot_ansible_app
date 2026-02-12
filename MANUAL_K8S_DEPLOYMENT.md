# Manual Kubernetes Deployment Guide - 6 VMs

## Your Infrastructure
- Master: `172.17.152.109` (onprem-k8s-master)
- Workers:
  - `172.17.152.103` (onprem-k8s-web-01)
  - `172.17.152.104` (onprem-k8s-web-02)
  - `172.17.152.105` (onprem-k8s-worker-01)
  - `172.17.152.106` (onprem-k8s-worker-02)
  - `172.17.152.108` (onprem-k8s-worker-03)

---

## STEP 1: Clean All Nodes (Run on ALL 6 VMs)

SSH into each VM and run:
```bash
# Reset Kubernetes
sudo kubeadm reset -f

# Clean all Kubernetes files
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube /root/.kube

# Clean CNI
sudo rm -rf /etc/cni/net.d /opt/cni /var/lib/cni

# Restart services
sudo systemctl restart containerd kubelet
```

**Quick command to clean all nodes from your jumpbox:**
```bash
for ip in 172.17.152.109 172.17.152.103 172.17.152.104 172.17.152.105 172.17.152.106 172.17.152.108; do
  ssh ubuntu@$ip "sudo kubeadm reset -f && sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube /root/.kube /etc/cni/net.d /opt/cni /var/lib/cni && sudo systemctl restart containerd kubelet"
done
```

---

## STEP 2: Initialize Master Node

SSH to master (`172.17.152.109`):
```bash
ssh ubuntu@172.17.152.109
```

Initialize cluster:
```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=172.17.152.109 \
  --control-plane-endpoint=172.17.152.109:6443
```

**Expected output:** Should complete in 10-30 seconds with "Your Kubernetes control-plane has initialized successfully!"

Setup kubeconfig:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify API is running:
```bash
kubectl cluster-info
kubectl get nodes
```

**Expected:** Master node in NotReady state (normal - CNI not installed yet)

---

## STEP 3: Install CNI (Flannel) - On Master

**IMPORTANT:** Install CNI immediately (within 2 minutes) to prevent API instability:

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

Wait for Flannel to start:
```bash
# Check Flannel pods (should show Running within 30 seconds)
kubectl get pods -n kube-flannel -w
# Press Ctrl+C after you see Running status

# Verify master node becomes Ready
kubectl get nodes -w
# Press Ctrl+C after master shows Ready
```

**If Flannel crashes with "subnet doesn't contain PodCIDR" error:**
- You used wrong pod-network-cidr in step 2
- Must reset and reinitialize with `--pod-network-cidr=10.244.0.0/16`

---

## STEP 4: Get Join Command - On Master

Generate join command for workers:
```bash
sudo kubeadm token create --print-join-command
```

**Copy the full output** - it will look like:
```
kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

---

## STEP 5: Join Worker Nodes (On Each Worker)

For **EACH** worker node, SSH and run the join command from Step 4:

### Worker 1 (172.17.152.103):
```bash
ssh ubuntu@172.17.152.103
# Paste the join command from Step 4 with sudo:
sudo kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

**Expected output:** "This node has joined the cluster"

### Worker 2 (172.17.152.104):
```bash
ssh ubuntu@172.17.152.104
# Paste the join command
sudo kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

### Worker 3 (172.17.152.105):
```bash
ssh ubuntu@172.17.152.105
# Paste the join command
sudo kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

### Worker 4 (172.17.152.106):
```bash
ssh ubuntu@172.17.152.106
# Paste the join command
sudo kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

### Worker 5 (172.17.152.108):
```bash
ssh ubuntu@172.17.152.108
# Paste the join command
sudo kubeadm join 172.17.152.109:6443 --token XXXXXX.YYYYYYYYYYYY \
  --discovery-token-ca-cert-hash sha256:ZZZZZZZZZZZZZZZZ
```

**If join fails with "already exists" errors:**
```bash
# On the failing worker:
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet/pki
sudo systemctl restart kubelet
sleep 5
# Then retry the join command
```

---

## STEP 6: Verify Cluster - On Master

Return to master node:
```bash
ssh ubuntu@172.17.152.109
```

Check all nodes:
```bash
kubectl get nodes -o wide
```

**Expected output:** All 6 nodes in Ready state
```
NAME                STATUS   ROLES           AGE   VERSION
onprem-k8s-master   Ready    control-plane   10m   v1.28.15
onprem-k8s-web-01   Ready    <none>          5m    v1.28.15
onprem-k8s-web-02   Ready    <none>          4m    v1.28.15
onprem-k8s-worker-01 Ready   <none>          3m    v1.28.15
onprem-k8s-worker-02 Ready   <none>          2m    v1.28.15
onprem-k8s-worker-03 Ready   <none>          1m    v1.28.15
```

Check system pods:
```bash
kubectl get pods -n kube-system
```

**All pods should be Running:**
- coredns (2 pods)
- etcd
- kube-apiserver
- kube-controller-manager
- kube-proxy (6 pods - one per node)
- kube-scheduler

Check Flannel:
```bash
kubectl get pods -n kube-flannel
```

**Expected:** 6 flannel pods (one per node) - all Running

---

## STEP 7: Deploy Nautobot

On master node:

### Install Helm (if not installed):
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Create namespace:
```bash
kubectl create namespace nautobot
```

### Add Nautobot Helm repo:
```bash
helm repo add nautobot https://nautobot.github.io/helm-charts/
helm repo update
```

### Deploy Nautobot:
```bash
helm install nautobot nautobot/nautobot -n nautobot \
  --set postgresql.enabled=true \
  --set postgresql.auth.password=nautobot123 \
  --set redis.enabled=true \
  --set nautobot.superuser.enabled=true \
  --set nautobot.superuser.username=admin \
  --set nautobot.superuser.password=admin \
  --set nautobot.superuser.email=admin@example.com
```

### Wait for pods to start:
```bash
kubectl get pods -n nautobot -w
# Press Ctrl+C once all pods show Running (may take 2-5 minutes)
```

### Get Nautobot URL:
```bash
kubectl get svc -n nautobot
# Look for service with type NodePort or LoadBalancer
# Access via http://<any-node-ip>:<nodeport>
```

---

## TROUBLESHOOTING

### Issue: API server keeps crashing (connection refused)
**Cause:** Ubuntu 25.10 kernel incompatibility
**Solutions:**
1. Wait 2-3 minutes - it often recovers automatically
2. Restart kubelet: `sudo systemctl restart kubelet`
3. If persistent: Downgrade to Ubuntu 22.04 LTS

### Issue: Flannel pods CrashLoopBackOff
**Cause:** Wrong pod-network-cidr
**Solution:** 
```bash
# On master:
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes
# Re-initialize with correct CIDR (Step 2)
```

### Issue: Node stays NotReady
**Checks:**
```bash
# On that node:
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50

# Check node conditions:
kubectl describe node <node-name>
```

### Issue: Worker join fails
**Solution:**
```bash
# On worker:
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet/pki
sudo systemctl restart kubelet
sleep 5
# Generate new token on master if old one expired:
sudo kubeadm token create --print-join-command
# Use new join command
```

### Issue: CoreDNS pending/not running
**Cause:** Flannel not working or node NotReady
**Check:**
```bash
kubectl get pods -n kube-flannel
kubectl logs -n kube-flannel <flannel-pod-name>
```

---

## Quick Verification Commands

```bash
# All nodes ready
kubectl get nodes

# All system pods running
kubectl get pods -A

# Check specific namespace
kubectl get pods -n nautobot

# Get logs for failing pod
kubectl logs -n <namespace> <pod-name>

# Describe pod for more details
kubectl describe pod -n <namespace> <pod-name>

# Check cluster health
kubectl get cs

# API server status
systemctl status kube-apiserver
```

---

## Time Estimates

- Step 1 (Clean): 2 minutes
- Step 2 (Init master): 1-2 minutes
- Step 3 (Install CNI): 1 minute
- Step 4 (Get join cmd): 10 seconds
- Step 5 (Join workers): 5 x 1 minute = 5 minutes
- Step 6 (Verify): 2 minutes
- Step 7 (Nautobot): 5-10 minutes

**Total: 15-25 minutes** for full deployment

---

## IMPORTANT NOTES

1. **Install Flannel within 2 minutes** of initializing master - this prevents API instability
2. **Use 10.244.0.0/16** for pod-network-cidr (required by Flannel)
3. If API crashes, **wait 2-3 minutes** for automatic recovery before troubleshooting
4. Token expires in 24 hours - generate new one if needed
5. **Ubuntu 25.10 is unstable** with K8s 1.28.15 - expect occasional crashes

---

## Success Criteria

✅ All 6 nodes show Ready status
✅ All coredns pods Running
✅ All flannel pods Running
✅ No CrashLoopBackOff pods
✅ Can create and access pods
✅ Nautobot deployed and accessible

Once you see all these, your cluster is production-ready!
