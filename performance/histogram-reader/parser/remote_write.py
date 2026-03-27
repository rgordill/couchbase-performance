"""Client for sending cbc_pillowfight_latency metrics via Prometheus remote write."""

import re
import sys
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import requests
import snappy
from google.protobuf.json_format import MessageToJson

from prometheus_remote_writer.proto import remote_pb2 as prompb_pb2
from prometheus_remote_writer.proto import types_pb2

from .models import HistogramSnapshot
from .utils import BUCKET_UPPER_BOUND_PATTERN, format_bound_for_label

PREFIX = "cbc_pillowfight_latency"


class RemoteWriteClient:
    """Client for sending Prometheus metrics via remote write."""

    def __init__(
        self,
        remote_write_url: str,
        headers: Optional[Dict[str, str]] = None,
        instance_label: str = "histogram-reader",
        verbose: bool = False,
    ):
        self.remote_write_url = remote_write_url
        self.headers = headers or {}
        self.headers.setdefault("Content-Type", "application/x-protobuf")
        self.headers.setdefault("Content-Encoding", "snappy")
        self.instance_label = instance_label
        self.verbose = verbose

    def send_metrics_from_snapshots(
        self,
        snapshots: List[HistogramSnapshot],
        dry_run: bool = False,
        debug_file: Optional[str] = None,
    ) -> bool:
        """Send metrics from histogram snapshots to remote write endpoint."""
        try:
            if snapshots:
                print(f"Processing {len(snapshots)} snapshot(s)", file=sys.stderr)
                print(
                    f"  First: timestamp={snapshots[0].timestamp}, relative_sec={snapshots[0].relative_seconds:.6f}",
                    file=sys.stderr,
                )
                print(
                    f"  Last: timestamp={snapshots[-1].timestamp}, relative_sec={snapshots[-1].relative_seconds:.6f}",
                    file=sys.stderr,
                )

            write_request = self._convert_snapshots_to_remote_write(snapshots)
            if write_request is None:
                print("Error: Could not convert snapshots to remote write format", file=sys.stderr)
                return False

            num_timeseries = len(write_request.timeseries)
            total_samples = sum(len(ts.samples) for ts in write_request.timeseries)
            print(f"Prepared {num_timeseries} time series with {total_samples} total samples", file=sys.stderr)

            data = write_request.SerializeToString()

            if debug_file:
                try:
                    json_data = MessageToJson(write_request)
                    with open(debug_file, "w", encoding="utf-8") as f:
                        f.write(json_data)
                    print(f"Saved uncompressed payload to {debug_file}", file=sys.stderr)
                except Exception as e:
                    print(f"Warning: Failed to write debug file: {e}", file=sys.stderr)

            if dry_run:
                print("Dry-run mode: Skipping actual send to endpoint", file=sys.stderr)
                return True

            compressed = snappy.compress(data)
            print(f"Sending {len(compressed)} bytes (uncompressed: {len(data)} bytes)", file=sys.stderr)
            response = requests.post(
                self.remote_write_url,
                data=compressed,
                headers=self.headers,
                timeout=30,
            )
            if response.status_code in (200, 204):
                print(f"Successfully sent metrics (status {response.status_code})", file=sys.stderr)
                return True
            print(f"Error sending metrics: {response.status_code} - {response.text}", file=sys.stderr)
            return False
        except requests.exceptions.ConnectionError as e:
            print(f"Connection error: {e}", file=sys.stderr)
            print("  Start Prometheus with: --web.enable-remote-write-receiver", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error in remote write: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)
            return False

    def _collect_bucket_bounds(self, snapshots: List[HistogramSnapshot]) -> List[float]:
        """Collect and sort all unique bucket upper bounds from all snapshots."""
        all_bounds = set()
        for s in snapshots:
            for bucket_range in s.latency_buckets:
                upper_str = bucket_range.split("-")[-1]
                try:
                    all_bounds.add(float(upper_str))
                except ValueError:
                    m = re.search(BUCKET_UPPER_BOUND_PATTERN, upper_str)
                    if m:
                        try:
                            all_bounds.add(float(m.group(1)))
                        except ValueError:
                            pass
        return sorted(all_bounds)

    def _calculate_interval_latency_stats(
        self, stats: HistogramSnapshot
    ) -> Tuple[float, int]:
        """Latency sum and count from bucket data (midpoint * count)."""
        total_sum = 0.0
        total_count = 0
        for bucket_range, count in stats.latency_buckets.items():
            total_count += count
            parts = bucket_range.split("-")
            if len(parts) == 2:
                try:
                    lower = float(parts[0])
                    upper = float(parts[1])
                    total_sum += (lower + upper) / 2.0 * count
                except ValueError:
                    pass
        return total_sum, total_count

    def _find_matching_bound(
        self, upper_float: float, sorted_bounds: List[float]
    ) -> Optional[float]:
        for b in sorted_bounds:
            if abs(b - upper_float) < 1e-12:
                return b
        return upper_float if upper_float in sorted_bounds else None

    def _process_interval_latency_buckets(
        self,
        stats: HistogramSnapshot,
        time_series_map: Dict[tuple, Any],
        sorted_bucket_bounds: List[float],
        cumulative_bucket_counts: Dict[str, int],
        cumulative_latency_count: int,
        timestamp_ms: int,
    ) -> Dict[str, int]:
        """Emit cumulative latency buckets for this snapshot."""
        interval_per_bucket: Dict[float, int] = {}
        for bucket_range, count in stats.latency_buckets.items():
            upper_str = bucket_range.split("-")[-1]
            try:
                upper_float = float(upper_str)
            except ValueError:
                m = re.search(BUCKET_UPPER_BOUND_PATTERN, upper_str)
                if m:
                    upper_float = float(m.group(1))
                else:
                    continue
            bound = self._find_matching_bound(upper_float, sorted_bucket_bounds)
            if bound is not None:
                interval_per_bucket[bound] = interval_per_bucket.get(bound, 0) + count

        cumulative_interval: Dict[float, int] = {}
        running = 0
        for b in sorted_bucket_bounds:
            running += interval_per_bucket.get(b, 0)
            cumulative_interval[b] = running

        for b in sorted_bucket_bounds:
            bound_str = format_bound_for_label(b)
            cumulative_bucket_counts[bound_str] = (
                cumulative_bucket_counts.get(bound_str, 0)
                + cumulative_interval.get(b, 0)
            )

        for b in sorted_bucket_bounds:
            bound_str = format_bound_for_label(b)
            self._add_sample_to_map(
                time_series_map,
                f"{PREFIX}_bucket",
                {"le": bound_str},
                cumulative_bucket_counts[bound_str],
                timestamp_ms,
            )
        self._add_sample_to_map(
            time_series_map, f"{PREFIX}_bucket", {"le": "+Inf"}, cumulative_latency_count, timestamp_ms
        )
        return cumulative_bucket_counts

    def _add_sample_to_map(
        self,
        time_series_map: Dict[tuple, Any],
        metric_name: str,
        labels: Dict[str, str],
        value: float,
        timestamp_ms: int,
    ) -> None:
        """Add a sample to the time series map."""
        labels = {**labels, "instance": self.instance_label}
        key = (metric_name, tuple(sorted(labels.items())))
        if key not in time_series_map:
            ts = types_pb2.TimeSeries()
            ts.labels.add(name="__name__", value=metric_name)
            for k, v in labels.items():
                ts.labels.add(name=k, value=str(v))
            time_series_map[key] = ts
        if metric_name.endswith("_info") and len(time_series_map[key].samples) > 0:
            return
        sample = time_series_map[key].samples.add()
        sample.value = value
        sample.timestamp = timestamp_ms
        if self.verbose:
            self._print_metric_sample(time_series_map[key], timestamp_ms, value)

    def _print_metric_sample(self, time_series, timestamp_ms: int, value: float) -> None:
        name = None
        labels = {}
        for lab in time_series.labels:
            if lab.name == "__name__":
                name = lab.value
            else:
                labels[lab.name] = lab.value
        ls = ",".join(f'{k}="{v}"' for k, v in sorted(labels.items()))
        dt = datetime.fromtimestamp(timestamp_ms / 1000.0)
        print(f"{dt.isoformat()} {name}{{{ls}}} {value}")

    def _finalize_time_series(
        self, time_series_map: Dict[tuple, Any], write_request
    ) -> None:
        for ts in time_series_map.values():
            if ts.samples:
                new_ts = write_request.timeseries.add()
                new_ts.CopyFrom(ts)

    def _convert_snapshots_to_remote_write(
        self, snapshots: List[HistogramSnapshot]
    ):
        """Build WriteRequest from snapshots (histogram metrics only)."""
        write_request = prompb_pb2.WriteRequest()
        time_series_map: Dict[tuple, Any] = {}
        if not snapshots:
            return write_request

        # Optional info metric at first timestamp
        first_ts_ms = int(snapshots[0].timestamp.timestamp() * 1000)
        self._add_sample_to_map(
            time_series_map,
            f"{PREFIX}_info",
            {"phase": snapshots[0].phase},
            1.0,
            first_ts_ms,
        )

        sorted_bounds = self._collect_bucket_bounds(snapshots)
        cumulative_latency_sum = 0.0
        cumulative_latency_count = 0
        cumulative_bucket_counts: Dict[str, int] = {}

        for stats in snapshots:
            timestamp_ms = int(stats.timestamp.timestamp() * 1000)
            interval_sum, interval_count = self._calculate_interval_latency_stats(stats)
            cumulative_latency_sum += interval_sum
            cumulative_latency_count += interval_count
            self._add_sample_to_map(
                time_series_map,
                f"{PREFIX}_seconds_sum",
                {},
                cumulative_latency_sum,
                timestamp_ms,
            )
            self._add_sample_to_map(
                time_series_map,
                f"{PREFIX}_seconds_count",
                {},
                cumulative_latency_count,
                timestamp_ms,
            )
            cumulative_bucket_counts = self._process_interval_latency_buckets(
                stats,
                time_series_map,
                sorted_bounds,
                cumulative_bucket_counts,
                cumulative_latency_count,
                timestamp_ms,
            )

        self._finalize_time_series(time_series_map, write_request)
        return write_request
