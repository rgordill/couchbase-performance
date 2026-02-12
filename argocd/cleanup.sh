#!/bin/bash
#
# Cleanup Couchbase ArgoCD deployment
# Usage: ./cleanup.sh
#

set -e

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
echo "Cleaning up Couchbase deployment"
echo "Platform: ${PLATFORM}"
echo "CLI: ${CLI}"
echo "ArgoCD Namespace: ${ARGOCD_NAMESPACE}"
echo "==================================="

# Delete the root app (cascading delete)
echo "Deleting ArgoCD applications..."
$CLI delete application couchbase-root-app -n ${ARGOCD_NAMESPACE} --cascade=foreground || true

# Wait a bit for cascading deletes
echo "Waiting for resources to be deleted..."
sleep 5

# Clean up any remaining resources
echo "Cleaning up remaining resources..."
$CLI delete namespace couchbase --ignore-not-found=true
$CLI delete namespace couchbase-operator --ignore-not-found=true

echo ""
echo "==================================="
echo "Cleanup complete!"
echo "==================================="
