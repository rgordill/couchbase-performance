# Applications (app-of-apps source 2)

Child Argo CD Application manifests and ApplicationSets applied by the app-of-apps as its second source.

- **couchbase-cluster-appset.yaml** — ApplicationSet for the in-cluster; kustomize patches set Ingress host to **couchbase-admin.<ingress-domain>** from cluster secret annotation.
- couchbase-monitoring-app.yaml
- couchbase-operator-app.yaml
- grafana-operator-app.yaml
- **grafana-server-appset.yaml** — ApplicationSet for the in-cluster; kustomize patches set Ingress host to **grafana-server.<ingress-domain>** from cluster secret annotation.

Each Application references manifests under `argocd/manifests/` (couchbase, grafana). Ingress hosts are injected via ApplicationSet `source.kustomize.patches` using the cluster secret annotation `ingress-domain` (see `.cursor/rules/argocd.mdc`).
