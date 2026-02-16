#!/usr/bin/env bash
#
# Operate on an Argo CD Application that uses a Helm chart with values from the
# local Git repo: template (default), install, or uninstall.
#
# Supports Application with spec.sources (two sources: chart + values from Git).
#
# Usage:
#   ./scripts/render-helm-app.sh [--template | --install | --uninstall] [APPLICATION_YAML] [-- HELM_ARGS...]
#
# Flags:
#   --template   Render manifests to stdout (default). Extra args passed to helm template.
#   --install    Install the chart into the cluster (helm install). Creates namespace if needed.
#   --uninstall  Remove the release (helm uninstall).
#
# Examples:
#   ./scripts/render-helm-app.sh --template
#   ./scripts/render-helm-app.sh --template argocd/applications/couchbase-operator-app.yaml > /tmp/rendered.yaml
#   ./scripts/render-helm-app.sh --install
#   ./scripts/render-helm-app.sh --uninstall
#
# Requires: helm, yq (https://github.com/mikefarah/yq)
# Note: helm will use/create its cache (e.g. ~/.cache/helm); run from a normal env.
#

set -euo pipefail

MODE=template
APPLICATION_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)  MODE=template ;;
    --install)   MODE=install ;;
    --uninstall) MODE=uninstall ;;
    --) shift; EXTRA_ARGS+=("$@"); break ;;
    -*) EXTRA_ARGS+=("$1") ;;
    *)  APPLICATION_FILE="$1" ;;
  esac
  shift
done

APPLICATION_FILE="${APPLICATION_FILE:-argocd/applications/couchbase-operator-app.yaml}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"

# Ensure we run from repo root so paths in the Application are resolved correctly
cd "$REPO_ROOT"

if [[ ! -f "$APPLICATION_FILE" ]]; then
  echo "ERROR: Application file not found: $APPLICATION_FILE" >&2
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required (https://github.com/mikefarah/yq). Install e.g. with: go install github.com/mikefarah/yq/v2@latest" >&2
  exit 1
fi

if ! command -v helm &>/dev/null; then
  echo "ERROR: helm is required." >&2
  exit 1
fi

# Detect if Application uses spec.sources (array) or spec.source (single)
if yq -e '.spec.sources' "$APPLICATION_FILE" >/dev/null 2>&1; then
  SOURCES_YAML=$(yq '.spec.sources' "$APPLICATION_FILE")
  SOURCE_COUNT=$(yq '.spec.sources | length' "$APPLICATION_FILE")
else
  echo "ERROR: Application must have spec.sources (array) with at least a Helm source and a values source." >&2
  exit 1
fi

# First source: Helm chart (has .chart)
HELM_INDEX=-1
VALUES_INDEX=-1
for (( i = 0; i < SOURCE_COUNT; i++ )); do
  if yq -e ".spec.sources[$i].chart" "$APPLICATION_FILE" >/dev/null 2>&1; then
    HELM_INDEX=$i
  fi
  if yq -e ".spec.sources[$i].path" "$APPLICATION_FILE" >/dev/null 2>&1 && \
     ( yq -e ".spec.sources[$i].valueFiles" "$APPLICATION_FILE" >/dev/null 2>&1 || yq -e ".spec.sources[$i].ref" "$APPLICATION_FILE" >/dev/null 2>&1 ); then
    VALUES_INDEX=$i
  fi
done

if [[ $HELM_INDEX -lt 0 ]]; then
  echo "ERROR: No Helm chart source found (no source with .chart)." >&2
  exit 1
fi

if [[ $VALUES_INDEX -lt 0 ]]; then
  echo "ERROR: No values source found (no source with .path and valueFiles or .ref)." >&2
  exit 1
fi

REPO_URL=$(yq -r ".spec.sources[$HELM_INDEX].repoURL" "$APPLICATION_FILE")
CHART_NAME=$(yq -r ".spec.sources[$HELM_INDEX].chart" "$APPLICATION_FILE")
# Argo CD Helm source may use .version or .targetRevision for chart version
CHART_VERSION=$(yq -r ".spec.sources[$HELM_INDEX].version // .spec.sources[$HELM_INDEX].targetRevision // \"\"" "$APPLICATION_FILE")
RELEASE_NAME=$(yq -r ".spec.sources[$HELM_INDEX].helm.releaseName // \"release\"" "$APPLICATION_FILE")
NAMESPACE=$(yq -r ".spec.destination.namespace // \"default\"" "$APPLICATION_FILE")

# Uninstall needs only release name and namespace
if [[ "$MODE" == "uninstall" ]]; then
  echo "Uninstalling release '$RELEASE_NAME' from namespace '$NAMESPACE'..." >&2
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" "${EXTRA_ARGS[@]}" 2>/dev/null || {
    echo "Release not found or already uninstalled." >&2
    exit 0
  }
  echo "Uninstall completed." >&2
  exit 0
fi

VALUES_PATH=$(yq -r ".spec.sources[$VALUES_INDEX].path" "$APPLICATION_FILE")
VALUE_FILES=$(yq -r ".spec.sources[$VALUES_INDEX].valueFiles[]?" "$APPLICATION_FILE" 2>/dev/null || true)
if [[ -z "${VALUE_FILES}" ]]; then
  VALUE_FILES="values.yaml"
fi

# First value file only for simplicity (multiple could be supported later)
FIRST_VALUE_FILE=$(echo "$VALUE_FILES" | head -1)
LOCAL_VALUES="${REPO_ROOT}/${VALUES_PATH}/${FIRST_VALUE_FILE}"

if [[ ! -f "$LOCAL_VALUES" ]]; then
  echo "ERROR: Values file not found: $LOCAL_VALUES" >&2
  exit 1
fi

# Helm repo name: use first component of host (e.g. couchbase-partners from couchbase-partners.github.io)
REPO_HOST=$(echo "$REPO_URL" | sed -E 's|https?://||' | sed -E 's|[/:].*||')
REPO_NAME=$(echo "$REPO_HOST" | cut -d. -f1 | tr -c 'a-zA-Z0-9-' '-' | cut -c1-32)
if [[ -z "$REPO_NAME" ]]; then
  REPO_NAME="helm-repo"
fi

echo "=============================================="
echo "Mode: $MODE | Chart: $REPO_NAME/$CHART_NAME @ ${CHART_VERSION:-<none>}"
echo "=============================================="
echo "Application:    $APPLICATION_FILE"
echo "Release name:   $RELEASE_NAME"
echo "Namespace:      $NAMESPACE"
echo "Values file:    $LOCAL_VALUES"
echo "=============================================="

helm repo add "$REPO_NAME" "$REPO_URL" --force-update 2>/dev/null || true
helm repo update "$REPO_NAME" 2>/dev/null || true

# If version is missing or template fails (e.g. version not found), show available versions and exit
show_available_versions() {
  echo "" >&2
  echo "Available versions for $REPO_NAME/$CHART_NAME:" >&2
  helm search repo "$REPO_NAME/$CHART_NAME" --versions 2>/dev/null || true
  echo "" >&2
  echo "Update version or targetRevision in $APPLICATION_FILE and re-run." >&2
}

if [[ -z "${CHART_VERSION:-}" ]]; then
  echo "ERROR: No chart version specified in Application (version or targetRevision)." >&2
  show_available_versions
  exit 1
fi

run_helm_template() {
  helm template "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" \
    --version "$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --values "$LOCAL_VALUES" \
    "${EXTRA_ARGS[@]}"
}

run_helm_install() {
  helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" \
    --version "$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$LOCAL_VALUES" \
    "${EXTRA_ARGS[@]}"
}

if [[ "$MODE" == "install" ]]; then
  if ! run_helm_install; then
    echo "ERROR: helm install failed (version '$CHART_VERSION' may not exist or cluster unreachable)." >&2
    show_available_versions
    exit 1
  fi
  echo ""
  echo "Install completed. Release '$RELEASE_NAME' is installed in namespace '$NAMESPACE'."
  exit 0
fi

# --template (default)
TMP_ERR=$(mktemp)
TMP_OUT=$(mktemp)
if ! run_helm_template >"$TMP_OUT" 2>"$TMP_ERR"; then
  echo "ERROR: Failed to render chart (version '$CHART_VERSION' may not exist)." >&2
  cat "$TMP_ERR" >&2
  rm -f "$TMP_ERR" "$TMP_OUT"
  show_available_versions
  exit 1
fi
cat "$TMP_OUT"
rm -f "$TMP_ERR" "$TMP_OUT"

echo ""
echo "Template completed successfully. Review the output above before committing."
