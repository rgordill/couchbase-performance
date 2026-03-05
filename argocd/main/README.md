# App-of-apps (bootstrap)

The app-of-apps Application has **two sources**:

1. **argocd/manifests/cluster-objects** — AppProject, RBAC for PreSync, PreSync Job (creates ConfigMap `cluster-configuration` with ingress subdomain).
2. **argocd/manifests/applications** — Child Argo CD Applications (couchbase-operator, couchbase-cluster, couchbase-monitoring, grafana-operator, grafana-server).

## Prerequisites

Before creating the app-of-apps Application, ensure the Argo CD Application Controller has permission to deploy the **CRDs and resources** from the operator manifests (Couchbase Operator, Grafana Operator). By default the controller’s cluster role is fixed; you must add permissions via **aggregated cluster roles** and a **user-defined ClusterRole**.

1. **Enable aggregated cluster roles** on your cluster-scoped Argo CD instance: set `spec.aggregatedClusterRoles: true` in the ArgoCD custom resource (see [Red Hat OpenShift GitOps — Enabling the creation of aggregated cluster roles](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.19/html/declarative_cluster_configuration/customizing-permissions-by-creating-aggregated-cluster-roles#gitops-enabling-the-creation-of-aggregated-cluster-roles_customizing-permissions-by-creating-aggregated-cluster-roles)).
2. **Create a user-defined ClusterRole** that grants the Application Controller the rights needed for the operator CRDs. Either run the script (recommended) or apply the manifest manually:

   ```bash
   # From repo root: run script (enables aggregated cluster roles and applies the ClusterRole)
   ./argocd/main/apply-prerequisites.sh

   # Or manually: enable aggregatedClusterRoles on the ArgoCD CR, then:
   kubectl apply -f argocd/main/argocd-application-controller-operator-permissions-clusterrole.yaml
   ```

   For a non-default Argo CD instance, set `ARGOCD_NAMESPACE` and `ARGOCD_NAME` before running the script (see `apply-prerequisites.sh`).

   That ClusterRole is labeled so it aggregates into the controller’s admin role (`argocd/aggregate-to-admin: 'true'`, plus `app.kubernetes.io/managed-by`, `app.kubernetes.io/name`, `app.kubernetes.io/part-of: argocd`). No ClusterRoleBinding is required—the OpenShift GitOps Operator manages the binding of the aggregated role to the Application Controller.

   Full procedure: [Creating user-defined cluster roles and configuring user-defined permissions for Application Controller](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.19/html/declarative_cluster_configuration/customizing-permissions-by-creating-aggregated-cluster-roles#gitops-creating-user-defined-cluster-roles-and-configuring-user-defined-permissions-for-application-controller_customizing-permissions-by-creating-aggregated-cluster-roles).

Without this, syncing the app-of-apps may fail when it tries to apply operator manifests that create or update CRDs.

## Bootstrap

The app-of-apps uses project `couchbase-performance`, which is defined in cluster-objects. Create the project first, then the Application:

```bash
# 1. Create project (and RBAC, PreSync manifests)
kubectl apply -k argocd/manifests/cluster-objects

# 2. Create the app-of-apps Application
kubectl apply -f argocd/main/app-of-apps.yaml
```

After that, the app-of-apps will sync both sources: PreSync runs (creates **cluster-configuration**), then project and child Applications are applied.
