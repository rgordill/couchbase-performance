# Performance Test Jobs

Kubernetes Jobs that run Couchbase performance tests using the [perftest container](../container) image (`quay.io/rgordill/couchbase-perftest:latest`). Jobs use **performance-user** and the **performance-user-password** Secret (key `password`).

## Prerequisites

- Couchbase cluster and `performance` bucket in the `couchbase` namespace.
- **CouchbaseUser** `performance-user` and **Secret** `performance-user-password` (from `argocd/manifests/couchbase/cluster/users.yaml`). The Secret must have key **`password`** (Couchbase Operator and the Jobs both use this key).

## If you see LCB_ERR_AUTHENTICATION_FAILURE (206)

1. **Server password must match the secret**  
   The Couchbase Operator sets the user password **only when the CouchbaseUser is first created**. If the secret was changed later, or the user was created when the secret had a different key/value, the password in Couchbase Server will not match. Fix: in Couchbase UI (Security → Users → performance-user) set the password to the same value as in the `performance-user-password` secret (e.g. `P3rf0rm@nce!`), or delete the CouchbaseUser and re-apply so the operator re-reads the secret.

2. **Secret has key `password`**  
   On OpenShift: `oc get secret performance-user-password -n couchbase -o jsonpath='{.data}'`. You should see `password`. If the key has another name, add a `password` key with the same value or change the Job to use your key.

3. **Performance user exists**  
   Ensure the CouchbaseUser and CouchbaseRoleBinding for `performance-user` are applied and the operator has created the user (check Couchbase UI or operator logs).

4. **RBAC**  
   The `rbac.yaml` in this directory grants the default service account permission to **get** the secret `performance-user-password`. Apply it with the Jobs (`kubectl apply -k performance/kubernetes`).

Each Job runs **cbc-pillowfight** directly with connection and profile-specific options (no wrapper scripts).

## Deploy

```bash
kubectl apply -k performance/kubernetes
# Or a single profile:
kubectl apply -f performance/kubernetes/perftest-mixed.yaml -n couchbase
```

## Logs

```bash
kubectl logs job/perftest-mixed -n couchbase -f
```

If the pod fails with authentication errors, check that the secret exists, has key `password`, and the server password for `performance-user` matches (see above).
