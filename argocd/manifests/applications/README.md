# Applications (app-of-apps source 2)

Child Argo CD Application manifests applied by the app-of-apps as its second source.

- couchbase-operator-app.yaml
- couchbase-cluster-app.yaml
- couchbase-monitoring-app.yaml
- grafana-operator-app.yaml
- grafana-server-app.yaml

Each Application references manifests under `argocd/manifests/` (couchbase, grafana).
