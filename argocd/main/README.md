# App-of-apps (bootstrap)

The app-of-apps Application has **two sources**:

1. **argocd/manifests/cluster-objects** — AppProject, RBAC for PreSync, PreSync Job (creates ConfigMap `cluster-configuration` with ingress subdomain).
2. **argocd/manifests/applications** — Child Argo CD Applications (couchbase-operator, couchbase-cluster, couchbase-monitoring, grafana-operator, grafana-server).

## Bootstrap

The app-of-apps uses project `couchbase-performance`, which is defined in cluster-objects. Create the project first, then the Application:

```bash
# 1. Create project (and RBAC, PreSync manifests)
kubectl apply -k argocd/manifests/cluster-objects

# 2. Create the app-of-apps Application
kubectl apply -f argocd/main/app-of-apps.yaml
```

After that, the app-of-apps will sync both sources: PreSync runs (creates **cluster-configuration**), then project and child Applications are applied.
