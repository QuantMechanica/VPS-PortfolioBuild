#!/usr/bin/env python
"""Long-running per-terminal worker for QM strategy_farm.

Usage:
    python terminal_worker.py --terminal T1
"""

from __future__ import annotations

import argparse
import atexit
from contextlib import contextmanager
import errno
import faulthandler
import hashlib
import json
import traceback
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
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

# ``terminal_worker.py`` is launched by absolute path from the long-running
# worker starter.  In that execution mode Python adds this file's directory to
# ``sys.path``, but not the repository root, so imports from ``framework`` fail
# unless the parent process happens to provide PYTHONPATH.  Make the documented
# direct entry point self-contained before importing repository packages.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

import farmctl
from artifact_identity import identity_update_clause, prepare_completion
import custom_history_contract
import custom_history_copy_on_claim
import custom_history_gate
import custom_history_lease
import custom_history_master
import dl089_scheduling
import longrun_scheduling_policy
import next_cell_prestage
import opt_census_pruning
import opt_census_select
from framework.scripts._phase_utils import cold_cache_summary_signature
from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
try:
    from sqlite_busy import (
        BUSY_TIMEOUT_MS,
        configure_connection as configure_sqlite_connection,
        is_sqlite_busy,
        retry_sqlite_busy,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.sqlite_busy import (
        BUSY_TIMEOUT_MS,
        configure_connection as configure_sqlite_connection,
        is_sqlite_busy,
        retry_sqlite_busy,
    )


_EARLY_RUN_SMOKE_PHASES = frozenset(
    phase.upper()
    for canonical in farmctl.SUPPORTED_BACKTEST_PHASES[:2]
    for phase in (canonical, farmctl.Q_TO_LEGACY_P[canonical])
)
_Q04_PHASE = farmctl.SUPPORTED_BACKTEST_PHASES[-1]
_Q09_NEWS_PHASE = farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "NEWS")
_Q07_PHASE = "Q07"
_Q08_PHASE = "Q08"
NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE = "NEWS_RUNNER_SPAWN_SILENT_ABORT"
NEWS_RUNNER_SPAWN_ABORT_HOLD_REASON = (
    "bound news runner disappeared before durable completion; exact process "
    "identity review required before retry"
)


def _is_early_run_smoke_phase(phase: object) -> bool:
    return str(phase or "").strip().upper() in _EARLY_RUN_SMOKE_PHASES


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
# DL-089 claim-boundary pruning may parse and hash multi-gigabyte native
# reports.  Serialize that backstop on its own lock so one worker performs the
# expensive check while peers remain free to claim non-census work.  This lock
# is deliberately distinct from FACTORY_MUTATION.lock.
CLAIM_PREFLIGHT_MAX_CANDIDATES = 8
Q09_CELL_SHARDING_FLAG = "Q09_CELL_SHARDING_ENABLED"
Q09_CELL_SHARDING_MAX_TERMINALS_FLAG = "Q09_CELL_SHARDING_MAX_TERMINALS"
Q09_CELL_SHARDING_DEFAULT_MAX_TERMINALS = 4
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
# 2026-09-02 (CEO): 6/12 let six testers (4.8-11.8 GB each; XAUUSD "ordinary" runs
# use 11-12 GB against an 8 GB reservation) drive a 63 GB host to 0.9 GB free and
# 16k pages/s; three workers died. Keep ~14 GB headroom for the growth of the
# runs already started; resume only once 20 GB are free. Rollback: 6.0 / 12.0.
RAM_MIN_FREE_GB = 14.0
RAM_RESUME_FREE_GB = 20.0
# 2026-09-03 (CEO): a governed COMPILE_EA row needs well under 1 GB, yet the
# 14/20 GB latch idled six workers for hours while three DL-089 sibling
# compiles (the critical path to a pair's census) waited.  Under the latch a
# worker may still claim COMPILE_EA rows -- and only those -- as long as free
# RAM stays above this small floor.  Backtests keep the full latch.
COMPILE_RAM_MIN_FREE_GB = 3.0
_RAM_LATCH_COMPILE_ONLY = False
RAM_GUARD_SLEEP_SECONDS = 20
TEST_FREE_RAM_GB_ENV = "QM_TEST_FREE_RAM_GB"
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
# OWNER 2026-08-29 ("Aggressive 10 Sekunden"): lowered 60->10 for short-cell
# throughput; the commit/RAM/CPU/disk admission gates carry the actual crash
# protection, the stagger stays only as launch-visibility ramp shaping.
CLAIM_SPACING_SECONDS = 10.0
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
# Today's annual OPT_CENSUS metatester cells were measured in the 2-4GB
# working-set band. Reserve the observed upper bound; unlike an ordinary
# full-history/news run, a single annual cell must not inherit the flat 8GB
# class. Any multisymbol census declaration retains its heavier class.
RAM_CLASS_OPT_CENSUS_CELL = "opt_census_cell"
OPT_CENSUS_RAM_RESERVATION_GB = 4.0
# 2026-09-03 (CEO, infra repair under the standing authorization): a DL-089
# census cell reserves 4 GB but was admitted only while free RAM minus that
# reservation still cleared the full 14 GB backtest floor, i.e. at >= 18 GB
# free.  Measured today: with three or four 8-14 GB testers running, free RAM
# sits at 12-18 GB for hours, every worker reports no_pending_claimable and
# the census (the counter's critical path) crawls at 2-10 cells / 10 min.
# Census cells now need 8 GB left after their reservation (claimable from
# 12 GB free); the 2026-09-02 crash class happened at a 6/12 GB GLOBAL guard
# with 8 GB backtests, which keep the full 14/20 GB latch.  Rollback: set the
# floor back to RAM_MIN_FREE_GB and idle-reload the workers.
OPT_CENSUS_POST_RESERVATION_FLOOR_GB = 8.0
# 2026-09-03 (CEO, infra repair under the Stehende Vollmacht GRUEN zone):
# CENSUS-FIRST claim-selection priority.  Measured today: four or five heavy
# single-symbol testers (Q07 5-seed full-history 11-20 GB, multi-symbol Q02
# like QM5_12580 at 19.7 GB, news expansions 8 GB) leave 9-11 GB free, six
# workers idle in ram_low_pause and the DL-089 census (the counter's critical
# path) drops from 26 to 4 cells / 10 min.  When claimable census cells exist
# and admitting a heavy candidate (measured or flat reservation
# >= HEAVY_RUN_RAM_GB) would push free RAM below the protected census band,
# the heavy row is DEFERRED this claim round so the small cells keep flowing.
# Bounded and selection-only: it defers, it never changes a verdict, cap,
# budget, or the census floor, and it never defers a priority-tracked
# OWNER-DEC-PRE0803 lineage rerun (Amendment B) or a COMPILE_EA row.  Rollback:
# QM_CENSUS_FIRST_RAM_PRIORITY=0 restores the prior admit-in-claim-order path.
HEAVY_RUN_RAM_GB = 10.0
# Keep this many 4 GB census lanes' worth of headroom above the
# post-reservation floor before a heavy candidate may consume it:
# 8 + 4 * 2 = 16 GB.
CENSUS_LANES_PROTECTED = 2


def _ram_floor_for_class(ram_class: str) -> float:
    """Minimum free RAM that must remain AFTER a candidate's reservation."""
    if ram_class == RAM_CLASS_OPT_CENSUS_CELL:
        return OPT_CENSUS_POST_RESERVATION_FLOOR_GB
    return RAM_MIN_FREE_GB
# DWX index universe seen in farm dispatch; extend with evidence, not guesses.
INDEX_TICK_SYMBOL_BASES = frozenset({"GDAXI", "SP500", "WS30", "NDX", "UK100"})
# --- Tester-memory measurement + measured-RAM admission (2026-09-03, CEO) ---
# Per-run peak working-set of the metatester/terminal subtree is sampled into a
# JSONL ledger; aggregated max-per-class expectations then feed the per-item RAM
# admission gate, replacing the flat commit class ONLY for heavy single-symbol
# runs (measured peak > TESTER_MEMORY_HEAVY_GB).  Fail-open throughout; the
# ledger keeps recording even when the admission override is rolled back via
# QM_TESTER_MEMORY_ADMISSION=0.
TESTER_MEMORY_SAMPLE_SECONDS = 20.0
TESTER_MEMORY_HEAVY_GB = 10.0
TESTER_MEMORY_MIN_SAMPLES = 3
# Classification-only currency/symbol sets: they never touch _FX_CURRENCIES or
# the reservation classes, only the ledger's lookup-key bucketing.
_TESTER_MEMORY_FX_MAJOR_BASES = frozenset({
    "EURUSD", "USDJPY", "GBPUSD", "USDCHF", "USDCAD", "AUDUSD", "NZDUSD",
})
_TESTER_MEMORY_METAL_BASES = frozenset({"XAUUSD", "XAGUSD", "XPTUSD", "XPDUSD"})
_TESTER_MEMORY_ENERGY_BASES = frozenset({
    "XTIUSD", "XBRUSD", "XNGUSD", "USOIL", "UKOIL",
})
_TESTER_MEMORY_EXOTIC_CURRENCIES = frozenset({
    "TRY", "ZAR", "MXN", "SGD", "NOK", "SEK", "DKK", "PLN", "HUF", "CZK",
    "HKD", "CNH", "RUB", "THB",
})
_TESTER_MEMORY_TIMEFRAMES = frozenset({
    "M1", "M5", "M15", "M30", "H1", "H2", "H4", "D1", "W1", "MN1",
})
_TESTER_MEMORY_EXPECTATIONS_TTL_SECONDS = 60.0
_TESTER_MEMORY_REBUILD_MIN_INTERVAL_SECONDS = 300.0
_TESTER_MEMORY_EXPECTATIONS_CACHE: dict[str, Any] = {
    "path": None, "mtime": None, "data": {}, "at": -1e9,
}
_TESTER_MEMORY_REBUILD_STATE: dict[str, Any] = {"at": -1e9, "src_mtime": None}
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
SQLITE_WRITE_RETRIES = 8
SQLITE_WRITE_RETRY_SLEEP_SECONDS = 0.05
# FACTORY_MUTATION.lock must never span the ordinary multi-attempt SQLite
# backoff. The connection itself has a 750ms busy timeout; one attempt keeps
# the OFF/claim fence below one second under writer contention and lets the
# worker retry on its next normal poll.
CLAIM_LOCK_SQLITE_ATTEMPTS = 1
CLAIM_LOCK_BUSY_TIMEOUT_MS = 750
# Claim transactions deliberately keep the short XCU contention budget above.
# Once a row is claimed, however, losing the worker's pre-spawn record write to
# a pump burst wastes the claim cycle and forces a daemon respawn.  Give only
# those post-claim writes a longer, still-bounded retry envelope.
POST_CLAIM_SQLITE_WRITE_RETRIES = 20
POST_CLAIM_SQLITE_WRITE_RETRY_SLEEP_SECONDS = 0.5
# A pre-spawn claim that cannot even be RELEASED because the DB is locked used
# to make the daemon exit (return 1) and strand the row as status='active',
# claimed_by=<terminal>, no runner pid — pinning that terminal's symbol lane and
# blocking containment-release quiescence until an operator ran
# release_stale_claims_for_terminal by hand (row c261068d, T4, 2026-09-02
# 07:22:42Z: ~15 minutes lost). The very same lock storm can also defeat the
# next worker's startup release, so we give the release its OWN ~60s exponential
# envelope first, then fall back to a durable filesystem marker that the worker
# startup path and the pump-maintenance reconcile stage drain later.
ORPHAN_DEFER_RELEASE_RETRY_ATTEMPTS = 32
ORPHAN_DEFER_RELEASE_RETRY_BASE_SECONDS = 0.5
ORPHAN_DEFER_RELEASE_RETRY_MAX_SECONDS = 2.0
# Durable marker location for a claim that could neither run nor be released.
ORPHAN_CLAIMS_REL = Path("state") / "orphan_claims"
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
# A runner process that disappears without a summary must not leave its parent
# claim pinned merely because the portable terminal process is still resident.
# Allow the normal report-publish window, then stop that slot and append a
# retryable pending disposition rather than manufacturing a gate verdict.
RUNNER_DEATH_REQUEUE_GRACE_SECONDS = 300.0
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

# Copy-on-claim failure isolation (2026-09-02). A privatization failure that is
# claim-local (terminal outside the provisioned set, missing Custom root/archive,
# no claimed symbols, prepared-binding mismatch) or a copy race must fail THIS
# terminal's claim closed WITHOUT stopping the whole fleet; only a genuine
# isolation-integrity breach engages fleet-wide containment. Four claim-local
# copy-on-claim failures in ~12h on 01./02.09 each tripped fleet containment and
# serialized the 10-terminal fleet down to a single claim lease for ~12h. A
# quarantine marker parks only the offending terminal for a bounded window so the
# same claim-local defect neither spins nor idles the rest of the fleet; an
# operator clears it by deleting the marker, or it expires on its own.
CUSTOM_HISTORY_QUARANTINE_DIRNAME = "custom_history_quarantine"
CUSTOM_HISTORY_QUARANTINE_MINUTES = 15
# Append-only forensic trail for every copy-on-claim failure and its containment
# decision. The 2026-09-02 07:02Z trip left no log line anywhere; that must never
# happen again.
CUSTOM_HISTORY_COPY_FAILURE_LOG = Path(
    "D:/QM/reports/state/custom_history_copy_on_claim_failures.jsonl"
)
CUSTOM_HISTORY_ITEM_HOLD_CODE = "CUSTOM_HISTORY_SYMBOL_NOT_IN_MANIFEST"
CUSTOM_HISTORY_ITEM_HOLD_REASON = (
    "claimed custom-history symbols are absent from the OWNER-signed archive manifest"
)

_STOP = False
_CLAIM_DB_INIT_LOCK = threading.Lock()
_CLAIM_DB_INITIALIZED_ROOTS: set[str] = set()


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
    return retry_sqlite_busy(
        fn,
        attempts=SQLITE_WRITE_RETRIES,
        base_delay_seconds=SQLITE_WRITE_RETRY_SLEEP_SECONDS,
    )


def _with_claim_lock_sqlite_write(fn):
    return retry_sqlite_busy(
        fn,
        attempts=CLAIM_LOCK_SQLITE_ATTEMPTS,
        base_delay_seconds=0.0,
    )


def _with_post_claim_sqlite_retry(fn):
    return retry_sqlite_busy(
        fn,
        attempts=POST_CLAIM_SQLITE_WRITE_RETRIES,
        base_delay_seconds=POST_CLAIM_SQLITE_WRITE_RETRY_SLEEP_SECONDS,
    )


def _is_sqlite_locked(exc: sqlite3.OperationalError) -> bool:
    return is_sqlite_busy(exc)


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


def _history_preflight_fingerprint(
    item: sqlite3.Row | dict[str, Any],
) -> tuple[str, str, str, str, str, str]:
    """Identity fields consumed by the claim-time history preflight."""

    return (
        str(_work_item_value(item, "id", "") or ""),
        str(_work_item_value(item, "phase", "") or ""),
        str(_work_item_value(item, "ea_id", "") or ""),
        str(_work_item_value(item, "symbol", "") or ""),
        str(_work_item_value(item, "setfile_path", "") or ""),
        str(_work_item_value(item, "payload_json", "{}") or "{}"),
    )


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
    if farmctl.phase_qid(phase) == farmctl.SUPPORTED_BACKTEST_PHASES[0]:
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


def _tester_memory_ledger_path() -> Path:
    """JSONL ledger location (env override for tests)."""
    return Path(
        os.environ.get("QM_TESTER_MEMORY_LEDGER")
        or "D:/QM/reports/state/tester_memory_ledger.jsonl"
    )


def _tester_memory_expectations_path() -> Path:
    """Compiled per-class expectations location (env override for tests)."""
    return Path(
        os.environ.get("QM_TESTER_MEMORY_EXPECTATIONS")
        or "D:/QM/reports/state/tester_memory_expectations.json"
    )


def _normalize_timeframe(
    item: sqlite3.Row | dict[str, Any], payload: dict[str, Any]
) -> str:
    """Canonical MT5 timeframe token, or 'TF?' when unknown."""
    tf = _work_item_test_period(item, payload).strip().upper()
    if tf.startswith("PERIOD_"):
        tf = tf[len("PERIOD_"):]
    return tf if tf in _TESTER_MEMORY_TIMEFRAMES else "TF?"


def _tester_memory_symbol_class(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    multisymbol: bool,
) -> str:
    """Coarse memory-cohort label for the ledger lookup key (classify-only)."""
    if multisymbol:
        count = 0
        raw = payload.get("basket_symbols")
        if isinstance(raw, list):
            count = len([sym for sym in raw if str(sym or "").strip()])
        if count == 0:
            try:
                count = int(payload.get("basket_symbol_count") or 0)
            except (TypeError, ValueError):
                count = 0
        if count == 2:
            return "basket2"
        if 3 <= count < MULTISYMBOL_HEAVY_SYMBOL_COUNT:
            return "basket3_9"
        return "basket10+"
    base = _work_item_test_symbol(item, payload).split(".")[0].upper()
    if base in INDEX_TICK_SYMBOL_BASES:
        return "index"
    if base in _TESTER_MEMORY_METAL_BASES:
        return "metal"
    if base in _TESTER_MEMORY_ENERGY_BASES:
        return "energy"
    if _is_fx_symbol(base):
        return "fx_major" if base in _TESTER_MEMORY_FX_MAJOR_BASES else "fx_cross"
    if len(base) == 6:
        leg1, leg2 = base[:3], base[3:]
        known1 = leg1 in _FX_CURRENCIES or leg1 in _TESTER_MEMORY_EXOTIC_CURRENCIES
        known2 = leg2 in _FX_CURRENCIES or leg2 in _TESTER_MEMORY_EXOTIC_CURRENCIES
        exotic = (
            leg1 in _TESTER_MEMORY_EXOTIC_CURRENCIES
            or leg2 in _TESTER_MEMORY_EXOTIC_CURRENCIES
        )
        if known1 and known2 and exotic:
            return "fx_exotic"
    return "other"


def _tester_memory_run_kind(
    item: sqlite3.Row | dict[str, Any], payload: dict[str, Any]
) -> str:
    """Coarse run-kind label for the ledger lookup key."""
    phase = str(_work_item_value(item, "phase", "") or "").strip().upper()
    if phase == farmctl.OPT_CENSUS_PHASE:
        return "census"
    if phase == farmctl.COMPILE_EA_PHASE:
        return "compile"
    if farmctl.is_recovery_payload(payload):
        return "recovery"
    if phase == str(_Q09_NEWS_PHASE).strip().upper():
        return "news"
    if phase in {
        str(farmctl._PATTERN_PHASE).strip().upper(),
        str(farmctl._PARAM_OPT_PHASE).strip().upper(),
        str(farmctl._HEAD_TO_HEAD_PHASE).strip().upper(),
    }:
        return "wf"
    if _is_early_run_smoke_phase(phase):
        return "smoke"
    return "backtest"


def _tester_memory_lookup_key(
    symbol_class: str, timeframe: str, run_kind: str
) -> str:
    return f"{symbol_class}|{timeframe}|{run_kind}"


def _tester_memory_percentile(sorted_values: list[float], q: float) -> float:
    """Linear-interpolated percentile of a pre-sorted, non-empty list."""
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return float(sorted_values[0])
    pos = q * (len(sorted_values) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(sorted_values) - 1)
    frac = pos - lo
    return float(sorted_values[lo] * (1.0 - frac) + sorted_values[hi] * frac)


def _compile_tester_memory_expectations(
    rows: list[dict[str, Any]]
) -> dict[str, dict[str, float]]:
    """Aggregate ledger rows into per-lookup-key {n, max_gb, p95_gb} (pure)."""
    groups: dict[str, list[float]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        key = row.get("lookup_key")
        if not key:
            continue
        try:
            gb = float(row.get("peak_subtree_working_set_gb"))
        except (TypeError, ValueError):
            continue
        groups.setdefault(str(key), []).append(gb)
    out: dict[str, dict[str, float]] = {}
    for key, values in groups.items():
        ordered = sorted(values)
        out[key] = {
            "n": len(ordered),
            "max_gb": round(max(ordered), 3),
            "p95_gb": round(_tester_memory_percentile(ordered, 0.95), 3),
        }
    return out


def rebuild_tester_memory_expectations(*, force: bool = False) -> bool:
    """Opportunistically rebuild the compiled expectations file (fail-open).

    Bounded: rebuilds only when the ledger mtime changed AND at least
    _TESTER_MEMORY_REBUILD_MIN_INTERVAL_SECONDS elapsed since the last check.
    Never raises; returns True only when a fresh file was written.
    """
    try:
        ledger = _tester_memory_ledger_path()
        if not ledger.is_file():
            return False
        now = time.monotonic()
        if not force and (
            now - _TESTER_MEMORY_REBUILD_STATE["at"]
        ) < _TESTER_MEMORY_REBUILD_MIN_INTERVAL_SECONDS:
            return False
        _TESTER_MEMORY_REBUILD_STATE["at"] = now
        try:
            src_mtime = ledger.stat().st_mtime
        except OSError:
            return False
        if not force and _TESTER_MEMORY_REBUILD_STATE["src_mtime"] == src_mtime:
            return False
        rows: list[dict[str, Any]] = []
        with open(ledger, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except (ValueError, json.JSONDecodeError):
                    continue
        expectations = _compile_tester_memory_expectations(rows)
        out_path = _tester_memory_expectations_path()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        document = {
            "schema": "qm.tester_memory_expectations/v1",
            "generated_at_utc": farmctl.utc_now(),
            "source_ledger": str(ledger),
            "keys": expectations,
        }
        tmp_path = out_path.with_suffix(out_path.suffix + ".tmp")
        tmp_path.write_text(
            json.dumps(document, sort_keys=True, indent=2), encoding="utf-8"
        )
        os.replace(tmp_path, out_path)
        _TESTER_MEMORY_REBUILD_STATE["src_mtime"] = src_mtime
        return True
    except Exception:
        return False


def _tester_memory_admission_active() -> bool:
    """Fast gate: is the measured-RAM override in play at all right now?

    False (skip all classification/lookup) when the env rollback flag is set or
    the compiled expectations file does not yet exist, so a first deploy and the
    disabled state are both near-zero cost on the hot admission path.
    """
    if os.environ.get("QM_TESTER_MEMORY_ADMISSION") == "0":
        return False
    try:
        return _tester_memory_expectations_path().is_file()
    except Exception:
        return False


def _measured_ram_expectation_gb(
    symbol_class: str, timeframe: str, run_kind: str
) -> float | None:
    """Measured expected peak (GB) for a class, or None (no data / disabled).

    Returns the conservative per-key max_gb once at least
    TESTER_MEMORY_MIN_SAMPLES runs exist; None disables the override and keeps
    the flat commit class.  Fail-open None on any error.
    """
    if os.environ.get("QM_TESTER_MEMORY_ADMISSION") == "0":
        return None
    try:
        path = _tester_memory_expectations_path()
        if not path.is_file():
            return None
        mtime = path.stat().st_mtime
        now = time.monotonic()
        cache = _TESTER_MEMORY_EXPECTATIONS_CACHE
        if (
            cache["path"] != str(path)
            or cache["mtime"] != mtime
            or (now - cache["at"]) >= _TESTER_MEMORY_EXPECTATIONS_TTL_SECONDS
        ):
            with open(path, "r", encoding="utf-8") as handle:
                document = json.load(handle)
            keys = document.get("keys") if isinstance(document, dict) else None
            cache["data"] = keys if isinstance(keys, dict) else {}
            cache["path"] = str(path)
            cache["mtime"] = mtime
            cache["at"] = now
        entry = cache["data"].get(
            _tester_memory_lookup_key(symbol_class, timeframe, run_kind)
        )
        if not isinstance(entry, dict):
            return None
        try:
            samples = int(entry.get("n") or 0)
            max_gb = float(entry.get("max_gb"))
        except (TypeError, ValueError):
            return None
        if samples < TESTER_MEMORY_MIN_SAMPLES:
            return None
        return max_gb
    except Exception:
        return None


def _resolve_ram_reservation_gb(
    ram_class: str,
    flat_gb: float,
    measured_gb: float | None,
    *,
    multisymbol: bool,
) -> float:
    """Pure admission-reservation resolver (the unit-test target).

    Heavy single-symbol runs (measured peak > TESTER_MEMORY_HEAVY_GB) reserve
    their measured peak; everything else keeps today's flat class.  max() so a
    class is never lowered below its flat default.
    """
    if multisymbol:
        return flat_gb
    if ram_class == RAM_CLASS_OPT_CENSUS_CELL:
        return flat_gb
    if measured_gb is None:
        return flat_gb
    if measured_gb <= TESTER_MEMORY_HEAVY_GB:
        return flat_gb
    return max(flat_gb, float(measured_gb))


def _ram_reservation_for_candidate(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    multisymbol: bool,
) -> tuple[str, float]:
    """Return the conservative physical-RAM class and launch reservation."""

    phase_upper = str(_work_item_value(item, "phase", "") or "").upper()
    if not multisymbol and phase_upper == "OPT_CENSUS":
        return RAM_CLASS_OPT_CENSUS_CELL, OPT_CENSUS_RAM_RESERVATION_GB
    # OQ-SIBLING-SEED-RANK-20260902 follow-through (CEO 2026-09-02): a DL-089
    # measurement-sibling Q02 prerequisite seed runs the same program window
    # on the same symbol as the census cells it unlocks (single symbol, D1/H1
    # smoke window); its tester footprint is the census-cell class, not the
    # 8 GB ordinary reservation that kept the seeds RAM-skipped while census
    # cells were admitted. Identified by the exact seed-path payload schema.
    if (
        not multisymbol
        and phase_upper == "Q02"
        and str((payload or {}).get("schema") or "")
        == "qm.dl089-measurement-q02-prerequisite/v1"
    ):
        return RAM_CLASS_OPT_CENSUS_CELL, OPT_CENSUS_RAM_RESERVATION_GB
    ram_class = _multisymbol_commit_class(item, payload, multisymbol)
    flat_gb = float(_commit_reservation_gb(ram_class))
    measured_gb = None
    if not multisymbol and _tester_memory_admission_active():
        measured_gb = _measured_ram_expectation_gb(
            _tester_memory_symbol_class(item, payload, multisymbol),
            _normalize_timeframe(item, payload),
            _tester_memory_run_kind(item, payload),
        )
    return ram_class, _resolve_ram_reservation_gb(
        ram_class, flat_gb, measured_gb, multisymbol=multisymbol
    )


def _census_first_ram_priority_enabled() -> bool:
    """CENSUS-FIRST claim priority is on unless QM_CENSUS_FIRST_RAM_PRIORITY=0.

    Env kill switch (2026-09-03, CEO).  Default on; the exact string "0"
    restores the prior admit-in-claim-order behaviour with no other effect.
    """
    return os.environ.get("QM_CENSUS_FIRST_RAM_PRIORITY") != "0"


def _census_first_protected_band_gb() -> float:
    """Free RAM that must stay claimable for the protected census lanes.

    OPT_CENSUS_POST_RESERVATION_FLOOR_GB plus one census reservation per
    protected lane (8 + 4 * 2 = 16 GB by default).  Reads the live census
    constants so a floor/reservation rollback flows through unchanged; this
    band never lowers the census floor itself.
    """
    return (
        OPT_CENSUS_POST_RESERVATION_FLOOR_GB
        + OPT_CENSUS_RAM_RESERVATION_GB * CENSUS_LANES_PROTECTED
    )


def _is_priority_tracked_lineage_rerun(
    payload: "dict[str, Any] | None",
) -> bool:
    """True for an OWNER-DEC-PRE0803 Amendment B priority-tracked lineage rerun.

    Mirrors the two forms farmctl._lineage_rerun_rank_sql ranks ahead of the
    census: an exact append-only rerun (append_only_rerun true/1), or a
    governed fresh-Q02 requalification seed (fresh_q02_seed with a non-empty
    requalification_old_work_item_id) -- in either case additionally marked
    priority_track true.  Such a row is the critical path to a Q10 lock and is
    never deferred by CENSUS-FIRST.
    """
    if not isinstance(payload, dict):
        return False
    if payload.get("priority_track") is not True:
        return False
    append_only = payload.get("append_only_rerun")
    if append_only is True or append_only == 1:
        return True
    if payload.get("fresh_q02_seed") is True and str(
        payload.get("requalification_old_work_item_id") or ""
    ):
        return True
    return False


def _census_first_defers_heavy_candidate(
    *,
    reservation_gb: float,
    free_ram_gb: float,
    census_cells_claimable: bool,
    is_priority_tracked_lineage_rerun: bool,
    is_compile: bool,
    enabled: bool,
) -> bool:
    """Pure CENSUS-FIRST deferral predicate (the unit-test target).

    True iff a heavy candidate should be SKIPPED this claim round to keep RAM
    headroom for the protected DL-089 census lanes.  Selection-only: on True
    the caller merely ``continue``s to a lighter row, exactly like
    skipped_ram_class; it never changes a verdict, cap, budget, or the census
    floor.

    A candidate is heavy when its measured-or-flat launch reservation is
    >= HEAVY_RUN_RAM_GB.  It is deferred only while (a) the rule is enabled,
    (b) it is neither a COMPILE_EA row nor a priority-tracked Amendment B
    lineage rerun, (c) claimable census cells exist, and (d) admitting it would
    leave free RAM below the protected band.
    """
    if not enabled:
        return False
    if is_compile or is_priority_tracked_lineage_rerun:
        return False
    if not census_cells_claimable:
        return False
    if reservation_gb < HEAVY_RUN_RAM_GB:
        return False
    return free_ram_gb - reservation_gb < _census_first_protected_band_gb()


# --- Bounded drain window for headroom-starved priority rows (2026-09-03, CEO) ---
# Evidence: docs/ops/evidence/2026-09-03_index_tick_admission_audit.md.  A heavy
# single-symbol / multi-leg priority-tracked row reserves a flat class (e.g. the
# 44 GB single_index_tick or the 32 GB multi_leg_fx_basket) and can only be
# claimed once free physical RAM clears reservation + floor.  With ordinary short
# rows (OPT_CENSUS cells, Q02-Q06 single-symbol jobs) continuously re-consuming
# every gigabyte that frees, a heavy priority row can wait indefinitely: over the
# 24 h in the audit host free RAM exceeded 44 GB in 0/1438 samples while short
# rows kept flowing.  The drain window is a claim-SELECTION-only reorder: when a
# qualifying heavy priority row has been headroom-skipped past the trigger age,
# the fleet stops taking NEW short rows (running rows finish, COMPILE_EA keeps
# flowing) so free RAM can organically climb to the row's reservation + floor,
# at which point the normal RAM gate admits it.  It changes WHICH claimable row a
# worker takes next, never how much any row reserves: no reservation constant,
# the RAM latch, the census floor and the tester ledger are all untouched.
#
# A row is only allowed to arm a drain when a fully drained fleet could actually
# satisfy it.  Because the ONE armed row is admitted at the reduced
# DRAIN_ARMED_ROW_FLOOR_GB on a drained fleet (see that constant), the arming
# ceiling is measured against that reduced floor: reservation +
# DRAIN_ARMED_ROW_FLOOR_GB <= host total minus DRAIN_WINDOW_HOST_BASELINE_GB, the
# ~10 GB that T_Live + resident workers + OS hold and never release (measured
# 2026-09-03 16:55Z).  This lets the 44 GB single_index_tick class arm on a
# 63 GB host (44 + 4 = 48 <= 53) though its 44 + 14 = 58 GB normal-floor
# requirement never fit; a row still needing more than the reduced ceiling stays
# a reservation-tuning matter (ROT) and never idles the fleet on an unkept
# promise (audit docs/ops/evidence/2026-09-03_index_tick_admission_audit.md).
QM_DRAIN_WINDOW_ENV = "QM_DRAIN_WINDOW"          # "0" disables; any other/unset = on
QM_TEST_TOTAL_RAM_GB_ENV = "QM_TEST_TOTAL_RAM_GB"
DRAIN_WINDOW_TRIGGER_MIN = 20.0                  # heavy priority row must be headroom-skipped this long
DRAIN_WINDOW_MAX_MIN = 30.0                      # a drain auto-expires after this many minutes
DRAIN_COOLDOWN_MIN = 90.0                        # no new drain until this long after one ends
DRAIN_WINDOW_HOST_BASELINE_GB = 10.0             # undrainable floor: T_Live + workers + OS
DRAIN_WINDOW_MIN_RESERVATION_GB = 24.0           # only genuinely heavy classes (32/44 GB) may drain
# DRAINED-FLEET admission floor (2026-09-03; audit
# docs/ops/evidence/2026-09-03_index_tick_admission_audit.md): the 14 GB
# post-reservation floor (RAM_MIN_FREE_GB) exists to protect OTHER running
# testers from the growth of their working sets.  Once a drain window has parked
# the fleet and NO other backtest tester is running (only COMPILE_EA rows may be
# active), there is nothing left to protect, so the ONE armed row is admitted
# when free RAM clears its reservation + this reduced floor instead of the 14 GB
# floor -- a 44 GB single_index_tick row then needs 44 + 4 = 48 GB free, which a
# drained 63 GB host provides but the 44 + 14 = 58 GB gate never could.  Every
# other row (and the armed row while any other tester still runs) keeps the
# 14/20 GB latch and its class floor; the QM_DRAIN_WINDOW=0 kill switch, which
# clears drain_active upstream, disables this reduced floor as well.
DRAIN_ARMED_ROW_FLOOR_GB = 4.0
DRAIN_STATE_FILENAME = "drain_window.json"
# Short-row phases the drain refuses while open (the armed heavy row and any
# COMPILE_EA row are always exempt); OPT_CENSUS is handled by name separately.
_DRAIN_SHORT_ROW_PHASES = frozenset({"Q02", "Q03", "Q04", "Q05", "Q06"})


def _total_ram_gb() -> float:
    """Total physical RAM in GB; env override for tests, fail-closed (inf) live.

    Returns +inf when the host total is unknown so the drainable-ceiling check in
    _drain_row_is_qualifying fails closed (no drain opens on an unreadable probe).
    """
    override = os.environ.get(QM_TEST_TOTAL_RAM_GB_ENV)
    if override is not None:
        try:
            value = float(override)
            if math.isfinite(value) and value > 0.0:
                return value
        except (TypeError, ValueError):
            pass
    if sys.platform != "win32":
        return float("inf")
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
            return float("inf")
        return stat.ullTotalPhys / (1024 ** 3)
    except Exception:
        return float("inf")


def _drain_window_enabled() -> bool:
    """Kill switch: QM_DRAIN_WINDOW=0 restores the pre-drain claim behaviour."""
    return str(os.environ.get(QM_DRAIN_WINDOW_ENV, "1")).strip() != "0"


def _drain_state_path(root: Path) -> Path:
    return root / "state" / DRAIN_STATE_FILENAME


def _empty_drain_state() -> dict[str, Any]:
    return {"version": 1, "active": None, "cooldown_until_epoch": 0.0, "tracker": {}}


def _load_drain_state(root: Path) -> dict[str, Any]:
    """Load the fleet drain state; fail-open to an empty state on any error."""
    try:
        with open(_drain_state_path(root), "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return _empty_drain_state()
    except Exception:
        return _empty_drain_state()
    if not isinstance(data, dict):
        return _empty_drain_state()
    active = data.get("active")
    if not isinstance(active, dict):
        active = None
    tracker = data.get("tracker")
    if not isinstance(tracker, dict):
        tracker = {}
    try:
        cooldown = float(data.get("cooldown_until_epoch") or 0.0)
    except (TypeError, ValueError):
        cooldown = 0.0
    return {
        "version": 1,
        "active": active,
        "cooldown_until_epoch": cooldown,
        "tracker": tracker,
    }


def _write_drain_state_atomic(root: Path, state: dict[str, Any]) -> bool:
    """Atomically replace the drain state file; fail-open (never raises)."""
    path = _drain_state_path(root)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(state, handle, sort_keys=True)
        os.replace(tmp, path)
        return True
    except Exception:
        try:
            if tmp.exists():
                tmp.unlink()
        except Exception:
            pass
        return False


def _drain_iso(now_epoch: float) -> str:
    try:
        return datetime.fromtimestamp(
            float(now_epoch), tz=timezone.utc
        ).isoformat(timespec="seconds")
    except Exception:
        return ""


def _drain_row_is_qualifying(
    *,
    reservation_gb: float,
    floor_gb: float,
    free_ram_gb: float,
    host_total_gb: float,
) -> bool:
    """Pure predicate: may a heavy row arm a drain given the current RAM picture?

    Qualifies only when it is genuinely heavy, cannot be claimed now, yet a fully
    drained fleet could satisfy it.  Reservation + floor are the row's existing
    physical-RAM admission requirement (read, never modified).
    """
    try:
        reservation = float(reservation_gb)
        floor = float(floor_gb)
        free_now = float(free_ram_gb)
        total = float(host_total_gb)
    except (TypeError, ValueError):
        return False
    if not (math.isfinite(reservation) and math.isfinite(floor)):
        return False
    if reservation < DRAIN_WINDOW_MIN_RESERVATION_GB:
        return False
    need = reservation + floor
    if not math.isfinite(need) or not math.isfinite(free_now):
        return False
    if need <= free_now:
        return False  # already claimable under the normal gate; no drain needed
    if not math.isfinite(total):
        return False  # unknown host total -> fail closed, do not idle the fleet
    # The armed row is admitted on a fully drained fleet at the reduced
    # DRAIN_ARMED_ROW_FLOOR_GB, not the class floor that protects other running
    # testers (2026-09-03; audit
    # docs/ops/evidence/2026-09-03_index_tick_admission_audit.md).  Measure the
    # drainable ceiling against that reduced floor so the 44 GB index class can
    # arm (44 + 4 = 48 <= 63.1 - 10) though 44 + 14 = 58 never fit.
    drained_need = reservation + DRAIN_ARMED_ROW_FLOOR_GB
    if not math.isfinite(drained_need):
        return False
    if drained_need > total - DRAIN_WINDOW_HOST_BASELINE_GB:
        return False  # unwinnable even on a fully drained fleet (reservation-tuning matter)
    return True


def _drain_candidate_from_row(
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    free_ram_gb: float,
    host_total_gb: float,
    multisym_ids: frozenset,
) -> dict[str, Any] | None:
    """Return a drain-candidate descriptor for a qualifying priority row, else None.

    Reads the row's existing reservation/floor via the unchanged resolver; only a
    priority-tracked, drain-qualifying row yields a descriptor.
    """
    try:
        if payload.get("priority_track") is not True:
            return None
        multisymbol = _work_item_is_multisymbol(item, payload, multisym_ids)
        ram_class, reservation_gb = _ram_reservation_for_candidate(
            item, payload, multisymbol
        )
        floor_gb = _ram_floor_for_class(ram_class)
        if not _drain_row_is_qualifying(
            reservation_gb=reservation_gb,
            floor_gb=floor_gb,
            free_ram_gb=free_ram_gb,
            host_total_gb=host_total_gb,
        ):
            return None
        return {
            "item_id": str(_work_item_value(item, "id", "") or ""),
            "ea_id": str(_work_item_value(item, "ea_id", "") or ""),
            "phase": str(_work_item_value(item, "phase", "") or "").upper(),
            "ram_class": ram_class,
            "reservation_gb": round(float(reservation_gb), 1),
            "floor_gb": round(float(floor_gb), 1),
        }
    except Exception:
        return None


def _drain_blocks_candidate(
    item: sqlite3.Row | dict[str, Any], drain_item_id: str | None
) -> bool:
    """True when an active drain must refuse this NEW short row.

    The armed heavy row itself and every COMPILE_EA row are always exempt.
    """
    if drain_item_id is not None and str(
        _work_item_value(item, "id", "") or ""
    ) == str(drain_item_id):
        return False
    phase = str(_work_item_value(item, "phase", "") or "").upper()
    if phase == farmctl.COMPILE_EA_PHASE:
        return False
    if phase == "OPT_CENSUS":
        return True
    return phase in _DRAIN_SHORT_ROW_PHASES


def _drain_active_now(
    state: dict[str, Any], now_epoch: float
) -> tuple[bool, str | None]:
    """Blocking-side read: is a drain in force now, honouring the max window?"""
    active = state.get("active") if isinstance(state, dict) else None
    if not isinstance(active, dict):
        return False, None
    try:
        opened = float(active.get("opened_epoch") or 0.0)
    except (TypeError, ValueError):
        return False, None
    if now_epoch - opened >= DRAIN_WINDOW_MAX_MIN * 60.0:
        return False, None  # past the max window -> treat as inactive even if unwritten
    item_id = active.get("item_id")
    if not item_id:
        return False, None
    return True, str(item_id)


def _drain_evaluate(
    state: dict[str, Any],
    *,
    now_epoch: float,
    qualifying_candidate: dict[str, Any] | None,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Pure open/expire/track state transition.  Returns (new_state, events).

    Only ONE heavy row holds a drain at a time; a drain opens only after the
    candidate has been continuously tracked for DRAIN_WINDOW_TRIGGER_MIN and no
    cooldown is in force, and expires after DRAIN_WINDOW_MAX_MIN.
    """
    events: list[dict[str, Any]] = []
    active = state.get("active") if isinstance(state.get("active"), dict) else None
    try:
        cooldown_until = float(state.get("cooldown_until_epoch") or 0.0)
    except (TypeError, ValueError):
        cooldown_until = 0.0
    tracker = dict(state.get("tracker") or {})

    if active is not None:
        try:
            opened = float(active.get("opened_epoch") or now_epoch)
        except (TypeError, ValueError):
            opened = now_epoch
        if now_epoch - opened >= DRAIN_WINDOW_MAX_MIN * 60.0:
            events.append({
                "event": "drain_window_expired",
                "item_id": active.get("item_id"),
                "ea_id": active.get("ea_id"),
                "reason": "max_window",
                "open_seconds": round(now_epoch - opened, 1),
            })
            cooldown_until = now_epoch + DRAIN_COOLDOWN_MIN * 60.0
            active = None

    if active is None and qualifying_candidate is not None:
        cid = str(qualifying_candidate.get("item_id"))
        rec = tracker.get(cid)
        if not isinstance(rec, dict):
            rec = {
                "first_skipped_epoch": now_epoch,
                "reservation_gb": qualifying_candidate.get("reservation_gb"),
                "floor_gb": qualifying_candidate.get("floor_gb"),
                "ea_id": qualifying_candidate.get("ea_id"),
            }
        tracker = {cid: rec}  # only one heavy row is tracked at a time
        try:
            first_skipped = float(rec.get("first_skipped_epoch") or now_epoch)
        except (TypeError, ValueError):
            first_skipped = now_epoch
        waited = now_epoch - first_skipped
        if (
            now_epoch >= cooldown_until
            and waited >= DRAIN_WINDOW_TRIGGER_MIN * 60.0
        ):
            active = {
                "item_id": cid,
                "ea_id": qualifying_candidate.get("ea_id"),
                "reservation_gb": qualifying_candidate.get("reservation_gb"),
                "floor_gb": qualifying_candidate.get("floor_gb"),
                "opened_epoch": now_epoch,
                "opened_iso": _drain_iso(now_epoch),
            }
            events.append({
                "event": "drain_window_open",
                "item_id": cid,
                "ea_id": qualifying_candidate.get("ea_id"),
                "reservation_gb": qualifying_candidate.get("reservation_gb"),
                "floor_gb": qualifying_candidate.get("floor_gb"),
                "waited_seconds": round(waited, 1),
            })
            tracker = {}  # consumed by the open
    elif active is None and qualifying_candidate is None:
        tracker = {}  # nothing waiting -> drop any stale tracker entry

    new_state = {
        "version": 1,
        "active": active,
        "cooldown_until_epoch": cooldown_until,
        "tracker": tracker,
    }
    return new_state, events


def _drain_note_claim(
    state: dict[str, Any], *, now_epoch: float, claimed_item_id: str
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Close the drain when its armed heavy row is claimed.  Returns (state, events)."""
    active = state.get("active") if isinstance(state.get("active"), dict) else None
    if active is None or str(active.get("item_id")) != str(claimed_item_id):
        return state, []
    try:
        opened = float(active.get("opened_epoch") or now_epoch)
    except (TypeError, ValueError):
        opened = now_epoch
    events = [{
        "event": "drain_window_claim",
        "item_id": active.get("item_id"),
        "ea_id": active.get("ea_id"),
        "open_seconds": round(now_epoch - opened, 1),
    }]
    new_state = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": now_epoch + DRAIN_COOLDOWN_MIN * 60.0,
        "tracker": {},
    }
    return new_state, events


def _drain_scan_candidate(
    root: Path,
    *,
    free_ram_gb: float,
    host_total_gb: float,
    multisym_ids: frozenset,
) -> dict[str, Any] | None:
    """Read-only scan for the top qualifying priority heavy row; None if none.

    Priority-tracked rows sort first in the canonical claim order, so the scan
    stops at the first non-priority row.  Runs OUTSIDE the claim transaction on a
    short read connection, mirroring the existing candidate preflight.
    """
    try:
        with farmctl.connect(root) as conn:
            conn.row_factory = sqlite3.Row
            for item in conn.execute(_priority_pending_query()).fetchall():
                payload = _json_loads(item["payload_json"])
                if payload.get("priority_track") is not True:
                    break
                candidate = _drain_candidate_from_row(
                    item, payload, free_ram_gb, host_total_gb, multisym_ids
                )
                if candidate is not None:
                    return candidate
    except Exception:
        return None
    return None


def _drain_run_postprocess(
    root: Path,
    terminal: str,
    claim_result: dict[str, Any],
    *,
    now_epoch: float,
    free_ram_gb: float,
    host_total_gb: float,
    multisym_ids: frozenset,
) -> None:
    """Advance the fleet drain state after a claim attempt and emit its events.

    Advisory fleet coordination: any failure here is swallowed so it can never
    break the claim path.
    """
    try:
        state = _load_drain_state(root)
        active = state.get("active") if isinstance(state.get("active"), dict) else None
        active_item_id = str(active.get("item_id")) if active else None
        claimed_item_id: str | None = None
        if claim_result.get("claimed"):
            item = claim_result.get("item")
            if isinstance(item, dict):
                claimed_item_id = str(item.get("id"))
        if (
            claimed_item_id is not None
            and active_item_id is not None
            and claimed_item_id == active_item_id
        ):
            new_state, events = _drain_note_claim(
                state, now_epoch=now_epoch, claimed_item_id=claimed_item_id
            )
        else:
            qualifying = _drain_scan_candidate(
                root,
                free_ram_gb=free_ram_gb,
                host_total_gb=host_total_gb,
                multisym_ids=multisym_ids,
            )
            new_state, events = _drain_evaluate(
                state, now_epoch=now_epoch, qualifying_candidate=qualifying
            )
        if events or new_state != state:
            _write_drain_state_atomic(root, new_state)
        for event in events:
            print(
                json.dumps(
                    {**event, "terminal": terminal, "at_utc": _drain_iso(now_epoch)},
                    sort_keys=True,
                ),
                flush=True,
            )
    except Exception:
        pass


_PROCESS_SNAPSHOT_TTL_SECONDS = 3.0
_process_snapshot_cache: dict[str, Any] = {
    "at": -1e9, "children": {}, "private": {}, "alive": set(),
    "working_set": {}, "peak_working_set": {}, "image": {},
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
    working_set: dict[int, int] = {}
    peak_working_set: dict[int, int] = {}
    image: dict[int, str] = {}
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
                pids.append((int(entry.th32ProcessID), int(entry.th32ParentProcessID), str(entry.szExeFile or "")))
                more = kernel32.Process32NextW(snapshot, ctypes.byref(entry))
        finally:
            kernel32.CloseHandle(snapshot)

        for pid, ppid, exe in pids:
            children.setdefault(ppid, []).append(pid)
            alive.add(pid)
            image[pid] = exe.lower()
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
                    working_set[pid] = int(counters.WorkingSetSize)
                    peak_working_set[pid] = int(counters.PeakWorkingSetSize)
            finally:
                kernel32.CloseHandle(handle)
    except Exception:
        return {}, {}, set()

    _process_snapshot_cache["at"] = now
    _process_snapshot_cache["children"] = children
    _process_snapshot_cache["private"] = private
    _process_snapshot_cache["alive"] = alive
    _process_snapshot_cache["working_set"] = working_set
    _process_snapshot_cache["peak_working_set"] = peak_working_set
    _process_snapshot_cache["image"] = image
    return children, private, alive


def _measured_subtree_gb(
    pid: Any,
    process_snapshot: tuple[dict[int, list[int]], dict[int, int], set[int]] | None = None,
) -> float | None:
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
    children, private, alive = process_snapshot or _process_private_snapshot()
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


def _sample_tester_memory(root_pid: Any, acc: dict[str, int]) -> None:
    """Accumulate running-max working-set of the pid subtree into ``acc``.

    Fail-open: any error leaves ``acc`` untouched and returns.  Reads the
    working-set / peak / image maps the refreshed process snapshot stored in
    ``_process_snapshot_cache`` (its 3-tuple return signature is unchanged).
    """
    try:
        children, private, alive = _process_private_snapshot()
        working_set = _process_snapshot_cache.get("working_set") or {}
        peak_working_set = _process_snapshot_cache.get("peak_working_set") or {}
        image = _process_snapshot_cache.get("image") or {}
        try:
            start = int(root_pid)
        except (TypeError, ValueError):
            return
        seen: set[int] = set()
        queue = [start]
        subtree_ws = 0
        subtree_private = 0
        metatester_ws = 0
        metatester_os_peak = 0
        terminal_ws = 0
        any_live = False
        while queue:
            current = queue.pop()
            if current in seen:
                continue
            seen.add(current)
            if current in alive:
                any_live = True
            ws = int(working_set.get(current, 0) or 0)
            subtree_ws += ws
            subtree_private += int(private.get(current, 0) or 0)
            img = str(image.get(current, "") or "")
            if img == "metatester64.exe":
                metatester_ws += ws
                osp = int(peak_working_set.get(current, 0) or 0)
                if osp > metatester_os_peak:
                    metatester_os_peak = osp
            elif img == "terminal64.exe":
                terminal_ws += ws
            queue.extend(children.get(current, ()))
        if not any_live:
            return
        if subtree_ws > acc["peak_subtree_ws"]:
            acc["peak_subtree_ws"] = subtree_ws
        if subtree_private > acc["peak_subtree_private"]:
            acc["peak_subtree_private"] = subtree_private
        if metatester_ws > acc["peak_metatester_ws"]:
            acc["peak_metatester_ws"] = metatester_ws
        if metatester_os_peak > acc["metatester_os_peak_ws"]:
            acc["metatester_os_peak_ws"] = metatester_os_peak
        if terminal_ws > acc["peak_terminal_ws"]:
            acc["peak_terminal_ws"] = terminal_ws
        acc["samples"] = int(acc.get("samples", 0)) + 1
    except Exception:
        return


def _write_tester_memory_ledger(
    root: Path,
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    spawn: dict[str, Any],
    acc: dict[str, int],
    terminal: str,
    *,
    run_seconds: float,
    outcome: str,
) -> None:
    """Append one qm.tester_memory_ledger/v1 line for a monitored run (fail-open)."""
    try:
        try:
            multisym_ids = _multisymbol_ea_ids()
        except Exception:
            multisym_ids = frozenset()
        try:
            multisymbol = _work_item_is_multisymbol(item, payload, multisym_ids)
        except Exception:
            multisymbol = False
        symbol_class = _tester_memory_symbol_class(item, payload, multisymbol)
        timeframe = _normalize_timeframe(item, payload)
        run_kind = _tester_memory_run_kind(item, payload)
        try:
            ram_class, _ = _ram_reservation_for_candidate(item, payload, multisymbol)
        except Exception:
            ram_class = MULTISYMBOL_COMMIT_CLASS_ORDINARY
        if ram_class == RAM_CLASS_OPT_CENSUS_CELL:
            flat_gb = OPT_CENSUS_RAM_RESERVATION_GB
        else:
            flat_gb = float(_commit_reservation_gb(ram_class))
        gib = float(1024 ** 3)
        record = {
            "schema": "qm.tester_memory_ledger/v1",
            "ts_utc": farmctl.utc_now(),
            "ea_id": str(_work_item_value(item, "ea_id", "") or ""),
            "symbol": _work_item_test_symbol(item, payload),
            "symbol_class": symbol_class,
            "timeframe": timeframe,
            "phase": str(_work_item_value(item, "phase", "") or ""),
            "run_kind": run_kind,
            "ram_class": ram_class,
            "reservation_gb": round(float(flat_gb), 3),
            "lookup_key": _tester_memory_lookup_key(symbol_class, timeframe, run_kind),
            "run_seconds": round(float(run_seconds), 3),
            "samples": int(acc.get("samples", 0)),
            "peak_subtree_working_set_gb": round(int(acc.get("peak_subtree_ws", 0)) / gib, 3),
            "peak_metatester_working_set_gb": round(int(acc.get("peak_metatester_ws", 0)) / gib, 3),
            "metatester_os_peak_working_set_gb": round(int(acc.get("metatester_os_peak_ws", 0)) / gib, 3),
            "peak_terminal_working_set_gb": round(int(acc.get("peak_terminal_ws", 0)) / gib, 3),
            "peak_subtree_private_gb": round(int(acc.get("peak_subtree_private", 0)) / gib, 3),
            "outcome": str(outcome),
            "worker_pid": os.getpid(),
            "terminal": str(terminal or ""),
        }
        path = _tester_memory_ledger_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True) + "\n")
    except Exception:
        return


def _commit_admission_snapshot(
    conn: sqlite3.Connection,
    now_iso: str,
    multisym_ids: frozenset,
    *,
    live_headroom_gb: float | None = None,
    process_snapshot: tuple[dict[int, list[int]], dict[int, int], set[int]] | None = None,
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
    live_headroom = (
        _commit_headroom_gb()
        if live_headroom_gb is None
        else float(live_headroom_gb)
    )
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
        measured_gb = (
            _measured_subtree_gb(pid, process_snapshot=process_snapshot)
            if pid
            else None
        )
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
        terminals.update({f"T{index}" for index in range(1, 13)} - allowed)
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
                if gate.get("item_hold_code") == CUSTOM_HISTORY_ITEM_HOLD_CODE:
                    _hold_custom_history_item(
                        conn,
                        row,
                        payload,
                        now,
                        str(gate.get("item_hold_detail") or gate.get("error") or ""),
                    )
                    conn.execute(
                        "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
                        (json.dumps(payload, sort_keys=True), now, row["id"]),
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
# ERROR_OUTOFMEMORY (14), ERROR_HANDLE_DISK_FULL (39), ERROR_DISK_FULL (112),
# ERROR_NO_SYSTEM_RESOURCES (1450), ERROR_COMMITMENT_LIMIT (1455).
# Disk exhaustion joined 2026-08-15 20:47Z: a D:-full window tripped fleet
# containment although no integrity fact was in question. Deliberately
# narrow — device/corruption OSErrors must keep engaging containment.
_RESOURCE_EXHAUSTION_WINERRORS = frozenset({8, 14, 39, 112, 1450, 1455})


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
            or current.errno in (errno.ENOMEM, errno.ENOSPC)
        ):
            return True
        current = current.__cause__ or current.__context__
    return False


def _custom_history_gate(root: Path, terminal: str) -> dict[str, Any]:
    """Run the activation-bound gate; every error is a dispatch refusal."""

    try:
        gate = custom_history_gate.run_worker_gate(root, terminal=terminal)
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


def _custom_history_quarantine_path(root: Path, terminal: str) -> Path:
    return (
        Path(root)
        / "state"
        / CUSTOM_HISTORY_QUARANTINE_DIRNAME
        / f"{str(terminal).upper()}.json"
    )


def _custom_history_quarantine_active(
    root: Path, terminal: str
) -> dict[str, Any] | None:
    """Return the live quarantine marker for a terminal, or None.

    Fail-open: an unreadable or absent marker never wedges a terminal. An expired
    marker (past its bounded window) is cleared and treated as absent, so the
    terminal resumes on its own after N minutes even without an operator.
    """

    path = _custom_history_quarantine_path(root, terminal)
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        # A corrupt/half-written marker must not permanently pause a terminal.
        return None
    if not isinstance(record, dict):
        return None
    expires_at = str(record.get("expires_at_utc") or "")
    try:
        expired = datetime.now(timezone.utc) >= datetime.fromisoformat(expires_at)
    except ValueError:
        expired = True
    if expired:
        try:
            path.unlink()
        except OSError:
            pass
        return None
    return record


def _write_custom_history_quarantine(
    root: Path,
    terminal: str,
    *,
    reason_code: str,
    item_id: str,
    error: str,
) -> Path | None:
    """Park one terminal for a bounded window after a claim-local copy failure."""

    now = datetime.now(timezone.utc)
    record = {
        "schema_version": "qm.custom-history-copy-on-claim-quarantine/v1",
        "terminal": str(terminal).upper(),
        "reason_code": reason_code,
        "item_id": item_id or None,
        "error": error,
        "recorded_at_utc": now.isoformat(timespec="seconds"),
        "expires_at_utc": (
            now + timedelta(minutes=CUSTOM_HISTORY_QUARANTINE_MINUTES)
        ).isoformat(timespec="seconds"),
        "quarantine_minutes": CUSTOM_HISTORY_QUARANTINE_MINUTES,
        "cleared_by": "operator_delete_or_window_expiry",
    }
    path = _custom_history_quarantine_path(root, terminal)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.parent / f".{path.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp"
        tmp.write_text(json.dumps(record, sort_keys=True), encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        return None
    return path


def _record_copy_on_claim_failure(
    root: Path,
    terminal: str,
    item_id: str,
    reason_code: str,
    exc: BaseException,
    *,
    fleet_containment_engaged: bool,
    quarantined: bool,
) -> None:
    """Append one forensic JSONL line for a copy-on-claim failure (best effort)."""

    event = {
        "event": "custom_history_copy_on_claim_failure",
        "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "terminal": str(terminal).upper(),
        "item_id": item_id or None,
        "reason_code": reason_code,
        "exception_type": type(exc).__name__,
        "error": repr(exc),
        "fleet_containment_engaged": bool(fleet_containment_engaged),
        "terminal_quarantined": bool(quarantined),
    }
    try:
        CUSTOM_HISTORY_COPY_FAILURE_LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(CUSTOM_HISTORY_COPY_FAILURE_LOG, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, sort_keys=True) + "\n")
    except OSError:
        pass


def _copy_on_claim_reason_code(exc: BaseException) -> str | None:
    """Walk the cause chain for a classified copy-on-claim error's reason code.

    Returns the reason_code of the nearest CustomHistoryCopyOnClaimError, or None
    when the failure is some other exception type. None fails safe: the caller
    engages fleet containment for an unclassified non-transient failure.
    """

    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(
            current, custom_history_copy_on_claim.CustomHistoryCopyOnClaimError
        ):
            return str(
                getattr(
                    current,
                    "reason_code",
                    custom_history_copy_on_claim.INTEGRITY,
                )
            )
        current = current.__cause__ or current.__context__
    return None


def _custom_history_item_bound_error(exc: BaseException) -> str | None:
    """Return a stable item-bound cause while walking wrapped exceptions."""

    prefixes = (
        "claim declares no .DWX host/conversion/basket history symbols",
        "manifest has no archive rows for claimed symbols:",
    )
    seen: set[int] = set()
    current: BaseException | None = exc
    while current is not None and id(current) not in seen:
        seen.add(id(current))
        if isinstance(
            current, custom_history_copy_on_claim.CustomHistoryCopyOnClaimError
        ):
            message = str(current)
            if any(message.startswith(prefix) for prefix in prefixes):
                return message
        current = current.__cause__ or current.__context__
    return None


def _hold_custom_history_item(
    conn: sqlite3.Connection,
    item: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    now: str,
    detail: str,
) -> None:
    """Append/update the non-restart poison hold and its audit event."""

    diagnostic = {
        "hold_code": CUSTOM_HISTORY_ITEM_HOLD_CODE,
        "reason": CUSTOM_HISTORY_ITEM_HOLD_REASON,
        "detail": detail,
        "release_condition": (
            "OWNER-signed archive manifest covers every declared .DWX symbol, "
            "then explicit governed hold release"
        ),
        "release_on_restart": False,
    }
    payload["custom_history_item_hold"] = diagnostic
    conn.execute(
        """
        INSERT INTO work_item_holds(
          work_item_id,hold_code,reason,active,release_on_restart,
          created_at,updated_at,released_at,release_note
        ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
        ON CONFLICT(work_item_id) DO UPDATE SET
          hold_code=excluded.hold_code,
          reason=excluded.reason,
          active=1,
          release_on_restart=0,
          updated_at=excluded.updated_at,
          released_at=NULL,
          release_note=NULL
        """,
        (
            str(_work_item_value(item, "id", "")),
            CUSTOM_HISTORY_ITEM_HOLD_CODE,
            CUSTOM_HISTORY_ITEM_HOLD_REASON,
            now,
            now,
        ),
    )
    conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
        "VALUES(?,'work_item',?,'custom_history_item_held',?)",
        (
            now,
            str(_work_item_value(item, "id", "")),
            json.dumps(diagnostic, sort_keys=True),
        ),
    )


def _privatize_custom_history_claim(
    root: Path,
    row: sqlite3.Row | dict[str, Any],
    terminal: str,
    gate: dict[str, Any],
    prestage_adoption: Mapping[str, Any] | None = None,
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
            prepared_sources=next_cell_prestage.cached_history_sources(
                prestage_adoption
            ),
            prestage_token_sha256=(
                str(prestage_adoption.get("token_sha256"))
                if prestage_adoption
                else None
            ),
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
            "already_private_file_count": receipt["already_private_file_count"],
            "prepared_cache_file_count": receipt.get("prepared_cache_file_count", 0),
            "prestage_token_sha256": receipt.get("prestage_token_sha256"),
            "receipt_sha256": receipt["receipt_sha256"],
            "receipt_path": receipt["receipt_path"],
            "receipt_file_sha256": receipt["receipt_file_sha256"],
        }
    except Exception as exc:
        item_id = str(_work_item_value(row, "id", "") or "")
        # Sharing violations / mid-swap misses while other terminals' MT5
        # processes hold archives open are OS-level concurrency artifacts of THIS
        # attempt, not integrity breaches — defer without fleet containment and
        # without quarantine (same classification as the gate's transient-IO
        # path); the terminal simply retries on its next poll.
        if _is_transient_gate_io_error(exc):
            _record_copy_on_claim_failure(
                root,
                terminal,
                item_id,
                "TRANSIENT_IO",
                exc,
                fleet_containment_engaged=False,
                quarantined=False,
            )
            return {
                "required": True,
                "status": "FAIL_CLOSED",
                "terminal": str(terminal).upper(),
                "reason": "custom_history_copy_on_claim_failure",
                "reason_code": "TRANSIENT_IO",
                "error": repr(exc),
                "activation_sha256": activation_sha256,
            }
        # A classified copy-on-claim error decides the blast radius: only a
        # genuine isolation-integrity breach — or an unclassified non-transient
        # failure, which fails safe — engages fleet-wide containment. Claim-local
        # and copy-race failures fail THIS claim closed and quarantine only this
        # terminal for a bounded window, leaving the rest of the fleet running.
        reason_code = _copy_on_claim_reason_code(exc)
        item_bound_error = _custom_history_item_bound_error(exc)
        if item_bound_error is not None:
            _record_copy_on_claim_failure(
                root,
                terminal,
                item_id,
                reason_code or custom_history_copy_on_claim.CLAIM_LOCAL,
                exc,
                fleet_containment_engaged=False,
                quarantined=False,
            )
            return {
                "required": True,
                "status": "FAIL_CLOSED",
                "terminal": str(terminal).upper(),
                "reason": "custom_history_item_not_in_manifest",
                "reason_code": reason_code or custom_history_copy_on_claim.CLAIM_LOCAL,
                "fleet_containment_engaged": False,
                "terminal_quarantined": False,
                "item_hold_code": CUSTOM_HISTORY_ITEM_HOLD_CODE,
                "item_hold_detail": item_bound_error,
                "error": repr(exc),
                "activation_sha256": activation_sha256,
            }
        engage_fleet = reason_code in (
            None,
            custom_history_copy_on_claim.INTEGRITY,
        )
        if engage_fleet:
            try:
                custom_history_lease.engage_emergency_mode(
                    root,
                    reason=f"custom_history_copy_on_claim_failure:{type(exc).__name__}",
                    activation_sha256=activation_sha256,
                )
            except Exception:
                pass
            _record_copy_on_claim_failure(
                root,
                terminal,
                item_id,
                reason_code or "UNCLASSIFIED",
                exc,
                fleet_containment_engaged=True,
                quarantined=False,
            )
            return {
                "required": True,
                "status": "FAIL_CLOSED",
                "terminal": str(terminal).upper(),
                "reason": "custom_history_copy_on_claim_failure",
                "reason_code": reason_code or "UNCLASSIFIED",
                "fleet_containment_engaged": True,
                "error": repr(exc),
                "activation_sha256": activation_sha256,
            }
        marker = _write_custom_history_quarantine(
            root,
            terminal,
            reason_code=reason_code,
            item_id=item_id,
            error=repr(exc),
        )
        _record_copy_on_claim_failure(
            root,
            terminal,
            item_id,
            reason_code,
            exc,
            fleet_containment_engaged=False,
            quarantined=marker is not None,
        )
        return {
            "required": True,
            "status": "FAIL_CLOSED",
            "terminal": str(terminal).upper(),
            "reason": "custom_history_copy_on_claim_failure",
            "reason_code": reason_code,
            "fleet_containment_engaged": False,
            "terminal_quarantined": marker is not None,
            "quarantine_path": str(marker) if marker else None,
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
            avoid = {f"T{index}" for index in range(1, 13)} - allowed
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


def _ram_latch_compile_bypass_available(root: Path, free_ram_gb: float) -> bool:
    """Allow only a claimable COMPILE_EA row through the RAM latch.

    Fail closed on any DB ambiguity; the floor keeps a small margin for the
    compiler process itself.  Mirrors ``_ram_latch_opt_census_bypass_available``.
    """
    if free_ram_gb < COMPILE_RAM_MIN_FREE_GB:
        return False
    db_path = root / farmctl.DB_REL
    if not db_path.is_file():
        return False
    try:
        uri = f"file:{db_path.as_posix()}?mode=ro"
        with sqlite3.connect(uri, uri=True, timeout=1) as conn:
            row = conn.execute(
                """
                SELECT 1 FROM work_items w
                WHERE w.status='pending' AND upper(w.phase)=?
                  AND NOT EXISTS (
                    SELECT 1 FROM work_item_holds h
                    WHERE h.work_item_id=w.id AND h.active=1
                  )
                  AND NOT EXISTS (
                    SELECT 1 FROM work_item_supersedes s
                    WHERE s.work_item_id=w.id
                  )
                LIMIT 1
                """,
                (farmctl.COMPILE_EA_PHASE,),
            ).fetchone()
        return row is not None
    except sqlite3.Error:
        return False


def _ram_latch_opt_census_bypass_available(root: Path, free_ram_gb: float) -> bool:
    """Allow only a class-admissible OPT_CENSUS row through RAM hysteresis.

    The 14/20GB latch remains the default and emergency defence. During the
    18-20GB recovery band, however, a measured 4GB annual cell can leave the
    full 14GB safety floor intact; holding it until 20GB would waste the small
    lane while large jobs drain. Any DB/registry ambiguity fails closed.
    """

    if free_ram_gb - OPT_CENSUS_RAM_RESERVATION_GB < OPT_CENSUS_POST_RESERVATION_FLOOR_GB:
        return False
    db_path = root / farmctl.DB_REL
    if not db_path.is_file():
        return False
    try:
        multisym_ids = _multisymbol_ea_ids()
        uri = f"file:{db_path.as_posix()}?mode=ro"
        with sqlite3.connect(uri, uri=True, timeout=1) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """
                SELECT * FROM work_items w
                WHERE w.status='pending' AND upper(w.phase)='OPT_CENSUS'
                  AND NOT EXISTS (
                    SELECT 1 FROM work_item_holds h
                    WHERE h.work_item_id=w.id AND h.active=1
                  )
                  AND NOT EXISTS (
                    SELECT 1 FROM work_item_supersedes s
                    WHERE s.work_item_id=w.id
                  )
                LIMIT 32
                """
            ).fetchall()
        for row in rows:
            payload = _json_loads(row["payload_json"])
            multisymbol = _work_item_is_multisymbol(
                row, payload, multisym_ids
            )
            _, reservation_gb = _ram_reservation_for_candidate(
                row, payload, multisymbol
            )
            if free_ram_gb - reservation_gb >= _ram_floor_for_class(
                RAM_CLASS_OPT_CENSUS_CELL if not multisymbol else ""
            ):
                return True
        return False
    except (OSError, sqlite3.Error, MultisymbolRegistryUnavailable):
        return False


def _opt_census_cells_claimable_in_txn(conn: sqlite3.Connection) -> bool:
    """Cheap in-transaction EXISTS: is any OPT_CENSUS cell claimable now?

    Runs on the already-open claim connection -- no second connection while
    BEGIN IMMEDIATE is held (see the poison-pill note in claim_atomic) -- and
    mirrors the pending/not-held/not-superseded row filter of
    _ram_latch_opt_census_bypass_available without its headroom coupling: this
    answers only "does protected census work exist", which the CENSUS-FIRST
    rule then weighs against the heavy candidate's reservation.  Fails toward
    False (do not defer the heavy) on any DB ambiguity -- the rule only defers.
    """
    try:
        row = conn.execute(
            """
            SELECT 1 FROM work_items w
            WHERE w.status='pending' AND upper(w.phase)='OPT_CENSUS'
              AND NOT EXISTS (
                SELECT 1 FROM work_item_holds h
                WHERE h.work_item_id=w.id AND h.active=1
              )
              AND NOT EXISTS (
                SELECT 1 FROM work_item_supersedes s
                WHERE s.work_item_id=w.id
              )
            LIMIT 1
            """
        ).fetchone()
        return row is not None
    except sqlite3.Error:
        return False


def _no_other_backtest_tester_active(conn: sqlite3.Connection) -> bool:
    """True when NO non-COMPILE backtest tester is active fleet-wide.

    Read on the already-open claim connection inside BEGIN IMMEDIATE so the
    answer is consistent with the row about to be claimed.  COMPILE_EA rows
    commit well under 1 GB and keep flowing during a drain, so an active compile
    never counts as a running tester here.  Fails toward False (treat the fleet
    as NOT drained -> keep the full floor) on any DB ambiguity, so the reduced
    DRAINED-FLEET floor is applied only when the armed drain is provably the last
    backtest work on the host (2026-09-03; audit
    docs/ops/evidence/2026-09-03_index_tick_admission_audit.md).
    """
    try:
        for row in conn.execute(
            "SELECT phase, kind FROM work_items WHERE status='active'"
        ):
            phase = str(row["phase"] or "").upper()
            kind = str(row["kind"] or "").lower()
            if (
                phase == farmctl.COMPILE_EA_PHASE
                or kind == farmctl.COMPILE_WORK_ITEM_KIND
            ):
                continue
            return False
        return True
    except sqlite3.Error:
        return False


def _ensure_claim_db_initialized(root: Path) -> None:
    """Run idempotent schema setup once per worker process and farm root."""

    key = str(Path(root).resolve()).casefold()
    if key in _CLAIM_DB_INITIALIZED_ROOTS:
        return
    with _CLAIM_DB_INIT_LOCK:
        if key in _CLAIM_DB_INITIALIZED_ROOTS:
            return
        farmctl.init_db(root)
        _CLAIM_DB_INITIALIZED_ROOTS.add(key)


def _governed_analytic_claim_block(
    item: sqlite3.Row | dict[str, Any], payload: dict[str, Any]
) -> dict[str, Any] | None:
    """Reject control-plane declarations from the one-setfile terminal lane."""

    dl089 = payload.get("routing_revision") == "dl089-annual-wf-cells-v1"
    governed = (
        str(_work_item_value(item, "kind", "") or "").lower() == "analytic"
        and payload.get("execution_lane") == "GOVERNED_ANALYTIC_DISPATCH"
    )
    if not (dl089 or governed):
        return None
    return {
        "claimed": False,
        "reason": "governed_analytic_dispatch_required",
        "item_id": _work_item_value(item, "id"),
        "routing_revision": payload.get("routing_revision"),
        "execution_lane": payload.get("execution_lane"),
        "required_runner": "dl089_matrix_service" if dl089 else "governed_analytic_service",
    }


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
            "ram_class_skipped": [],
            "census_lane_protection_skipped": [],
            "multisymbol_commit_skipped": [],
            "terminal_avoid_skipped": [],
            "longrun_cap_skipped": [],
            "recovery_capped": [],
        }

    # A completed runner can publish a valid summary and then lose the final
    # SQLite write to sustained fleet contention.  _finish_work_item reports
    # sqlite_locked_finish_deferred in that case, but the resident worker used
    # to enter its next claim cycle, see its own still-live worker PID, and
    # decline forever as terminal_worker_busy.  Reconcile only a claim-fresh
    # summary for this terminal before taking another claim.  The summary
    # freshness/evidence binding is the same fail-closed check used by the
    # ordinary finish path, so stale output cannot release an active row.
    completed_claim_recovery = _recover_completed_claim_for_terminal(root, terminal)
    if completed_claim_recovery and not completed_claim_recovery.get("finished"):
        return {
            "claimed": False,
            "reason": "completed_claim_finish_deferred",
            "completed_claim_recovery": completed_claim_recovery,
        }

    # Never run the PowerShell/CIM terminal census while BEGIN IMMEDIATE is
    # open.  On 2026-08-29 that subprocess stalled inside the claim transaction;
    # the same worker's pre-spawn write and every peer writer then exhausted
    # their busy retries.  The census was already a fallible cached snapshot,
    # so taking it immediately before the serialized claim preserves its
    # fail-open contract without holding a SQLite writer lock across a process
    # launch.
    running_mt5_terminals = (
        set(farmctl._running_mt5_terminals())
        if root.resolve() == farmctl.DEFAULT_ROOT.resolve()
        else set()
    )
    # Every filesystem/process/OS probe completes before the fleet-wide
    # mutation lock.  The lock below is reserved for the fresh OFF check and
    # the SQLite claim transaction; a cold registry read, CIM fallback, or
    # report hash must never convoy peer terminals.
    _ensure_claim_db_initialized(root)
    process_snapshot = _process_private_snapshot()
    commit_headroom_snapshot = _commit_headroom_gb()
    multisym_free_ram_snapshot = _free_ram_gb()
    # Bounded drain window (2026-09-03): read the fleet drain state now so the
    # candidate loop can refuse NEW short rows while a heavy priority row drains
    # the fleet. State is advanced (open/expire/claim) AFTER the claim below,
    # outside the BEGIN IMMEDIATE transaction. Kill switch QM_DRAIN_WINDOW=0.
    drain_enabled = _drain_window_enabled()
    drain_now_epoch = time.time()
    drain_host_total_gb = _total_ram_gb() if drain_enabled else float("inf")
    drain_active = False
    drain_item_id: str | None = None
    if drain_enabled:
        drain_active, drain_item_id = _drain_active_now(
            _load_drain_state(root), drain_now_epoch
        )
    reservation = farmctl.terminal_reservation(root, terminal)
    watchdog_reset_blocked = _watchdog_reset_admission_blocked(root)
    longrun_policy_enabled = longrun_scheduling_policy.policy_enabled()
    history_registry = farmctl._dwx_symbol_history_registry()
    claim_history_manifest: dict[str, Any] | None = None
    try:
        claim_activation = custom_history_gate.load_activation(root)
        if claim_activation is not None:
            claim_history_manifest = custom_history_contract.load_manifest(
                Path(str(claim_activation["manifest_path"])),
                require_owner_approval=True,
            )
    except Exception:
        # The ordinary post-claim gate owns activation/manifest integrity
        # failures. This selector guard only acts when a valid signed manifest
        # is cheaply available and the defect conclusively follows the item.
        claim_history_manifest = None
    try:
        multisym_ids = _multisymbol_ea_ids()
    except MultisymbolRegistryUnavailable as exc:
        return {
            "claimed": False,
            "reason": "multisymbol_registry_unavailable",
            "error": str(exc),
        }
    active_terminal_preflight = _active_terminal_claim_preflight(root, terminal)
    if not active_terminal_preflight.get("ready"):
        return {
            "claimed": False,
            "reason": active_terminal_preflight.get(
                "reason", "active_terminal_preflight_failed"
            ),
            "error": active_terminal_preflight.get("error"),
        }

    pruning_enabled = opt_census_pruning.pruning_enabled()
    pruning_checked_payloads: dict[str, str] = {}
    opt_census_lane_tokens: dict[str, dict[str, Any]] = {}
    pruning_deferred_candidates: set[tuple[str, str]] = set()
    pruning_attempted_lanes: set[tuple[str, str]] = set()
    opt_census_worker_count = len(farmctl.worker_policy_terminals())
    history_preflight_cache: dict[
        str,
        tuple[
            tuple[str, str, str, str, str, str],
            bool,
            dict[str, Any] | None,
        ],
    ] = {}
    skip_unchecked_history = False

    # Prime the most likely candidate before the first global-lock acquisition.
    # This keeps the common one-row claim path to a single OFF-check/write
    # transaction while still revalidating the exact identity in `_claim`.
    try:
        with farmctl.connect(root) as _preflight_conn:
            # Build the full memoized claim order here so the main-loop
            # fetchall reuses it (same db, same process) instead of
            # re-sorting ~12.7k pending rows a second time in the same
            # claim_atomic.  execute_pending_claim_order returns the exact
            # rows _priority_pending_query() would, and the head row is the
            # fetchone this prime needs.
            _primed_order = farmctl.execute_pending_claim_order(_preflight_conn)
            initial_candidate_row = _primed_order[0] if _primed_order else None
    except sqlite3.Error:
        initial_candidate_row = None
    if initial_candidate_row is not None and not (
        pruning_enabled
        and str(initial_candidate_row["phase"] or "").upper() == "OPT_CENSUS"
    ):
        initial_candidate = dict(initial_candidate_row)
        initial_fingerprint = _history_preflight_fingerprint(initial_candidate)
        try:
            initial_history_ok, initial_history = _p2_history_claimable(
                initial_candidate,
                terminal,
                history_registry,
            )
        except Exception as exc:
            initial_history_ok = False
            initial_history = {
                "reason": "history_preflight_failed",
                "error": f"{type(exc).__name__}: {exc}",
            }
        history_preflight_cache[str(initial_candidate["id"])] = (
            initial_fingerprint,
            initial_history_ok,
            initial_history,
        )

    def _claim() -> dict[str, Any]:
        now = farmctl.utc_now()
        db_path = root / farmctl.DB_REL
        # Do not inherit the singleton pump's optional long env override here:
        # this connection runs while FACTORY_MUTATION.lock is held.
        with sqlite3.connect(
            db_path,
            timeout=CLAIM_LOCK_BUSY_TIMEOUT_MS / 1000.0,
        ) as conn:
            conn.row_factory = sqlite3.Row
            configure_sqlite_connection(
                conn,
                busy_timeout_ms=CLAIM_LOCK_BUSY_TIMEOUT_MS,
            )
            # Candidate ordering and every selector/preflight DB read run with
            # SQLite's connection-level write interlock enabled. Only the exact
            # row transition below temporarily disables query_only and takes
            # BEGIN IMMEDIATE, so a long candidate walk cannot convoy writers.
            conn.execute("PRAGMA query_only=ON")

            def _begin_optimistic_write(
                item_id: str,
                expected_status: str,
                expected_payload_json: str,
            ) -> tuple[sqlite3.Row | None, float | None]:
                conn.execute("PRAGMA query_only=OFF")
                lock_started = time.perf_counter()
                conn.execute("BEGIN IMMEDIATE")
                current = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (item_id,)
                ).fetchone()
                if (
                    current is None
                    or str(current["status"] or "") != expected_status
                    or str(current["payload_json"] or "{}")
                    != str(expected_payload_json or "{}")
                ):
                    conn.rollback()
                    conn.execute("PRAGMA query_only=ON")
                    return None, None
                return current, lock_started

            def _commit_optimistic_write(lock_started: float) -> float:
                conn.commit()
                elapsed_ms = (time.perf_counter() - lock_started) * 1000.0
                conn.execute("PRAGMA query_only=ON")
                return round(elapsed_ms, 3)
            try:
                active_terminal = conn.execute(
                    "SELECT * FROM work_items WHERE status='active' AND claimed_by=? LIMIT 1",
                    (terminal,),
                ).fetchone()
                if active_terminal:
                    if (
                        str(active_terminal["id"])
                        != str(active_terminal_preflight.get("item_id") or "")
                        or str(active_terminal["payload_json"] or "{}")
                        != str(active_terminal_preflight.get("payload_json") or "{}")
                    ):
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "active_terminal_preflight_stale",
                            "item_id": active_terminal["id"],
                        }
                    payload = _json_loads(active_terminal["payload_json"])
                    pid = payload.get("pid")
                    worker_pid = payload.get("claimed_by_worker_pid")
                    worker_alive = active_terminal_preflight.get("worker_alive")
                    child_alive = bool(active_terminal_preflight.get("child_alive"))
                    if worker_pid and worker_alive is False:
                        current, housekeeping_lock_started = _begin_optimistic_write(
                            str(active_terminal["id"]),
                            "active",
                            str(active_terminal["payload_json"] or "{}"),
                        )
                        if current is None:
                            return {
                                "claimed": False,
                                "reason": "active_terminal_optimistic_race",
                                "item_id": active_terminal["id"],
                            }
                        active_terminal = current
                        payload = _json_loads(active_terminal["payload_json"])
                        if pid and child_alive:
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
                            claim_write_lock_ms = _commit_optimistic_write(
                                housekeeping_lock_started
                            )
                            row = conn.execute("SELECT * FROM work_items WHERE id=?", (active_terminal["id"],)).fetchone()
                            return {
                                "claimed": True,
                                "item": dict(row),
                                "adopt_existing": True,
                                "claim_write_lock_ms": claim_write_lock_ms,
                            }

                        child_identity = dict(
                            active_terminal_preflight.get("child_identity") or {}
                        )
                        if _news_runner_abort_eligible(dict(active_terminal), payload):
                            parked = _park_news_runner_abort(
                                conn,
                                dict(active_terminal),
                                payload,
                                terminal,
                                now,
                                child_identity,
                            )
                            claim_write_lock_ms = _commit_optimistic_write(
                                housekeeping_lock_started
                            )
                            return {
                                "claimed": False,
                                "reason": "news_runner_spawn_abort_held",
                                "item_id": active_terminal["id"],
                                "claim_write_lock_ms": claim_write_lock_ms,
                                **parked,
                            }

                        payload["prior_failure"] = payload.get("prior_failure") or "worker_process_missing_released_stale_claim"
                        terminal_stopped = active_terminal_preflight.get("terminal_stopped")
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
                        _commit_optimistic_write(housekeeping_lock_started)
                    elif worker_pid and worker_alive is True:
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "terminal_worker_busy",
                            "item_id": active_terminal["id"],
                            "worker_pid": worker_pid,
                        }
                    elif pid and child_alive:
                        conn.commit()
                        return {"claimed": False, "reason": "terminal_busy", "item_id": active_terminal["id"]}
                    else:
                        current, housekeeping_lock_started = _begin_optimistic_write(
                            str(active_terminal["id"]),
                            "active",
                            str(active_terminal["payload_json"] or "{}"),
                        )
                        if current is None:
                            return {
                                "claimed": False,
                                "reason": "active_terminal_optimistic_race",
                                "item_id": active_terminal["id"],
                            }
                        active_terminal = current
                        payload = _json_loads(active_terminal["payload_json"])
                        payload["prior_failure"] = payload.get("prior_failure") or "worker_loop_released_stale_claim"
                        terminal_stopped = active_terminal_preflight.get("terminal_stopped")
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
                        _commit_optimistic_write(housekeeping_lock_started)

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

                if terminal in running_mt5_terminals:
                    conn.commit()
                    return {"claimed": False, "reason": "terminal_process_busy", "terminal": terminal}

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

                if watchdog_reset_blocked:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "watchdog_reset_pending",
                        "terminal": terminal,
                    }

                # Fleet-wide claim stagger, atomic under this BEGIN IMMEDIATE:
                # the ledger read and the eventual claim commit cannot interleave
                # with another worker's, so exactly one worker wins each window.
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

                admission = _commit_admission_snapshot(
                    conn,
                    now,
                    multisym_ids,
                    live_headroom_gb=commit_headroom_snapshot,
                    process_snapshot=process_snapshot,
                )
                if not admission["probe_ok"]:
                    conn.commit()
                    return {
                        "claimed": False,
                        "reason": "commit_probe_failed",
                        "commit_reserved_gb": round(admission["reserved_gb"], 1),
                        "commit_reservation_count": len(admission["reservations"]),
                    }
                effective_commit_headroom = admission["effective_headroom_gb"]
                compile_only_due_to_commit_headroom = False
                if effective_commit_headroom < COMMIT_MIN_FREE_GB:
                    compile_available = conn.execute(
                        """
                        SELECT 1 FROM work_items w
                        WHERE w.status='pending' AND w.phase=?
                          AND NOT EXISTS (
                            SELECT 1 FROM work_item_holds h
                            WHERE h.work_item_id=w.id AND h.active=1
                          )
                          AND NOT EXISTS (
                            SELECT 1 FROM work_item_supersedes s
                            WHERE s.work_item_id=w.id
                          )
                        LIMIT 1
                        """,
                        (farmctl.COMPILE_EA_PHASE,),
                    ).fetchone()
                    if (
                        compile_available
                        and admission["live_headroom_gb"]
                        >= COMMIT_MIN_FREE_GB
                    ):
                        compile_only_due_to_commit_headroom = True
                    else:
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
                active_opt_census_rows = [
                    dict(row)
                    for row in conn.execute(
                        "SELECT id,phase,ea_id,symbol,payload_json FROM work_items "
                        "WHERE status='active' AND upper(phase)='OPT_CENSUS'"
                    )
                ]
                active_opt_census = dl089_scheduling.active_census_snapshot(
                    active_opt_census_rows
                )
                opt_k_eff, opt_l_eff, opt_g_eff = dl089_scheduling.effective_limits(
                    opt_census_worker_count
                )
                opt_allowlist = dl089_scheduling.same_program_parallel_allowlist()
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
                skipped_ram_class: list[dict[str, Any]] = []
                skipped_census_lane_protection: list[dict[str, Any]] = []
                skipped_avoid_terminal: list[dict[str, Any]] = []
                skipped_longrun_cap: list[dict[str, Any]] = []
                skipped_opt_census_slots: list[dict[str, Any]] = []
                skipped_drain_window: list[dict[str, Any]] = []
                longrun_active_counts: dict[str, int] | None = None
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
                # CENSUS-FIRST (2026-09-03, CEO): the env flag is read once, and
                # the census-cell EXISTS runs at most once per claim round and
                # only when a heavy non-exempt candidate is actually reached.
                census_first_enabled = _census_first_ram_priority_enabled()
                census_cells_claimable: bool | None = None
                # claim-order memo (2026-09-03): byte-identical rows, reused while
                # PRAGMA data_version proves the DB unchanged (see farmctl).
                for item in farmctl.execute_pending_claim_order(conn):
                    preclaim_payload_sha256 = next_cell_prestage.sha256_text(
                        item["payload_json"] or "{}"
                    )
                    payload = _json_loads(item["payload_json"])
                    if (
                        claim_history_manifest is not None
                        and str(item["phase"] or "").upper() != farmctl.COMPILE_EA_PHASE
                        and str(item["kind"] or "").lower()
                        != farmctl.COMPILE_WORK_ITEM_KIND
                    ):
                        try:
                            custom_history_copy_on_claim.select_archive_rows_for_symbols(
                                claim_history_manifest,
                                _work_item_history_symbols(item, payload),
                            )
                        except Exception as exc:
                            item_bound_detail = _custom_history_item_bound_error(exc)
                            if item_bound_detail is not None:
                                current, hold_lock_started = _begin_optimistic_write(
                                    str(item["id"]),
                                    "pending",
                                    str(item["payload_json"] or "{}"),
                                )
                                if current is None:
                                    continue
                                item = current
                                payload = _json_loads(item["payload_json"])
                                _hold_custom_history_item(
                                    conn, item, payload, now, item_bound_detail
                                )
                                conn.execute(
                                    "UPDATE work_items SET payload_json=?,updated_at=? "
                                    "WHERE id=? AND status='pending' AND claimed_by IS NULL",
                                    (
                                        json.dumps(payload, sort_keys=True),
                                        now,
                                        item["id"],
                                    ),
                                )
                                _commit_optimistic_write(hold_lock_started)
                                continue
                    if (
                        (compile_only_due_to_commit_headroom or _RAM_LATCH_COMPILE_ONLY)
                        and str(item["phase"]).upper() != farmctl.COMPILE_EA_PHASE
                    ):
                        continue
                    item_is_recovery = farmctl.is_recovery_payload(payload)
                    if item_is_recovery:
                        if not recovery_gate_checked:
                            recovery_allowed = farmctl.recovery_claim_allowed(conn)
                            recovery_gate_checked = True
                        if not recovery_allowed:
                            recovery_capped = True
                            break
                    # Bounded drain window: while a heavy priority row drains the
                    # fleet, refuse NEW short rows (OPT_CENSUS + Q02-Q06) so free
                    # RAM can climb to the heavy row's reservation. The armed row
                    # and COMPILE_EA are always exempt (2026-09-03; audit
                    # docs/ops/evidence/2026-09-03_index_tick_admission_audit.md).
                    if drain_active and _drain_blocks_candidate(item, drain_item_id):
                        skipped_drain_window.append({
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            "phase": str(item["phase"] or "").upper(),
                            "drain_item_id": drain_item_id,
                        })
                        continue
                    avoid_terminals = _payload_avoid_terminals(payload)
                    if str(terminal).upper() in avoid_terminals:
                        skipped_avoid_terminal.append({
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            "avoid_terminals": sorted(avoid_terminals),
                        })
                        continue
                    # One transaction-bound snapshot enforces the combined
                    # Q10_NEWS cap, its expansion subcap, and the Q07/Q08 cap.
                    if longrun_active_counts is None:
                        longrun_active_counts = longrun_scheduling_policy.active_longrun_counts(
                            conn,
                            news_phase=_Q09_NEWS_PHASE,
                            q07_phase=_Q07_PHASE,
                            q08_phase=_Q08_PHASE,
                        )
                    longrun_skip, longrun_detail = longrun_scheduling_policy.should_skip_for_longrun_cap(
                        item["phase"],
                        payload,
                        longrun_active_counts,
                        news_phase=_Q09_NEWS_PHASE,
                        q07_phase=_Q07_PHASE,
                        q08_phase=_Q08_PHASE,
                        enabled=longrun_policy_enabled,
                    )
                    if longrun_skip:
                        skipped_longrun_cap.append({
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            **(longrun_detail or {}),
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
                    item_is_opt_census = str(item["phase"] or "").upper() == "OPT_CENSUS"
                    opt_program, opt_arm = dl089_scheduling.lane_id(
                        payload,
                        ea_id=item["ea_id"],
                        symbol=item["symbol"],
                    )
                    opt_lane = (opt_program, opt_arm)
                    governed_opt_census = _is_governed_dl089_census_payload(payload)
                    candidate_lane_limit = (
                        opt_l_eff if opt_program in opt_allowlist else min(1, opt_l_eff)
                    )
                    if item_is_opt_census:
                        if active_opt_census["total"] >= opt_g_eff:
                            skipped_opt_census_slots.append({
                                "item_id": item["id"],
                                "program_id": opt_program,
                                "reason": "CELL_SLOT_WAIT",
                                "cell_slots_effective": opt_g_eff,
                            })
                            continue
                        if (
                            opt_program not in active_opt_census["programs"]
                            and len(active_opt_census["programs"]) >= opt_k_eff
                        ):
                            skipped_opt_census_slots.append({
                                "item_id": item["id"],
                                "program_id": opt_program,
                                "reason": "PROGRAM_SLOT_WAIT",
                                "program_slots_effective": opt_k_eff,
                            })
                            continue
                        if active_opt_census["program_lane_counts"].get(opt_program, 0) >= candidate_lane_limit:
                            skipped_opt_census_slots.append({
                                "item_id": item["id"],
                                "program_id": opt_program,
                                "reason": "PROGRAM_LANE_WAIT",
                                "lanes_per_program_effective": candidate_lane_limit,
                            })
                            continue
                        if opt_lane in active_opt_census["lanes"]:
                            skipped_opt_census_slots.append({
                                "item_id": item["id"],
                                "program_id": opt_program,
                                "arm": opt_arm,
                                "reason": "PROGRAM_LANE_WAIT",
                            })
                            continue

                    # Compute this before the duplicate-pair exception: basket
                    # rows are never eligible for same-program concurrency.
                    item_is_multisym = _work_item_is_multisymbol(item, payload, multisym_ids)
                    symbol_key = str(item["symbol"] or "").upper()
                    if symbol_key:
                        if active_symbol_counts.get(symbol_key, 0) >= farmctl.CLAIM_SYMBOL_ACTIVE_CAP:
                            continue
                        if (str(item["ea_id"]), symbol_key) in active_ea_symbol_pairs:
                            duplicates = active_opt_census["pairs"].get(
                                (str(item["ea_id"]), symbol_key), []
                            )
                            if not (
                                governed_opt_census
                                and dl089_scheduling.duplicate_pair_exception_allowed(
                                    candidate=dict(item),
                                    candidate_payload=payload,
                                    active_duplicates=duplicates,
                                    l_eff=candidate_lane_limit,
                                    candidate_is_multisymbol=item_is_multisym,
                                    allowlist=opt_allowlist,
                                )
                            ):
                                continue
                    if str(item["phase"]).upper() == _Q04_PHASE and str(item["ea_id"]) in active_q04_eas:
                        continue
                    # Skip a multi-symbol item while another multi-symbol backtest
                    # is already running anywhere in the farm (serialize the heavy
                    # basket loads). Non-multi-symbol items are unaffected.
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
                        if multisym_free_ram_snapshot < MULTISYMBOL_RAM_MIN_FREE_GB:
                            skipped_multisym_ram.append({
                                "item_id": item["id"],
                                "ea_id": item["ea_id"],
                                "free_ram_gb": round(multisym_free_ram_snapshot, 1),
                                "threshold_gb": MULTISYMBOL_RAM_MIN_FREE_GB,
                            })
                            continue
                    ram_class, ram_reservation_gb = _ram_reservation_for_candidate(
                        item, payload, item_is_multisym
                    )
                    # CENSUS-FIRST claim priority (2026-09-03, CEO;
                    # OWNER-DEC-PRE0803 census is the counter's critical path):
                    # defer a heavy candidate this round when admitting it would
                    # starve the protected census lanes, then fall through to a
                    # lighter row -- exactly like skipped_ram_class below.  The
                    # gate short-circuits on the reservation so light census
                    # cells cost one float compare; the pure predicate owns the
                    # decision and re-checks the exemptions independently.
                    if (
                        census_first_enabled
                        and ram_reservation_gb >= HEAVY_RUN_RAM_GB
                    ):
                        item_is_compile = (
                            str(item["phase"] or "").upper()
                            == farmctl.COMPILE_EA_PHASE
                            or str(item["kind"] or "").lower()
                            == farmctl.COMPILE_WORK_ITEM_KIND
                        )
                        is_lineage_rerun = _is_priority_tracked_lineage_rerun(
                            payload
                        )
                        if not item_is_compile and not is_lineage_rerun:
                            if census_cells_claimable is None:
                                census_cells_claimable = (
                                    _opt_census_cells_claimable_in_txn(conn)
                                )
                            if _census_first_defers_heavy_candidate(
                                reservation_gb=ram_reservation_gb,
                                free_ram_gb=multisym_free_ram_snapshot,
                                census_cells_claimable=census_cells_claimable,
                                is_priority_tracked_lineage_rerun=is_lineage_rerun,
                                is_compile=item_is_compile,
                                enabled=census_first_enabled,
                            ):
                                skipped_census_lane_protection.append({
                                    "item_id": item["id"],
                                    "ea_id": item["ea_id"],
                                    "ram_class": ram_class,
                                    "reservation_gb": ram_reservation_gb,
                                    "free_ram_gb": round(
                                        multisym_free_ram_snapshot, 1
                                    ),
                                    "post_reservation_free_gb": round(
                                        multisym_free_ram_snapshot
                                        - ram_reservation_gb,
                                        1,
                                    ),
                                    "protected_band_gb": (
                                        _census_first_protected_band_gb()
                                    ),
                                    "reason": "census_lane_protection",
                                })
                                continue
                    post_reservation_free_gb = (
                        multisym_free_ram_snapshot - ram_reservation_gb
                    )
                    ram_floor_gb = _ram_floor_for_class(ram_class)
                    # DRAINED-FLEET admission floor (2026-09-03; audit
                    # docs/ops/evidence/2026-09-03_index_tick_admission_audit.md):
                    # the class floor protects OTHER running testers.  When THIS
                    # row is the one an open drain window is armed for and no
                    # other backtest tester is running fleet-wide (only COMPILE_EA
                    # rows may still be active), nothing is left to protect, so
                    # the armed row -- and only it -- clears at the reduced
                    # DRAIN_ARMED_ROW_FLOOR_GB (a 44 GB index row then needs
                    # 44 + 4 = 48 GB free, which a drained 63 GB host provides).
                    # The fleet-drained probe runs only for the armed row (the
                    # short-circuit keeps it off every other candidate), and the
                    # QM_DRAIN_WINDOW=0 kill switch clears drain_active upstream.
                    if (
                        drain_active
                        and drain_item_id is not None
                        and str(item["id"]) == str(drain_item_id)
                        and _no_other_backtest_tester_active(conn)
                    ):
                        ram_floor_gb = DRAIN_ARMED_ROW_FLOOR_GB
                    if post_reservation_free_gb < ram_floor_gb and not (
                        _RAM_LATCH_COMPILE_ONLY
                        and str(item["phase"]).upper() == farmctl.COMPILE_EA_PHASE
                    ):
                        skipped_ram_class.append({
                            "item_id": item["id"],
                            "ea_id": item["ea_id"],
                            "ram_class": ram_class,
                            "reservation_gb": ram_reservation_gb,
                            "free_ram_gb": round(multisym_free_ram_snapshot, 1),
                            "post_reservation_free_gb": round(
                                post_reservation_free_gb, 1
                            ),
                            "threshold_gb": ram_floor_gb,
                        })
                        continue
                    # Capacity, duplicate, and resource checks above are entirely
                    # local to this transaction. Run the cold-file lane preflight
                    # only after they admit the candidate; otherwise the default
                    # L=1 rollback state can exhaust the bounded preflight budget
                    # on rows that it must serialize and prevent later work from
                    # flowing. This block must remain outside the multisymbol-only
                    # resource branch: governed census cells are normally single-
                    # symbol and may never bypass their authenticated arm frontier.
                    if governed_opt_census:
                        token = opt_census_lane_tokens.get(str(item["id"]))
                        if not _opt_census_token_matches(
                            conn, item, payload, token
                        ):
                            candidate_key = (
                                str(item["id"]),
                                str(item["payload_json"] or "{}"),
                            )
                            if (
                                candidate_key in pruning_deferred_candidates
                                or opt_lane in pruning_attempted_lanes
                            ):
                                continue
                            conn.commit()
                            return {
                                "claimed": False,
                                "reason": "opt_census_lane_preflight_required",
                                "candidate": dict(item),
                                "program_id": opt_program,
                                "arm": opt_arm,
                            }
                    if (
                        pruning_enabled
                        and item_is_opt_census
                        and pruning_checked_payloads.get(str(item["id"]))
                        != str(item["payload_json"] or "{}")
                    ):
                        candidate_key = (
                            str(item["id"]),
                            str(item["payload_json"] or "{}"),
                        )
                        if (
                            candidate_key in pruning_deferred_candidates
                            or opt_lane in pruning_attempted_lanes
                        ):
                            continue
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "opt_census_pruning_required",
                            "candidate": dict(item),
                            "program_id": opt_program,
                        }
                    history_fingerprint = _history_preflight_fingerprint(item)
                    history_preflight = history_preflight_cache.get(str(item["id"]))
                    if (
                        history_preflight is None
                        or history_preflight[0] != history_fingerprint
                    ):
                        if skip_unchecked_history:
                            skipped_history.append({
                                "item_id": item["id"],
                                "reason": "history_preflight_deferred",
                            })
                            continue
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "history_preflight_required",
                            "candidate": dict(item),
                        }
                    _, history_ok, history = history_preflight
                    if not history_ok:
                        skipped_history.append({"item_id": item["id"], **(history or {})})
                        continue
                    _merge_history_window_payload(payload, history)
                    payload.update({
                        "claimed_at_iso": now,
                        "claimed_by_worker_pid": os.getpid(),
                        "terminal": terminal,
                    })
                    if compile_only_due_to_commit_headroom:
                        payload.update({
                            "claim_admission_mode": "compile_only_under_reservation_pressure",
                            "claim_admission_commit_headroom_gb": round(
                                admission["live_headroom_gb"], 1
                            ),
                            "claim_admission_commit_reserved_gb": round(
                                admission["reserved_gb"], 1
                            ),
                            "claim_admission_effective_commit_headroom_gb": round(
                                effective_commit_headroom, 1
                            ),
                        })
                    _set_commit_reservation(
                        payload,
                        claimed_at_iso=now,
                        multisymbol=item_is_multisym,
                        commit_class=_multisymbol_commit_class(item, payload, item_is_multisym),
                    )
                    current, claim_lock_started = _begin_optimistic_write(
                        str(item["id"]),
                        "pending",
                        str(item["payload_json"] or "{}"),
                    )
                    if current is None:
                        continue
                    blocked = conn.execute(
                        """
                        SELECT 1
                        WHERE EXISTS (
                            SELECT 1 FROM work_item_holds
                            WHERE work_item_id=? AND active=1
                        ) OR EXISTS (
                            SELECT 1 FROM work_item_supersedes
                            WHERE work_item_id=?
                        )
                        """,
                        (item["id"], item["id"]),
                    ).fetchone()
                    if blocked is not None:
                        conn.rollback()
                        conn.execute("PRAGMA query_only=ON")
                        continue
                    cur = conn.execute(
                        """
                        UPDATE work_items
                        SET status='active', claimed_by=?, payload_json=?, updated_at=?
                        WHERE id=? AND status='pending' AND claimed_by IS NULL
                          AND NOT EXISTS (
                            SELECT 1 FROM work_item_holds h
                            WHERE h.work_item_id=work_items.id AND h.active=1
                          )
                          AND NOT EXISTS (
                            SELECT 1 FROM work_item_supersedes s
                            WHERE s.work_item_id=work_items.id
                          )
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
                        claim_write_lock_ms = _commit_optimistic_write(
                            claim_lock_started
                        )
                        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
                        return {
                            "claimed": True,
                            "item": dict(row),
                            "claim_class": "recovery" if item_is_recovery else "priority",
                            "claim_admission_mode": payload.get("claim_admission_mode"),
                            "preclaim_payload_sha256": preclaim_payload_sha256,
                            "claim_write_lock_ms": claim_write_lock_ms,
                            "ram_class_skipped": skipped_ram_class,
                            "census_lane_protection_skipped": skipped_census_lane_protection,
                        }
                    conn.rollback()
                    conn.execute("PRAGMA query_only=ON")
                conn.commit()
                return {
                    "claimed": False,
                    "reason": "no_pending_claimable",
                    "history_skipped": skipped_history,
                    "launch_cooldown_skipped": skipped_launch_cooldown,
                    "multisymbol_ram_skipped": skipped_multisym_ram,
                    "ram_class_skipped": skipped_ram_class,
                    "census_lane_protection_skipped": skipped_census_lane_protection,
                    "multisymbol_commit_skipped": skipped_multisym_commit,
                    "terminal_avoid_skipped": skipped_avoid_terminal,
                    "longrun_cap_skipped": skipped_longrun_cap,
                    "opt_census_slot_deferred": skipped_opt_census_slots,
                    "drain_window_skipped": skipped_drain_window,
                    "opt_census_program_slots": opt_k_eff,
                    "opt_census_lanes_per_program": opt_l_eff,
                    "opt_census_cell_slots": opt_g_eff,
                    "recovery_capped": recovery_capped,
                }
            except Exception:
                conn.rollback()
                raise

    # The shared mutation lock closes the OFF-during-claim race. Factory_OFF
    # asserts its flag first and then waits for this lock to drain. Every cold
    # file/process/report probe above is complete before this helper; while held
    # we only re-read OFF and execute one bounded SQLite claim attempt.
    mutation_lock_path = path_for_factory_flag(factory_off_flag)

    def _claim_under_factory_lock() -> dict[str, Any]:
        admission_deadline = (
            time.monotonic() + FACTORY_ADMISSION_LOCK_TIMEOUT_SECONDS
        )
        while True:
            mutation_lock = FactoryMutationLock(
                mutation_lock_path,
                owner=f"terminal_worker.claim_atomic:{terminal}",
            )
            try:
                mutation_lock.__enter__()
                break
            except RuntimeError:
                # Re-probe OFF on every contention retry so an asserted
                # interlock wins immediately.
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
                # Windows can surface the short delete-pending handoff between
                # lock owners as sharing/access-denied instead of FileExists.
                # Treat only those well-known codes as ordinary contention;
                # permanent/unknown I/O failures remain explicit interlock
                # errors.
                winerror = getattr(exc, "winerror", None)
                if winerror in {5, 32, 80, 183} or getattr(exc, "errno", None) in {
                    errno.EACCES,
                    errno.EEXIST,
                }:
                    if time.monotonic() >= admission_deadline:
                        return {
                            "claimed": False,
                            "reason": "factory_mutation_lock_busy",
                            "lock": str(mutation_lock_path),
                        }
                    time.sleep(FACTORY_ADMISSION_LOCK_POLL_SECONDS)
                    continue
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
                return _with_claim_lock_sqlite_write(_claim)
            except sqlite3.OperationalError as exc:
                if not _is_sqlite_locked(exc):
                    raise
                return {"claimed": False, "reason": "sqlite_locked"}
        finally:
            mutation_lock.__exit__(None, None, None)

    claim_result = _claim_under_factory_lock()
    lane_preflights: list[dict[str, Any]] = []
    pruning_preflights: list[dict[str, Any]] = []
    history_preflights: list[dict[str, Any]] = []
    for _preflight_index in range(CLAIM_PREFLIGHT_MAX_CANDIDATES):
        reason = claim_result.get("reason")
        if reason == "opt_census_lane_preflight_required":
            candidate = dict(claim_result["candidate"])
            payload = _json_loads(candidate.get("payload_json"))
            lane = dl089_scheduling.lane_id(
                payload,
                ea_id=candidate.get("ea_id"),
                symbol=candidate.get("symbol"),
            )
            lane_preflight = _opt_census_lane_preflight_outside_factory_lock(
                root,
                terminal,
                candidate,
                pruning_enabled=pruning_enabled,
            )
            lane_preflights.append({
                "program_id": lane[0],
                "arm": lane[1],
                **lane_preflight,
            })
            if (
                lane_preflight.get("status") == "checked"
                and lane_preflight.get("candidate_pending") is True
                and lane_preflight.get("token")
            ):
                opt_census_lane_tokens[str(candidate["id"])] = dict(
                    lane_preflight["token"]
                )
                pruning_checked_payloads[str(candidate["id"])] = str(
                    candidate.get("payload_json") or "{}"
                )
            else:
                pruning_attempted_lanes.add(lane)
                pruning_deferred_candidates.add(
                    (str(candidate["id"]), str(candidate.get("payload_json") or "{}"))
                )
            claim_result = _claim_under_factory_lock()
            continue
        if reason == "opt_census_pruning_required":
            candidate = dict(claim_result["candidate"])
            program = str(
                claim_result.get("program_id")
                or dl089_scheduling.program_id(
                    _json_loads(candidate.get("payload_json")),
                    ea_id=candidate.get("ea_id"),
                    symbol=candidate.get("symbol"),
                )
            )
            pruning_preflight = _prune_candidate_outside_factory_lock(
                root,
                terminal,
                candidate,
            )
            pruning_preflights.append({"program_id": program, **pruning_preflight})
            pruning_attempted_lanes.add(
                dl089_scheduling.lane_id(
                    _json_loads(candidate.get("payload_json")),
                    ea_id=candidate.get("ea_id"),
                    symbol=candidate.get("symbol"),
                )
            )
            if (
                pruning_preflight.get("status") == "checked"
                and pruning_preflight.get("candidate_pending") is True
            ):
                pruning_checked_payloads[str(candidate["id"])] = str(
                    candidate.get("payload_json") or "{}"
                )
            else:
                pruning_deferred_candidates.add(
                    (str(candidate["id"]), str(candidate.get("payload_json") or "{}"))
                )
            claim_result = _claim_under_factory_lock()
            continue
        if reason == "history_preflight_required":
            candidate = dict(claim_result["candidate"])
            fingerprint = _history_preflight_fingerprint(candidate)
            try:
                history_ok, history = _p2_history_claimable(
                    candidate,
                    terminal,
                    history_registry,
                )
            except Exception as exc:
                history_ok = False
                history = {
                    "reason": "history_preflight_failed",
                    "error": f"{type(exc).__name__}: {exc}",
                }
            history_preflight_cache[str(candidate["id"])] = (
                fingerprint,
                history_ok,
                history,
            )
            history_preflights.append({
                "item_id": candidate["id"],
                "claimable": history_ok,
                "detail": history,
            })
            claim_result = _claim_under_factory_lock()
            continue
        break
    if claim_result.get("reason") in {
        "history_preflight_required",
        "opt_census_pruning_required",
        "opt_census_lane_preflight_required",
    }:
        # Bound pathological queues: after eight exact preflights, defer every
        # still-unchecked history/census row and let ordinary checked work flow.
        skip_unchecked_history = True
        if claim_result.get("reason") in {
            "opt_census_pruning_required",
            "opt_census_lane_preflight_required",
        }:
            candidate = dict(claim_result["candidate"])
            pruning_deferred_candidates.add(
                (str(candidate["id"]), str(candidate.get("payload_json") or "{}"))
            )
            payload = _json_loads(candidate.get("payload_json"))
            pruning_attempted_lanes.add(
                dl089_scheduling.lane_id(
                    payload,
                    ea_id=candidate.get("ea_id"),
                    symbol=candidate.get("symbol"),
                )
            )
        claim_result = _claim_under_factory_lock()

    if lane_preflights:
        claim_result["dl089_lane_preflights"] = lane_preflights
        claim_result["dl089_lane_preflight"] = lane_preflights[-1]
    if pruning_preflights:
        claim_result["dl089_claim_pruning_preflights"] = pruning_preflights
        claim_result["dl089_claim_pruning_preflight"] = pruning_preflights[-1]
    if history_preflights:
        claim_result["history_claim_preflights"] = history_preflights
    if completed_claim_recovery:
        claim_result["completed_claim_recovery"] = completed_claim_recovery
    # Advance the fleet drain state (open/expire/claim) and emit its events.
    # Runs outside every claim transaction and swallows its own errors, so the
    # advisory drain coordination can never affect the claim result above.
    if drain_enabled:
        _drain_run_postprocess(
            root,
            terminal,
            claim_result,
            now_epoch=drain_now_epoch,
            free_ram_gb=multisym_free_ram_snapshot,
            host_total_gb=drain_host_total_gb,
            multisym_ids=multisym_ids,
        )
    return claim_result


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

    # See claim_atomic(): this census may spawn a slow CIM subprocess and must
    # complete before the claim's BEGIN IMMEDIATE transaction is opened.
    running_mt5_terminals = (
        set(farmctl._running_mt5_terminals())
        if root.resolve() == farmctl.DEFAULT_ROOT.resolve()
        else set()
    )
    try:
        targeted_multisym_ids = _multisymbol_ea_ids()
    except MultisymbolRegistryUnavailable as exc:
        return {
            "claimed": False,
            "reason": "multisymbol_registry_unavailable",
            "item_id": item_id,
            "error": str(exc),
        }
    targeted_worker_count = len(farmctl.worker_policy_terminals())
    targeted_lane_token: dict[str, Any] | None = None
    try:
        with farmctl.connect(root) as preflight_conn:
            preflight_row = preflight_conn.execute(
                "SELECT * FROM work_items WHERE id=?", (item_id,)
            ).fetchone()
        if preflight_row is not None:
            preflight_payload = _json_loads(preflight_row["payload_json"])
            if (
                str(preflight_row["phase"] or "").upper() == "OPT_CENSUS"
                and _is_governed_dl089_census_payload(preflight_payload)
            ):
                lane_preflight = _opt_census_lane_preflight_outside_factory_lock(
                    root,
                    terminal,
                    dict(preflight_row),
                    pruning_enabled=opt_census_pruning.pruning_enabled(),
                    allow_factory_off=True,
                )
                if (
                    lane_preflight.get("status") != "checked"
                    or not lane_preflight.get("token")
                ):
                    return {
                        "claimed": False,
                        "reason": "opt_census_lane_preflight_failed",
                        "item_id": item_id,
                        "preflight": lane_preflight,
                    }
                targeted_lane_token = dict(lane_preflight["token"])
    except sqlite3.Error as exc:
        return {
            "claimed": False,
            "reason": "opt_census_lane_preflight_sqlite_failed",
            "item_id": item_id,
            "error": str(exc),
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
        with sqlite3.connect(db_path, timeout=BUSY_TIMEOUT_MS / 1000.0) as conn:
            conn.row_factory = sqlite3.Row
            configure_sqlite_connection(conn)
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

                if terminal in running_mt5_terminals:
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
                analytic_block = _governed_analytic_claim_block(item, payload)
                if analytic_block is not None:
                    conn.commit()
                    return analytic_block
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

                item_is_opt_census = str(item["phase"] or "").upper() == "OPT_CENSUS"
                governed_opt_census = (
                    item_is_opt_census
                    and _is_governed_dl089_census_payload(payload)
                )
                active_opt_rows = [
                    dict(row)
                    for row in conn.execute(
                        "SELECT id,phase,ea_id,symbol,payload_json FROM work_items "
                        "WHERE status='active' AND upper(phase)='OPT_CENSUS'"
                    )
                ]
                active_opt = dl089_scheduling.active_census_snapshot(active_opt_rows)
                k_eff, l_eff, g_eff = dl089_scheduling.effective_limits(
                    targeted_worker_count
                )
                allowlist = dl089_scheduling.same_program_parallel_allowlist()
                program, arm = dl089_scheduling.lane_id(
                    payload, ea_id=item["ea_id"], symbol=item["symbol"]
                )
                candidate_lane_limit = l_eff if program in allowlist else min(1, l_eff)
                if item_is_opt_census:
                    if governed_opt_census and not _opt_census_token_matches(
                        conn, item, payload, targeted_lane_token
                    ):
                        conn.commit()
                        return {
                            "claimed": False,
                            "reason": "opt_census_lane_token_stale",
                            "item_id": item_id,
                        }
                    if active_opt["total"] >= g_eff:
                        conn.commit()
                        return {"claimed": False, "reason": "CELL_SLOT_WAIT", "item_id": item_id}
                    if program not in active_opt["programs"] and len(active_opt["programs"]) >= k_eff:
                        conn.commit()
                        return {"claimed": False, "reason": "PROGRAM_SLOT_WAIT", "item_id": item_id}
                    if active_opt["program_lane_counts"].get(program, 0) >= candidate_lane_limit:
                        conn.commit()
                        return {"claimed": False, "reason": "PROGRAM_LANE_WAIT", "item_id": item_id}
                    if (program, arm) in active_opt["lanes"]:
                        conn.commit()
                        return {"claimed": False, "reason": "PROGRAM_LANE_WAIT", "item_id": item_id}

                item_is_multisym = _work_item_is_multisymbol(
                    item, payload, targeted_multisym_ids
                )
                symbol_key = str(item["symbol"] or "").upper()
                active_symbol_counts, active_ea_symbol_pairs = farmctl._active_symbol_claim_state(conn)
                if symbol_key and active_symbol_counts.get(symbol_key, 0) >= farmctl.CLAIM_SYMBOL_ACTIVE_CAP:
                    conn.commit()
                    return {"claimed": False, "reason": "symbol_busy", "item_id": item_id}
                if symbol_key and (str(item["ea_id"]), symbol_key) in active_ea_symbol_pairs:
                    duplicates = active_opt["pairs"].get(
                        (str(item["ea_id"]), symbol_key), []
                    )
                    if not (
                        governed_opt_census
                        and dl089_scheduling.duplicate_pair_exception_allowed(
                            candidate=dict(item),
                            candidate_payload=payload,
                            active_duplicates=duplicates,
                            l_eff=candidate_lane_limit,
                            candidate_is_multisymbol=item_is_multisym,
                            allowlist=allowlist,
                        )
                    ):
                        conn.commit()
                        return {"claimed": False, "reason": "symbol_busy", "item_id": item_id}

                if str(item["phase"]).upper() == _Q04_PHASE:
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

                multisym_ids = targeted_multisym_ids
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
    if not _is_early_run_smoke_phase(phase):
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


def _dispatch_ex5_requirement(
    item: sqlite3.Row | dict[str, Any],
) -> dict[str, Any]:
    """Resolve and authenticate the immutable EX5 source without staging it."""

    payload = _json_loads(_work_item_value(item, "payload_json", "{}"))
    raw_path = payload.get("staged_ex5_path")
    raw_sha = payload.get("staged_ex5_sha256")
    item_kind = str(_work_item_value(item, "kind", "") or "")
    if item_kind == farmctl.HARNESS_WORK_ITEM_KIND:
        # Harness pseudo-EAs live outside framework/EAs with no setfile and no
        # registry row, so the EA-dir resolution below can only fail (row
        # cb5e3cd3 died staged_ex5_ea_dir_unresolved right after the generic
        # preflight learned the same lesson). Their canonical binary is the
        # harness .ex5 itself; the verified-copy staging below still applies.
        canonical_source = farmctl.HARNESS_PP_FIXTURE_SOURCE_DIR / (
            f"{farmctl.HARNESS_PP_FIXTURE_EA_LABEL}.ex5"
        )
        # The staging destination below derives its filename from ea_dir.name;
        # for the harness that identity is the source dir itself (the .ex5 is
        # framework/tests/<label>.ex5, staged as <label>.ex5 on the terminal).
        ea_dir = canonical_source.parent / farmctl.HARNESS_PP_FIXTURE_EA_LABEL
    else:
        ea_id = str(_work_item_value(item, "ea_id", "") or "")
        ea_dir = farmctl._ea_dir_from_setfile_path(
            Path(str(_work_item_value(item, "setfile_path", "") or "")),
            ea_id,
        )
        if ea_dir is None:
            ea_dir = farmctl._preferred_ea_dir(ea_id)
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
    return {
        "payload": payload,
        "ea_dir": ea_dir,
        "source": source,
        "source_sha256": source_sha,
        "expected_sha256": expected,
        "binding_source": binding_source,
    }


def _prepare_staged_ex5(
    item: sqlite3.Row | dict[str, Any],
    terminal: str,
    prestage_adoption: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Atomically stage and verify the exact EX5 required for this dispatch.

    Manifest-pinned diagnostic binaries retain precedence. Ordinary work items
    use the registry-resolved canonical EX5 and any enqueue-time hash binding;
    legacy rows without a binding acquire one from that source at this gate.
    Every path copies before dispatch so a dormant divergent terminal is
    repaired only through the same verified gate that authorizes its run.  An
    adopted pre-stage may supply the copy source, but this authoritative gate
    still re-hashes the canonical source, copied temporary, and live target.
    """

    requirement = _dispatch_ex5_requirement(item)
    ea_dir = requirement["ea_dir"]
    source = Path(requirement["source"])
    source_sha = str(requirement["source_sha256"])
    expected = str(requirement["expected_sha256"])
    binding_source = str(requirement["binding_source"])
    copy_source = source
    prestaged = next_cell_prestage.cached_file(
        prestage_adoption,
        role="ex5",
        logical_name=str(source.resolve(strict=True)),
    )
    if prestaged is not None:
        if (
            str(prestaged.get("sha256") or "") == expected
            and os.path.normcase(str(Path(str(prestaged.get("source_path"))).resolve(strict=True)))
            == os.path.normcase(str(source.resolve(strict=True)))
        ):
            candidate = Path(str(prestaged.get("cache_path") or ""))
            if candidate.is_file():
                copy_source = candidate

    destination = farmctl.MT5_ROOT / terminal / "MQL5" / "Experts" / "QM" / f"{ea_dir.name}.ex5"
    destination.parent.mkdir(parents=True, exist_ok=True)
    preexisting_sha = _sha256_file(destination) if destination.is_file() else None
    temporary = destination.with_suffix(destination.suffix + f".{os.getpid()}.tmp")
    prestage_cache_fallback = False
    try:
        shutil.copy2(copy_source, temporary)
        copied_sha = _sha256_file(temporary)
        if copied_sha != expected and copy_source != source:
            # A detached cache is only an optimization. Corruption or an
            # interrupted cache write falls back to the canonical source and
            # can never manufacture a terminal preflight failure.
            shutil.copy2(source, temporary)
            copied_sha = _sha256_file(temporary)
            copy_source = source
            prestage_cache_fallback = True
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
        "copy_source_path": str(copy_source.resolve()),
        "prestage_adopted": copy_source != source,
        "prestage_cache_fallback": prestage_cache_fallback,
        "prestage_token_sha256": (
            prestage_adoption.get("token_sha256") if copy_source != source and prestage_adoption else None
        ),
        "binding_source": binding_source,
        "preexisting_destination_sha256": preexisting_sha,
        "copied": True,
        "restaged": preexisting_sha != expected,
        "pre_run_sha256": pre_run_sha,
        "verified": True,
    }


def _next_cell_prestage_policy_generation() -> str:
    """Fingerprint selector semantics and flag-gated DL-089 policy inputs."""

    payload = {
        "schema": next_cell_prestage.POLICY_SCHEMA,
        "pending_claim_order_sql": _priority_pending_query(),
        "dl089_pruning_enabled": opt_census_pruning.pruning_enabled(),
        "dl089_limits": dl089_scheduling.effective_limits(
            len(farmctl.worker_policy_terminals())
        ),
        "dl089_allowlist": sorted(
            dl089_scheduling.same_program_parallel_allowlist()
        ),
    }
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def _next_cell_prestage_cpu_percent() -> float:
    """Short one-shot CPU sample isolated from claim-loop hysteresis state."""

    if sys.platform != "win32":
        return 0.0
    try:
        import ctypes

        class _FileTime(ctypes.Structure):
            _fields_ = [("lo", ctypes.c_uint32), ("hi", ctypes.c_uint32)]

        def _sample() -> tuple[int, int]:
            idle, kernel, user = _FileTime(), _FileTime(), _FileTime()
            if not ctypes.windll.kernel32.GetSystemTimes(
                ctypes.byref(idle), ctypes.byref(kernel), ctypes.byref(user)
            ):
                raise OSError("GetSystemTimes failed")

            def _ticks(value: "_FileTime") -> int:
                return (int(value.hi) << 32) | int(value.lo)

            idle_ticks = _ticks(idle)
            return idle_ticks, (_ticks(kernel) - idle_ticks) + _ticks(user)

        idle_before, busy_before = _sample()
        time.sleep(0.2)
        idle_after, busy_after = _sample()
        delta_idle = idle_after - idle_before
        delta_busy = busy_after - busy_before
        total = delta_idle + delta_busy
        return 100.0 * delta_busy / total if total > 0 else 0.0
    except Exception:
        # This is an optional optimization. Ambiguity declines instead of
        # stealing resources from an active tester.
        return float("nan")


def _next_cell_prestage_resource_probe(
    root: Path, config: next_cell_prestage.PrestageConfig
) -> dict[str, Any]:
    disk_gb = _disk_free_gb(root)
    free_ram_gb, free_commit_gb = _memory_headroom_gb()
    cpu_percent = _next_cell_prestage_cpu_percent()
    metrics = {
        "disk_free_gb": round(disk_gb, 3),
        "free_ram_gb": round(free_ram_gb, 3),
        "free_commit_gb": (
            round(free_commit_gb, 3) if math.isfinite(free_commit_gb) else None
        ),
        "cpu_percent": round(cpu_percent, 3) if math.isfinite(cpu_percent) else None,
    }
    if disk_gb < config.min_free_disk_gb:
        return {"allowed": False, "reason": "disk_headroom_low", **metrics}
    if free_ram_gb < config.min_free_ram_gb:
        return {"allowed": False, "reason": "ram_headroom_low", **metrics}
    if not math.isfinite(free_commit_gb) or free_commit_gb < config.min_free_commit_gb:
        return {"allowed": False, "reason": "commit_headroom_low", **metrics}
    if not math.isfinite(cpu_percent) or cpu_percent > config.max_cpu_percent:
        return {"allowed": False, "reason": "cpu_pressure", **metrics}
    return {"allowed": True, "reason": "within_budget", **metrics}


@contextmanager
def _next_cell_prestage_readonly_connection(root: Path):
    db_path = (root / farmctl.DB_REL).resolve(strict=True)
    connection = sqlite3.connect(
        f"file:{db_path.as_posix()}?mode=ro",
        uri=True,
        timeout=2,
    )
    connection.row_factory = sqlite3.Row
    configure_sqlite_connection(connection)
    connection.execute("PRAGMA query_only=ON")
    try:
        yield connection
    finally:
        connection.close()


def _next_cell_prestage_dl089_snapshot(
    conn: sqlite3.Connection,
    candidate: Mapping[str, Any],
    payload: Mapping[str, Any],
) -> tuple[dict[str, Any], list[Path]]:
    if str(candidate.get("phase") or "").upper() != "OPT_CENSUS":
        return {}, []
    dependencies: list[Path] = []
    metadata: dict[str, Any] = {
        "program_id": str(payload.get("program_id") or ""),
        "arm": str(payload.get("arm") or ""),
        "year": payload.get("year"),
        "cell_key": str(payload.get("cell_key") or ""),
        "q12_work_item_id": str(payload.get("q12_work_item_id") or ""),
        "q12_declaration_sha256": str(
            payload.get("q12_declaration_sha256") or ""
        ),
    }
    ledger_path_raw = str(payload.get("ledger_path") or "").strip()
    if ledger_path_raw:
        dependencies.append(Path(ledger_path_raw).resolve(strict=True))
    if opt_census_pruning.AMENDMENT_PATH.is_file():
        dependencies.append(opt_census_pruning.AMENDMENT_PATH.resolve(strict=True))
    if opt_census_pruning.pruning_enabled():
        advisory = opt_census_pruning.inspect_candidate_exclusion(conn, candidate)
        metadata["pruning_advisory"] = advisory
        for predecessor in advisory.get("inspected_predecessors") or []:
            evidence_path = Path(str(predecessor.get("evidence_path") or ""))
            if evidence_path.is_file():
                dependencies.append(evidence_path.resolve(strict=True))
        if advisory.get("would_skip_current"):
            raise next_cell_prestage.PrestageError(
                "dl089_pruning_advisory_would_skip"
            )
    if not _is_governed_dl089_census_payload(payload):
        metadata["governed"] = False
        return metadata, dependencies
    ledger_path, ledger = opt_census_pruning._load_ledger(payload)
    cells, lane_ledger = _dl089_declared_lane(ledger, payload)
    ids = [str(cell.get("work_item_id") or "") for cell in cells]
    if not ids or any(not value for value in ids):
        raise next_cell_prestage.PrestageError("dl089_ledger_cell_ids_incomplete")
    marks = ",".join("?" for _ in ids)
    matrix_rows = [
        dict(value)
        for value in conn.execute(
            f"SELECT * FROM work_items WHERE id IN ({marks})", ids
        ).fetchall()
    ]
    program, arm = dl089_scheduling.lane_id(
        payload,
        ea_id=candidate.get("ea_id"),
        symbol=candidate.get("symbol"),
    )
    frontier = dl089_scheduling.arm_frontier(matrix_rows, lane_ledger).get(
        (program, arm)
    )
    candidate_is_frontier = bool(
        frontier is not None
        and str(frontier.get("id") or "") == str(candidate.get("id") or "")
    )
    declared = next(
        (
            cell
            for cell in cells
            if str(cell.get("work_item_id") or "")
            == str(candidate.get("id") or "")
        ),
        None,
    )
    if declared is None:
        raise next_cell_prestage.PrestageError("dl089_candidate_absent_from_ledger")
    opt_census_pruning._validate_declared_identity(declared, payload)
    year = int(payload["year"])
    predecessors = [
        str(cell["work_item_id"])
        for cell in cells
        if str(cell.get("arm")) == arm and int(cell.get("year")) < year
    ]
    metadata.update(
        {
            "governed": True,
            "program_id": program,
            "arm": arm,
            "candidate_is_frontier": candidate_is_frontier,
            "ledger_path": str(ledger_path),
            "ledger_sha256": _sha256_file(ledger_path),
            "predecessor_ids": predecessors,
            "predecessor_status_sha256": _predecessor_status_fingerprint(
                conn, predecessors
            ),
        }
    )
    return metadata, dependencies


def _load_next_cell_prestage_snapshot(
    root: Path,
    terminal: str,
    config: next_cell_prestage.PrestageConfig,
    worker_generation: str,
    cancel: threading.Event,
) -> dict[str, Any]:
    """Read and hash one likely next row without claiming or mutating it."""

    with _next_cell_prestage_readonly_connection(root) as conn:
        candidate_row = conn.execute(_priority_pending_query()).fetchone()
        if candidate_row is None:
            raise next_cell_prestage.PrestageError("no_pending_candidate")
        candidate = dict(candidate_row)
        phase = str(candidate.get("phase") or "").upper()
        kind = str(candidate.get("kind") or "").lower()
        if phase == farmctl.COMPILE_EA_PHASE or kind == farmctl.COMPILE_WORK_ITEM_KIND:
            raise next_cell_prestage.PrestageError("candidate_is_compile_utility")
        payload_raw = str(candidate.get("payload_json") or "{}")
        payload = _json_loads(payload_raw)
        if terminal.upper() in _payload_avoid_terminals(payload):
            raise next_cell_prestage.PrestageError("candidate_avoids_terminal")
        setfile = Path(str(candidate.get("setfile_path") or ""))
        if not setfile.is_absolute() or not setfile.is_file():
            raise next_cell_prestage.PrestageError("candidate_setfile_unavailable")
        requirement = _dispatch_ex5_requirement(candidate)
        ex5_source = Path(requirement["source"])

        activation = custom_history_gate.load_activation(root)
        history_rows: list[dict[str, Any]] = []
        history_master_root: Path | None = None
        dependency_paths: list[Path] = []
        history_metadata: dict[str, Any] = {"required": activation is not None}
        if activation is not None:
            activation_path = custom_history_gate.activation_path(root).resolve(
                strict=True
            )
            manifest_path = Path(str(activation["manifest_path"])).resolve(
                strict=True
            )
            manifest = custom_history_contract.load_manifest(
                manifest_path, require_owner_approval=True
            )
            master_state = custom_history_master.load_master_state(
                root, manifest=manifest
            )
            history_master_root = Path(master_state["master_root"])
            history_rows, selected_symbols, ignored_symbols = (
                custom_history_copy_on_claim.select_archive_rows_for_symbols(
                    manifest,
                    _work_item_history_symbols(candidate, payload),
                )
            )
            dependency_paths.extend(
                [
                    activation_path,
                    manifest_path,
                    custom_history_master.master_state_path(root).resolve(strict=True),
                ]
            )
            history_metadata.update(
                {
                    "activation_sha256": activation.get("activation_sha256"),
                    "manifest_sha256": manifest.get("manifest_sha256"),
                    "selected_symbols": selected_symbols,
                    "ignored_symbols": ignored_symbols,
                    "archive_count": len(history_rows),
                }
            )

        dl089_metadata, dl089_dependencies = _next_cell_prestage_dl089_snapshot(
            conn, candidate, payload
        )
        dependency_paths.extend(dl089_dependencies)

        planned_copy_bytes = setfile.stat().st_size + ex5_source.stat().st_size
        planned_copy_bytes += sum(int(value["size"]) for value in history_rows)
        if planned_copy_bytes > config.max_bytes:
            raise next_cell_prestage.PrestageError(
                f"byte_cap_exceeded:{planned_copy_bytes}:cap:{config.max_bytes}"
            )

        files = [
            next_cell_prestage.file_spec(
                setfile.resolve(strict=True),
                role="setfile",
                logical_name=str(setfile.resolve(strict=True)),
                expected_sha256=(
                    str(payload.get("expected_setfile_sha256"))
                    if payload.get("expected_setfile_sha256")
                    else None
                ),
                cache=True,
                cancel=cancel,
            ),
            next_cell_prestage.file_spec(
                ex5_source.resolve(strict=True),
                role="ex5",
                logical_name=str(ex5_source.resolve(strict=True)),
                expected_sha256=str(requirement["expected_sha256"]),
                cache=True,
                cancel=cancel,
            ),
        ]
        if history_master_root is not None:
            for manifest_row in history_rows:
                relative = str(manifest_row["relative_path"])
                files.append(
                    next_cell_prestage.file_spec(
                        custom_history_master.master_file_path(
                            history_master_root, relative
                        ).resolve(strict=True),
                        role="custom_history_archive",
                        logical_name=relative,
                        expected_sha256=str(manifest_row["sha256"]),
                        cache=True,
                        cancel=cancel,
                    )
                )
        seen_dependencies: set[str] = set()
        for dependency in dependency_paths:
            resolved = dependency.resolve(strict=True)
            key = os.path.normcase(str(resolved))
            if key in seen_dependencies:
                continue
            seen_dependencies.add(key)
            files.append(
                next_cell_prestage.file_spec(
                    resolved,
                    role="dependency",
                    logical_name=str(resolved),
                    cache=False,
                    cancel=cancel,
                )
            )

        item_identity = {
            "id": str(candidate["id"]),
            "phase": phase,
            "ea_id": str(candidate.get("ea_id") or ""),
            "symbol": str(candidate.get("symbol") or ""),
            "period": _work_item_test_period(candidate, payload),
            "year": payload.get("year"),
        }
        return {
            "terminal": terminal.upper(),
            "worker_generation": worker_generation,
            "item": item_identity,
            "payload_sha256": next_cell_prestage.sha256_text(payload_raw),
            "policy_generation": _next_cell_prestage_policy_generation(),
            "files": files,
            "dependencies": {
                "dl089": dl089_metadata,
                "custom_history": history_metadata,
            },
            "metadata": {
                "planned_copy_bytes": planned_copy_bytes,
                "input_class": phase,
                "archive_bytes": sum(int(value["size"]) for value in history_rows),
            },
        }


def _next_cell_prestage_snapshot_sources_current(
    token: Mapping[str, Any],
) -> tuple[bool, str]:
    for spec in token.get("files") or []:
        source = Path(str(spec.get("source_path") or ""))
        try:
            stat = source.stat()
        except OSError:
            return False, f"source_missing:{spec.get('role')}"
        if (
            stat.st_size != int(spec.get("source_size", -1))
            or stat.st_mtime_ns != int(spec.get("source_mtime_ns", -1))
            or int(getattr(stat, "st_ino", 0)) != int(spec.get("source_inode", 0))
        ):
            return False, f"source_identity_changed:{spec.get('role')}"
        if not spec.get("cache") and _sha256_file(source) != str(
            spec.get("sha256") or ""
        ):
            return False, f"dependency_hash_changed:{spec.get('logical_name')}"
    return True, "match"


def _next_cell_prestage_candidate_is_current(
    root: Path,
    token: Mapping[str, Any],
) -> tuple[bool, str]:
    item_id = str((token.get("item") or {}).get("id") or "")
    try:
        with _next_cell_prestage_readonly_connection(root) as conn:
            row = conn.execute(
                "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
                (item_id,),
            ).fetchone()
            if row is None:
                return False, "candidate_missing"
            if str(row["status"]).lower() != "pending" or row["claimed_by"] is not None:
                return False, "candidate_not_pending"
            if next_cell_prestage.sha256_text(row["payload_json"] or "{}") != str(
                token.get("payload_sha256") or ""
            ):
                return False, "candidate_payload_changed"
            dl089 = dict((token.get("dependencies") or {}).get("dl089") or {})
            predecessors = [str(value) for value in dl089.get("predecessor_ids") or []]
            if predecessors and _predecessor_status_fingerprint(
                conn, predecessors
            ) != str(dl089.get("predecessor_status_sha256") or ""):
                return False, "dl089_predecessor_changed"
        if str(token.get("policy_generation") or "") != _next_cell_prestage_policy_generation():
            return False, "policy_generation_changed"
        return _next_cell_prestage_snapshot_sources_current(token)
    except (OSError, sqlite3.Error, ValueError) as exc:
        return False, f"current_probe_error:{type(exc).__name__}:{exc}"


def _next_cell_prestage_dependency_validator(
    root: Path,
    terminal: str,
    plan: Mapping[str, Any],
) -> tuple[bool, str]:
    item_id = str((plan.get("item") or {}).get("id") or "")
    try:
        with _next_cell_prestage_readonly_connection(root) as conn:
            row = conn.execute(
                "SELECT status,claimed_by FROM work_items WHERE id=?", (item_id,)
            ).fetchone()
            if (
                row is None
                or str(row["status"]).lower() != "active"
                or str(row["claimed_by"] or "").upper() != terminal.upper()
            ):
                return False, "claimed_row_binding_changed"
            dl089 = dict((plan.get("dependencies") or {}).get("dl089") or {})
            predecessors = [str(value) for value in dl089.get("predecessor_ids") or []]
            if predecessors and _predecessor_status_fingerprint(
                conn, predecessors
            ) != str(dl089.get("predecessor_status_sha256") or ""):
                return False, "dl089_predecessor_changed"
            q12_id = str(dl089.get("q12_work_item_id") or "")
            if q12_id and conn.execute(
                "SELECT 1 FROM work_items WHERE id=?", (q12_id,)
            ).fetchone() is None:
                return False, "dl089_q12_identity_missing"
        return True, "match"
    except (OSError, sqlite3.Error) as exc:
        return False, f"dependency_probe_error:{type(exc).__name__}:{exc}"


def _make_next_cell_prestage_controller(
    root: Path, terminal: str
) -> next_cell_prestage.PrestageController:
    config = next_cell_prestage.PrestageConfig.from_env(root, terminal)
    return next_cell_prestage.PrestageController(
        config,
        snapshot_loader=lambda generation, cancel: _load_next_cell_prestage_snapshot(
            root, terminal, config, generation, cancel
        ),
        candidate_is_current=lambda token: _next_cell_prestage_candidate_is_current(
            root, token
        ),
        resource_probe=lambda: _next_cell_prestage_resource_probe(root, config),
        policy_generation=_next_cell_prestage_policy_generation,
        dependency_validator=lambda plan: _next_cell_prestage_dependency_validator(
            root, terminal, plan
        ),
        telemetry=lambda value: print(
            json.dumps(dict(value), sort_keys=True), flush=True
        ),
    )


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

    if str(item["phase"] or "").upper() != _Q09_NEWS_PHASE:
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
    if not _is_early_run_smoke_phase(item.get("phase")):
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


def q09_cell_sharding_enabled(environ: dict[str, str] | None = None) -> bool:
    """Return the explicit rollout flag; absence is deliberately serial."""

    source = os.environ if environ is None else environ
    return str(source.get(Q09_CELL_SHARDING_FLAG, "")).strip().lower() in {
        "1", "true", "yes", "on",
    }


def _q09_max_terminals(environ: dict[str, str] | None = None) -> int:
    source = os.environ if environ is None else environ
    try:
        requested = int(
            source.get(
                Q09_CELL_SHARDING_MAX_TERMINALS_FLAG,
                str(Q09_CELL_SHARDING_DEFAULT_MAX_TERMINALS),
            )
        )
    except (TypeError, ValueError):
        requested = Q09_CELL_SHARDING_DEFAULT_MAX_TERMINALS
    return max(1, min(10, requested))


def _q09_helper_reservation_minutes(
    payload: dict[str, Any], total_terminals: int
) -> int:
    """Cover one deterministic shard plus an hour of catch-up headroom."""

    try:
        cells = max(1, int(payload.get("q09_cell_count") or 40))
        timeout_sec = max(60, int(payload.get("q09_cell_timeout_sec") or 3600))
    except (TypeError, ValueError):
        cells, timeout_sec = 40, 3600
    shard_cells = math.ceil(cells / max(1, total_terminals))
    return max(60, math.ceil(shard_cells * 3 * (timeout_sec + 600) / 60) + 60)


def _reserve_q09_helper_terminals(
    root: Path, row: sqlite3.Row | dict[str, Any], primary_terminal: str
) -> dict[str, Any] | None:
    """Atomically reserve idle helper slots for one active Q09 main claim."""

    payload = _json_loads(row["payload_json"])
    if (
        not q09_cell_sharding_enabled()
        or str(row["phase"] or "").upper() != _Q09_NEWS_PHASE
        or payload.get("diagnostic_non_admission") is True
        or _q09_max_terminals() <= 1
    ):
        return None
    primary = str(primary_terminal).upper()
    lock_path = path_for_factory_flag(root / "state" / "FACTORY_OFF.flag")
    try:
        mutation_lock = FactoryMutationLock(
            lock_path,
            owner=f"terminal_worker.q09_helpers:{primary}",
        )
        mutation_lock.__enter__()
    except (OSError, RuntimeError):
        return {
            "enabled": True,
            "helper_terminals": [],
            "reason": "factory_mutation_lock_busy",
        }
    try:
        if (root / "state" / "FACTORY_OFF.flag").exists():
            return {
                "enabled": True,
                "helper_terminals": [],
                "reason": "factory_off",
            }
        with farmctl.connect(root) as conn:
            active_rows = conn.execute(
                "SELECT claimed_by,payload_json FROM work_items "
                "WHERE status='active'"
            ).fetchall()
        active = {
            str(value["claimed_by"] or "").upper()
            for value in active_rows
            if value["claimed_by"]
        }
        try:
            running = (
                set(farmctl._running_mt5_terminals())
                if root.resolve() == farmctl.DEFAULT_ROOT.resolve()
                else set()
            )
        except Exception:
            return {
                "enabled": True,
                "helper_terminals": [],
                "reason": "terminal_process_scan_failed",
            }
        reservations = farmctl.terminal_reservations(root)
        try:
            expected_peak_gb = max(
                1.0,
                float(
                    payload.get("commit_reservation_gb")
                    or ORDINARY_COMMIT_RESERVATION_GB
                ),
            )
            already_reserved_gb = sum(
                max(
                    0.0,
                    float(
                        _json_loads(value["payload_json"]).get(
                            "commit_reservation_gb"
                        )
                        or 0.0
                    ),
                )
                for value in active_rows
            )
            commit_headroom_gb = _commit_headroom_gb() - already_reserved_gb
            ram_headroom_gb = _free_ram_gb()
            if not math.isfinite(commit_headroom_gb):
                commit_cap = 9 if commit_headroom_gb > 0 else 0
            else:
                commit_cap = math.floor(
                    max(0.0, commit_headroom_gb - COMMIT_MIN_FREE_GB)
                    / expected_peak_gb
                )
            if not math.isfinite(ram_headroom_gb):
                ram_cap = 9 if ram_headroom_gb > 0 else 0
            else:
                ram_cap = math.floor(
                    max(0.0, ram_headroom_gb - RAM_MIN_FREE_GB)
                    / expected_peak_gb
                )
            resource_cap = max(0, min(commit_cap, ram_cap))
        except (OSError, TypeError, ValueError):
            return {
                "enabled": True,
                "helper_terminals": [],
                "reason": "helper_resource_probe_failed",
            }
        candidates = [
            terminal
            for terminal in farmctl.active_mt5_terminals()
            if terminal != primary
            and terminal not in active
            and terminal not in running
            and terminal not in reservations
        ]
        helpers = candidates[: min(_q09_max_terminals() - 1, resource_cap)]
        if not helpers:
            return {
                "enabled": True,
                "helper_terminals": [],
                "reason": (
                    "helper_resource_headroom_low"
                    if resource_cap <= 0
                    else "no_free_helper_terminal"
                ),
            }
        reserved_by = f"q09_cell_shard:{os.getpid()}:{uuid.uuid4().hex}"
        minutes = _q09_helper_reservation_minutes(payload, len(helpers) + 1)
        reason = f"{_Q09_NEWS_PHASE} helper for {row['id']}"
        rows = [
            farmctl.set_terminal_reservation(
                root,
                helper,
                reserved_by,
                minutes=minutes,
                reason=reason,
            )
            for helper in helpers
        ]
        return {
            "schema_version": "qm.q09-cell-helper-lease/v1",
            "enabled": True,
            "main_terminal": primary,
            "helper_terminals": helpers,
            "reserved_by": reserved_by,
            "reservation_minutes": minutes,
            "reservations": rows,
        }
    finally:
        mutation_lock.__exit__(None, None, None)


def _release_q09_helper_terminals(root: Path, lease: dict[str, Any] | None) -> None:
    """Release only reservations still owned by this exact Q09 lease token."""

    if not lease or not lease.get("helper_terminals"):
        return
    expected = str(lease.get("reserved_by") or "")
    lock_path = path_for_factory_flag(root / "state" / "FACTORY_OFF.flag")
    deadline = time.monotonic() + FACTORY_ADMISSION_LOCK_TIMEOUT_SECONDS
    mutation_lock = None
    while mutation_lock is None:
        candidate = FactoryMutationLock(
            lock_path,
            owner=f"terminal_worker.q09_helper_release:{os.getpid()}",
        )
        try:
            candidate.__enter__()
            mutation_lock = candidate
        except RuntimeError:
            if time.monotonic() >= deadline:
                print(
                    json.dumps(
                        {
                            "event": "q09_helper_release_deferred",
                            "reason": "factory_mutation_lock_busy",
                            "terminals": lease.get("helper_terminals"),
                        },
                        sort_keys=True,
                    ),
                    flush=True,
                )
                return
            time.sleep(FACTORY_ADMISSION_LOCK_POLL_SECONDS)
    try:
        for terminal in lease["helper_terminals"]:
            current = farmctl.terminal_reservation(root, terminal)
            if current and current.get("reserved_by") == expected:
                farmctl.release_terminal_reservation(root, terminal)
    finally:
        mutation_lock.__exit__(None, None, None)


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
                    if _is_early_run_smoke_phase(item["phase"])
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
                    # Measurement family (OPT_CENSUS): a healthy completion is
                    # MEASURED, never a gate PASS/FAIL; INFRA_FAIL keeps the infra
                    # path. Non-measurement phases pass through unchanged.
                    verdict, reason, payload["verdict_taxonomy"] = (
                        farmctl._apply_measurement_phase_verdict(
                            item["phase"], verdict, reason, payload
                        )
                    )
                payload["verdict_reason"] = reason
                payload["run_smoke_exit_code"] = exit_code
                # 2026-06-10 — two-stage prescreen, worker path (mirrors the
                # farmctl dispatch classification): a prescreen PASS is NOT a
                # final verdict — requeue the item for the full window with
                # p2_prescreen_done so the next spawn uses full dates. A
                # prescreen FAIL is final by P2-prescreen design (cheap kill)
                # and gets the explicit P2_PRESCREEN_ reason prefix. An
                # INFRA_FAIL falls through to normal infra handling untouched.
                if (farmctl.phase_qid(item["phase"]) == farmctl.SUPPORTED_BACKTEST_PHASES[0]
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
                taxonomy = str(payload.get("verdict_taxonomy") or "unknown")
                verdict, taxonomy, identity, missing_identity = prepare_completion(
                    phase=str(item["phase"]), kind=str(item["kind"]), payload=payload,
                    summary=summary, verdict=verdict, taxonomy=taxonomy,
                )
                payload["verdict_taxonomy"] = taxonomy
                identity_sql, identity_values = identity_update_clause(
                    conn, identity, taxonomy
                )
                identity_sql = (", " + identity_sql) if identity_sql else ""
                final_status = "failed" if missing_identity else "done"
                conn.execute(
                    f"""
                    UPDATE work_items
                    SET status=?, verdict=?, evidence_path=?, claimed_by=NULL,
                        payload_json=?, updated_at=?{identity_sql}
                    WHERE id=?
                    """,
                    (
                        final_status, verdict, str(summary_path),
                        json.dumps(payload, sort_keys=True), now,
                        *identity_values, item_id,
                    ),
                )
                promoted = (
                    farmctl._promote_zero_trade_q02_cohort_to_draft_defect(conn, item)
                    if not missing_identity else []
                )
                dl089_pruning = None
                if (
                    final_status == "done"
                    and verdict == opt_census_pruning.census_measured_verdict()
                ):
                    dl089_pruning = (
                        opt_census_pruning.prune_after_completed_measurement(
                            conn, work_item_id=item_id, now=now
                        )
                    )
                conn.commit()
                if item_id in promoted:
                    verdict = "DRAFT_DEFECT"
                    reason = "Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES"
                aggregate = _aggregate_finished_parent(root, item["parent_task_id"])
                return {"finished": True, "status": final_status, "verdict": verdict,
                        "reason": payload.get("verdict_reason", reason),
                        "artifact_identity_missing": list(missing_identity),
                        "dl089_pruning": dl089_pruning,
                        "aggregate": aggregate}

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
                storm_log_path = payload.get("transient_infra_evidence_path")
                evidence_path = (
                    str(storm_log_path)
                    if isinstance(storm_log_path, str) and storm_log_path.strip()
                    else farmctl._evidence_unavailable_sentinel(payload["final_failure"])
                )
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict='INFRA_FAIL', claimed_by=NULL,
                        evidence_path=?, payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (evidence_path, json.dumps(payload, sort_keys=True), now, item_id),
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
                evidence_path = (
                    str(log_path)
                    if isinstance(log_path, str) and log_path.strip()
                    else farmctl._evidence_unavailable_sentinel(payload["final_failure"])
                )
                conn.execute(
                    """
                    UPDATE work_items
                    SET status='failed', verdict=?, claimed_by=NULL,
                        evidence_path=?, payload_json=?, updated_at=?
                    WHERE id=?
                    """,
                    (verdict, evidence_path, json.dumps(payload, sort_keys=True), now, item_id),
                )
                status = "failed"
            conn.commit()
            aggregate = _aggregate_finished_parent(root, item["parent_task_id"]) if status == "failed" else None
            return {"finished": True, "status": status, "verdict": verdict, "attempt": attempt, "aggregate": aggregate}

    try:
        result = _with_sqlite_retry(_finish)
        if (
            result.get("finished") is True
            and result.get("status") == "done"
            and result.get("verdict") == "CONFIG_LOCKED"
        ):
            result["q10_cascade"] = farmctl.auto_enqueue_q10_after_q09_result(
                root, q09_news_work_item_id=item_id
            )
        return result
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return {"finished": False, "reason": "sqlite_locked_finish_deferred"}


def _recover_completed_claim_for_terminal(
    root: Path,
    terminal: str,
) -> dict[str, Any] | None:
    """Finish one claim-fresh completed row stranded by SQLite contention.

    This is deliberately narrower than stale-claim recovery: it never releases
    or requeues an active row without a summary that passes the normal
    claim-time/evidence freshness checks.
    """

    db_path = root / farmctl.DB_REL
    if not db_path.is_file():
        return None
    try:
        with farmctl.connect(root) as conn:
            item = conn.execute(
                "SELECT * FROM work_items "
                "WHERE status='active' AND claimed_by=? "
                "ORDER BY updated_at LIMIT 1",
                (terminal,),
            ).fetchone()
    except sqlite3.OperationalError as exc:
        if _is_sqlite_locked(exc):
            return {"finished": False, "reason": "sqlite_locked_recovery_probe_deferred"}
        if "no such table" in str(exc).lower():
            return None
        raise
    if item is None:
        return None

    payload = _json_loads(item["payload_json"])
    child_pid = payload.get("pid")
    if child_pid and farmctl._pid_tree_exists(child_pid):
        return None
    summary_data = _find_work_item_summary_data(item, payload)
    if summary_data is None:
        return None

    summary_path, summary = summary_data
    exit_code = payload.get("run_smoke_exit_code")
    if not isinstance(exit_code, int):
        run_exit_codes = [
            run.get("exit_code")
            for run in summary.get("runs", [])
            if isinstance(run, dict) and isinstance(run.get("exit_code"), int)
        ]
        exit_code = next((code for code in run_exit_codes if code != 0), 0)

    result = _finish_work_item(root, str(item["id"]), exit_code)
    return {
        "item_id": str(item["id"]),
        "summary_path": str(summary_path),
        "run_smoke_exit_code": exit_code,
        **result,
    }


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
    # Harness rows (kind='harness', e.g. the pattern-permission fixture runner)
    # are pseudo-EAs living outside framework/EAs (framework/tests/) with no
    # setfile and no registry row — the generic EA-dir/setfile preflight can
    # only ever kill them (2026-08-21: row 83b89730 died ea_dir_missing on its
    # first claim). Their own spawn path validates the harness .ex5 and the
    # fixture bundle fail-closed, so the generic preflight must step aside.
    if "kind" in item.keys() and str(item["kind"]) == farmctl.HARNESS_WORK_ITEM_KIND:
        ex5 = farmctl.HARNESS_PP_FIXTURE_SOURCE_DIR / (
            f"{farmctl.HARNESS_PP_FIXTURE_EA_LABEL}.ex5"
        )
        if not ex5.is_file():
            return {"reason": "harness_ex5_missing", "detail": str(ex5)}
        return None
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


def _defer_runner_death(
    root: Path,
    item_id: str,
    terminal: str,
    spawn: dict[str, Any],
    ran_seconds: float,
) -> dict[str, Any]:
    """Release a dead runner's claim without inventing pipeline evidence."""

    now = farmctl.utc_now()

    def _update() -> int:
        with farmctl.connect(root) as conn:
            row = conn.execute(
                "SELECT payload_json FROM work_items "
                "WHERE id=? AND status='active' AND claimed_by=?",
                (item_id, terminal),
            ).fetchone()
            if row is None:
                return 0
            payload = _json_loads(row["payload_json"])
            payload["prior_failure"] = "runner_process_died_without_summary"
            payload["runner_death_at_iso"] = now
            payload["runner_death_pid"] = spawn.get("pid")
            payload["runner_death_seconds"] = round(ran_seconds, 2)
            try:
                prior_runner_deaths = max(
                    0, int(payload.get("runner_death_count") or 0)
                )
            except (TypeError, ValueError):
                prior_runner_deaths = 0
            payload["runner_death_count"] = prior_runner_deaths + 1
            _clear_stale_runtime_payload(payload)
            cursor = conn.execute(
                """
                UPDATE work_items
                SET status='pending',verdict=NULL,claimed_by=NULL,
                    payload_json=?,updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (json.dumps(payload, sort_keys=True), now, item_id, terminal),
            )
            conn.commit()
            return cursor.rowcount

    released = bool(_with_sqlite_retry(_update))
    return {
        "finished": True,
        "status": "pending" if released else "unknown",
        "verdict": None,
        "reason": "runner_process_died_without_summary",
        "claim_released": released,
    }


def _bound_runner_identity(payload: dict[str, Any]) -> dict[str, Any]:
    """Resolve runner liveness without accepting a reused historical PID.

    New spawns are bound to an immutable creation key.  For those rows a PID
    occupied by any other process is dead for this work item, even though the
    generic PID/tree probe reports it alive.  Legacy rows without a creation
    key retain the old tree probe until they naturally drain.
    """

    pid = payload.get("pid")
    if not pid:
        return {"state": "pid_missing", "alive": False, "pid": None}
    expected_key = str(payload.get("process_creation_key") or "").strip()
    if not expected_key:
        alive = farmctl._pid_tree_exists(pid)
        return {
            "state": "legacy_tree_live" if alive else "legacy_tree_dead",
            "alive": alive,
            "pid": pid,
            "expected_creation_key": None,
        }
    try:
        identity = farmctl.get_process_identity(int(pid))
    except Exception as exc:  # fail closed: identity uncertainty is not ownership
        return {
            "state": "identity_probe_error",
            "alive": False,
            "pid": pid,
            "expected_creation_key": expected_key,
            "error": f"{type(exc).__name__}: {exc}"[:240],
        }
    if identity is None:
        return {
            "state": "process_missing",
            "alive": False,
            "pid": pid,
            "expected_creation_key": expected_key,
            "observed_creation_key": None,
        }
    observed_key = str(identity.get("creation_key") or "")
    running = bool(identity.get("is_running", True))
    matches = running and observed_key == expected_key
    return {
        "state": "exact_live" if matches else (
            "pid_reused" if running and observed_key != expected_key else "exact_exited"
        ),
        "alive": matches,
        "pid": pid,
        "expected_creation_key": expected_key,
        "observed_creation_key": observed_key or None,
        "observed_image_path": identity.get("image_path"),
        "observed_running": running,
    }


def _news_runner_abort_eligible(item: dict[str, Any], payload: dict[str, Any]) -> bool:
    return bool(
        str(item.get("phase") or "").upper() == _Q09_NEWS_PHASE
        and payload.get("q09_run_plan_path")
        and payload.get("q09_run_plan_file_sha256")
    )


def _park_news_runner_abort(
    conn: sqlite3.Connection,
    item: dict[str, Any],
    payload: dict[str, Any],
    terminal: str,
    now: str,
    child_identity: dict[str, Any],
) -> dict[str, Any]:
    """Park a dead bound news runner and preserve its exact failure boundary."""

    diagnostic = {
        "reason": "bound_news_runner_process_not_live",
        "detected_at_iso": now,
        "terminal": terminal,
        "claim_stage": payload.get("claim_stage") or "spawned_monitoring",
        "started_at_iso": payload.get("started_at_iso"),
        "log_path": payload.get("log_path"),
        "runner_identity": child_identity,
    }
    payload["news_runner_spawn_abort"] = diagnostic
    payload["verdict_reason"] = NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE
    payload["verdict_taxonomy"] = "infra"
    _clear_stale_runtime_payload(payload)
    cursor = conn.execute(
        """
        UPDATE work_items
        SET status='pending',verdict=NULL,claimed_by=NULL,payload_json=?,updated_at=?
        WHERE id=? AND status='active' AND claimed_by=?
        """,
        (json.dumps(payload, sort_keys=True), now, item["id"], terminal),
    )
    if cursor.rowcount != 1:
        return {
            "parked": False,
            "hold_code": NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE,
            "diagnostic": diagnostic,
        }
    conn.execute(
        """
        INSERT INTO work_item_holds(
          work_item_id,hold_code,reason,active,release_on_restart,
          created_at,updated_at,released_at,release_note
        ) VALUES(?,?,?,1,0,?,?,NULL,NULL)
        ON CONFLICT(work_item_id) DO UPDATE SET
          hold_code=excluded.hold_code,
          reason=excluded.reason,
          active=1,
          release_on_restart=0,
          updated_at=excluded.updated_at,
          released_at=NULL,
          release_note=NULL
        """,
        (
            item["id"],
            NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE,
            NEWS_RUNNER_SPAWN_ABORT_HOLD_REASON,
            now,
            now,
        ),
    )
    event_detail = {
        "hold_code": NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE,
        "reason": NEWS_RUNNER_SPAWN_ABORT_HOLD_REASON,
        "terminal": terminal,
        "runner_identity": child_identity,
    }
    conn.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
        "VALUES(?,'work_item',?,'news_runner_spawn_abort_held',?)",
        (now, item["id"], json.dumps(event_detail, sort_keys=True)),
    )
    return {
        "parked": cursor.rowcount == 1,
        "hold_code": NEWS_RUNNER_SPAWN_ABORT_HOLD_CODE,
        "diagnostic": diagnostic,
    }


def _park_news_runner_abort_active(
    root: Path,
    item: dict[str, Any],
    payload: dict[str, Any],
    terminal: str,
    child_identity: dict[str, Any],
) -> dict[str, Any]:
    def _park() -> dict[str, Any]:
        with farmctl.connect(root) as conn:
            working_payload = dict(payload)
            parked = _park_news_runner_abort(
                conn,
                item,
                working_payload,
                terminal,
                farmctl.utc_now(),
                child_identity,
            )
            conn.commit()
            return parked

    return _with_post_claim_sqlite_retry(_park)


def _defer_runner_death_or_hold(
    root: Path,
    item: dict[str, Any],
    terminal: str,
    spawn: dict[str, Any],
    payload: dict[str, Any],
    ran_seconds: float,
) -> dict[str, Any]:
    if _news_runner_abort_eligible(item, payload):
        child_identity = _bound_runner_identity(payload)
        parked = _park_news_runner_abort_active(
            root,
            item,
            payload,
            terminal,
            child_identity,
        )
        return {
            "action": "news_runner_spawn_abort_held",
            "item_id": item["id"],
            "ran_seconds": round(ran_seconds, 2),
            **parked,
        }
    return {
        "action": "runner_death_requeued",
        "item_id": item["id"],
        **_defer_runner_death(
            root,
            item["id"],
            terminal,
            spawn,
            ran_seconds,
        ),
    }


def _active_terminal_claim_preflight(root: Path, terminal: str) -> dict[str, Any]:
    """Resolve process/slot state before the global claim mutation lock.

    ``_pid_tree_exists`` may launch a 15-second CIM subprocess and stopping a
    stale portable slot may also block.  Snapshot both outside
    ``FACTORY_MUTATION.lock``; the claim transaction compares the exact active
    row identity/payload before using the result and defers if it changed.
    """

    def _read_active() -> dict[str, Any] | None:
        with farmctl.connect(root) as conn:
            row = conn.execute(
                "SELECT * FROM work_items "
                "WHERE status='active' AND claimed_by=? LIMIT 1",
                (terminal,),
            ).fetchone()
            return dict(row) if row is not None else None

    try:
        row = _with_sqlite_retry(_read_active)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        return {
            "ready": False,
            "reason": "sqlite_locked_active_terminal_preflight",
            "error": str(exc),
        }
    if row is None:
        return {"ready": True, "item_id": None}

    payload_raw = str(row.get("payload_json") or "{}")
    payload = _json_loads(payload_raw)
    pid = payload.get("pid")
    worker_pid = payload.get("claimed_by_worker_pid")
    worker_alive = farmctl._pid_exists(worker_pid) if worker_pid else None
    child_alive = False
    child_identity: dict[str, Any] = {"state": "not_checked", "alive": False}
    if pid and worker_alive is not True:
        child_identity = _bound_runner_identity(payload)
        child_alive = bool(child_identity.get("alive"))
    stale_release = worker_alive is not True and not child_alive
    terminal_stopped = (
        _stop_terminal_slot_for_release(root, terminal) if stale_release else None
    )
    return {
        "ready": True,
        "item_id": str(row["id"]),
        "payload_json": payload_raw,
        "worker_pid": worker_pid,
        "worker_alive": worker_alive,
        "child_alive": child_alive,
        "child_identity": child_identity,
        "terminal_stopped": terminal_stopped,
    }


def _is_governed_dl089_census_payload(payload: Mapping[str, Any]) -> bool:
    """Distinguish sealed DL-089 cells from pre-contract legacy census rows."""

    return bool(
        payload.get("schema") == "qm.opt-census.v1"
        and str(payload.get("program_id") or "").strip()
        and str(payload.get("arm") or "").strip()
        and str(payload.get("cell_key") or "").strip()
        and str(payload.get("ledger_path") or "").strip()
        and str(payload.get("q12_work_item_id") or "").strip()
        and str(payload.get("q12_declaration_sha256") or "").strip()
    )


def _dl089_declared_lane(
    ledger: Mapping[str, Any], payload: Mapping[str, Any]
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Resolve the authenticated declaration containing one candidate lane."""

    stage = str(payload.get("opt_census_stage") or "").removesuffix("_RERUN")
    if stage in {"NUMERIC_BASELINE", "NUMERIC"}:
        source = list(
            ledger.get("driver", {}).get("numeric", {}).get("runs") or []
        )
    elif stage == "WF_COMBO":
        source = list(ledger.get("driver", {}).get("wf", {}).get("combo_runs") or [])
    elif stage == "FINAL_FULLWINDOW":
        source = list(
            ledger.get("driver", {}).get("final_fullwindow", {}).get("runs") or []
        )
    else:
        # 2026-09-03 (CEO): the annual CENSUS stage must see the driver's
        # append-only INFRA reruns exactly like the derived stages below do -
        # driver['reruns'] maps cell_key -> [rerun ids]; the newest rerun is
        # the cell's current row.  Without this the rerun row (new UUID) was
        # refused as candidate_not_arm_frontier / dl089_candidate_absent_from_ledger
        # and a program could never finish its last cell (DL089_QM5_1537).
        census_reruns = ledger.get("driver", {}).get("reruns", {}) or {}
        cells = []
        for raw_cell in ledger.get("cells") or []:
            cell = dict(raw_cell)
            rerun_ids = [
                str(value)
                for value in census_reruns.get(str(cell.get("cell_key") or ""), [])
                if str(value)
            ]
            if rerun_ids:
                cell["work_item_id"] = rerun_ids[-1]
            cells.append(cell)
        if census_reruns:
            return cells, {**dict(ledger), "cells": cells}
        return cells, dict(ledger)

    program = str(ledger.get("program_id") or "").strip()
    payload_program = str(payload.get("program_id") or "").strip()
    if not program or program != payload_program:
        raise opt_census_pruning.PruningError("payload/ledger program mismatch")
    target_arm = str(payload.get("arm") or "").strip()
    if not target_arm:
        raise opt_census_pruning.PruningError("derived payload has no lane arm")
    reruns = ledger.get("driver", {}).get("reruns", {}) or {}
    cells: list[dict[str, Any]] = []
    for raw_spec in source:
        spec = dict(raw_spec)
        spec_stage = str(spec.get("stage") or "")
        if spec_stage.removesuffix("_RERUN") != stage:
            continue
        derived = opt_census_select._derived_run_fields(
            dict(ledger), str(spec.get("cell_key") or ""), spec_stage, spec
        )
        if str(derived.get("arm") or "") != target_arm:
            continue
        cell_key = str(spec.get("cell_key") or "")
        rerun_ids = [str(value) for value in reruns.get(cell_key, []) if str(value)]
        if rerun_ids:
            spec["work_item_id"] = rerun_ids[-1]
        spec.update({"arm": derived["arm"], "year": derived["year"]})
        cells.append(spec)
    if not cells:
        raise opt_census_pruning.PruningError(
            f"derived lane absent from ledger: {stage}/{target_arm}"
        )
    years = sorted({int(cell["year"]) for cell in cells})
    lane_ledger = {**dict(ledger), "cells": cells, "years": years}
    return cells, lane_ledger


def _predecessor_status_fingerprint(
    conn: sqlite3.Connection, predecessor_ids: list[str]
) -> str:
    if not predecessor_ids:
        return hashlib.sha256(b"[]").hexdigest()
    marks = ",".join("?" for _ in predecessor_ids)
    rows = conn.execute(
        f"SELECT id,status,verdict,claimed_by FROM work_items WHERE id IN ({marks})",
        predecessor_ids,
    ).fetchall()
    by_id = {str(row["id"]): row for row in rows}
    if set(by_id) != set(predecessor_ids):
        return "MISSING"
    canonical = [
        {
            "id": work_item_id,
            "status": str(by_id[work_item_id]["status"] or ""),
            "verdict": str(by_id[work_item_id]["verdict"] or ""),
            "claimed_by": str(by_id[work_item_id]["claimed_by"] or ""),
        }
        for work_item_id in predecessor_ids
    ]
    return hashlib.sha256(
        json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def _opt_census_token_matches(
    conn: sqlite3.Connection,
    item: Mapping[str, Any],
    payload: Mapping[str, Any],
    token: Mapping[str, Any] | None,
) -> bool:
    """Revalidate the cold-file lane authorization inside the claim CAS."""

    if not token:
        return False
    if str(token.get("item_id") or "") != str(item["id"]):
        return False
    if str(token.get("payload_json") or "") != str(item["payload_json"] or "{}"):
        return False
    lane = dl089_scheduling.lane_id(
        payload, ea_id=item["ea_id"], symbol=item["symbol"]
    )
    if tuple(token.get("lane_id") or ()) != lane:
        return False
    try:
        year = int(payload.get("year"))
    except (TypeError, ValueError):
        return False
    if int(token.get("year", -1)) != year:
        return False
    predecessor_ids = [str(value) for value in token.get("predecessor_ids") or []]
    return _predecessor_status_fingerprint(conn, predecessor_ids) == str(
        token.get("predecessor_status_sha256") or ""
    )


def _opt_census_lane_preflight_outside_factory_lock(
    root: Path,
    terminal: str,
    candidate: dict[str, Any],
    *,
    pruning_enabled: bool,
    allow_factory_off: bool = False,
) -> dict[str, Any]:
    """Authenticate one exact arm head and return a transaction-bound token."""

    payload = _json_loads(candidate.get("payload_json"))
    if not _is_governed_dl089_census_payload(payload):
        return {"status": "legacy", "candidate_pending": True, "token": None}
    program, arm = dl089_scheduling.lane_id(
        payload, ea_id=candidate.get("ea_id"), symbol=candidate.get("symbol")
    )
    lane_lock_path = root / "state" / dl089_scheduling.pruning_lock_filename(
        program, arm
    )
    lane_lock = FactoryMutationLock(
        lane_lock_path,
        owner=f"terminal_worker.dl089_lane_preflight:{terminal}",
    )
    try:
        lane_lock.__enter__()
    except (OSError, RuntimeError) as exc:
        return {
            "status": "busy",
            "reason": "dl089_claim_pruning_lock_busy",
            "lock": str(lane_lock_path),
            "program_id": program,
            "arm": arm,
            "detail": str(exc),
        }
    if pruning_enabled:
        pruning = _prune_candidate_outside_factory_lock(
            root,
            terminal,
            candidate,
            allow_factory_off=allow_factory_off,
            lane_lock_held=True,
        )
        if pruning.get("status") != "checked" or pruning.get("candidate_pending") is not True:
            lane_lock.__exit__(None, None, None)
            return pruning
    else:
        pruning = {"status": "disabled", "candidate_pending": True}

    try:
        opt_census_pruning.authenticate_amendment()
        ledger_path, ledger = opt_census_pruning._load_ledger(payload)
        ledger_sha256 = _sha256_file(ledger_path)
        if str(ledger.get("q12_work_item_id") or "") != str(
            payload.get("q12_work_item_id") or ""
        ):
            raise opt_census_pruning.PruningError("payload/ledger Q12 binding mismatch")
        if str(ledger.get("q12_declaration_sha256") or "") != str(
            payload.get("q12_declaration_sha256") or ""
        ):
            raise opt_census_pruning.PruningError(
                "payload/ledger declaration hash mismatch"
            )
        cells, lane_ledger = _dl089_declared_lane(ledger, payload)
        ids = [str(cell.get("work_item_id") or "") for cell in cells]
        if not ids or any(not value for value in ids):
            raise opt_census_pruning.PruningError("ledger cell IDs are incomplete")

        def _read() -> dict[str, Any]:
            with farmctl.connect(root) as conn:
                row = conn.execute(
                    "SELECT * FROM work_items WHERE id=?", (str(candidate["id"]),)
                ).fetchone()
                if (
                    row is None
                    or str(row["status"]).lower() != "pending"
                    or row["claimed_by"] is not None
                    or str(row["payload_json"] or "{}")
                    != str(candidate.get("payload_json") or "{}")
                ):
                    return {"status": "stale", "reason": "candidate_changed"}
                marks = ",".join("?" for _ in ids)
                matrix_rows = [
                    dict(value)
                    for value in conn.execute(
                        f"SELECT * FROM work_items WHERE id IN ({marks})", ids
                    ).fetchall()
                ]
                frontier = dl089_scheduling.arm_frontier(matrix_rows, lane_ledger)
                frontier_row = frontier.get((program, arm))
                if frontier_row is None or str(frontier_row["id"]) != str(candidate["id"]):
                    return {
                        "status": "ineligible",
                        "reason": "candidate_not_arm_frontier",
                    }
                declared = next(
                    cell for cell in cells if str(cell["work_item_id"]) == str(candidate["id"])
                )
                opt_census_pruning._validate_declared_identity(declared, payload)
                year = int(payload["year"])
                predecessors = [
                    str(cell["work_item_id"])
                    for cell in cells
                    if str(cell.get("arm")) == arm and int(cell.get("year")) < year
                ]
                token = {
                    "schema": "qm.dl089-lane-eligibility-token/v1",
                    "item_id": str(candidate["id"]),
                    "payload_json": str(candidate.get("payload_json") or "{}"),
                    "ledger_sha256": ledger_sha256,
                    "lane_id": [program, arm],
                    "year": year,
                    "cell_key": str(payload["cell_key"]),
                    "q12_work_item_id": str(payload.get("q12_work_item_id") or ""),
                    "predecessor_ids": predecessors,
                    "predecessor_status_sha256": _predecessor_status_fingerprint(
                        conn, predecessors
                    ),
                }
                return {
                    "status": "checked",
                    "candidate_pending": True,
                    "program_id": program,
                    "arm": arm,
                    "token": token,
                    "pruning": pruning,
                }

        return _with_sqlite_retry(_read)
    except Exception as exc:
        return {
            "status": "error",
            "reason": "dl089_lane_preflight_failed",
            "item_id": str(candidate.get("id") or ""),
            "program_id": program,
            "arm": arm,
            "error": f"{type(exc).__name__}: {exc}",
        }
    finally:
        lane_lock.__exit__(None, None, None)


def _prune_candidate_outside_factory_lock(
    root: Path,
    terminal: str,
    candidate: dict[str, Any],
    *,
    allow_factory_off: bool = False,
    lane_lock_held: bool = False,
) -> dict[str, Any]:
    """Run the DL-089 file/hash backstop without the fleet-wide lock.

    A per-lane non-blocking lock prevents workers from parsing the same arm
    concurrently while independent arms can inspect in parallel.
    The database row is re-read and compared with the transaction snapshot
    before pruning; stale input is never authorized.
    """

    payload = _json_loads(candidate.get("payload_json"))
    program = dl089_scheduling.program_id(
        payload,
        ea_id=candidate.get("ea_id"),
        symbol=candidate.get("symbol"),
    )
    _program, arm = dl089_scheduling.lane_id(
        payload, ea_id=candidate.get("ea_id"), symbol=candidate.get("symbol")
    )
    lock_path = root / "state" / dl089_scheduling.pruning_lock_filename(program, arm)
    pruning_lock = None
    if not lane_lock_held:
        pruning_lock = FactoryMutationLock(
            lock_path,
            owner=f"terminal_worker.dl089_pruning:{terminal}",
        )
        try:
            pruning_lock.__enter__()
        except (OSError, RuntimeError) as exc:
            return {
                "status": "busy",
                "reason": "dl089_claim_pruning_lock_busy",
                "lock": str(lock_path),
                "program_id": program,
                "detail": str(exc),
            }

    try:
        expected_id = str(candidate.get("id") or "")
        expected_payload = str(candidate.get("payload_json") or "{}")
        if not allow_factory_off and (root / "state" / "FACTORY_OFF.flag").exists():
            return {
                "status": "factory_off",
                "reason": "factory_off",
                "item_id": expected_id,
                "program_id": program,
            }

        def _prune() -> dict[str, Any]:
            with farmctl.connect(root) as conn:
                row = conn.execute(
                    "SELECT * FROM work_items WHERE id=?",
                    (expected_id,),
                ).fetchone()
                if (
                    row is None
                    or str(row["status"]) != "pending"
                    or row["claimed_by"] is not None
                    or str(row["payload_json"] or "{}") != expected_payload
                ):
                    return {
                        "status": "stale",
                        "reason": "candidate_changed_before_pruning",
                        "item_id": expected_id,
                        "program_id": program,
                    }
                pruning = opt_census_pruning.prune_candidate_if_excluded(
                    conn,
                    row,
                    now=farmctl.utc_now(),
                )
                conn.commit()
                current = conn.execute(
                    "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
                    (expected_id,),
                ).fetchone()
                candidate_pending = bool(
                    current is not None
                    and str(current["status"]) == "pending"
                    and current["claimed_by"] is None
                    and str(current["payload_json"] or "{}") == expected_payload
                )
                return {
                    "status": "checked",
                    "item_id": expected_id,
                    "program_id": program,
                    "candidate_pending": candidate_pending,
                    "pruning": pruning,
                }

        try:
            return _with_sqlite_retry(_prune)
        except sqlite3.OperationalError as exc:
            if not _is_sqlite_locked(exc):
                raise
            return {
                "status": "sqlite_busy",
                "reason": "dl089_claim_pruning_sqlite_busy",
                "item_id": expected_id,
                "program_id": program,
                "error": str(exc),
            }
        except Exception as exc:  # fail closed for this census candidate
            return {
                "status": "error",
                "reason": "dl089_claim_pruning_failed",
                "item_id": expected_id,
                "error": f"{type(exc).__name__}: {exc}",
            }
    finally:
        if pruning_lock is not None:
            pruning_lock.__exit__(None, None, None)


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
    if str(phase or "").upper() == _Q08_PHASE:
        phase_timeout_min = farmctl._active_timeout_min_for_work_item(
            _Q08_PHASE, json.dumps(payload, sort_keys=True)
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
    identity_payload = dict(spawn)
    identity_payload.update(payload)
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
    runner_dead_observed_at: float | None = None
    _mem_acc: dict[str, int] = {
        "samples": 0,
        "peak_subtree_ws": 0,
        "peak_subtree_private": 0,
        "peak_metatester_ws": 0,
        "metatester_os_peak_ws": 0,
        "peak_terminal_ws": 0,
    }
    _last_mem_sample = 0.0
    while time.monotonic() < deadline:
        child_alive = bool(_bound_runner_identity(identity_payload).get("alive"))
        terminal_alive_after_child_exit = (not child_alive) and _terminal_slot_running(root, terminal)
        if not child_alive and not terminal_alive_after_child_exit:
            break
        if not child_alive and terminal_alive_after_child_exit:
            runner_dead_observed_at = runner_dead_observed_at or time.monotonic()
            if (
                time.monotonic() - runner_dead_observed_at
                >= RUNNER_DEATH_REQUEUE_GRACE_SECONDS
                and not _work_item_has_summary_data(root, item["id"])
            ):
                _stop_terminal_slot_for_release(root, terminal)
                return _defer_runner_death_or_hold(
                    root,
                    item,
                    terminal,
                    spawn,
                    identity_payload,
                    time.monotonic() - spawn_started,
                )
        else:
            runner_dead_observed_at = None
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
        _now_mem = time.monotonic()
        if _now_mem - _last_mem_sample >= TESTER_MEMORY_SAMPLE_SECONDS:
            _last_mem_sample = _now_mem
            _sample_tester_memory(pid, _mem_acc)
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
                    "attempt_count=99, evidence_path=COALESCE(?, evidence_path, ?), "
                    "claimed_by=NULL, payload_json=?, updated_at=? WHERE id=?",
                    (
                        str(evidence_path) if evidence_path is not None else None,
                        farmctl._evidence_unavailable_sentinel("log_bomb"),
                        json.dumps(payload, sort_keys=True),
                        killed_at,
                        item["id"],
                    ),
                )
                conn.commit()

        _with_sqlite_retry(_record_log_bomb)
        if _mem_acc["samples"] > 0:
            _write_tester_memory_ledger(
                root, item, payload, spawn, _mem_acc, terminal,
                run_seconds=(time.monotonic() - spawn_started),
                outcome="log_bomb",
            )
        return {"action": "log_bomb_killed", "item_id": item["id"],
                "ea_id": item.get("ea_id"), "journal_gb": gb,
                "evidence_path": str(evidence_path) if evidence_path is not None else None,
                "terminal_stopped": terminal_stopped}
    ran_seconds = time.monotonic() - spawn_started
    child_alive = bool(_bound_runner_identity(identity_payload).get("alive"))
    terminal_alive_after_child_exit = (not child_alive) and _terminal_slot_running(root, terminal)
    if (
        not child_alive
        and not terminal_alive_after_child_exit
        and ran_seconds >= LAUNCH_FAULT_MIN_SECONDS
        and not _work_item_has_summary_data(root, item["id"])
    ):
        return _defer_runner_death_or_hold(
            root,
            item,
            terminal,
            spawn,
            identity_payload,
            ran_seconds,
        )
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
    if _mem_acc["samples"] > 0:
        _write_tester_memory_ledger(
            root, item, payload, spawn, _mem_acc, terminal,
            run_seconds=ran_seconds,
            outcome=(
                "timeout"
                if (child_alive or terminal_alive_after_child_exit)
                else "finished"
            ),
        )
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


def _record_active_payload(
    root: Path,
    item_id: str,
    payload: dict[str, Any],
    *,
    terminal: str | None = None,
) -> bool:
    """Persist an active-row payload through the bounded contention policy."""

    def _write() -> bool:
        with farmctl.connect(root) as conn:
            where = "id=? AND status='active'"
            args: list[Any] = [
                json.dumps(payload, sort_keys=True),
                farmctl.utc_now(),
                item_id,
            ]
            if terminal is not None:
                where += " AND claimed_by=?"
                args.append(terminal)
            cursor = conn.execute(
                f"UPDATE work_items SET payload_json=?, updated_at=? WHERE {where}",
                tuple(args),
            )
            conn.commit()
            return cursor.rowcount == 1

    return bool(_with_post_claim_sqlite_retry(_write))


def _record_unspawned_terminal_state(
    root: Path,
    item_id: str,
    *,
    verdict: str,
    payload: dict[str, Any],
    updated_at: str,
) -> bool:
    def _write() -> bool:
        with farmctl.connect(root) as conn:
            cursor = conn.execute(
                """
                UPDATE work_items
                SET status='done', verdict=?, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=? AND status='active'
                """,
                (verdict, json.dumps(payload, sort_keys=True), updated_at, item_id),
            )
            conn.commit()
            return cursor.rowcount == 1

    return bool(_with_post_claim_sqlite_retry(_write))


def _run_claimed_item(
    root: Path,
    item: dict[str, Any],
    terminal: str,
    timeout_seconds: int,
    *,
    prestage_controller: next_cell_prestage.PrestageController | None = None,
    prestage_adoption: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (item["id"],)).fetchone()
    if not row:
        return {"action": "missing_item", "item_id": item["id"]}
    if (
        row["kind"] == farmctl.COMPILE_WORK_ITEM_KIND
        or row["phase"] == farmctl.COMPILE_EA_PHASE
    ):
        # COMPILE_EA deliberately consumes this claimed/quiescent slot without
        # launching terminal64. Its worker owns setfile generation, MetaEditor,
        # strict scoped build_check, and the utility evidence transition.
        try:
            from tools.strategy_farm import compile_work_items as _compile_work_items
        except ModuleNotFoundError:
            import compile_work_items as _compile_work_items
        return _compile_work_items.run_compile_work_item(
            root,
            farmctl.REPO_ROOT,
            row,
            terminal,
        )
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

        refreshed = _with_post_claim_sqlite_retry(_record_stale_preflight_clear)
        if not refreshed:
            return {"action": "missing_item", "item_id": item["id"]}
        row = refreshed
        existing_payload = _json_loads(row["payload_json"])
    existing_pid = existing_payload.get("pid")
    existing_identity = _bound_runner_identity(existing_payload)
    if existing_pid and existing_identity.get("alive"):
        existing_payload["adopted_active_child_at_iso"] = farmctl.utc_now()
        existing_payload["claimed_by_worker_pid"] = os.getpid()

        def _record_adoption() -> None:
            with farmctl.connect(root) as conn:
                conn.execute(
                    "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='active'",
                    (json.dumps(existing_payload, sort_keys=True), farmctl.utc_now(), item["id"]),
                )
                conn.commit()

        _with_post_claim_sqlite_retry(_record_adoption)
        existing_spawn = {
            "pid": existing_pid,
            "log_path": existing_payload.get("log_path"),
            "report_root": existing_payload.get("report_root"),
        }
        # The outer watchdog must never fire before the inner budget this row was
        # actually spawned with — the CLI --timeout-minutes default is a floor,
        # not the effective ceiling. See docs/ops/evidence/
        # q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md.
        try:
            existing_inner_budget_seconds = int(existing_payload.get("timeout_seconds") or 0)
        except (TypeError, ValueError):
            existing_inner_budget_seconds = 0
        if prestage_controller is not None:
            prestage_controller.child_spawned(
                item_id=str(item["id"]),
                pid=existing_pid,
                adopted_existing=True,
            )
        try:
            return _monitor_spawned_work_item(
                root,
                item,
                terminal,
                existing_spawn,
                existing_payload,
                max(timeout_seconds, existing_inner_budget_seconds),
                adopted=True,
            )
        finally:
            if prestage_controller is not None:
                prestage_controller.child_finished(item_id=str(item["id"]))
    if existing_pid and _news_runner_abort_eligible(dict(row), existing_payload):
        parked = _park_news_runner_abort_active(
            root,
            dict(row),
            existing_payload,
            terminal,
            existing_identity,
        )
        return {
            "action": "news_runner_spawn_abort_held",
            "item_id": item["id"],
            **parked,
        }
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
        if prestage_adoption is None:
            staging = _prepare_staged_ex5(row, terminal)
        else:
            staging = _prepare_staged_ex5(
                row,
                terminal,
                prestage_adoption=prestage_adoption,
            )
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
    if not _record_active_payload(root, item["id"], existing_payload):
        return {"action": "missing_item", "item_id": item["id"]}
    row = dict(row)
    row["payload_json"] = json.dumps(existing_payload, sort_keys=True)
    history_gate = _custom_history_gate(root, terminal)
    if history_gate.get("required") and (
        history_gate.get("status") not in CUSTOM_HISTORY_GATE_PASS_STATUSES
        or history_gate.get("admission_allowed") is False
    ):
        return {
            "action": "custom_history_gate_deferred",
            "item_id": item["id"],
            **_defer_custom_history_gate(root, row, terminal, history_gate),
        }
    if prestage_adoption is None:
        copy_on_claim = _privatize_custom_history_claim(
            root, row, terminal, history_gate
        )
    else:
        copy_on_claim = _privatize_custom_history_claim(
            root,
            row,
            terminal,
            history_gate,
            prestage_adoption=prestage_adoption,
        )
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
        if not _record_active_payload(root, item["id"], existing_payload):
            return {"action": "missing_item", "item_id": item["id"]}
        row["payload_json"] = json.dumps(existing_payload, sort_keys=True)

    # Re-audit the mixed topology after every mutation.  This proves both the
    # dynamic family link minima and every private manifest SHA before spawn.
    if copy_on_claim.get("status") == "PASS_PRIVATIZED":
        post_copy_gate = _custom_history_gate(root, terminal)
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
        if not _record_active_payload(root, item["id"], existing_payload):
            return {"action": "missing_item", "item_id": item["id"]}
        row["payload_json"] = json.dumps(existing_payload, sort_keys=True)
    q09_helper_lease = _reserve_q09_helper_terminals(root, row, terminal)
    if q09_helper_lease is not None:
        existing_payload["q09_cell_sharding"] = q09_helper_lease
        if not _record_active_payload(
            root, item["id"], existing_payload, terminal=terminal
        ):
            return {"action": "missing_item", "item_id": item["id"]}
        row["payload_json"] = json.dumps(existing_payload, sort_keys=True)
    try:
        _acquire_launch_slot(terminal)
        spawn = farmctl._spawn_work_item_runner(root, row, terminal)
    except BaseException:
        _release_q09_helper_terminals(root, q09_helper_lease)
        raise
    now = farmctl.utc_now()
    if not spawn.get("spawned"):
        _release_q09_helper_terminals(root, q09_helper_lease)
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
            if not _record_unspawned_terminal_state(
                root,
                item["id"],
                verdict="PENDING_RUNNER",
                payload=payload,
                updated_at=now,
            ):
                return {"action": "missing_item", "item_id": item["id"]}
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
            if not _record_unspawned_terminal_state(
                root,
                item["id"],
                verdict="WAITING_INPUT",
                payload=payload,
                updated_at=now,
            ):
                return {"action": "missing_item", "item_id": item["id"]}
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
    })
    # Real phase-runner spawn metadata intentionally omits most enqueue-time
    # bindings.  Never replace those authenticated values with ``None``.
    spawn_bindings = {
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
    }
    payload.update({key: value for key, value in spawn_bindings.items()
                    if value is not None})
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

    try:
        _with_post_claim_sqlite_retry(_record_spawn)
    except sqlite3.OperationalError as exc:
        if not _is_sqlite_locked(exc):
            raise
        # The child already exists; never rerun the whole item and double-spawn.
        # Continue monitoring with the in-memory binding.  Completion persists
        # the same payload through its own bounded retry transaction.
        payload["spawn_record_deferred_sqlite_busy"] = True

    if prestage_controller is not None:
        prestage_controller.child_spawned(
            item_id=str(item["id"]),
            pid=spawn.get("pid"),
        )

    # The outer watchdog must never fire before the inner budget just computed
    # and handed to run_smoke.ps1 as -TimeoutSeconds — the CLI --timeout-minutes
    # default is a floor, not the effective ceiling. See docs/ops/evidence/
    # q02_summary_missing_90min_outer_watchdog_mismatch_2026-08-16.md.
    try:
        return _monitor_spawned_work_item(
            root, item, terminal, spawn, payload, max(timeout_seconds, spawn_timeout_seconds)
        )
    finally:
        if prestage_controller is not None:
            prestage_controller.child_finished(item_id=str(item["id"]))
        _release_q09_helper_terminals(root, q09_helper_lease)


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
    override = os.environ.get(TEST_FREE_RAM_GB_ENV)
    if override is not None:
        try:
            value = float(override)
            if math.isfinite(value) and value >= 0.0:
                return value
        except (TypeError, ValueError):
            pass
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
            "at_utc": datetime.now(timezone.utc).isoformat(),
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


def _orphan_claim_marker_path(root: Path, item_id: str) -> Path:
    safe = "".join(
        ch if (ch.isalnum() or ch in "._-") else "_" for ch in str(item_id)
    )
    return root / ORPHAN_CLAIMS_REL / f"{safe}.json"


def _write_orphan_claim_marker(
    root: Path,
    item: dict[str, Any],
    terminal: str,
    run_exc: BaseException,
    release_exc: BaseException | None,
) -> Path | None:
    """Record a claim that could neither run nor be released, for later reconcile.

    Written to the filesystem (not the DB, which is exactly what is unavailable)
    so the next worker startup or the pump-maintenance reconcile stage can return
    the row to ``pending`` once the lock storm has cleared. Best-effort: a marker
    that cannot be written must not mask the original busy exit.
    """

    marker = _orphan_claim_marker_path(root, item["id"])
    record = {
        "item_id": item["id"],
        "terminal": terminal,
        "reason": "worker_exit_sqlite_busy_defer_release_failed",
        "run_error": str(run_exc)[:240],
        "release_error": (str(release_exc)[:240] if release_exc is not None else None),
        "created_at_iso": farmctl.utc_now(),
        "created_by_pid": os.getpid(),
    }
    try:
        marker.parent.mkdir(parents=True, exist_ok=True)
        tmp = marker.with_suffix(marker.suffix + f".tmp{os.getpid()}")
        tmp.write_text(json.dumps(record, sort_keys=True), encoding="utf-8")
        os.replace(tmp, marker)
        return marker
    except OSError as write_exc:
        print(json.dumps({
            "event": "orphan_claim_marker_write_failed",
            "terminal": terminal,
            "item_id": item["id"],
            "error": f"{type(write_exc).__name__}: {write_exc}",
        }), flush=True)
        return None


def _release_orphan_claim_row(
    root: Path, item_id: str, terminal: str
) -> str:
    """Return an orphaned active row to pending; append-only event on success.

    Returns one of ``released`` / ``already_clear`` (row moved on already) /
    ``missing`` (row gone). Raises ``sqlite3.OperationalError`` only when the DB
    is still locked, so the caller can keep the marker for the next reconcile.
    """

    def _release() -> str:
        now = farmctl.utc_now()
        with farmctl.connect(root) as conn:
            row = conn.execute(
                "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
                (item_id,),
            ).fetchone()
            if row is None:
                return "missing"
            if not (
                str(row["status"]) == "active"
                and str(row["claimed_by"] or "") == terminal
            ):
                return "already_clear"
            payload = _json_loads(row["payload_json"])
            payload["prior_failure"] = "worker_exit_sqlite_busy_released"
            payload["orphan_claim_released_at_iso"] = now
            _clear_stale_runtime_payload(payload)
            cursor = conn.execute(
                """
                UPDATE work_items
                SET status='pending', verdict=NULL, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (json.dumps(payload, sort_keys=True), now, item_id, terminal),
            )
            if cursor.rowcount != 1:
                return "already_clear"
            conn.execute(
                "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) "
                "VALUES(?,'work_item',?,'orphan_claim_released',?)",
                (
                    now,
                    item_id,
                    json.dumps(
                        {
                            "terminal": terminal,
                            "reason": "worker_exit_sqlite_busy_released",
                        },
                        sort_keys=True,
                    ),
                ),
            )
            conn.commit()
            return "released"

    return _with_post_claim_sqlite_retry(_release)


def reconcile_orphan_claims(root: Path, terminal: str | None = None) -> list[str]:
    """Drain durable orphan-claim markers, releasing their rows to pending.

    Read by the worker startup path (scoped to its own terminal) and by the
    pump-maintenance reconcile stage (fleet-wide, ``terminal=None``). Fully
    best-effort: a marker whose row is still lock-pinned is left in place for the
    next pass, and no exception here may block worker startup or the pump.
    """

    marker_dir = root / ORPHAN_CLAIMS_REL
    try:
        markers = sorted(marker_dir.glob("*.json"))
    except OSError:
        return []
    released: list[str] = []
    for marker in markers:
        try:
            record = json.loads(marker.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            # An unreadable/partial marker is not actionable; drop it so it does
            # not accumulate. A concurrently-written .tmp file is skipped by the
            # *.json glob above.
            try:
                marker.unlink()
            except OSError:
                pass
            continue
        item_id = str(record.get("item_id") or "")
        marker_terminal = str(record.get("terminal") or "")
        if not item_id or not marker_terminal:
            try:
                marker.unlink()
            except OSError:
                pass
            continue
        if terminal is not None and marker_terminal != terminal:
            continue
        try:
            outcome = _release_orphan_claim_row(root, item_id, marker_terminal)
        except sqlite3.OperationalError as exc:
            if not _is_sqlite_locked(exc):
                raise
            # Still locked — keep the marker and try again next reconcile pass.
            print(json.dumps({
                "event": "orphan_claim_reconcile_deferred",
                "terminal": marker_terminal,
                "item_id": item_id,
                "error": str(exc)[:240],
            }), flush=True)
            continue
        except Exception as exc:  # noqa: BLE001 — reconcile must never crash startup
            print(json.dumps({
                "event": "orphan_claim_reconcile_error",
                "terminal": marker_terminal,
                "item_id": item_id,
                "error": f"{type(exc).__name__}: {exc}",
            }), flush=True)
            continue
        try:
            marker.unlink()
        except OSError:
            pass
        if outcome == "released":
            released.append(item_id)
        print(json.dumps({
            "event": "orphan_claim_reconciled",
            "terminal": marker_terminal,
            "item_id": item_id,
            "outcome": outcome,
        }), flush=True)
    return released


def _defer_item_after_sqlite_busy(
    root: Path,
    item: dict[str, Any],
    terminal: str,
    exc: sqlite3.OperationalError,
) -> bool:
    """Return a pre-spawn item to pending without manufacturing INFRA evidence.

    On persistent lock (the release itself cannot commit within the ~60s
    exponential envelope) we write a durable orphan-claim marker so the row is
    still returned to pending by the next reconcile, instead of being stranded
    active for an operator to release by hand.
    """

    def _defer() -> bool:
        with farmctl.connect(root) as conn:
            row = conn.execute(
                "SELECT payload_json FROM work_items WHERE id=? AND status='active' AND claimed_by=?",
                (item["id"], terminal),
            ).fetchone()
            if row is None:
                return False
            payload = _json_loads(row["payload_json"])
            payload["sqlite_busy_deferred_at_iso"] = farmctl.utc_now()
            payload["sqlite_busy_deferred_operation"] = "run_claimed_item_pre_spawn"
            payload["sqlite_busy_error"] = str(exc)[:240]
            _clear_stale_runtime_payload(payload)
            cursor = conn.execute(
                """
                UPDATE work_items
                SET status='pending', verdict=NULL, claimed_by=NULL,
                    payload_json=?, updated_at=?
                WHERE id=? AND status='active' AND claimed_by=?
                """,
                (
                    json.dumps(payload, sort_keys=True),
                    farmctl.utc_now(),
                    item["id"],
                    terminal,
                ),
            )
            conn.commit()
            return cursor.rowcount == 1

    try:
        return bool(
            retry_sqlite_busy(
                _defer,
                attempts=ORPHAN_DEFER_RELEASE_RETRY_ATTEMPTS,
                base_delay_seconds=ORPHAN_DEFER_RELEASE_RETRY_BASE_SECONDS,
                max_delay_seconds=ORPHAN_DEFER_RELEASE_RETRY_MAX_SECONDS,
            )
        )
    except sqlite3.OperationalError as defer_exc:
        if not _is_sqlite_locked(defer_exc):
            raise
        # The DB is still locked after the full retry envelope. Do not strand the
        # row as active/<terminal> with no runner pid: persist a durable marker
        # so the worker startup path or the pump reconcile stage releases it.
        _write_orphan_claim_marker(root, item, terminal, exc, defer_exc)
        return False


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
    # Drain durable orphan-claim markers left by a prior worker that exited on a
    # busy DB and could not release its own claim (c261068d, 2026-09-02). Scoped
    # to this terminal so a peer's marker is left for its own worker / the pump.
    reconciled = reconcile_orphan_claims(root, terminal)
    if reconciled:
        print(json.dumps({"event": "reconciled_orphan_claims", "terminal": terminal, "item_ids": reconciled}), flush=True)
    startup_gate = _custom_history_gate(root, terminal)
    print(json.dumps({"event": "custom_history_startup_gate", **startup_gate}, sort_keys=True), flush=True)
    prestage_controller = _make_next_cell_prestage_controller(root, terminal)
    while not _STOP:
        rebuild_tester_memory_expectations()
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
        ram_census_bypass = (
            free_ram < ram_floor
            and _ram_latch_opt_census_bypass_available(root, free_ram)
        )
        global _RAM_LATCH_COMPILE_ONLY
        _RAM_LATCH_COMPILE_ONLY = False
        if free_ram < ram_floor and not ram_census_bypass:
            _RESOURCE_LATCH["ram_low"] = True
            if _ram_latch_compile_bypass_available(root, free_ram):
                # Latched, but a governed compile is claimable and cheap: run the
                # claim in compile-only mode instead of idling (2026-09-03).
                _RAM_LATCH_COMPILE_ONLY = True
                print(json.dumps({"event": "ram_low_compile_only", "terminal": terminal,
                                  "free_ram_gb": round(free_ram, 1), "threshold_gb": ram_floor,
                                  "compile_floor_gb": COMPILE_RAM_MIN_FREE_GB}), flush=True)
            else:
                print(json.dumps({"event": "ram_low_pause", "terminal": terminal,
                                  "free_ram_gb": round(free_ram, 1), "threshold_gb": ram_floor,
                                  "hysteresis_latched": True}), flush=True)
                # jitter so the fleet doesn't wake in lockstep and re-spike RAM together
                time.sleep(RAM_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
                continue
        elif not ram_census_bypass:
            _RESOURCE_LATCH["ram_low"] = False
        cpu_load = _cpu_load_percent()
        cpu_ceiling = (
            CPU_RESUME_LOAD_PERCENT if _RESOURCE_LATCH["cpu_high"] else CPU_MAX_LOAD_PERCENT
        )
        if cpu_load > cpu_ceiling:
            _RESOURCE_LATCH["cpu_high"] = True
            print(json.dumps({"event": "cpu_high_pause", "terminal": terminal,
                              "at_utc": datetime.now(timezone.utc).isoformat(),
                              "cpu_load_percent": round(cpu_load, 1),
                              "threshold_percent": cpu_ceiling,
                              "hysteresis_latched": True}), flush=True)
            time.sleep(CPU_GUARD_SLEEP_SECONDS + random.uniform(0, 10))
            continue
        _RESOURCE_LATCH["cpu_high"] = False
        quarantine = _custom_history_quarantine_active(root, terminal)
        if quarantine is not None:
            print(json.dumps({
                "event": "custom_history_terminal_quarantined",
                "terminal": terminal,
                "reason_code": quarantine.get("reason_code"),
                "item_id": quarantine.get("item_id"),
                "expires_at_utc": quarantine.get("expires_at_utc"),
                "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            }, sort_keys=True), flush=True)
            time.sleep(CUSTOM_HISTORY_GUARD_SLEEP_SECONDS)
            continue
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
                # v11 7.9: an event without a time cannot answer "how often". The
                # busy/release ratio was measurable (dimensionless); the lease cycle
                # RATE was not, so the (b) tail ETA could not be stated at all.
                "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            }, sort_keys=True), flush=True)
            time.sleep(POLL_SLEEP_SECONDS + random.uniform(0, 2))
            continue
        lease_handle = lease_result.handle
        try:
            prestage_controller.claim_attempt()
            claim = claim_atomic(root, terminal)
            prestage_adoption = prestage_controller.claim_result(claim)
            if not claim.get("claimed"):
                _pause_after_unclaimed(claim, terminal)
                continue
            item = claim["item"]
            lane_preflight = claim.get("dl089_lane_preflight") or {}
            if lease_handle is not None:
                lease_handle.bind_work_item(item["id"])
            print(json.dumps({
                "event": "claimed",
                "terminal": terminal,
                "item_id": item["id"],
                "custom_history_gate_audit_sha256": history_gate.get("audit_sha256"),
                "custom_history_lease_token": lease_handle.token if lease_handle else None,
                "claim_admission_mode": claim.get("claim_admission_mode"),
                "claim_write_lock_ms": claim.get("claim_write_lock_ms"),
                "dl089_lane_preflight_status": lane_preflight.get("status"),
                "dl089_lane_preflight_program_id": lane_preflight.get("program_id"),
                "dl089_lane_preflight_arm": lane_preflight.get("arm"),
                "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            }), flush=True)
            try:
                result = _run_claimed_item(
                    root,
                    item,
                    terminal,
                    timeout_seconds,
                    prestage_controller=prestage_controller,
                    prestage_adoption=prestage_adoption,
                )
            except sqlite3.OperationalError as exc:
                if not _is_sqlite_locked(exc):
                    raise
                deferred = _defer_item_after_sqlite_busy(root, item, terminal, exc)
                print(json.dumps({
                    "event": "run_item_sqlite_busy_deferred",
                    "terminal": terminal,
                    "item_id": item["id"],
                    "deferred_to_pending": deferred,
                    "error": str(exc),
                    "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }), flush=True)
                if not deferred:
                    # Exit cleanly without writing a verdict.  The supervisor
                    # restarts the daemon; the dead worker PID makes the claim
                    # safely releasable on the next atomic claim pass.
                    return 1
                time.sleep(random.uniform(0.05, 0.25))
                continue
            except Exception as exc:  # noqa: BLE001 — a bad ITEM must never kill the DAEMON
                # 2026-08-22 fleet attrition: an unhandled exception here used to
                # propagate through run_loop (which only had a finally) straight
                # to SystemExit — the daemon died, the watchdog respawned, and
                # the same poison-pill row was re-claimed by the fresh worker
                # (rank-0 harness KeyError; secondly a T10 IntegrityError from
                # the MNT-009 evidence trigger). Convert the crash into a
                # terminal INFRA_FAIL on THIS item with the EVIDENCE_UNAVAILABLE
                # sentinel (satisfying that very trigger) and keep the loop.
                tb = traceback.format_exc()
                print(json.dumps({
                    "event": "run_item_crashed",
                    "terminal": terminal,
                    "item_id": item["id"],
                    "error": f"{type(exc).__name__}: {exc}",
                    "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }), flush=True)
                try:
                    _fail_item_after_worker_crash(root, item, terminal, tb)
                except Exception as fail_exc:  # noqa: BLE001
                    print(json.dumps({
                        "event": "run_item_crash_record_failed",
                        "terminal": terminal,
                        "item_id": item["id"],
                        "error": f"{type(fail_exc).__name__}: {fail_exc}",
                    }), flush=True)
                continue
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
                    # The token pairs this release with its "claimed" record, so hold
                    # duration is a subtraction rather than an inference from ordering.
                    "lease_token": lease_handle.token,
                    "at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }, sort_keys=True), flush=True)
    prestage_controller.shutdown()
    return 0


def _fail_item_after_worker_crash(root: Path, item: sqlite3.Row, terminal: str, tb: str) -> None:
    """Land a crashed item as terminal INFRA_FAIL instead of killing the daemon.

    Uses the EVIDENCE_UNAVAILABLE sentinel so the MNT-009 evidence trigger
    accepts the row (the bare write without it is exactly what killed T10).
    The traceback is preserved in the payload for forensics.
    """
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT payload_json FROM work_items WHERE id=? AND status='active'",
            (item["id"],),
        ).fetchone()
        if row is None:
            return
        payload = _json_loads(row["payload_json"])
        payload["worker_crash_traceback_tail"] = tb.strip().splitlines()[-6:]
        payload["verdict_reason"] = "worker_crashed_handling_item"
        payload["verdict_taxonomy"] = "infra"
        cur = conn.execute(
            """
            UPDATE work_items
            SET status='failed', verdict='INFRA_FAIL', claimed_by=NULL,
                evidence_path=?, payload_json=?, updated_at=?
            WHERE id=? AND status='active'
            """,
            (
                farmctl._evidence_unavailable_sentinel("worker_crashed_handling_item"),
                json.dumps(payload, sort_keys=True),
                now,
                item["id"],
            ),
        )
        if cur.rowcount == 1:
            conn.commit()
        else:
            conn.rollback()


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
    parser.add_argument("--terminal", choices=farmctl.MT5_TERMINALS)
    parser.add_argument("--root", type=Path, default=farmctl.DEFAULT_ROOT)
    parser.add_argument("--timeout-minutes", type=float, default=90.0)
    parser.add_argument(
        "--work-item-id",
        help="run exactly this pending work item once; requires FACTORY_OFF.flag",
    )
    parser.add_argument(
        "--reconcile-orphan-claims",
        action="store_true",
        help="fleet-wide: drain state/orphan_claims/ markers to pending, then exit "
        "(pump-maintenance reconcile stage); does not require --terminal",
    )
    args = parser.parse_args(argv)
    if args.reconcile_orphan_claims:
        released = reconcile_orphan_claims(args.root, None)
        print(json.dumps({
            "event": "reconcile_orphan_claims_cli",
            "released": released,
            "count": len(released),
        }, sort_keys=True), flush=True)
        return 0
    if not args.terminal:
        parser.error("--terminal is required unless --reconcile-orphan-claims is set")
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
        # 2026-09-02 incident: workers restarted from an interactive session
        # silently lost the machine-level QM_* flags; log the effective config.
        "topdown_gate_priority": farmctl.topdown_gate_priority_enabled(),
        "dl089_pruning_env": os.environ.get("QM_ENABLE_DL089_PRUNING"),
        "sqlite_busy_timeout_ms_env": os.environ.get("QM_SQLITE_BUSY_TIMEOUT_MS"),
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
