# Cluster objects (app-of-apps source 1)

Resources applied by the app-of-apps as its first source: project, RBAC, and PreSync hook.

- **project.yaml** — AppProject `couchbase-performance`.
- **rbac-cluster-config-hook.yaml** — ServiceAccount and RBAC for the PreSync Job.
- **sync-hook-cluster-config-pre.yaml** — PreSync Job: creates or patches Argo CD cluster Secret **cluster-couchbase-in-cluster** in `openshift-gitops` with **name** (couchbase-in-cluster), **server** (https://kubernetes.default.svc), and **ingress-domain** (OpenShift subdomain). Label `grafana-server-cluster: "true"` so the ApplicationSet generates one Application; grafana-server PostSync reads this Secret to set Ingress host to **grafana-server.<subdomain>**.

Apply as part of bootstrap: `kubectl apply -k argocd/manifests/cluster-objects` before creating the app-of-apps Application.
