"""Opt-in, per-run MT5 tester-cache growth budget.

The guard is deliberately disabled unless ``QM_TESTER_CACHE_BUDGET_GB`` is a
finite positive number.  When enabled, a worker snapshots the terminal's
``Tester/bases`` and ``Tester/Agent-*`` trees immediately before launch and
measures their net growth while that one terminal slot is running.  The
effective allowance is the smaller of the configured per-run budget and the
space available above the farm disk-stop reserve.

This module only measures and classifies.  ``terminal_worker`` owns process
containment, durable evidence, and the work-item transition.
"""
from __future__ import annotations

import math
import os
import shutil
from pathlib import Path
from typing import Any, Mapping


SCHEMA = "qm.tester_cache_budget/v1"
ENV_BUDGET_GB = "QM_TESTER_CACHE_BUDGET_GB"
VERDICT_REASON = "TESTER_CACHE_BUDGET_EXCEEDED"
PAIR_HOLD_PHASE = "*"
PAIR_HOLD_THRESHOLD = 2
GIB = 1024 ** 3
DEFAULT_DISK_STOP_GB = 40.0
# Sampling is not instantaneous.  Keep a material reserve above the 40 GB
# fleet stop so the worker can contain the run before the purge tears down
# otherwise-idle slots.  Historical bombs grew at roughly 0.5-1.0 GB/10 s.
DEFAULT_DISK_STOP_MARGIN_GB = 8.0


def configured_budget_gb(environ: Mapping[str, str] | None = None) -> float | None:
    """Return the opt-in budget, or ``None`` when absent/invalid/non-positive."""

    env = os.environ if environ is None else environ
    raw = str(env.get(ENV_BUDGET_GB, "") or "").strip()
    if not raw:
        return None
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return None
    return value if math.isfinite(value) and value > 0.0 else None


def _terminal_tester_root(mt5_root: Path, terminal: str) -> Path:
    token = str(terminal or "").strip().upper()
    if token not in {f"T{i}" for i in range(1, 11)}:
        raise ValueError(f"tester-cache budget only supports T1-T10, got {terminal!r}")
    return Path(mt5_root) / token / "Tester"


def _tree_size_bytes(root: Path) -> tuple[int, int]:
    """Return (bytes, files), never following directory/file symlinks."""

    total = 0
    files = 0
    if not root.exists():
        return 0, 0
    stack = [root]
    while stack:
        current = stack.pop()
        with os.scandir(current) as entries:
            for entry in entries:
                try:
                    if entry.is_symlink():
                        continue
                    if entry.is_dir(follow_symlinks=False):
                        stack.append(Path(entry.path))
                    elif entry.is_file(follow_symlinks=False):
                        try:
                            total += int(entry.stat(follow_symlinks=False).st_size)
                            files += 1
                        except FileNotFoundError:
                            # MT5 can rotate a file between scandir and stat.
                            continue
                except FileNotFoundError:
                    continue
    return total, files


def snapshot(mt5_root: Path, terminal: str) -> dict[str, Any]:
    """Measure the disk-consuming tick roots for one isolated terminal slot."""

    tester_root = _terminal_tester_root(mt5_root, terminal)
    try:
        if not tester_root.is_dir():
            raise FileNotFoundError(str(tester_root))
        roots = [tester_root / "bases"]
        roots.extend(
            sorted(
                (
                    child
                    for child in tester_root.iterdir()
                    if child.is_dir() and child.name.startswith("Agent-")
                ),
                key=lambda path: path.name.casefold(),
            )
        )
        total = 0
        files = 0
        for cache_root in roots:
            root_bytes, root_files = _tree_size_bytes(cache_root)
            total += root_bytes
            files += root_files
        free_bytes = int(shutil.disk_usage(tester_root).free)
        return {
            "ok": True,
            "cache_bytes": total,
            "file_count": files,
            "free_bytes": free_bytes,
            "roots": [str(path) for path in roots],
            "error": None,
        }
    except (OSError, ValueError) as exc:
        return {
            "ok": False,
            "cache_bytes": None,
            "file_count": None,
            "free_bytes": None,
            "roots": [],
            "error": f"{type(exc).__name__}:{exc}",
        }


def arm(
    mt5_root: Path,
    terminal: str,
    *,
    environ: Mapping[str, str] | None = None,
    disk_stop_gb: float = DEFAULT_DISK_STOP_GB,
    disk_stop_margin_gb: float = DEFAULT_DISK_STOP_MARGIN_GB,
) -> dict[str, Any]:
    """Create a JSON-serializable run state immediately before process spawn."""

    raw = str((os.environ if environ is None else environ).get(ENV_BUDGET_GB, "") or "").strip()
    budget_gb = configured_budget_gb(environ)
    if budget_gb is None:
        return {
            "schema": SCHEMA,
            "enabled": False,
            "configuration": "absent" if not raw else "invalid_or_non_positive",
            "environment_variable": ENV_BUDGET_GB,
        }

    measured = snapshot(Path(mt5_root), terminal)
    configured_bytes = int(budget_gb * GIB)
    floor_bytes = int((float(disk_stop_gb) + float(disk_stop_margin_gb)) * GIB)
    baseline = measured.get("cache_bytes") if measured.get("ok") else None
    initial_free = measured.get("free_bytes") if measured.get("ok") else None
    floor_allowance = (
        max(0, int(initial_free) - floor_bytes)
        if initial_free is not None
        else configured_bytes
    )
    return {
        "schema": SCHEMA,
        "enabled": True,
        "environment_variable": ENV_BUDGET_GB,
        "configured_budget_bytes": configured_bytes,
        "effective_budget_bytes": min(configured_bytes, floor_allowance),
        "disk_stop_bytes": int(float(disk_stop_gb) * GIB),
        "disk_stop_margin_bytes": int(float(disk_stop_margin_gb) * GIB),
        "disk_guard_floor_bytes": floor_bytes,
        "mt5_root": str(Path(mt5_root)),
        "terminal": str(terminal).strip().upper(),
        "baseline_cache_bytes": baseline,
        "initial_free_bytes": initial_free,
        "last_cache_bytes": baseline,
        "last_free_bytes": initial_free,
        "peak_growth_bytes": 0,
        "minimum_free_bytes": initial_free,
        "samples": 1 if measured.get("ok") else 0,
        "sample_errors": 0 if measured.get("ok") else 1,
        "last_error": measured.get("error"),
        "roots": measured.get("roots") or [],
        "baseline_source": "pre_spawn" if measured.get("ok") else "unavailable_pre_spawn",
    }


def sample(state: dict[str, Any]) -> dict[str, Any]:
    """Update an armed state and return a trip decision (measurement fail-open)."""

    if not state.get("enabled"):
        return {"tripped": False, "enabled": False}
    measured = snapshot(Path(str(state["mt5_root"])), str(state["terminal"]))
    if not measured.get("ok"):
        state["sample_errors"] = int(state.get("sample_errors") or 0) + 1
        state["last_error"] = measured.get("error")
        return {
            "tripped": False,
            "enabled": True,
            "measurement_ok": False,
            "error": measured.get("error"),
        }

    current = int(measured["cache_bytes"])
    free = int(measured["free_bytes"])
    baseline = state.get("baseline_cache_bytes")
    if baseline is None:
        baseline = current
        state["baseline_cache_bytes"] = current
        state["baseline_source"] = "late_first_valid_sample"
        # A late baseline cannot reconstruct prior tree growth, but the global
        # free-space floor below still protects the 40 GB fleet stop.
        available = max(0, free - int(state["disk_guard_floor_bytes"]))
        state["effective_budget_bytes"] = min(
            int(state["configured_budget_bytes"]), available
        )
    growth = max(0, current - int(baseline))
    state["last_cache_bytes"] = current
    state["last_free_bytes"] = free
    state["peak_growth_bytes"] = max(int(state.get("peak_growth_bytes") or 0), growth)
    previous_minimum = state.get("minimum_free_bytes")
    state["minimum_free_bytes"] = (
        free if previous_minimum is None else min(int(previous_minimum), free)
    )
    state["samples"] = int(state.get("samples") or 0) + 1
    state["last_error"] = None

    effective_budget = int(state["effective_budget_bytes"])
    floor = int(state["disk_guard_floor_bytes"])
    growth_trip = growth >= effective_budget
    floor_trip = free <= floor
    trigger = (
        "disk_stop_reserve"
        if floor_trip
        else "growth_budget"
        if growth_trip
        else None
    )
    return {
        "tripped": bool(trigger),
        "enabled": True,
        "measurement_ok": True,
        "trigger": trigger,
        "verdict_reason": VERDICT_REASON if trigger else None,
        "cache_bytes": current,
        "baseline_cache_bytes": int(baseline),
        "growth_bytes": growth,
        "peak_growth_bytes": int(state["peak_growth_bytes"]),
        "configured_budget_bytes": int(state["configured_budget_bytes"]),
        "effective_budget_bytes": effective_budget,
        "free_bytes": free,
        "disk_guard_floor_bytes": floor,
        "disk_stop_bytes": int(state["disk_stop_bytes"]),
        "file_count": int(measured["file_count"]),
        "roots": list(measured.get("roots") or []),
    }
