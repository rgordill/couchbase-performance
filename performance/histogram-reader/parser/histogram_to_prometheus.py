#!/usr/bin/env python3
"""
Parse cbc-pillowfight histogram log and send latency buckets to Prometheus via remote write.
Timestamps are derived from the log first line (Test started ... UTC ...).
"""

import sys
import os
import argparse

try:
    from .parser import HistogramLogParser
    from .utils import prepare_headers, send_metrics_remote_write
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from parser.parser import HistogramLogParser
    from parser.utils import prepare_headers, send_metrics_remote_write


def main():
    parser = argparse.ArgumentParser(
        description="Parse cbc-pillowfight histogram log and send to Prometheus via remote write"
    )
    parser.add_argument(
        "input_file",
        help="Path to histogram log file (first line: Test started ... UTC ... uptime: ...)",
    )
    parser.add_argument(
        "--remote-write-url",
        required=True,
        help="Prometheus remote write endpoint URL (e.g. http://localhost:9090/api/v1/write)",
    )
    parser.add_argument(
        "--remote-write-header",
        action="append",
        help="Additional header for remote write (format: Key=Value)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and process metrics without sending",
    )
    parser.add_argument(
        "--instance-label",
        default="histogram-reader",
        help="Value for the instance label (default: histogram-reader)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print each metric with timestamp to stdout",
    )
    parser.add_argument(
        "--debug-file",
        help="Save uncompressed payload as JSON to this file for debugging",
    )
    args = parser.parse_args()

    print(f"Parsing histogram log from {args.input_file}...")
    log_parser = HistogramLogParser(args.input_file)
    try:
        snapshots = log_parser.parse()
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not snapshots:
        print("No histogram snapshots found in file.", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(snapshots)} snapshot(s)")
    headers = prepare_headers(args.remote_write_header)
    send_metrics_remote_write(
        args.remote_write_url,
        headers,
        snapshots,
        args.instance_label,
        args.verbose,
        args.dry_run,
        args.debug_file,
    )


if __name__ == "__main__":
    main()
