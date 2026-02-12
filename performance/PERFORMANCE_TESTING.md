# Couchbase Performance Testing Tools

This directory contains tools and scripts for performance testing Couchbase.

## Available Tools

### 1. Load Generator

A tool to generate load on Couchbase for performance testing.

```bash
./tools/load-generator.sh \
  --host couchbase-cluster \
  --bucket performance \
  --username performance-user \
  --password P3rf0rm@nce! \
  --operations 1000 \
  --threads 10
```

### 2. Performance Benchmark

Run standardized performance benchmarks.

```bash
./tools/benchmark.sh --profile write-heavy
./tools/benchmark.sh --profile read-heavy
./tools/benchmark.sh --profile mixed
```

### 3. Metrics Collector

Collect and export Prometheus metrics for analysis.

```bash
./tools/collect-metrics.sh --duration 3600 --output metrics.json
```

### 4. Capacity Planning

Analyze current usage and provide capacity recommendations.

```bash
./tools/capacity-planning.sh --namespace couchbase
```

## Creating Performance Tests

### Using cbc-pillowfight

```bash
# High write load
kubectl exec -it -n couchbase couchbase-cluster-0000 -- \
  cbc-pillowfight \
  -U couchbase://localhost/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 1000000 \
  --num-threads 4 \
  --set-pct 100 \
  --min-size 1024 \
  --max-size 4096

# Read-heavy load
kubectl exec -it -n couchbase couchbase-cluster-0000 -- \
  cbc-pillowfight \
  -U couchbase://localhost/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 1000000 \
  --num-threads 8 \
  --set-pct 10 \
  --get-pct 90

# Mixed workload
kubectl exec -it -n couchbase couchbase-cluster-0000 -- \
  cbc-pillowfight \
  -U couchbase://localhost/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 1000000 \
  --num-threads 8 \
  --set-pct 30 \
  --get-pct 70
```

### Using YCSB (Yahoo! Cloud Serving Benchmark)

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
  -p couchbase.password=P3rf0rm@nce! \
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
  -p couchbase.password=P3rf0rm@nce! \
  -p operationcount=1000000
```

## Performance Monitoring During Tests

### Watch Metrics in Real-time

```bash
# Operations per second
watch -n 1 'kubectl exec -n couchbase couchbase-cluster-0000 -- \
  couchbase-cli bucket-stats -c localhost \
  -u Administrator -p P@ssw0rd123! \
  --bucket performance | grep ops'

# Memory usage
watch -n 5 'kubectl exec -n couchbase couchbase-cluster-0000 -- \
  couchbase-cli server-info -c localhost \
  -u Administrator -p P@ssw0rd123!'
```

### Query Prometheus

```bash
# Get operations rate
kubectl exec -n openshift-user-workload-monitoring prometheus-user-workload-0 -- \
  promtool query instant \
  'http://localhost:9090' \
  'rate(couchbase_bucket_ops_total[5m])'
```

## Benchmark Results Format

Results should be saved in JSON format:

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

## Best Practices

1. **Warm-up Period**: Always include a warm-up period before measuring
2. **Multiple Runs**: Run tests multiple times and average results
3. **Isolate Tests**: Run performance tests in isolated environments
4. **Document Configuration**: Record all cluster and test configurations
5. **Monitor Resources**: Always monitor CPU, memory, disk, and network during tests
6. **Compare Baseline**: Establish and compare against baseline performance

## Example Performance Test Workflow

```bash
# 1. Deploy fresh cluster
./deploy.sh

# 2. Wait for cluster to be ready
./verify.sh

# 3. Pre-populate data
./tools/prepopulate.sh --documents 10000000

# 4. Run warm-up
./tools/warmup.sh --duration 300

# 5. Run benchmark
./tools/benchmark.sh --profile mixed --duration 1800

# 6. Collect results
./tools/collect-metrics.sh --output results/test-$(date +%Y%m%d-%H%M%S).json

# 7. Generate report
./tools/generate-report.sh --input results/test-*.json
```
