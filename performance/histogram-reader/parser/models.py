"""Data models for cbc-pillowfight histogram log parsing."""

from dataclasses import dataclass
from datetime import datetime
from typing import Dict


@dataclass
class HistogramSnapshot:
    """One histogram snapshot from the log (one header block)."""
    interval_number: int
    relative_seconds: float  # Seconds since test start (from header)
    timestamp: datetime  # Wall-clock time: start_time + relative_seconds
    phase: str
    latency_buckets: Dict[str, int]  # "lower_sec-upper_sec" -> count
