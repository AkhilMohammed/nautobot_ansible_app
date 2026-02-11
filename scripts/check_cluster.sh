#!/bin/bash
# Kubernetes Cluster Status Check Script
# Usage: ./scripts/check_cluster.sh

set -e

MASTER_IP="172.17.152.109"
MASTER_USER="ubuntu"

echo "================================================"
echo "   KUBERNETES CLUSTER STATUS CHECK"
echo "================================================"
echo ""

echo "🔍 1. CLUSTER CONNECTIVITY"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl cluster-info" || echo "❌ Cluster not accessible"
echo ""

echo "🖥️  2. NODE STATUS"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get nodes -o wide" || echo "❌ Cannot get nodes"
echo ""

echo "📦 3. ALL PODS (All Namespaces)"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get pods -A -o wide" || echo "❌ Cannot get pods"
echo ""

echo "🌐 4. ALL SERVICES"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get svc -A" || echo "❌ Cannot get services"
echo ""

echo "🚀 5. DEPLOYMENTS"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get deployments -A" || echo "❌ Cannot get deployments"
echo ""

echo "⚠️  6. PROBLEM PODS (Not Running/Completed)"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get pods -A | grep -Ev 'Running|Completed|STATUS'" || echo "✅ All pods are healthy"
echo ""

echo "📊 7. RESOURCE USAGE"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl top nodes 2>/dev/null" || echo "⚠️  Metrics not available"
echo ""

echo "📋 8. RECENT EVENTS"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get events -A --sort-by='.lastTimestamp' | tail -10" || echo "❌ Cannot get events"
echo ""

echo "================================================"
echo "   NAUTOBOT-SPECIFIC CHECKS"
echo "================================================"
echo ""

echo "🔍 9. NAUTOBOT NAMESPACE PODS"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get pods -n nautobot -o wide 2>/dev/null" || echo "ℹ️  Nautobot namespace not found (not deployed yet)"
echo ""

echo "🔍 10. NAUTOBOT SERVICES"
echo "----------------------------------------"
ssh ${MASTER_USER}@${MASTER_IP} "kubectl get svc -n nautobot 2>/dev/null" || echo "ℹ️  Nautobot services not found"
echo ""

echo "✅ Status check complete!"
