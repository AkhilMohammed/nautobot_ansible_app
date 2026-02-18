#!/bin/bash
# Build and deploy Nautobot with Git plugins to Kubernetes

set -e

echo "==> Building Nautobot image with Git plugins..."

# Configuration
IMAGE_NAME="nautobot-with-plugins"
IMAGE_TAG="3.0.6-$(date +%Y%m%d-%H%M%S)"
REGISTRY="your-registry.azurecr.io"  # CHANGE THIS to your Azure Container Registry

# Build the image
cd /home/ubuntu/nautobot_ansible_app/docker
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile.nautobot-with-plugins .

echo "==> Image built: ${IMAGE_NAME}:${IMAGE_TAG}"

# Tag for registry
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:latest

echo "==> Tagged images for registry: ${REGISTRY}"

# Login to Azure Container Registry (if needed)
# Uncomment and run this if you haven't logged in:
# az acr login --name your-registry-name

# Push to registry
echo "==> Pushing images to registry..."
docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
docker push ${REGISTRY}/${IMAGE_NAME}:latest

echo "==> Images pushed successfully!"
echo ""
echo "Now update your Helm values file with:"
echo ""
echo "image:"
echo "  repository: ${REGISTRY}/${IMAGE_NAME}"
echo "  tag: \"${IMAGE_TAG}\""
echo "  pull Policy: Always"
echo ""
echo "nautobot:"
echo "  plugins:"
echo "    enabled: false  # Plugins already in image!"
echo ""
echo "Then deploy with:"
echo "helm upgrade nautobot ~/nautobot-helm -n nautobot -f values.yaml"
