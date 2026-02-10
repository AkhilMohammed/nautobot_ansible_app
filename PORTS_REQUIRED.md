# Required Ports for Kubernetes + Nautobot Deployment

## Master Node (Control Plane) - 172.17.152.109

### Kubernetes Control Plane
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **6443** | TCP | Kubernetes API Server | All nodes, kubectl clients |
| **2379-2380** | TCP | etcd server client API | API server, etcd |
| **10250** | TCP | Kubelet API | Master, workers |
| **10259** | TCP | kube-scheduler | Self |
| **10257** | TCP | kube-controller-manager | Self |

## Worker Nodes (All 4 workers)

### Kubernetes Worker
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **10250** | TCP | Kubelet API | Master, self |
| **30000-32767** | TCP | NodePort Services | External clients |

### Flannel CNI
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **8472** | UDP | VXLAN overlay network | All nodes |
| **8285** | UDP | Flannel health checks | All nodes |

## Application Ports

### Nautobot (via NodePort)
| Port | Protocol | Purpose | Accessible From |
|------|----------|---------|-----------------|
| **30080** | TCP | HTTP (Nginx Ingress) | External clients |
| **30443** | TCP | HTTPS (Nginx Ingress) | External clients |

### PostgreSQL (172.17.152.107)
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **5432** | TCP | PostgreSQL | Nautobot pods |

### Redis (172.17.152.108)
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **6379** | TCP | Redis | Nautobot pods |

## SSH Access (All Nodes)
| Port | Protocol | Purpose | Used By |
|------|----------|---------|---------|
| **22** | TCP | SSH/Ansible | Deployment runner |

## Required Firewall Rules

### Master Node → Workers
- Allow TCP 10250 (kubelet)

### Workers → Master
- Allow TCP 6443 (API server)

### All Nodes → All Nodes
- Allow UDP 8472 (Flannel VXLAN)
- Allow UDP 8285 (Flannel health)
- Allow TCP 10250 (kubelet)

### Workers → Database/Redis
- Allow TCP 5432 (PostgreSQL)
- Allow TCP 6379 (Redis)

### External → Any Worker Node
- Allow TCP 30080 (HTTP)
- Allow TCP 30443 (HTTPS)

### Deployment Runner → All Nodes
- Allow TCP 22 (SSH)

## Minimum Requirements Summary

**INTERNET ACCESS (All nodes):**
- GitHub: 443/TCP (Download images, actions)
- Docker Hub: 443/TCP (Pull container images)
- k8s.io: 443/TCP (Download Kubernetes packages)

**INTERNAL CLUSTER:**
- All nodes must communicate on ports: 6443, 10250, 8472/UDP, 8285/UDP

**APPLICATION ACCESS:**
- Nautobot accessible on: http://<any-worker-ip>:30080
- Or: https://<any-worker-ip>:30443
