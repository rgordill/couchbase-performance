#!/bin/bash
#
# Verify Couchbase deployment and monitoring
#

set -e

NAMESPACE="couchbase"
OPERATOR_NAMESPACE="couchbase"

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

echo "==================================="
echo "Couchbase Deployment Verification"
echo "Platform: ${PLATFORM}"
echo "CLI: ${CLI}"
echo "==================================="

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" == "OK" ]; then
        echo "✓ $message"
    else
        echo "✗ $message"
    fi
}

# Check namespaces
echo ""
echo "1. Checking Namespaces..."
if $CLI get namespace $NAMESPACE &> /dev/null; then
    print_status "OK" "Couchbase namespace exists"
else
    print_status "FAIL" "Couchbase namespace missing"
fi

# Check operator
echo ""
echo "2. Checking Couchbase Operator..."
OPERATOR_READY=$($CLI get deployment -n $OPERATOR_NAMESPACE -l app.kubernetes.io/name=couchbase-operator -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$OPERATOR_READY" -gt "0" ]; then
    print_status "OK" "Operator is running ($OPERATOR_READY replicas)"
else
    print_status "FAIL" "Operator is not ready"
fi

# Check cluster
echo ""
echo "3. Checking Couchbase Cluster..."
CLUSTER_STATUS=$($CLI get couchbasecluster couchbase-cluster -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
if [ "$CLUSTER_STATUS" == "True" ]; then
    print_status "OK" "Cluster is available"
    
    POD_COUNT=$($CLI get pods -n $NAMESPACE -l app=couchbase -o json | jq '[.items[] | select(.status.phase=="Running")] | length')
    print_status "OK" "Running pods: $POD_COUNT"
else
    print_status "FAIL" "Cluster is not available (status: $CLUSTER_STATUS)"
fi

# Check buckets
echo ""
echo "4. Checking Buckets..."
BUCKET_COUNT=$($CLI get couchbasebuckets -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$BUCKET_COUNT" -gt "0" ]; then
    print_status "OK" "Found $BUCKET_COUNT bucket(s)"
    $CLI get couchbasebuckets -n $NAMESPACE -o custom-columns=NAME:.metadata.name,MEMORY:.spec.memoryQuota,REPLICAS:.spec.replicas
else
    print_status "FAIL" "No buckets found"
fi

# Check users
echo ""
echo "5. Checking Users..."
USER_COUNT=$($CLI get couchbaseusers -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$USER_COUNT" -gt "0" ]; then
    print_status "OK" "Found $USER_COUNT user(s)"
    $CLI get couchbaseusers -n $NAMESPACE
else
    print_status "FAIL" "No users found"
fi

# Check monitoring
echo ""
echo "6. Checking Monitoring..."
if $CLI get servicemonitor couchbase-cluster -n $NAMESPACE &> /dev/null; then
    print_status "OK" "ServiceMonitor exists"
else
    print_status "FAIL" "ServiceMonitor not found"
fi

if $CLI get podmonitor couchbase-pods -n $NAMESPACE &> /dev/null; then
    print_status "OK" "PodMonitor exists"
else
    print_status "FAIL" "PodMonitor not found"
fi

# Note: Assuming user workload monitoring is enabled

# Check ingress/routes
echo ""
echo "7. Checking Ingress..."
if $CLI get ingress couchbase-admin-ui -n $NAMESPACE &> /dev/null; then
    ADMIN_HOST=$($CLI get ingress couchbase-admin-ui -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')
    print_status "OK" "Admin UI ingress configured: https://$ADMIN_HOST"
else
    print_status "FAIL" "Admin UI ingress not found"
fi

# Test metrics endpoint
echo ""
echo "8. Testing Metrics Endpoint..."
FIRST_POD=$($CLI get pods -n $NAMESPACE -l app=couchbase -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$FIRST_POD" ]; then
    METRICS_TEST=$($CLI exec -n $NAMESPACE $FIRST_POD -- curl -s localhost:9102/metrics 2>/dev/null | grep -c "couchbase_" || echo "0")
    if [ "$METRICS_TEST" -gt "0" ]; then
        print_status "OK" "Metrics endpoint is working ($METRICS_TEST metrics found)"
    else
        print_status "FAIL" "Metrics endpoint is not working"
    fi
else
    print_status "FAIL" "No pods found to test metrics"
fi

# Check ArgoCD applications
echo ""
echo "9. Checking ArgoCD Applications..."
if command -v argocd &> /dev/null; then
    APPS=("couchbase-operator" "couchbase-cluster" "couchbase-monitoring")
    for app in "${APPS[@]}"; do
        APP_HEALTH=$(argocd app get $app -o json 2>/dev/null | jq -r '.status.health.status' || echo "Unknown")
        APP_SYNC=$(argocd app get $app -o json 2>/dev/null | jq -r '.status.sync.status' || echo "Unknown")
        if [ "$APP_HEALTH" == "Healthy" ] && [ "$APP_SYNC" == "Synced" ]; then
            print_status "OK" "$app: $APP_HEALTH, $APP_SYNC"
        else
            print_status "FAIL" "$app: $APP_HEALTH, $APP_SYNC"
        fi
    done
else
    echo "ArgoCD CLI not found, skipping..."
fi

echo ""
echo "==================================="
echo "Verification Complete"
echo "==================================="
echo ""
echo "To access Couchbase Web Console:"
echo "  $CLI get ingress couchbase-admin-ui -n $NAMESPACE"
echo ""
echo "Default credentials (change in production!):"
echo "  Username: Administrator"
echo "  Password: P@ssw0rd123!"
echo ""
if [ "$PLATFORM" == "openshift" ]; then
    echo "To view metrics in OpenShift:"
    echo "  Console → Observe → Metrics"
    echo "  Query: couchbase_bucket_ops_total"
else
    echo "View metrics in Prometheus/Grafana"
fi
echo ""
