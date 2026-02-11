# Kubernetes kubectl Commands Quick Reference

## Prerequisites
All kubectl commands must be run either:
1. **From master node:** `ssh ubuntu@172.17.152.109`
2. **Via SSH wrapper:** `ssh ubuntu@172.17.152.109 "kubectl <command>"`
3. **Use the script:** `./scripts/check_cluster.sh`

---

## 🚀 Quick Check Commands

### Check Cluster Status
```bash
# From your machine
ssh ubuntu@172.17.152.109 "kubectl cluster-info"

# Or SSH to master first
ssh ubuntu@172.17.152.109
kubectl cluster-info
```

### Check All Nodes
```bash
kubectl get nodes
kubectl get nodes -o wide  # Shows more details (IPs, OS, etc)
```

### Check All Pods
```bash
kubectl get pods -A                    # All namespaces
kubectl get pods -A -o wide            # With node placement and IPs
kubectl get pods -n nautobot           # Only Nautobot namespace
kubectl get pods -n kube-system        # Only kube-system namespace
```

### Check Services
```bash
kubectl get svc -A                     # All services
kubectl get svc -n nautobot            # Nautobot services only
```

### Check Deployments
```bash
kubectl get deployments -A             # All deployments
kubectl get deployments -n nautobot    # Nautobot deployments only
```

---

## 🔍 Detailed Investigation Commands

### Describe Resources (Full Details)
```bash
kubectl describe node <node-name>
kubectl describe pod <pod-name> -n <namespace>
kubectl describe svc <service-name> -n <namespace>
kubectl describe deployment <deployment-name> -n <namespace>
```

### View Pod Logs
```bash
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=50           # Last 50 lines
kubectl logs <pod-name> -n <namespace> --follow            # Live tail
kubectl logs <pod-name> -n <namespace> --previous          # Previous container logs
```

### Check Events (Troubleshooting)
```bash
kubectl get events -A                                      # All events
kubectl get events -A --sort-by='.lastTimestamp'           # Sorted by time
kubectl get events -n nautobot                             # Nautobot events
```

### Check Resource Usage
```bash
kubectl top nodes                      # Node CPU/Memory usage
kubectl top pods -A                    # Pod resource usage
kubectl top pods -n nautobot           # Nautobot pod usage
```

---

## 🎯 Nautobot-Specific Commands

### Check Nautobot Deployment Status
```bash
kubectl get all -n nautobot
kubectl get pods -n nautobot -o wide
kubectl get svc -n nautobot
kubectl get ingress -n nautobot
```

### Check Nautobot Logs
```bash
# Web pods
kubectl logs -n nautobot -l app.kubernetes.io/component=web --tail=100

# Worker pods
kubectl logs -n nautobot -l app.kubernetes.io/component=worker --tail=100

# Scheduler pods
kubectl logs -n nautobot -l app.kubernetes.io/component=scheduler --tail=100

# All Nautobot pods
kubectl logs -n nautobot -l app.kubernetes.io/name=nautobot --tail=100
```

### Connect to Nautobot Pod (Shell Access)
```bash
# Get pod name first
kubectl get pods -n nautobot

# Connect to pod
kubectl exec -it <nautobot-pod-name> -n nautobot -- /bin/bash

# Run Nautobot management commands
kubectl exec -it <nautobot-pod-name> -n nautobot -- nautobot-server shell
```

---

## 🛠️ Debugging Commands

### Find Problematic Pods
```bash
# Not running
kubectl get pods -A | grep -v Running

# With errors
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Restart count
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount
```

### Check Pod Readiness
```bash
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase
```

### View Full Pod Status
```bash
kubectl get pods -n nautobot -o json | jq '.items[] | {name:.metadata.name, status:.status.phase, conditions:.status.conditions}'
```

---

## 📊 Monitoring Commands

### Watch Resources (Auto-Refresh)
```bash
kubectl get pods -A --watch
kubectl get nodes --watch
watch -n 2 'kubectl get pods -A'       # Refresh every 2 seconds
```

### Check Control Plane Components
```bash
kubectl get pods -n kube-system
kubectl get componentstatuses          # Deprecated but sometimes useful
kubectl get --raw /healthz             # API server health
kubectl get --raw /livez               # Liveness check
kubectl get --raw /readyz              # Readiness check
```

### Check Network Plugins (Calico)
```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50
```

---

## 🔧 Utility Commands

### Get All Resources Summary
```bash
kubectl get all -A                     # Quick overview
kubectl api-resources                  # List all resource types
kubectl get ns                         # List namespaces
```

### Port Forward (Access Service Locally)
```bash
# Forward Nautobot service to localhost
kubectl port-forward -n nautobot svc/nautobot 8080:80

# Then access: http://localhost:8080
```

### Copy Files To/From Pods
```bash
# Copy TO pod
kubectl cp /local/file.txt nautobot/<pod-name>:/tmp/file.txt

# Copy FROM pod
kubectl cp nautobot/<pod-name>:/app/logs/nautobot.log ./nautobot.log
```

---

## 📝 Quick One-Liners

```bash
# Count pods by status
kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c

# List all images in use
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}' | sort | uniq

# Get pod IPs
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,IP:.status.podIP

# Get external IPs of services
kubectl get svc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip

# Check which pods are on which nodes
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,POD:.metadata.name,NODE:.spec.nodeName

# Restart deployment (rolling restart)
kubectl rollout restart deployment <deployment-name> -n nautobot
```

---

## 🎬 Quick Start Script

Use the pre-made script for quick checks:
```bash
./scripts/check_cluster.sh
```

This checks:
- Cluster connectivity
- Node status
- All pods
- All services
- Problematic pods
- Recent events
- Nautobot-specific resources
