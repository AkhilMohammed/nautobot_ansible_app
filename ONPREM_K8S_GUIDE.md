# On-Premises Kubernetes Deployment Guide

## Overview

This guide covers deploying Nautobot on an on-premises Kubernetes cluster with your 8 VMs.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│            GitHub Actions Runner (VM #1)             │
│              192.168.1.18                            │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│         Kubernetes Cluster (5 VMs)                   │
│  ┌──────────────────────────────────────────────┐   │
│  │  Master Node (VM #2) - 192.168.1.10          │   │
│  │  - API Server, Scheduler, Controller Manager │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  Worker Nodes (VMs #3-6)                     │   │
│  │  - 192.168.1.11 - Nautobot Web Pods          │   │
│  │  - 192.168.1.12 - Nautobot Web/Worker Pods   │   │
│  │  - 192.168.1.13 - Nautobot Worker Pods       │   │
│  │  - 192.168.1.14 - Nautobot Worker/Scheduler  │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌──────────────────┐         ┌──────────────────┐
│  PostgreSQL      │         │     Redis        │
│  VM #7           │         │    VM #8         │
│  192.168.1.16    │         │  192.168.1.17    │
└──────────────────┘         └──────────────────┘
```

## VM Allocation

| VM # | Role | IP | Purpose |
|------|------|----|---------| 
| 1 | GitHub Runner | 192.168.1.18 | CI/CD automation |
| 2 | K8s Master | 192.168.1.10 | Control plane |
| 3 | K8s Worker 1 | 192.168.1.11 | Nautobot pods |
| 4 | K8s Worker 2 | 192.168.1.12 | Nautobot pods |
| 5 | K8s Worker 3 | 192.168.1.13 | Nautobot pods |
| 6 | K8s Worker 4 | 192.168.1.14 | Nautobot pods |
| 7 | PostgreSQL | 192.168.1.16 | Database |
| 8 | Redis | 192.168.1.17 | Cache & broker |

## Prerequisites

- 8 VMs with Ubuntu 20.04/22.04
- At least 2 CPU, 4GB RAM per VM
- Network connectivity between all VMs
- SSH access to all VMs

## Setup Steps

### 1. Configure Inventory

Edit `inventory/k8s/onprem.yml` with your VM IPs and credentials.

### 2. Setup Vault

```bash
cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml
vim group_vars/onprem/vault.yml  # Add passwords
ansible-vault encrypt group_vars/onprem/vault.yml
```

### 3. Install Kubernetes Cluster

This will set up a complete K8s cluster with kubeadm:

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/setup_k8s_cluster.yml \
  --ask-vault-pass
```

This installs:
- containerd runtime
- kubelet, kubeadm, kubectl
- Flannel CNI networking
- Joins all worker nodes

**Time:** ~15-20 minutes

### 4. Deploy Database & Cache (VMs)

PostgreSQL and Redis run on separate VMs (not in K8s):

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_onprem.yml \
  --tags "postgres,redis" \
  --ask-vault-pass
```

### 5. Deploy Nautobot to Kubernetes

Deploy Nautobot application to K8s cluster:

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_onprem.yml \
  --tags "nautobot" \
  --ask-vault-pass
```

This creates:
- Nautobot namespace
- ConfigMaps and Secrets
- Deployments (web, worker, scheduler)
- Services
- Persistent volumes for media/static files

### 6. Access Nautobot

**Option 1: Port Forward (for testing)**
```bash
kubectl port-forward -n nautobot svc/nautobot 8000:8000
```
Visit: http://localhost:8000

**Option 2: NodePort**
```bash
kubectl get svc -n nautobot
# Access via: http://<any-worker-ip>:<nodeport>
```

**Option 3: LoadBalancer (requires MetalLB)**
```bash
# Install MetalLB first
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
# Configure IP pool
# Then access via LoadBalancer IP
```

### 7. Setup GitHub Actions Runner

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/setup_github_runner.yml \
  --ask-vault-pass
```

## Kubernetes Resources

Check deployed resources:

```bash
# All resources in nautobot namespace
kubectl get all -n nautobot

# Pods
kubectl get pods -n nautobot -o wide

# Services
kubectl get svc -n nautobot

# Logs
kubectl logs -n nautobot deployment/nautobot-web
kubectl logs -n nautobot deployment/nautobot-worker
kubectl logs -n nautobot deployment/nautobot-scheduler

# Shell into pod
kubectl exec -it -n nautobot deploy/nautobot-web -- /bin/bash
```

## Scaling

Scale Nautobot deployments:

```bash
# Scale web pods
kubectl scale -n nautobot deployment/nautobot-web --replicas=3

# Scale workers
kubectl scale -n nautobot deployment/nautobot-worker --replicas=4

# Auto-scaling (HPA)
kubectl autoscale -n nautobot deployment/nautobot-web \
  --cpu-percent=70 --min=2 --max=6
```

## GitHub Actions Workflow

The workflow automatically deploys on push:

```bash
git add .
git commit -m "Update configuration"
git push origin feat/onprem-deployment
```

Or manually trigger in GitHub Actions UI.

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n nautobot <pod-name>
kubectl logs -n nautobot <pod-name>
```

### Database connection issues
```bash
# Check from a pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
nc -zv 192.168.1.16 5432  # Test PostgreSQL
nc -zv 192.168.1.17 6379  # Test Redis
```

### Node issues
```bash
kubectl get nodes
kubectl describe node <node-name>
```

## Comparison: VM vs K8s Deployment

| Feature | VM Deployment | K8s Deployment |
|---------|--------------|----------------|
| **Complexity** | Simple | Moderate |
| **Scaling** | Manual | Automatic |
| **HA** | Load balancer needed | Built-in |
| **Updates** | Rolling manual | Rolling automatic |
| **Resource Usage** | Fixed per VM | Dynamic |
| **Monitoring** | Custom | K8s native |

## When to Use Each

**Use VM Deployment when:**
- Simple setup preferred
- Small scale (1-2 instances)
- Team not familiar with K8s

**Use K8s Deployment when:**
- Need auto-scaling
- High availability required
- Multiple environments
- CI/CD integration
- Team has K8s experience

## Files

- `inventory/k8s/onprem.yml` - K8s inventory
- `playbooks/setup_k8s_cluster.yml` - Cluster setup
- `playbooks/deploy_k8s_onprem.yml` - Nautobot deployment
- `roles/k8s_*` - K8s deployment roles

For VM-based deployment, see: [ONPREM_SETUP_GUIDE.md](ONPREM_SETUP_GUIDE.md)
