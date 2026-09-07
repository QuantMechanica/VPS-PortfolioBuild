#!/usr/bin/env python
"""Benchmark idle ``claim_atomic`` passes on an isolated live-DB snapshot.

The source database is opened with SQLite ``mode=ro`` and copied using the
online backup API.  ``claim_atomic`` runs only against the disposable copy,
with deterministic zero-free-RAM fixtures that make every queued row
inadmissible.  No worker, tester, terminal, or production queue mutation is
performed.
"""

from __future__ import annotations

import argparse
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import statistics
import sys
import tempfile
import time
from typing import Any
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_ROOT = Path(__file__).resolve().parent
for import_root in (SCRIPT_ROOT, REPO_ROOT):
    if str(import_root) not in sys.path:
        sys.path.insert(0, str(import_root))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


SCHEMA = "qm.idle-claim-cache-benchmark/v1"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _copy_read_only_snapshot(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    uri = f"file:{source.resolve().as_posix()}?mode=ro"
    with sqlite3.connect(uri, uri=True, timeout=30.0) as src:
        src.execute("PRAGMA query_only=ON")
        with sqlite3.connect(destination) as dst:
            src.backup(dst)


def _percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * fraction))))
    return ordered[index]


def _summary(samples: list[dict[str, Any]]) -> dict[str, Any]:
    wall = [float(sample["wall_ms"]) for sample in samples]
    cpu = [float(sample["cpu_ms"]) for sample in samples]
    return {
        "calls": len(samples),
        "wall_ms_mean": round(statistics.fmean(wall), 3),
        "wall_ms_median": round(statistics.median(wall), 3),
        "wall_ms_p95": round(_percentile(wall, 0.95), 3),
        "cpu_ms_mean": round(statistics.fmean(cpu), 3),
        "cpu_ms_median": round(statistics.median(cpu), 3),
        "cpu_ms_p95": round(_percentile(cpu, 0.95), 3),
        "cache_hits": sum(bool(sample["cache_hit"]) for sample in samples),
        "samples": samples,
    }


def _run_calls(root: Path, terminal: str, iterations: int) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for index in range(iterations):
        wall_started = time.perf_counter()
        cpu_started = time.process_time()
        result = terminal_worker.claim_atomic(root, terminal)
        cpu_ms = (time.process_time() - cpu_started) * 1000.0
        wall_ms = (time.perf_counter() - wall_started) * 1000.0
        if result.get("claimed") or result.get("reason") != "no_pending_claimable":
            raise RuntimeError(f"benchmark_fixture_not_idle:{result}")
        samples.append(
            {
                "index": index + 1,
                "wall_ms": round(wall_ms, 3),
                "cpu_ms": round(cpu_ms, 3),
                "cache_hit": bool(result.get("idle_claim_cache_hit")),
            }
        )
    return samples


def _deterministic_idle_patches(stack: ExitStack) -> None:
    stack.enter_context(
        mock.patch.object(
            farmctl, "_news_calendar_preflight", return_value={"ok": True}
        )
    )
    stack.enter_context(mock.patch.object(terminal_worker, "_free_ram_gb", return_value=0.0))
    stack.enter_context(
        mock.patch.object(terminal_worker, "_commit_headroom_gb", return_value=10_000.0)
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_process_private_snapshot", return_value=({}, {}, set()))
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_multisymbol_ea_ids", return_value=frozenset())
    )
    stack.enter_context(mock.patch.object(terminal_worker, "_drain_window_enabled", return_value=False))
    stack.enter_context(
        mock.patch.object(
            terminal_worker, "_active_terminal_claim_preflight", return_value={"ready": True}
        )
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_watchdog_reset_admission_blocked", return_value=False)
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_claim_spacing_remaining_seconds", return_value=0.0)
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_census_first_ram_priority_enabled", return_value=False)
    )
    stack.enter_context(
        mock.patch.object(terminal_worker, "_p2_history_claimable", return_value=(True, None))
    )
    stack.enter_context(mock.patch.object(farmctl, "terminal_reservation", return_value=None))
    stack.enter_context(
        mock.patch.object(terminal_worker.opt_census_pruning, "pruning_enabled", return_value=False)
    )
    stack.enter_context(
        mock.patch.object(
            terminal_worker.longrun_scheduling_policy, "policy_enabled", return_value=False
        )
    )
    stack.enter_context(
        mock.patch.object(terminal_worker.custom_history_gate, "load_activation", return_value=None)
    )
    # The copied production schema is already initialized.  Avoid even
    # idempotent DDL so byte identity can prove this fixture remained read-only.
    stack.enter_context(
        mock.patch.object(terminal_worker, "_ensure_claim_db_initialized", return_value=None)
    )


def benchmark(source_db: Path, iterations: int, terminal: str, temp_parent: Path) -> dict[str, Any]:
    if iterations < 1:
        raise ValueError("iterations must be >= 1")
    if not source_db.is_file():
        raise FileNotFoundError(source_db)
    temp_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="qm_idle_claim_cache_", dir=temp_parent, ignore_cleanup_errors=True
    ) as temp_dir:
        root = Path(temp_dir) / "farm"
        clone_db = root / farmctl.DB_REL
        _copy_read_only_snapshot(source_db, clone_db)
        clone_before = _sha256(clone_db)
        with sqlite3.connect(f"file:{clone_db.as_posix()}?mode=ro", uri=True) as conn:
            conn.execute("PRAGMA query_only=ON")
            queue_counts = {
                str(status): int(count)
                for status, count in conn.execute(
                    "SELECT status,COUNT(*) FROM work_items GROUP BY status"
                )
            }

        with ExitStack() as stack:
            _deterministic_idle_patches(stack)

            terminal_worker._IDLE_CLAIM_CACHE.clear()
            farmctl._CLAIM_ORDER_CACHE.clear()
            farmctl._reset_claim_order_pollers()
            stack.enter_context(
                mock.patch.dict(
                    os.environ,
                    {terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV: "0"},
                )
            )
            baseline = _run_calls(root, terminal, iterations)

        with ExitStack() as stack:
            _deterministic_idle_patches(stack)
            terminal_worker._IDLE_CLAIM_CACHE.clear()
            farmctl._CLAIM_ORDER_CACHE.clear()
            farmctl._reset_claim_order_pollers()
            stack.enter_context(
                mock.patch.dict(
                    os.environ,
                    {
                        terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV: str(
                            terminal_worker.IDLE_CLAIM_CACHE_MAX_TTL_SECONDS
                        )
                    },
                )
            )
            # Warm the exact negative result outside the measured hit series.
            warmup = _run_calls(root, terminal, 1)[0]
            cached = _run_calls(root, terminal, iterations)

        terminal_worker._IDLE_CLAIM_CACHE.clear()
        farmctl._CLAIM_ORDER_CACHE.clear()
        farmctl._reset_claim_order_pollers()
        clone_after = _sha256(clone_db)

    baseline_summary = _summary(baseline)
    cached_summary = _summary(cached)
    baseline_cpu = float(baseline_summary["cpu_ms_median"])
    cached_cpu = float(cached_summary["cpu_ms_median"])
    reduction = 0.0 if baseline_cpu <= 0 else 100.0 * (baseline_cpu - cached_cpu) / baseline_cpu
    baseline_wall = float(baseline_summary["wall_ms_median"])
    uncached_cycle_seconds = terminal_worker.POLL_SLEEP_SECONDS + baseline_wall / 1000.0
    cached_cycle_seconds = terminal_worker.IDLE_CLAIM_CACHE_MAX_TTL_SECONDS + baseline_wall / 1000.0
    uncached_core_percent = 100.0 * (baseline_cpu / 1000.0) / uncached_cycle_seconds
    cached_core_percent = 100.0 * (baseline_cpu / 1000.0) / cached_cycle_seconds
    return {
        "schema": SCHEMA,
        "source_db": str(source_db.resolve()),
        "source_open_mode": "sqlite_uri_mode_ro_query_only",
        "fixture": "online_backup; zero-free-RAM; no candidate admissible; no spawn",
        "terminal": terminal,
        "queue_counts": queue_counts,
        "iterations": iterations,
        "cache_ttl_seconds": terminal_worker.IDLE_CLAIM_CACHE_MAX_TTL_SECONDS,
        "claim_latency_upper_bound_seconds": (
            terminal_worker.IDLE_CLAIM_CACHE_MAX_TTL_SECONDS
            + terminal_worker.POLL_SLEEP_SECONDS
        ),
        "warmup": warmup,
        "cache_disabled": baseline_summary,
        "cache_enabled_hits": cached_summary,
        "median_cpu_reduction_percent": round(reduction, 3),
        "projected_idle_worker_cpu_one_core_percent": {
            "cache_disabled": round(uncached_core_percent, 3),
            "cache_enabled_steady_state": round(cached_core_percent, 3),
            "reduction_percent": round(
                0.0
                if uncached_core_percent <= 0.0
                else 100.0
                * (uncached_core_percent - cached_core_percent)
                / uncached_core_percent,
                3,
            ),
            "method": (
                "median process CPU per full negative pass divided by full-pass wall "
                "+ 2 s poll cadence (disabled), or + 8 s memo lifetime (enabled)"
            ),
        },
        "clone_db_sha256_before": clone_before,
        "clone_db_sha256_after": clone_after,
        "clone_db_sha256_unchanged": clone_before == clone_after,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-db",
        type=Path,
        default=Path("D:/QM/strategy_farm/state/farm_state.sqlite"),
    )
    parser.add_argument("--iterations", type=int, default=5)
    parser.add_argument("--terminal", default="T_BENCH")
    parser.add_argument("--temp-parent", type=Path, default=Path("D:/QM/tmp"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = benchmark(args.source_db, args.iterations, args.terminal, args.temp_parent)
        result["status"] = "PASS"
        code = 0
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as exc:
        result = {"schema": SCHEMA, "status": "FAIL", "error": f"{type(exc).__name__}: {exc}"}
        code = 2
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    print(rendered, end="")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
