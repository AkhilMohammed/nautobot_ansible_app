# 🚀 DEPLOYMENT GUIDE - Kubernetes Cluster Setup

**Last Updated:** February 11, 2026  
**Current Status:** Cluster not deployed yet  
**Next Step:** Run automated script below

---

## 🎯 QUICK START (RECOMMENDED)

```bash
cd /home/ubuntu/nautobot_ansible_app
./scripts/deploy_automated.sh
```

**Answer the prompts:**
- Clean previous deployments? → **y** (Yes)
- Pre-pull images? → **y** (YES! Solves slow download)

**That's it!** The script handles everything automatically.

---

## 📋 WHAT YOU GET

✅ **Automated Script:** Handles all deployment steps  
✅ **Pre-pull Images:** Solves slow registry downloads (Run #94 issue)  
✅ **Error Handling:** Automatic cleanup and retry logic  
✅ **Progress Monitoring:** Real-time status updates  
✅ **Health Verification:** Post-deployment checks  

**Time:** 20-35 minutes for full 6-node cluster

---

## 💡 TWO DEPLOYMENT OPTIONS

### Option 1: Automated Script ⚡ (RECOMMENDED)
```bash
./scripts/deploy_automated.sh
```
- Solves slow image pull issue
- Monitors progress in real-time
- Verifies deployment success
- Best for: Quick reliable deployment

### Option 2: GitHub Actions 🤖
Visit: https://github.com/AkhilMohammed/nautobot_ansible_app/actions
- Uses CI/CD pipeline
- Logs on GitHub
- Best for: Team workflows

---

## 🔧 TROUBLESHOOTING

### Script fails with SSH error
```bash
ssh ubuntu@172.17.152.109 "echo test"
# If fails, copy SSH key:
cp group_vars/dev/ansible-ci ~/.ssh/ansible-ci
chmod 600 ~/.ssh/ansible-ci
```

### Deployment hangs at "kubeadm init"
**You said NO to pre-pull!** This is why it's slow.
- Stop: `Ctrl+C`
- Re-run: `./scripts/deploy_automated.sh`
- Say YES to image pre-pull this time

### Check deployment logs
```bash
tail -f /tmp/deployment_run95.log
```

---

## ✅ AFTER SUCCESSFUL DEPLOYMENT

### Check cluster health
```bash
./scripts/check_cluster.sh
```

### Verify manually
```bash
ssh ubuntu@172.17.152.109 "kubectl get nodes -o wide"
ssh ubuntu@172.17.152.109 "kubectl get pods -A"
```

---

## 📚 MORE HELP

- **All kubectl commands:** `cat KUBECTL_COMMANDS.md`
- **Cluster checks:** `./scripts/check_cluster.sh`
- **This guide:** `cat DEPLOYMENT_GUIDE.md`

---

## 🎬 START NOW

```bash
cd /home/ubuntu/nautobot_ansible_app && ./scripts/deploy_automated.sh
```
