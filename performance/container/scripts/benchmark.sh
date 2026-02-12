#!/bin/bash
#
# Run predefined benchmark profiles
#

set -euo pipefail

PROFILE="${1:-mixed}"

CB_HOST="${CB_HOST:-couchbase-cluster}"
CB_BUCKET="${CB_BUCKET:-performance}"
CB_USER="${CB_USER:-performance-user}"
CB_PASSWORD="${CB_PASSWORD:-P3rf0rm@nce!}"

CONNSTR="couchbase://${CB_HOST}/${CB_BUCKET}"

echo "Running benchmark profile: ${PROFILE}"
echo "Target: ${CB_HOST}/${CB_BUCKET}"
echo ""

case "${PROFILE}" in
    write-heavy)
        echo "Profile: Write Heavy (90% writes, 10% reads)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 100000 \
            --num-threads 8 \
            --min-size 512 \
            --max-size 8192 \
            --set-pct 90 \
            --get-pct 10 \
            --json
        ;;
    
    read-heavy)
        echo "Profile: Read Heavy (10% writes, 90% reads)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 100000 \
            --num-threads 8 \
            --min-size 512 \
            --max-size 8192 \
            --set-pct 10 \
            --get-pct 90 \
            --json
        ;;
    
    mixed)
        echo "Profile: Mixed Workload (50% writes, 50% reads)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 100000 \
            --num-threads 8 \
            --min-size 1024 \
            --max-size 4096 \
            --set-pct 50 \
            --get-pct 50 \
            --json
        ;;
    
    small-documents)
        echo "Profile: Small Documents (256-512 bytes)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 200000 \
            --num-threads 8 \
            --min-size 256 \
            --max-size 512 \
            --set-pct 50 \
            --get-pct 50 \
            --json
        ;;
    
    large-documents)
        echo "Profile: Large Documents (10KB-50KB)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 10000 \
            --num-threads 4 \
            --min-size 10240 \
            --max-size 51200 \
            --set-pct 50 \
            --get-pct 50 \
            --json
        ;;
    
    stress)
        echo "Profile: Stress Test (high concurrency)"
        cbc-pillowfight \
            -U "${CONNSTR}" \
            -u "${CB_USER}" \
            -P "${CB_PASSWORD}" \
            --num-items 1000000 \
            --num-threads 32 \
            --min-size 1024 \
            --max-size 4096 \
            --set-pct 50 \
            --get-pct 50 \
            --json
        ;;
    
    *)
        echo "Unknown profile: ${PROFILE}"
        echo ""
        echo "Available profiles:"
        echo "  write-heavy      - 90% writes, 10% reads"
        echo "  read-heavy       - 10% writes, 90% reads"
        echo "  mixed            - 50% writes, 50% reads (default)"
        echo "  small-documents  - Test with 256-512 byte documents"
        echo "  large-documents  - Test with 10-50 KB documents"
        echo "  stress           - High concurrency stress test"
        exit 1
        ;;
esac

echo ""
echo "Benchmark complete!"
