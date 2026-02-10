# High Availability Control Plane Solution

## Problem with Current Setup
Single control plane (1 master) gets overwhelmed during worker joins:
- Handling certificate signing
- Managing etcd writes
- Scheduling Calico pods
- Processing API requests from 4 workers simultaneously
→ Result: API server crashes repeatedly

## Solution: 3-Node Control Plane

### Benefits
- ✅ Load distributed across 3 masters
- ✅ API server behind load balancer (auto-failover)
- ✅ etcd cluster (3 nodes = fault tolerant)
- ✅ If 1 master crashes, other 2 keep working
- ✅ No more "API connection refused" errors

### Required Infrastructure Changes

**Option A: Use Existing VMs as Masters**
Convert web-01 and web-02 to be control plane nodes:

```yaml
# inventory/k8s/onprem.yml
[k8s_control_plane]
onprem-k8s-master ansible_host=172.17.152.109
onprem-k8s-web-01 ansible_host=172.17.152.103  # Now a master
onprem-k8s-web-02 ansible_host=172.17.152.104  # Now a master

[k8s_workers]
onprem-k8s-worker-01 ansible_host=172.17.152.106
onprem-k8s-worker-02 ansible_host=172.17.152.105

[k8s_loadbalancer]
onprem-k8s-master ansible_host=172.17.152.109  # HAProxy for API
```

**Option B: Provision New VMs**
Keep current setup, add 2 more VMs:
- 172.17.152.110 (master-02)
- 172.17.152.111 (master-03)

### Implementation Complexity
- **Playbook changes**: Medium (need HAProxy for API load balancing, staggered etcd init)
- **Time to implement**: 2-3 hours
- **Risk**: Low (well-documented pattern)

### When to Use This
- You have extra VMs available OR can reassign workers as masters
- You need production-grade reliability
- You're willing to invest setup time now for stability later

### Deployment Time After Setup
- Initial deployment: 20-25 minutes (3 masters init in parallel)
- Worker joins: 10-15 minutes (spread across 3 masters)
- Total: 30-40 minutes with NO failures or recovery needed

## Decision Matrix

| Scenario | Best Option |
|----------|-------------|
| Can fix VM clocks | **Option 1** (fix infrastructure) |
| Need quick proof-of-concept | **Option 2** (1 worker test) |
| Building production system | **Option 3** (HA control plane) |
| Limited VMs available | **Option 2** then scale gradually |
| Have 2+ extra VMs | **Option 3** |

