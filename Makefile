.PHONY: help deploy verify cleanup status sync logs test

# Default repository URL - override with: make deploy REPO_URL=https://...
REPO_URL ?= https://github.com/your-org/couchbase-performance.git
NAMESPACE ?= couchbase
OPERATOR_NAMESPACE ?= couchbase-operator

# Detect CLI (prefer kubectl)
CLI := $(shell command -v kubectl 2>/dev/null || command -v oc 2>/dev/null)

# Detect platform and set ArgoCD namespace accordingly
PLATFORM := $(shell $(CLI) get namespace openshift-monitoring >/dev/null 2>&1 && echo "openshift" || echo "kubernetes")
ifeq ($(PLATFORM),openshift)
    ARGOCD_NAMESPACE ?= openshift-gitops
else
    ARGOCD_NAMESPACE ?= argocd
endif

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Detected:'
	@echo '  CLI: $(CLI)'
	@echo '  Platform: $(PLATFORM)'
	@echo '  ArgoCD Namespace: $(ARGOCD_NAMESPACE)'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy Couchbase using ArgoCD
	@echo "Deploying Couchbase..."
	@cd argocd && REPO_URL=$(REPO_URL) ./deploy.sh

verify: ## Verify Couchbase deployment
	@echo "Verifying deployment..."
	@cd argocd && ./verify.sh

cleanup: ## Remove Couchbase deployment
	@echo "Cleaning up..."
	@cd argocd && ./cleanup.sh

deploy-manual: ## Deploy manifests manually (no ArgoCD)
	@cd argocd && ./deploy-manual.sh

deploy-dry-run: ## Dry-run: show what would be applied (client-side)
	@cd argocd && ./deploy-manual.sh --dry-run=client

deploy-dry-run-server: ## Dry-run: validate against server
	@cd argocd && ./deploy-manual.sh --dry-run=server

deploy-build-only: ## Validate kustomize build only (no cluster needed)
	@cd argocd && ./deploy-manual.sh --build-only

deploy-manual-remove: ## Remove objects deployed by deploy-manual (manual test teardown)
	@cd argocd && ./deploy-manual.sh --remove

status: ## Show status of all components
	@echo "=== ArgoCD Applications ==="
	@$(CLI) get applications -n $(ARGOCD_NAMESPACE) | grep couchbase || echo "No applications found"
	@echo ""
	@echo "=== Operator Status ==="
	@$(CLI) get pods -n $(OPERATOR_NAMESPACE) -l app=couchbase-operator || echo "Operator not found"
	@echo ""
	@echo "=== Cluster Status ==="
	@$(CLI) get couchbaseclusters -n $(NAMESPACE) || echo "No clusters found"
	@echo ""
	@echo "=== Pods ==="
	@$(CLI) get pods -n $(NAMESPACE) -l app=couchbase || echo "No pods found"
	@echo ""
	@echo "=== Buckets ==="
	@$(CLI) get couchbasebuckets -n $(NAMESPACE) || echo "No buckets found"
	@echo ""
	@echo "=== Monitoring ==="
	@$(CLI) get servicemonitor,podmonitor -n $(NAMESPACE) || echo "No monitors found"

sync: ## Force sync all ArgoCD applications
	@echo "Syncing applications..."
	@argocd app sync couchbase-root-app --force || echo "Failed to sync root app"
	@argocd app sync couchbase-operator --force || echo "Failed to sync operator"
	@argocd app sync couchbase-cluster --force || echo "Failed to sync cluster"
	@argocd app sync couchbase-monitoring --force || echo "Failed to sync monitoring"

logs-operator: ## Show operator logs
	@$(CLI) logs -n $(OPERATOR_NAMESPACE) -l app=couchbase-operator --tail=100 -f

logs-cluster: ## Show cluster logs
	@$(CLI) logs -n $(NAMESPACE) -l app=couchbase --tail=100 -f

ui: ## Get Couchbase Web UI URL
	@echo "Couchbase Web UI:"
	@$(CLI) get ingress couchbase-admin-ui -n $(NAMESPACE) -o jsonpath='https://{.spec.rules[0].host}{"\n"}' 2>/dev/null || \
		$(CLI) get route couchbase-admin-ui -n $(NAMESPACE) -o jsonpath='https://{.spec.host}{"\n"}' 2>/dev/null || \
		echo "Ingress/Route not found"
	@echo ""
	@echo "Default credentials (CHANGE IN PRODUCTION!):"
	@echo "  Username: Administrator"
	@echo "  Password: P@ssw0rd123!"

metrics: ## Show sample metrics
	@echo "Querying Prometheus metrics..."
	@$(CLI) exec -n $(NAMESPACE) $$($(CLI) get pods -n $(NAMESPACE) -l app=couchbase -o jsonpath='{.items[0].metadata.name}') -- \
		curl -s localhost:9102/metrics | grep "couchbase_bucket_ops_total" | head -10

test-connection: ## Test connection to Couchbase
	@echo "Testing Couchbase connection..."
	@$(CLI) run test-connection --rm -it --restart=Never \
		--image=couchbase:community-7.2.4 \
		--namespace=$(NAMESPACE) \
		-- /opt/couchbase/bin/cbc ping \
		-U couchbase://couchbase-cluster/performance \
		-u Administrator \
		-P P@ssw0rd123!

load-test: ## Run a simple load test
	@echo "Running load test..."
	@$(CLI) exec -it -n $(NAMESPACE) $$($(CLI) get pods -n $(NAMESPACE) -l app=couchbase -o jsonpath='{.items[0].metadata.name}') -- \
		cbc-pillowfight \
		-U couchbase://localhost/performance \
		-u performance-user \
		-P P3rf0rm@nce! \
		--num-items 10000 \
		--num-threads 4

port-forward: ## Port forward to Couchbase Web UI (localhost:8091)
	@echo "Port forwarding to Couchbase Web UI..."
	@echo "Access at: http://localhost:8091"
	@$(CLI) port-forward -n $(NAMESPACE) $$($(CLI) get pods -n $(NAMESPACE) -l app=couchbase -o jsonpath='{.items[0].metadata.name}') 8091:8091

backup-now: ## Trigger manual backup
	@echo "Triggering manual backup..."
	@$(CLI) create -f - <<< "apiVersion: couchbase.com/v2\nkind: CouchbaseBackupRestore\nmetadata:\n  name: manual-backup-$$(date +%Y%m%d-%H%M%S)\n  namespace: $(NAMESPACE)\nspec:\n  backup: couchbase-backup-plan\n  action: backup"

describe-cluster: ## Show detailed cluster information
	@$(CLI) describe couchbasecluster -n $(NAMESPACE)

get-events: ## Show recent events
	@$(CLI) get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

watch-pods: ## Watch pod status
	@watch -n 2 '$(CLI) get pods -n $(NAMESPACE) -l app=couchbase'

argocd-ui: ## Get ArgoCD UI URL
	@echo "ArgoCD UI:"
	@$(CLI) get ingress argocd-server -n $(ARGOCD_NAMESPACE) -o jsonpath='https://{.spec.rules[0].host}{"\n"}' 2>/dev/null || \
		$(CLI) get route argocd-server -n $(ARGOCD_NAMESPACE) -o jsonpath='https://{.spec.host}{"\n"}' 2>/dev/null || \
		echo "ArgoCD ingress/route not found"

.DEFAULT_GOAL := help
