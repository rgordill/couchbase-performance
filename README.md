# Couchbase Performance Project

This repository contains ArgoCD manifests and tools for deploying and testing Couchbase on OpenShift with integrated Prometheus monitoring.

## 🎯 Overview

A complete GitOps-based Couchbase deployment solution featuring:

- **ArgoCD Applications**: Declarative deployment using App of Apps pattern
- **Couchbase Operator**: Automated cluster management
- **Multi-bucket Setup**: Pre-configured buckets for different workloads
- **RBAC Configuration**: User management and role bindings
- **Prometheus Integration**: Full metrics export to user-workload-monitoring
- **Performance Testing**: Tools and scripts for benchmarking
- **Backup & Recovery**: Automated backup configurations

## 📁 Repository Structure

```
couchbase-performance/
├── argocd/                              # ArgoCD deployment manifests
│   ├── main/                            # Bootstrap: project, app-of-apps, PreSync (cluster-configuration)
│   │   ├── app-of-apps.yaml             # Root application (syncs argocd/main)
│   │   ├── project.yaml
│   │   └── kustomization.yaml
│   ├── applications/                    # Individual app definitions
│   │   ├── couchbase-operator-app.yaml
│   │   ├── couchbase-cluster-app.yaml
│   │   └── couchbase-monitoring-app.yaml
│   ├── manifests/
│   │   └── couchbase/                   # Couchbase Kubernetes resources
│   │       ├── operator/                # Operator installation
│   │       ├── cluster/                 # Cluster configuration
│   │       └── monitoring/              # Prometheus integration
│   ├── deploy.sh                        # Deployment script
│   ├── cleanup.sh                       # Cleanup script
│   ├── verify.sh                        # Verification script
│   ├── README.md                        # ArgoCD documentation
│   ├── CONFIGURATION.md                 # Configuration guide
│   └── PROMETHEUS_QUERIES.md            # Useful Prometheus queries
└── performance/                         # Performance testing tools
    └── PERFORMANCE_TESTING.md           # Testing guide
```

## 🚀 Quick Start

### Prerequisites

- OpenShift 4.12+ cluster
- ArgoCD installed on the cluster
- `kubectl` CLI configured (or `oc` on OpenShift)
- User Workload Monitoring enabled

### Deploy

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/couchbase-performance.git
   cd couchbase-performance
   ```

2. **Update repository URL** in ArgoCD manifests:
   ```bash
   export REPO_URL="https://github.com/your-org/couchbase-performance.git"
   sed -i "s|repoURL:.*|repoURL: ${REPO_URL}|g" argocd/main/app-of-apps.yaml argocd/applications/*.yaml
   ```

3. **Deploy using the script**:
   ```bash
   cd argocd
   ./deploy.sh
   ```

4. **Verify deployment**:
   ```bash
   ./verify.sh
   ```

### Access Couchbase

```bash
# Get Admin UI URL
kubectl get ingress -n couchbase

# Default credentials (CHANGE IN PRODUCTION!)
Username: Administrator
Password: P@ssw0rd123!
```

## 📊 Monitoring

### Access Prometheus Metrics

1. **OpenShift Console**: Navigate to Observe → Metrics
2. **Query examples**:
   ```promql
   # Operations per second
   rate(couchbase_bucket_ops_total[5m])
   
   # Memory usage
   couchbase_bucket_mem_used_bytes / 1024 / 1024 / 1024
   
   # Item count
   couchbase_bucket_item_count
   ```

3. **See more queries**: Check `argocd/PROMETHEUS_QUERIES.md`

### Grafana Dashboards

Import the provided dashboard from `argocd/manifests/couchbase/monitoring/grafana-dashboard.yaml`

## 🌐 Access

- **Cluster domain**: `apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`
- **Admin UI**: https://couchbase-admin.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com (TLS via cert-manager, cluster-issuer: lab-ca-issuer)
- **Client (SDK)**: couchbase-client.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com (passthrough)

## 🔧 Configuration

### Customize Cluster Size

Edit `argocd/manifests/couchbase/cluster/cluster.yaml`:

```yaml
servers:
  - name: data
    size: 2  # Data + index + query (change as needed)
  - name: analytics
    size: 1  # Analytics + eventing (3 replicas total by default)
```

### Adjust Memory Quotas

```yaml
cluster:
  dataServiceMemoryQuota: 2Gi  # Adjust as needed
  indexServiceMemoryQuota: 1Gi
```

### Add Custom Buckets

Edit `argocd/manifests/couchbase/cluster/buckets.yaml` or add new bucket definitions.

**See detailed configuration guide**: `argocd/CONFIGURATION.md`

## 🧪 Performance Testing

The repository includes performance testing tools and guides.

**See**: `performance/PERFORMANCE_TESTING.md`

### Quick Performance Test

```bash
# Generate load
kubectl exec -it -n couchbase couchbase-cluster-0000 -- \
  cbc-pillowfight \
  -U couchbase://localhost/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 100000 \
  --num-threads 4
```

## 🔐 Security

### Default Credentials

**⚠️ WARNING**: Change default credentials before production use!

| User | Password | Purpose |
|------|----------|---------|
| Administrator | P@ssw0rd123! | Cluster admin |
| performance-user | P3rf0rm@nce! | Application user |
| readonly-user | R3ad0nly! | Read-only access |

### Update Credentials

```bash
# Update admin password
kubectl create secret generic cb-admin-auth \
  --from-literal=username=Administrator \
  --from-literal=password=YourNewPassword \
  --dry-run=client -o yaml | kubectl apply -n couchbase -f -

# Restart cluster to apply
kubectl rollout restart statefulset -n couchbase -l app=couchbase
```

## 💾 Backup & Recovery

### Automated Backups

Configured in `argocd/manifests/couchbase/cluster/backup.yaml`:

- **Full backup**: Weekly (Sunday 2 AM)
- **Incremental backup**: Daily (Monday-Saturday 2 AM)
- **Retention**: 30 days

### Manual Backup

```bash
# Trigger manual backup
kubectl create -f - <<EOF
apiVersion: couchbase.com/v2
kind: CouchbaseBackupRestore
metadata:
  name: manual-backup-$(date +%Y%m%d)
  namespace: couchbase
spec:
  backup: couchbase-backup-plan
  action: backup
EOF
```

## 📚 Documentation

- **[ArgoCD README](argocd/README.md)**: Deployment guide
- **[Configuration Guide](argocd/CONFIGURATION.md)**: Detailed configuration options
- **[Prometheus Queries](argocd/PROMETHEUS_QUERIES.md)**: Useful monitoring queries
- **[Performance Testing](performance/PERFORMANCE_TESTING.md)**: Load testing guide

## 🛠️ Troubleshooting

### Check Application Status

```bash
argocd app get couchbase-cluster
```

### View Logs

```bash
# Operator logs
kubectl logs -n couchbase -l app.kubernetes.io/name=couchbase-operator --tail=100

# Couchbase logs
kubectl logs -n couchbase -l app=couchbase --tail=100
```

### Common Issues

1. **Pods not starting**: Check storage class availability
2. **Metrics not showing**: Verify user-workload-monitoring is enabled
3. **Connection refused**: Check network policies and routes

**See detailed troubleshooting**: `argocd/CONFIGURATION.md#troubleshooting`

## 🔄 Multi-Environment Deployment

Use the ApplicationSet for deploying across multiple environments:

```bash
kubectl apply -f argocd/applicationset.yaml
```

This creates separate deployments for dev, staging, and production with appropriate sizing.

## 🧹 Cleanup

Remove all Couchbase resources:

```bash
cd argocd
./cleanup.sh
```

## 📝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test in a dev environment
5. Submit a pull request

## 📄 License

This project is licensed under the GNU General Public License v2.0 (GPL-2). See [LICENSE](LICENSE) for the full text.

## 🤝 Support

For issues and questions:
- Open a GitHub issue
- Contact: [your-email@example.com]

## 📚 Additional Resources

- [Couchbase Documentation](https://docs.couchbase.com/)
- [Couchbase Operator Guide](https://docs.couchbase.com/operator/current/overview.html)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift Monitoring](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)
