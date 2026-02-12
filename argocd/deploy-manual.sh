#!/bin/bash
#
# Deploy Couchbase manifests manually (same as ArgoCD would apply).
# Use for testing manifests without ArgoCD.
#
# Usage:
#   ./deploy-manual.sh                    # Apply for real
#   ./deploy-manual.sh --dry-run          # Dry run (build + client apply)
#   ./deploy-manual.sh --dry-run=client   # Client-side dry run (needs cluster for CRDs)
#   ./deploy-manual.sh --build-only      # Only validate kustomize build (no cluster needed)
#   ./deploy-manual.sh --remove          # Remove objects deployed by manual deploy
#   ./deploy-manual.sh --dry-run=server  # Server-side dry run
#   ./deploy-manual.sh -n                # Same as --dry-run=server
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"
DRY_RUN=""
DRY_RUN_FLAG=""
BUILD_ONLY=""
REMOVE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="client"
            DRY_RUN_FLAG="--dry-run=client"
            shift
            ;;
        --dry-run=*)
            DRY_RUN="${1#*=}"
            DRY_RUN_FLAG="--dry-run=${DRY_RUN}"
            shift
            ;;
        --build-only)
            BUILD_ONLY=1
            shift
            ;;
        --remove)
            REMOVE=1
            shift
            ;;
        -n)
            DRY_RUN="server"
            DRY_RUN_FLAG="--dry-run=server"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Deploy Couchbase manifests manually in the same order as ArgoCD."
            echo ""
            echo "Options:"
            echo "  --dry-run           Client-side dry run (show what would be applied)"
            echo "  --dry-run=client    Client-side dry run (may need cluster for CRDs)"
            echo "  --dry-run=server    Server-side dry run (validate against server; CRDs must exist for cluster resources)"
            echo "  --build-only        Only run kustomize build (no cluster needed)"
            echo "  --remove            Remove objects deployed by manual deploy (reverse order)"
            echo "  -n                  Same as --dry-run=server"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --build-only     # Validate manifests, no cluster"
            echo "  $0 --dry-run        # Preview (cluster optional for CRDs)"
            echo "  $0 --dry-run=server # Validate against API server"
            echo "  $0                  # Apply for real"
            echo "  $0 --remove         # Remove manually deployed objects"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Detect CLI (prefer kubectl)
if command -v kubectl &> /dev/null; then
    CLI="kubectl"
elif command -v oc &> /dev/null; then
    CLI="oc"
else
    echo "ERROR: kubectl or oc required"
    exit 1
fi

# Check kustomize is available
if ! $CLI kustomize version &> /dev/null && ! command -v kustomize &> /dev/null; then
    echo "ERROR: kustomize required (kubectl kustomize or kustomize)"
    exit 1
fi

# Helm is used for the Couchbase operator (not OLM)
HELM_RELEASE_NAME="couchbase-operator"
HELM_CHART_REPO="https://couchbase-partners.github.io/helm-charts/"
HELM_CHART_NAME="couchbase/couchbase-operator"
HELM_VALUES="${SCRIPT_DIR}/helm/openshift-values.yaml"
if [ -z "$BUILD_ONLY" ] && [ -z "$DRY_RUN" ] && [ -z "$REMOVE" ]; then
    if ! command -v helm &>/dev/null; then
        echo "ERROR: helm required for operator install (https://docs.couchbase.com/operator/current/helm-setup-guide.html)" >&2
        exit 1
    fi
fi

# Use kubectl kustomize or standalone kustomize
if $CLI kustomize version &>/dev/null; then
    KUSTOMIZE_CMD() { $CLI kustomize "$1"; }
else
    KUSTOMIZE_CMD() { kustomize build "$1"; }
fi

# Mutual exclusion for options
if [ -n "$REMOVE" ] && { [ -n "$BUILD_ONLY" ] || [ -n "$DRY_RUN" ]; }; then
    echo "ERROR: --remove cannot be combined with --build-only or --dry-run" >&2
    exit 1
fi

echo "=============================================="
echo "Couchbase Manual Deploy"
echo "=============================================="
echo "CLI:        ${CLI}"
echo "Manifests:  ${MANIFESTS_DIR}"
if [ -n "$REMOVE" ]; then
    echo "Mode:       REMOVE (undeploy)"
    echo "=============================================="
    echo ""
elif [ -n "$BUILD_ONLY" ]; then
    echo "Mode:       BUILD ONLY (no cluster)"
    echo "=============================================="
    echo ""
elif [ -n "$DRY_RUN" ]; then
    echo "Mode:       DRY RUN (${DRY_RUN})"
    echo "=============================================="
    echo ""
else
    echo "Mode:       APPLY"
    echo "=============================================="
    echo ""
fi

build_dir() {
    local dir="$1"
    local name="$2"
    if [ ! -d "$dir" ]; then
        echo "Skip: $name (directory not found: $dir)"
        return 0
    fi
    if [ ! -f "$dir/kustomization.yaml" ]; then
        echo "Skip: $name (no kustomization.yaml)"
        return 0
    fi
    echo ">>> $name"
    if ! KUSTOMIZE_CMD "$dir" > /dev/null 2>&1; then
        KUSTOMIZE_CMD "$dir" 2>&1
        return 1
    fi
    local count
    count=$(KUSTOMIZE_CMD "$dir" 2>/dev/null | grep -c '^---' || true)
    echo "    Built successfully ($((count + 1)) resources)"
    echo ""
    return 0
}

apply_dir() {
    local dir="$1"
    local name="$2"
    if [ ! -d "$dir" ]; then
        echo "Skip: $name (directory not found: $dir)"
        return 0
    fi
    if [ ! -f "$dir/kustomization.yaml" ]; then
        echo "Skip: $name (no kustomization.yaml)"
        return 0
    fi
    echo ">>> $name"
    if [ -n "$BUILD_ONLY" ]; then
        build_dir "$dir" "$name"
        return $?
    fi
    if [ -n "$DRY_RUN_FLAG" ]; then
        KUSTOMIZE_CMD "$dir" 2>/dev/null | $CLI apply -f - $DRY_RUN_FLAG --validate=false 2>&1 || true
    else
        KUSTOMIZE_CMD "$dir" 2>/dev/null | $CLI apply -f - --validate=false
    fi
    echo ""
}

remove_dir() {
    local dir="$1"
    local name="$2"
    if [ ! -d "$dir" ]; then
        echo "Skip: $name (directory not found: $dir)"
        return 0
    fi
    if [ ! -f "$dir/kustomization.yaml" ]; then
        echo "Skip: $name (no kustomization.yaml)"
        return 0
    fi
    echo ">>> $name"
    KUSTOMIZE_CMD "$dir" 2>/dev/null | $CLI delete -f - --ignore-not-found --wait=false 2>&1 || true
    echo ""
}

# Order: operator (Helm) -> cluster (manifests) -> monitoring (manifests)
# Remove in reverse: monitoring -> cluster -> operator (Helm uninstall) -> operator namespace
if [ -n "$REMOVE" ]; then
    echo "Removing manually deployed objects (reverse order)..."
    echo ""
    remove_dir "${MANIFESTS_DIR}/monitoring" "3/3 Monitoring (ServiceMonitor, PodMonitor, ...)"
    remove_dir "${MANIFESTS_DIR}/cluster"    "2/3 Cluster (namespace, cluster, buckets, users, ...)"
    echo ">>> 1/3 Operator (Helm uninstall)"
    helm uninstall "${HELM_RELEASE_NAME}" -n couchbase-operator --wait 2>/dev/null || true
    echo ""
    remove_dir "${MANIFESTS_DIR}/operator"   "Namespace (couchbase-operator)"
elif [ -n "$BUILD_ONLY" ]; then
    echo "Validating kustomize build only (no cluster required)..."
    echo ""
    build_dir "${MANIFESTS_DIR}/operator"   "1/3 Operator namespace only (operator installed via Helm)"
    build_dir "${MANIFESTS_DIR}/cluster"   "2/3 Cluster (namespace, cluster, buckets, users, ...)" || exit 1
    build_dir "${MANIFESTS_DIR}/monitoring" "3/3 Monitoring (ServiceMonitor, PodMonitor, ...)" || exit 1
else
    # 1) Namespace
    apply_dir "${MANIFESTS_DIR}/operator" "1/3 Operator namespace"
    # 2) Helm install Couchbase operator + admission controller (https://docs.couchbase.com/operator/current/helm-setup-guide.html)
    if [ -z "$DRY_RUN_FLAG" ]; then
        echo ">>> 2/3 Operator (Helm: couchbase-operator chart)"
        if [ ! -f "$HELM_VALUES" ]; then
            echo "ERROR: Helm values not found: $HELM_VALUES" >&2
            exit 1
        fi
        # Use workspace Helm cache when default cache is not writable (e.g. in CI/sandbox)
        HELM_CACHE_DIR="${SCRIPT_DIR}/.helm"
        export HELM_CACHE_HOME="${HELM_CACHE_DIR}/cache"
        export HELM_REPOSITORY_CACHE="${HELM_CACHE_DIR}/repository"
        mkdir -p "$HELM_CACHE_HOME" "$HELM_REPOSITORY_CACHE" 2>/dev/null || true
        helm repo add couchbase "${HELM_CHART_REPO}" 2>/dev/null || true
        helm repo update couchbase 2>/dev/null || true
        helm upgrade --install "${HELM_RELEASE_NAME}" "${HELM_CHART_NAME}" \
            -f "$HELM_VALUES" \
            -n couchbase-operator \
            --create-namespace \
            --wait --timeout 5m 2>&1
        echo ""
    else
        echo ">>> 2/3 Operator (Helm) - skipped in dry run"
        echo ""
    fi

    # Wait for Couchbase CRDs before applying cluster resources
    if [ -z "$DRY_RUN_FLAG" ]; then
        echo "Waiting for Couchbase CRDs..."
        CRDS_READY=""
        for i in $(seq 1 30); do
            if $CLI get crd couchbaseclusters.couchbase.com &>/dev/null; then
                if $CLI wait --for=condition=established crd/couchbaseclusters.couchbase.com --timeout=60s 2>/dev/null; then
                    CRDS_READY=1
                    break
                fi
            fi
            echo "    Attempt $i/30: CRDs not ready, waiting 10s..."
            sleep 10
        done
        if [ -z "$CRDS_READY" ]; then
            echo "ERROR: Couchbase CRDs not established. Check operator pods: $CLI get pods -n couchbase-operator"
            exit 1
        fi
        echo "    Couchbase CRDs ready."
        echo ""
    else
        if ! $CLI get crd couchbaseclusters.couchbase.com &>/dev/null; then
            echo "Note: Couchbase CRDs not installed; cluster apply may show 'resource mapping not found' (expected)."
            echo ""
        fi
    fi

    apply_dir "${MANIFESTS_DIR}/cluster"    "3/3 Cluster (namespace, cluster, buckets, users, ...)"
    apply_dir "${MANIFESTS_DIR}/monitoring" "Monitoring (ServiceMonitor, PodMonitor, ...)"
fi

if [ -n "$REMOVE" ]; then
    echo "=============================================="
    echo "Remove complete. Manually deployed objects deleted."
    echo "Namespaces couchbase and couchbase-operator may remain if not empty."
    echo "=============================================="
elif [ -n "$BUILD_ONLY" ]; then
    echo "=============================================="
    echo "Build validation complete. All kustomizations OK."
    echo "Run without --build-only to apply (or use --dry-run with cluster)."
    echo "=============================================="
elif [ -n "$DRY_RUN" ]; then
    echo "=============================================="
    echo "Dry run complete. No changes applied."
    echo "Run without --dry-run to apply."
    echo "=============================================="
else
    echo "=============================================="
    echo "Manual deploy complete."
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "  $CLI get pods -n couchbase-operator"
    echo "  $CLI get pods -n couchbase"
    echo "  $CLI get couchbasecluster -n couchbase"
    echo ""
fi
