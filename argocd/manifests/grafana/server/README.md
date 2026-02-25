# Grafana server

Grafana server instance and Ingress for the Couchbase performance project.

## Contents

- **rbac-sync-hook.yaml** – ServiceAccount and RBAC for PreSync/PostSync hooks (read OpenShift ingress, ConfigMap, patch Ingress in couchbase).
- **sync-hook-presync.yaml** – PreSync Job: ensures ConfigMap `cluster-configuration` in couchbase has `ingress-domain` and `grafana-host` (from OpenShift) **before** the main sync applies resources.
- **sync-hook-postsync.yaml** – PostSync Job: patches Ingress `grafana-server` with the host from `cluster-configuration` (effectively substitutes `PLACEHOLDER_SUBDOMAIN` after kustomize build).
- **grafana.yaml** – `Grafana` CR (grafana.integreatly.org/v1beta1). The grafana-operator creates the Deployment and Service; service name `server`, port 3000.
- **ingress.yaml** – Ingress for the Grafana UI (edge TLS, cert-manager `lab-ca-issuer`). Host is `grafana-couchbase.PLACEHOLDER_SUBDOMAIN` in repo; PostSync sets the real host (e.g. `grafana-couchbase.apps.ocp.sa-iberia.lab.eng.brq2.redhat.com`).
- **kustomization.yaml** – Resources (hooks, Grafana CR, Ingress).

## Dependencies

- **Grafana operator** deployed first (Application `grafana-operator`), in namespace `couchbase`.
- **cert-manager** with ClusterIssuer `lab-ca-issuer` for Ingress TLS.

## Deployment

Via Argo CD: Application `grafana-server` (path `argocd/manifests/grafana/server`). Or apply manually: `kubectl apply -k argocd/manifests/grafana/server`.

## Default credentials

The Grafana CR sets `admin_user` / `admin_password` in config. For production, use an admin credentials Secret (see [grafana-operator docs](https://grafana.github.io/grafana-operator/docs/grafana/#admin-credentials-secret)).
