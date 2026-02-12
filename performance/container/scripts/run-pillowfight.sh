#!/bin/bash
#
# Run cbc-pillowfight with common parameters
#

set -euo pipefail

# Configuration with defaults
CB_HOST="${CB_HOST:-couchbase-cluster}"
CB_BUCKET="${CB_BUCKET:-performance}"
CB_USER="${CB_USER:-performance-user}"
CB_PASSWORD="${CB_PASSWORD:-P3rf0rm@nce!}"
CB_OPERATIONS="${CB_OPERATIONS:-10000}"
CB_THREADS="${CB_THREADS:-4}"
CB_MIN_SIZE="${CB_MIN_SIZE:-1024}"
CB_MAX_SIZE="${CB_MAX_SIZE:-4096}"
CB_SET_PCT="${CB_SET_PCT:-50}"
CB_GET_PCT="${CB_GET_PCT:-50}"

# Build connection string
CONNSTR="couchbase://${CB_HOST}/${CB_BUCKET}"

echo "========================================"
echo "Couchbase Performance Test"
echo "========================================"
echo "Host:       ${CB_HOST}"
echo "Bucket:     ${CB_BUCKET}"
echo "User:       ${CB_USER}"
echo "Operations: ${CB_OPERATIONS}"
echo "Threads:    ${CB_THREADS}"
echo "Size range: ${CB_MIN_SIZE}-${CB_MAX_SIZE} bytes"
echo "Set/Get:    ${CB_SET_PCT}%/${CB_GET_PCT}%"
echo "========================================"

# Run cbc-pillowfight
cbc-pillowfight \
    -U "${CONNSTR}" \
    -u "${CB_USER}" \
    -P "${CB_PASSWORD}" \
    --num-items "${CB_OPERATIONS}" \
    --num-threads "${CB_THREADS}" \
    --min-size "${CB_MIN_SIZE}" \
    --max-size "${CB_MAX_SIZE}" \
    --set-pct "${CB_SET_PCT}" \
    --get-pct "${CB_GET_PCT}" \
    --json

echo ""
echo "Test completed!"
