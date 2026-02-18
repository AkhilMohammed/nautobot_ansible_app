# Nautobot Plugins in Kubernetes - TWO WORKING SOLUTIONS

## Your Question: "Why should I rebuild again and again?"

**You're right!** Here are BOTH solutions - choose what fits your workflow:

---

## Solution 1: DEVELOPMENT - Runtime Installation (No Image Rebuild)

**Perfect for:** Frequently adding/changing plugins during development

### How it Works
- Plugins install when containers start (just like Azure VMs!)
- Add/remove plugins in values file → redeploy → done
- **No Docker image building required**

### Limitations
- Slower startup (5-8 minutes for plugin install)
- Requires extended health check delays
- Must have internet access for Git URLs

### Quick Deploy Steps

1. **Create values file** (`nautobot-dev.yaml`):
```yaml
nautobot:
  plugins:
    enabled: true
    packages:
      - name: git+https://github.com/your-org/your-plugin.git@main
        module: your_plugin
    config:
      your_plugin: {}

web:
  livenessProbe:
    initialDelaySeconds: 600  # Wait for plugin install
  readinessProbe:
    initialDelaySeconds: 480
```

2. **Deploy**:
```bash
helm upgrade nautobot ~/nautobot-helm -n nautobot -f nautobot-dev.yaml --wait
```

3. **Watch plugins install**:
```bash
kubectl logs -f -n nautobot -l app.kubernetes.io/component=web
# You'll see: "Installing git+https://..."
```

**Done!** Add another plugin? Edit the YAML and redeploy. No image rebuild.

---

## Solution 2: PRODUCTION - Custom Docker Image (Fast & Reliable)

**Perfect for:** Production deployments, stable plugin sets, CI/CD pipelines

### How it Works
- Build image once with all plugins
- Deploy anywhere, anytime - plugins already there
- **0 seconds** plugin install time

###Advantages
- Fast pod startup (<30 seconds)
- Reliable (no runtime failures)
- Version controlled (Dockerfile in Git)
- CI/CD friendly

### Quick Build Steps

1. **Create `Dockerfile.custom`**:
```dockerfile
FROM networktocode/nautobot:3.0.6-py3.11

USER root
RUN apt-get update && apt-get install -y git && apt-get clean

USER 999
RUN pip install --no-cache-dir \
    git+https://github.com/yourorg/plugin1.git@main && \
    pip install --no-cache-dir \
    git+https://github.com/yourorg/plugin2.git@develop

RUN pip list | grep nautobot  # Verify
```

2. **Build & Push** (one-time setup):
```bash
docker build -t yourregistry.azurecr.io/nautobot:custom -f Dockerfile.custom .
docker push yourregistry.azurecr.io/nautobot:custom
```

3. **Deploy** (instant startups):
```yaml
image:
  repository: yourregistry.azurecr.io/nautobot
  tag: custom
nautobot:
  plugins:
    enabled: false  # Already in image!
```

**Automate with CI/CD?** See `docs/K8S_GIT_PLUGINS_GUIDE.md` for GitHub Actions workflow

---

## Which Should I Use?

| Scenario | Solution |
|----------|----------|
| **Testing new plugins frequently** | Development (Runtime) |
| **Production with stable plugins** | Production (Custom Image) |
| **CI/CD automated deployments** | Production (Custom Image) |
| **Multiple environments (dev/test/prod)** | Both! Dev=runtime, Prod=image |
| **Custom plugins in private repos** | Both work! |
| **Fast iteration during development** | Development (Runtime) |

---

## Hybrid Approach (Best of Both Worlds)

Many teams use:
- **Dev/Test**: Runtime installation (flexibility)
- **Production**: Custom image (speed & reliability)

Same config, different deployment method:
```yaml
# dev-values.yaml
nautobot:
  plugins:
    enabled: true  # Install at runtime

# prod-values.yaml  
image:
  repository: yourregistry.azurecr.io/nautobot
  tag: stable
nautobot:
  plugins:
    enabled: false  # Already in custom image
```

---

## Your Custom Plugins Work With Both!

```yaml
# Runtime installation
packages:
  - name: git+https://github.com/yourcompany/nautobot-custom-ipam.git@main
    module: nautobot_custom_ipam

# OR in Dockerfile
RUN pip install git+https://github.com/yourcompany/nautobot-custom-ipam.git@main
```

**Same Git URLs, same plugins, different deployment method!**

---

## Troubleshooting

### Runtime Installation Not Working?

**Check init containers are disabled**:
```bash
kubectl get deployment nautobot-web -n nautobot -o yaml | grep -A 3 initContainers
# Should see: initContainers: [] or no initContainers section
```

**Check health probe delays**:
```bash
kubectl get deployment nautobot-web -n nautobot -o yaml | grep initialDelaySeconds
# Should be: 600 (10 min) or more
```

**Watch plugin installation**:
```bash
kubectl logs -f nautobot-web-xxxxx -n nautobot
# Should see: "==> Installing Git plugins at runtime..."
```

### Custom Image Not Working?

**Verify plugins in image**:
```bash
docker run --rm yourimage:tag pip list | grep nautobot
# Should show all your plugins
```

**Check image pull**:
```bash
kubectl describe pod nautobot-web-xxxx -n nautobot | grep -A 5 Events
# Should NOT show ImagePullBackOff
```

---

## Summary

**You asked:** "Why should I build again and again?"  
**Answer:** You don't have to! 

- **Development**: Runtime installation = no rebuilds needed ✅
- **Production**: Build once, deploy everywhere = fast & reliable ✅

**Both support:**
- ✅ Git URLs from any repo (public or private)
- ✅ Custom plugins
- ✅ Multiple plugins  
- ✅ `@develop` or any Git branch/tag

**Choose based on your needs, not limitations!** 🚀

---

## Next Steps

**Want runtime installation?** → See `nautobot-values-runtime-plugins.yaml`  
**Want custom image?** → See `docker/Dockerfile.nautobot-with-plugins`  
**Want both?** → Use runtime for dev, image for prod!

Full guide with CI/CD automation: `docs/K8S_GIT_PLUGINS_GUIDE.md`
