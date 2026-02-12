# Prometheus Queries for Couchbase Monitoring

This document contains useful Prometheus queries for monitoring Couchbase performance.

## Bucket Metrics

### Operations per Second by Bucket
```promql
rate(couchbase_bucket_ops_total[5m])
```

### Memory Usage by Bucket
```promql
couchbase_bucket_mem_used_bytes / 1024 / 1024 / 1024
```

### Memory Utilization Percentage
```promql
(couchbase_bucket_mem_used_bytes / couchbase_bucket_mem_quota_bytes) * 100
```

### Item Count by Bucket
```promql
couchbase_bucket_item_count
```

### Disk Usage by Bucket
```promql
couchbase_bucket_disk_used_bytes / 1024 / 1024 / 1024
```

### Cache Miss Ratio
```promql
rate(couchbase_bucket_ep_bg_fetched[5m]) / rate(couchbase_bucket_ops_total{op_type="get"}[5m])
```

## Query Service Metrics

### Active Queries
```promql
couchbase_query_active_requests
```

### Query Requests per Second
```promql
rate(couchbase_query_requests_total[5m])
```

### Query Errors per Second
```promql
rate(couchbase_query_errors_total[5m])
```

### Average Query Duration
```promql
rate(couchbase_query_request_time_total[5m]) / rate(couchbase_query_requests_total[5m])
```

## Index Service Metrics

### Index RAM Used
```promql
couchbase_index_memory_used_bytes / 1024 / 1024 / 1024
```

### Index Disk Size
```promql
couchbase_index_disk_size_bytes / 1024 / 1024 / 1024
```

### Index Items Count
```promql
couchbase_index_items_count
```

## Data Service Metrics

### Get Operations per Second
```promql
rate(couchbase_bucket_ops_total{op_type="get"}[5m])
```

### Set Operations per Second
```promql
rate(couchbase_bucket_ops_total{op_type="set"}[5m])
```

### Delete Operations per Second
```promql
rate(couchbase_bucket_ops_total{op_type="delete"}[5m])
```

### Current Connections
```promql
couchbase_bucket_curr_connections
```

## XDCR Metrics

### XDCR Changes Remaining
```promql
couchbase_xdcr_changes_left
```

### XDCR Docs Written per Second
```promql
rate(couchbase_xdcr_docs_written[5m])
```

### XDCR Replication Lag
```promql
couchbase_xdcr_docs_failed_cr_source
```

## Node Metrics

### CPU Usage per Node
```promql
rate(couchbase_sys_cpu_utilization_rate[5m])
```

### Memory Free per Node
```promql
couchbase_sys_mem_free_bytes / 1024 / 1024 / 1024
```

### Swap Usage
```promql
couchbase_sys_swap_used_bytes / 1024 / 1024 / 1024
```

## Performance Metrics

### 95th Percentile Get Latency
```promql
histogram_quantile(0.95, rate(couchbase_bucket_cmd_get_bucket[5m]))
```

### Average Document Size
```promql
couchbase_bucket_disk_used_bytes / couchbase_bucket_item_count
```

### Resident Items Ratio
```promql
(couchbase_bucket_vb_active_resident_items_ratio + couchbase_bucket_vb_replica_resident_items_ratio) / 2
```

## Cluster Health

### Cluster Membership Status
```promql
couchbase_cluster_membership_status
```

### Node Count
```promql
count(couchbase_cluster_membership_status)
```

### Unhealthy Nodes
```promql
count(couchbase_cluster_membership_status != 1)
```

## Alerts and Thresholds

### High Memory Usage (>85%)
```promql
(couchbase_bucket_mem_used_bytes / couchbase_bucket_mem_quota_bytes) * 100 > 85
```

### High Disk Usage (>80%)
```promql
(couchbase_bucket_disk_used_bytes / couchbase_bucket_disk_quota_bytes) * 100 > 80
```

### Node Down
```promql
up{job="couchbase-cluster"} == 0
```

### High Query Rate (>1000 qps)
```promql
rate(couchbase_query_requests_total[5m]) > 1000
```

### XDCR Replication Issues
```promql
couchbase_xdcr_docs_failed_cr_source > 100
```

## Useful Aggregations

### Total Operations per Second (Cluster-wide)
```promql
sum(rate(couchbase_bucket_ops_total[5m]))
```

### Total Memory Usage (Cluster-wide)
```promql
sum(couchbase_bucket_mem_used_bytes) / 1024 / 1024 / 1024
```

### Total Items (Cluster-wide)
```promql
sum(couchbase_bucket_item_count)
```

### Average Operations per Node
```promql
avg(rate(couchbase_bucket_ops_total[5m])) by (instance)
```

## Dashboard Queries

### Top 5 Busiest Buckets by Operations
```promql
topk(5, sum(rate(couchbase_bucket_ops_total[5m])) by (bucket))
```

### Top 5 Buckets by Memory Usage
```promql
topk(5, sum(couchbase_bucket_mem_used_bytes) by (bucket))
```

### Top 5 Slowest Queries
```promql
topk(5, rate(couchbase_query_request_time_total[5m]) / rate(couchbase_query_requests_total[5m]))
```
