"""Utility functions for histogram log parsing and remote write."""

from typing import Dict, List, Optional
import sys

from .models import HistogramSnapshot

# Regex pattern for extracting upper bound from bucket range (supports scientific notation)
BUCKET_UPPER_BOUND_PATTERN = r"([\d.eE+-]+)$"


def format_bound_for_label(value: float) -> str:
    """Format a float value as a string for Prometheus label (decimal notation)."""
    return f"{value:.9f}".rstrip("0").rstrip(".")


def prepare_headers(remote_write_headers: Optional[List[str]]) -> Dict[str, str]:
    """Prepare headers dictionary from command-line arguments (Key=Value)."""
    headers = {}
    if remote_write_headers:
        for header in remote_write_headers:
            if "=" in header:
                key, value = header.split("=", 1)
                headers[key] = value
    return headers


def send_metrics_remote_write(
    remote_write_url: str,
    headers: Dict[str, str],
    snapshots: List[HistogramSnapshot],
    instance_label: str,
    verbose: bool = False,
    dry_run: bool = False,
    debug_file: Optional[str] = None,
) -> None:
    """Send metrics via remote write endpoint."""
    from .remote_write import RemoteWriteClient

    if dry_run:
        print(f"\nDry-run mode: Processing metrics (not sending to {remote_write_url})...")
    else:
        print(f"\nSending metrics to {remote_write_url}...")

    client = RemoteWriteClient(remote_write_url, headers, instance_label, verbose)

    if client.send_metrics_from_snapshots(
        snapshots, dry_run=dry_run, debug_file=debug_file
    ):
        if dry_run:
            print(f"Dry-run completed: Processed metrics for {len(snapshots)} snapshot(s)")
        else:
            print(f"Successfully sent metrics for {len(snapshots)} snapshot(s)")
    else:
        print("Failed to process/send metrics", file=sys.stderr)
        sys.exit(1)
