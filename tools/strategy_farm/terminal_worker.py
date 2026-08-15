#!/usr/bin/env python
"""Long-running per-terminal worker for QM strategy_farm.

Usage:
    python terminal_worker.py --terminal T1
"""

from __future__ import annotations

import argparse
import atexit
import errno
import faulthandler
import hashlib
import json
import math
import os
import random
import shutil
import signal
import sqlite3
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# ``terminal_worker.py`` is launched by absolute path from the long-running
# worker starter.  In that execution mode Python adds this file's directory to
# ``sys.path``, but not the repository root, so imports from ``framework`` fail
# unless the parent process happens to provide PYTHONPATH.  Make the documented
# direct entry point self-contained before importing repository packages.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

import farmctl
import custom_history_contract
import custom_history_copy_on_claim
import custom_history_gate
import custom_history_lease
import custom_history_master
from framework.scripts._phase_utils import cold_cache_summary_signature
from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag


POLL_SLEEP_SECONDS = 2.0
CUSTOM_HISTORY_GUARD_SLEEP_SECONDS = 30.0
CUSTOM_HISTORY_GATE_PASS_STATUSES = frozenset(
    {"PASS_ISOLATED", "PASS_SERIALIZED_ROLLBACK"}
)
CUSTOM_HISTORY_COPY_PASS_STATUSES = frozenset(
    {"PASS_PRIVATIZED", "SKIPPED_OWNER_ROLLBACK_TOPOLOGY"}
)
# DL-085: these audit findings self-heal — torn family link counts reconcile
# on re-audit, manifest gaps repair from the verified master tree. They defer
# one claim attempt; only master loss or a non-benign topology finding may
# stop the whole fleet.
CUSTOM_HISTORY_BENIGN_FINDING_CODES = (
    frozenset({"ARCHIVE_LINK_COUNT_TOO_LOW"})
    | custom_history_master.REPAIRABLE_FINDING_CODES
)
# Administrative defers release the claim without a run; their reason string
# carries the gate's own fail-closed token and must never feed the run-result
# stop-condition text scan (2026-08-14 11:18Z containment trip).
CUSTOM_HISTORY_GATE_DEFER_ACTIONS = frozenset(
    {
        "custom_history_gate_deferred",
        "custom_history_copy_on_claim_deferred",
        "custom_history_post_copy_gate_deferred",
    }
)
FACTORY_ADMISSION_LOCK_TIMEOUT_SECONDS = 5.0
FACTORY_ADMISSION_LOCK_POLL_SECONDS = 0.01
NEWS_CALENDAR_GUARD_SLEEP_SECONDS = 30.0
MAX_WORK_ITEM_RETRIES = 3
# Disk circuit-breaker (2026-06-19 incident): if free space on the runtime drive
# drops below this, workers must NOT claim+run backtests (MT5 fails ticks
# generation with "no disk space" -> fleet-wide INFRA_FAIL). Pause + trigger the
# cache-purge task instead of burning the queue.
DISK_MIN_FREE_GB = 40.0
DISK_GUARD_SLEEP_SECONDS = 60
DISK_PURGE_TASK = "QM_StrategyFarm_TesterCachePurge"
_DISK_PURGE_COOLDOWN_SECONDS = 600.0
_last_disk_purge_trigger = [0.0]
# RAM circuit-breaker (2026-06-22 incident): heavy real-tick backtests use ~6-7GB
# RAM each. When too many run concurrently, free RAM hits ~0 and the NEXT terminal64
# cannot allocate at startup -> it instant-exits in ~0.05s, logged as launch_fault,
# burning the queue to INFRA_FAIL without ever running. Don't claim+launch when free
# RAM is below this floor — let the in-flight terminals finish and release RAM first.
# This dynamically caps concurrency by RAM availability (complements the static
# terminal cap in start_terminal_workers disabled_terminals.txt). Fail-open.
# OWNER 2026-08-15 ("warten, bis die Situation sich nachhaltig verbessert hat"):
# the floor is a two-threshold hysteresis latch. Once a worker observes free RAM
# below RAM_MIN_FREE_GB it keeps deferring claims until free RAM has recovered to
# RAM_RESUME_FREE_GB — a single sample above the trip floor is not sustained
# improvement (an ordinary job allocates 6-7GB right after launch, and single
# testers have been observed at 46.8GB working set, 2026-08-15 T6 SP500).
RAM_MIN_FREE_GB = 6.0
RAM_RESUME_FREE_GB = 12.0
RAM_GUARD_SLEEP_SECONDS = 20
# CPU admission (OWNER 2026-08-15): don't add testers while the box is already
# compute-saturated. The load sample is a GetSystemTimes delta over the whole
# previous worker-loop iteration (>= POLL_SLEEP_SECONDS), so a trip is a
# sustained average, not an instantaneous spike. Same hysteresis shape as RAM.
# Deliberate throughput tradeoff: with multi-threaded tick-generation testers
# the box saturates below 10 slots; pacing claims to sustained CPU headroom is
# OWNER's call over maximal slot occupancy.
CPU_MAX_LOAD_PERCENT = 97.0
CPU_RESUME_LOAD_PERCENT = 90.0
CPU_GUARD_SLEEP_SECONDS = 20
# Fleet-wide claim stagger (OWNER 2026-08-15: "Die Worker müssen nach und nach
# starten"): at most one successful claim per CLAIM_SPACING_SECONDS across all
# workers, checked atomically against claim_class_ledger inside BEGIN IMMEDIATE.
# Each new tester's real memory footprint is then visible to the commit/RAM
# admission gates before the next launch — no post-restart thundering herd.
CLAIM_SPACING_SECONDS = 60.0
# Per-worker resource hysteresis latches (process-local; workers are resident).
_RESOURCE_LATCH = {"ram_low": False, "cpu_high": False}
# Free physical RAM did not expose the 2026-07-23 failure mode: Windows still
# had RAM available while system commit was close enough to its limit that new
# processes failed with 0xC0000142.  Gate new claims on commit headroom too.
# Ordinary real-tick jobs typically consume ~6-7GB; 24GB leaves room for the
# claim-to-launch race between several worker daemons. Commit probe errors pause
# admission briefly and retry; they must not bypass this crash-prevention gate.
COMMIT_MIN_FREE_GB = 24.0
COMMIT_GUARD_SLEEP_SECONDS = 20
# A claim becomes visible in SQLite before its child has allocated the real-tick
# working set. Reserve its expected peak during that launch/warm-up window so
# other workers cannot all pass against the same unchanged OS measurement.
COMMIT_RESERVATION_SECONDS = 300
# Throttle ledger for claim-decline logging: reason -> monotonic timestamp.
# 2026-08-10: factory_mutation_lock_busy declines were fully silent, hiding a
# wedged restart window behind an idle-looking fleet for 40 minutes.
_UNCLAIMED_DECLINE_LOG_LAST: dict[str, float] = {}
ORDINARY_COMMIT_RESERVATION_GB = 8.0
WATCHDOG_RESET_BLOCK_FILENAME = "WATCHDOG_RESET_PENDING.json"
# Multi-symbol real-tick jobs need materially more launch headroom than ordinary
# single-symbol jobs. A low-memory launch can generate a syntactically valid
# MT5 report with 0 bars and get misclassified as symbol history failure.
MULTISYMBOL_RAM_MIN_FREE_GB = 12.0
# Observed multi-symbol working sets range from 20-44GB.  Keep that worst case
# plus a small system margin available before admitting another heavy job.
MULTISYMBOL_COMMIT_MIN_FREE_GB = 48.0
# Commit reservations are calibrated from per-run maxima in the worker's
# decaying reservation telemetry (2026-07-26 through 2026-08-04). Exact
# two-symbol FX pairs observed p95/max 7.36GB; 3-9-symbol FX baskets observed
# p95 24.81GB and max 28.23GB. Unknown, 10+-symbol, and non-FX baskets stay in
# the 44GB fail-safe class (observed p95 34.99GB, max 38.52GB).
MULTISYMBOL_TWO_LEG_FX_COMMIT_RESERVATION_GB = 8.0
MULTISYMBOL_MULTI_LEG_FX_COMMIT_RESERVATION_GB = 32.0
MULTISYMBOL_COMMIT_RESERVATION_GB = 44.0
MULTISYMBOL_COMMIT_CLASS_ORDINARY = "ordinary"
MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX = "two_leg_fx_pair"
MULTISYMBOL_COMMIT_CLASS_MULTI_LEG_FX = "multi_leg_fx_basket"
MULTISYMBOL_COMMIT_CLASS_HEAVY = "heavy_or_unknown_multisymbol"
MULTISYMBOL_HEAVY_SYMBOL_COUNT = 10
# Single-symbol INDEX real-tick jobs are not "ordinary": dense index tick
# years privately commit far beyond the 8GB ordinary class (metatester64
# observed at 45.7GB private / 46.8GB WS on SP500 Q02, 2026-08-15). The 44GB
# reservation plus the 24GB effective-headroom floor hard-serializes index
# monsters (two can never stack against the 122.6GB commit limit) while
# ordinary jobs keep flowing beside one.
COMMIT_CLASS_SINGLE_INDEX_TICK = "single_index_tick"
SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB = 44.0
# DWX index universe seen in farm dispatch; extend with evidence, not guesses.
INDEX_TICK_SYMBOL_BASES = frozenset({"GDAXI", "SP500", "WS30", "NDX", "UK100"})
# Legacy source-scanned EAs do not carry basket_symbols in their old work-item
# payloads. Keep this narrow and host-specific: the audited QM5_11240 FX hosts
# each exercise one two-leg FX sleeve; its metal/index hosts remain heavy.
_AUDITED_LEGACY_TWO_LEG_FX_HOSTS: dict[str, frozenset[str]] = {
    "QM5_11240": frozenset({
        "AUDUSD.DWX",
        "EURUSD.DWX",
        "GBPUSD.DWX",
        "NZDUSD.DWX",
    }),
}
_FX_CURRENCIES = frozenset({"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"})
# A multisymbol loader materializes its working set over tens of minutes, so the
# ordinary 300s window expires long before it stops growing and other jobs get
# admitted into the balloon phase (2026-07-26 17:45 pagefile storm). Holding the
# window open is only safe because the reservation decays against measured
# usage — see _commit_admission_snapshot; a flat hold double-counts and starves
# the fleet (reverted 347859ad3).
MULTISYMBOL_COMMIT_RESERVATION_SECONDS = 3600
# Launch-fault guard (2026-06-20): the spawned phase-runner child vanishing far
# faster than any real backtest (terminal64 startup + sync alone is ~6-10s) means
# the run never actually started — a transient pwsh/host launch fault, NOT a clean
# exit. Don't record it as exit_code=0 (success), and back off so a host hiccup
# can't burn a whole re-fed batch through all its retries in seconds (observed
# 2026-06-19: 250 work_items INFRA_FAIL in 14s).
LAUNCH_FAULT_MIN_SECONDS = 10.0
LAUNCH_FAULT_BACKOFF_SECONDS = 30.0
# A report-missing run can be MT5 history error [32]: the just-used portable
# terminal profile still owns a custom-symbol history file.  Immediate retries
# on that same slot deterministically burn the row's retry budget.  Give the
# profile time to release its handles and route the retry to another slot.
SUMMARY_MISSING_RETRY_COOLDOWN_SECONDS = 30.0
# History-lock STORM (2026-07-21 diagnosis, refined by the QM5_20007 diagnosis on
# 2026-08-02). A FINISHED pass can lose its report when the terminal profile hits a
# history sharing violation during pass-end re-sync. This is a separate transient
# retry class, but it is safe only when the token is bound to the CURRENT work item.
# Every run_smoke launch writes the exact work-item UUID in its tester.ini path to the
# terminal log. Detection below requires that marker and scans only text after its
# last occurrence; absent binding fails open to ordinary summary-missing handling.
HISTORY_LOCK_STORM_TOKENS = (
    "history synchronization error",
    "some error after pass finished",
)
# Hard cap on transient auto-heal retries before falling through to a real INFRA_FAIL
# for manual attention (never loop forever). 6 is deliberately > the 3-terminal
# MAX_WORK_ITEM_RETRIES: with per-retry terminal steering each attempt avoids the
# previously-sick terminal, so 6 attempts can walk past the worst-case sick fraction of
# the ~10-terminal fleet and still terminate deterministically. These retries are
# counted on a SEPARATE payload key (transient_infra_attempts) and never touch
# attempt_count, so a real strategy failure that later occurs still has its full budget.
TRANSIENT_INFRA_RETRY_CAP = 6
TRANSIENT_INFRA_BACKOFF_BASE_SECONDS = 45.0
TRANSIENT_INFRA_BACKOFF_MAX_SECONDS = 600.0
# Never read a whole MT5 log — a storm terminal can produce a multi-GB log-bomb
# (T9 07-19: 1.6 GB). Scan only the tail of the most recently-written logs.
HISTORY_LOCK_SCAN_TAIL_BYTES = 256 * 1024
HISTORY_LOCK_SCAN_MAX_FILES = 6
# farmctl's run_smoke launcher always supplies -Year 2024. Q03 intentionally
# omits an explicit window, so run_smoke resolves that year to these dates.
# Evidence binding must freeze the same resolved window instead of persisting
# null expected dates (which makes every valid run_smoke/v2 summary fail closed).
DEFAULT_RUN_SMOKE_YEAR = 2024
# Log-bomb guard. Some EAs spam the MT5 tester journal per-tick (framework
# symbol_slot resolver logging on every tick), producing 50-60GB .log files that
# burn D: at ~10GB/min — that is a BUG to kill. But a legit multi-position /
# basket EA (e.g. QM5_12823 pyramid, the T-WIN 7-leg basket) logs the tester's
# own order/deal/SL lines and grows SLOWLY to ~0.5-2GB over a 7-yr run — that is
# NOT a bomb. The old absolute 512MB cap killed both (2026-06-30 incident: 12823
# killed at exactly 0.5GB; its 6-mo prescreen passed). Fix (2026-06-30): trigger
# on GROWTH RATE (catches the ~10GB/min spam in one check window) with a high
# absolute HARD-CEILING backstop (bounds disk for a slow-but-unbounded grower).
# See ops_issue f6769583 + project_qm_magic_resolver_race_2026-06-30.
LOG_BOMB_RATE_MB_PER_MIN = 1500.0             # >> any legit EA's journal growth (~50-200 MB/min);
                                              # << the per-tick spam (~10000 MB/min)
LOG_BOMB_HARD_CEIL_BYTES = 4 * 1024 ** 3      # 4 GB absolute backstop (disk safety; 4x7 terminals = 28GB worst case)
LOG_BOMB_JOURNAL_CAP_BYTES = LOG_BOMB_HARD_CEIL_BYTES  # back-compat alias (kill-record field)
LOG_BOMB_CHECK_EVERY_ITERS = 5                # ~every 10s (loop sleeps 2s)
SQLITE_WRITE_RETRIES = 12
SQLITE_WRITE_RETRY_SLEEP_SECONDS = 1.5
# run_smoke can spend up to 240 seconds publishing a report after terminal_exit.
# The outer worker therefore waits through that complete contract plus 60 seconds
# of margin before treating the wrapper as stalled. A 60-second ceiling destroyed
# valid GDAXI handoffs before summary.json could be published (2026-08-02 diagnosis).
SMOKE_TERMINAL_EXIT_GRACE_SECONDS = 300.0
# A latched report can still need several minutes of deterministic parser/logger
# post-processing before summary.json is atomically published.  QM5_1257 produced
# a valid report at 08:39Z and its identity-bound summary at 08:46Z; the ordinary
# five-minute watchdog released the row in between and caused a duplicate retry.
# Keep the short grace for true no-report exits, but give an explicit report latch
# enough bounded time to finish evidence publication.
SMOKE_VALID_REPORT_POSTPROCESS_GRACE_SECONDS = 1200.0
DETACHED_TERMINAL_POLL_SECONDS = 2.0
SQLITE_LOCK_BACKOFF_SECONDS = 10.0
STALLDUMP_REQUEST_PATH = Path("D:/QM/reports/state/STALLDUMP_REQUEST")
STALLDUMP_DIR = Path("D:/QM/reports/state/worker_stalldump")
# Launch-admission gate (2026-06-22): concurrent terminal64 DLL-init contends on a
# session-global resource (desktop heap / CSRSS). When N workers launch terminal64 in
# the same ~8s init window, some fail 0xC0000142 -> the 0.05s "launch_fault". An
# ISOLATED launch always succeeds, so the cure is to serialize the *init window* (not
# the whole minutes-long backtest). TTL leaky-semaphore: drop a timestamped lock file,
# proceed only when fewer than MAX recent locks exist; files age out after the window
# (crash-safe — a dead worker never blocks others) and the gate is fail-open (never
# blocks the factory if anything goes wrong or the wait times out).
LAUNCH_GATE_DIR = Path("D:/QM/strategy_farm/state/launch_slots")
LAUNCH_GATE_WINDOW_SECONDS = 15.0         # terminal64 startup+DLL-init window to protect
LAUNCH_GATE_MAX_CONCURRENT = 1            # max overlapping inits (override: launch_gate_max.txt)
LAUNCH_GATE_WAIT_TIMEOUT_SECONDS = 90.0   # fail-open after this so the factory never stalls
LAUNCH_FAULT_DEFER_SECONDS = 300.0        # host launch storm: defer without burning retries
LAUNCH_FAULT_DEFER_MAX_SECONDS = 3600.0   # repeated launch storms should not thrash the queue

_STOP = False


def _handle_stop(_signum: int, _frame: object) -> None:
    global _STOP
    _STOP = True


def _json_loads(text: str | None) -> dict[str, Any]:
    if not text:
        return {}
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def _resolved_evidence_window(spawn: dict[str, Any]) -> tuple[str | None, str | None]:
    """Return the exact run_smoke window used for evidence binding."""
    from_date = spawn.get("expected_from_date")
    to_date = spawn.get("expected_to_date")
    if spawn.get("evidence_binding_required") and not from_date and not to_date:
        year = int(spawn.get("year") or DEFAULT_RUN_SMOKE_YEAR)
        return f"{year:04d}.01.01", f"{year:04d}.12.31"
    return from_date, to_date


def _parse_utc_iso(value: object) -> datetime | None:
    if not value:
        return None
    try:
        text = str(value).replace("Z", "+00:00")
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def _launch_fault_count(value: object) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def _launch_fault_defer_seconds(previous_fault_count: object) -> float:
    previous_faults = _launch_fault_count(previous_fault_count)
    return min(
        LAUNCH_FAULT_DEFER_SECONDS * (2 ** min(previous_faults, 8)),
        LAUNCH_FAULT_DEFER_MAX_SECONDS,
    )


def _with_sqlite_retry(fn):
    for attempt in range(1, SQLITE_WRITE_RETRIES + 1):
        try:
            return fn()
        except sqlite3.OperationalError as exc:
            if "locked" not in str(exc).lower() or attempt == SQLITE_WRITE_RETRIES:
                raise
            time.sleep(min(30.0, SQLITE_WRITE_RETRY_SLEEP_SECONDS * attempt) + random.random())
    raise RuntimeError("unreachable sqlite retry state")


def _is_sqlite_locked(exc: sqlite3.OperationalError) -> bool:
    return "locked" in str(exc).lower()


def _start_stalldump_watcher(terminal: str) -> None:
    """Dump all Python thread stacks when the watchdog asks for stall evidence."""

    def _watch() -> None:
        last_request: tuple[int, int] | None = None
        while True:
            try:
                if STALLDUMP_REQUEST_PATH.exists():
                    stat = STALLDUMP_REQUEST_PATH.stat()
                    request_key = (stat.st_mtime_ns, stat.st_size)
                    if request_key != last_request:
                        last_request = request_key
                        STALLDUMP_DIR.mkdir(parents=True, exist_ok=True)
                        dump_path = STALLDUMP_DIR / f"{terminal}_{os.getpid()}.txt"
                        stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                        with dump_path.open("a", encoding="utf-8") as fh:
                            fh.write(f"\n===== STALLDUMP {stamp} terminal={terminal} pid={os.getpid()} =====\n")
                            fh.flush()
                            faulthandler.dump_traceback(file=fh, all_threads=True)
                            fh.flush()
                else:
                    last_request = None
            except Exception:
                pass
            time.sleep(5.0)

    thread = threading.Thread(target=_watch, name="stalldump_watcher", daemon=True)
    thread.start()


def _priority_pending_query() -> str:
    # ULTRACODE WS-A (2026-07-26): the pending-work ordering now lives in ONE place —
    # farmctl.pending_claim_order_sql — shared by this production claimant AND the
    # farmctl.dispatch_work_items secondary claimant, so the two can never diverge.
    # It preserves the previous priority_track/phase/basket/winner/asset ordering
    # EXACTLY and only prepends a recovery-last rank (inert until rows are tagged).
    # The recovery idle-cap is applied in claim_atomic below, not in SQL.
    return farmctl.pending_claim_order_sql()


TERMINAL_NO_SYMBOL_HISTORY_REASON = "TERMINAL_NO_SYMBOL_HISTORY_FOR_PERIOD"


def _source_terminal_set(value: object) -> set[str]:
    if isinstance(value, (list, tuple, set, frozenset)):
        return {str(v).strip().upper() for v in value if str(v).strip()}
    return {part.strip().upper() for part in str(value or "").split(",") if part.strip()}


def _work_item_value(item: sqlite3.Row | dict[str, Any], key: str, default: object = None) -> object:
    try:
        return item[key]
    except (IndexError, KeyError, TypeError):
        if isinstance(item, dict):
            return item.get(key, default)
        return default


def _work_item_test_period(item: sqlite3.Row | dict[str, Any], payload: dict[str, Any]) -> str:
    period = str(payload.get("host_timeframe") or payload.get("period") or "").strip().upper()
    if not period:
        try:
            period = farmctl._detect_ea_period(
                str(_work_item_value(item, "ea_id", "")),
                str(_work_item_value(item, "setfile_path", "") or ""),
            )
        except Exception:
            period = ""
    return period


def _work_item_test_symbol(item: sqlite3.Row | dict[str, Any], payload: dict[str, Any]) -> str:
    return str(payload.get("host_symbol") or _work_item_value(item, "symbol", "") or "").strip().upper()


def _unique_symbols(values: list[object]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for value in values:
        text = str(value or "").strip().upper()
        if not text or text in seen:
            continue
        seen.add(text)
        out.append(text)
    return out


def _payload_basket_manifest(payload: dict[str, Any], ea_id: str) -> dict[str, Any] | None:
    manifest_path = str(payload.get("basket_manifest") or "").strip()
    if manifest_path:
        try:
            path = Path(manifest_path)
            if path.exists():
                return json.loads(path.read_text(encoding="utf-8-sig"))
        except Exception:
            pass
    try:
        return farmctl._load_basket_manifest(ea_id)
    except Exception:
        return None


def _work_item_history_symbols(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
) -> list[str]:
    symbols: list[object] = [payload.get("host_symbol") or _work_item_value(item, "symbol", "")]
    for field in ("basket_symbols", "conversion_symbols"):
        payload_symbols = payload.get(field)
        if isinstance(payload_symbols, list):
            symbols.extend(payload_symbols)

    is_basket = (
        str(payload.get("portfolio_scope") or "").strip().lower() == "basket"
        or bool(payload.get("basket_manifest"))
        or str(payload.get("basket_symbol_count") or "").strip() not in {"", "0", "1"}
    )
    if is_basket:
        manifest = _payload_basket_manifest(payload, str(_work_item_value(item, "ea_id", "") or ""))
        if manifest:
            symbols.append(manifest.get("host_symbol"))
            manifest_symbols = manifest.get("basket_symbols")
            if isinstance(manifest_symbols, list):
                symbols.extend(manifest_symbols)
            manifest_conversion = manifest.get("conversion_symbols")
            if isinstance(manifest_conversion, list):
                symbols.extend(manifest_conversion)

    return _unique_symbols(symbols)


def _p2_history_claimable(
    item: sqlite3.Row | dict[str, Any],
    terminal: str | None = None,
    registry: dict[tuple[str, str], dict[str, Any]] | None = None,
) -> tuple[bool, dict[str, Any] | None]:
    payload = _json_loads(str(_work_item_value(item, "payload_json", "") or ""))
    phase = str(_work_item_value(item, "phase", "") or "").upper()
    symbol = _work_item_test_symbol(item, payload)
    period = _work_item_test_period(item, payload)
    if not period:
        return True, None
    registry = farmctl._dwx_symbol_history_registry() if registry is None else registry

    window: dict[str, Any] | None = None
    if phase in {"P2", "Q02"}:
        setfile_path = str(_work_item_value(item, "setfile_path", "") or "")
        is_exploration = any(token in setfile_path for token in ("_ablation_", "_grid_", "_synth_"))
        default_from_year = 2020 if is_exploration else farmctl.P2_DEFAULT_FROM_YEAR
        from_year = int(payload.get("from_year") or default_from_year)
        to_year = int(payload.get("to_year") or farmctl.P2_DEFAULT_TO_YEAR)
        window = farmctl._p2_history_window_for_symbol(symbol, period, from_year, to_year, registry)
        if window.get("skip"):
            return False, window

    if not terminal:
        return True, window
    terminal_key = str(terminal).strip().upper()
    required_symbols = _work_item_history_symbols(item, payload)
    for required_symbol in required_symbols:
        if not required_symbol.endswith(".DWX"):
            continue
        source_terminals = _source_terminal_set(registry.get((required_symbol, period), {}).get("source_terminals"))
        if not source_terminals or terminal_key in source_terminals:
            continue
        return False, {
            **(window or {}),
            "skip": True,
            "reason": TERMINAL_NO_SYMBOL_HISTORY_REASON,
            "symbol": required_symbol,
            "period": period,
            "terminal": terminal_key,
            "source_terminals": sorted(source_terminals),
            "history_check_symbols": required_symbols,
        }
    return True, window


def _merge_history_window_payload(payload: dict[str, Any], history: dict[str, Any] | None) -> None:
    """Persist a non-skipped history window so the runner uses the guarded dates."""
    if not history or history.get("skip"):
        return
    if "from_year" not in history or "to_year" not in history:
        return
    payload["from_year"] = history["from_year"]
    payload["to_year"] = history["to_year"]
    if "requested_from_year" in history:
        payload["requested_from_year"] = history["requested_from_year"]
    if "requested_to_year" in history:
        payload["requested_to_year"] = history["requested_to_year"]
    if "first_year" in history:
        payload["history_first_year"] = history["first_year"]
    if "last_year" in history:
        payload["history_last_year"] = history["last_year"]
    if history.get("adjusted"):
        payload["history_adjusted"] = True
        payload["history_adjustment_source"] = "terminal_worker_claim"


MULTISYMBOL_REGISTRY_PATH = Path("D:/QM/strategy_farm/state/multisymbol_eas.txt")
_multisym_cache: dict[str, Any] = {
    "mtime": -1.0,
    "ids": frozenset(),
    "loaded": False,
}


class MultisymbolRegistryUnavailable(RuntimeError):
    """The safety-critical registry is unavailable and has no valid cache."""


def _multisymbol_ea_ids() -> frozenset:
    """EA ids that load MULTIPLE symbols' history (basket / cross-sectional /
    relative-momentum). In the real-tick tester each such backtest loads EVERY
    member symbol's full tick history -> 20-44GB working set (vs ~6-7GB for a
    normal single-symbol EA). Running several concurrently spikes system commit
    to the pagefile/commit limit (~122GB) -> CreateProcess fails (0xC0000142) ->
    launch_fault wedge (2026-06-24 incident, EA QM5_1218 = 44GB x3 = 90GB).

    Populated by scanning EA .mq5 for basket markers (g_symbols[], QM_Basket,
    _SYMBOL_COUNT, Strategy_GroupMembers). Cached, refreshed on file mtime
    change. A transient read failure reuses the last valid cache; without one,
    admission fails closed because treating a legacy multisymbol EA as ordinary
    can recreate the commit-exhaustion incident this registry prevents.
    """
    try:
        st = MULTISYMBOL_REGISTRY_PATH.stat().st_mtime
        if st != _multisym_cache["mtime"]:
            ids = frozenset(
                ln.strip().split()[0]
                for ln in MULTISYMBOL_REGISTRY_PATH.read_text(encoding="utf-8").splitlines()
                if ln.strip() and not ln.lstrip().startswith("#")
            )
            if not ids:
                raise ValueError("multisymbol registry is empty")
            _multisym_cache["mtime"] = st
            _multisym_cache["ids"] = ids
            _multisym_cache["loaded"] = True
        return _multisym_cache["ids"]
    except Exception as exc:
        if _multisym_cache.get("loaded"):
            return _multisym_cache["ids"]
        raise MultisymbolRegistryUnavailable(
            f"multisymbol registry unavailable: {exc!r}"
        ) from exc


def _watchdog_reset_admission_blocked(root: Path) -> bool:
    """Block new claims until Factory_ON explicitly completes the handover.

    This is intentionally not time-based. A delayed or hung Factory_ON must
    never let admissions resume and then kill work it did not see in the fresh
    pre-reset snapshot. The next watchdog run can remove a provably orphaned
    pre-handover marker; Factory_ON removes a live marker only after terminating
    the old worker/terminal fleet.
    """

    marker = root / "state" / WATCHDOG_RESET_BLOCK_FILENAME
    try:
        return marker.exists()
    except OSError:
        # An unreadable marker path is safety-significant, but should pause the
        # worker cleanly rather than crash its long-running loop.
        return True


def _work_item_is_multisymbol(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    multisym_ids: frozenset,
) -> bool:
    """True when a work item loads more than its chart symbol's history.

    `state/multisymbol_eas.txt` is a runtime hint, but build-time basket
    work_items already carry durable payload markers. Treat those payload
    markers as authoritative so newly built basket EAs are protected even when
    the runtime hint file has not been refreshed yet.
    """

    ea_id = str(_work_item_value(item, "ea_id", "") or "")
    if ea_id in multisym_ids:
        return True
    if str(payload.get("portfolio_scope") or "").strip().lower() == "basket":
        return True
    if str(payload.get("basket_manifest") or "").strip():
        return True
    try:
        return int(payload.get("basket_symbol_count") or 0) > 1
    except (TypeError, ValueError):
        return False


def _is_fx_symbol(symbol: Any) -> bool:
    canonical = str(symbol or "").strip().upper().split(".", 1)[0]
    return (
        len(canonical) == 6
        and canonical[:3] in _FX_CURRENCIES
        and canonical[3:] in _FX_CURRENCIES
    )


def _multisymbol_commit_class(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    multisymbol: bool,
) -> str:
    """Return the measured reservation class, defaulting unknowns to heavy.

    Only a complete, internally consistent ``basket_symbols`` list can lower a
    multisymbol reservation. A bare count or malformed list is not enough: an
    unclassified item must retain the historical 44GB fail-safe reservation.
    Non-multisymbol items refine into the index-tick class when the host
    symbol is a dense-tick index (COMMIT_CLASS_SINGLE_INDEX_TICK).
    """

    if not multisymbol:
        host = str(
            _work_item_value(item, "symbol", "") or payload.get("host_symbol") or ""
        ).strip().upper()
        if host.split(".")[0] in INDEX_TICK_SYMBOL_BASES:
            return COMMIT_CLASS_SINGLE_INDEX_TICK
        return MULTISYMBOL_COMMIT_CLASS_ORDINARY

    raw_symbols = payload.get("basket_symbols")
    if isinstance(raw_symbols, list):
        symbols = tuple(str(value or "").strip().upper() for value in raw_symbols)
        if symbols and all(symbols):
            try:
                declared_count = int(payload.get("basket_symbol_count") or len(symbols))
            except (TypeError, ValueError):
                declared_count = -1
            if declared_count != len(symbols):
                return MULTISYMBOL_COMMIT_CLASS_HEAVY
            if len(symbols) == 2 and all(_is_fx_symbol(symbol) for symbol in symbols):
                return MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX
            if (
                3 <= len(symbols) < MULTISYMBOL_HEAVY_SYMBOL_COUNT
                and all(_is_fx_symbol(symbol) for symbol in symbols)
            ):
                return MULTISYMBOL_COMMIT_CLASS_MULTI_LEG_FX
            return MULTISYMBOL_COMMIT_CLASS_HEAVY

    ea_id = str(_work_item_value(item, "ea_id", "") or "").strip().upper()
    host_symbol = str(
        _work_item_value(item, "symbol", "") or payload.get("host_symbol") or ""
    ).strip().upper()
    if host_symbol in _AUDITED_LEGACY_TWO_LEG_FX_HOSTS.get(ea_id, frozenset()):
        return MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX
    return MULTISYMBOL_COMMIT_CLASS_HEAVY


def _commit_reservation_gb(commit_class: str) -> float:
    if commit_class == MULTISYMBOL_COMMIT_CLASS_ORDINARY:
        return ORDINARY_COMMIT_RESERVATION_GB
    if commit_class == COMMIT_CLASS_SINGLE_INDEX_TICK:
        return SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB
    if commit_class == MULTISYMBOL_COMMIT_CLASS_TWO_LEG_FX:
        return MULTISYMBOL_TWO_LEG_FX_COMMIT_RESERVATION_GB
    if commit_class == MULTISYMBOL_COMMIT_CLASS_MULTI_LEG_FX:
        return MULTISYMBOL_MULTI_LEG_FX_COMMIT_RESERVATION_GB
    return MULTISYMBOL_COMMIT_RESERVATION_GB


_PROCESS_SNAPSHOT_TTL_SECONDS = 3.0
_process_snapshot_cache: dict[str, Any] = {
    "at": -1e9, "children": {}, "private": {}, "alive": set(),
}


def _process_private_snapshot() -> tuple[dict[int, list[int]], dict[int, int], set[int]]:
    """(children-by-parent-pid, private-commit-bytes-by-pid, all-live-pids).

    Toolhelp32 + psapi via ctypes: the admission gate runs on every poll of every
    worker, so the PowerShell-based probes in ``farmctl`` (hundreds of ms each)
    are unusable here. Cached for ``_PROCESS_SNAPSHOT_TTL_SECONDS`` because nine
    workers poll independently. Returns empty maps on any failure — callers must
    treat that as "unknown", never as "zero usage".

    ``alive`` carries every pid Toolhelp32 reported, including those whose
    ``OpenProcess`` failed. Without it a running-but-unreadable process is
    indistinguishable from a dead one (Codex review 2026-07-26).
    """
    now = time.monotonic()
    if now - _process_snapshot_cache["at"] < _PROCESS_SNAPSHOT_TTL_SECONDS:
        return (_process_snapshot_cache["children"],
                _process_snapshot_cache["private"],
                _process_snapshot_cache["alive"])
    children: dict[int, list[int]] = {}
    private: dict[int, int] = {}
    alive: set[int] = set()
    if sys.platform != "win32":
        return children, private, alive
    try:
        import ctypes
        from ctypes import wintypes

        class _PROCESSENTRY32W(ctypes.Structure):
            _fields_ = [
                ("dwSize", wintypes.DWORD),
                ("cntUsage", wintypes.DWORD),
                ("th32ProcessID", wintypes.DWORD),
                ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)),
                ("th32ModuleID", wintypes.DWORD),
                ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD),
                ("pcPriClassBase", ctypes.c_long),
                ("dwFlags", wintypes.DWORD),
                ("szExeFile", ctypes.c_wchar * 260),
            ]

        class _PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
            _fields_ = [
                ("cb", wintypes.DWORD),
                ("PageFaultCount", wintypes.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t),
                ("PrivateUsage", ctypes.c_size_t),
            ]

        kernel32 = ctypes.windll.kernel32
        psapi = ctypes.windll.psapi
        TH32CS_SNAPPROCESS = 0x00000002
        INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        PROCESS_VM_READ = 0x0010

        snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        if snapshot == INVALID_HANDLE_VALUE:
            return children, private, alive
        try:
            entry = _PROCESSENTRY32W()
            entry.dwSize = ctypes.sizeof(_PROCESSENTRY32W)
            more = kernel32.Process32FirstW(snapshot, ctypes.byref(entry))
            pids: list[tuple[int, int]] = []
            while more:
                pids.append((int(entry.th32ProcessID), int(entry.th32ParentProcessID)))
                more = kernel32.Process32NextW(snapshot, ctypes.byref(entry))
        finally:
            kernel32.CloseHandle(snapshot)

        for pid, ppid in pids:
            children.setdefault(ppid, []).append(pid)
            alive.add(pid)
            handle = kernel32.OpenProcess(
                PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, False, pid
            )
            if not handle:
                handle = kernel32.OpenProcess(
                    PROCESS_QUERY_LIMITED_INFORMATION, False, pid
                )
            if not handle:
                continue
            try:
                counters = _PROCESS_MEMORY_COUNTERS_EX()
                counters.cb = ctypes.sizeof(_PROCESS_MEMORY_COUNTERS_EX)
                if psapi.GetProcessMemoryInfo(
                    handle, ctypes.byref(counters), counters.cb
                ):
                    private[pid] = int(counters.PrivateUsage)
            finally:
                kernel32.CloseHandle(handle)
    except Exception:
        return {}, {}, set()

    _process_snapshot_cache["at"] = now
    _process_snapshot_cache["children"] = children
    _process_snapshot_cache["private"] = private
    _process_snapshot_cache["alive"] = alive
    return children, private, alive


def _measured_subtree_gb(pid: Any) -> float | None:
    """Private commit (GB) held by ``pid`` and every descendant, or None.

    Walks the children map rather than the live parent links: a phase driver's
    Python parent often exits while its run_smoke/pwsh child keeps running, and
    Windows leaves the dead parent's id in the child's PPID field, so the
    subtree stays discoverable. None means "could not measure" — the caller then
    keeps the full reservation instead of assuming the job uses nothing.
    """
    try:
        root_pid = int(pid)
    except (TypeError, ValueError):
        return None
    children, private, alive = _process_private_snapshot()
    if not alive:
        return None
    total = 0
    seen: set[int] = set()
    queue = [root_pid]
    any_alive = False
    any_readable = False
    while queue:
        current = queue.pop()
        if current in seen:
            continue
        seen.add(current)
        if current in alive:
            any_alive = True
        if current in private:
            total += private[current]
            any_readable = True
        queue.extend(children.get(current, ()))
    if not any_alive:
        # No process of this lineage exists any more: the job is over, so there
        # is no future growth left to reserve for.
        return float("inf")
    if not any_readable:
        # The lineage IS running but every OpenProcess failed (access denied,
        # protected or exiting process). Codex review 2026-07-26 (33a18bb2e):
        # the earlier version could not tell this apart from a vanished tree and
        # released the reservation for a job that was still allocating — exactly
        # the over-admission this mechanism exists to prevent. Unknown must stay
        # unknown, so the caller keeps the full reservation.
        return None
    return total / (1024 ** 3)


def _commit_admission_snapshot(
    conn: sqlite3.Connection,
    now_iso: str,
    multisym_ids: frozenset,
) -> dict[str, Any]:
    """Measure commit headroom minus the *unmaterialized* part of active claims.

    Windows' commit charge does not jump at SQLite claim time. Without a durable
    reservation, every worker can observe the same headroom and over-admit work
    before any child reaches its peak. Active claims therefore reserve their
    expected peak — but only the portion that has not been allocated yet:

        reservation = max(0, expected_peak - measured_subtree_private_bytes)

    The OS commit measurement already contains whatever a running job has really
    taken, so reserving its full peak on top of that double-counts it. Holding a
    flat 44GB for a ballooning multisymbol job pinned the entire fleet below the
    admission threshold on a box with 64GB free (2026-07-26, reverted in
    347859ad3). Decaying against the measurement keeps the launch-race
    protection at full strength (nothing allocated yet -> full reservation) and
    fades to zero once the job is at peak, which is what lets the window stay
    open for the whole balloon phase instead of expiring mid-growth.
    """
    live_headroom = _commit_headroom_gb()
    probe_ok = math.isfinite(live_headroom) or (
        sys.platform != "win32" and math.isinf(live_headroom) and live_headroom > 0
    )
    now_dt = _parse_utc_iso(now_iso) or datetime.now(timezone.utc)
    reservations: list[dict[str, Any]] = []
    reserved_gb = 0.0
    rows = conn.execute(
        "SELECT id, ea_id, symbol, payload_json FROM work_items WHERE status='active'"
    ).fetchall()
    for row in rows:
        payload = _json_loads(row["payload_json"])
        item_is_multisym = _work_item_is_multisymbol(row, payload, multisym_ids)
        window_seconds = (
            MULTISYMBOL_COMMIT_RESERVATION_SECONDS
            if item_is_multisym
            else COMMIT_RESERVATION_SECONDS
        )
        until = _parse_utc_iso(payload.get("commit_reservation_until_utc"))
        claimed_at = _parse_utc_iso(payload.get("claimed_at_iso"))
        if until is None and claimed_at is not None:
            until = claimed_at + timedelta(seconds=window_seconds)
        if until is None or until <= now_dt:
            continue
        commit_class = _multisymbol_commit_class(row, payload, item_is_multisym)
        default_reservation = _commit_reservation_gb(commit_class)
        try:
            expected_peak_gb = max(
                0.0,
                float(payload.get("commit_reservation_gb") or default_reservation),
            )
        except (TypeError, ValueError):
            expected_peak_gb = default_reservation
        # Decay the reservation against what the job has already allocated; the
        # live headroom above already accounts for that part.
        pid = payload.get("pid")
        measured_gb = _measured_subtree_gb(pid) if pid else None
        if measured_gb is None:
            # Not spawned yet, or the probe failed: keep the full peak reserved.
            reservation_gb = expected_peak_gb
        else:
            reservation_gb = max(0.0, expected_peak_gb - measured_gb)
        reserved_gb += reservation_gb
        reservations.append({
            "item_id": row["id"],
            "ea_id": row["ea_id"],
            "reservation_gb": round(reservation_gb, 2),
            "expected_peak_gb": expected_peak_gb,
            "reservation_class": commit_class,
            "measured_gb": (
                None
                if measured_gb is None or math.isinf(measured_gb)
                else round(measured_gb, 2)
            ),
            "until_utc": until.isoformat(),
        })
    return {
        "probe_ok": probe_ok,
        "live_headroom_gb": live_headroom if probe_ok else None,
        "reserved_gb": reserved_gb,
        "effective_headroom_gb": live_headroom - reserved_gb if probe_ok else None,
        "reservations": reservations,
    }


def _set_commit_reservation(
    payload: dict[str, Any],
    *,
    claimed_at_iso: str,
    multisymbol: bool,
    commit_class: str | None = None,
) -> None:
    claimed_at = _parse_utc_iso(claimed_at_iso) or datetime.now(timezone.utc)
    if commit_class is None:
        commit_class = (
            MULTISYMBOL_COMMIT_CLASS_HEAVY
            if multisymbol
            else MULTISYMBOL_COMMIT_CLASS_ORDINARY
        )
    payload["commit_reservation_class"] = commit_class
    payload["commit_reservation_gb"] = _commit_reservation_gb(commit_class)
    payload["commit_reservation_until_utc"] = (
        claimed_at
        + timedelta(
            seconds=(
                MULTISYMBOL_COMMIT_RESERVATION_SECONDS
                if multisymbol
                else COMMIT_RESERVATION_SECONDS
            )
        )
    ).isoformat()


def _payload_avoid_terminals(payload: dict[str, Any]) -> set[str]:
    """Return factory terminals this item must not be claimed by."""
    raw = payload.get("avoid_terminals", payload.get("skip_terminals", []))
    if isinstance(raw, str):
        values = [raw]
    elif isinstance(raw, (list, tuple, set)):
        values = list(raw)
    else:
        values = []
    terminals: set[str] = set()
    for value in values:
        terminal = str(value or "").strip().upper()
        if farmctl.is_factory_terminal_name(terminal):
            terminals.add(terminal)
    if payload.get("diagnostic_non_admission") is True:
        allowed_raw = payload.get("diagnostic_allowed_terminals", [])
        allowed = {str(value or "").strip().upper() for value in allowed_raw}
        terminals.update({f"T{index}" for index in range(1, 11)} - allowed)
    return terminals


_STALE_RUNTIME_PAYLOAD_KEYS = (
    "pid",
    "started_at_iso",
    "log_path",
    "claimed_at_iso",
    "claimed_by_worker_pid",
    "commit_reservation_gb",
    "commit_reservation_class",
    "commit_reservation_until_utc",
    "terminal",
)


def _clear_stale_runtime_payload(payload: dict[str, Any]) -> None:
    for field in _STALE_RUNTIME_PAYLOAD_KEYS:
        payload.pop(field, None)


def _defer_news_calendar_preflight(
    root: Path,
    row: sqlite3.Row | dict[str, Any],
    terminal: str,
    calendar: dict[str, Any],
) -> dict[str, Any]:
    """Release a pre-spawn claim without consuming attempt/claim capacity."""
    payload = _json_loads(row["payload_json"])
    claimed_at = payload.get("claimed_at_iso")
    _clear_stale_runtime_payload(payload)
    for field in ("claim_stage", "targeted_factory_off_run", "staged_ex5"):
        payload.pop(field, None)
    now = farmctl.utc_now()

    def _release() -> bool:
        with farmctl.connect(root) as conn:
            conn.execute("BEGIN IMMEDIATE")
            cur = conn.execute(
                """
                UPDATE work_items
                SET status='pending', verdict=NULL, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (
                    json.dumps(payload, sort_keys=True),
                    now,
                    row["id"],
                    terminal,
                ),
            )
            if cur.rowcount == 1:
                farmctl.retract_claim_ledger(
                    conn,
                    terminal,
                    row["id"],
                    str(claimed_at) if claimed_at else None,
                )
            conn.commit()
            return cur.rowcount == 1

    released = bool(_with_sqlite_retry(_release))
    return {
        "status": "pending" if released else str(row.get("status", "active") if isinstance(row, dict) else row["status"]),
        "reason": f"NEWS_CALENDAR_{calendar.get('status')}",
        "calendar_preflight_blocked": True,
        "claim_released": released,
        "attempt_count_unchanged": True,
        "principal": calendar.get("principal"),
        "common_dir": calendar.get("common_dir"),
        "news_calendar_preflight": calendar,
    }


def _defer_custom_history_gate(
    root: Path,
    row: sqlite3.Row | dict[str, Any],
    terminal: str,
    gate: dict[str, Any],
) -> dict[str, Any]:
    """Release an isolation-blocked claim without consuming retry capacity."""

    payload = _json_loads(row["payload_json"])
    claimed_at = payload.get("claimed_at_iso")
    _clear_stale_runtime_payload(payload)
    for field in ("claim_stage", "targeted_factory_off_run", "staged_ex5"):
        payload.pop(field, None)
    payload["custom_history_gate_failure"] = gate
    now = farmctl.utc_now()

    def _release() -> bool:
        with farmctl.connect(root) as conn:
            conn.execute("BEGIN IMMEDIATE")
            cur = conn.execute(
                """
                UPDATE work_items
                SET status='pending', verdict=NULL, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (json.dumps(payload, sort_keys=True), now, row["id"], terminal),
            )
            if cur.rowcount == 1:
                farmctl.retract_claim_ledger(
                    conn,
                    terminal,
                    row["id"],
                    str(claimed_at) if claimed_at else None,
                )
            conn.commit()
            return cur.rowcount == 1

    released = bool(_with_sqlite_retry(_release))
    return {
        "status": "pending" if released else "active",
        "reason": "CUSTOM_HISTORY_ISOLATION_FAIL_CLOSED",
        "claim_released": released,
        "attempt_count_unchanged": True,
        "custom_history_gate": gate,
    }


# Windows resource-exhaustion I/O failures: ERROR_NOT_ENOUGH_MEMORY (8),
# ERROR_OUTOFMEMORY (14), ERROR_NO_SYSTEM_RESOURCES (1450),
# ERROR_COMMITMENT_LIMIT (1455). Deliberately narrow — device/corruption
# OSErrors must keep engaging containment.
_RESOURCE_EXHAUSTION_WINERRORS = frozenset({8, 14, 1450, 1455})


def _is_transient_gate_io_error(exc: BaseException) -> bool:
    """Concurrency/resource artifacts of the gate, not isolation breaches.

    A running terminal's MT5 holds privatized archives write-open (sharing
    violation → PermissionError) and copy-on-claim swaps files atomically
    (FileNotFoundError mid-scan). MemoryError joined 2026-08-14: an audit under
    tester RAM pressure ran out of memory and engaged fleet-wide containment
    (reason custom_history_gate_exception:MemoryError, 10:04Z) although no
    integrity fact was in question. Resource-exhaustion OSErrors joined the
    same day: winerror 1450 ("Insufficient system resources", surfaced as
    OSError errno 22) tripped containment at 18:11Z under 8-wide tester load.
    All of these defer THIS claim attempt only; engaging fleet-wide
    containment for them serializes the factory.
    """

    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(current, (PermissionError, FileNotFoundError, MemoryError)):
            return True
        if isinstance(current, OSError) and (
            getattr(current, "winerror", None) in _RESOURCE_EXHAUSTION_WINERRORS
            or current.errno == errno.ENOMEM
        ):
            return True
        current = current.__cause__ or current.__context__
    return False


def _custom_history_gate(
    root: Path,
    terminal: str,
    *,
    required_symbols: list[str] | None = None,
    allow_required_restore: bool = False,
) -> dict[str, Any]:
    """Run the activation-bound gate; every error is a dispatch refusal."""

    try:
        gate_kwargs: dict[str, Any] = {"terminal": terminal}
        if required_symbols is not None:
            gate_kwargs["required_symbols"] = required_symbols
            gate_kwargs["allow_required_restore"] = allow_required_restore
        gate = custom_history_gate.run_worker_gate(root, **gate_kwargs)
    except Exception as exc:
        activation_file = custom_history_gate.activation_path(root)
        try:
            activation_hash = hashlib.sha256(activation_file.read_bytes()).hexdigest()
        except OSError:
            activation_hash = "0" * 64
        if _is_transient_gate_io_error(exc):
            return {
                "required": True,
                "status": "FAIL_CLOSED",
                "terminal": terminal,
                "reason": "custom_history_gate_transient_io",
                "error": repr(exc),
                "activation_sha256": activation_hash,
            }
        try:
            custom_history_lease.engage_emergency_mode(
                root,
                reason=f"custom_history_gate_exception:{type(exc).__name__}",
                activation_sha256=activation_hash,
            )
        except Exception:
            pass
        return {
            "required": True,
            "status": "FAIL_CLOSED",
            "terminal": terminal,
            "reason": "custom_history_gate_exception",
            "error": repr(exc),
            "activation_sha256": activation_hash,
        }
    if (
        gate.get("required")
        and gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
        and _custom_history_gate_fail_is_emergency(gate)
    ):
        try:
            custom_history_lease.engage_emergency_mode(
                root,
                reason="custom_history_isolation_gate_failure",
                activation_sha256=str(gate.get("activation_sha256") or "0" * 64),
            )
        except Exception:
            pass
    return gate


def _custom_history_gate_fail_is_emergency(gate: dict[str, Any]) -> bool:
    """DL-085: containment is for master loss, not for self-healing audits.

    A failing audit whose findings are all benign classes (torn family link
    counts, manifest gaps the master tree repairs) defers this claim attempt
    only. The fleet-wide emergency stop engages when the master tree cannot
    vouch for content (repair status ERROR/PARTIAL) or a finding outside the
    benign classes appears (cross-terminal alias, ACL, protected-root).
    Repair statuses ERROR_TRANSIENT_IO / PARTIAL_TRANSIENT_IO (every failure
    a copy race or resource artifact while the master vouches) deliberately
    stay outside the emergency set — they defer like any benign-only fail.
    """

    master_repair = gate.get("master_repair") or {}
    if str(master_repair.get("status") or "") in {"ERROR", "PARTIAL"}:
        return True
    findings = list(gate.get("findings") or [])
    return any(
        str(finding.get("code")) not in CUSTOM_HISTORY_BENIGN_FINDING_CODES
        for finding in findings
    )


def _custom_history_copy_receipt_path(root: Path, item_id: str, terminal: str) -> Path:
    safe_item_id = "".join(
        character if character.isalnum() or character in {"-", "_"} else "_"
        for character in str(item_id)
    )
    return (
        root
        / "artifacts"
        / "ops"
        / "custom_history_copy_on_claim"
        / f"{safe_item_id}_{str(terminal).upper()}.json"
    )


def _privatize_custom_history_claim(
    root: Path,
    row: sqlite3.Row | dict[str, Any],
    terminal: str,
    gate: dict[str, Any],
) -> dict[str, Any]:
    """Privatize the host plus declared conversion/basket archive set."""

    if not gate.get("required"):
        return {"required": False, "status": "NOT_ACTIVE", "terminal": terminal}
    if gate.get("status") == "PASS_SERIALIZED_ROLLBACK":
        return {
            "required": True,
            "status": "SKIPPED_OWNER_ROLLBACK_TOPOLOGY",
            "terminal": terminal,
        }
    activation_sha256 = str(gate.get("activation_sha256") or "0" * 64)
    try:
        activation = custom_history_gate.load_activation(root)
        if activation is None:
            raise custom_history_copy_on_claim.CustomHistoryCopyOnClaimError(
                "activation disappeared after the pre-copy gate"
            )
        manifest = custom_history_contract.load_manifest(
            Path(activation["manifest_path"]), require_owner_approval=True
        )
        payload = _json_loads(str(_work_item_value(row, "payload_json", "") or ""))
        symbols = _work_item_history_symbols(row, payload)
        receipt_path = _custom_history_copy_receipt_path(
            root, str(_work_item_value(row, "id", "")), terminal
        )
        receipt = custom_history_copy_on_claim.privatize_terminal_archives(
            manifest=manifest,
            mt5_root=custom_history_gate.mt5_history_isolation.DEFAULT_MT5_ROOT,
            terminal=terminal,
            symbols=symbols,
            receipt_path=receipt_path,
            # DL-085: privatization reads come from the standalone verified
            # master tree, never from the cross-terminal shared family inode.
            farm_root=root,
        )
        return {
            "required": True,
            "status": receipt["status"],
            "terminal": str(terminal).upper(),
            "activation_sha256": activation_sha256,
            "manifest_sha256": receipt["manifest_sha256"],
            "symbols": receipt["symbols"],
            "ignored_non_custom_symbols": receipt["ignored_non_custom_symbols"],
            "selected_file_count": receipt["selected_file_count"],
            "copied_file_count": receipt["copied_file_count"],
            "restored_file_count": receipt["restored_file_count"],
            "already_private_file_count": receipt["already_private_file_count"],
            "pruned_file_count": receipt["pruned_file_count"],
            "already_pruned_file_count": receipt["already_pruned_file_count"],
            "receipt_sha256": receipt["receipt_sha256"],
            "receipt_path": receipt["receipt_path"],
            "receipt_file_sha256": receipt["receipt_file_sha256"],
        }
    except Exception as exc:
        # Sharing violations / mid-swap misses while other terminals' MT5
        # processes hold archives open are concurrency artifacts of THIS
        # attempt, not integrity breaches — defer without fleet containment
        # (same classification as the gate's transient-IO path).
        if not _is_transient_gate_io_error(exc):
            try:
                custom_history_lease.engage_emergency_mode(
                    root,
                    reason=f"custom_history_copy_on_claim_failure:{type(exc).__name__}",
                    activation_sha256=activation_sha256,
                )
            except Exception:
                pass
        return {
            "required": True,
            "status": "FAIL_CLOSED",
            "terminal": str(terminal).upper(),
            "reason": "custom_history_copy_on_claim_failure",
            "error": repr(exc),
            "activation_sha256": activation_sha256,
        }


def _reconcile_stale_custom_history_lease(
    root: Path, record: dict[str, Any]
) -> dict[str, Any]:
    """Prove terminal inactivity and database reconciliation before stale reap."""

    terminal = str(record.get("terminal") or "").upper()
    work_item_id = str(record.get("work_item_id") or "")
    try:
        terminal_inactive = terminal not in farmctl._running_mt5_terminals()
    except Exception:
        terminal_inactive = False
    released_claims: list[str] = []
    if terminal_inactive:
        try:
            released_claims = release_stale_claims_for_terminal(root, terminal)
        except Exception:
            released_claims = []
    claim_reconciled = False
    try:
        with farmctl.connect(root) as conn:
            if work_item_id:
                row = conn.execute(
                    "SELECT status,claimed_by FROM work_items WHERE id=?",
                    (work_item_id,),
                ).fetchone()
                claim_reconciled = row is None or not (
                    str(row["status"]) == "active"
                    and str(row["claimed_by"] or "").upper() == terminal
                )
            else:
                row = conn.execute(
                    "SELECT 1 FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1",
                    (terminal,),
                ).fetchone()
                claim_reconciled = row is None
    except Exception:
        claim_reconciled = False
    return {
        "terminal": terminal,
        "work_item_id": work_item_id or None,
        "terminal_inactive": terminal_inactive,
        "claim_reconciled": claim_reconciled,
        "released_stale_claims": released_claims,
    }


def _acquire_custom_history_lease(
    root: Path, terminal: str
) -> custom_history_lease.LeaseAcquireResult:
    return custom_history_lease.acquire_lease(
        root,
        terminal=terminal,
        reconcile_stale=lambda record: _reconcile_stale_custom_history_lease(
            root, dict(record)
        ),
    )


def _custom_history_stop_condition(result: dict[str, Any]) -> str | None:
    # DL-085: an administrative gate defer releases the claim without a run;
    # its reason string carries the gate's own fail-closed token, so scanning
    # it would re-trip fleet containment on every benign self-heal defer
    # (2026-08-14 11:18Z trip). Only real run results are scanned.
    if str(result.get("action") or "") in CUSTOM_HISTORY_GATE_DEFER_ACTIONS:
        return None
    text = json.dumps(result, sort_keys=True, default=str).casefold()
    tokens = {
        "history_error_32": ("error [32]", "error 32", "sharing_violation"),
        "history_sync_error": ("history synchronization error", "history synchronization abort"),
        "archive_drift": ("archive_manifest_mismatch", "archive hash drift", "archive write"),
        "missing_real_ticks_marker": (
            "missing_real_ticks_marker",
            "real_ticks_marker_missing",
            "real ticks marker missing",
        ),
        "isolation_gate": ("custom_history_isolation_fail_closed",),
    }
    for reason, values in tokens.items():
        if any(value in text for value in values):
            return reason
    return None


def _accumulate_avoid_terminal(payload: dict[str, Any], failed_terminal: str | None) -> list[str]:
    """Add a sick terminal to the item's avoid_terminals steering list.

    Guards against the list eating the whole fleet: if the accumulated set would
    exclude EVERY enabled factory terminal (which would make the item permanently
    unclaimable), it is cleared instead — the item retries anywhere rather than
    deadlocking. Fail-open on any enabled-terminal lookup error (keep the list).
    """
    avoid = _payload_avoid_terminals(payload)
    name = str(failed_terminal or "").strip().upper()
    if name and farmctl.is_factory_terminal_name(name):
        avoid.add(name)
    try:
        enabled = {t.upper() for t in farmctl.active_mt5_terminals()}
    except Exception:
        enabled = set()
    if enabled and enabled.issubset(avoid):
        if payload.get("diagnostic_non_admission") is True:
            allowed_raw = payload.get("diagnostic_allowed_terminals", [])
            allowed = {str(value or "").strip().upper() for value in allowed_raw}
            avoid = {f"T{index}" for index in range(1, 11)} - allowed
            payload["avoid_terminals"] = sorted(avoid)
            payload["avoid_terminals_cleared_reason"] = (
                "diagnostic_retry_hints_would_exclude_allowed_fleet"
            )
            return payload["avoid_terminals"]
        payload.pop("avoid_terminals", None)
        payload["avoid_terminals_cleared_reason"] = "would_exclude_whole_fleet"
        print(json.dumps({
            "event": "avoid_terminals_cleared",
            "reason": "would_exclude_whole_fleet",
            "avoid": sorted(avoid),
            "enabled": sorted(enabled),
        }, sort_keys=True), flush=True)
        return []
    payload["avoid_terminals"] = sorted(avoid)
    payload.pop("avoid_terminals_cleared_reason", None)
    return payload["avoid_terminals"]


def _transient_infra_backoff_seconds(prior_attempts: Any) -> float:
    """Exponential backoff (capped) for shared-bases history-lock transient retries."""
    try:
        n = int(prior_attempts)
    except (TypeError, ValueError):
        n = 0
    n = max(n, 0)
    delay = TRANSIENT_INFRA_BACKOFF_BASE_SECONDS * (2 ** n)
    return min(delay, TRANSIENT_INFRA_BACKOFF_MAX_SECONDS)


def _read_tail_bytes(path: Path, max_bytes: int) -> bytes:
    try:
        size = path.stat().st_size
        with open(path, "rb") as fh:
            if size > max_bytes:
                start = size - max_bytes
                if start % 2:  # keep UTF-16-LE code units aligned
                    start += 1
                fh.seek(start)
            return fh.read()
    except OSError:
        return b""


def _decode_log_tail(raw: bytes) -> str:
    if not raw:
        return ""
    # MT5 terminal/tester logs are UTF-16-LE (ASCII bytes interleaved with 0x00).
    sample = raw[:512]
    if sample.count(0) > len(sample) // 4:
        return raw.decode("utf-16-le", errors="ignore")
    return raw.decode("utf-8", errors="ignore")


def _detect_history_lock_storm(
    terminal: str | None,
    mt5_root: Path | None = None,
    *,
    work_item_id: str | None = None,
    started_at_iso: str | None = None,
) -> dict[str, Any] | None:
    """Return current-run history-lock evidence, else ``None``.

    The exact work-item UUID in the terminal's tester.ini launch marker is the
    evidence boundary. Only text after the marker's last occurrence is eligible;
    a prior run or prior-day tail can never classify the current claim. The scan
    remains bounded so a multi-GB storm log is never read whole. Any missing or
    unreadable binding fails open to ordinary summary-missing handling.
    """
    name = str(terminal or "").strip().upper()
    marker = str(work_item_id or "").strip().lower()
    if not name or not marker:
        return None
    root = mt5_root or farmctl.MT5_ROOT
    term_dir = root / name
    try:
        if not term_dir.is_dir():
            return None
    except OSError:
        return None
    candidates: list[Path] = []
    search_dirs = [term_dir / "logs", term_dir / "Tester" / "logs"]
    tester_dir = term_dir / "Tester"
    try:
        if tester_dir.is_dir():
            search_dirs.extend(sorted(tester_dir.glob("Agent-*/logs")))
    except OSError:
        pass
    for sub in search_dirs:
        try:
            if sub.is_dir():
                candidates.extend(p for p in sub.glob("*.log") if p.is_file())
        except OSError:
            continue
    if not candidates:
        return None

    def _mtime(p: Path) -> float:
        try:
            return p.stat().st_mtime
        except OSError:
            return 0.0

    started_at = _parse_utc_iso(started_at_iso)
    started_epoch = started_at.timestamp() - 2.0 if started_at is not None else None
    candidates.sort(key=_mtime, reverse=True)
    for path in candidates[:HISTORY_LOCK_SCAN_MAX_FILES]:
        mtime = _mtime(path)
        if started_epoch is not None and mtime < started_epoch:
            continue
        decoded = _decode_log_tail(_read_tail_bytes(path, HISTORY_LOCK_SCAN_TAIL_BYTES))
        text = decoded.lower()
        marker_at = text.rfind(marker)
        if marker_at < 0:
            continue
        current_run_text = text[marker_at:]
        for token in HISTORY_LOCK_STORM_TOKENS:
            token_at = current_run_text.find(token)
            if token_at < 0:
                continue
            absolute_at = marker_at + token_at
            line_start = decoded.rfind("\n", marker_at, absolute_at) + 1
            line_end = decoded.find("\n", absolute_at)
            if line_end < 0:
                line_end = len(decoded)
            matched_line = decoded[line_start:line_end].strip()
            return {
                "terminal": name,
                "token": token,
                "log_path": str(path),
                "matched_line": matched_line,
                "log_mtime_utc": datetime.fromtimestamp(
                    mtime, tz=timezone.utc
                ).isoformat(),
                "work_item_id": str(work_item_id),
            }
    return None


def _claim_queue_may_need_mutation(root: Path, terminal: str) -> bool:
    """Avoid an fsynced global lock when the claim queue is plainly empty.

    A false negative only delays a concurrently inserted item until the next
    worker poll: the real claim still performs complete transactional selection.
    Any DB, schema, or probe ambiguity returns ``True`` and takes the locked
    fail-closed path.
    """

    db_path = root / farmctl.DB_REL
    if not db_path.is_file():
        return True
    try:
        uri = f"file:{db_path.as_posix()}?mode=ro"
        with sqlite3.connect(uri, uri=True, timeout=1) as conn:
            row = conn.execute(
                """
                SELECT 1
                FROM work_items
                WHERE status='pending' OR (status='active' AND claimed_by=?)
                LIMIT 1
                """,
                (terminal,),
            ).fetchone()
        return row is not None
    except (OSError, sqlite3.Error):
        return True


def claim_atomic(root: Path, terminal: str) -> dict[str, Any]:
    """Atomically claim one pending work_item for a terminal.

    The transaction serializes competing worker daemons. A symbol already active
    anywhere in the farm blocks another item with the same symbol. Multi-symbol
    (basket) EAs are additionally serialized to AT MOST ONE active farm-wide, so
    their oversized tick-history working sets never stack and exhaust commit.
    Every new claim requires free system-commit headroom. Multi-symbol claims
    additionally require higher commit and physical-RAM headroom than ordinary
    single-symbol jobs to avoid process-start and allocator failures.
    """
    factory_off_flag = root / "state" / "FACTORY_OFF.flag"
    try:
        if factory_off_flag.exists():
            return {
                "claimed": False,
                "reason": "factory_off",
                "flag": str(factory_off_flag),
            }
    except OSError as exc:
        return {
            "claimed": False,
            "reason": "factory_admission_interlock_error",
            "flag": str(factory_off_flag),
            "error": str(exc),
        }

    # Read before opening the claim transaction. Cached stat-bound results keep
    # idle worker polling cheap; every actual spawn performs an uncached re-read.
    calendar_preflight = farmctl._news_calendar_preflight(use_cache=True)
    if calendar_preflight.get("ok") and not _claim_queue_may_need_mutation(root, terminal):
        return {
            "claimed": False,
            "reason": "no_pending_claimable",
            "history_skipped": [],
            "launch_cooldown_skipped": [],
            "multisymbol_ram_skipped": [],
            "multisymbol_commit_skipped": [],
            "terminal_avoid_skipped": [],
            "recovery_capped": [],
        }

    def _claim() -> dict[str, Any]:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        db_path = root / farmctl.DB_REL
        # Warm the process snapshot BEFORE taking the write lock. The admission
        # gate needs it, and a cold Toolhelp32+psapi scan costs ~8ms — which is
        # cheap in itself but must not be paid while holding BEGIN IMMEDIATE with
        # nine workers contending, least of all when the box is paging
        # (Codex review 2026-07-26, 33a18bb2e). Inside the transaction the call
        # is then a ~0.4us cache hit. Fail-open: errors are swallowed there.
        _process_private_snapshot()
        with sqlite3.connect(db_path, timeout=30) as conn:
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("BEGIN IMMEDIATE")
            try:
                active_terminal = conn.execute(
                    "SELECT * FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1",
                    (terminal,),
                ).fetchone()
                if active_terminal:
                    payload = _json_loads(active_terminal["payload_json"])
                    pid = payload.get("pid")
                    worker_pid = payload.get("claimed_by_worker_pid")
                    if worker_pid and not farmctl._pid_exists(worker_pid):
                        if pid and farmctl._pid_tree_exists(pid):
                            payload["prior_failure"] = payload.get("prior_failure") or "worker_process_missing_adopted_active_child"
                            payload["orphan_worker_pid"] = worker_pid
                            payload["orphan_child_adopted_at_iso"] = now
                            payload["claimed_by_worker_pid"] = os.getpid()
                            conn.execute(
                                """
                                UPDATE work_items
                                SET payload_json=?, updated_at=?
                                WHERE id=? AND status='active' AND claimed_by=?
                                """,
                                (json.dumps(payload, sort_keys=True), now, active_terminal["id"], terminal),
                            )
                            conn.commit()
                            row = conn.execute("SELECT * FROM work_items WHERE id=?", (active_terminal["id"],)).fetchone()
                            return {"claimed": True, "item": dict(row), "adopt_existing": True}

                        payload["prior_failure"] = payload.get("prior_failure") or "worker_process_missing_released_stale_claim"
                        terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
                        if terminal_stopped is not None:
                            payload["terminal_stopped_on_release"] = terminal_stopped
                        _clear_stale_runtime_payload(payload)
                        conn.execute(
                            """
                            UPDATE work_items
                            SET status='pending', verdict=NULL, claimed_by=NULL, payload_json=?, updated_at=?
                            WHERE id=? AND status='active' AND claimed_by=?
                            """,
                            (json.dumps(payload, sort_keys=True), now, active_terminal["id"], terminal),
                        )
                    elif worker_pid:
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "terminal_worker_busy",
                            "item_id": active_terminal["id"],
                            "worker_pid": worker_pid,
                        }
                    elif pid and farmctl._pid_tree_exists(pid):
                        conn.commit()
                        return {"claimed": False, "reason": "terminal_busy", "item_id": active_terminal["id"]}
                    else:
                        payload["prior_failure"] = payload.get("prior_failure") or "worker_loop_released_stale_claim"
                        terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
                        if terminal_stopped is not None:
                            payload["terminal_stopped_on_release"] = terminal_stopped
                        _clear_stale_runtime_payload(payload)
                        conn.execute(
                            """
                            UPDATE work_items
                            SET status='pending', verdict=NULL, claimed_by=NULL, payload_json=?, updated_at=?
                            WHERE id=? AND status='active' AND claimed_by=?
                            """,
                            (json.dumps(payload, sort_keys=True), now, active_terminal["id"], terminal),
                        )

                if not calendar_preflight.get("ok"):
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "news_calendar_preflight_failed",
                        "calendar_status": calendar_preflight.get("status"),
                        "principal": calendar_preflight.get("principal"),
                        "common_dir": calendar_preflight.get("common_dir"),
                        "news_calendar_preflight": calendar_preflight,
                    }

                if root.resolve() == farmctl.DEFAULT_ROOT.resolve() and terminal in farmctl._running_mt5_terminals():
                    conn.commit()
                    return {"claimed": False, "reason": "terminal_process_busy", "terminal": terminal}

                reservation = farmctl.terminal_reservation(root, terminal)
                if reservation:
                    decline = {
                        "event": "terminal_reservation_claim_declined",
                        "terminal": terminal,
                        "reserved_by": reservation["reserved_by"],
                        "until_utc": reservation["until_utc"],
                        "reason": reservation["reason"],
                    }
                    print(json.dumps(decline, sort_keys=True), flush=True)
                    conn.commit()
                    return {"claimed": False, **reservation, "reason": "terminal_reserved"}

                if _watchdog_reset_admission_blocked(root):
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "watchdog_reset_pending",
                        "terminal": terminal,
                    }

                # Fleet-wide claim stagger, atomic under this BEGIN IMMEDIATE:
                # the ledger read and the eventual claim commit cannot interleave
                # with another worker's, so exactly one worker wins each window.
                farmctl.ensure_claim_class_ledger(conn)
                last_claim_iso = conn.execute(
                    "SELECT MAX(claimed_at_utc) FROM claim_class_ledger"
                ).fetchone()[0]
                spacing_wait = _claim_spacing_remaining_seconds(last_claim_iso, now)
                if spacing_wait > 0:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "claim_spacing_wait",
                        "retry_after_seconds": round(spacing_wait, 1),
                        "last_claim_at_utc": last_claim_iso,
                    }

                try:
                    multisym_ids = _multisymbol_ea_ids()
                except MultisymbolRegistryUnavailable as exc:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "multisymbol_registry_unavailable",
                        "error": str(exc),
                    }
                admission = _commit_admission_snapshot(conn, now, multisym_ids)
                if not admission["probe_ok"]:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "commit_probe_failed",
                        "commit_reserved_gb": round(admission["reserved_gb"], 1),
                        "commit_reservation_count": len(admission["reservations"]),
                    }
                effective_commit_headroom = admission["effective_headroom_gb"]
                if effective_commit_headroom < COMMIT_MIN_FREE_GB:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "commit_headroom_low",
                        "commit_headroom_gb": round(admission["live_headroom_gb"], 1),
                        "commit_reserved_gb": round(admission["reserved_gb"], 1),
                        "effective_commit_headroom_gb": round(effective_commit_headroom, 1),
                        "commit_reservation_count": len(admission["reservations"]),
                        "commit_reservation_detail": admission["reservations"],
                        "threshold_gb": COMMIT_MIN_FREE_GB,
                    }

                active_symbol_counts, active_ea_symbol_pairs = farmctl._active_symbol_claim_state(conn)
                active_q04_eas = {
                    str(row["ea_id"])
                    for row in conn.execute(
                        "SELECT DISTINCT ea_id FROM work_items WHERE status='active' AND phase='Q04'"
                    )
                }
                # Multi-symbol (basket) serialization: at most ONE multi-symbol
                # backtest active farm-wide (their 20-44GB tick-history working
                # sets must not stack and exhaust commit). BEGIN IMMEDIATE (above)
                # makes this active-check + claim atomic across workers, so two
                # daemons can't both pass the gate. OWNER 2026-06-24.
                multisym_active = any(
                    _work_item_is_multisymbol(row, _json_loads(row["payload_json"]), multisym_ids)
                    for row in conn.execute("SELECT ea_id, payload_json FROM work_items WHERE status='active'")
                )
                skipped_history: list[dict[str, Any]] = []
                skipped_launch_cooldown: list[dict[str, Any]] = []
                skipped_multisym_ram: list[dict[str, Any]] = []
                skipped_multisym_commit: list[dict[str, Any]] = []
                skipped_avoid_terminal: list[dict[str, Any]] = []
                multisym_free_ram: float | None = None
                history_registry = farmctl._dwx_symbol_history_registry()
                # NOTE: do NOT refresh the poison-pill table here. Measured cost of
                # poison_pill_quarantine.refresh_pending() on the live DB is ~413ms
                # (full scan + one upsert per finding, 371 today), and this point is
                # inside BEGIN IMMEDIATE. Nine workers claiming every ~2s would demand
                # ~3.7s of write lock per 2s window and serialise the whole fleet.
                # The claim query already excludes quarantined rows through an indexed
                # NOT EXISTS on the table's primary key, so it only needs the table to
                # be CURRENT, not freshly rebuilt per claim — and farmctl's dispatch
                # path already refreshes it every pump cycle in its own transaction
                # (farmctl.py, before the free-terminal loop).
                # ULTRACODE WS-A (2026-07-26): recovery idle-cap. Recovery-class rows
                # sort LAST (pending_claim_order_sql _recovery_rank), so the loop only
                # reaches one after every eligible priority/frontier row was claimed
                # (→ returned) or skipped by a resource filter — i.e. the priority lane
                # is idle for this worker (Operating Rule 22, incl. the resource-filter
                # fallback). The durable rolling ledger then caps recovery to at most 1
                # of the last CLAIM_RECOVERY_WINDOW successful claims fleet-wide. The
                # decision is computed once (recovery rows are contiguous at the tail);
                # if capped, nothing else is claimable this cycle → stop.
                recovery_gate_checked = False
                recovery_allowed = False
                recovery_capped = False
                for item in conn.execute(_priority_pending_query()).fetchall():
                    payload = _json_loads(item["payload_json"])
                    item_is_recovery = farmctl.is_recovery_payload(payload)
                    if item_is_recovery:
                        if not recovery_gate_checked:
                            recovery_allowed = farmctl.recovery_claim_allowed(conn)
                            recovery_gate_checked = True
                        if not recovery_allowed:
                            recovery_capped = True
                            break
                    avoid_terminals = _payload_avoid_terminals(payload)
                    if str(terminal).upper() in avoid_terminals:
                        skipped_avoid_terminal.append({
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            "avoid_terminals": sorted(avoid_terminals),
                        })
                        continue
                    launch_not_before = _parse_utc_iso(payload.get("launch_not_before_utc"))
                    if launch_not_before is not None:
                        try:
                            now_dt = datetime.fromisoformat(now).astimezone(timezone.utc)
                        except ValueError:
                            now_dt = datetime.now(timezone.utc)
                        if launch_not_before > now_dt:
                            skipped_launch_cooldown.append({
                                "item_id": item["id"],
                                "launch_not_before_utc": launch_not_before.isoformat(),
                            })
                            continue
                    symbol_key = str(item["symbol"] or "").upper()
                    if symbol_key:
                        # Duplicate (ea_id, symbol) never runs twice concurrently
                        # (2026-05-18 crash shape); cross-EA same-symbol work is
                        # capped, not serialized, since Variant-A private Custom
                        # stores removed the shared-history hazard.
                        if (str(item["ea_id"]), symbol_key) in active_ea_symbol_pairs:
                            continue
                        if active_symbol_counts.get(symbol_key, 0) >= farmctl.CLAIM_SYMBOL_ACTIVE_CAP:
                            continue
                    if str(item["phase"]).upper() == "Q04" and str(item["ea_id"]) in active_q04_eas:
                        continue
                    # Skip a multi-symbol item while another multi-symbol backtest
                    # is already running anywhere in the farm (serialize the heavy
                    # basket loads). Non-multi-symbol items are unaffected.
                    item_is_multisym = _work_item_is_multisymbol(item, payload, multisym_ids)
                    if multisym_active and item_is_multisym:
                        continue
                    if item_is_multisym:
                        if effective_commit_headroom < MULTISYMBOL_COMMIT_MIN_FREE_GB:
                            skipped_multisym_commit.append({
                                "item_id": item["id"],
                                "ea_id": item["ea_id"],
                                "commit_headroom_gb": round(admission["live_headroom_gb"], 1),
                                "commit_reserved_gb": round(admission["reserved_gb"], 1),
                                "effective_commit_headroom_gb": round(effective_commit_headroom, 1),
                                "threshold_gb": MULTISYMBOL_COMMIT_MIN_FREE_GB,
                            })
                            continue
                        if multisym_free_ram is None:
                            multisym_free_ram = _free_ram_gb()
                        if multisym_free_ram < MULTISYMBOL_RAM_MIN_FREE_GB:
                            skipped_multisym_ram.append({
                                "item_id": item["id"],
                                "ea_id": item["ea_id"],
                                "free_ram_gb": round(multisym_free_ram, 1),
                                "threshold_gb": MULTISYMBOL_RAM_MIN_FREE_GB,
                            })
                            continue
                    history_ok, history = _p2_history_claimable(item, terminal, history_registry)
                    if not history_ok:
                        skipped_history.append({"item_id": item["id"], **(history or {})})
                        continue
                    _merge_history_window_payload(payload, history)
                    payload.update({
                        "claimed_at_iso": now,
                        "claimed_by_worker_pid": os.getpid(),
                        "terminal": terminal,
                    })
                    _set_commit_reservation(
                        payload,
                        claimed_at_iso=now,
                        multisymbol=item_is_multisym,
                        commit_class=_multisymbol_commit_class(item, payload, item_is_multisym),
                    )
                    cur = conn.execute(
                        """
                        UPDATE work_items
                        SET status='active', claimed_by=?, payload_json=?, updated_at=?
                        WHERE id=? AND status='pending'
                        """,
                        (terminal, json.dumps(payload, sort_keys=True), now, item["id"]),
                    )
                    if cur.rowcount == 1:
                        # Advance the durable claim-class ledger in the SAME
                        # BEGIN IMMEDIATE transaction as the claim so the fleet-wide
                        # recovery idle-cap read+advance is atomic against competing
                        # workers (Codex: "successful eligible claims, not attempts").
                        farmctl.record_claim_ledger(
                            conn, terminal, item["id"],
                            "recovery" if item_is_recovery else "priority", now,
                        )
                        conn.commit()
                        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
                        return {
                            "claimed": True,
                            "item": dict(row),
                            "claim_class": "recovery" if item_is_recovery else "priority",
                        }
                conn.commit()
                return {
                    "claimed": False,
                    "reason": "no_pending_claimable",
                    "history_skipped": skipped_history,
                    "launch_cooldown_skipped": skipped_launch_cooldown,
                    "multisymbol_ram_skipped": skipped_multisym_ram,
                    "multisymbol_commit_skipped": skipped_multisym_commit,
                    "terminal_avoid_skipped": skipped_avoid_terminal,
                    "recovery_capped": recovery_capped,
                }
            except Exception:
                conn.rollback()
                raise

    # The shared mutation lock closes the OFF-during-claim race. Factory_OFF
    # asserts its flag first and then waits for this lock to drain. A claim that
    # acquired the lock before that assertion is an admitted bounded unit; after
    # acquisition we re-read the flag so no later claimant can cross the fence.
    mutation_lock_path = path_for_factory_flag(factory_off_flag)
    admission_deadline = time.monotonic() + FACTORY_ADMISSION_LOCK_TIMEOUT_SECONDS
    while True:
        mutation_lock = FactoryMutationLock(
            mutation_lock_path,
            owner=f"terminal_worker.claim_atomic:{terminal}",
        )
        try:
            mutation_lock.__enter__()
            break
        except RuntimeError:
            # Contending workers serialize here. Re-probe OFF on every retry so
            # an asserted interlock wins immediately instead of waiting for the
            # admission timeout.
            try:
                if factory_off_flag.exists():
                    return {
                        "claimed": False,
                        "reason": "factory_off",
                        "flag": str(factory_off_flag),
                    }
            except OSError as exc:
                return {
                    "claimed": False,
                    "reason": "factory_admission_interlock_error",
                    "flag": str(factory_off_flag),
                    "error": str(exc),
                }
            if time.monotonic() >= admission_deadline:
                return {
                    "claimed": False,
                    "reason": "factory_mutation_lock_busy",
                    "lock": str(mutation_lock_path),
                }
            time.sleep(FACTORY_ADMISSION_LOCK_POLL_SECONDS)
        except OSError as exc:
            return {
                "claimed": False,
                "reason": "factory_admission_interlock_error",
                "lock": str(mutation_lock_path),
                "error": str(exc),
            }

    try:
        try:
            if factory_off_flag.exists():
                return {
                    "claimed": False,
                    "reason": "factory_off",
                    "flag": str(factory_off_flag),
                }
        except OSError as exc:
            return {
                "claimed": False,
                "reason": "factory_admission_interlock_error",
                "flag": str(factory_off_flag),
                "error": str(exc),
            }

        try:
            return _with_sqlite_retry(_claim)
        except sqlite3.OperationalError as exc:
            if not _is_sqlite_locked(exc):
                raise
            return {"claimed": False, "reason": "sqlite_locked"}
    finally:
        mutation_lock.__exit__(None, None, None)


def claim_specific_atomic(root: Path, terminal: str, item_id: str) -> dict[str, Any]:
    """Claim exactly one pending work item for an isolated Factory-OFF run.

    This is the operator path for a targeted recovery or qualification run. It
    deliberately refuses to operate without the software interlock so it cannot
    race the normal priority queue. Unlike ``claim_atomic``, it never substitutes
    a different work item when the requested row is not currently claimable.
    """
    factory_off_flag = root / "state" / "FACTORY_OFF.flag"
    if not factory_off_flag.exists():
        return {
            "claimed": False,
            "reason": "factory_off_required",
            "flag": str(factory_off_flag),
        }

    calendar_preflight = farmctl._news_calendar_preflight(use_cache=True)
    if not calendar_preflight.get("ok"):
        return {
            "claimed": False,
            "reason": "news_calendar_preflight_failed",
            "item_id": item_id,
            "calendar_status": calendar_preflight.get("status"),
            "principal": calendar_preflight.get("principal"),
            "common_dir": calendar_preflight.get("common_dir"),
            "news_calendar_preflight": calendar_preflight,
        }

    def _claim() -> dict[str, Any]:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        db_path = root / farmctl.DB_REL
        # Warm the process snapshot BEFORE taking the write lock. The admission
        # gate needs it, and a cold Toolhelp32+psapi scan costs ~8ms — which is
        # cheap in itself but must not be paid while holding BEGIN IMMEDIATE with
        # nine workers contending, least of all when the box is paging
        # (Codex review 2026-07-26, 33a18bb2e). Inside the transaction the call
        # is then a ~0.4us cache hit. Fail-open: errors are swallowed there.
        _process_private_snapshot()
        with sqlite3.connect(db_path, timeout=30) as conn:
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA busy_timeout=30000")
            conn.execute("BEGIN IMMEDIATE")
            try:
                active_terminal = conn.execute(
                    "SELECT id FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1",
                    (terminal,),
                ).fetchone()
                if active_terminal:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "terminal_worker_busy",
                        "item_id": active_terminal["id"],
                    }

                if root.resolve() == farmctl.DEFAULT_ROOT.resolve() and terminal in farmctl._running_mt5_terminals():
                    conn.commit()
                    return {"claimed": False, "reason": "terminal_process_busy", "terminal": terminal}

                item = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
                if not item:
                    conn.commit()
                    return {"claimed": False, "reason": "work_item_missing", "item_id": item_id}
                if item["status"] != "pending":
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "work_item_not_pending",
                        "item_id": item_id,
                        "status": item["status"],
                    }

                payload = _json_loads(item["payload_json"])
                avoid_terminals = _payload_avoid_terminals(payload)
                if terminal.upper() in avoid_terminals:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "terminal_avoided",
                        "item_id": item_id,
                        "avoid_terminals": sorted(avoid_terminals),
                    }

                launch_not_before = _parse_utc_iso(payload.get("launch_not_before_utc"))
                if launch_not_before is not None:
                    try:
                        now_dt = datetime.fromisoformat(now).astimezone(timezone.utc)
                    except ValueError:
                        now_dt = datetime.now(timezone.utc)
                    if launch_not_before > now_dt:
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "launch_cooldown",
                            "item_id": item_id,
                            "launch_not_before_utc": launch_not_before.isoformat(),
                        }

                symbol_key = str(item["symbol"] or "").upper()
                active_symbol_counts, active_ea_symbol_pairs = farmctl._active_symbol_claim_state(conn)
                if symbol_key and (
                    (str(item["ea_id"]), symbol_key) in active_ea_symbol_pairs
                    or active_symbol_counts.get(symbol_key, 0) >= farmctl.CLAIM_SYMBOL_ACTIVE_CAP
                ):
                    conn.commit()
                    return {"claimed": False, "reason": "symbol_busy", "item_id": item_id}

                if str(item["phase"]).upper() == "Q04":
                    active_q04 = conn.execute(
                        "SELECT id FROM work_items WHERE status='active' AND phase='Q04' AND ea_id=? LIMIT 1",
                        (item["ea_id"],),
                    ).fetchone()
                    if active_q04:
                        conn.commit()
                        return {"claimed": False, "reason": "q04_ea_busy", "item_id": item_id}

                if _watchdog_reset_admission_blocked(root):
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "watchdog_reset_pending",
                        "terminal": terminal,
                        "item_id": item_id,
                    }

                try:
                    multisym_ids = _multisymbol_ea_ids()
                except MultisymbolRegistryUnavailable as exc:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "multisymbol_registry_unavailable",
                        "item_id": item_id,
                        "error": str(exc),
                    }
                admission = _commit_admission_snapshot(conn, now, multisym_ids)
                if not admission["probe_ok"]:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "commit_probe_failed",
                        "item_id": item_id,
                        "commit_reserved_gb": round(admission["reserved_gb"], 1),
                        "commit_reservation_count": len(admission["reservations"]),
                    }
                effective_commit_headroom = admission["effective_headroom_gb"]
                if effective_commit_headroom < COMMIT_MIN_FREE_GB:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "commit_headroom_low",
                        "item_id": item_id,
                        "commit_headroom_gb": round(admission["live_headroom_gb"], 1),
                        "commit_reserved_gb": round(admission["reserved_gb"], 1),
                        "effective_commit_headroom_gb": round(effective_commit_headroom, 1),
                        "commit_reservation_count": len(admission["reservations"]),
                        "commit_reservation_detail": admission["reservations"],
                        "threshold_gb": COMMIT_MIN_FREE_GB,
                    }

                item_is_multisym = _work_item_is_multisymbol(item, payload, multisym_ids)
                if item_is_multisym:
                    multisym_active = any(
                        _work_item_is_multisymbol(row, _json_loads(row["payload_json"]), multisym_ids)
                        for row in conn.execute("SELECT ea_id, payload_json FROM work_items WHERE status='active'")
                    )
                    if multisym_active:
                        conn.commit()
                        return {"claimed": False, "reason": "multisymbol_busy", "item_id": item_id}
                    if effective_commit_headroom < MULTISYMBOL_COMMIT_MIN_FREE_GB:
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "multisymbol_commit_headroom_low",
                            "item_id": item_id,
                            "commit_headroom_gb": round(admission["live_headroom_gb"], 1),
                            "commit_reserved_gb": round(admission["reserved_gb"], 1),
                            "effective_commit_headroom_gb": round(effective_commit_headroom, 1),
                            "threshold_gb": MULTISYMBOL_COMMIT_MIN_FREE_GB,
                        }
                    free_ram = _free_ram_gb()
                    if free_ram < MULTISYMBOL_RAM_MIN_FREE_GB:
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "multisymbol_ram_low",
                            "item_id": item_id,
                            "free_ram_gb": round(free_ram, 1),
                            "threshold_gb": MULTISYMBOL_RAM_MIN_FREE_GB,
                        }

                history_ok, history = _p2_history_claimable(
                    item,
                    terminal,
                    farmctl._dwx_symbol_history_registry(),
                )
                if not history_ok:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "history_not_claimable",
                        "item_id": item_id,
                        "history": history,
                    }
                _merge_history_window_payload(payload, history)
                payload.update({
                    "claimed_at_iso": now,
                    "claimed_by_worker_pid": os.getpid(),
                    "targeted_factory_off_run": True,
                    "terminal": terminal,
                })
                _set_commit_reservation(
                    payload,
                    claimed_at_iso=now,
                    multisymbol=item_is_multisym,
                    commit_class=_multisymbol_commit_class(item, payload, item_is_multisym),
                )
                cur = conn.execute(
                    """
                    UPDATE work_items
                    SET status='active', claimed_by=?, payload_json=?, updated_at=?
                    WHERE id=? AND status='pending'
                    """,
                    (terminal, json.dumps(payload, sort_keys=True), now, item_id),
                )
                if cur.rowcount != 1:
                    conn.rollback()
                    return {"claimed": False, "reason": "claim_race_lost", "item_id": item_id}
                conn.commit()
                row = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
                return {"claimed": True, "item": dict(row), "targeted": True}
            except Exception:
                conn.rollback()
                raise

    try:
        return _with_sqlite_retry(_claim)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return {"claimed": False, "reason": "sqlite_locked", "item_id": item_id}


def release_stale_claims_for_terminal(root: Path, terminal: str) -> list[str]:
    """Release this terminal's active rows if the recorded smoke process is gone."""
    def _release() -> list[str]:
        farmctl.init_db(root)
        released: list[str] = []
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            rows = conn.execute(
                "SELECT * FROM work_items WHERE status='active' AND claimed_by=?",
                (terminal,),
            ).fetchall()
            for row in rows:
                payload = _json_loads(row["payload_json"])
                pid = payload.get("pid")
                if pid and farmctl._pid_tree_exists(pid):
                    continue
                payload["prior_failure"] = payload.get("prior_failure") or "worker_restart_released_stale_claim"
                terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
                if terminal_stopped is not None:
                    payload["terminal_stopped_on_release"] = terminal_stopped
                _clear_stale_runtime_payload(payload)
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', verdict=NULL, claimed_by=NULL, payload_json=?, updated_at=?
                    WHERE id=? AND status='active' AND claimed_by=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, row["id"], terminal),
                )
                released.append(row["id"])
            if released:
                conn.commit()
        return released

    try:
        return _with_sqlite_retry(_release)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return []


def _summary_run_tag_utc(path: Path, summary: dict[str, Any]) -> datetime | None:
    tag = str(summary.get("run_tag") or path.parent.name or "").strip()
    try:
        return datetime.strptime(tag, "%Y%m%d_%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _summary_fresh_for_claim(path: Path, summary: dict[str, Any], payload: dict[str, Any]) -> bool:
    claim_time = (
        _parse_utc_iso(payload.get("started_at_iso"))
        or _parse_utc_iso(payload.get("claimed_at_iso"))
    )
    if claim_time is None:
        return True
    threshold = claim_time - timedelta(seconds=2)
    run_tag_time = _summary_run_tag_utc(path, summary)
    if run_tag_time is not None:
        return run_tag_time >= threshold
    try:
        mtime = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
    except OSError:
        return False
    return mtime >= threshold


def _load_fresh_summary(path: Path, payload: dict[str, Any]) -> dict[str, Any] | None:
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    if not _summary_fresh_for_claim(path, summary, payload):
        return None
    return summary if farmctl._summary_matches_expected_evidence(summary, payload) else None


def _find_bound_persisted_pass_summary_data(
    item: sqlite3.Row,
    payload: dict[str, Any],
) -> tuple[Path, dict[str, Any]] | None:
    """Recover a durable Q02/Q03 PASS that predates the current claim.

    Normal ``report_root`` discovery is intentionally claim-fresh.  A worker
    restart or a later shared-history-lock retry can nevertheless leave an
    exact PASS in that item-isolated tree (or in its durable ``evidence_path``)
    which freshness filtering hides.  Reuse is fail-closed: only v2
    identity-bound smoke evidence whose window, expert, MQ5, EX5, and setfile
    still match may bypass claim freshness, and only a derived PASS is
    latched.  A persisted failure can never suppress a deliberate recovery
    run.
    """
    phase = str(item["phase"] or "").upper()
    if phase not in {"P2", "P3", "Q02", "Q03"}:
        return None
    if not payload.get("evidence_binding_required"):
        return None
    candidates: list[Path] = []
    raw_path = item["evidence_path"]
    if raw_path:
        candidates.append(Path(str(raw_path)))
    report_root = payload.get("report_root")
    if report_root:
        root = Path(str(report_root))
        try:
            if root.is_dir():
                candidates.extend(sorted(
                    root.rglob("summary.json"),
                    key=lambda path: path.stat().st_mtime,
                    reverse=True,
                ))
        except OSError:
            pass

    seen: set[str] = set()
    for path in candidates:
        key = str(path).casefold()
        if key in seen:
            continue
        seen.add(key)
        try:
            summary = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(summary, dict):
            continue
        if not farmctl._summary_matches_expected_evidence(summary, payload):
            continue
        if cold_cache_summary_signature(summary):
            continue
        effective_min_trades = int(
            payload.get("effective_min_trades")
            or summary.get("min_trades_required")
            or 5
        )
        verdict, _ = farmctl._derive_verdict_from_summary(
            summary,
            min_trades=effective_min_trades,
            phase=phase,
        )
        if verdict == "PASS":
            return path, summary
        # The newest (or explicitly DB-bound) exact outcome is authoritative.
        # Do not skip a persisted failure and hunt for an older PASS.
        return None
    return None


def _find_summary(report_root: str | None, payload: dict[str, Any] | None = None) -> Path | None:
    if not report_root:
        return None
    root = Path(report_root)
    if not root.is_dir():
        return None
    candidates = sorted(root.rglob("summary.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if payload is None:
        return candidates[0] if candidates else None
    for candidate in candidates:
        if _load_fresh_summary(candidate, payload) is not None:
            return candidate
    return None


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalized_ex5_sha256(raw: Any, *, role: str) -> str:
    value = str(raw or "").strip().lower()
    if len(value) != 64 or any(ch not in "0123456789abcdef" for ch in value):
        raise ValueError(f"{role}_invalid")
    return value


def _prepare_staged_ex5(item: sqlite3.Row, terminal: str) -> dict[str, Any]:
    """Atomically stage and verify the exact EX5 required for this dispatch.

    Manifest-pinned diagnostic binaries retain precedence. Ordinary work items
    use the registry-resolved canonical EX5 and any enqueue-time hash binding;
    legacy rows without a binding acquire one from that source at this gate.
    Every path copies before dispatch so a dormant divergent terminal is
    repaired only through the same verified gate that authorizes its run.
    """

    payload = _json_loads(item["payload_json"])
    raw_path = payload.get("staged_ex5_path")
    raw_sha = payload.get("staged_ex5_sha256")
    ea_dir = farmctl._ea_dir_from_setfile_path(Path(str(item["setfile_path"])), str(item["ea_id"]))
    if ea_dir is None:
        ea_dir = farmctl._preferred_ea_dir(str(item["ea_id"]))
    if ea_dir is None:
        raise ValueError("staged_ex5_ea_dir_unresolved")
    canonical_source = ea_dir / f"{ea_dir.name}.ex5"

    if raw_path is not None or raw_sha is not None:
        if not raw_path or not raw_sha:
            raise ValueError("staged_ex5_path_and_sha256_required_together")
        source = Path(str(raw_path))
        if not source.is_absolute():
            raise ValueError(f"staged_ex5_path_not_absolute:{source}")
        expected = _normalized_ex5_sha256(
            raw_sha, role="staged_ex5_sha256"
        )
        if payload.get("expected_ex5_sha256"):
            payload_expected = _normalized_ex5_sha256(
                payload["expected_ex5_sha256"],
                role="expected_ex5_sha256",
            )
            if payload_expected != expected:
                raise ValueError(
                    "staged_ex5_expected_binding_mismatch:"
                    f"{payload_expected}:staged:{expected}"
                )
        binding_source = "manifest_pinned_staged_ex5"
    else:
        source = canonical_source
        payload_expected = payload.get("expected_ex5_sha256")
        if payload_expected:
            expected = _normalized_ex5_sha256(
                payload_expected, role="expected_ex5_sha256"
            )
            binding_source = "work_item_expected_ex5_sha256"
        else:
            if not source.is_file():
                raise ValueError(f"dispatch_ex5_missing:{source}")
            expected = _sha256_file(source)
            binding_source = "canonical_ex5_at_dispatch"

    if not source.is_file():
        raise ValueError(f"staged_ex5_missing:{source}")
    source_sha = _sha256_file(source)
    if source_sha != expected:
        if binding_source == "manifest_pinned_staged_ex5":
            raise ValueError(
                f"staged_ex5_source_sha256_mismatch:{source_sha}"
            )
        raise ValueError(
            f"dispatch_ex5_source_sha256_mismatch:{source_sha}:expected:{expected}"
        )

    destination = farmctl.MT5_ROOT / terminal / "MQL5" / "Experts" / "QM" / f"{ea_dir.name}.ex5"
    destination.parent.mkdir(parents=True, exist_ok=True)
    preexisting_sha = _sha256_file(destination) if destination.is_file() else None
    temporary = destination.with_suffix(destination.suffix + f".{os.getpid()}.tmp")
    try:
        shutil.copy2(source, temporary)
        copied_sha = _sha256_file(temporary)
        if copied_sha != expected:
            if binding_source == "manifest_pinned_staged_ex5":
                raise ValueError(f"staged_ex5_copy_sha256_mismatch:{copied_sha}")
            raise ValueError(
                f"dispatch_ex5_copy_sha256_mismatch:{copied_sha}:expected:{expected}"
            )
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    pre_run_sha = _sha256_file(destination)
    if pre_run_sha != expected:
        if binding_source == "manifest_pinned_staged_ex5":
            raise ValueError(
                f"staged_ex5_pre_run_sha256_mismatch:{pre_run_sha}"
            )
        raise ValueError(
            f"dispatch_ex5_pre_run_sha256_mismatch:{pre_run_sha}:expected:{expected}"
        )
    return {
        "source_path": str(source.resolve()),
        "destination_path": str(destination.resolve()),
        "required_sha256": expected,
        "source_sha256": source_sha,
        "binding_source": binding_source,
        "preexisting_destination_sha256": preexisting_sha,
        "copied": True,
        "restaged": preexisting_sha != expected,
        "pre_run_sha256": pre_run_sha,
        "verified": True,
    }


def _verify_and_record_staged_ex5(payload: dict[str, Any]) -> dict[str, Any] | None:
    staging = payload.get("staged_ex5")
    if not isinstance(staging, dict):
        return None
    actual = _sha256_file(Path(str(staging["destination_path"])))
    staging["post_run_sha256"] = actual
    staging["verified"] = actual == staging["required_sha256"]
    summary_path = _find_summary(payload.get("report_root"))
    if summary_path:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        summary["staged_ex5"] = staging
        temporary = summary_path.with_suffix(summary_path.suffix + f".{os.getpid()}.tmp")
        temporary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(temporary, summary_path)
    if not staging["verified"]:
        raise ValueError(
            f"staged_ex5_post_run_sha256_mismatch:{actual}:expected:{staging['required_sha256']}"
        )
    return staging


def _find_work_item_summary_data(item: sqlite3.Row, payload: dict[str, Any]) -> tuple[Path, dict[str, Any]] | None:
    phase = str(item["phase"])
    if phase in farmctl.REAL_PHASE_RUNNER_PHASES:
        exact_evidence = payload.get("phase_evidence_path")
        if exact_evidence:
            evidence_path = Path(str(exact_evidence))
            if not evidence_path.is_file():
                return None
            summary = _load_fresh_summary(evidence_path, payload)
            return (evidence_path, summary) if summary is not None else None
        report_root = payload.get("report_root")
        if report_root:
            summary_path = Path(str(report_root)) / str(item["ea_id"]) / phase / "summary.json"
            if summary_path.exists():
                summary = _load_fresh_summary(summary_path, payload)
                if summary is None:
                    return None
                return summary_path, summary
            # Q-rewrite runners (q04..q10) write aggregate.json at
            # <report_root>/QM5_<num>/<phase>/<symbol>/aggregate.json with a
            # top-level `verdict` field that _derive_phase_runner_verdict
            # already understands. Q04 keeps the raw symbol in the path
            # (e.g. NDX.DWX); Q05+ replace '.' with '_' (e.g. NDX_DWX).
            ea_num = str(item["ea_id"]).replace("QM5_", "")
            symbol = str(item["symbol"] or "")
            for sym_variant in (symbol, symbol.replace(".", "_")):
                if not sym_variant:
                    continue
                agg = Path(str(report_root)) / f"QM5_{ea_num}" / phase / sym_variant / "aggregate.json"
                if agg.exists():
                    summary = _load_fresh_summary(agg, payload)
                    if summary is None:
                        return None
                    return agg, summary
            phase_dir = Path(str(report_root)) / f"QM5_{ea_num}" / phase
            if phase_dir.is_dir():
                cands = sorted(
                    phase_dir.rglob("aggregate.json"),
                    key=lambda p: p.stat().st_mtime,
                    reverse=True,
                )
                for agg in cands:
                    summary = _load_fresh_summary(agg, payload)
                    if summary is not None:
                        return agg, summary
        canonical_summary_path = farmctl._ea_phase_dir(str(item["ea_id"]), phase) / "summary.json"
        if canonical_summary_path.exists():
            summary = _load_fresh_summary(canonical_summary_path, payload)
            if summary is None:
                return None
            return canonical_summary_path, summary
        return farmctl._phase_artifact_summary(item)
    summary_path = _find_summary(payload.get("report_root"), payload)
    if summary_path:
        summary = _load_fresh_summary(summary_path, payload)
        if summary is not None:
            return summary_path, summary
    return _find_bound_persisted_pass_summary_data(item, payload)


def _q09_sidecar_matches(
    root: Path,
    item: sqlite3.Row,
    aggregate_path: Path,
    aggregate: dict[str, Any],
) -> bool:
    """Require the appropriate sealed Q09 sidecar before accepting an aggregate."""

    if str(item["phase"] or "").upper() != "Q09_NEWS":
        return True
    try:
        aggregate_sha256 = _sha256_file(aggregate_path)
        payload = _json_loads(item["payload_json"])
        connection = farmctl.connect(root)
        try:
            row = connection.execute(
                """
                SELECT verdict,aggregate_path,aggregate_sha256
                FROM q09_news_tests WHERE work_item_id=?
                """,
                (str(item["id"]),),
            ).fetchone()
        finally:
            connection.close()
        if payload.get("diagnostic_non_admission") is True:
            # Diagnostic results must stay outside q09_news_tests.  Their
            # sibling summary is the fail-closed sidecar and forces the worker
            # verdict to REVIEW_REQUIRED even when the underlying Q09
            # adjudication happens to find a lockable arm.
            if row is not None:
                return False
            diagnostic_path = aggregate_path.resolve().parent / "summary.json"
            diagnostic = json.loads(
                diagnostic_path.read_text(encoding="utf-8-sig")
            )
            evidence_path = Path(str(diagnostic.get("evidence_path") or ""))
            return bool(
                diagnostic.get("schema_version")
                == "q09-live-news-diagnostic-summary/v1"
                and diagnostic.get("diagnostic_non_admission") is True
                and diagnostic.get("diagnostic_contract")
                == "q09-live-news-backfill/v1"
                and str(diagnostic.get("work_item_id") or "") == str(item["id"])
                and str(diagnostic.get("verdict") or "") == "REVIEW_REQUIRED"
                and str(diagnostic.get("underlying_q09_verdict") or "")
                == str(aggregate.get("verdict") or "")
                and Path(str(diagnostic.get("aggregate_path") or "")).resolve()
                == aggregate_path.resolve()
                and str(diagnostic.get("aggregate_sha256") or "")
                == aggregate_sha256
                and evidence_path.is_file()
                and str(diagnostic.get("evidence_sha256") or "")
                == _sha256_file(evidence_path)
                and diagnostic.get("diagnostic_anchor_path")
                == payload.get("diagnostic_anchor_path")
                and diagnostic.get("diagnostic_anchor_sha256")
                == payload.get("diagnostic_anchor_sha256")
            )
        return bool(
            row is not None
            and str(row["verdict"]) == str(aggregate.get("verdict") or "")
            and Path(str(row["aggregate_path"])).resolve() == aggregate_path.resolve()
            and str(row["aggregate_sha256"]) == aggregate_sha256
        )
    except (OSError, sqlite3.Error, ValueError):
        return False


def _work_item_has_summary_data(root: Path, item_id: str) -> bool:
    try:
        with farmctl.connect(root) as conn:
            item = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
        if not item:
            return False
        return _find_work_item_summary_data(item, _json_loads(item["payload_json"])) is not None
    except Exception:
        return False


def _mirror_real_phase_artifacts(item: sqlite3.Row, summary_path: Path, verdict: str) -> None:
    """Publish the latest passing real-phase artifacts for downstream inputs.

    The work_item evidence remains the isolated report_root copy. The canonical
    `D:/QM/reports/pipeline/<EA>/<Phase>/` directory is only a convenience input
    surface for later phases and dashboards.
    """
    if verdict != "PASS" or str(item["phase"]) not in farmctl.REAL_PHASE_RUNNER_PHASES:
        return
    source_dir = summary_path.parent
    target_dir = farmctl._ea_phase_dir(str(item["ea_id"]), str(item["phase"]))
    source_resolved = source_dir.resolve()
    target_resolved = target_dir.resolve()
    if source_resolved == target_resolved or source_resolved.is_relative_to(target_resolved):
        return
    target_dir.mkdir(parents=True, exist_ok=True)
    for source in source_dir.iterdir():
        if not source.is_file():
            continue
        shutil.copy2(source, target_dir / source.name)


def _launch_gate_max() -> int:
    """Concurrent-launch cap, overridable at runtime via launch_gate_max.txt."""
    try:
        override = LAUNCH_GATE_DIR.parent / "launch_gate_max.txt"
        if override.exists():
            return max(1, int(override.read_text(encoding="utf-8").strip()))
    except (OSError, ValueError):
        pass
    return LAUNCH_GATE_MAX_CONCURRENT


def _acquire_launch_slot(terminal: str) -> None:
    """Block until fewer than _launch_gate_max() terminal64 inits are in flight.

    TTL-based: stale lock files (older than the init window) are swept and a fresh
    timestamped lock is dropped, which then ages out on its own — no explicit release,
    so a crashed worker can never deadlock the gate. Fail-open: any error or a wait
    past the timeout proceeds anyway, so the gate can only ever slow a launch storm,
    never stop the factory.
    """
    try:
        LAUNCH_GATE_DIR.mkdir(parents=True, exist_ok=True)
    except OSError:
        return
    deadline = time.monotonic() + LAUNCH_GATE_WAIT_TIMEOUT_SECONDS
    maxc = _launch_gate_max()
    while True:
        now = time.time()
        active = 0
        try:
            for p in list(LAUNCH_GATE_DIR.glob("*.lock")):
                try:
                    if now - p.stat().st_mtime > LAUNCH_GATE_WINDOW_SECONDS:
                        p.unlink(missing_ok=True)
                    else:
                        active += 1
                except OSError:
                    pass
        except OSError:
            return
        if active < maxc:
            try:
                slot = LAUNCH_GATE_DIR / f"{terminal}_{os.getpid()}_{int(now * 1000)}.lock"
                slot.write_text(str(now), encoding="utf-8")
            except OSError:
                pass
            return
        if time.monotonic() >= deadline:
            return
        time.sleep(0.5 + random.uniform(0, 0.5))


def _smoke_terminal_exit_stall_grace_seconds(
    item: dict[str, Any], payload: dict[str, Any]
) -> float | None:
    """Return the elapsed grace for a run_smoke wrapper proven stalled.

    Q02/Q03 (and legacy P2/P3 aliases) use a single run_smoke.ps1 child. If
    its log has reached terminal_exit but no summary appears and the log is
    quiet, waiting for the full worker timeout only blocks the symbol dedupe
    queue.  A valid-report latch receives a longer bounded grace because report
    parsing and logger-sample publication continue after terminal_exit.
    """
    if str(item.get("phase") or "").upper() not in {"Q02", "Q03", "P2", "P3"}:
        return None
    if _find_summary(payload.get("report_root"), payload):
        return None
    log_path = payload.get("log_path")
    if not log_path:
        return None
    path = Path(str(log_path))
    try:
        stat = path.stat()
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
    except OSError:
        return None
    last_start = text.rfind("run_smoke.stage=terminal_start")
    last_exit = text.rfind("run_smoke.stage=terminal_exit")
    if last_exit < 0 or last_start < 0 or last_exit <= last_start:
        return None
    last_latch = text.rfind("run_smoke.stage=valid_report_latched")
    grace_seconds = (
        SMOKE_VALID_REPORT_POSTPROCESS_GRACE_SECONDS
        if last_start < last_latch < last_exit
        else SMOKE_TERMINAL_EXIT_GRACE_SECONDS
    )
    if time.time() - stat.st_mtime < grace_seconds:
        return None
    return grace_seconds


def _smoke_terminal_exit_stalled(item: dict[str, Any], payload: dict[str, Any]) -> bool:
    return _smoke_terminal_exit_stall_grace_seconds(item, payload) is not None


def _stop_terminal_slot_for_release(root: Path, terminal: str | None) -> bool | None:
    """Stop the factory MT5 process before a released work_item can orphan it."""
    if root.resolve() != farmctl.DEFAULT_ROOT.resolve():
        return None
    if not terminal:
        return None
    return farmctl._stop_terminal_slot(str(terminal))


def _terminal_slot_running(root: Path, terminal: str | None) -> bool:
    if root.resolve() != farmctl.DEFAULT_ROOT.resolve():
        return False
    if not terminal:
        return False
    try:
        return str(terminal).upper() in farmctl._running_mt5_terminals()
    except Exception:
        return False


def _work_item_ownership(root: Path, item_id: str, terminal: str) -> dict[str, Any]:
    """Return whether a worker still owns the active work_item claim."""
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status, claimed_by FROM work_items WHERE id=?",
            (item_id,),
        ).fetchone()
    if not row:
        return {"owned": False, "reason": "missing_item"}
    status = row["status"]
    claimed_by = row["claimed_by"]
    if status != "active":
        return {"owned": False, "reason": "status_changed", "status": status, "claimed_by": claimed_by}
    if claimed_by != terminal:
        return {"owned": False, "reason": "claim_transferred", "status": status, "claimed_by": claimed_by}
    return {"owned": True, "status": status, "claimed_by": claimed_by}


def _finish_harness_work_item(
    conn: sqlite3.Connection,
    item: sqlite3.Row,
    payload: dict[str, Any],
    exit_code: int | None,
    now: str,
    item_id: str,
) -> dict[str, Any]:
    """Finish a kind='harness' work_item.

    A harness never trades, so the generic summary.json / min-trades verdict
    pipeline does not apply (there is no summary.json -- OnTester returns a
    flat 0.0 and the tester report is discarded). Success means run_smoke
    exited cleanly AND the runner's own verdict CSV was collected out of the
    shared MT5 Common\\Files folder without weakening the staleness guard.
    """
    payload["run_smoke_exit_code"] = exit_code
    harness_type = str(payload.get("harness_type") or "")
    verdict = "HARNESS_FAIL"
    reason = "unknown_harness_type"
    collection: dict[str, Any] | None = None
    if harness_type == "pattern_permission_fixture":
        from framework.scripts import collect_pattern_fixture_harness_results as _collector

        source_csv = Path(str(payload.get("results_csv_path") or ""))
        bundle_csv = Path(str(payload.get("bundle_csv_path") or _collector.DEFAULT_BUNDLE_CSV))
        try:
            collection = _collector.collect_results(
                source_csv=source_csv, bundle_csv=bundle_csv, dest_csv=_collector.DEFAULT_DEST_CSV,
            )
            report_root = payload.get("report_root")
            if report_root:
                collection["journal_purged"] = _collector.purge_report_root_journal(Path(report_root))
            if exit_code not in (0, None):
                verdict, reason = "HARNESS_FAIL", f"run_smoke_exit_code_{exit_code}"
            else:
                verdict, reason = "HARNESS_OK", "collected"
        except FileNotFoundError as exc:
            reason = f"results_missing:{exc}"
        except _collector.StaleResultsError as exc:
            reason = f"stale_results:{exc}"
        except Exception as exc:  # never crash the poll loop on a harness item
            reason = f"collection_error:{exc!r}"
    else:
        reason = f"unknown_harness_type:{harness_type}"
    payload["harness_verdict_reason"] = reason
    if collection is not None:
        payload["harness_collection"] = collection
    conn.execute(
        """
        UPDATE work_items
        SET status='done', verdict=?, evidence_path=?, claimed_by=NULL,
            payload_json=?, updated_at=?
        WHERE id=?
        """,
        (
            verdict,
            (collection or {}).get("dest_csv"),
            json.dumps(payload, sort_keys=True),
            now,
            item_id,
        ),
    )
    conn.commit()
    return {"finished": True, "status": "done", "verdict": verdict, "reason": reason,
            "aggregate": None}


def _finish_work_item(
    root: Path,
    item_id: str,
    exit_code: int | None,
    runtime_payload_updates: dict[str, Any] | None = None,
) -> dict[str, Any]:
    def _finish() -> dict[str, Any]:
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            item = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
            if not item:
                return {"finished": False, "reason": "missing_item"}
            payload = _json_loads(item["payload_json"])
            if runtime_payload_updates:
                payload.update(runtime_payload_updates)
            if item["kind"] == farmctl.HARNESS_WORK_ITEM_KIND:
                return _finish_harness_work_item(conn, item, payload, exit_code, now, item_id)
            summary_data = _find_work_item_summary_data(item, payload)
            if summary_data and not _q09_sidecar_matches(
                root, item, summary_data[0], summary_data[1]
            ):
                payload["q09_sidecar_verification"] = "missing_or_mismatched"
                summary_data = None
            elif summary_data and payload.get("diagnostic_non_admission") is True:
                payload["q09_sidecar_verification"] = "diagnostic_summary_matched"
            if summary_data:
                summary_path, summary = summary_data
                cold_signature = (
                    cold_cache_summary_signature(summary)
                    if str(item["phase"]).upper() in {"P2", "P3", "Q02", "Q03"}
                    else None
                )
                if cold_signature:
                    retry_attempt = int(item["attempt_count"] or 0) + 1
                    failed_terminal = str(item["claimed_by"] or "").strip().upper()
                    payload.update({
                        "prior_failure": "cold_cache_invalid_summary",
                        "cold_cache_retry_attempt": retry_attempt,
                        "cold_cache_retry_cap": MAX_WORK_ITEM_RETRIES,
                        "cold_cache_signature": cold_signature,
                        "cold_cache_summary_path": str(summary_path),
                        "run_smoke_exit_code": exit_code,
                        "verdict_reason": f"cold_cache_retry:{cold_signature}",
                    })
                    if failed_terminal:
                        _accumulate_avoid_terminal(payload, failed_terminal)
                    payload["launch_not_before_utc"] = (
                        datetime.now(timezone.utc)
                        + timedelta(seconds=SUMMARY_MISSING_RETRY_COOLDOWN_SECONDS)
                    ).isoformat()
                    _clear_stale_runtime_payload(payload)
                    print(
                        json.dumps({
                            "event": "cold_cache_retry",
                            "item_id": item_id,
                            "phase": item["phase"],
                            "attempt": retry_attempt,
                            "max_attempts": MAX_WORK_ITEM_RETRIES,
                            "matched_signature": cold_signature,
                            "action": (
                                "requeue"
                                if retry_attempt < MAX_WORK_ITEM_RETRIES
                                else "exhausted"
                            ),
                        }),
                        flush=True,
                    )
                    if retry_attempt < MAX_WORK_ITEM_RETRIES:
                        conn.execute(
                            """
                            UPDATE work_items
                            SET status='pending', verdict=NULL, attempt_count=?,
                                claimed_by=NULL, evidence_path=NULL,
                                payload_json=?, updated_at=?
                            WHERE id=?
                            """,
                            (
                                retry_attempt,
                                json.dumps(payload, sort_keys=True),
                                now,
                                item_id,
                            ),
                        )
                        conn.commit()
                        return {
                            "finished": True,
                            "status": "pending",
                            "verdict": None,
                            "reason": payload["verdict_reason"],
                            "attempt": retry_attempt,
                            "matched_signature": cold_signature,
                            "aggregate": None,
                        }
                    payload["final_failure"] = "cold_cache_retries_exhausted"
                    payload["verdict_reason"] = (
                        f"cold_cache_retries_exhausted:{cold_signature}"
                    )
                    payload["verdict_taxonomy"] = "infra"
                    conn.execute(
                        """
                        UPDATE work_items
                        SET status='failed', verdict='INFRA_FAIL', attempt_count=?,
                            evidence_path=?, claimed_by=NULL,
                            payload_json=?, updated_at=?
                        WHERE id=?
                        """,
                        (
                            retry_attempt,
                            str(summary_path),
                            json.dumps(payload, sort_keys=True),
                            now,
                            item_id,
                        ),
                    )
                    conn.commit()
                    return {
                        "finished": True,
                        "status": "failed",
                        "verdict": "INFRA_FAIL",
                        "reason": payload["verdict_reason"],
                        "attempt": retry_attempt,
                        "matched_signature": cold_signature,
                        "aggregate": _aggregate_finished_parent(
                            root, item["parent_task_id"]
                        ),
                    }
                if payload.get("diagnostic_non_admission") is True:
                    diagnostic_summary_path = summary_path.resolve().parent / "summary.json"
                    diagnostic_summary = json.loads(
                        diagnostic_summary_path.read_text(encoding="utf-8-sig")
                    )
                    payload["diagnostic_underlying_q09_verdict"] = summary.get("verdict")
                    summary_path = diagnostic_summary_path
                    summary = diagnostic_summary
                    verdict, reason = "REVIEW_REQUIRED", "diagnostic_non_admission"
                    payload["evidence_provenance"] = "phase_runner_diagnostic_non_admission"
                    payload["verdict_taxonomy"] = "review"
                else:
                    effective_min_trades = int(
                        payload.get("effective_min_trades")
                        or summary.get("min_trades_required")
                        or 5
                    )
                    verdict, reason = farmctl._derive_verdict_from_summary(
                        summary,
                        min_trades=effective_min_trades,
                        phase=item["phase"],
                    )
                    _mirror_real_phase_artifacts(item, summary_path, verdict)
                    payload["evidence_provenance"] = "phase_runner" if item["phase"] in farmctl.REAL_PHASE_RUNNER_PHASES else "real_mt5"
                    payload["verdict_taxonomy"] = "infra" if verdict == "INFRA_FAIL" else "strategy"
                payload["verdict_reason"] = reason
                payload["run_smoke_exit_code"] = exit_code
                # 2026-06-10 — two-stage prescreen, worker path (mirrors the
                # farmctl dispatch classification): a prescreen PASS is NOT a
                # final verdict — requeue the item for the full window with
                # p2_prescreen_done so the next spawn uses full dates. A
                # prescreen FAIL is final by P2-prescreen design (cheap kill)
                # and gets the explicit P2_PRESCREEN_ reason prefix. An
                # INFRA_FAIL falls through to normal infra handling untouched.
                if (item["phase"] in ("P2", "Q02")
                        and payload.get("p2_run_stage") == "prescreen"
                        and verdict in ("PASS", "FAIL")):
                    payload.update({
                        "p2_prescreen_done": True,
                        "p2_prescreen_verdict": verdict,
                        "p2_prescreen_reason": reason,
                        "p2_prescreen_evidence_path": str(summary_path),
                        "p2_prescreen_from_date": payload.get("from_date"),
                        "p2_prescreen_to_date": payload.get("to_date"),
                    })
                    if verdict == "PASS":
                        payload.update({
                            "p2_run_stage": "full_pending",
                            "pid": None,
                            "started_at_iso": None,
                            "log_path": None,
                        })
                        conn.execute(
                            """
                            UPDATE work_items
                            SET status='pending', verdict=NULL, claimed_by=NULL,
                                evidence_path=NULL, payload_json=?, updated_at=?
                            WHERE id=?
                            """,
                            (json.dumps(payload, sort_keys=True), now, item_id),
                        )
                        conn.commit()
                        return {"finished": True, "status": "pending",
                                "verdict": None,
                                "reason": f"prescreen_pass_requeued_full:{reason}"}
                    payload["verdict_reason"] = f"P2_PRESCREEN_{reason}"
                    reason = payload["verdict_reason"]
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='done', verdict=?, evidence_path=?, claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (verdict, str(summary_path), json.dumps(payload, sort_keys=True), now, item_id),
                )
                promoted = farmctl._promote_zero_trade_q02_cohort_to_draft_defect(
                    conn, item
                )
                conn.commit()
                if item_id in promoted:
                    verdict = "DRAFT_DEFECT"
                    reason = "Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES"
                aggregate = _aggregate_finished_parent(root, item["parent_task_id"])
                return {"finished": True, "status": "done", "verdict": verdict, "reason": reason, "aggregate": aggregate}

            payload["run_smoke_exit_code"] = exit_code
            failed_terminal = str(item["claimed_by"] or "").strip().upper()

            # Shared-bases history-lock STORM auto-heal (see constants above). Only
            # probe the LIVE factory's MT5 logs (root == DEFAULT_ROOT); on a temp/test
            # root the probe is skipped so the ordinary summary_missing path is used.
            # Fail-open: any detection error falls through to the normal path.
            storm = None
            try:
                if root.resolve() == farmctl.DEFAULT_ROOT.resolve():
                    storm = _detect_history_lock_storm(
                        failed_terminal,
                        work_item_id=item_id,
                        started_at_iso=(
                            payload.get("started_at_iso")
                            or payload.get("claimed_at_iso")
                        ),
                    )
            except Exception:
                storm = None

            terminal_stopped = _stop_terminal_slot_for_release(root, item["claimed_by"])
            if terminal_stopped is not None:
                payload["terminal_stopped_on_release"] = terminal_stopped

            if storm:
                # Transient INFRA class: SEPARATE counter, does NOT touch attempt_count.
                transient_attempts = int(payload.get("transient_infra_attempts") or 0) + 1
                payload["transient_infra_attempts"] = transient_attempts
                payload["prior_failure"] = "shared_bases_history_lock_storm"
                payload["transient_infra_signature"] = storm.get("token")
                payload["transient_infra_evidence_path"] = storm.get("log_path")
                payload["transient_infra_evidence_line"] = storm.get("matched_line")
                payload["transient_infra_evidence_mtime_utc"] = storm.get("log_mtime_utc")
                _accumulate_avoid_terminal(payload, failed_terminal)
                payload["launch_not_before_utc"] = (
                    datetime.now(timezone.utc)
                    + timedelta(seconds=_transient_infra_backoff_seconds(transient_attempts - 1))
                ).isoformat()
                # Staged recovery: strip stale runtime keys so the re-claim is clean;
                # priority_track / requeue reason in the payload are left untouched.
                _clear_stale_runtime_payload(payload)
                if transient_attempts <= TRANSIENT_INFRA_RETRY_CAP:
                    conn.execute(
                        """
                        UPDATE work_items
                        SET status='pending', verdict=NULL, claimed_by=NULL,
                            payload_json=?, updated_at=?
                        WHERE id=?
                        """,
                        (json.dumps(payload, sort_keys=True), now, item_id),
                    )
                    conn.commit()
                    return {
                        "finished": True,
                        "status": "pending",
                        "verdict": None,
                        "transient_infra": True,
                        "transient_infra_attempts": transient_attempts,
                        "avoid_terminals": payload.get("avoid_terminals", []),
                        "attempt": int(item["attempt_count"] or 0),
                        "aggregate": None,
                    }
                # Transient cap exhausted -> real INFRA_FAIL for manual attention.
                payload["final_failure"] = "shared_bases_history_lock_transient_cap_exhausted"
                farmctl._ensure_verdict_reason(payload)
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict='INFRA_FAIL', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item_id),
                )
                conn.commit()
                aggregate = _aggregate_finished_parent(root, item["parent_task_id"])
                return {
                    "finished": True,
                    "status": "failed",
                    "verdict": "INFRA_FAIL",
                    "transient_infra": True,
                    "transient_infra_attempts": transient_attempts,
                    "attempt": int(item["attempt_count"] or 0),
                    "aggregate": aggregate,
                }

            attempt = int(item["attempt_count"] or 0) + 1
            payload["prior_failure"] = payload.get("prior_failure") or "summary_missing"
            if failed_terminal:
                _accumulate_avoid_terminal(payload, failed_terminal)
            payload["launch_not_before_utc"] = (
                datetime.now(timezone.utc)
                + timedelta(seconds=SUMMARY_MISSING_RETRY_COOLDOWN_SECONDS)
            ).isoformat()
            if attempt < MAX_WORK_ITEM_RETRIES:
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='pending', verdict=NULL, attempt_count=?, claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (attempt, json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "pending"
                verdict = None
            else:
                # Census rank 1 (2026-07-27): stop flattening every summary-missing
                # exhaustion into a retryable INFRA_FAIL. Classify the fresh run_smoke
                # log's terminal_exit signature; a DETERMINISTIC no-summary (clean exit
                # with no report / report latched but unparseable / log-bomb / an
                # explicit defect token) is not retry-owed transport failure and maps to
                # the non-retryable INVALID verdict, exactly as the Q08 boundary fix does.
                # Only transient / unclassified signatures stay retryable INFRA_FAIL.
                # Fail-open: an unreadable log yields UNCLASSIFIED -> INFRA_FAIL, i.e. the
                # prior behaviour, so a recoverable run is never wrongly demoted.
                payload["final_failure"] = "summary_missing_retries_exhausted"
                log_text = None
                log_path = payload.get("log_path")
                if log_path:
                    try:
                        log_text = Path(str(log_path)).read_text(
                            encoding="utf-8-sig", errors="ignore"
                        )
                    except OSError:
                        log_text = None
                classification = farmctl.classify_summary_missing_run(payload, log_text)
                payload["failure_class"] = classification["failure_class"]
                payload["failure_subclass"] = classification["failure_subclass"]
                payload["failure_class_evidence"] = classification["evidence"]
                payload["verdict_reason"] = (
                    f"summary_missing:{classification['failure_subclass']}"
                )
                if classification["retryable"]:
                    verdict = "INFRA_FAIL"
                    payload["verdict_taxonomy"] = "infra"
                else:
                    verdict = "INVALID"
                    payload["verdict_taxonomy"] = "invalid"
                farmctl._ensure_verdict_reason(payload)
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict=?, claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (verdict, json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "failed"
            conn.commit()
            aggregate = _aggregate_finished_parent(root, item["parent_task_id"]) if status == "failed" else None
            return {"finished": True, "status": status, "verdict": verdict, "attempt": attempt, "aggregate": aggregate}

    try:
        return _with_sqlite_retry(_finish)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return {"finished": False, "reason": "sqlite_locked_finish_deferred"}


def _phase_from_task_kind(kind: str) -> str:
    raw = kind.replace("backtest_", "").upper()
    return {"P35": "P3.5"}.get(raw, raw)


def _aggregate_finished_parent(root: Path, parent_task_id: str | None) -> dict[str, Any] | None:
    return farmctl.aggregate_finished_parent_cas(
        root,
        parent_task_id,
        source="terminal_worker_aggregate",
    )


def _work_item_preflight_failure(item: sqlite3.Row) -> dict[str, Any] | None:
    """Return a deterministic failure before consuming an MT5 slot."""
    ea_id = str(item["ea_id"])
    setfile_path = Path(str(item["setfile_path"]))
    if not setfile_path.exists():
        return {"reason": "setfile_missing", "detail": str(setfile_path)}

    ea_root_dir = farmctl.REPO_ROOT / "framework" / "EAs"
    ea_dir_from_setfile = farmctl._ea_dir_from_setfile_path(setfile_path, ea_id)
    candidates = (
        [ea_dir_from_setfile]
        if ea_dir_from_setfile is not None
        else [p for p in ea_root_dir.glob(f"{ea_id}_*") if p.is_dir()]
    )
    if not candidates:
        return {"reason": "ea_dir_missing", "detail": str(ea_root_dir / f"{ea_id}_*")}
    if len(candidates) > 1:
        pref = farmctl._preferred_ea_dir(ea_id)  # DL-068: registry-aware disambiguation
        if pref is not None:
            candidates = [pref]
        else:
            return {"reason": "ea_dir_ambiguous", "detail": [p.name for p in candidates]}

    ea_dir = candidates[0]
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    if not ex5.exists():
        return {"reason": "ex5_missing", "detail": str(ex5)}
    ex5_files = sorted(p.name for p in ea_dir.glob("*.ex5"))
    if ex5_files != [ex5.name]:
        return {"reason": "duplicate_ex5", "detail": ex5_files}
    return None


_STALE_PREFLIGHT_PAYLOAD_KEYS = (
    "preflight_failure",
    "preflight_failed_at",
    "verdict_reason",
    "repair_handler",
    "repair_note",
    "report_root",
    "phase_evidence_path",
    "pid",
    "started_at_iso",
    "log_path",
    "run_smoke_exit_code",
    "adopted_active_child_at_iso",
)


def _clear_stale_preflight_payload(payload: dict[str, Any], now: str) -> bool:
    """Drop old preflight/runtime fields once the current preflight is clean."""
    if "preflight_failure" not in payload and "preflight_failed_at" not in payload:
        return False
    failure = payload.get("preflight_failure")
    reason = failure.get("reason") if isinstance(failure, dict) else None
    for key in _STALE_PREFLIGHT_PAYLOAD_KEYS:
        payload.pop(key, None)
    payload["cleared_stale_preflight_at"] = now
    if reason:
        payload["cleared_stale_preflight_reason"] = str(reason)
    return True


def _fail_work_item_preflight(root: Path, item: sqlite3.Row, failure: dict[str, Any]) -> dict[str, Any]:
    now = farmctl.utc_now()
    report_root = Path(r"D:\QM\reports\work_items") / str(item["id"])
    evidence_dir = report_root / str(item["ea_id"]) / str(item["phase"])
    evidence_dir.mkdir(parents=True, exist_ok=True)
    evidence_path = evidence_dir / "preflight_failure.json"
    payload = _json_loads(item["payload_json"])
    payload.update({
        "preflight_failed_at": now,
        "preflight_failure": failure,
        "report_root": str(report_root),
        "verdict_reason": failure.get("reason") or "preflight_failed",
    })
    evidence = {
        "created_at": now,
        "detail": failure.get("detail"),
        "ea_id": item["ea_id"],
        "phase": item["phase"],
        "reason": failure.get("reason") or "preflight_failed",
        "setfile_path": item["setfile_path"],
        "symbol": item["symbol"],
        "verdict": "INFRA_FAIL",
    }
    evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def _update() -> None:
        with farmctl.connect(root) as conn:
            conn.execute(
                """
                UPDATE work_items
                SET status='failed', verdict='INFRA_FAIL', evidence_path=?,
                    claimed_by=NULL, payload_json=?, updated_at=?
                WHERE id=?
                """,
                (str(evidence_path), json.dumps(payload, sort_keys=True), now, item["id"]),
            )
            conn.commit()

    _with_sqlite_retry(_update)
    aggregate = _aggregate_finished_parent(root, item["parent_task_id"])
    return {
        "finished": True,
        "status": "failed",
        "verdict": "INFRA_FAIL",
        "reason": evidence["reason"],
        "evidence_path": str(evidence_path),
        "aggregate": aggregate,
    }


def _journal_bomb(report_root: str | None, sizes: dict, now_mono: float):
    """Rate-based log-bomb detector. Returns (path, gb, reason) for a tester .log
    journal under report_root that is BOMBING, else None. `sizes` is a mutable
    {path: (bytes, mono_time)} carried across calls so growth rate can be measured.

    A journal bombs if EITHER:
      * its growth rate exceeds LOG_BOMB_RATE_MB_PER_MIN (fast per-tick spam — the
        ~10GB/min framework-resolver bug; caught within one ~10s check window), OR
      * its absolute size exceeds LOG_BOMB_HARD_CEIL_BYTES (a slow-but-unbounded
        grower — disk-safety backstop).
    A legit multi-position EA grows ~50-200 MB/min to <=~2GB and trips neither.
    Fail-open (None) on any error so a measurement glitch never kills a legit run."""
    if not report_root:
        return None
    try:
        for dirpath, _dirs, files in os.walk(report_root):
            for fn in files:
                if not fn.lower().endswith(".log"):
                    continue
                fp = os.path.join(dirpath, fn)
                try:
                    sz = os.path.getsize(fp)
                except OSError:
                    continue
                prev = sizes.get(fp)
                sizes[fp] = (sz, now_mono)
                gb = round(sz / 1024 ** 3, 2)
                if sz > LOG_BOMB_HARD_CEIL_BYTES:
                    return (fp, gb, f"abs>{LOG_BOMB_HARD_CEIL_BYTES // 1024 ** 3}GB")
                if prev:
                    d_min = max((now_mono - prev[1]) / 60.0, 1e-6)
                    rate = ((sz - prev[0]) / 1024 ** 2) / d_min  # MB/min
                    if rate > LOG_BOMB_RATE_MB_PER_MIN:
                        return (fp, gb, f"rate>{int(LOG_BOMB_RATE_MB_PER_MIN)}MB/min(~{int(rate)})")
    except Exception:
        return None
    return None


def _defer_launch_fault(root: Path, item_id: str, terminal: str, spawn: dict[str, Any], ran_seconds: float, child_tail: str) -> dict[str, Any]:
    """Release a launch-faulted work item without consuming retry budget.

    A sub-second child exit means terminal64 never reached a real tester run.
    Marking that as final INFRA_FAIL burns good Q02 rows during host launch
    storms, so the row is cooled down and left pending for a later clean launch.
    """

    now = farmctl.utc_now()
    try:
        now_dt = datetime.fromisoformat(now).astimezone(timezone.utc)
    except ValueError:
        now_dt = datetime.now(timezone.utc)
    default_defer_seconds = _launch_fault_defer_seconds(0)
    default_launch_not_before = now_dt + timedelta(seconds=default_defer_seconds)

    def _update() -> dict[str, Any]:
        with farmctl.connect(root) as conn:
            row = conn.execute("SELECT payload_json, attempt_count FROM work_items WHERE id=?", (item_id,)).fetchone()
            if not row:
                return {
                    "launch_fault_count": None,
                    "launch_fault_defer_seconds": default_defer_seconds,
                    "launch_not_before_utc": default_launch_not_before.isoformat(),
                }
            payload = _json_loads(row["payload_json"])
            previous_fault_count = _launch_fault_count(payload.get("launch_fault_count"))
            defer_seconds = _launch_fault_defer_seconds(previous_fault_count)
            launch_not_before = now_dt + timedelta(seconds=defer_seconds)
            next_fault_count = previous_fault_count + 1
            payload.update({
                "prior_failure": "launch_fault",
                "last_launch_fault_at": now,
                "last_launch_fault_terminal": terminal,
                "last_launch_fault_pid": spawn.get("pid"),
                "last_launch_fault_seconds": round(ran_seconds, 2),
                "last_launch_fault_child_tail": child_tail,
                "launch_not_before_utc": launch_not_before.isoformat(),
                "launch_fault_defer_seconds": defer_seconds,
                "launch_fault_count": next_fault_count,
                "run_smoke_exit_code": None,
            })
            conn.execute(
                """
                UPDATE work_items
                SET status='pending', verdict=NULL, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=?
                """,
                (json.dumps(payload, sort_keys=True), now, item_id),
            )
            conn.commit()
            return {
                "launch_fault_count": next_fault_count,
                "launch_fault_defer_seconds": defer_seconds,
                "launch_not_before_utc": launch_not_before.isoformat(),
            }

    update_result = _with_sqlite_retry(_update)
    return {
        "finished": True,
        "status": "pending",
        "verdict": None,
        "reason": "launch_fault_deferred",
        **update_result,
    }


def _monitor_timeout_seconds(
    payload: dict[str, Any],
    default_timeout_seconds: int,
    phase: str | None = None,
) -> int:
    timeout_seconds = int(default_timeout_seconds)
    try:
        payload_timeout_min = int(payload.get("timeout_min") or 0)
        if payload_timeout_min > 0:
            timeout_seconds = max(timeout_seconds, payload_timeout_min * 60)
    except (TypeError, ValueError):
        pass
    if str(phase or "").upper() == "Q08":
        phase_timeout_min = farmctl._active_timeout_min_for_work_item(
            "Q08", json.dumps(payload, sort_keys=True)
        )
        if phase_timeout_min is not None:
            timeout_seconds = max(timeout_seconds, int(phase_timeout_min) * 60)
    return timeout_seconds


def _monitor_deadline_monotonic(
    payload: dict[str, Any],
    default_timeout_seconds: int,
    monitor_started: float,
    *,
    adopted: bool,
    phase: str | None = None,
) -> float:
    timeout_seconds = _monitor_timeout_seconds(
        payload, default_timeout_seconds, phase=phase
    )
    if adopted:
        started_at = _parse_utc_iso(payload.get("started_at_iso") or payload.get("claimed_at_iso"))
        if started_at:
            elapsed_seconds = max(0.0, (datetime.now(timezone.utc) - started_at).total_seconds())
            return monitor_started + max(0.0, timeout_seconds - elapsed_seconds)
    return monitor_started + timeout_seconds


def _monitor_spawned_work_item(
    root: Path,
    item: dict[str, Any],
    terminal: str,
    spawn: dict[str, Any],
    payload: dict[str, Any],
    timeout_seconds: int,
    *,
    adopted: bool = False,
) -> dict[str, Any]:
    pid = spawn["pid"]
    spawn_started = time.monotonic()
    deadline = _monitor_deadline_monotonic(
        payload,
        timeout_seconds,
        spawn_started,
        adopted=adopted,
        phase=str(item.get("phase") or ""),
    )
    log_bomb_path: str | None = None
    _lb_iter = 0
    _lb_sizes: dict = {}
    _lb_bomb: tuple | None = None
    post_exit_watchdog: dict[str, Any] | None = None
    child_alive = True
    terminal_alive_after_child_exit = False
    while time.monotonic() < deadline:
        child_alive = farmctl._pid_tree_exists(pid)
        terminal_alive_after_child_exit = (not child_alive) and _terminal_slot_running(root, terminal)
        if not child_alive and not terminal_alive_after_child_exit:
            break
        if _STOP:
            return {"action": "shutdown_waiting_for_child", "item_id": item["id"], "pid": pid}
        ownership = _work_item_ownership(root, item["id"], terminal)
        if not ownership.get("owned"):
            child_stopped = farmctl._stop_pid_tree(pid) if child_alive else False
            terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
            return {
                "action": "external_release_observed",
                "item_id": item["id"],
                "pid": pid,
                "child_stopped": child_stopped,
                "terminal_stopped": terminal_stopped,
                **ownership,
            }
        stalled_grace_seconds = _smoke_terminal_exit_stall_grace_seconds(item, payload)
        if stalled_grace_seconds is not None:
            post_exit_watchdog = {
                "post_exit_watchdog_killed": True,
                "post_exit_watchdog_killed_at_utc": farmctl.utc_now(),
                "post_exit_watchdog_grace_seconds": stalled_grace_seconds,
                "post_exit_watchdog_reason": "terminal_exit_without_summary_after_handoff_grace",
            }
            farmctl._stop_pid_tree(pid)
            _stop_terminal_slot_for_release(root, terminal)
            break
        # Log-bomb guard: kill a backtest whose tester journal GROWS too fast
        # (per-tick spam -> ~10GB/min) or breaches the absolute hard ceiling.
        # Rate-based so legit slow-growing multi-position/basket journals survive.
        _lb_iter += 1
        if _lb_iter % LOG_BOMB_CHECK_EVERY_ITERS == 0:
            _lb_bomb = _journal_bomb(spawn.get("report_root"), _lb_sizes, time.monotonic())
            if _lb_bomb:
                log_bomb_path = _lb_bomb[0]
                farmctl._stop_pid_tree(pid)
                break
        time.sleep(DETACHED_TERMINAL_POLL_SECONDS)
    if log_bomb_path:
        # Reclaim the disk immediately and record a terminal verdict with a high
        # attempt_count so the sweep does NOT re-enqueue (it would re-bomb).
        killed_at = farmctl.utc_now()
        bomb_reason = _lb_bomb[2] if _lb_bomb else "unknown"
        try:
            gb = round(os.path.getsize(log_bomb_path) / 1024 ** 3, 1)
        except OSError:
            gb = (_lb_bomb[1] if _lb_bomb else 0.0)
        try:
            os.remove(log_bomb_path)
        except OSError:
            pass
        terminal_stopped = _stop_terminal_slot_for_release(root, terminal)
        evidence_path: Path | None = None
        evidence = {
            "event": "LOG_BOMB",
            "item_id": item["id"],
            "ea_id": item.get("ea_id"),
            "symbol": item.get("symbol"),
            "phase": item.get("phase"),
            "terminal": terminal,
            "journal_path": log_bomb_path,
            "journal_gb": gb,
            "bomb_reason": bomb_reason,
            "journal_cap_bytes": LOG_BOMB_JOURNAL_CAP_BYTES,
            "rate_cap_mb_per_min": LOG_BOMB_RATE_MB_PER_MIN,
            "killed_at_utc": killed_at,
            "terminal_stopped": terminal_stopped,
        }
        report_root = spawn.get("report_root")
        if report_root:
            try:
                evidence_dir = Path(str(report_root))
                evidence_dir.mkdir(parents=True, exist_ok=True)
                evidence_path = evidence_dir / "log_bomb_evidence.json"
                evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8")
            except OSError:
                evidence_path = None
        print(json.dumps({"event": "log_bomb", "terminal": terminal, "item_id": item["id"],
                          "ea_id": item.get("ea_id"), "journal_gb": gb,
                          "path": log_bomb_path}), flush=True)

        def _record_log_bomb() -> None:
            with farmctl.connect(root) as conn:
                row = conn.execute("SELECT payload_json FROM work_items WHERE id=?", (item["id"],)).fetchone()
                payload = _json_loads(row["payload_json"]) if row else {}
                reason_classes = [
                    str(reason)
                    for reason in (payload.get("reason_classes") or [])
                    if str(reason).strip()
                ]
                if "LOG_BOMB" not in [reason.upper() for reason in reason_classes]:
                    reason_classes.append("LOG_BOMB")
                payload.update({
                    "reason_classes": reason_classes,
                    "verdict_reason": "LOG_BOMB",
                    "verdict_taxonomy": "infra",
                    "final_failure": "log_bomb",
                    "log_bomb_journal_path": log_bomb_path,
                    "log_bomb_journal_gb": gb,
                    "log_bomb_journal_cap_bytes": LOG_BOMB_JOURNAL_CAP_BYTES,
                    "killed_at": killed_at,
                })
                if terminal_stopped is not None:
                    payload["terminal_stopped_on_release"] = terminal_stopped
                if evidence_path is not None:
                    payload["log_bomb_evidence_path"] = str(evidence_path)
                conn.execute(
                    "UPDATE work_items SET status='done', verdict='INFRA_FAIL', "
                    "attempt_count=99, evidence_path=COALESCE(?, evidence_path), "
                    "claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                    (
                        str(evidence_path) if evidence_path is not None else None,
                        json.dumps(payload, sort_keys=True),
                        killed_at,
                        item["id"],
                    ),
                )
                conn.commit()

        _with_sqlite_retry(_record_log_bomb)
        return {"action": "log_bomb_killed", "item_id": item["id"],
                "ea_id": item.get("ea_id"), "journal_gb": gb,
                "evidence_path": str(evidence_path) if evidence_path is not None else None,
                "terminal_stopped": terminal_stopped}
    ran_seconds = time.monotonic() - spawn_started
    child_alive = farmctl._pid_tree_exists(pid)
    terminal_alive_after_child_exit = (not child_alive) and _terminal_slot_running(root, terminal)
    if post_exit_watchdog is not None:
        # The wrapper was explicitly killed by this worker; its real return code
        # is unknown and must never be rewritten as success.
        exit_code = None
    elif child_alive or terminal_alive_after_child_exit:
        # Timed out - kill the wrapper and the detached terminal slot, then
        # treat as no-result. MT5 can outlive run_smoke.ps1; stopping only the
        # parent can leave the tester writing a late summary after the DB row
        # has already been classified from stale evidence.
        if child_alive:
            farmctl._stop_pid_tree(pid)
        _stop_terminal_slot_for_release(root, terminal)
        exit_code = None
    elif (
        (not adopted)
        and ran_seconds < LAUNCH_FAULT_MIN_SECONDS
        and not _work_item_has_summary_data(root, item["id"])
    ):
        # Child vanished far too fast to be a real run (terminal64 startup alone
        # is ~6-10s) -> transient launch fault, NOT a clean exit_code=0. Record as
        # no-result and back off so a host hiccup can't burn the whole batch
        # through its retries in seconds.
        # Capture the child's log tail so a launch_fault wedge is diagnosable: a
        # session-resource exhaustion fault (0xC0000142 STATUS_DLL_INIT_FAILED, the
        # phase-runner/terminal64 failing to init) looks identical in the metrics to
        # a clean EA/data error, and the child process is already gone so its exit
        # code is unrecoverable here. The log tail is the only surviving evidence.
        # Fail-open: never let tail capture affect the launch_fault handling.
        child_tail = ""
        try:
            lp = spawn.get("log_path")
            if lp and os.path.exists(lp):
                with open(lp, "rb") as _ltf:
                    _ltf.seek(0, os.SEEK_END)
                    _ltsz = _ltf.tell()
                    _ltf.seek(max(0, _ltsz - 2000))
                    child_tail = _ltf.read().decode("utf-8", "replace").strip().replace("\n", " | ")[-700:]
        except Exception:
            child_tail = "<tail-read-failed>"
        print(json.dumps({"event": "launch_fault", "terminal": terminal,
                          "item_id": item["id"], "pid": pid,
                          "ran_seconds": round(ran_seconds, 2),
                          "child_log_tail": child_tail}), flush=True)
        result = {
            "action": "finished",
            "item_id": item["id"],
            **_defer_launch_fault(root, item["id"], terminal, spawn, ran_seconds, child_tail),
        }
        time.sleep(LAUNCH_FAULT_BACKOFF_SECONDS)
        return result
    else:
        # Child exited on its own after a plausible runtime, or this worker adopted
        # an already-running child whose runtime began before adoption.
        exit_code = 0
    try:
        _verify_and_record_staged_ex5(payload)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        with farmctl.connect(root) as conn:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
        if row is None:
            return {"action": "staged_ex5_post_run_failed", "item_id": item["id"], "reason": str(exc)}
        return {
            "action": "staged_ex5_post_run_failed",
            "item_id": item["id"],
            **_fail_work_item_preflight(
                root,
                row,
                {"reason": "staged_ex5_post_run_sha256_mismatch", "detail": str(exc)},
            ),
        }
    if post_exit_watchdog is None:
        finish_result = _finish_work_item(root, item["id"], exit_code)
    else:
        finish_result = _finish_work_item(
            root,
            item["id"],
            exit_code,
            runtime_payload_updates=post_exit_watchdog,
        )
    return {"action": "finished", "item_id": item["id"], **finish_result}


def _run_claimed_item(root: Path, item: dict[str, Any], terminal: str, timeout_seconds: int) -> dict[str, Any]:
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
    if not row:
        return {"action": "missing_item", "item_id": item["id"]}
    preflight_failure = _work_item_preflight_failure(row)
    if preflight_failure:
        return {
            "action": "preflight_failed",
            "item_id": item["id"],
            **_fail_work_item_preflight(root, row, preflight_failure),
        }
    existing_payload = _json_loads(row["payload_json"])
    stale_preflight_cleared_at = farmctl.utc_now()
    if _clear_stale_preflight_payload(existing_payload, stale_preflight_cleared_at):
        def _record_stale_preflight_clear() -> sqlite3.Row | None:
            with farmctl.connect(root) as conn:
                cur = conn.execute(
                    """
                    UPDATE work_items
                    SET evidence_path=NULL, payload_json=?, updated_at=?
                    WHERE id=? AND status='active'
                    """,
                    (json.dumps(existing_payload, sort_keys=True), stale_preflight_cleared_at, item["id"]),
                )
                if cur.rowcount != 1:
                    conn.rollback()
                    return None
                conn.commit()
                return conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()

        refreshed = _with_sqlite_retry(_record_stale_preflight_clear)
        if not refreshed:
            return {"action": "missing_item", "item_id": item["id"]}
        row = refreshed
        existing_payload = _json_loads(row["payload_json"])
    existing_pid = existing_payload.get("pid")
    if existing_pid and farmctl._pid_tree_exists(existing_pid):
        existing_payload["adopted_active_child_at_iso"] = farmctl.utc_now()
        existing_payload["claimed_by_worker_pid"] = os.getpid()

        def _record_adoption() -> None:
            with farmctl.connect(root) as conn:
                conn.execute(
                    "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                    (json.dumps(existing_payload, sort_keys=True), farmctl.utc_now(), item["id"]),
                )
                conn.commit()

        _with_sqlite_retry(_record_adoption)
        existing_spawn = {
            "pid": existing_pid,
            "log_path": existing_payload.get("log_path"),
            "report_root": existing_payload.get("report_root"),
        }
        return _monitor_spawned_work_item(
            root,
            item,
            terminal,
            existing_spawn,
            existing_payload,
            timeout_seconds,
            adopted=True,
        )
    # This early read avoids staging against a known-bad bundle and may reuse the
    # stat-bound claim cache. The shared spawn boundary below always re-reads
    # uncached immediately before subprocess creation.
    calendar_preflight = farmctl._news_calendar_preflight(use_cache=True)
    if not calendar_preflight.get("ok"):
        return {
            "action": "calendar_preflight_deferred",
            "item_id": item["id"],
            **_defer_news_calendar_preflight(
                root,
                row,
                terminal,
                calendar_preflight,
            ),
        }
    # Serialize the terminal64 DLL-init window across workers to kill the 0xC0000142
    # launch_fault storm that hits when many terminals launch at once (TTL leaky
    # semaphore, fail-open — see LAUNCH_GATE_* and _acquire_launch_slot).
    try:
        staging = _prepare_staged_ex5(row, terminal)
    except (OSError, ValueError) as exc:
        return {
            "action": "staged_ex5_preflight_failed",
            "item_id": item["id"],
            **_fail_work_item_preflight(
                root,
                row,
                {"reason": "staged_ex5_preflight_failed", "detail": str(exc)},
            ),
        }
    existing_payload["staged_ex5"] = staging
    existing_payload["expected_ex5_sha256"] = staging["required_sha256"]
    existing_payload["expected_ex5_path"] = staging["source_path"]
    existing_payload["dispatch_ex5_verified_at"] = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
            (json.dumps(existing_payload, sort_keys=True), farmctl.utc_now(), item["id"]),
        )
        conn.commit()
    row = dict(row)
    row["payload_json"] = json.dumps(existing_payload, sort_keys=True)
    history_symbols = _work_item_history_symbols(row, existing_payload)
    history_gate = _custom_history_gate(
        root,
        terminal,
        required_symbols=history_symbols,
        allow_required_restore=True,
    )
    if history_gate.get("required") and (
        history_gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
        or history_gate.get("admission_allowed") is False
    ):
        return {
            "action": "custom_history_gate_deferred",
            "item_id": item["id"],
            **_defer_custom_history_gate(root, row, terminal, history_gate),
        }
    copy_on_claim = _privatize_custom_history_claim(root, row, terminal, history_gate)
    if copy_on_claim.get("required") and (
        copy_on_claim.get("status") not in CUSTOM_HISTORY_COPY_PASS_STATUSES
    ):
        return {
            "action": "custom_history_copy_on_claim_deferred",
            "item_id": item["id"],
            **_defer_custom_history_gate(root, row, terminal, copy_on_claim),
        }
    if copy_on_claim.get("required"):
        existing_payload["custom_history_copy_on_claim"] = copy_on_claim
        existing_payload["custom_history_pre_copy_audit_sha256"] = history_gate.get(
            "audit_sha256"
        )
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                (json.dumps(existing_payload, sort_keys=True), farmctl.utc_now(), item["id"]),
            )
            conn.commit()
        row["payload_json"] = json.dumps(existing_payload, sort_keys=True)

    # Re-audit the mixed topology after every mutation.  This proves both the
    # dynamic family link minima, the sparse claim scope, and every selected
    # private manifest SHA before spawn.
    if copy_on_claim.get("status") == "PASS_PRIVATIZED":
        post_copy_gate = _custom_history_gate(
            root,
            terminal,
            required_symbols=history_symbols,
            allow_required_restore=False,
        )
        if (
            post_copy_gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
            or post_copy_gate.get("admission_allowed") is False
        ):
            return {
                "action": "custom_history_post_copy_gate_deferred",
                "item_id": item["id"],
                **_defer_custom_history_gate(root, row, terminal, post_copy_gate),
            }
        existing_payload["custom_history_post_copy_audit_sha256"] = post_copy_gate.get(
            "audit_sha256"
        )
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                (json.dumps(existing_payload, sort_keys=True), farmctl.utc_now(), item["id"]),
            )
            conn.commit()
        row["payload_json"] = json.dumps(existing_payload, sort_keys=True)
    _acquire_launch_slot(terminal)
    spawn = farmctl._spawn_work_item_runner(root, row, terminal)
    now = farmctl.utc_now()
    if not spawn.get("spawned"):
        if spawn.get("calendar_preflight_blocked"):
            calendar_preflight = spawn.get("news_calendar_preflight") or {}
            return {
                "action": "calendar_preflight_deferred",
                "item_id": item["id"],
                **_defer_news_calendar_preflight(
                    root,
                    row,
                    terminal,
                    calendar_preflight,
                ),
            }
        if spawn.get("pending_runner"):
            payload = _json_loads(row["payload_json"])
            payload.update({
                "verdict_reason": spawn.get("reason"),
                "log_path": spawn.get("log_path"),
                "report_root": spawn.get("report_root"),
            })
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='done', verdict='PENDING_RUNNER', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item["id"]),
                )
                conn.commit()
            return {
                "action": "pending_runner",
                "item_id": item["id"],
                "reason": spawn.get("reason"),
                "aggregate": _aggregate_finished_parent(root, row["parent_task_id"]),
            }
        if spawn.get("waiting_input"):
            # Preserve the diagnostic signal — farmctl reported a missing
            # input file (e.g. parent-phase artifact not produced yet).
            # Previously this fell through to a verdict-less INFRA_FAIL with
            # no payload context, making input-gap bugs invisible from the DB.
            # WAITING_INPUT mirrors PENDING_RUNNER as a terminal "done" state
            # (no retry — if the input later appears, a new work_item should
            # be enqueued rather than reviving this one).
            payload = _json_loads(row["payload_json"])
            payload.update({
                "verdict_reason": spawn.get("reason"),
                "missing_inputs": spawn.get("missing_inputs"),
                "log_path": spawn.get("log_path"),
                "report_root": spawn.get("report_root"),
            })
            with farmctl.connect(root) as conn:
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='done', verdict='WAITING_INPUT', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item["id"]),
                )
                conn.commit()
            return {
                "action": "waiting_input",
                "item_id": item["id"],
                "reason": spawn.get("reason"),
                "aggregate": _aggregate_finished_parent(root, row["parent_task_id"]),
            }
        refusal_evidence = farmctl.record_work_item_spawn_refusal(
            root,
            row,
            terminal,
            spawn,
            failed_at=now,
        )
        return {
            "action": "spawn_failed",
            "item_id": item["id"],
            "reason": spawn.get("reason"),
            "refusal_evidence": refusal_evidence,
        }

    payload = _json_loads(row["payload_json"])
    expected_from_date, expected_to_date = _resolved_evidence_window(spawn)
    payload.update({
        "started_at_iso": now,
        "pid": spawn["pid"],
        "process_creation_key": spawn.get("process_creation_key"),
        "process_image_path": spawn.get("process_image_path"),
        "process_started_at_epoch": spawn.get("process_started_at_epoch"),
        "job_object_assigned": spawn.get("job_object_assigned"),
        "job_object_mode": spawn.get("job_object_mode"),
        "job_object_registry_key": spawn.get("job_object_registry_key"),
        "process_started_suspended": spawn.get("process_started_suspended"),
        "primary_thread_resumed": spawn.get("primary_thread_resumed"),
        "log_path": spawn["log_path"],
        "report_root": spawn["report_root"],
        "phase_evidence_path": spawn.get("phase_evidence_path"),
        "ea_dir_name": spawn["ea_dir_name"],
        "terminal": terminal,
        "expected_trades_per_year_per_symbol": spawn.get("expected_trades_per_year_per_symbol"),
        "smoke_year_count": spawn.get("smoke_year_count"),
        "effective_min_trades": spawn.get("effective_min_trades"),
        "phase_runner": spawn.get("phase_runner"),
        # 2026-06-10 — prescreen stage must survive into classification.
        # Before this, _finish_work_item could not tell a 6-month prescreen
        # run from the full window, so prescreen PASSes were recorded as
        # FINAL Q02 PASSes on ~6 months of evidence (intraday H1/H4/M*
        # primaries; D1/W1/MN1 skip prescreen and were unaffected).
        "p2_run_stage": spawn.get("p2_run_stage"),
        "from_date": spawn.get("from_date"),
        "to_date": spawn.get("to_date"),
        "evidence_binding_required": spawn.get("evidence_binding_required"),
        "expected_from_date": expected_from_date,
        "expected_to_date": expected_to_date,
        "expected_symbol": spawn.get("expected_symbol"),
        "expected_period": spawn.get("expected_period"),
        "expected_expert": spawn.get("expected_expert"),
        "expected_ex5_sha256": spawn.get("expected_ex5_sha256"),
        "expected_setfile_sha256": spawn.get("expected_setfile_sha256"),
        "expected_mq5_sha256": spawn.get("expected_mq5_sha256"),
    })
    # Bind the runner's actual inner budget before monitoring starts.  The
    # active-age reaper deliberately derives its outer ceiling from this field;
    # omitting it collapsed long but healthy Q02 full runs back to the generic
    # 45-minute ceiling even when run_smoke had been launched with a two-hour
    # budget.
    try:
        spawn_timeout_seconds = int(spawn.get("timeout_seconds") or 0)
    except (TypeError, ValueError):
        spawn_timeout_seconds = 0
    if spawn_timeout_seconds > 0:
        payload["timeout_seconds"] = spawn_timeout_seconds

    def _record_spawn() -> None:
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                (json.dumps(payload, sort_keys=True), now, item["id"]),
            )
            conn.commit()

    _with_sqlite_retry(_record_spawn)

    return _monitor_spawned_work_item(root, item, terminal, spawn, payload, timeout_seconds)


def _disk_free_gb(root: Path) -> float:
    """Free space (GB) on the runtime drive. Fail-open (inf) on error so a
    measurement glitch never wedges the worker."""
    try:
        return shutil.disk_usage(root.anchor or str(root)).free / (1024 ** 3)
    except Exception:
        return float("inf")


def _memory_headroom_gb() -> tuple[float, float]:
    """Return (free physical RAM, free system commit) in GB via Win32.

    ``ullAvailPageFile`` is Windows' currently available commit, despite the
    historic field name. The SYSTEM Python has no psutil dependency. Physical
    RAM remains fail-open on probe error; commit returns NaN so admission pauses
    and retries instead of bypassing the crash-prevention gate.
    """
    if sys.platform != "win32":
        return float("inf"), float("inf")
    try:
        import ctypes

        class _MEMSTATEX(ctypes.Structure):
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

        stat = _MEMSTATEX()
        stat.dwLength = ctypes.sizeof(_MEMSTATEX)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return float("inf"), float("nan")
        gib = 1024 ** 3
        return stat.ullAvailPhys / gib, stat.ullAvailPageFile / gib
    except Exception:
        return float("inf"), float("nan")


def _free_ram_gb() -> float:
    """Free physical RAM in GB; fail-open on probe error."""
    return _memory_headroom_gb()[0]


_CPU_SAMPLE_PREV: dict[str, int] = {}


def _cpu_load_percent() -> float:
    """System CPU load (percent) since the previous call; 0.0 on first call.

    GetSystemTimes delta over the caller's own loop cadence — the worker loop
    sleeps multiple seconds between iterations, so the value is a sustained
    average over that window, not an instantaneous spike. Fail-open (0.0) on
    probe errors, matching the RAM probe's crash-prevention-only contract.
    """
    try:
        import ctypes

        class _FileTime(ctypes.Structure):
            _fields_ = [("lo", ctypes.c_uint32), ("hi", ctypes.c_uint32)]

        idle, kernel, user = _FileTime(), _FileTime(), _FileTime()
        if not ctypes.windll.kernel32.GetSystemTimes(
            ctypes.byref(idle), ctypes.byref(kernel), ctypes.byref(user)
        ):
            return 0.0

        def _ticks(ft: "_FileTime") -> int:
            return (int(ft.hi) << 32) | int(ft.lo)

        idle_ticks = _ticks(idle)
        # Kernel time includes idle time; busy = (kernel - idle) + user.
        busy_ticks = (_ticks(kernel) - idle_ticks) + _ticks(user)
        prev_idle = _CPU_SAMPLE_PREV.get("idle")
        prev_busy = _CPU_SAMPLE_PREV.get("busy")
        _CPU_SAMPLE_PREV["idle"] = idle_ticks
        _CPU_SAMPLE_PREV["busy"] = busy_ticks
        if prev_idle is None or prev_busy is None:
            return 0.0
        delta_idle = idle_ticks - prev_idle
        delta_busy = busy_ticks - prev_busy
        total = delta_idle + delta_busy
        if total <= 0:
            return 0.0
        return 100.0 * delta_busy / total
    except Exception:
        return 0.0


def _claim_spacing_remaining_seconds(last_claim_iso: "str | None", now_iso: str) -> float:
    """Seconds until the fleet-wide claim stagger admits the next claim.

    One successful claim per CLAIM_SPACING_SECONDS across all workers (OWNER
    2026-08-15). Missing or unparseable ledger timestamps fail open — the
    stagger is a ramp-shaping aid, never a correctness gate.
    """
    if not last_claim_iso:
        return 0.0
    try:
        last_dt = datetime.fromisoformat(str(last_claim_iso))
        now_dt = datetime.fromisoformat(str(now_iso))
    except ValueError:
        return 0.0
    if last_dt.tzinfo is None:
        last_dt = last_dt.replace(tzinfo=timezone.utc)
    if now_dt.tzinfo is None:
        now_dt = now_dt.replace(tzinfo=timezone.utc)
    elapsed = (now_dt - last_dt).total_seconds()
    if elapsed < 0:
        # Clock skew / future timestamp: fail open rather than wedge the fleet.
        return 0.0
    return max(0.0, CLAIM_SPACING_SECONDS - elapsed)


def _commit_headroom_gb() -> float:
    """Free system-commit headroom; NaN makes Windows admission pause on error."""
    return _memory_headroom_gb()[1]


def _trigger_disk_purge() -> None:
    """Best-effort kick of the cache-purge task, cooldown-guarded to avoid spam."""
    now = time.monotonic()
    if now - _last_disk_purge_trigger[0] < _DISK_PURGE_COOLDOWN_SECONDS:
        return
    _last_disk_purge_trigger[0] = now
    try:
        subprocess.run(
            ["schtasks", "/run", "/TN", DISK_PURGE_TASK],
            capture_output=True, timeout=15,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except Exception:
        pass


def _pause_after_unclaimed(claim: dict[str, Any], terminal: str) -> None:
    if claim.get("reason") == "sqlite_locked":
        print(json.dumps({"event": "sqlite_locked", "terminal": terminal, "action": "claim_backoff"}), flush=True)
        time.sleep(SQLITE_LOCK_BACKOFF_SECONDS + random.random())
        return
    if claim.get("reason") == "news_calendar_preflight_failed":
        print(
            json.dumps(
                {
                    "event": "news_calendar_preflight_deferred",
                    "terminal": terminal,
                    "status": claim.get("calendar_status"),
                    "principal": claim.get("principal"),
                    "common_dir": claim.get("common_dir"),
                    "news_calendar_preflight": claim.get("news_calendar_preflight"),
                },
                sort_keys=True,
            ),
            flush=True,
        )
        time.sleep(NEWS_CALENDAR_GUARD_SLEEP_SECONDS)
        return
    if claim.get("reason") in {"commit_probe_failed", "commit_headroom_low"}:
        print(json.dumps({
            "event": (
                "commit_probe_failed_pause"
                if claim.get("reason") == "commit_probe_failed"
                else "commit_headroom_low_pause"
            ),
            "terminal": terminal,
            "commit_headroom_gb": claim.get("commit_headroom_gb"),
            "commit_reserved_gb": claim.get("commit_reserved_gb"),
            "effective_commit_headroom_gb": claim.get("effective_commit_headroom_gb"),
            "commit_reservation_count": claim.get("commit_reservation_count"),
            "commit_reservation_detail": claim.get("commit_reservation_detail"),
            "threshold_gb": claim.get("threshold_gb"),
        }), flush=True)
        time.sleep(COMMIT_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
        return
    if claim.get("reason") in {"multisymbol_registry_unavailable", "watchdog_reset_pending"}:
        print(json.dumps({
            "event": f"{claim.get('reason')}_pause",
            "terminal": terminal,
            "error": claim.get("error"),
        }), flush=True)
        time.sleep(POLL_SLEEP_SECONDS + random.uniform(0, 5))
        return
    reason = str(claim.get("reason") or "unknown")
    now_mono = time.monotonic()
    interval = 300.0 if reason == "no_pending_claimable" else 60.0
    if now_mono - _UNCLAIMED_DECLINE_LOG_LAST.get(reason, 0.0) >= interval:
        _UNCLAIMED_DECLINE_LOG_LAST[reason] = now_mono
        print(json.dumps({
            "event": "claim_declined",
            "terminal": terminal,
            "reason": reason,
            "lock": claim.get("lock"),
            "history_skipped": len(claim.get("history_skipped") or []),
            "launch_cooldown_skipped": len(claim.get("launch_cooldown_skipped") or []),
        }), flush=True)
    if reason == "factory_mutation_lock_busy":
        # A held restart window lasts minutes. Ten workers cycling the full
        # gate+claim path every 2s are exactly the WAL reader/writer churn
        # that starved the ceremony's post-commit FULL-checkpoint evidence
        # (2026-08-14 Factory_ON abort: log 57->64 while checkpointed 54->55
        # across the whole 36x2.5s envelope).
        time.sleep(COMMIT_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
        return
    if reason == "claim_spacing_wait":
        # Sleep out (most of) the stagger window instead of hammering the
        # write lock every POLL_SLEEP_SECONDS; jitter de-synchronizes the
        # fleet so a random worker wins the next window.
        retry_after = float(claim.get("retry_after_seconds") or CLAIM_SPACING_SECONDS)
        time.sleep(min(CLAIM_SPACING_SECONDS, max(retry_after, 1.0)) + random.uniform(0, 5))
        return
    time.sleep(POLL_SLEEP_SECONDS)


def run_loop(root: Path, terminal: str, timeout_seconds: int) -> int:
    """Run the resident production owner for this terminal's runner Jobs.

    Each contained child Job handle lives in farmctl's in-process registry.
    Keeping this daemon alive until the complete child tree exits is therefore
    part of the containment contract; orderly worker exit intentionally closes
    those handles and kills any still-running descendants.
    """

    signal.signal(signal.SIGINT, _handle_stop)
    signal.signal(signal.SIGTERM, _handle_stop)
    released = release_stale_claims_for_terminal(root, terminal)
    if released:
        print(json.dumps({"event": "released_stale_claims", "terminal": terminal, "item_ids": released}), flush=True)
    startup_gate = _custom_history_gate(root, terminal)
    print(json.dumps({"event": "custom_history_startup_gate", **startup_gate}, sort_keys=True), flush=True)
    while not _STOP:
        free_gb = _disk_free_gb(root)
        if free_gb < DISK_MIN_FREE_GB:
            print(json.dumps({"event": "disk_low_pause", "terminal": terminal,
                              "free_gb": round(free_gb, 1), "threshold_gb": DISK_MIN_FREE_GB}), flush=True)
            _trigger_disk_purge()
            time.sleep(DISK_GUARD_SLEEP_SECONDS)
            continue
        free_ram = _free_ram_gb()
        # Hysteresis: after a low-RAM trip, claims stay paused until free RAM
        # recovers to RAM_RESUME_FREE_GB — sustained improvement, not the first
        # sample that crawls back over the trip floor (OWNER 2026-08-15).
        ram_floor = RAM_RESUME_FREE_GB if _RESOURCE_LATCH["ram_low"] else RAM_MIN_FREE_GB
        if free_ram < ram_floor:
            _RESOURCE_LATCH["ram_low"] = True
            print(json.dumps({"event": "ram_low_pause", "terminal": terminal,
                              "free_ram_gb": round(free_ram, 1), "threshold_gb": ram_floor,
                              "hysteresis_latched": True}), flush=True)
            # jitter so the fleet doesn't wake in lockstep and re-spike RAM together
            time.sleep(RAM_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
            continue
        _RESOURCE_LATCH["ram_low"] = False
        cpu_load = _cpu_load_percent()
        cpu_ceiling = (
            CPU_RESUME_LOAD_PERCENT if _RESOURCE_LATCH["cpu_high"] else CPU_MAX_LOAD_PERCENT
        )
        if cpu_load > cpu_ceiling:
            _RESOURCE_LATCH["cpu_high"] = True
            print(json.dumps({"event": "cpu_high_pause", "terminal": terminal,
                              "cpu_load_percent": round(cpu_load, 1),
                              "threshold_percent": cpu_ceiling,
                              "hysteresis_latched": True}), flush=True)
            time.sleep(CPU_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
            continue
        _RESOURCE_LATCH["cpu_high"] = False
        if not _claim_queue_may_need_mutation(root, terminal):
            time.sleep(POLL_SLEEP_SECONDS)
            continue
        history_gate = _custom_history_gate(root, terminal)
        if history_gate.get("required") and (
            history_gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
            or history_gate.get("admission_allowed") is False
        ):
            print(json.dumps({"event": "custom_history_gate_pause", **history_gate}, sort_keys=True), flush=True)
            time.sleep(CUSTOM_HISTORY_GUARD_SLEEP_SECONDS)
            continue
        try:
            lease_result = _acquire_custom_history_lease(root, terminal)
        except Exception as exc:
            print(json.dumps({
                "event": "custom_history_lease_error_pause",
                "terminal": terminal,
                "error": repr(exc),
            }, sort_keys=True), flush=True)
            time.sleep(CUSTOM_HISTORY_GUARD_SLEEP_SECONDS)
            continue
        if lease_result.required and not lease_result.acquired:
            print(json.dumps({
                "event": "custom_history_lease_busy",
                "terminal": terminal,
                "reason": lease_result.reason,
                "detail": lease_result.detail,
            }, sort_keys=True), flush=True)
            time.sleep(POLL_SLEEP_SECONDS + random.uniform(0, 2))
            continue
        lease_handle = lease_result.handle
        try:
            claim = claim_atomic(root, terminal)
            if not claim.get("claimed"):
                _pause_after_unclaimed(claim, terminal)
                continue
            item = claim["item"]
            if lease_handle is not None:
                lease_handle.bind_work_item(item["id"])
            print(json.dumps({
                "event": "claimed",
                "terminal": terminal,
                "item_id": item["id"],
                "custom_history_gate_audit_sha256": history_gate.get("audit_sha256"),
                "custom_history_lease_token": lease_handle.token if lease_handle else None,
            }), flush=True)
            result = _run_claimed_item(root, item, terminal, timeout_seconds)
            stop_condition = _custom_history_stop_condition(result)
            if stop_condition and history_gate.get("required"):
                custom_history_lease.engage_emergency_mode(
                    root,
                    reason=f"runtime_stop_condition:{stop_condition}",
                    activation_sha256=str(history_gate.get("activation_sha256")),
                )
            print(json.dumps({"event": "run_result", "terminal": terminal, **result}, sort_keys=True), flush=True)
        finally:
            if lease_handle is not None:
                release_status = lease_handle.release()
                print(json.dumps({
                    "event": "custom_history_lease_release",
                    "terminal": terminal,
                    "status": release_status,
                }, sort_keys=True), flush=True)
    return 0


def _acquire_instance_mutex(terminal: str):
    """One worker per terminal, enforced by the OS (2026-07-06).

    The recurring duplicate-spawn class (watchdog flap 06-22, double-spawn
    06-05/07-05, midnight dedupe re-spawn 07-06) always came from SPAWNER-side
    detection failing (console children like tasklist/powershell can die under
    0xC0000142-class console-init failures while pythonw keeps running). A named
    mutex held by the worker itself makes duplicates structurally impossible no
    matter how broken the spawner's view is. Returns the handle (keep alive for
    process lifetime), False if another instance holds it, None if unavailable
    (non-win32 / create failed -> proceed unguarded, spawner checks still apply).
    """
    if sys.platform != "win32":
        return None
    import ctypes
    kernel32 = ctypes.windll.kernel32
    name = f"Global\\QM_TerminalWorker_{terminal.upper()}"
    handle = kernel32.CreateMutexW(None, True, name)
    if not handle:
        return None
    ERROR_ALREADY_EXISTS = 183
    if kernel32.GetLastError() == ERROR_ALREADY_EXISTS:
        kernel32.CloseHandle(handle)
        return False
    return handle


def _install_exit_tracer(terminal: str) -> None:
    """Log every *orderly* exit path so a hard kill is identifiable by silence.

    Workers have been vanishing with a resource-pause event as their last line
    and an empty stderr (2026-07-26: T4/T9/T10 17:45, T6/T10 18:29, T2/T8/T10
    18:40, T4/T7 19:10). No traceback means it is not an unhandled exception,
    but "no log line either" left clean-exit and external termination
    indistinguishable. Windows runs neither atexit handlers nor signal handlers
    on TerminateProcess, so from now on:

        worker_exit present  -> the worker chose to stop (or was signalled)
        worker_exit absent   -> something killed the process outright

    which is the discriminator the next investigation needs.
    """
    def _emit(reason: str, detail: dict[str, Any] | None = None) -> None:
        try:
            print(json.dumps({
                "event": "worker_exit",
                "terminal": terminal,
                "reason": reason,
                "pid": os.getpid(),
                "free_ram_gb": round(_free_ram_gb(), 1),
                **(detail or {}),
            }, sort_keys=True), flush=True)
        except Exception:
            pass

    atexit.register(_emit, "atexit")
    for signal_name in ("SIGTERM", "SIGINT", "SIGBREAK"):
        handler_signal = getattr(signal, signal_name, None)
        if handler_signal is None:
            continue
        try:
            signal.signal(
                handler_signal,
                lambda signum, frame, _n=signal_name: (
                    _emit("signal", {"signal": _n}),
                    sys.exit(128),
                ),
            )
        except (ValueError, OSError):
            pass


def main(argv: list[str] | None = None) -> int:
    # DL-065: the terminal worker is deterministic factory machinery (trusted
    # base), not a spawned agent. Without this, a spawn chain that does not
    # export QM_AGENT_ID leaves the worker as 'unknown' and every post-PASS
    # cascade enqueue dies fail-closed in agent_scopes.guard (fleet churn
    # 2026-08-01). setdefault keeps explicit spawned identities intact.
    os.environ.setdefault("QM_AGENT_ID", "controller")
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal", required=True, choices=farmctl.MT5_TERMINALS)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--timeout-minutes", type=float, default=90.0)
    parser.add_argument(
        "--work-item-id",
        help="run exactly this pending work item once; requires FACTORY_OFF.flag",
    )
    args = parser.parse_args(argv)
    mutex = _acquire_instance_mutex(args.terminal)
    if mutex is False:
        print(json.dumps({"event": "duplicate_instance_exit", "terminal": args.terminal}))
        return 0
    faulthandler.enable()
    _install_exit_tracer(args.terminal)
    print(json.dumps({
        "event": "worker_start",
        "terminal": args.terminal,
        "pid": os.getpid(),
    }, sort_keys=True), flush=True)
    _start_stalldump_watcher(args.terminal)
    if args.work_item_id:
        history_gate = _custom_history_gate(args.root, args.terminal)
        if history_gate.get("required") and (
            history_gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
            or history_gate.get("admission_allowed") is False
        ):
            print(json.dumps({"event": "target_custom_history_gate_refused", **history_gate}, sort_keys=True))
            return 2
        lease_result = _acquire_custom_history_lease(args.root, args.terminal)
        if lease_result.required and not lease_result.acquired:
            print(json.dumps({
                "event": "target_custom_history_lease_refused",
                "terminal": args.terminal,
                "reason": lease_result.reason,
                "detail": lease_result.detail,
            }, sort_keys=True))
            return 2
        lease_handle = lease_result.handle
        try:
            claim = claim_specific_atomic(args.root, args.terminal, args.work_item_id)
            if not claim.get("claimed"):
                print(json.dumps({"event": "target_claim_refused", "terminal": args.terminal, **claim}, sort_keys=True))
                return 2
            item = claim["item"]
            if lease_handle is not None:
                lease_handle.bind_work_item(item["id"])
            print(json.dumps({"event": "target_claimed", "terminal": args.terminal, "item_id": item["id"]}), flush=True)
            result = _run_claimed_item(args.root, item, args.terminal, int(args.timeout_minutes * 60))
            print(json.dumps({"event": "target_run_result", "terminal": args.terminal, **result}, sort_keys=True), flush=True)
            return 0 if result.get("status") == "done" and result.get("verdict") == "PASS" else 1
        finally:
            if lease_handle is not None:
                lease_handle.release()
    return run_loop(args.root, args.terminal, int(args.timeout_minutes * 60))


if __name__ == "__main__":
    raise SystemExit(main())
