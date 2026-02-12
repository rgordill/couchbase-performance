# Quick Start Guide - Couchbase on OpenShift with ArgoCD

This guide will walk you through deploying Couchbase on OpenShift using ArgoCD in under 10 minutes.

## Prerequisites Checklist

- [ ] OpenShift 4.12+ cluster access
- [ ] `kubectl` CLI installed and configured (or `oc` on OpenShift)
- [ ] Cluster admin privileges
- [ ] ArgoCD installed (or you can install it)
- [ ] At least 50GB storage available

## Step 1: Install ArgoCD (if not already installed)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD Operator
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: argocd-operator
  namespace: argocd
spec:
  channel: alpha
  name: argocd-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator to be ready
kubectl wait --for=condition=ready pod -l name=argocd-operator -n argocd --timeout=300s

# Create ArgoCD instance
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: argocd
  namespace: argocd
spec:
  server:
    route:
      enabled: true
EOF

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-cluster -n argocd -o jsonpath='{.data.admin\.password}' | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Get ArgoCD URL (OpenShift: use route; otherwise use ingress)
ARGOCD_URL=$(kubectl get route argocd-server -n argocd -o jsonpath='{.spec.host}' 2>/dev/null || kubectl get ingress -n argocd -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
echo "ArgoCD URL: https://$ARGOCD_URL"
```

## Step 2: Enable User Workload Monitoring

```bash
# Enable user workload monitoring in OpenShift
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

# Wait for user workload monitoring to start
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n openshift-user-workload-monitoring --timeout=300s
```

## Step 3: Clone and Configure Repository

```bash
# Clone the repository
git clone https://github.com/your-org/couchbase-performance.git
cd couchbase-performance

# Update repository URL in all files (replace with your actual repo URL)
export REPO_URL="https://github.com/your-org/couchbase-performance.git"
find argocd -name "*.yaml" -exec sed -i "s|repoURL:.*|repoURL: ${REPO_URL}|g" {} \;

# Commit changes
git add .
git commit -m "Update repository URL"
git push
```

## Step 4: Deploy Couchbase

```bash
# Change to argocd directory
cd argocd

# Deploy using the script
./deploy.sh

# OR deploy manually
kubectl apply -f app-of-apps.yaml
```

## Step 5: Monitor Deployment

```bash
# Watch ArgoCD applications
watch -n 5 'kubectl get applications -n argocd | grep couchbase'

# Watch pods coming up
watch -n 5 'kubectl get pods -n couchbase-operator && echo "" && kubectl get pods -n couchbase'

# Check operator logs
kubectl logs -f -n couchbase-operator -l app=couchbase-operator

# This will take about 5-10 minutes for full deployment
```

## Step 6: Verify Deployment

```bash
# Run verification script
./verify.sh

# Or use Makefile
cd ..
make verify
```

## Step 7: Access Couchbase

```bash
# Get Web UI URL
kubectl get ingress -n couchbase -o jsonpath='https://{.items[0].spec.rules[0].host}' 2>/dev/null || kubectl get route couchbase-admin-ui -n couchbase -o jsonpath='https://{.spec.host}'

# Default credentials (CHANGE THESE!)
# Username: Administrator
# Password: P@ssw0rd123!

# Or use Makefile
make ui
```

## Step 8: Verify Monitoring

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n couchbase

# Test metrics endpoint
kubectl exec -n couchbase $(kubectl get pods -n couchbase -l app=couchbase -o jsonpath='{.items[0].metadata.name}') -- \
  curl -s localhost:9102/metrics | grep couchbase_bucket

# View in OpenShift Console
# Navigate to: Observe → Metrics
# Query: rate(couchbase_bucket_ops_total[5m])
```

## Step 9: Run Performance Test (Optional)

```bash
# Simple load test
make load-test

# OR manually
kubectl exec -it -n couchbase $(kubectl get pods -n couchbase -l app=couchbase -o jsonpath='{.items[0].metadata.name}') -- \
  cbc-pillowfight \
  -U couchbase://localhost/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 10000 \
  --num-threads 4
```

## Step 10: Explore and Customize

### View Cluster Status

```bash
make status
```

### Check Buckets

```bash
kubectl get couchbasebuckets -n couchbase
```

### View Logs

```bash
make logs-cluster
```

### Access ArgoCD UI

```bash
make argocd-ui
```

## Common Operations

### Sync Applications

```bash
make sync
```

### Port Forward to Web UI

```bash
make port-forward
# Access at: http://localhost:8091
```

### Trigger Manual Backup

```bash
make backup-now
```

### Scale Cluster

Edit `argocd/manifests/cluster/cluster.yaml`:

```yaml
servers:
  - name: data
    size: 5  # Change from 3 to 5
```

Commit and push - ArgoCD will auto-sync.

## Troubleshooting

### Issue: Operator Not Starting

```bash
# Check operator logs
make logs-operator

# Check operator subscription
kubectl get subscription -n couchbase-operator
kubectl describe subscription couchbase-enterprise-certified -n couchbase-operator
```

### Issue: Pods Pending

```bash
# Check storage class
kubectl get storageclass

# Check PVC status
kubectl get pvc -n couchbase

# Check events
make get-events
```

### Issue: Metrics Not Showing

```bash
# Verify user workload monitoring
kubectl get pods -n openshift-user-workload-monitoring

# Check ServiceMonitor
kubectl get servicemonitor -n couchbase -o yaml

# Test metrics endpoint
make metrics
```

### Issue: ArgoCD Sync Failed

```bash
# Check application status
argocd app get couchbase-cluster

# View sync errors
argocd app sync couchbase-cluster --dry-run

# Force sync
make sync
```

## Next Steps

1. **Change Default Passwords**: Update secrets in `argocd/manifests/cluster/users.yaml`
2. **Configure TLS**: Enable TLS for production use
3. **Setup Backups**: Configure S3 credentials in backup configuration
4. **Tune Resources**: Adjust memory and CPU based on workload
5. **Add Applications**: Connect your applications to Couchbase

## Security Checklist

- [ ] Change Administrator password
- [ ] Change all user passwords
- [ ] Enable TLS
- [ ] Configure network policies
- [ ] Set up RBAC properly
- [ ] Enable audit logging
- [ ] Configure backup encryption
- [ ] Review resource limits

## Production Readiness

Before going to production:

1. Review and customize `argocd/manifests/cluster/cluster.yaml`
2. Update all passwords and secrets
3. Configure proper storage class and sizes
4. Set up monitoring alerts
5. Configure backup strategy
6. Document runbooks
7. Test disaster recovery procedures
8. Set up proper RBAC

## Getting Help

- **Documentation**: See `README.md` and other docs
- **Configuration**: See `CONFIGURATION.md`
- **Monitoring**: See `PROMETHEUS_QUERIES.md`
- **Performance**: See `performance/PERFORMANCE_TESTING.md`
- **Issues**: Open a GitHub issue

## Cleanup

When you're done testing:

```bash
make cleanup
```

This will remove all Couchbase resources.

---

**Congratulations!** 🎉 You now have a fully functional Couchbase cluster on OpenShift with monitoring!
