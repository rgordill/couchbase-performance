# Couchbase cluster manifests

- **base/**: Shared cluster resources (CouchbaseCluster, buckets, users, ingress). Namespace in base is `couchbase`.
- **Root** (`kustomization.yaml`): Default build for the static `couchbase-cluster` application; uses base with namespace `couchbase`.
- **overlays/{{environment}}**: Per-environment overlay. Sets namespace (e.g. `couchbase-dev`, `couchbase-prod`) and optional labels. Used by the ApplicationSet `couchbase-environments` with path `argocd/manifests/couchbase/cluster/overlays/{{environment}}`.

The static application deploys from path `argocd/manifests/couchbase/cluster` (default namespace `couchbase`). The ApplicationSet generates `couchbase-cluster-dev`, `couchbase-cluster-prod`, etc., from the overlays.
