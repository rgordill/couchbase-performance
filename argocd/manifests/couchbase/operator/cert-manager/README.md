# Admission controller Certificate (cert-manager)

The Certificate for the Couchbase admission controller webhook is built with Kustomize. The **ClusterIssuer** (`issuerRef.name`) is set via a replacement from a ConfigMap; the default is `lab-ca-issuer`.

- **base/**: Certificate manifest with placeholder `issuerRef.name`.
- **Root** (`kustomization.yaml`): Single default build using `lab-ca-issuer`.

## Argo CD path

The operator Application uses:

`argocd/manifests/couchbase/operator/cert-manager`

No overlays are used by default.

## Extending to other clusters or issuers

If you need a different ClusterIssuer (e.g. another cluster or environment), you can:

1. **Override the default in this kustomization**  
   Edit `kustomization.yaml` and change the `configMapGenerator` literal to your issuer name, e.g. `cluster-issuer=prod-ca-issuer`.

2. **Add overlays for multiple environments**  
   Create `overlays/<env>/kustomization.yaml` that references `../../base`, defines its own `configMapGenerator` with `cluster-issuer=<issuer-name>`, and the same `replacements` block as the root. Point the operator (or an ApplicationSet) at `argocd/manifests/couchbase/operator/cert-manager/overlays/<env>` when deploying that environment.

3. **Fork or duplicate for a separate cluster**  
   Copy this directory (base + kustomization.yaml) elsewhere and set the ConfigMap literal to the ClusterIssuer used in that cluster.
