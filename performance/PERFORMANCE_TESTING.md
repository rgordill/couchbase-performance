# Couchbase Performance Testing

This directory contains Kubernetes Jobs and documentation for running Couchbase performance tests with **cbc-pillowfight**. Benchmarks run in the cluster using the perftest container image; no wrapper scripts are used.

## Running Benchmarks (Kubernetes Jobs)

Benchmarks are defined as Kubernetes Jobs in `performance/kubernetes/`. Each Job runs **cbc-pillowfight** with connection and profile-specific options. Credentials come from the **performance-user** CouchbaseUser and the **performance-user-password** Secret (key `password`).

### Prerequisites

- Couchbase cluster and `performance` bucket in the `couchbase` namespace.
- **CouchbaseUser** `performance-user` and **Secret** `performance-user-password` (see `argocd/manifests/couchbase/cluster/users.yaml`). The Secret must have key **`password`**.

See `performance/kubernetes/README.md` for authentication troubleshooting (e.g. LCB_ERR_AUTHENTICATION_FAILURE).

### Deploy and run

```bash
# Run all Job manifests (each creates one Job)
kubectl apply -k performance/kubernetes

# Or run a single profile
kubectl apply -f performance/kubernetes/perftest-mixed.yaml -n couchbase
kubectl apply -f performance/kubernetes/perftest-read-heavy.yaml -n couchbase
kubectl apply -f performance/kubernetes/perftest-write-heavy.yaml -n couchbase
kubectl apply -f performance/kubernetes/perftest-stress.yaml -n couchbase
kubectl apply -f performance/kubernetes/perftest-small-documents.yaml -n couchbase
kubectl apply -f performance/kubernetes/perftest-large-documents.yaml -n couchbase
```

### View logs

```bash
kubectl logs job/perftest-mixed -n couchbase -f
```

Jobs use `ttlSecondsAfterFinished: 86400` (24h) so completed/failed Jobs are cleaned up automatically. To re-run a profile, delete the Job first: `kubectl delete job perftest-mixed -n couchbase`.

## cbc-pillowfight command lines (per profile)

Connection is via env vars: `CB_HOST`, `CB_BUCKET`, `CB_USER`, `CB_PASSWORD` (password from Secret `performance-user-password`, key `password`). The equivalent command lines are below.

### Read-heavy (10% writes, 90% reads)

```bash
cbc-pillowfight \
  -U "couchbase://$(CB_HOST)/$(CB_BUCKET)" \
  -u "$(CB_USER)" \
  -P "$(CB_PASSWORD)" \
  --batch-size 1 \
  --num-cycles 100000 \
  --num-items 100000 \
  --num-threads 1 \
  --min-size 1024 \
  --max-size 1024 \
  --set-pct 10 \
  --timings \
  --json
```

### Write-heavy (90% writes, 10% reads)

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --num-items 100000 \
  --num-threads 8 \
  --min-size 512 \
  --max-size 8192 \
  --set-pct 90 \
  --json
```

### Mixed (50% writes, 50% reads)

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --num-items 100000 \
  --num-threads 8 \
  --min-size 1024 \
  --max-size 4096 \
  --set-pct 50 \
  --json
```

### Stress (high concurrency: 32 threads, 1M ops)

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --num-items 1000000 \
  --num-threads 32 \
  --min-size 1024 \
  --max-size 4096 \
  --set-pct 50 \
  --json
```

### Small documents (256–512 bytes)

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --num-items 200000 \
  --num-threads 8 \
  --min-size 256 \
  --max-size 512 \
  --set-pct 50 \
  --json
```

### Large documents (10–50 KB)

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --num-items 10000 \
  --num-threads 4 \
  --min-size 10240 \
  --max-size 51200 \
  --set-pct 50 \
  --json
```

Typical env values in the Jobs: `CB_HOST=couchbase-cluster`, `CB_BUCKET=performance`, `CB_USER=performance-user`; `CB_PASSWORD` from Secret.

## Running cbc-pillowfight manually (e.g. inside a cluster pod)

From a pod that can reach the Couchbase service (e.g. for quick ad-hoc tests):

```bash
# Read-heavy
cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P '<password-from-secret>' \
  --num-items 100000 \
  --num-threads 8 \
  --set-pct 10 \
  --min-size 1024 \
  --max-size 4096 \
  --json

# Write-heavy
cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P '<password-from-secret>' \
  --num-items 100000 \
  --num-threads 8 \
  --set-pct 90 \
  --min-size 512 \
  --max-size 8192 \
  --json

# Mixed
cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P '<password-from-secret>' \
  --num-items 100000 \
  --num-threads 8 \
  --set-pct 30 \
  --get-pct 70 \
  --min-size 1024 \
  --max-size 4096 \
  --json
```

## Timings and histograms

**cbc-pillowfight** can report latency distributions via the **`--timings`** option. This dumps a **histogram of command timings** (latencies) so you can see how long operations take and spot tail latencies.

### What you get

- **Histogram**: Bucketed counts of operation latencies (e.g. how many ops fell in 0–1 ms, 1–2 ms, etc.).
- **When**: Depending on the build, timings can be printed periodically (e.g. every second) and/or **at the end of the run**.
- **Output**: Printed to the process output (stdout/stderr). In Kubernetes Jobs, this appears in **pod logs**.

### Enabling timings

Add **`--timings`** to the cbc-pillowfight command. You can combine it with **`--json`** (JSON summary and timings histogram both appear in the logs).

**Second `--timings` option (histograms per second):** In some builds, passing **`--timings` twice** enables a **per-second** timing dump: a histogram is printed every second during the run, not only at the end. That lets you watch latency evolution over time (e.g. warm-up, spikes, degradation). Check your cbc-pillowfight version if you rely on per-second output.

Example (read-heavy with timings):

```bash
cbc-pillowfight \
  -U "couchbase://${CB_HOST}/${CB_BUCKET}" \
  -u "${CB_USER}" \
  -P "${CB_PASSWORD}" \
  --batch-size 1 \
  --num-cycles 100000 \
  --num-items 100000 \
  --num-threads 1 \
  --min-size 1024 \
  --max-size 1024 \
  --set-pct 10 \
  --timings \
  --timings \
  --json
```

The **read-heavy** Job in `performance/kubernetes/perftest-read-heavy.yaml` uses `--timings` twice for per-second histograms; other profiles can add one or two `--timings` as needed.

### Viewing timings in Kubernetes

```bash
kubectl logs job/perftest-read-heavy -n couchbase
```

Look for the histogram block in the log output (often at the end). It shows latency buckets and counts, so you can derive p50/p95/p99-style metrics or compare runs.

### Live dump (interactive runs)

When running cbc-pillowfight interactively (e.g. in a local container or `kubectl run ... -it`), sending **SIGQUIT** (Ctrl+\ on many terminals) can trigger an immediate dump of timing diagnostics to stderr, without waiting for the run to finish. This is useful for ad-hoc latency inspection during a long test.

## Using YCSB (optional)

YCSB can be used as an alternative workload generator:

```bash
# Load data
kubectl run ycsb-load --rm -it --restart=Never \
  --image=pingcap/go-ycsb \
  --namespace=couchbase \
  -- load couchbase \
  -P workloads/workloada \
  -p couchbase.url=couchbase://couchbase-cluster \
  -p couchbase.bucket=performance \
  -p couchbase.username=performance-user \
  -p couchbase.password=<password> \
  -p recordcount=1000000

# Run workload
kubectl run ycsb-run --rm -it --restart=Never \
  --image=pingcap/go-ycsb \
  --namespace=couchbase \
  -- run couchbase \
  -P workloads/workloada \
  -p couchbase.url=couchbase://couchbase-cluster \
  -p couchbase.bucket=performance \
  -p couchbase.username=performance-user \
  -p couchbase.password=<password> \
  -p operationcount=1000000
```

## Performance monitoring during tests

### Watch metrics (cluster CLI)

```bash
# Operations per second (replace credentials if different)
watch -n 1 'kubectl exec -n couchbase couchbase-cluster-0000 -- \
  couchbase-cli bucket-stats -c localhost \
  -u Administrator -p <admin-password> \
  --bucket performance | grep ops'

# Server info
watch -n 5 'kubectl exec -n couchbase couchbase-cluster-0000 -- \
  couchbase-cli server-info -c localhost \
  -u Administrator -p <admin-password>'
```

### Prometheus

If Prometheus is installed (e.g. OpenShift user-workload monitoring):

```bash
# Example: query operations rate
kubectl exec -n openshift-user-workload-monitoring prometheus-user-workload-0 -- \
  promtool query instant \
  'http://localhost:9090' \
  'rate(couchbase_bucket_ops_total[5m])'
```

Grafana dashboards can be wired to the same Prometheus metrics (see `argocd/manifests/grafana/`).

## Benchmark results format

Capture JSON output from cbc-pillowfight (Jobs use `--json`). For latency distribution details, use **`--timings`** as well (see [Timings and histograms](#timings-and-histograms)). Results can be stored in a consistent shape for comparison:

```json
{
  "test_name": "write-heavy-1m-docs",
  "timestamp": "2024-02-12T10:00:00Z",
  "duration_seconds": 300,
  "operations": {
    "total": 1000000,
    "write": 900000,
    "read": 100000
  },
  "throughput": {
    "ops_per_second": 3333,
    "writes_per_second": 3000,
    "reads_per_second": 333
  },
  "latency": {
    "p50_ms": 2.5,
    "p95_ms": 15.0,
    "p99_ms": 45.0
  },
  "resources": {
    "cpu_avg_percent": 45,
    "memory_avg_gb": 6.2,
    "disk_io_mb_per_sec": 150
  }
}
```

## Best practices

1. **Warm-up**: Allow a short warm-up before measuring (e.g. run a lighter load first).
2. **Multiple runs**: Run each profile several times and average or compare results.
3. **Isolate tests**: Run performance tests in a dedicated namespace or cluster when possible.
4. **Document configuration**: Record cluster size, bucket settings, and Job parameters for each run.
5. **Monitor resources**: Watch CPU, memory, disk, and network during tests (Prometheus/Grafana or CLI).
6. **Baseline**: Establish a baseline and compare subsequent runs against it.

## Example workflow

```bash
# 1. Ensure Couchbase cluster and performance bucket are ready
kubectl get couchbasecluster -n couchbase
kubectl get secret performance-user-password -n couchbase

# 2. Run a benchmark (e.g. mixed)
kubectl apply -f performance/kubernetes/perftest-mixed.yaml -n couchbase

# 3. Follow logs
kubectl logs job/perftest-mixed -n couchbase -f

# 4. (Optional) Run other profiles or collect Prometheus/Grafana metrics during/after the run

# 5. To re-run the same profile, delete the Job then apply again
kubectl delete job perftest-mixed -n couchbase
kubectl apply -f performance/kubernetes/perftest-mixed.yaml -n couchbase
```
