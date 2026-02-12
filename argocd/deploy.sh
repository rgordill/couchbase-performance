#!/bin/bash
#
# Deploy Couchbase using ArgoCD
# Usage: ./deploy.sh [environment]
#

set -e

ENVIRONMENT=${1:-"dev"}
REPO_URL=${REPO_URL:-"https://github.com/rgordill/couchbase-performance.git"}

# Detect CLI (prefer kubectl)
if command -v kubectl &> /dev/null; then
    CLI="kubectl"
elif command -v oc &> /dev/null; then
    CLI="oc"
else
    echo "ERROR: kubectl or oc required"
    exit 1
fi

# Detect platform
PLATFORM="kubernetes"
if $CLI get namespace openshift-monitoring &> /dev/null 2>&1; then
    PLATFORM="openshift"
fi

# Set ArgoCD namespace based on platform
if [ "$PLATFORM" == "openshift" ]; then
    ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-"openshift-gitops"}
else
    ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-"argocd"}
fi

echo "==================================="
echo "Deploying Couchbase via ArgoCD"
echo "Platform: ${PLATFORM}"
echo "CLI: ${CLI}"
echo "Environment: ${ENVIRONMENT}"
echo "ArgoCD Namespace: ${ARGOCD_NAMESPACE}"
echo "==================================="

# Check if ArgoCD is installed
if ! $CLI get namespace ${ARGOCD_NAMESPACE} &> /dev/null; then
    echo "ERROR: ArgoCD namespace '${ARGOCD_NAMESPACE}' not found"
    echo "Please install ArgoCD first"
    exit 1
fi

# Update the app-of-apps with the correct repo URL
echo "Updating repository URL to: ${REPO_URL}"
sed -i "s|repoURL:.*|repoURL: ${REPO_URL}|g" app-of-apps.yaml applications/*.yaml

# Substitute ArgoCD namespace (openshift-gitops on OpenShift, argocd on Kubernetes)
echo "Using ArgoCD namespace: ${ARGOCD_NAMESPACE}"
for f in app-of-apps.yaml applications/*.yaml; do
  [ -f "$f" ] && sed -i "s|namespace: argocd|namespace: ${ARGOCD_NAMESPACE}|g" "$f" && sed -i "s|namespace: openshift-gitops|namespace: ${ARGOCD_NAMESPACE}|g" "$f"
done
[ -f applicationset.yaml ] && sed -i "s|namespace: argocd|namespace: ${ARGOCD_NAMESPACE}|g" applicationset.yaml && sed -i "s|namespace: openshift-gitops|namespace: ${ARGOCD_NAMESPACE}|g" applicationset.yaml

# Deploy the app of apps
echo "Deploying ArgoCD root application..."
$CLI apply -f app-of-apps.yaml -n ${ARGOCD_NAMESPACE}

echo ""
echo "==================================="
echo "Deployment initiated!"
echo "==================================="
echo ""
echo "Monitor the deployment with:"
echo "  $CLI get applications -n ${ARGOCD_NAMESPACE}"
echo ""
echo "Check application status:"
echo "  argocd app get couchbase-root-app"
echo "  argocd app get couchbase-operator"
echo "  argocd app get couchbase-cluster"
echo "  argocd app get couchbase-monitoring"
echo ""
echo "Access Couchbase Web Console:"
echo "  $CLI get ingress couchbase-admin-ui -n couchbase"
echo ""
if [ "$PLATFORM" == "openshift" ]; then
    echo "View metrics in OpenShift Console:"
    echo "  Observe → Metrics"
    echo "  Query: couchbase_bucket_ops_total"
    echo ""
    echo "Note: User workload monitoring is assumed to be enabled"
else
    echo "View metrics in Prometheus/Grafana"
fi
echo ""
