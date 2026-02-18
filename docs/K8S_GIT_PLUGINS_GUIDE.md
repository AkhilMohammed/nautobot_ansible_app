# Kubernetes Git Plugin Support - Complete Guide

## Why Kubernetes Needs a Different Approach

### The Core Issue

**Azure VMs** (what you have working):
- Single persistent filesystem at `/opt/nautobot/`
- `pip install git+https://...` installs to venv
- Nautobot imports from same venv ✅  
- Works perfectly!

**Kubernetes Pods** (the challenge):
- Each container has its own filesystem  
- Init containers install plugins → separate lifecycle
- Main container can't see init container installations ❌  
- Pod restarts = lose all installs (must reinstall every time)

This isn't a Kubernetes limitation - it's container design. **The solution is simple: bake plugins into the image.**

---

## Solution Overview: Custom Docker Image

Instead of installing plugins at runtime (slow, unreliable), build them into the image (fast, reliable).

### Why This is "NTC Style"

You mentioned wanting "NTC style" - this IS how Network to Code does it:

1. **Declarative**: Your Dockerfile declares exactly what plugins and versions  
2. **Repeatable**: Same image = same plugins every time
3. **Version Controlled**: Dockerfile in Git tracks plugin changes
4. **CI/CD Ready**: Automated builds when plugins change  
5. **Fast Deployment**: No 10-15 min install time per pod!

### Your Custom Plugins

This approach works PERFECTLY for your own plugins:

```dockerfile
# Your custom plugins from your private repos
RUN pip install git+https://github.com/your-org/your-custom-nautobot-plugin.git@main
```

---

## Implementation Steps

### Step 1: Build Custom Image

```bash
cd /home/ubuntu/nautobot_ansible_app/docker

# Edit Dockerfile.nautobot-with-plugins to add/remove plugins
# Then build:
docker build -t nautobot-with-plugins:latest -f Dockerfile.nautobot-with-plugins .
```

### Step 2: Push to Container Registry

**Option A: Azure Container Registry (recommended)**
```bash
# One-time setup
az acr create --resource-group your-rg --name yourregistry --sku Basic
az acr login --name yourregistry

# Push image
docker tag nautobot-with-plugins:latest yourregistry.azurecr.io/nautobot:3.0.6-plugins
docker push yourregistry.azurecr.io/nautobot:3.0.6-plugins
```

**Option B: Docker Hub**
```bash
docker login
docker tag nautobot-with-plugins:latest yourusername/nautobot:3.0.6-plugins
docker push yourusername/nautobot:3.0.6-plugins
```

**Optional C: Local Registry** (for testing)
```bash
# Run local registry on master node
docker run -d -p 5000:5000 --name registry registry:2

# Push to local
docker tag nautobot-with-plugins:latest localhost:5000/nautobot:3.0.6-plugins
docker push localhost:5000/nautobot:3.0.6-plugins
```

### Step 3: Update Helm Values

Create `nautobot-values-custom-image.yaml`:

```yaml
image:
  repository: yourregistry.azurecr.io/nautobot  # or yourusername/nautobot or localhost:5000/nautobot
  tag: "3.0.6-plugins"
  pullPolicy: Always

nautobot:
  secretKey: "your-secret-key"
  # Plugins are IN the image now, so disable runtime installation
  plugins:
    enabled: false  # ← Important! Plugins already installed in image
  
  # But still configure them in nautobot_config.py
  pluginsConfig:
    nautobot_device_lifecycle_mgmt: {}
    nautobot_dns_models: {}
    nautobot_bgp_models: {}
    nautobot_firewall_models: {}

database:
  host: nautobot-postgresql
  name: nautobot
  # ... rest of config
```

### Step 4: Deploy

```bash
scp nautobot-values-custom-image.yaml ubuntu@172.17.152.109:/tmp/
ssh ubuntu@172.17.152.109 "helm upgrade nautobot ~/nautobot-helm -n nautobot -f /tmp/nautobot-values-custom-image.yaml --wait"
```

---

## Comparison: Runtime Install vs Custom Image

| Aspect | Runtime Install (failing now) | Custom Image (solution) |
|--------|------------------------------|------------------------|
| **Install Time** | 10-15 min per pod | 0 seconds (pre-installed) |
| **Pod Startup** | Slow, often timeout | Fast (<30 seconds) |
| **Reliability** | Fails if Git is down | Always works |
| **Git Repos** | ✅ Supported | ✅ Supported |
| **Custom Plugins** | ✅ Supported | ✅ Supported |
| **Version Control** | ❌ No | ✅ Dockerfile in Git |
| **CI/CD** | ❌ Hard | ✅ Easy to automate |
| **Pod Restarts** | Reinstall every time | Fast (already installed) |

---

## Automated CI/CD for Plugin Updates

### GitHub Actions Workflow

Create `.github/workflows/build-nautobot-image.yml`:

```yaml
name: Build Nautobot Image

on:
  push:
    paths:
      - 'docker/Dockerfile.nautobot-with-plugins'
      - 'group_vars/*/nautobot.yml'  # When plugins change

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Login to Azure Container Registry
        uses: docker/login-action@v2
        with:
          registry: yourregistry.azurecr.io
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      
      - name: Build and push
        run: |
          cd docker
          IMAGE_TAG="3.0.6-$(date +%Y%m%d-%H%M%S)"
          docker build -t yourregistry.azurecr.io/nautobot:${IMAGE_TAG} \
                       -t yourregistry.azurecr.io/nautobot:latest \
                       -f Dockerfile.nautobot-with-plugins .
          docker push yourregistry.azurecr.io/nautobot:${IMAGE_TAG}
          docker push yourregistry.azurecr.io/nautobot:latest
      
      - name: Update Kubernetes deployment
        run: |
          # Auto-deploy to dev environment
          kubectl set image deployment/nautobot-web \
            nautobot=yourregistry.azurecr.io/nautobot:${IMAGE_TAG} \
            -n nautobot
```

Now when you add a plugin:
1. Edit `Dockerfile.nautobot-with-plugins`
2. Git commit & push
3. GitHub Actions builds new image
4. K8s automatically updates ✅

---

## FAQ

**Q: Can I still use Git URLs with this approach?**  
A: Absolutely! The Dockerfile uses `pip install git+https://...` just like Azure VMs.

**Q: What about my own custom plugins?**  
A: Perfect use case! Add your private repo URLs to the Dockerfile:
```dockerfile
RUN pip install git+https://${GIT_TOKEN}@github.com/your-org/your-plugin.git@main
```

**Q: How do I update a plugin?**  
A: Update the Dockerfile, rebuild image pushes, update Helm values with new tag. K8s rolls out automatically.

**Q: Isn't this slower than runtime install?**  
A: **Much faster!** Build once (10 min), deploy everywhere (<30 sec per pod vs 10-15 min).

**Q: Can I test locally before pushing to K8s?**  
A: Yes!
```bash
docker build -t nautobot-test .
docker run -it --rm nautobot-test bash
  pip list | grep nautobot  # Verify plugins
```

---

## Alternative Approaches (Not Recommended)

### Why Init Containers Don't Work
- Separate filesystem from main container
- Plugins install but main container can't import them  
- Kubernetes architectural limitation

### Why Runtime Installation is Problematic
- 10-15 minutes per pod startup
- Fails if Git is down during pod restart
- No version control or reproducibility  
- Health check timeouts during install

---

## Next Steps

1. **Test Build Locally**:
   ```bash
   cd /home/ubuntu/nautobot_ansible_app/docker
   docker build -t nautobot-custom -f Dockerfile.nautobot-with-plugins .
   docker run -it --rm nautobot-custom bash
   > pip list | grep nautobot  # Verify plugins installed
   ```

2. **Set Up Container Registry** (choose one):
   - Azure Container Registry (best for Azure deployments)
   - Docker Hub (easiest to start)
   - Local registry (for testing)

3. **Build & Push Image**:
   ```bash
   chmod +x docker/build-and-push.sh
   # Edit script to set your registry
   ./docker/build-and-push.sh
   ```

4. **Deploy to Kubernetes**:
   ```bash
   # Use the image you just pushed
   helm upgrade nautobot ~/nautobot-helm -n nautobot \
     --set image.repository=YOUR_REGISTRY/nautobot \
     --set image.tag=YOUR_TAG \
     --set nautobot.plugins.enabled=false
   ```

---

## Summary

**Kubernetes CAN handle Git plugin URLs** - it just requires the right approach:

✅ **Azure VMs**: Runtime pip install (works, you have this)  
✅ **Kubernetes**: Baked-in Docker image (faster, more reliable)

Both use the same Git URLs, both support custom plugins, both are "NTC style" declarative infrastructure!

The image-based approach is actually **better** because:
- Faster pod startup
- Version controlled  
- CI/CD ready
- No runtime failures

This is exactly how production Kubernetes deployments work! 🚀
