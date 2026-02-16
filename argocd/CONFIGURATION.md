# Configuration Guide for Couchbase on OpenShift

This guide explains how to customize the Couchbase deployment for your specific needs.

## Table of Contents

1. [Cluster Configuration](#cluster-configuration)
2. [Bucket Configuration](#bucket-configuration)
3. [User Management](#user-management)
4. [Monitoring Configuration](#monitoring-configuration)
5. [Performance Tuning](#performance-tuning)
6. [Security](#security)
7. [Backup and Recovery](#backup-and-recovery)
8. [Troubleshooting](#troubleshooting)

## Cluster Configuration

### Storage Class

Update the `storageClassName` in `manifests/cluster/cluster.yaml`:

```yaml
volumeClaimTemplates:
  - metadata:
      name: couchbase
    spec:
      storageClassName: "your-storage-class"  # Change this
```

Common OpenShift storage classes:
- `ocs-storagecluster-ceph-rbd` - OpenShift Data Foundation (block)
- `ocs-storagecluster-cephfs` - OpenShift Data Foundation (filesystem)
- `gp3-csi` - AWS EBS (if on AWS)
- `thin` - VMware vSphere

### Node Sizing

Adjust node resources in `manifests/cluster/cluster.yaml`:

```yaml
servers:
  - name: data
    size: 2  # Data server class size (2 data + 1 analytics = 3 replicas total)
    pod:
      spec:
        containers:
          - name: couchbase
            resources:
              requests:
                cpu: 2      # Adjust CPU
                memory: 4Gi # Adjust memory
              limits:
                cpu: 4
                memory: 8Gi
```

### Memory Quotas

Set service memory quotas in `manifests/cluster/cluster.yaml`:

```yaml
cluster:
  dataServiceMemoryQuota: 2Gi      # Adjust for your workload
  indexServiceMemoryQuota: 1Gi
  searchServiceMemoryQuota: 1Gi
  eventingServiceMemoryQuota: 1Gi
  analyticsServiceMemoryQuota: 1Gi
```

### Ingress and cluster domain

Cluster domain and TLS for Ingress are configured in `manifests/cluster/ingress.yaml`:

- **Cluster domain**: `apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`
- **Admin UI (edge termination)**: `couchbase-admin.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com` — TLS at ingress; a Certificate in `certificate-admin.yaml` uses ClusterIssuer `lab-ca-issuer` to create the secret referenced by the Ingress so OpenShift can create the Route.
- **Client (passthrough)**: `couchbase-client.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com` — TLS passes through to the backend; no cert-manager annotation.

For any Ingress with **edge** or **reencrypt** termination (TLS terminated at ingress), add:

```yaml
annotations:
  cert-manager.io/cluster-issuer: lab-ca-issuer
```

Ensure the ClusterIssuer `lab-ca-issuer` exists in the cluster. Passthrough Ingress resources do not need this annotation.

## Bucket Configuration

### Create Additional Buckets

Add more buckets in `manifests/cluster/buckets.yaml`:

```yaml
---
apiVersion: couchbase.com/v2
kind: CouchbaseBucket
metadata:
  name: my-custom-bucket
  namespace: couchbase
spec:
  name: mycustom
  memoryQuota: 1Gi
  replicas: 2
  ioPriority: high
  evictionPolicy: fullEviction
  enableFlush: false
```

### Bucket Types

- **evictionPolicy**:
  - `fullEviction`: Better for large datasets (documents not in memory)
  - `valueOnly`: Better for small datasets (metadata always in memory)
  - `nruEviction`: Not recently used eviction
  - `noEviction`: No eviction (cache full errors when full)

- **ioPriority**:
  - `high`: Higher disk I/O priority
  - `low`: Lower disk I/O priority

### Durability Requirements

Set durability levels:

```yaml
minimumDurability: majorityAndPersistActive  # Options:
  # - none
  # - majority
  # - majorityAndPersistActive
  # - persistToMajority
```

## User Management

### Create Application Users

Add users in `manifests/cluster/users.yaml`:

```yaml
---
apiVersion: couchbase.com/v2
kind: CouchbaseUser
metadata:
  name: my-app-user
  namespace: couchbase
spec:
  authDomain: local
  authSecret: my-app-user-password
---
apiVersion: v1
kind: Secret
metadata:
  name: my-app-user-password
  namespace: couchbase
type: Opaque
stringData:
  password: "YourSecurePassword123!"
---
apiVersion: couchbase.com/v2
kind: CouchbaseRoleBinding
metadata:
  name: my-app-user-binding
  namespace: couchbase
spec:
  subjects:
    - kind: CouchbaseUser
      name: my-app-user
  roleRef:
    kind: CouchbaseRole
    name: bucket_admin
    scope: "your-bucket-name"
```

### Available Roles

- **Admin Roles**:
  - `admin`: Full cluster admin
  - `cluster_admin`: Cluster operations admin
  - `ro_admin`: Read-only admin

- **Bucket Roles**:
  - `bucket_admin`: Full bucket admin
  - `bucket_full_access`: Read/write access
  - `data_reader`: Read-only data access
  - `data_writer`: Write data access
  - `data_dcp_reader`: DCP read access
  - `data_backup`: Backup access

- **Query Roles**:
  - `query_select`: SELECT query execution
  - `query_update`: UPDATE query execution
  - `query_insert`: INSERT query execution
  - `query_delete`: DELETE query execution
  - `query_manage_index`: Index management

## Monitoring Configuration

Monitoring uses **Couchbase Server native Prometheus metrics** (Server 7.0+) as recommended in the [official guide](https://docs.couchbase.com/operator/current/howto-prometheus.html). The deprecated exporter sidecar is not used.

- **Metrics Service** (`manifests/monitoring/couchbase-metrics-service.yaml`): A dedicated Service targeting the admin port 8091 on Couchbase server pods, with label `app.couchbase.com/name: couchbase` for ServiceMonitor selection. One service per cluster; Couchbase exposes a Prometheus-compatible endpoint on each pod.
- **ServiceMonitor** (`manifests/monitoring/service-monitor.yaml`): Directs Prometheus to scrape the metrics Service with `basicAuth` using the cluster admin Secret (`cb-admin-auth`). Includes `namespaceSelector.matchNames: [couchbase]`. If your Prometheus runs in another namespace (e.g. `monitoring`), ensure its `serviceMonitorNamespaceSelector` includes `couchbase`, or move the ServiceMonitor to the Prometheus namespace and keep `namespaceSelector` pointing at `couchbase`.
- **TLS**: If the Couchbase admin console uses TLS, use port **18091** in the metrics Service and add `tlsConfig: {}` (or appropriate [SafeTLSConfig](https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.SafeTLSConfig)) to the ServiceMonitor endpoint.

### Adjust Scrape Intervals

Edit `manifests/monitoring/service-monitor.yaml` (Couchbase cluster endpoint):

```yaml
endpoints:
  - port: metrics
    interval: 15s        # Change scrape interval
    scrapeTimeout: 10s   # Change timeout
```

### Custom Prometheus Rules

Add custom alerts in `manifests/monitoring/prometheus-rules.yaml`:

```yaml
- alert: MyCustomAlert
  expr: your_prometheus_query > threshold
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Alert summary"
    description: "Alert description"
```

### Grafana Dashboards

Import dashboards:
1. Access Grafana in OpenShift Console
2. Import dashboard JSON from `manifests/monitoring/grafana-dashboard.yaml`
3. Select Prometheus datasource

## Performance Tuning

### Couchbase Server Settings

#### Memory Settings

For high-performance workloads:

```yaml
cluster:
  dataServiceMemoryQuota: 4Gi    # Increase for more cache
  indexServiceMemoryQuota: 2Gi   # Increase for larger indexes
```

#### Storage Settings

For SSD storage:

```yaml
cluster:
  indexStorageSetting: plasma    # plasma for SSD, forestdb for HDD
```

#### Auto-failover Settings

```yaml
cluster:
  autoFailoverTimeout: 10s                      # Failover timeout
  autoFailoverMaxCount: 3                       # Max auto-failovers
  autoFailoverOnDataDiskIssues: true           # Disk issue failover
  autoFailoverOnDataDiskIssuesTimePeriod: 120s # Disk check period
```

### Pod Resources

For performance testing, increase resources:

```yaml
resources:
  requests:
    cpu: 4
    memory: 8Gi
  limits:
    cpu: 8
    memory: 16Gi
```

### Network Performance

Adjust pod anti-affinity:

```yaml
antiAffinity: true  # Spread pods across nodes for better network distribution
```

## Security

### TLS Configuration

Enable TLS for client connections:

```yaml
security:
  tls:
    static:
      serverSecret: couchbase-server-tls
      operatorSecret: couchbase-operator-tls
```

Create TLS secrets:

```bash
kubectl create secret tls couchbase-server-tls \
  --cert=server.crt \
  --key=server.key \
  -n couchbase
```

### Network Policies

The included network policy restricts access. To allow your app:

```yaml
# Label your application namespace
kubectl label namespace my-app app-access=allowed
```

### RBAC

Update user roles regularly and follow principle of least privilege.

## Backup and Recovery

### Create Backup Plan

```yaml
---
apiVersion: couchbase.com/v2
kind: CouchbaseBackup
metadata:
  name: couchbase-backup
  namespace: couchbase
spec:
  strategy: full_incremental
  full:
    schedule: "0 2 * * 0"  # Weekly full backup at 2 AM Sunday
  incremental:
    schedule: "0 2 * * 1-6"  # Daily incremental at 2 AM
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  backupRetention: 720h  # 30 days
  logRetention: 168h     # 7 days
  size: 100Gi
  storageClassName: ocs-storagecluster-ceph-rbd
```

### Restore from Backup

```yaml
---
apiVersion: couchbase.com/v2
kind: CouchbaseBackupRestore
metadata:
  name: restore-performance
  namespace: couchbase
spec:
  backup: couchbase-backup
  repo: my-repo
  archive: 2024-01-15T02:00:00
  autoCreateBuckets: true
  forceUpdates: false
```

## Repository Configuration

Before deploying, update the repository URL in these files:

1. `app-of-apps.yaml`
2. `applications/couchbase-operator-app.yaml`
3. `applications/couchbase-cluster-app.yaml`
4. `applications/couchbase-monitoring-app.yaml`

Replace:
```yaml
repoURL: https://github.com/your-org/couchbase-performance.git
```

With your actual repository URL.

Or use the deploy script:
```bash
export REPO_URL="https://github.com/your-org/couchbase-performance.git"
./deploy.sh
```

## Environment-Specific Configurations

### Development

- Smaller resource requests/limits
- Single replica buckets
- Enable flush on buckets
- Shorter backup retention

### Production

- Higher resource requests/limits
- Multiple replica buckets (2+)
- Disable flush on buckets
- Longer backup retention (30+ days)
- Enable auto-failover
- TLS encryption
- Strict network policies

## Troubleshooting

### View Couchbase Logs

```bash
kubectl logs -n couchbase -l app=couchbase --tail=100
```

### Check Cluster Status

```bash
kubectl exec -n couchbase couchbase-cluster-0000 -- couchbase-cli server-list \
  -c localhost -u Administrator -p P@ssw0rd123!
```

### Debug Monitoring

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n couchbase -o yaml

# Test metrics endpoint
kubectl exec -n couchbase couchbase-cluster-0000 -- curl -s localhost:9102/metrics | grep couchbase
```

### Check ArgoCD Sync Status

```bash
argocd app get couchbase-cluster
argocd app sync couchbase-cluster --force
```

### Admin UI Ingress: OpenShift not creating a Route from the Ingress

OpenShift creates a Route from the `couchbase-admin-ui` Ingress when the Ingress is valid and the controller admits it. If no Route appears, fix the following:

1. **ingressClassName** must match the cluster’s IngressClass used by the default IngressController. Check with:
   ```bash
   kubectl get ingressclass
   ```
   Use the name of the default class (or the one backed by the IngressController). The manifests use `openshift-default`; if your cluster uses a different name (e.g. `openshift`), set `spec.ingressClassName` in `manifests/cluster/ingress.yaml` to that value.

2. **TLS secret must exist** for edge termination. The secret `couchbase-admin-tls` is created by the Certificate in `manifests/cluster/certificate-admin.yaml` (cert-manager). Ensure the Certificate is applied and the ClusterIssuer `lab-ca-issuer` exists. Until the secret exists, the controller may not create the Route. Check:
   ```bash
   kubectl get certificate -n couchbase couchbase-admin-tls
   kubectl get secret -n couchbase couchbase-admin-tls
   ```

3. **Backend port** must be by number: `port.number: 8091` (not `port.name`), so the controller can create the Route without resolving service port names.

4. **OpenShift annotations** on the Ingress: `route.openshift.io/termination: edge` and `route.openshift.io/insecureEdgeTerminationPolicy: Redirect` are set in the manifest.

**Verify** that the Route was created:

```bash
kubectl get route -n couchbase
kubectl get ingress -n couchbase couchbase-admin-ui -o yaml
```
