# 🚀 PRODUCTION K8S DEPLOYMENT - QUICK START

## ✅ What You Have

**Production-ready Kubernetes deployment with:**
- ✅ **Automated kubectl/kubeadm installation** (no manual setup needed)
- ✅ **Helm 3** for package management
- ✅ **Master node as Load Balancer** (Nginx Ingress on port 30080/30443)
- ✅ **2 Web pods** (labeled nodes: workload=web)
- ✅ **2 Worker pods** (labeled nodes: workload=worker) with **auto-scaling**
- ✅ **1 Scheduler pod**
- ✅ **External PostgreSQL** (VM #6)
- ✅ **External Redis** (VM #7)
- ✅ **High Availability, Health Checks, Rolling Updates**
- ✅ **GitHub Actions CI/CD integration**

## 📍 Your 8 VMs

| VM | Role | IP (REPLACE!) | What Runs |
|----|------|---------------|-----------|
| 1 | K8s Master + LB | 192.168.1.10 | Control plane + Nginx Ingress |
| 2 | K8s Web Worker | 192.168.1.11 | Nautobot web pods |
| 3 | K8s Web Worker | 192.168.1.12 | Nautobot web pods |
| 4 | K8s Celery Worker | 192.168.1.13 | Celery worker pods |
| 5 | K8s Celery Worker | 192.168.1.14 | Celery worker pods |
| 6 | PostgreSQL | 192.168.1.16 | Database |
| 7 | Redis | 192.168.1.17 | Cache/Broker |
| 8 | GitHub Runner | 192.168.1.18 | CI/CD automation |

## 🎯 Deploy in 3 Steps

### Step 1: Configure IPs and Passwords

**Edit inventory file:**
```bash
vim inventory/k8s/onprem.yml
```
Replace:
- All `192.168.1.XX` with your actual VM IPs
- `your_username` with your SSH username (e.g., ubuntu, root)

**Configure passwords:**
```bash
# Copy example
cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml

# Edit with your passwords
vim group_vars/onprem/vault.yml

# Add these passwords:
# - vault_ssh_password: Your VM SSH password
# - vault_database_password: PostgreSQL password
# - vault_redis_password: Redis password
# - vault_nautobot_secret_key: (generate below)
# - vault_nautobot_superuser_password: Nautobot admin password

# Generate secret key (add to vault file)
python3 -c "import secrets; print(secrets.token_urlsafe(50))"

# Encrypt vault
ansible-vault encrypt group_vars/onprem/vault.yml
# Enter vault password when prompted

# Save vault password (for automation)
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
```

### Step 2: Deploy Everything (ONE COMMAND!)

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file .vault_pass
```

**This will automatically:**
1. ✅ Install containerd on all nodes
2. ✅ Install kubectl, kubeadm, kubelet
3. ✅ Initialize Kubernetes cluster
4. ✅ Join all worker nodes
5. ✅ Label web and worker nodes
6. ✅ Install Helm 3
7. ✅ Install Nginx Ingress (Load Balancer)
8. ✅ Deploy PostgreSQL and Redis
9. ✅ Deploy Nautobot with Helm

**Time:** ~25-30 minutes

### Step 3: Access Nautobot

```
URL: http://192.168.1.10:30080
     (or your master node IP)

Username: admin
Password: (from vault_nautobot_superuser_password)
```

## 🔍 Verify Deployment

SSH to master node:
```bash
ssh your_username@192.168.1.10

# Check nodes
kubectl get nodes -o wide

# Check pods
kubectl get pods -n nautobot -o wide

# You should see:
# nautobot-web-xxxxx        1/1  Running  (on web workers)
# nautobot-worker-xxxxx     1/1  Running  (on celery workers)
# nautobot-scheduler-xxxxx  1/1  Running

# Check services
kubectl get svc -n nautobot

# Check ingress
kubectl get ingress -n nautobot

# View Helm deployment
helm list -n nautobot
```

## 📊 Production Features

### Auto-Scaling (Already Configured!)
```bash
# Watch auto-scaling in action
kubectl get hpa -n nautobot -w

# When CPU > 70% or Memory > 80%:
# Workers auto-scale from 2 → 6 pods
```

### Scaling (Manual)
```bash
# Scale web pods
kubectl scale -n nautobot deployment/nautobot-web --replicas=4

# Scale workers
kubectl scale -n nautobot deployment/nautobot-worker --replicas=8
```

### View Logs
```bash
# Web logs
kubectl logs -n nautobot -l app.kubernetes.io/component=web -f

# Worker logs
kubectl logs -n nautobot -l app.kubernetes.io/component=worker -f
```

### Update Nautobot
```bash
helm upgrade nautobot ~/nautobot-helm \
  --namespace nautobot \
  --set image.tag=3.0.7-py3.11 \
  --wait
```

### Rollback
```bash
helm rollback nautobot -n nautobot
```

## 🎛️ What Makes This Production-Ready?

✅ **High Availability**
- 2 web replicas on different nodes (anti-affinity)
- 2 worker replicas on different nodes
- Automatic failover

✅ **Health Checks**
- Liveness probes: /health/ every 10s
- Readiness probes: /health/ every 5s
- Auto-restart on failure

✅ **Resource Management**
- CPU/Memory requests and limits set
- Prevents resource starvation
- Optimized for 8 VMs

✅ **Auto-Scaling**
- HPA enabled for workers
- Scales based on CPU/Memory
- Min: 2, Max: 6 replicas

✅ **Rolling Updates**
- Zero-downtime deployments
- Gradual pod replacement
- Automatic rollback on failure

✅ **Persistent Storage**
- 10GB for media files
- 2GB for static files
- 5GB for git repos

✅ **Security**
- Non-root containers
- Secrets for credentials
- SecurityContext enabled
- Network isolation

✅ **Load Balancing**
- Nginx Ingress on master
- Distributes traffic across web pods
- SSL/TLS ready

✅ **Monitoring Ready**
- Metrics enabled
- Prometheus integration ready
- Health endpoints exposed

## 🤖 GitHub Actions (Optional)

Already configured! To use:

1. **Setup GitHub Runner:**
```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/setup_github_runner.yml \
  --vault-password-file .vault_pass
```

2. **Configure GitHub:**
- Go to repo Settings → Actions → Runners
- Get registration token
- SSH to runner VM and register

3. **Trigger deployment:**
```bash
git push origin feat/onprem-deployment
```

Or manually in GitHub Actions UI:
- Select workflow: "Deploy Nautobot On-Premises"
- Choose: `k8s_production`
- Run workflow

## 📚 Files You Need to Edit

| File | What to Change | Why |
|------|----------------|-----|
| `inventory/k8s/onprem.yml` | Replace all IPs and usernames | Match your VMs |
| `group_vars/onprem/vault.yml` | Add all passwords | Security credentials |
| `group_vars/onprem/nautobot.yml` | Update DB/Redis IPs | Point to your VMs |

**That's it!** Everything else is automated.

## 🆘 Need Help?

**Pods not starting?**
```bash
kubectl describe pod -n nautobot <pod-name>
kubectl logs -n nautobot <pod-name>
```

**Can't access UI?**
```bash
# Check ingress
kubectl get ingress -n nautobot

# Check service
kubectl get svc -n nautobot

# Port forward (temporary access)
kubectl port-forward -n nautobot svc/nautobot 8000:8000
# Then access: http://localhost:8000
```

**Database issues?**
```bash
# Test from pod
kubectl exec -it -n nautobot deploy/nautobot-web -- bash
apt-get update && apt-get install -y postgresql-client
psql -h 192.168.1.16 -U nautobot -d nautobot
```

## 📖 Full Documentation

- **Production Guide:** [PRODUCTION_K8S_GUIDE.md](PRODUCTION_K8S_GUIDE.md)
- **VM Deployment:** [ONPREM_SETUP_GUIDE.md](ONPREM_SETUP_GUIDE.md)
- **Basic K8s Guide:** [ONPREM_K8S_GUIDE.md](ONPREM_K8S_GUIDE.md)

## ✨ Summary

You now have a **production-ready, enterprise-grade** Nautobot deployment with:
- **Fully automated** setup (kubectl, K8s cluster, Helm, everything!)
- **High availability** with multiple replicas
- **Auto-scaling** based on load
- **Zero-downtime** updates
- **Health monitoring** and auto-recovery
- **Load balancing** via Nginx Ingress
- **CI/CD integration** with GitHub Actions

**Just update IPs/passwords and run ONE command!** 🚀

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file .vault_pass
```

**That's it!** ✅
