# Simple Test Deployment - Proof of Concept

## Goal
Deploy and validate Kubernetes + Nautobot with MINIMAL infrastructure to prove the automation works.

## Test Configuration

### Phase 1: Master + 1 Worker Only
**Infrastructure**:
- 1 Master: onprem-k8s-master (172.17.152.109)
- 1 Worker: onprem-k8s-worker-01 (172.17.152.106)
- 1 PostgreSQL: onprem-k8s-postgres (172.17.152.107)
- 1 Redis: onprem-k8s-redis (172.17.152.108)

**What to do**:
1. Edit `inventory/k8s/onprem.yml`:
```yaml
[k8s_workers]
onprem-k8s-worker-01 ansible_host=172.17.152.106

# Comment out the other workers temporarily:
# onprem-k8s-worker-02 ansible_host=172.17.152.105
# onprem-k8s-web-01 ansible_host=172.17.152.103
# onprem-k8s-web-02 ansible_host=172.17.152.104
```

2. Commit and push:
```bash
git add inventory/k8s/onprem.yml
git commit -m "TEST: Deploy with 1 worker only"
git push origin feat/onprem-deployment
```

3. Wait for deployment (~15-20 minutes)

### Phase 2: Add Workers Gradually
Once Phase 1 succeeds:

**Add 1 worker at a time**:
```bash
# Uncomment worker-02, commit, push, wait
# Then uncomment web-01, commit, push, wait
# Then uncomment web-02, commit, push, wait
```

## Why This Works
- ✅ Less load on single master
- ✅ Easier to debug if one fails
- ✅ Proves automation before scaling
- ✅ Each success builds confidence

## Expected Timeline
- Phase 1 (Master + 1 worker): 15-20 minutes
- Each additional worker: 5-10 minutes
- Total: 35-50 minutes (vs 45min trying to do all at once and failing)

## Success Criteria
```bash
# After Phase 1, verify:
kubectl get nodes
# Should show: master (Ready) + worker-01 (Ready)

kubectl get pods -n nautobot
# Should show: nautobot-app, nautobot-worker, nautobot-scheduler (Running)
```
