"""Measured disk/RAM/commit admission and reclaim-telemetry policy.

This module is pure at its policy boundary so low-headroom and corrupt
telemetry cases can be fault-injected without touching the factory.  Runtime
probes are read-only.  A probe failure permits existing workers to remain but
never authorizes a new worker.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import math
import shutil
import sys
from pathlib import Path
from typing import Any, Mapping


SCHEMA = "qm.resource-headroom.v1"
GIB = 1024 ** 3
DISK_STOP_GB = 40.0
DISK_PER_WORKER_GB = 8.0
RAM_RESERVE_GB = 6.0
# Spawn-time per-worker charge covers the worker DAEMON plus an idle
# terminal (~1-2GB measured), NOT a running backtest claim — concurrent
# run RAM is protected by the claim-time admission gate (per-claim
# reservation), not here.  The original 8.0 copied the claim-level figure
# and made a 10-worker COLD START arithmetically impossible on this
# 63GB host (needs 6+8*10=86GB free): Factory_ON failed closed twice on
# 2026-08-22 with exactly workers T6-T10 missing (governor cap 5).
RAM_PER_WORKER_GB = 2.0
COMMIT_RESERVE_GB = 24.0
COMMIT_PER_WORKER_GB = 2.0  # same spawn-vs-claim rationale as RAM above
RECLAIM_TOLERANCE_MIN_GB = 1.0
RECLAIM_TOLERANCE_FRACTION = 0.25


def _finite_nonnegative(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) and number >= 0 else None


def _memory_headroom_windows() -> tuple[float | None, float | None, str | None]:
    if sys.platform != "win32":
        return None, None, "windows_memory_probe_unavailable"

    class MemoryStatusEx(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    try:
        stat = MemoryStatusEx()
        stat.dwLength = ctypes.sizeof(MemoryStatusEx)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return None, None, "GlobalMemoryStatusEx_false"
        return stat.ullAvailPhys / GIB, stat.ullAvailPageFile / GIB, None
    except Exception as exc:  # pragma: no cover - platform API failure
        return None, None, f"GlobalMemoryStatusEx:{type(exc).__name__}"


def probe(runtime_root: Path = Path(r"D:\QM\strategy_farm")) -> dict[str, Any]:
    errors: list[str] = []
    disk_free_gb: float | None
    try:
        disk_free_gb = shutil.disk_usage(runtime_root.anchor or runtime_root).free / GIB
    except Exception as exc:
        disk_free_gb = None
        errors.append(f"disk:{type(exc).__name__}")
    ram_free_gb, commit_free_gb, memory_error = _memory_headroom_windows()
    if memory_error:
        errors.append(memory_error)
    return {
        "schema": SCHEMA,
        "probe_ok": not errors,
        "disk_free_gb": None if disk_free_gb is None else round(disk_free_gb, 2),
        "ram_free_gb": None if ram_free_gb is None else round(ram_free_gb, 2),
        "commit_free_gb": None if commit_free_gb is None else round(commit_free_gb, 2),
        "errors": errors,
    }


def concurrency_decision(
    snapshot: Mapping[str, Any],
    *,
    installed_workers: int,
    running_workers: int,
) -> dict[str, Any]:
    """Bound new worker starts by currently measured resource headroom.

    The decision never asks a caller to stop a running worker.  ``max_workers``
    is therefore at least ``running_workers`` even under pressure; the throttle
    applies only to missing/new workers.
    """
    installed = max(0, int(installed_workers))
    running = min(installed, max(0, int(running_workers)))
    disk = _finite_nonnegative(snapshot.get("disk_free_gb"))
    ram = _finite_nonnegative(snapshot.get("ram_free_gb"))
    commit = _finite_nonnegative(snapshot.get("commit_free_gb"))
    invalid = [name for name, value in (("disk", disk), ("ram", ram), ("commit", commit)) if value is None]
    if snapshot.get("probe_ok") is not True or invalid:
        return {
            "schema": SCHEMA,
            "state": "TELEMETRY_ERROR",
            "allow_new_workers": False,
            "max_workers": running,
            "installed_workers": installed,
            "running_workers": running,
            "bottleneck": "probe",
            "errors": list(snapshot.get("errors") or []) + [f"invalid_{name}" for name in invalid],
            "snapshot": dict(snapshot),
        }

    # The probe measures FREE resources, so each capacity is how many ADDITIONAL
    # workers currently fit — the running ones already consumed their share and
    # must not be charged twice.  Treating these as an absolute fleet cap froze
    # the fleet wherever it happened to stand (4/10 on 2026-08-21: free RAM
    # 39.8GB -> cap 4 == running 4 -> allow_new False on every 5-minute watchdog
    # heal, forever).  Crediting the running workers keeps the guard's intent
    # (never start a worker without per-worker headroom free right now, reserves
    # untouched) while letting the fleet grow while headroom lasts.
    capacities = {
        "disk": max(0, math.floor((disk - DISK_STOP_GB) / DISK_PER_WORKER_GB)),
        "ram": max(0, math.floor((ram - RAM_RESERVE_GB) / RAM_PER_WORKER_GB)),
        "commit": max(0, math.floor((commit - COMMIT_RESERVE_GB) / COMMIT_PER_WORKER_GB)),
    }
    additional_cap = min(capacities.values())
    resource_cap = min(installed, running + additional_cap)
    max_workers = max(running, resource_cap)
    bottleneck = min(capacities, key=capacities.get)
    allow_new = running < max_workers
    return {
        "schema": SCHEMA,
        # THROTTLED states resource PRESSURE, not fleet fullness: either the
        # measured headroom cannot carry the fleet up to ``installed``, or there
        # is no per-worker headroom left at all (a full fleet on a tight host is
        # still an observation worth surfacing — it is never an interrupt order).
        "state": "THROTTLED" if (resource_cap < installed or additional_cap == 0) else "OPEN",
        "allow_new_workers": allow_new,
        "max_workers": max_workers,
        "resource_cap": resource_cap,
        "installed_workers": installed,
        "running_workers": running,
        "bottleneck": bottleneck,
        "capacities": capacities,
        "additional_capacity": additional_cap,
        "thresholds": {
            "disk_stop_gb": DISK_STOP_GB,
            "ram_reserve_gb": RAM_RESERVE_GB,
            "commit_reserve_gb": COMMIT_RESERVE_GB,
            "per_worker_gb": {
                "disk": DISK_PER_WORKER_GB,
                "ram": RAM_PER_WORKER_GB,
                "commit": COMMIT_PER_WORKER_GB,
            },
        },
        "errors": [],
        "snapshot": dict(snapshot),
    }


def validate_reclaim(
    *,
    expected_deleted_bytes: Any,
    free_before_gb: Any,
    free_after_gb: Any,
) -> dict[str, Any]:
    expected = _finite_nonnegative(expected_deleted_bytes)
    before = _finite_nonnegative(free_before_gb)
    after = _finite_nonnegative(free_after_gb)
    if expected is None or before is None or after is None:
        return {
            "schema": SCHEMA,
            "status": "TELEMETRY_ERROR",
            "reason": "invalid_numeric_input",
            "expected_deleted_bytes": expected_deleted_bytes,
            "free_before_gb": free_before_gb,
            "free_after_gb": free_after_gb,
        }
    observed_bytes = (after - before) * GIB
    tolerance_bytes = max(RECLAIM_TOLERANCE_MIN_GB * GIB, expected * RECLAIM_TOLERANCE_FRACTION)
    lower = -tolerance_bytes
    upper = expected + tolerance_bytes
    if observed_bytes > upper:
        status, reason = "TELEMETRY_ERROR", "implausible_free_space_gain"
    elif observed_bytes < lower:
        status, reason = "TELEMETRY_ERROR", "implausible_free_space_loss"
    else:
        status, reason = "OK", "plausible_with_concurrent_io_tolerance"
    return {
        "schema": SCHEMA,
        "status": status,
        "reason": reason,
        "expected_deleted_bytes": int(expected),
        "expected_deleted_gb": round(expected / GIB, 3),
        "observed_free_delta_gb": round(observed_bytes / GIB, 3),
        "tolerance_gb": round(tolerance_bytes / GIB, 3),
        "plausible_min_gb": round(lower / GIB, 3),
        "plausible_max_gb": round(upper / GIB, 3),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    snapshot = sub.add_parser("snapshot")
    snapshot.add_argument("--runtime-root", type=Path, default=Path(r"D:\QM\strategy_farm"))
    reclaim = sub.add_parser("validate-reclaim")
    reclaim.add_argument("--expected-deleted-bytes", required=True)
    reclaim.add_argument("--free-before-gb", required=True)
    reclaim.add_argument("--free-after-gb", required=True)
    args = parser.parse_args(argv)
    if args.command == "snapshot":
        result = probe(args.runtime_root)
    else:
        result = validate_reclaim(
            expected_deleted_bytes=args.expected_deleted_bytes,
            free_before_gb=args.free_before_gb,
            free_after_gb=args.free_after_gb,
        )
    print(json.dumps(result, sort_keys=True))
    return 2 if result.get("status") == "TELEMETRY_ERROR" or result.get("probe_ok") is False else 0


if __name__ == "__main__":
    raise SystemExit(main())
