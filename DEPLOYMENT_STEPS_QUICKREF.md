# Kubernetes Deployment - Quick Reference Card

## 🚀 ONE-PAGE DEPLOYMENT GUIDE

### Infrastructure
```
Master:  172.17.152.109
Workers: 172.17.152.103, .104, .105, .106, .108
```

---

## Step 1: Clean (2 min)
```bash
for ip in 172.17.152.109 172.17.152.103 172.17.152.104 172.17.152.105 172.17.152.106 172.17.152.108; do
  ssh ubuntu@$ip "sudo kubeadm reset -f && sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube /root/.kube /etc/cni/net.d /opt/cni /var/lib/cni && sudo systemctl restart containerd kubelet"
done
```

## Step 2: Init Master (2 min)
```bash
ssh ubuntu@172.17.152.109

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=172.17.152.109 \
  --control-plane-endpoint=172.17.152.109:6443

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Step 3: Install Flannel (1 min)
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl get pods -n kube-flannel -w  # Wait for Running
```

## Step 4: Get Join Command (10 sec)
```bash
sudo kubeadm token create --print-join-command
# COPY THE OUTPUT!
```

## Step 5: Join Workers (5 min)
```bash
# On EACH worker (use command from Step 4):
ssh ubuntu@172.17.152.103
sudo kubeadm join 172.17.152.109:6443 --token XXX --discovery-token-ca-cert-hash sha256:YYY

ssh ubuntu@172.17.152.104
sudo kubeadm join 172.17.152.109:6443 --token XXX --discovery-token-ca-cert-hash sha256:YYY

ssh ubuntu@172.17.152.105
sudo kubeadm join 172.17.152.109:6443 --token XXX --discovery-token-ca-cert-hash sha256:YYY

ssh ubuntu@172.17.152.106
sudo kubeadm join 172.17.152.109:6443 --token XXX --discovery-token-ca-cert-hash sha256:YYY

ssh ubuntu@172.17.152.108
sudo kubeadm join 172.17.152.109:6443 --token XXX --discovery-token-ca-cert-hash sha256:YYY
```

## Step 6: Verify (2 min)
```bash
kubectl get nodes -o wide          # All 6 nodes Ready
kubectl get pods -n kube-system    # All Running
kubectl get pods -n kube-flannel   # All Running
```

## Step 7: Deploy Nautobot (10 min)
```bash
kubectl create namespace nautobot

helm repo add nautobot https://nautobot.github.io/helm-charts/
helm repo update

helm install nautobot nautobot/nautobot -n nautobot \
  --set postgresql.enabled=true \
  --set postgresql.auth.password=nautobot123 \
  --set redis.enabled=true \
  --set nautobot.superuser.enabled=true \
  --set nautobot.superuser.username=admin \
  --set nautobot.superuser.password=admin

kubectl get pods -n nautobot -w   # Wait for Running
kubectl get svc -n nautobot       # Get access URL
```

---

## 🔥 TROUBLESHOOTING

### API Crashes (Connection Refused)
```bash
# Wait 2-3 minutes OR:
ssh ubuntu@172.17.152.109 "sudo systemctl restart kubelet"
```

### Worker Join Fails
```bash
# On failing worker:
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet/pki
sudo systemctl restart kubelet && sleep 5
# Retry join command
```

### Flannel CrashLoopBackOff
```bash
# Wrong pod CIDR - must reinit with 10.244.0.0/16
kubectl logs -n kube-flannel <pod-name>  # Check error
```

### Node NotReady
```bash
kubectl describe node <node-name>
ssh ubuntu@<node-ip> "sudo systemctl status kubelet"
ssh ubuntu@<node-ip> "sudo systemctl restart kubelet"
```

---

## 📊 VERIFICATION COMMANDS

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Check specific pod
kubectl logs -n <namespace> <pod-name>
kubectl describe pod -n <namespace> <pod-name>

# Resources
kubectl top nodes
kubectl get deployments -A
kubectl get svc -A

# Nautobot
kubectl get all -n nautobot
kubectl logs -n nautobot deployment/nautobot
```

---

## ⏱️ TOTAL TIME: 20-30 minutes

---

## ✅ SUCCESS CRITERIA

- [ ] 6 nodes show Ready status
- [ ] All coredns pods Running
- [ ] All flannel pods Running  
- [ ] No CrashLoopBackOff
- [ ] Nautobot pods Running
- [ ] Can access Nautobot UI

---

## 📞 NEED HELP?

See detailed guide: `MANUAL_K8S_DEPLOYMENT.md`
Run helper script: `./scripts/manual_deploy_k8s.sh`
