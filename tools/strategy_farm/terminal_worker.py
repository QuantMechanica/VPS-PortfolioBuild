#!/usr/bin/env python
"""Long-running per-terminal worker for QM strategy_farm.

Usage:
    python terminal_worker.py --terminal T1
"""

from __future__ import annotations

import argparse
import faulthandler
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

import farmctl


POLL_SLEEP_SECONDS = 2.0
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
RAM_MIN_FREE_GB = 4.0
RAM_GUARD_SLEEP_SECONDS = 20
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
ORDINARY_COMMIT_RESERVATION_GB = 8.0
WATCHDOG_RESET_BLOCK_FILENAME = "WATCHDOG_RESET_PENDING.json"
# Multi-symbol real-tick jobs need materially more launch headroom than ordinary
# single-symbol jobs. A low-memory launch can generate a syntactically valid
# MT5 report with 0 bars and get misclassified as symbol history failure.
MULTISYMBOL_RAM_MIN_FREE_GB = 12.0
# Observed multi-symbol working sets range from 20-44GB.  Keep that worst case
# plus a small system margin available before admitting another heavy job.
MULTISYMBOL_COMMIT_MIN_FREE_GB = 48.0
MULTISYMBOL_COMMIT_RESERVATION_GB = 44.0
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
# Shared-bases history-lock STORM (2026-07-21 diagnosis,
# docs/ops/evidence/2026-07-21_qm20004_infra_diagnosis.md). T2-T10 `bases` are NTFS
# junctions to ONE T1 store that ALSO holds the raw Darwinex-Live history. Every
# transient tester spawn logs into the live account and writes live quotes into that
# one store, so concurrent spawns collide with sharing-violations. A FINISHED — often
# profitable — pass whose deposit-currency conversion symbol (raw EURUSD for EUR-quoted
# indices, or the test symbol itself) is locked at pass-end re-sync gets its report
# DISCARDED ("history synchronization error [Not found]" / terminal "some error after
# pass finished ... in 0:00:00.000") -> no summary latched -> summary_missing. Measured
# storm: GDAXI 126 INFRA vs 58 PASS, NDX 68 vs 23 — 2/3 of index-symbol gate attempts
# burned. The EA is innocent, so this signature auto-heals as a SEPARATE transient-retry
# class that (a) steers off the sick terminal via avoid_terminals and (b) does NOT
# consume the strategy MAX_WORK_ITEM_RETRIES budget. The STRUCTURAL cure (de-junction /
# remap conversion to .DWX) needs a factory-OFF window and is deferred; this is the
# factory-ON mitigation. Tokens are matched case-insensitively against the tail of the
# terminal's own MT5 logs; they are specific to this class and never appear for a
# genuine 0-trade / PF-fail run (which produces a real summary and never reaches here).
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
SMOKE_TERMINAL_EXIT_GRACE_SECONDS = 60.0
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
    return """
        SELECT w.*,
          CASE
            WHEN w.payload_json LIKE '%"priority_track": true%' THEN 0
            ELSE 1 END AS _priority_track_rank,
          CASE w.phase
            -- Downstream phases first so work drains rather than re-pooling
            -- at the head of the pipeline. Without this Q04+ stars in
            -- 'ELSE 9' alongside Q02 and lose every FIFO tie to fresh Q02
            -- inflow, leaving Q03-PASS-promoted Q04 rows starved.
            -- Legacy P-keys preserved at their original ranks for any work
            -- still using the old nomenclature.
            WHEN 'Q10'  THEN 0
            WHEN 'Q09_PORTFOLIO' THEN 1
            WHEN 'Q09'  THEN 1
            WHEN 'Q08'  THEN 2
            WHEN 'Q07'  THEN 3
            WHEN 'Q06'  THEN 4
            WHEN 'Q05'  THEN 5
            WHEN 'Q04'  THEN 6
            WHEN 'Q03'  THEN 7
            WHEN 'Q02'  THEN 8
            WHEN 'P8'   THEN 0
            WHEN 'P7'   THEN 1
            WHEN 'P6'   THEN 2
            WHEN 'P5c'  THEN 3
            WHEN 'P5b'  THEN 4
            WHEN 'P5'   THEN 5
            WHEN 'P4'   THEN 6
            WHEN 'P3.5' THEN 7
            WHEN 'P3'   THEN 8
            WHEN 'P2'   THEN 9
            ELSE 9 END AS _phase_rank,
          CASE
            WHEN w.phase='Q02' AND w.payload_json LIKE '%"portfolio_scope": "basket"%' THEN 0
            ELSE 1 END AS _basket_q02_rank,
          CASE WHEN EXISTS (
            SELECT 1 FROM work_items wp
            WHERE wp.ea_id=w.ea_id AND wp.status='done' AND wp.verdict='PASS'
          ) THEN 0 ELSE 1 END AS _winner_rank,
          -- Asset-class tie-break (2026-07-09, Claude). Within an otherwise-equal
          -- (track, phase, basket, winner) tier, prefer the classes that actually
          -- survive the Q04 net/commission gate. Measured Q04 net-pass by class
          -- (docs/ops/evidence/q02_q04_survival_by_assetclass_2026-07-09.csv):
          --   METAL 12.2% > INDEX 6.9% > ENERGY 2.4% > FX 1.6%.
          -- FX passes the $0-commission Q02 gross pre-screen best (68.6%) but dies
          -- at Q04, so FIFO order was spending the scarce Q02 CPU front-loading the
          -- lowest-yield class (FX = 51% of the pending queue). This ONLY reorders
          -- pre-screens: promoted Q04+ survivors still beat any Q02 via _phase_rank,
          -- so FX *survivors* are never delayed — only FX *pre-screens* wait behind
          -- metal/index. Executes OWNER's 2026-07-06 "Index/Metalle zuerst" mandate.
          -- Reversible; ordering is never a gate. Baskets already jump via
          -- _basket_q02_rank, so they need no asset boost here.
          CASE
            WHEN upper(w.symbol) LIKE 'XAU%' OR upper(w.symbol) LIKE 'XAG%'
              OR upper(w.symbol) LIKE 'XPT%' OR upper(w.symbol) LIKE 'XCU%' THEN 0
            WHEN upper(w.symbol) LIKE 'SP500%' OR upper(w.symbol) LIKE 'NDX%'
              OR upper(w.symbol) LIKE 'WS30%' OR upper(w.symbol) LIKE 'US30%'
              OR upper(w.symbol) LIKE 'US2000%' OR upper(w.symbol) LIKE 'GDAXI%'
              OR upper(w.symbol) LIKE 'GER40%' OR upper(w.symbol) LIKE 'UK100%'
              OR upper(w.symbol) LIKE 'STOXX%' OR upper(w.symbol) LIKE '%225%'
              OR upper(w.symbol) LIKE 'DAX%' THEN 1
            WHEN upper(w.symbol) LIKE 'XTI%' OR upper(w.symbol) LIKE 'XBR%'
              OR upper(w.symbol) LIKE 'XNG%' OR upper(w.symbol) LIKE 'WTI%'
              OR upper(w.symbol) LIKE 'NGAS%' OR upper(w.symbol) LIKE '%OIL%' THEN 2
            ELSE 3 END AS _asset_rank
        FROM work_items w
        WHERE w.status='pending'
        ORDER BY _priority_track_rank ASC, _phase_rank ASC, _basket_q02_rank ASC, _winner_rank ASC, _asset_rank ASC, w.updated_at ASC, w.created_at ASC
    """


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
    payload_symbols = payload.get("basket_symbols")
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


def _commit_admission_snapshot(
    conn: sqlite3.Connection,
    now_iso: str,
    multisym_ids: frozenset,
) -> dict[str, Any]:
    """Measure commit headroom minus recent atomic claim reservations.

    Windows' commit charge does not jump at SQLite claim time. Without a durable
    reservation, every worker can observe the same headroom and over-admit work
    before any child reaches its peak. Active claims reserve their expected peak
    for the bounded launch/warm-up window; afterwards the OS measurement is the
    source of truth. The reservation is deliberately conservative and disappears
    immediately when the work item leaves ``active``.
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
        until = _parse_utc_iso(payload.get("commit_reservation_until_utc"))
        claimed_at = _parse_utc_iso(payload.get("claimed_at_iso"))
        if until is None and claimed_at is not None:
            until = claimed_at + timedelta(seconds=COMMIT_RESERVATION_SECONDS)
        if until is None or until <= now_dt:
            continue
        item_is_multisym = _work_item_is_multisymbol(row, payload, multisym_ids)
        default_reservation = (
            MULTISYMBOL_COMMIT_RESERVATION_GB
            if item_is_multisym
            else ORDINARY_COMMIT_RESERVATION_GB
        )
        try:
            reservation_gb = max(
                0.0,
                float(payload.get("commit_reservation_gb") or default_reservation),
            )
        except (TypeError, ValueError):
            reservation_gb = default_reservation
        reserved_gb += reservation_gb
        reservations.append({
            "item_id": row["id"],
            "ea_id": row["ea_id"],
            "reservation_gb": reservation_gb,
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
) -> None:
    claimed_at = _parse_utc_iso(claimed_at_iso) or datetime.now(timezone.utc)
    payload["commit_reservation_gb"] = (
        MULTISYMBOL_COMMIT_RESERVATION_GB
        if multisymbol
        else ORDINARY_COMMIT_RESERVATION_GB
    )
    payload["commit_reservation_until_utc"] = (
        claimed_at + timedelta(seconds=COMMIT_RESERVATION_SECONDS)
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
    return terminals


_STALE_RUNTIME_PAYLOAD_KEYS = (
    "pid",
    "started_at_iso",
    "log_path",
    "claimed_at_iso",
    "claimed_by_worker_pid",
    "commit_reservation_gb",
    "commit_reservation_until_utc",
    "terminal",
)


def _clear_stale_runtime_payload(payload: dict[str, Any]) -> None:
    for field in _STALE_RUNTIME_PAYLOAD_KEYS:
        payload.pop(field, None)


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
) -> dict[str, Any] | None:
    """Return storm-signature evidence if the terminal's recent MT5 logs show the
    shared-bases history-lock class, else None.

    Scans only the TAIL of the most recently-written terminal / tester / agent logs
    (bounded by HISTORY_LOCK_SCAN_TAIL_BYTES and HISTORY_LOCK_SCAN_MAX_FILES) so a
    multi-GB storm log can never be read whole. Fail-open (returns None on any error).
    """
    name = str(terminal or "").strip().upper()
    if not name:
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

    candidates.sort(key=_mtime, reverse=True)
    for path in candidates[:HISTORY_LOCK_SCAN_MAX_FILES]:
        text = _decode_log_tail(_read_tail_bytes(path, HISTORY_LOCK_SCAN_TAIL_BYTES)).lower()
        if not text:
            continue
        for token in HISTORY_LOCK_STORM_TOKENS:
            if token in text:
                return {"terminal": name, "token": token, "log_path": str(path)}
    return None


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
    def _claim() -> dict[str, Any]:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        db_path = root / farmctl.DB_REL
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

                if root.resolve() == farmctl.DEFAULT_ROOT.resolve() and terminal in farmctl._running_mt5_terminals():
                    conn.commit()
                    return {"claimed": False, "reason": "terminal_process_busy", "terminal": terminal}

                if _watchdog_reset_admission_blocked(root):
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "watchdog_reset_pending",
                        "terminal": terminal,
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
                        "threshold_gb": COMMIT_MIN_FREE_GB,
                    }

                active_symbols = farmctl._active_work_item_symbols(conn)
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
                for item in conn.execute(_priority_pending_query()).fetchall():
                    payload = _json_loads(item["payload_json"])
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
                    if symbol_key and symbol_key in active_symbols:
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
                        conn.commit()
                        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
                        return {"claimed": True, "item": dict(row)}
                conn.commit()
                return {
                    "claimed": False,
                    "reason": "no_pending_claimable",
                    "history_skipped": skipped_history,
                    "launch_cooldown_skipped": skipped_launch_cooldown,
                    "multisymbol_ram_skipped": skipped_multisym_ram,
                    "multisymbol_commit_skipped": skipped_multisym_commit,
                    "terminal_avoid_skipped": skipped_avoid_terminal,
                }
            except Exception:
                conn.rollback()
                raise

    try:
        return _with_sqlite_retry(_claim)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return {"claimed": False, "reason": "sqlite_locked"}


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

    def _claim() -> dict[str, Any]:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        db_path = root / farmctl.DB_REL
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
                active_symbols = farmctl._active_work_item_symbols(conn)
                if symbol_key and symbol_key in active_symbols:
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


def _find_work_item_summary_data(item: sqlite3.Row, payload: dict[str, Any]) -> tuple[Path, dict[str, Any]] | None:
    phase = str(item["phase"])
    if phase in farmctl.REAL_PHASE_RUNNER_PHASES:
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
    if not summary_path:
        return None
    summary = _load_fresh_summary(summary_path, payload)
    if summary is None:
        return None
    return summary_path, summary


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
    if source_dir.resolve() == target_dir.resolve():
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


def _smoke_terminal_exit_stalled(item: dict[str, Any], payload: dict[str, Any]) -> bool:
    """Detect run_smoke wrappers stuck after MT5 already exited.

    Q02/Q03 (and legacy P2/P3 aliases) use a single run_smoke.ps1 child. If
    its log has reached terminal_exit but no summary appears and the log is
    quiet, waiting for the full worker timeout only blocks the symbol dedupe
    queue.
    """
    if str(item.get("phase") or "").upper() not in {"Q02", "Q03", "P2", "P3"}:
        return False
    if _find_summary(payload.get("report_root"), payload):
        return False
    log_path = payload.get("log_path")
    if not log_path:
        return False
    path = Path(str(log_path))
    try:
        stat = path.stat()
        if time.time() - stat.st_mtime < SMOKE_TERMINAL_EXIT_GRACE_SECONDS:
            return False
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
    except OSError:
        return False
    last_start = text.rfind("run_smoke.stage=terminal_start")
    last_exit = text.rfind("run_smoke.stage=terminal_exit")
    return last_exit >= 0 and last_start >= 0 and last_exit > last_start


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


def _finish_work_item(root: Path, item_id: str, exit_code: int | None) -> dict[str, Any]:
    def _finish() -> dict[str, Any]:
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            item = conn.execute("SELECT * FROM work_items WHERE id=?", (item_id,)).fetchone()
            if not item:
                return {"finished": False, "reason": "missing_item"}
            payload = _json_loads(item["payload_json"])
            summary_data = _find_work_item_summary_data(item, payload)
            if summary_data:
                summary_path, summary = summary_data
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
                payload["verdict_reason"] = reason
                payload["evidence_provenance"] = "phase_runner" if item["phase"] in farmctl.REAL_PHASE_RUNNER_PHASES else "real_mt5"
                payload["verdict_taxonomy"] = "infra" if verdict == "INFRA_FAIL" else "strategy"
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
                    storm = _detect_history_lock_storm(failed_terminal)
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
                payload["final_failure"] = "summary_missing_retries_exhausted"
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict='INFRA_FAIL', claimed_by=NULL,
                        payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "failed"
                verdict = "INFRA_FAIL"
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
    if not parent_task_id:
        return None
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        summary = conn.execute(
            """
            SELECT COUNT(*) AS total,
                   SUM(CASE WHEN status='done' OR status='failed' THEN 1 ELSE 0 END) AS finished
            FROM work_items
            WHERE parent_task_id=?
            """,
            (parent_task_id,),
        ).fetchone()
        if not summary or int(summary["total"] or 0) == 0 or summary["total"] != summary["finished"]:
            return None
        parent = conn.execute("SELECT * FROM tasks WHERE id=?", (parent_task_id,)).fetchone()
        if not parent or parent["status"] == "done":
            return None
        wis = conn.execute("SELECT * FROM work_items WHERE parent_task_id=?", (parent_task_id,)).fetchall()
        phase = _phase_from_task_kind(parent["kind"])
        pass_symbols = [w["symbol"] for w in wis if w["verdict"] == "PASS"]
        p2_profit_skipped: list[dict[str, Any]] = []
        if phase == "P2":
            surviving, p2_profit_skipped = farmctl._filter_p2_profitable_symbols(conn, parent_task_id, pass_symbols)
        else:
            surviving = pass_symbols
        verdict = farmctl._aggregate_work_item_verdict(phase, list(wis), surviving)
        classification: dict[str, Any] = {
            "verdict": verdict,
            "surviving_symbols": surviving,
            "counts_by_verdict": {
                v: sum(1 for w in wis if w["verdict"] == v)
                for v in ("PASS", "FAIL", "ZERO_TRADES", "DRAFT_DEFECT", "MIN_TRADES_NOT_MET", "INVALID", "INFRA_FAIL")
            },
            "source": "terminal_worker_aggregate",
        }
        if verdict == "DRAFT_DEFECT":
            classification["route"] = "RE_DRAFT"
            classification["retire_strategy"] = False
        if p2_profit_skipped:
            classification["p2_p3_profit_filter_skipped"] = p2_profit_skipped
        parent_payload = _json_loads(parent["payload_json"])
        parent_payload["classification"] = classification
        parent_payload["completed_at_iso"] = now
        conn.execute(
            "UPDATE tasks SET status='done', payload_json=?, updated_at=? WHERE id=?",
            (json.dumps(parent_payload, sort_keys=True), now, parent_task_id),
        )
        conn.commit()

    auto_next = None
    if verdict == "PASS":
        next_map = {"P2": "P3", "P3": "P3.5", "P3.5": "P4"}
        next_phase = next_map.get(phase)
        if next_phase and next_phase in farmctl.SUPPORTED_BACKTEST_PHASES:
            npp_kind = next_phase.lower().replace(".", "")
            with farmctl.connect(root) as conn:
                existing = conn.execute(
                    "SELECT id FROM tasks WHERE kind=? AND payload_json LIKE ?",
                    (f"backtest_{npp_kind}", f"%\"ea_id\": \"{parent_payload.get('ea_id')}\"%"),
                ).fetchone()
            if not existing:
                enq = farmctl.enqueue_backtest(root, parent_task_id, next_phase)
                if enq.get("enqueued"):
                    auto_next = {
                        "phase": next_phase,
                        "task_id": enq.get("task_id"),
                        "work_items_created": len(enq.get("work_items_created", [])),
                    }
    return {
        "parent_task_id": parent_task_id,
        "phase": phase,
        "verdict": verdict,
        "surviving_symbols": surviving,
        "auto_next": auto_next,
    }


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
        if _smoke_terminal_exit_stalled(item, payload):
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
    if child_alive or terminal_alive_after_child_exit:
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
    return {"action": "finished", "item_id": item["id"], **_finish_work_item(root, item["id"], exit_code)}


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
    # Serialize the terminal64 DLL-init window across workers to kill the 0xC0000142
    # launch_fault storm that hits when many terminals launch at once (TTL leaky
    # semaphore, fail-open — see LAUNCH_GATE_* and _acquire_launch_slot).
    _acquire_launch_slot(terminal)
    spawn = farmctl._spawn_work_item_runner(root, row, terminal)
    now = farmctl.utc_now()
    if not spawn.get("spawned"):
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
        with farmctl.connect(root) as conn:
            conn.execute(
                "UPDATE work_items SET status='failed', verdict='INFRA_FAIL', claimed_by=NULL, updated_at=? WHERE id=?",
                (now, item["id"]),
            )
            conn.commit()
        return {"action": "spawn_failed", "item_id": item["id"], "reason": spawn.get("reason")}

    payload = _json_loads(row["payload_json"])
    payload.update({
        "started_at_iso": now,
        "pid": spawn["pid"],
        "log_path": spawn["log_path"],
        "report_root": spawn["report_root"],
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
        "expected_from_date": spawn.get("expected_from_date"),
        "expected_to_date": spawn.get("expected_to_date"),
        "expected_symbol": spawn.get("expected_symbol"),
        "expected_period": spawn.get("expected_period"),
        "expected_expert": spawn.get("expected_expert"),
        "expected_ex5_sha256": spawn.get("expected_ex5_sha256"),
        "expected_setfile_sha256": spawn.get("expected_setfile_sha256"),
        "expected_mq5_sha256": spawn.get("expected_mq5_sha256"),
    })
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


def run_loop(root: Path, terminal: str, timeout_seconds: int) -> int:
    signal.signal(signal.SIGINT, _handle_stop)
    signal.signal(signal.SIGTERM, _handle_stop)
    released = release_stale_claims_for_terminal(root, terminal)
    if released:
        print(json.dumps({"event": "released_stale_claims", "terminal": terminal, "item_ids": released}), flush=True)
    while not _STOP:
        free_gb = _disk_free_gb(root)
        if free_gb < DISK_MIN_FREE_GB:
            print(json.dumps({"event": "disk_low_pause", "terminal": terminal,
                              "free_gb": round(free_gb, 1), "threshold_gb": DISK_MIN_FREE_GB}), flush=True)
            _trigger_disk_purge()
            time.sleep(DISK_GUARD_SLEEP_SECONDS)
            continue
        free_ram = _free_ram_gb()
        if free_ram < RAM_MIN_FREE_GB:
            print(json.dumps({"event": "ram_low_pause", "terminal": terminal,
                              "free_ram_gb": round(free_ram, 1), "threshold_gb": RAM_MIN_FREE_GB}), flush=True)
            # jitter so the fleet doesn't wake in lockstep and re-spike RAM together
            time.sleep(RAM_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
            continue
        claim = claim_atomic(root, terminal)
        if not claim.get("claimed"):
            if claim.get("reason") == "sqlite_locked":
                print(json.dumps({"event": "sqlite_locked", "terminal": terminal, "action": "claim_backoff"}), flush=True)
                time.sleep(SQLITE_LOCK_BACKOFF_SECONDS + random.random())
                continue
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
                    "threshold_gb": claim.get("threshold_gb"),
                }), flush=True)
                time.sleep(COMMIT_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
                continue
            if claim.get("reason") in {
                "multisymbol_registry_unavailable",
                "watchdog_reset_pending",
            }:
                print(json.dumps({
                    "event": f"{claim.get('reason')}_pause",
                    "terminal": terminal,
                    "error": claim.get("error"),
                }), flush=True)
                time.sleep(POLL_SLEEP_SECONDS + random.uniform(0, 5))
                continue
            time.sleep(POLL_SLEEP_SECONDS)
            continue
        item = claim["item"]
        print(json.dumps({"event": "claimed", "terminal": terminal, "item_id": item["id"]}), flush=True)
        result = _run_claimed_item(root, item, terminal, timeout_seconds)
        print(json.dumps({"event": "run_result", "terminal": terminal, **result}, sort_keys=True), flush=True)
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


def main(argv: list[str] | None = None) -> int:
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
    _start_stalldump_watcher(args.terminal)
    if args.work_item_id:
        claim = claim_specific_atomic(args.root, args.terminal, args.work_item_id)
        if not claim.get("claimed"):
            print(json.dumps({"event": "target_claim_refused", "terminal": args.terminal, **claim}, sort_keys=True))
            return 2
        item = claim["item"]
        print(json.dumps({"event": "target_claimed", "terminal": args.terminal, "item_id": item["id"]}), flush=True)
        result = _run_claimed_item(args.root, item, args.terminal, int(args.timeout_minutes * 60))
        print(json.dumps({"event": "target_run_result", "terminal": args.terminal, **result}, sort_keys=True), flush=True)
        return 0 if result.get("status") == "done" and result.get("verdict") == "PASS" else 1
    return run_loop(args.root, args.terminal, int(args.timeout_minutes * 60))


if __name__ == "__main__":
    raise SystemExit(main())
