# Project Review Against Cursor Rules

This document summarizes the review of the couchbase-performance project against the Cursor rules (Kubernetes, Container, Couchbase, ArgoCD) and the fixes applied.

---

## 1. Kubernetes Rules (`.cursor/rules/kubernetes.mdc`)

### ✅ Compliant

| Rule | Status | Location |
|------|--------|----------|
| Use Ingress instead of Routes | ✅ | `argocd/manifests/couchbase/cluster/ingress.yaml` uses standard Ingress |
| OpenShift annotations for termination | ✅ | `route.openshift.io/termination: edge/passthrough` present |
| Nginx annotations commented out | ✅ | Commented with "uncomment if needed" |
| Docs and scripts prefer kubectl (Kubernetes CLI); oc only when OpenShift-specific | ✅ | .cursor/rules/kubernetes.mdc; deploy.sh, verify.sh, cleanup.sh |
| Makefile CLI detection | ✅ | Makefile uses $(CLI) for all targets |

### ⚠️ Fixed

| Issue | Fix |
|-------|-----|
| ArgoCD manifests hardcode `namespace: argocd` | deploy.sh now substitutes `ARGOCD_NAMESPACE` (openshift-gitops on OpenShift) in YAML before apply |

---

## 2. Container Rules (`.cursor/rules/container.mdc`)

### ✅ Compliant

| Rule | Status | Location |
|------|--------|----------|
| Use Containerfile (not Dockerfile) | ✅ | `performance/container/Containerfile` |
| UBI Minimal base | ✅ | `registry.access.redhat.com/ubi9/ubi-minimal:9.3` |
| Multi-stage build | ✅ | Builder + final stage |
| Non-root user (1001) | ✅ | `USER 1001` |
| Layer optimization (combined RUN, clean) | ✅ | microdnf clean all, rm -rf /var/cache/yum |
| .containerignore present | ✅ | `performance/container/.containerignore` |
| Labels for scanning | ✅ | name, version, summary, description, etc. |

### No issues found

---

## 3. Couchbase Rules (`.cursor/rules/couchbase.mdc`)

Reference: https://docs.couchbase.com/operator/current/prerequisite-and-setup.html

### ✅ Compliant

| Rule | Status | Location |
|------|--------|----------|
| Specific image versions (no latest) | ✅ | cluster.yaml uses 7.2.4, exporter 1.0.8 |
| Prometheus exporter with resources | ✅ | monitoring.prometheus with requests/limits |
| Resource requests (2 CPU min, memory) | ✅ | data: 2 CPU/4Gi, analytics: 1 CPU/2Gi |
| CSI storage (storageClassName) | ✅ | ocs-storagecluster-ceph-rbd (ODF) |
| Networking ClusterIP + Ingress | ✅ | adminConsoleServiceType: ClusterIP |
| Anti-affinity | ✅ | antiAffinity: true |

### ⚠️ Fixed

| Issue | Rule | Fix |
|-------|------|-----|
| Couchbase Server 7.2.4 | Recommended 7.6.x or 8.0.x | Bumped to `couchbase/server:7.6.8` in cluster.yaml |
| Backup CronJob image 1.3.0 | Use operator-backup:1.5.0+ | Updated to `couchbase/operator-backup:1.5.0` in backup.yaml |
| OLM Subscription installPlanApproval | Use Manual for production | Set to `Manual` with comment in subscription.yaml |

### 📋 Documented (no change)

| Item | Note |
|------|------|
| Kubernetes 1.33+ / OCP 4.20+ | Required by rules; documented in couchbase.mdc and README |
| Storage class `ocs-storagecluster-ceph-rbd` | OpenShift-specific; document in CONFIGURATION.md (already present) |

---

## 4. ArgoCD Rules (`.cursor/rules/argocd.mdc`)

### ✅ Compliant

| Rule | Status | Location |
|------|--------|----------|
| App of Apps pattern | ✅ | app-of-apps.yaml → applications/ |
| Sync waves | ✅ | operator=1, cluster=2, monitoring=3 |
| syncPolicy with prune, selfHeal | ✅ | All applications |
| syncOptions CreateNamespace | ✅ | operator, cluster apps |
| Retry with backoff | ✅ | All applications |
| Finalizers on Application | ✅ | resources-finalizer.argocd.argoproj.io |
| ignoreDifferences for controller-managed | ✅ | Deployment replicas, CouchbaseCluster size |

### ⚠️ Fixed

| Issue | Rule | Fix |
|-------|------|-----|
| Finalizer name | Rule shows `argocd.argoproj.io/finalizer` | Kept `resources-finalizer.argocd.argoproj.io` (valid for cascade delete) |
| ignoreDifferences for webhooks | Recommended for operator | Added to couchbase-operator-app.yaml for Mutating/ValidatingWebhookConfiguration caBundle |

### 📋 Note

- Rule suggests `argocd.argoproj.io/finalizer`; project uses `resources-finalizer.argocd.argoproj.io` for resource cleanup on app delete. Both are valid.

---

## 5. Summary of Fixes Applied

1. **deploy.sh**  
   - Before applying, substitute `namespace: argocd` with `namespace: ${ARGOCD_NAMESPACE}` in app-of-apps.yaml, applications/*.yaml, and applicationset.yaml so OpenShift uses `openshift-gitops`.

2. **argocd/manifests/couchbase/cluster/cluster.yaml**  
   - `image: couchbase/server:7.2.4` → `couchbase/server:7.6.8` (Couchbase compatibility rules).

3. **argocd/manifests/couchbase/cluster/backup.yaml**  
   - CronJob image `couchbase/operator-backup:1.3.0` → `couchbase/operator-backup:1.5.0`.

4. **argocd/manifests/couchbase/operator/subscription.yaml**  
   - `installPlanApproval: Automatic` → `installPlanApproval: Manual` with comment for production.

5. **argocd/applications/couchbase-operator-app.yaml**  
   - Added `ignoreDifferences` for MutatingWebhookConfiguration and ValidatingWebhookConfiguration `caBundle` (ArgoCD best practice).

---

## 6. Checklist for New Changes

When adding or changing manifests:

- [ ] **Kubernetes**: Prefer Ingress + `route.openshift.io/*` annotations; avoid new Route resources.
- [ ] **Kubernetes**: Scripts/Makefile use CLI detection (kubectl preferred).
- [ ] **Container**: Use Containerfile, UBI minimal/micro, non-root, explicit versions.
- [ ] **Couchbase**: Server 7.6+ or 8.0.x, explicit image tags, 2+ CPU and proper memory, CSI storage.
- [ ] **ArgoCD**: Sync waves, finalizers, ignoreDifferences for webhooks/status, retry/backoff.

---

## 7. References

- Kubernetes rules: `.cursor/rules/kubernetes.mdc`
- Container rules: `.cursor/rules/container.mdc`
- Couchbase rules: `.cursor/rules/couchbase.mdc`
- ArgoCD rules: `.cursor/rules/argocd.mdc`
- Couchbase prerequisites: https://docs.couchbase.com/operator/current/prerequisite-and-setup.html
