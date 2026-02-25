# Applications (app-of-apps source 2)

Child Argo CD Application manifests and ApplicationSet applied by the app-of-apps as its second source.

- couchbase-operator-app.yaml
- couchbase-cluster-app.yaml
- couchbase-monitoring-app.yaml
- grafana-operator-app.yaml
- **grafana-server-appset.yaml** — ApplicationSet that generates one Application for the in-cluster (secret label `grafana-server-cluster: "true"`). PostSync in grafana/server patches Ingress host to **grafana-server.<subdomain>** from that secret.

Each Application references manifests under `argocd/manifests/` (couchbase, grafana).
