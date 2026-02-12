# Couchbase Performance Testing Client Container

This container includes `cbc-pillowfight` and other Couchbase performance testing tools built from libcouchbase.

## Features

- Built on Red Hat UBI 9 Minimal
- Includes cbc-pillowfight for load testing
- Pre-configured benchmark profiles
- Runs as non-root (UID 1001)
- Works with podman, docker, buildah, nerdctl

## Building the Image

### Using Podman (Recommended)

```bash
podman build -t couchbase-perftest:latest .
```

### Using Docker

```bash
docker build -t couchbase-perftest:latest .
```

### Using Makefile

```bash
cd ../..  # Go to project root
make build-perftest
```

## Running Performance Tests

### Quick Test

```bash
# Using podman
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 10000 \
  --num-threads 4

# Using kubectl on Kubernetes
kubectl run cbc-perftest --rm -it --restart=Never \
  --image=couchbase-perftest:latest \
  -- cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 10000 \
  --num-threads 4
```

### Using Environment Variables

```bash
podman run --rm \
  -e CB_HOST=couchbase-cluster \
  -e CB_BUCKET=performance \
  -e CB_USER=performance-user \
  -e CB_PASSWORD=P3rf0rm@nce! \
  -e CB_OPERATIONS=50000 \
  -e CB_THREADS=8 \
  couchbase-perftest:latest \
  /scripts/run-pillowfight.sh
```

### Benchmark Profiles

Run predefined benchmark profiles:

```bash
# Mixed workload (default)
podman run --rm \
  -e CB_HOST=couchbase-cluster \
  -e CB_USER=performance-user \
  -e CB_PASSWORD=P3rf0rm@nce! \
  couchbase-perftest:latest \
  /scripts/benchmark.sh mixed

# Write-heavy workload
podman run --rm \
  -e CB_HOST=couchbase-cluster \
  -e CB_USER=performance-user \
  -e CB_PASSWORD=P3rf0rm@nce! \
  couchbase-perftest:latest \
  /scripts/benchmark.sh write-heavy

# Read-heavy workload
podman run --rm \
  -e CB_HOST=couchbase-cluster \
  -e CB_USER=performance-user \
  -e CB_PASSWORD=P3rf0rm@nce! \
  couchbase-perftest:latest \
  /scripts/benchmark.sh read-heavy

# Stress test
podman run --rm \
  -e CB_HOST=couchbase-cluster \
  -e CB_USER=performance-user \
  -e CB_PASSWORD=P3rf0rm@nce! \
  couchbase-perftest:latest \
  /scripts/benchmark.sh stress
```

## Available Benchmark Profiles

| Profile | Description | Operations | Threads | Set/Get Ratio |
|---------|-------------|------------|---------|---------------|
| `mixed` | Balanced workload | 100,000 | 8 | 50/50 |
| `write-heavy` | Write-intensive | 100,000 | 8 | 90/10 |
| `read-heavy` | Read-intensive | 100,000 | 8 | 10/90 |
| `small-documents` | Small docs (256-512B) | 200,000 | 8 | 50/50 |
| `large-documents` | Large docs (10-50KB) | 10,000 | 4 | 50/50 |
| `stress` | High concurrency | 1,000,000 | 32 | 50/50 |

## Running on Kubernetes/OpenShift

### As a Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: couchbase-perftest
  namespace: couchbase
spec:
  template:
    spec:
      containers:
        - name: perftest
          image: couchbase-perftest:latest
          command: ["/scripts/benchmark.sh"]
          args: ["mixed"]
          env:
            - name: CB_HOST
              value: "couchbase-cluster"
            - name: CB_BUCKET
              value: "performance"
            - name: CB_USER
              value: "performance-user"
            - name: CB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: performance-user-password
                  key: password
      restartPolicy: Never
  backoffLimit: 4
```

### As a CronJob (Scheduled Tests)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: couchbase-perftest-daily
  namespace: couchbase
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: perftest
              image: couchbase-perftest:latest
              command: ["/scripts/benchmark.sh"]
              args: ["mixed"]
              env:
                - name: CB_HOST
                  value: "couchbase-cluster"
                - name: CB_BUCKET
                  value: "performance"
                - name: CB_USER
                  value: "performance-user"
                - name: CB_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: performance-user-password
                      key: password
          restartPolicy: OnFailure
```

### Interactive Testing

```bash
# Start an interactive shell in Kubernetes
kubectl run -it --rm cbc-shell \
  --image=couchbase-perftest:latest \
  --restart=Never \
  -- /bin/bash

# Then inside the container:
cbc-pillowfight -U couchbase://couchbase-cluster/performance \
  -u performance-user -P password \
  --num-items 10000 \
  --num-threads 4
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CB_HOST` | `couchbase-cluster` | Couchbase host/service name |
| `CB_BUCKET` | `performance` | Target bucket |
| `CB_USER` | `performance-user` | Username |
| `CB_PASSWORD` | `P3rf0rm@nce!` | Password |
| `CB_OPERATIONS` | `10000` | Number of operations |
| `CB_THREADS` | `4` | Number of threads |
| `CB_MIN_SIZE` | `1024` | Minimum document size (bytes) |
| `CB_MAX_SIZE` | `4096` | Maximum document size (bytes) |
| `CB_SET_PCT` | `50` | Percentage of write operations |
| `CB_GET_PCT` | `50` | Percentage of read operations |

## cbc-pillowfight Options

```bash
# View all options
podman run --rm couchbase-perftest:latest cbc-pillowfight --help

# Common options:
#   -U <connstr>          Connection string
#   -u <username>         Username
#   -P <password>         Password
#   --num-items <n>       Number of operations
#   --num-threads <n>     Number of threads
#   --min-size <bytes>    Minimum document size
#   --max-size <bytes>    Maximum document size
#   --set-pct <n>         Percentage of SET operations
#   --get-pct <n>         Percentage of GET operations
#   --json                Output in JSON format
#   --no-population       Skip initial population
#   --persist-to <n>      Persist to N nodes
#   --replicate-to <n>    Replicate to N nodes
```

## Available Tools

This container includes all libcouchbase command-line tools:

- `cbc-pillowfight` - Load testing tool
- `cbc-n1qlback` - N1QL benchmarking
- `cbc-cat` - Retrieve documents
- `cbc-create` - Create documents
- `cbc-stats` - Get server statistics
- `cbc-ping` - Ping services
- `cbc-watch` - Watch for mutations

## Examples

### Basic Load Test

```bash
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 10000 \
  --num-threads 4 \
  --min-size 1024 \
  --max-size 4096 \
  --set-pct 50 \
  --get-pct 50 \
  --json
```

### Write-Only Test

```bash
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 50000 \
  --num-threads 8 \
  --set-pct 100 \
  --get-pct 0
```

### Read-Only Test (requires pre-populated data)

```bash
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 50000 \
  --num-threads 8 \
  --set-pct 0 \
  --get-pct 100 \
  --no-population
```

### High Concurrency Test

```bash
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 1000000 \
  --num-threads 32 \
  --set-pct 50 \
  --get-pct 50
```

## Troubleshooting

### Connection Issues

```bash
# Test connectivity
podman run --rm couchbase-perftest:latest \
  cbc-ping \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce!
```

### View Cluster Stats

```bash
podman run --rm couchbase-perftest:latest \
  cbc-stats \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce!
```

### Debug Mode

```bash
# Run with verbose output
podman run --rm couchbase-perftest:latest \
  cbc-pillowfight \
  -U couchbase://couchbase-cluster/performance \
  -u performance-user \
  -P P3rf0rm@nce! \
  --num-items 100 \
  -v
```

## Building from Source

The Containerfile builds libcouchbase from source for the latest features:

```bash
# Build with specific libcouchbase version
podman build \
  --build-arg LIBCOUCHBASE_VERSION=3.3.12 \
  -t couchbase-perftest:3.3.12 \
  .

# Build with build metadata
podman build \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  -t couchbase-perftest:latest \
  .
```

## Security

- Runs as non-root user (UID 1001)
- Based on Red Hat UBI 9 Minimal
- No unnecessary packages installed
- Minimal attack surface

## License

Same as the main couchbase-performance project.
