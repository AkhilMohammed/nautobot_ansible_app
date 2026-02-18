# QUICK START: Git Plugins in Kubernetes

## The TL;DR

**Kubernetes CAN handle Git plugin URLs!** You just need a custom Docker image.

### 3-Minute Setup

**1. Build image with your plugins:**
```bash
cd ~/nautobot_ansible_app/docker
docker build -t nautobot-plugins:latest -f Dockerfile.nautobot-with-plugins .
```

**2. Test locally:**
```bash
docker run -it --rm nautobot-plugins:latest bash -c "pip list | grep nautobot"
# You should see all 4 plugins listed
```

**3. For production, push to a registry:**
``bash
# Azure Container Registry
az acr login --name yourregistry
docker tag nautobot-plugins:latest yourregistry.azurecr.io/nautobot:3.0.6-plugins
docker push yourregistry.azurecr.io/nautobot:3.0.6-plugins
```

**4. Deploy to K8s:**
```bash
helm upgrade nautobot ~/nautobot-helm -n nautobot \
  --set image.repository=yourregistry.azurecr.io/nautobot \
  --set image.tag=3.0.6-plugins \
  --set nautobot.plugins.enabled=false \
  --wait
```

Pods will start in <30 seconds with all plugins ready! ✅

---

## Why This Approach?

| Method | Azure VM | K8s Runtime Install | K8s Custom Image |
|--------|----------|---------------------|------------------|
| Works? | ✅ | ❌ | ✅ |
| Git URLs? | ✅ | ✅ | ✅ |
| Fast startup? | ✅ | ❌ (10-15 min) | ✅ (<30 sec) |
| Custom plugins? | ✅ | ✅ | ✅ |
| Reliable? | ✅ | ❌ | ✅ |

---

## Adding Your Custom Plugins

Edit `docker/Dockerfile.nautobot-with-plugins`:

```dockerfile
# Your custom plugin from your Git repo
RUN pip install --no-cache-dir \
    git+https://github.com/yourorg/your-nautobot-plugin.git@main
```

Then rebuild and push. That's it!

---

## Full Documentation

See [docs/K8S_GIT_PLUGINS_GUIDE.md](K8S_GIT_PLUGINS_GUIDE.md) for:
- Detailed explanation of why init containers don't work
- CI/CD automation with GitHub Actions  
- Container registry setup guides
- Troubleshooting tips

---

## Common Questions

**Q: Is this really "NTC style"?**  
A: Yes! Network to Code uses declarative Dockerfiles with Git URLs for plugin management in K8s deployments.

**Q: Can I test without a registry?**  
A: Yes! Build locally and use `imagePullPolicy: Never` in Helm values. Perfect for dev/test.

**Q: What if my plugin updates frequently?**  
A: Set up CI/CD (see full guide). Git push → auto-build → auto-deploy. Takes 5 minutes to set up.

**Q: How is this different from Azure VMs?**  
A: Same plugins, same Git URLs. Just pre-installed in image instead of installed at boot. Actually faster!
