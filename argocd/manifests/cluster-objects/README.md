# Cluster objects (app-of-apps source 1)

Resources applied by the app-of-apps as its first source: project, RBAC, and PreSync hook.

- **project.yaml** — AppProject `couchbase-performance`.
- **rbac-cluster-config-hook.yaml** — ServiceAccount and RBAC for the PreSync Job.
- **sync-hook-cluster-config-pre.yaml** — PreSync Job: creates or patches ConfigMap **cluster-configuration** in `openshift-gitops`; sets **ingress-domain** (OpenShift default ingress domain). If the ConfigMap already exists, only `ingress-domain` is added/updated and other fields are preserved.

Apply as part of bootstrap: `kubectl apply -k argocd/manifests/cluster-objects` before creating the app-of-apps Application.
