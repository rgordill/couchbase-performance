"""Parser for cbc-pillowfight histogram log output."""

import re
import sys
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict

from .models import HistogramSnapshot

# First line: "Test started Mon Mar 16 16:15:44 UTC 2026, uptime: 2737299.78"
FIRST_LINE_RE = re.compile(
    r"Test started\s+(\w+\s+\w+\s+\d+\s+\d+:\d+:\d+)\s+UTC\s+(\d{4}),\s+uptime:\s*([\d.]+)",
    re.ASCII,
)
# Header block: "[2737300.033083 Populate]"
HEADER_RE = re.compile(r"\[\s*([\d.]+)\s+(.+?)\]\s*$", re.ASCII)
# Bucket line: "[160  - 169 ]us |" or "[10   - 19  ]ms |"
BUCKET_LINE_RE = re.compile(r"\[\s*(\d+)\s*-\s*(\d+)\s*\](us|ms)\s*\|", re.ASCII)
# Count on same line: " - 44" at end
COUNT_SAME_LINE_RE = re.compile(r"\s*-\s*(\d+)\s*$", re.ASCII)
# Count on next line
COUNT_NEXT_LINE_RE = re.compile(r"^\s*-\s*(\d+)\s*$", re.ASCII)


class HistogramLogParser:
    """Parse cbc-pillowfight histogram log and yield HistogramSnapshot."""

    def __init__(self, file_path: str):
        self.file_path = file_path
        self.snapshots: List[HistogramSnapshot] = []
        self.start_time: Optional[datetime] = None

    def parse(self) -> List[HistogramSnapshot]:
        """Parse the log file and return list of histogram snapshots."""
        with open(self.file_path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()

        if not lines:
            raise ValueError("Log file is empty")

        first = lines[0].strip()
        self._parse_first_line(first)

        # Split into blocks by header lines; each block is [header, optional separator, bucket lines...]
        i = 1
        interval_number = 0
        while i < len(lines):
            header_match = HEADER_RE.match(lines[i].strip())
            if not header_match:
                i += 1
                continue

            relative_sec = float(header_match.group(1))
            phase = header_match.group(2).strip()
            i += 1

            # Skip separator lines (e.g. +---------+ or +----------------------------------------)
            while i < len(lines) and lines[i].strip().startswith("+"):
                i += 1

            buckets: Dict[str, int] = {}
            while i < len(lines):
                line = lines[i]
                stripped = line.strip()
                # Next header starts a new block
                if HEADER_RE.match(stripped):
                    break
                bucket_match = BUCKET_LINE_RE.search(stripped)
                if bucket_match:
                    lower_val = int(bucket_match.group(1))
                    upper_val = int(bucket_match.group(2))
                    unit = bucket_match.group(3)
                    if unit == "us":
                        scale = 1e-6
                    else:
                        scale = 1e-3
                    lower_sec = lower_val * scale
                    upper_sec = upper_val * scale
                    bucket_key = f"{lower_sec}-{upper_sec}"

                    # Count on same line after " |"
                    count_match = COUNT_SAME_LINE_RE.search(stripped)
                    if count_match:
                        count = int(count_match.group(1))
                    else:
                        # Count on next line
                        i += 1
                        if i < len(lines):
                            next_match = COUNT_NEXT_LINE_RE.match(lines[i].strip())
                            if next_match:
                                count = int(next_match.group(1))
                            else:
                                count = 0
                        else:
                            count = 0
                    buckets[bucket_key] = buckets.get(bucket_key, 0) + count
                i += 1

            if not buckets:
                continue

            interval_number += 1
            if self.start_time is None:
                raise ValueError("start_time must be set from first line")
            timestamp = self.start_time + timedelta(seconds=relative_sec)
            self.snapshots.append(
                HistogramSnapshot(
                    interval_number=interval_number,
                    relative_seconds=relative_sec,
                    timestamp=timestamp,
                    phase=phase,
                    latency_buckets=buckets,
                )
            )

        return self.snapshots

    def _parse_first_line(self, line: str) -> None:
        """Parse first line to get test start time (UTC)."""
        m = FIRST_LINE_RE.match(line)
        if not m:
            raise ValueError(
                "Expected first line: Test started <Weekday> <Mon> <DD> <HH>:<MM>:<SS> UTC <YYYY>, uptime: <float>"
            )
        date_part = m.group(1).strip()  # e.g. "Mon Mar 16 16:15:44"
        year = m.group(2)  # e.g. "2026"
        try:
            dt = datetime.strptime(f"{date_part} {year}", "%a %b %d %H:%M:%S %Y")
        except ValueError:
            raise ValueError(
                f"Could not parse date/time from first line: {date_part!r} {year!r}"
            )
        self.start_time = dt.replace(tzinfo=timezone.utc)
        # uptime_str can be used for validation if needed
