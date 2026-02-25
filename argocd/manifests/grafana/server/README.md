# Grafana server

Grafana server instance and Ingress for the Couchbase performance project.

## Contents

- **ingress-domain.yaml** – ConfigMap (var) with `data.domain` and `data.host`. Default matches project cluster domain. PreSync populates this in the cluster from OpenShift (application PARAM). The kustomization uses it as replacement source to patch the Ingress host.
- **grafana.yaml** – `Grafana` CR (grafana.integreatly.org/v1beta1). The grafana-operator in the same namespace creates the Deployment and Service from this CR. The Service name is the CR name (`server`), port 3000.
- **ingress.yaml** – Ingress for the Grafana UI with edge TLS (cert-manager `lab-ca-issuer`). Host is set by **kustomization replacements** from ConfigMap `ingress-domain` (var); no post-hook.
- **sync-hook-domain-pre.yaml** – PreSync hook Job: gets default domain with `kubectl get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'`, stores it in ConfigMap `ingress-domain` (application PARAM). Image: `registry.k8s.io/kubectl:latest`. The kustomization that runs as part of the Argo CD deployment then uses that var to patch the Ingress.
- **rbac-domain-hook.yaml** – ServiceAccount and RBAC for the PreSync hook (read OpenShift ingress config, create/update ConfigMap). Applied each sync then removed by the PostSync hook so it does not persist.
- **rbac-cleanup.yaml** – Persistent RBAC for the PostSync cleanup Job (can delete the hook RBAC only). Not deleted by the post-hook.
- **sync-hook-cleanup-rbac-post.yaml** – PostSync hook Job: removes the extra `rbac-domain-hook` resources so they do not persist in the cluster. Image: `registry.k8s.io/kubectl:latest`.
- **kustomization.yaml** – Kustomize resources, namespace `couchbase`, and **replacements** from ConfigMap `ingress-domain` (data.host) to Ingress `grafana-server` (spec.rules.0.host, spec.tls.0.hosts.0).

## Dependencies

- **Grafana operator** must be deployed first (Application `grafana-operator`), in namespace `couchbase`.
- **cert-manager** with ClusterIssuer `lab-ca-issuer` for Ingress TLS.

## Deployment

- Via Argo CD: Application `grafana-server` (path `argocd/manifests/grafana/server`), or apply manually:

  ```bash
  kubectl apply -k argocd/manifests/grafana/server
  ```

## Default credentials

The Grafana CR sets `admin_user` / `admin_password` in config. For production, use an admin credentials Secret and reference it in the Grafana CR (see [grafana-operator docs](https://grafana.github.io/grafana-operator/docs/grafana/#admin-credentials-secret)).
