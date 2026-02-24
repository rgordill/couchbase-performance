# Couchbase Performance - ArgoCD Deployment

This directory contains ArgoCD Application manifests for deploying Couchbase on OpenShift with Prometheus monitoring integration. Documentation and examples use **kubectl** (Kubernetes CLI) by default; use `oc` only when an OpenShift-specific resource or command is required (see project Kubernetes rules).

**Official documentation**: [Helm Deployment](https://docs.couchbase.com/operator/current/helm-setup-guide.html) | [Install on OpenShift (manual)](https://docs.couchbase.com/operator/current/install-openshift.html)

## Operator installation (Helm)

The Couchbase operator is installed via the **official Helm chart** ([Helm setup guide](https://docs.couchbase.com/operator/current/helm-setup-guide.html)), not OLM. The chart deploys the Kubernetes Operator and the Admission Controller; the Couchbase cluster itself is managed by manifests in `manifests/couchbase/cluster/`.

- **Chart repo**: `https://couchbase-partners.github.io/helm-charts/`
- **Values**: OpenShift-specific values (Red Hat Container Catalog images, image pull secret) are in `helm/openshift-values.yaml`. For ArgoCD the same values are embedded in the operator Application.

**Image pull secret (OpenShift):** Create a pull secret for `registry.connect.redhat.com` in the **couchbase** namespace (where the operator runs) before installing:

```bash
kubectl create secret docker-registry rh-catalog -n couchbase \
  --docker-server=registry.connect.redhat.com \
  --docker-username=<rhel-username> --docker-password=<rhel-password> --docker-email=<email>
```

### User permissions

By default on OpenShift, users may not have permission to create or modify Couchbase custom resources. The [official guide](https://docs.couchbase.com/operator/current/install-openshift.html) describes installing a cluster role and role bindings. When using ArgoCD or a cluster-admin deployer, the same account that applies the manifests typically has sufficient rights; for restricted users, create the role and role bindings as in the docs.

## Cluster domain and TLS

- **Cluster domain**: `apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`
- **Ingress**: `manifests/couchbase/cluster/ingress.yaml` — Admin UI uses edge termination with `cert-manager.io/cluster-issuer: lab-ca-issuer`; client uses passthrough. For edge or reencrypt Ingress, always set the cert-manager cluster-issuer annotation to `lab-ca-issuer`.

## Architecture

The deployment consists of multiple ArgoCD Applications organized in an App of Apps pattern:

1. **couchbase-root-app**: Parent application managing all child applications
2. **couchbase-operator**: Couchbase Autonomous Operator
3. **couchbase-cluster**: Couchbase cluster resources (databases, buckets, etc.)
4. **couchbase-monitoring**: ServiceMonitor for Prometheus user-workload-monitoring
5. **grafana-operator**: Grafana Operator (Helm OCI chart); manages Grafana instances, dashboards, and data sources via CRs

## Prerequisites

- OpenShift 4.12+ cluster
- ArgoCD installed
- User Workload Monitoring enabled in OpenShift

## Enabling User Workload Monitoring

Before deploying, ensure user workload monitoring is enabled:

```bash
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
```

## Deployment

### Quick Start

Deploy the root application:

```bash
kubectl apply -f app-of-apps.yaml
```

### Manual Deployment (without ArgoCD)

To test the same manifests that ArgoCD would apply, use the manual deploy script:

```bash
# Build only - validate manifests (no cluster needed)
cd argocd
./deploy-manual.sh --build-only

# Dry run (preview; may need cluster for CRD validation)
./deploy-manual.sh --dry-run

# Server-side dry run (validate against API server)
./deploy-manual.sh --dry-run=server

# Apply for real (same order as ArgoCD: operator → cluster → monitoring)
./deploy-manual.sh

# Remove objects deployed by manual deploy (teardown)
./deploy-manual.sh --remove
```

From repo root with Makefile:

```bash
make deploy-build-only       # Validate kustomize build only (no cluster)
make deploy-dry-run          # Preview (cluster optional)
make deploy-dry-run-server   # Validate against server
make deploy-manual           # Apply manually
make deploy-manual-remove    # Remove manually deployed objects
```

The script installs the operator via Helm (`helm/openshift-values.yaml`), then applies the cluster and monitoring manifests. It requires `helm` and `kubectl`.

## Directory Structure

```
argocd/
├── README.md                           # This file
├── app-of-apps.yaml                    # Root ArgoCD Application
├── applications/                       # Individual ArgoCD Applications
│   ├── couchbase-operator-app.yaml
│   ├── couchbase-cluster-app.yaml
│   └── couchbase-monitoring-app.yaml
├── helm/                               # Helm values for Couchbase operator
│   ├── openshift-values.yaml           # Used by deploy-manual.sh
│   ├── Chart.yaml                      # Optional umbrella chart
│   └── values.yaml
└── manifests/                          # Kubernetes manifests
    ├── operator/                       # Namespace only (operator installed via Helm)
    │   ├── namespace.yaml
    │   └── kustomization.yaml
    ├── cluster/                        # Couchbase cluster resources
    │   ├── namespace.yaml
    │   ├── cluster.yaml
    │   ├── buckets.yaml
    │   ├── users.yaml
    │   └── replication.yaml
    └── monitoring/                     # Prometheus monitoring
        ├── service-monitor.yaml
        └── pod-monitor.yaml
```

## Monitoring

Prometheus metrics are exported via:
- ServiceMonitor for cluster-level metrics
- PodMonitor for pod-level metrics

Access metrics in OpenShift console:
- Observe → Metrics
- Query: `couchbase_*`

## Customization

Edit values in the manifests under `manifests/` directory. ArgoCD will automatically sync changes.

### Common Customizations

1. **Cluster Size**: Edit `manifests/couchbase/cluster/cluster.yaml` → `spec.servers[].size`
2. **Bucket Memory**: Edit `manifests/couchbase/cluster/buckets.yaml` → `spec.memoryQuota`
3. **Monitoring Interval**: Edit `manifests/couchbase/monitoring/service-monitor.yaml` → `spec.endpoints[].interval`

## Troubleshooting

### Operator pods not starting or ImagePullBackOff

Ensure the image pull secret `rh-catalog` exists in the `couchbase` namespace for `registry.connect.redhat.com` (see [Helm setup guide](https://docs.couchbase.com/operator/current/helm-setup-guide.html)).

### Check ArgoCD Application Status

```bash
kubectl get applications -n argocd
```

### Check Couchbase Operator

Per the [official guide](https://docs.couchbase.com/operator/current/install-openshift.html), the operator is ready when the deployments are available. The operator is installed in the **couchbase** namespace (Helm release `operator`) so it manages the CouchbaseCluster there; deployment name is `operator-couchbase-operator`.

```bash
# Operator and admission controller in couchbase namespace (deployment: operator-couchbase-operator)
kubectl get deployments -n couchbase
kubectl get pods -n couchbase
kubectl logs -n couchbase -l app.kubernetes.io/name=couchbase-operator --tail=50
```

### Check Couchbase Cluster

```bash
kubectl get couchbaseclusters -n couchbase
kubectl describe couchbasecluster couchbase-cluster -n couchbase
```

### Check Metrics

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n couchbase

# Test metrics endpoint
kubectl exec -n couchbase <pod-name> -- curl localhost:8091/metrics
```
