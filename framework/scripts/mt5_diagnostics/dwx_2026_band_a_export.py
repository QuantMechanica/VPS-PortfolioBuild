"""Governed, task-bound T1 wrapper for the Darwinex-native 2026 Band A export.

The wrapper is intentionally not a Strategy Farm worker.  It is an explicit
maintenance operation for task 35eb350f and may run only from the clean
canonical checkout after review/landing.  Long extraction happens without
holding FACTORY_MUTATION.lock; T1 is protected by a PID-bound reservation and
the tester-cache purge task is quiesced for the whole session.
"""

from __future__ import annotations

import argparse
import csv
import ctypes
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time
from typing import Any, Mapping, Sequence

import psutil


REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from tools.dukascopy import common as dukascopy_common
from tools.strategy_farm import custom_history_contract
from tools.strategy_farm import custom_history_gate
from tools.strategy_farm import custom_history_master
from tools.strategy_farm import farmctl
from tools.strategy_farm import ftmo_m1_bootstrap as boot
from tools.strategy_farm import identity_hash
from tools.strategy_farm import reload_idle_workers
from tools.strategy_farm import start_terminal_workers
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock
# Imported last: dwx_m1_overlap_export pulls in dwx_m1_overlap_export_work_item,
# which inserts the absolute C:/QM/repo into sys.path (task af1e6342). The
# tools.strategy_farm namespace package then re-resolves to the canonical
# checkout, so a worktree under test would bind the unpatched launcher.
from framework.scripts.mt5_diagnostics import dwx_m1_overlap_export as overlap_export
from framework.scripts.mt5_diagnostics import dwx_tick_tail_probe as governance_guard


TASK_ID = "35eb350f-1fe2-4649-a349-58c38bd7e855"
TERMINAL_NAME = "T1"
TERMINAL_ROOT = Path("D:/QM/mt5/T1")
TERMINAL_BINARY = TERMINAL_ROOT / "terminal64.exe"
METAEDITOR_BINARY = TERMINAL_ROOT / "MetaEditor64.exe"
FARM_ROOT = Path("D:/QM/strategy_farm")
ARTIFACT_ROOT = FARM_ROOT / "artifacts" / "ops" / f"task_{TASK_ID}" / "source"
CANONICAL_REPO = Path("C:/QM/repo")
RESTORE_LAUNCHER = REPO_ROOT / "tools" / "strategy_farm" / "start_terminal_workers.py"
SOURCE = Path(__file__).with_name("QM_DWX_2026_Band_A_Export.mq5")
PROBE_SOURCE = Path(__file__).with_name("QM_DWX_Native_Depth_Probe.mq5")
PURGE_TASK = "QM_StrategyFarm_TesterCachePurge"
# Session-scoped chart history depth written into the generated startup.ini
# ([Charts] MaxBars).  A finite value is used deliberately: the INI encoding of
# the UI's "Unlimited" choice is not documented/verified for this build, while
# 1,000,000 M1 bars (~2.7 years of 24x5 minutes) covers the ~375k M1 bars from
# 2025-10-01 to the 2026 cutoff with margin.  T1's persistent common.ini is
# snapshotted before launch and restored + verified after owned termination.
SESSION_MAX_BARS = 1_000_000
WARMUP_SECONDS = 600
TERMINAL_CONFIG_DIR_NAME = "Config"
CONFIG_RESTORE_PROCESS_WAIT_SECONDS = 30
CONFIG_NOT_RESTORED_SCHEMA = "qm.dwx-2026-band-a-config-not-restored/v1"
PROBE_SCHEMA = "qm.dwx-2026-band-a-history-depth-probe/v1"
# Two symbols x 600 s warm-up + 180 s connect wait + launch overhead fit in
# 30 min; 45 min reservation keeps the 12+1 min cleanup margin intact.
PROBE_RESERVATION_MINUTES = 45
PROBE_TIMEOUT_SECONDS = 30 * 60
PROBE_ADMISSION_GIB = 17.0
PROBE_CSV_NAME = "probe.csv"
HISTORY_DEPTH_HEADER = [
    "symbol",
    "phase",
    "terminal_maxbars",
    "server_firstdate_broker_epoch",
    "terminal_firstdate_broker_epoch",
    "series_firstdate_broker_epoch",
    "series_bars_count",
    "synchronized",
    "bars_in_window",
    "window_from_broker_epoch",
    "window_to_broker_epoch_exclusive",
    "iterations",
    "warmup_ms",
    "status",
    "reason",
]
HISTORY_DEPTH_TEXT_FIELDS = {"symbol", "phase", "status", "reason"}
HISTORY_DEPTH_PHASES = ("BEFORE_WARMUP", "AFTER_WARMUP")
HISTORY_DEPTH_STATUSES = {
    "BEFORE_WARMUP",
    "OK",
    "HISTORY_DEPTH_SHORT",
    "UNKNOWN",
    "SYMBOL_SELECT_FAILED",
}
HISTORY_DEPTH_REASONS = {
    "NONE",
    "SERVER_FIRSTDATE_AFTER_START",
    "MAXBARS_REACHED",
    "NOT_SYNCHRONIZED",
    "WARMUP_TIMEOUT",
    "SERIES_FIRSTDATE_AFTER_START",
}
# Tick-leg empty-chunk contract (export MQL ExportTicks).  CopyTicksRange
# returning 0 inside a window with zero exported M1 bars is a closed market and
# is accepted on attempt 1 (CLOSED_SESSION).  Every other empty chunk keeps the
# full EXPORT_COPY_ATTEMPTS backoff and then fails the symbol closed (TICK_GAP).
# The wrapper re-verifies the journal and the sidecar below after the export.
EXPORT_COPY_ATTEMPTS = 30
RETRYABLE_HISTORY_ERRORS = frozenset({4401, 4403})
CHUNK_JOURNAL_HEADER = [
    "symbol",
    "stream",
    "from",
    "to_exclusive",
    "attempts",
    "copied",
    "error",
    "status",
]
TICK_ZERO_HEADER = [
    "symbol",
    "from_msc",
    "to_msc_exclusive",
    "bars_in_window",
    "attempts",
    "copied",
    "error",
    "classification",
]
TICK_ZERO_CLOSED = "CLOSED_SESSION"
TICK_ZERO_GAP_CLASSES = frozenset({"OPEN_MARKET_GAP", "UNPROVEN_WINDOW", "HISTORY_ERROR"})
TICK_JOURNAL_STATUSES = frozenset({"OK", "ZERO_CLOSED", "ZERO_GAP", "ERROR", "CEILING"})
# The probe must be structurally unable to emit prices: no price API, no
# floating-point type, no tick/rate structures.  Checked on the source text
# (static half) and on every output cell (runtime half, _parse_probe_csv).
PROBE_FORBIDDEN_PATTERNS = (
    r"\bdouble\b",
    r"\bfloat\b",
    r"\bMqlRates\b",
    r"\bMqlTick\b",
    r"\bMqlBookInfo\b",
    r"\bCopy(?:Rates|Open|High|Low|Close|Ticks|TicksRange|Spread|TickVolume|RealVolume|Buffer)\s*\(",
    r"\bi(?:Open|High|Low|Close|MA|Bands|ATR)\s*\(",
    r"\bSymbolInfo(?:Double|Tick)\s*\(",
    r"\bMarketBook\w*\s*\(",
    r"\bDoubleToString\s*\(",
    r"\bNormalizeDouble\s*\(",
    r"\bFileWrite(?:Double|Float|Struct|Array)\s*\(",
    r"\bSYMBOL_(?:BID|ASK|LAST)",
    r"\bCustom\w*\s*\(",
    r"\bWebRequest\s*\(",
)
MIN_FREE_GIB = 14.0
MIN_START_DISK_FREE_GIB = 90.0
MIN_RUNTIME_DISK_FREE_GIB = 60.0
DISK_SAMPLE_SECONDS = 60.0
RESERVATION_CLEANUP_MARGIN_SECONDS = 12 * 60
RESERVATION_DEADLINE_GUARD_SECONDS = 60
RESTORE_LOCK_MAX_WAIT_SECONDS = 120.0
RESTORE_LOCK_BACKOFF_SECONDS = 2.0
RESERVATION_HEARTBEAT_INTERVAL_SECONDS = 60.0
RESERVATION_HEARTBEAT_RETRY_SECONDS = 5.0
RESERVATION_HEARTBEAT_LEASE_MINUTES = 20
MAX_SESSION_MINUTES = 135
START_UTC = dt.datetime(2025, 10, 1, tzinfo=dt.UTC)
SESSION_TAG_RE = re.compile(r"^20\d{6}T\d{6}Z_[a-z0-9][a-z0-9_-]{0,47}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
RECEIPT_SCHEMA = "qm.dwx-2026-band-a-export-session/v1"
CALIBRATION_SCHEMA = "qm.dwx-2026-band-a-headroom-calibration/v1"
HEADROOM_ACCEPTANCE_SCHEMA = "qm.dwx-2026-band-a-headroom-acceptance/v1"
WORKER_NOT_RESTORED_SCHEMA = "qm.dwx-2026-band-a-worker-not-restored/v1"
WORKER_SOURCE = CANONICAL_REPO / "tools/strategy_farm/terminal_worker.py"
# These are the worker-governance values whose drift can change claim selection,
# concurrency, or RAM admission.  They are deliberately narrow: never persist a
# worker's full environment (which may contain credentials) in an ops receipt.
WORKER_ENVIRONMENT_KEYS = (
    "DL089_LANES_PER_PROGRAM",
    "DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST",
    "QM_ENABLE_DL089_PRUNING",
    "QM_EXACT_TESTER_RSS_RESERVATIONS",
    "QM_INDEX_RAM_CANARY",
    "QM_MULTISYMBOL_RAM_CANARY_V2",
    "QM_MULTISYMBOL_RAM_CANARY_V2_MAX_ROWS",
    "QM_RESEARCH_BACKTEST_MAX_ACTIVE",
    "QM_RESEARCH_RAM_FLOOR_V1",
    "QM_SQLITE_BUSY_TIMEOUT_MS",
    "QM_TOPDOWN_GATE_PRIORITY_ENABLED",
)
TASK_EVIDENCE_ROOT = (
    CANONICAL_REPO / "docs/ops/evidence" / f"task_{TASK_ID}"
)

A2_EVIDENCE_ROOT = CANONICAL_REPO / "docs/ops/evidence/2026-10-12_a2_research_ram_floor"
A2_CLOSURE_NOTE = A2_EVIDENCE_ROOT / "A2_WINDOW_CLOSURE_NOTE.md"
A2_BASE_RELOAD = A2_EVIDENCE_ROOT / "RELOAD_RECEIPT_cap2_20261012T172344Z.json"
A2_PREFIX_RELOAD = A2_EVIDENCE_ROOT / "RELOAD_RECEIPT_cap2_prefix_workers_20261012T181639Z.json"
A2_T6_DISCHARGE = A2_EVIDENCE_ROOT / "RELOAD_RECEIPT_cap2_T6_20261012T192331Z.json"
FABLE_AUTHORITY = (
    CANONICAL_REPO
    / "docs/ops/evidence"
    / f"task_{TASK_ID}"
    / "FABLE_VERIFICATION_PHASE3_PREREQS_2026-10-12.md"
)

# Rank and hard ceilings are the reviewed C1 table in PHASE2_PLAN.md.
BAND_A = (
    "XAUUSD",
    "NDX",
    "XTIUSD",
    "GDAXI",
    "USDJPY",
    "EURUSD",
    "GBPUSD",
    "SP500",
    "EURJPY",
    "AUDUSD",
    "XNGUSD",
    "EURGBP",
    "AUDCAD",
    "AUDJPY",
    "EURAUD",
)
HARD_CEILING_MINUTES = {
    "XAUUSD": 60,
    "NDX": 45,
    "XTIUSD": 40,
    "GDAXI": 40,
    "USDJPY": 50,
    "EURUSD": 60,
    "GBPUSD": 50,
    "SP500": 40,
    "EURJPY": 45,
    "AUDUSD": 45,
    "XNGUSD": 35,
    "EURGBP": 40,
    "AUDCAD": 40,
    "AUDJPY": 40,
    "EURAUD": 40,
}


class ExportRefused(RuntimeError):
    """A launch or cleanup invariant could not be proved."""


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _canonical_sha256(value: object) -> str:
    encoded = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("ascii")
    return hashlib.sha256(encoded).hexdigest()


def _atomic_write_json(path: Path, value: object) -> None:
    governance_guard._atomic_write_json(Path(path), value)


def _file_binding(path: Path) -> dict[str, Any]:
    resolved = Path(path).resolve()
    if not resolved.is_file():
        raise ExportRefused(f"required file missing: {resolved}")
    return {
        "path": str(resolved),
        "bytes": resolved.stat().st_size,
        "sha256": sha256_file(resolved),
    }


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ExportRefused(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ExportRefused(f"JSON object required: {path}")
    return value


def validate_symbols(values: Sequence[str]) -> tuple[str, ...]:
    symbols = tuple(str(value).strip().upper().removesuffix(".DWX") for value in values)
    if not 1 <= len(symbols) <= 2:
        raise ExportRefused("each session must contain one or two Band A symbols")
    if len(set(symbols)) != len(symbols) or any(symbol not in BAND_A for symbol in symbols):
        raise ExportRefused("session symbols must be distinct members of Band A")
    if tuple(sorted(symbols, key=BAND_A.index)) != symbols:
        raise ExportRefused("session symbols must preserve the reviewed Band A rank order")
    return symbols


def reservation_minutes(symbols: Sequence[str]) -> int:
    selected = validate_symbols(symbols)
    minutes = 15 + sum(HARD_CEILING_MINUTES[symbol] for symbol in selected)
    if minutes > MAX_SESSION_MINUTES:
        raise ExportRefused("selected symbols exceed the 135-minute session ceiling")
    return minutes


def export_timeout_seconds(symbols: Sequence[str]) -> int:
    """Leave ten of the reservation's fifteen overhead minutes for cleanup."""
    selected = validate_symbols(symbols)
    return (5 + sum(HARD_CEILING_MINUTES[symbol] for symbol in selected)) * 60


def _parse_cutoff(value: str) -> dt.datetime:
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as exc:
        raise ExportRefused("cutoff must be an ISO-8601 UTC minute") from exc
    if parsed.tzinfo is None:
        raise ExportRefused("cutoff must carry an explicit UTC offset")
    parsed = parsed.astimezone(dt.UTC)
    if parsed.second or parsed.microsecond:
        raise ExportRefused("cutoff must be minute-aligned")
    now_floor = dt.datetime.now(dt.UTC).replace(second=0, microsecond=0)
    if parsed < dt.datetime(2026, 1, 1, tzinfo=dt.UTC) or parsed > now_floor:
        raise ExportRefused("cutoff must be within 2026 and no later than the last UTC minute")
    return parsed


def _parse_utc_timestamp(value: object, *, label: str) -> dt.datetime:
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError) as exc:
        raise ExportRefused(f"{label} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise ExportRefused(f"{label} must carry an explicit UTC offset")
    return parsed.astimezone(dt.UTC)


def _disk_free_gib(path: Path = Path("D:/")) -> float:
    return shutil.disk_usage(Path(path)).free / (1024**3)


def _process_session_id(pid: int) -> int | None:
    if sys.platform != "win32":
        return None
    session_id = ctypes.c_ulong()
    if not ctypes.windll.kernel32.ProcessIdToSessionId(
        int(pid), ctypes.byref(session_id)
    ):
        return None
    return int(session_id.value)


def _worker_identity(worker: psutil.Process) -> dict[str, Any]:
    try:
        executable_path = worker.exe()
        command_line = worker.cmdline()
        created = worker.create_time()
    except (psutil.NoSuchProcess, psutil.AccessDenied) as exc:
        raise ExportRefused("T1 worker identity became unreadable") from exc
    if reload_idle_workers.terminal_for(command_line) != TERMINAL_NAME:
        raise ExportRefused("T1 worker command line is not governed")
    return {
        "terminal": TERMINAL_NAME,
        "pid": worker.pid,
        "created": created,
        "executable_path": str(Path(executable_path).resolve()),
        "command_line": [str(value) for value in command_line],
        "session_id": _process_session_id(worker.pid),
    }


def _worker_environment_binding(environment: Mapping[str, object]) -> dict[str, Any]:
    values = {
        key: (None if environment.get(key) is None else str(environment.get(key)))
        for key in WORKER_ENVIRONMENT_KEYS
    }
    return {
        "keys": list(WORKER_ENVIRONMENT_KEYS),
        "values": values,
        "sha256": _canonical_sha256(values),
    }


def _process_environment_binding(worker: psutil.Process) -> dict[str, Any]:
    try:
        environment = worker.environ()
    except (psutil.NoSuchProcess, psutil.AccessDenied) as exc:
        raise ExportRefused("T1 worker governance environment became unreadable") from exc
    return _worker_environment_binding(environment)


def _reservation_remaining_seconds(
    reservation: Mapping[str, Any] | None,
    *,
    now: dt.datetime | None = None,
) -> float | None:
    if reservation is None:
        return None
    until = _parse_utc_timestamp(
        reservation.get("until_utc"), label="reservation until_utc"
    )
    current = now or dt.datetime.now(dt.UTC)
    return (until - current.astimezone(dt.UTC)).total_seconds()


def _maintain_terminal_reservation(
    reserved_by: str,
    *,
    task_id: str = TASK_ID,
) -> dict[str, Any]:
    """Renew the exact T1 reservation under the global mutation lock.

    A transiently busy lock may defer one heartbeat while the existing lease
    still contains the complete cleanup/restore envelope.  Identity drift,
    expiry, or a missed safety envelope is always a hard refusal.
    """

    observed_at = _utc_now()
    try:
        with FactoryMutationLock(
            FARM_ROOT / "state/FACTORY_MUTATION.lock",
            owner=f"dwx_2026_band_a_export:{task_id}:heartbeat",
        ):
            before = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
            if before is None or before.get("reserved_by") != reserved_by:
                raise ExportRefused(
                    "task-bound T1 reservation changed before heartbeat"
                )
            renewed = farmctl.renew_terminal_reservation(
                FARM_ROOT,
                TERMINAL_NAME,
                reserved_by,
                minutes=RESERVATION_HEARTBEAT_LEASE_MINUTES,
            )
            if renewed.get("reserved_by") != reserved_by:
                raise ExportRefused(
                    "task-bound T1 reservation changed during heartbeat"
                )
            return {
                "status": "RENEWED",
                "observed_at_utc": observed_at,
                "until_before_utc": before.get("until_utc"),
                "until_after_utc": renewed.get("until_utc"),
                "heartbeat_at_utc": renewed.get("heartbeat_at_utc"),
                "heartbeat_count": renewed.get("heartbeat_count"),
            }
    except ExportRefused:
        raise
    except Exception as exc:
        current = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
        if current is None or current.get("reserved_by") != reserved_by:
            raise ExportRefused(
                "task-bound T1 reservation changed while heartbeat was deferred"
            ) from exc
        remaining = _reservation_remaining_seconds(current)
        required = (
            RESERVATION_CLEANUP_MARGIN_SECONDS
            + RESERVATION_DEADLINE_GUARD_SECONDS
            + RESTORE_LOCK_MAX_WAIT_SECONDS
            + RESERVATION_HEARTBEAT_INTERVAL_SECONDS
        )
        if remaining is None or remaining <= required:
            raise ExportRefused(
                "reservation heartbeat failed inside the cleanup safety envelope"
            ) from exc
        return {
            "status": "DEFERRED_LOCK_BUSY",
            "observed_at_utc": observed_at,
            "until_before_utc": current.get("until_utc"),
            "until_after_utc": current.get("until_utc"),
            "heartbeat_at_utc": current.get("heartbeat_at_utc"),
            "heartbeat_count": current.get("heartbeat_count"),
            "remaining_seconds": round(remaining, 6),
            "error": f"{type(exc).__name__}: {exc}",
        }


def _maintain_reservation_for_task(
    reserved_by: str,
    task_id: str,
) -> dict[str, Any]:
    """Keep the legacy one-argument seam for Band-A tests and callers."""
    if task_id == TASK_ID:
        return _maintain_terminal_reservation(reserved_by)
    return _maintain_terminal_reservation(reserved_by, task_id=task_id)


def _effective_export_timeout_seconds(
    requested_seconds: float,
    reservation_until_utc: object,
    *,
    now: dt.datetime | None = None,
) -> float:
    current = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    reservation_until = _parse_utc_timestamp(
        reservation_until_utc, label="reservation until_utc"
    )
    available = (reservation_until - current).total_seconds() - (
        RESERVATION_CLEANUP_MARGIN_SECONDS
        + RESERVATION_DEADLINE_GUARD_SECONDS
    )
    effective = min(float(requested_seconds), available)
    if effective <= 0:
        raise ExportRefused(
            "reservation has less than the required 12-minute cleanup margin"
        )
    return effective


def validate_mql_source(path: Path = SOURCE) -> dict[str, Any]:
    text = Path(path).read_text(encoding="utf-8-sig")
    forbidden = [
        pattern for pattern in boot.FORBIDDEN_MQL_TOKENS if re.search(pattern, text)
    ]
    forbidden.extend(
        token
        for token in ("CustomRates", "CustomTicks", "WebRequest(")
        if token in text
    )
    if forbidden:
        raise ExportRefused("export source contains forbidden APIs: " + ",".join(forbidden))
    compact = re.sub(r"\s+", "", text).lower()
    if 'root!="d:\\\\qm\\\\mt5\\\\t1"' not in compact:
        raise ExportRefused("exact T1 MQL path guard absent")
    declared = tuple(re.findall(r'"([A-Z0-9]+)"', text[text.index("QM_BAND_A_BEGIN") : text.index("QM_BAND_A_END")]))
    if declared != BAND_A:
        raise ExportRefused("MQL Band A symbol order differs from the reviewed rank order")
    for required in (
        "CopyRates(",
        "CopyTicksRange(",
        "COPY_TICKS_ALL",
        "TimeTradeServer()",
        "TimeGMT()",
        "TimeLocal()",
        "SYMBOL_DIGITS",
        "SYMBOL_POINT",
        "SymbolInfoSessionTrade(",
        "FILE_REWRITE",
        "TERMINAL_MAXBARS",
        "SERIES_SYNCHRONIZED",
        "SERIES_FIRSTDATE",
        "SERIES_SERVER_FIRSTDATE",
        "SERIES_TERMINAL_FIRSTDATE",
        "WarmUpHistory(",
        "InpWarmupSeconds",
        '"HISTORY_DEPTH_SHORT"',
        ".history_depth.csv",
        "ExportedBarsInWindow(",
        ".tick_zero_chunks.csv",
        '"ZERO_CLOSED"',
        '"ZERO_GAP"',
        '"CLOSED_SESSION"',
        '"OPEN_MARKET_GAP"',
        '"UNPROVEN_WINDOW"',
        '"HISTORY_ERROR"',
        '"TICK_GAP"',
        "zero_tick_closed_session_chunks",
        "zero_tick_gap_chunks",
        "if(copied==0 && !RetryableHistoryError(last_error) && closed_session) break;",
        "if(copied==0 && !RetryableHistoryError(last_error) && attempt==InpCopyAttempts) break;",
        "if(copied<0 && !RetryableHistoryError(last_error)) break;",
    ):
        if required not in text:
            raise ExportRefused(f"required MQL export token absent: {required}")
    return {**_file_binding(Path(path)), "band_a": list(BAND_A), "read_only": True}


def validate_probe_source(path: Path | None = None) -> dict[str, Any]:
    """Static half of the probe no-price guard."""

    path = Path(path) if path is not None else PROBE_SOURCE
    text = Path(path).read_text(encoding="utf-8-sig")
    forbidden = [
        pattern for pattern in boot.FORBIDDEN_MQL_TOKENS if re.search(pattern, text)
    ]
    forbidden.extend(
        pattern for pattern in PROBE_FORBIDDEN_PATTERNS if re.search(pattern, text)
    )
    if forbidden:
        raise ExportRefused(
            "probe source contains forbidden (price/trade/custom) APIs: "
            + ",".join(forbidden)
        )
    compact = re.sub(r"\s+", "", text).lower()
    if 'root!="d:\\\\qm\\\\mt5\\\\t1"' not in compact:
        raise ExportRefused("exact T1 MQL path guard absent from probe")
    declared = tuple(
        re.findall(
            r'"([A-Z0-9]+)"',
            text[text.index("QM_BAND_A_BEGIN") : text.index("QM_BAND_A_END")],
        )
    )
    if declared != BAND_A:
        raise ExportRefused("probe Band A symbol order differs from the reviewed rank order")
    for required in (
        "TERMINAL_MAXBARS",
        "SERIES_SERVER_FIRSTDATE",
        "SERIES_TERMINAL_FIRSTDATE",
        "SERIES_FIRSTDATE",
        "SERIES_SYNCHRONIZED",
        "Bars(",
        "WarmUpHistory(",
        "QM_DWX_2026_BAND_A_PROBE_COMPLETE_",
        "QM\\\\dwx_2026_band_a_probe\\\\",
    ):
        if required not in text:
            raise ExportRefused(f"required probe token absent: {required}")
    return {
        **_file_binding(Path(path)),
        "band_a": list(BAND_A),
        "read_only": True,
        "no_price_api": True,
    }


def _git(*args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(CANONICAL_REPO), *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
        creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
    )
    if completed.returncode:
        raise ExportRefused((completed.stderr or completed.stdout or "git failed").strip())
    return completed.stdout.strip()


def validate_canonical_runtime() -> dict[str, Any]:
    try:
        Path(__file__).resolve().relative_to(CANONICAL_REPO.resolve())
    except ValueError as exc:
        raise ExportRefused("apply mode is allowed only from C:/QM/repo after landing") from exc
    relative = Path(__file__).resolve().relative_to(CANONICAL_REPO.resolve()).as_posix()
    source_relative = SOURCE.resolve().relative_to(CANONICAL_REPO.resolve()).as_posix()
    probe_relative = (
        PROBE_SOURCE.resolve().relative_to(CANONICAL_REPO.resolve()).as_posix()
    )
    for path in (relative, source_relative, probe_relative):
        _git("ls-files", "--error-unmatch", "--", path)
    if _git("status", "--porcelain=v1", "--", relative, source_relative, probe_relative):
        raise ExportRefused("wrapper/source are dirty or untracked in the canonical checkout")
    return {
        "head": _git("rev-parse", "HEAD"),
        "wrapper": _file_binding(Path(__file__)),
        "source": _file_binding(SOURCE),
        "probe_source": _file_binding(PROBE_SOURCE),
    }


def validate_a2_authority() -> dict[str, Any]:
    bindings = {
        "closure_note": _file_binding(A2_CLOSURE_NOTE),
        "fable_authority": _file_binding(FABLE_AUTHORITY),
        "base_reload": _file_binding(A2_BASE_RELOAD),
        "prefix_reload": _file_binding(A2_PREFIX_RELOAD),
        "t6_discharge": _file_binding(A2_T6_DISCHARGE),
    }
    base = _load_json(A2_BASE_RELOAD)
    prefix = _load_json(A2_PREFIX_RELOAD)
    discharge = _load_json(A2_T6_DISCHARGE)
    if not base.get("finished_at") or base.get("pending") != []:
        raise ExportRefused("base cap-2 reload receipt is incomplete")
    if prefix.get("pending") not in ([], ["T6"]) or not prefix.get("finished_at"):
        raise ExportRefused("prefix reload receipt has an undischargeable pending set")
    if not discharge.get("finished_at") or discharge.get("pending") != []:
        raise ExportRefused("T6 discharge receipt is incomplete")
    reloaded = [str(row.get("terminal") or "").upper() for row in discharge.get("reloaded") or []]
    if prefix.get("pending") == ["T6"] and reloaded != ["T6"]:
        raise ExportRefused("T6 discharge does not close the prefix receipt")
    if "no open ram re-measure / observation window" not in A2_CLOSURE_NOTE.read_text(
        encoding="utf-8-sig"
    ).casefold():
        raise ExportRefused("A2 closure note lacks the reviewed closure statement")
    return bindings


def _task_snapshot() -> dict[str, Any]:
    value = boot._powershell_json(
        f"""
$task=Get-ScheduledTask -TaskName '{PURGE_TASK}' -ErrorAction Stop
$info=Get-ScheduledTaskInfo -InputObject $task -ErrorAction Stop
$actions=@($task.Actions | ForEach-Object {{
  [pscustomobject]@{{execute=[string]$_.Execute;arguments=[string]$_.Arguments;working_directory=[string]$_.WorkingDirectory}}
}})
[pscustomobject]@{{
  task_name=$task.TaskName
  task_path=$task.TaskPath
  state=[string]$task.State
  enabled=([string]$task.State -ne 'Disabled')
  running=([string]$task.State -eq 'Running')
  actions=$actions
  last_task_result=[int]$info.LastTaskResult
  last_run_time=if($info.LastRunTime){{$info.LastRunTime.ToUniversalTime().ToString('o')}}else{{$null}}
  next_run_time=if($info.NextRunTime){{$info.NextRunTime.ToUniversalTime().ToString('o')}}else{{$null}}
}} | ConvertTo-Json -Compress
"""
    )
    if not isinstance(value, dict) or value.get("task_name") != PURGE_TASK:
        raise ExportRefused("purge scheduled-task state is unreadable")
    return value


def _purge_processes() -> list[dict[str, Any]]:
    value = boot._powershell_json(
        r"""
@(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
  $c=[string]$_.CommandLine
  $c -match 'tester_cache_purge\.ps1' -or $c -match 'custom_history_eviction\.py'
} | Select-Object ProcessId,Name,ExecutablePath,CreationDate) | ConvertTo-Json -Depth 4 -Compress
"""
    )
    if value in (None, []):
        return []
    rows = value if isinstance(value, list) else [value]
    if not all(isinstance(row, dict) for row in rows):
        raise ExportRefused("purge process scan returned malformed data")
    return rows


def _quiesce_purge(before: Mapping[str, Any]) -> dict[str, Any]:
    boot._powershell_json(
        f"""
$task=Get-ScheduledTask -TaskName '{PURGE_TASK}' -ErrorAction Stop
if([string]$task.State -eq 'Running'){{Stop-ScheduledTask -InputObject $task -ErrorAction Stop}}
Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
$deadline=(Get-Date).AddSeconds(30)
do{{$task=Get-ScheduledTask -TaskName '{PURGE_TASK}' -ErrorAction Stop; if([string]$task.State -eq 'Disabled'){{break}}; Start-Sleep -Milliseconds 250}}while((Get-Date) -lt $deadline)
if([string]$task.State -ne 'Disabled'){{throw 'purge task did not become Disabled'}}
@{{ok=$true}} | ConvertTo-Json -Compress
""",
        timeout=40,
    )
    active = _purge_processes()
    if active:
        raise ExportRefused("purge/eviction process remains active after task quiesce")
    return {"before": dict(before), "quiesced": _task_snapshot(), "active_processes": active}


def _restore_purge(before: Mapping[str, Any]) -> dict[str, Any]:
    enabled = "$true" if before.get("enabled") is True else "$false"
    running = "$true" if before.get("running") is True else "$false"
    boot._powershell_json(
        f"""
$task=Get-ScheduledTask -TaskName '{PURGE_TASK}' -ErrorAction Stop
$wasEnabled={enabled}; $wasRunning={running}
if($wasEnabled){{Enable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null}}
else{{if([string]$task.State -eq 'Running'){{Stop-ScheduledTask -InputObject $task -ErrorAction Stop}}; Disable-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null}}
if($wasRunning){{Start-ScheduledTask -TaskName '{PURGE_TASK}' -ErrorAction Stop}}
@{{ok=$true}} | ConvertTo-Json -Compress
"""
    )
    after = _task_snapshot()
    if (
        after.get("task_path") != before.get("task_path")
        or after.get("actions") != before.get("actions")
    ):
        raise ExportRefused("purge scheduled-task identity changed during the session")
    if bool(after.get("enabled")) != bool(before.get("enabled")):
        raise ExportRefused("purge task enabled state was not restored exactly")
    if before.get("running") is True and after.get("state") not in {"Running", "Ready"}:
        raise ExportRefused("previously running purge task was not restarted")
    if before.get("enabled") is False and _purge_processes():
        raise ExportRefused("disabled purge task retained an active process after restore")
    return {"before": dict(before), "after": after, "restart_requested": before.get("running") is True}


def _t1_mt5_processes() -> list[dict[str, Any]]:
    value = boot._powershell_json(
        r"""
@(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
  $_.Name -in @('terminal64.exe','metatester64.exe') -and
  ([string]$_.ExecutablePath).Replace('/','\').ToLowerInvariant().StartsWith('d:\qm\mt5\t1\')
} | Select-Object ProcessId,Name,ExecutablePath,CreationDate) | ConvertTo-Json -Depth 4 -Compress
"""
    )
    if value in (None, []):
        return []
    rows = value if isinstance(value, list) else [value]
    if not all(isinstance(row, dict) for row in rows):
        raise ExportRefused("T1 process scan returned malformed data")
    return rows


def _active_t1_rows() -> list[str]:
    with farmctl.connect(FARM_ROOT) as connection:
        rows = connection.execute(
            "SELECT id FROM work_items WHERE status='active' AND claimed_by='T1' ORDER BY id"
        ).fetchall()
    return [str(row[0]) for row in rows]


def _assert_t1_idle(*, expected_reservation: str | None = None) -> dict[str, Any]:
    active_rows = _active_t1_rows()
    processes = _t1_mt5_processes()
    reservation = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    if active_rows or processes:
        raise ExportRefused("T1 has an active work item or MT5 process")
    if expected_reservation is None and reservation is not None:
        raise ExportRefused("T1 already has a conflicting reservation")
    if expected_reservation is not None and (
        reservation is None or reservation.get("reserved_by") != expected_reservation
    ):
        raise ExportRefused("task-bound T1 reservation identity changed")
    workers = reload_idle_workers.workers()
    worker = workers.get(TERMINAL_NAME)
    if worker is None or not reload_idle_workers.idle(
        TERMINAL_NAME,
        worker,
        allow_reservation_owner=expected_reservation,
    ):
        raise ExportRefused("T1 worker is absent, duplicated, or not stably idle")
    worker_identity = _worker_identity(worker)
    return {
        "worker_pid": worker.pid,
        "worker_created": worker_identity["created"],
        "worker_identity": worker_identity,
        "active_rows": active_rows,
        "mt5_processes": processes,
        "reservation": reservation,
    }


def _quiesce_worker(
    reserved_by: str,
    minutes: int,
    out: Path,
    *,
    task_id: str = TASK_ID,
) -> tuple[dict[str, Any], dict[str, str]]:
    before = _assert_t1_idle()
    worker = reload_idle_workers.workers()[TERMINAL_NAME]
    environment = worker.environ()
    before["worker_environment"] = _worker_environment_binding(environment)
    reservation: dict[str, Any] | None = None
    termination_requested = False
    try:
        reservation = farmctl.set_terminal_reservation(
            FARM_ROOT,
            TERMINAL_NAME,
            reserved_by,
            minutes=minutes,
            reason=(
                f"task_{TASK_ID}:Darwinex-native Band A export"
                if task_id == TASK_ID
                else f"task_{task_id}:governed T1 read-only export"
            ),
        )
        stable = _assert_t1_idle(expected_reservation=reserved_by)
        if (stable["worker_pid"], stable["worker_created"]) != (
            before["worker_pid"],
            before["worker_created"],
        ):
            raise ExportRefused("T1 worker lifecycle changed while acquiring the reservation")
        worker.terminate()
        termination_requested = True
        worker.wait(timeout=10)
        if TERMINAL_NAME in reload_idle_workers.workers() or _t1_mt5_processes():
            raise ExportRefused("T1 worker/process did not quiesce")
        return (
            {"before": before, "reservation": reservation, "stopped_pid": worker.pid},
            environment,
        )
    except BaseException as original_error:
        # A failure inside this helper occurs before its state can be returned
        # to run_session, so roll back here rather than leaking a reservation or
        # leaving T1 without its worker.
        if reservation is not None:
            try:
                if termination_requested:
                    try:
                        worker_still_running = worker.is_running()
                    except psutil.NoSuchProcess:
                        worker_still_running = False
                    except psutil.AccessDenied:
                        worker_still_running = True
                    if worker_still_running:
                        raise ExportRefused(
                            "terminated T1 worker exit is unconfirmed; reservation retained"
                        )
                    restored = _restore_worker(
                        environment,
                        reserved_by,
                        before["worker_identity"],
                    )
                    restart_path = Path(out) / "worker_restart_receipt.json"
                    _atomic_write_json(restart_path, restored["restart_receipt"])
                else:
                    _release_exact_reservation(reserved_by)
            except BaseException as cleanup_exc:
                failure = _worker_not_restored_receipt(
                    out=out,
                    reserved_by=reserved_by,
                    attempts=[
                        {
                            "attempt": 1,
                            "at_utc": _utc_now(),
                            "result": "QUIESCE_ROLLBACK_FAILED",
                        }
                    ],
                    error=cleanup_exc,
                )
                raise ExportRefused(
                    "T1 quiesce failed and local rollback failed; "
                    f"receipt={failure['path']}"
                ) from original_error
        raise original_error


def _release_exact_reservation(reserved_by: str) -> dict[str, Any]:
    current = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    if current is None or current.get("reserved_by") != reserved_by:
        raise ExportRefused("refusing to release a changed or absent T1 reservation")
    return farmctl.release_terminal_reservation(FARM_ROOT, TERMINAL_NAME)


def _restore_worker(
    environment: Mapping[str, str],
    reserved_by: str,
    before_identity: Mapping[str, Any],
) -> dict[str, Any]:
    if _active_t1_rows() or _t1_mt5_processes():
        raise ExportRefused("T1 became active before worker restoration")
    current = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    if current is not None and current.get("reserved_by") != reserved_by:
        raise ExportRefused("T1 reservation changed before worker restoration")
    started_at = _utc_now()
    canonical_environment = start_terminal_workers.canonical_worker_environment(
        dict(environment)
    )
    expected_environment = _worker_environment_binding(canonical_environment)
    worker = reload_idle_workers.workers().get(TERMINAL_NAME)
    launcher_exit: int | None = None
    released: dict[str, Any] | None = None
    if worker is None:
        # The governed launcher now correctly skips every live reservation.  We
        # hold FACTORY_MUTATION.lock here, so release our exact reservation only
        # at the restoration boundary, then let whichever governed restarter
        # wins the benign race launch the same canonical environment.
        if current is not None:
            released = _release_exact_reservation(reserved_by)
        env = dict(canonical_environment)
        env.pop("PYTHONHOME", None)
        env.pop("PYTHONPATH", None)
        # REPO_ROOT, not CANONICAL_REPO: apply mode already refuses to run
        # outside C:/QM/repo (validate_canonical_runtime), so production is
        # unchanged, while a worktree or archive extract under test exercises
        # its own launcher instead of the canonical one.
        completed = subprocess.run(
            [
                sys.executable,
                str(RESTORE_LAUNCHER),
                "--dedupe",
            ],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
            creationflags=(subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0),
        )
        launcher_exit = int(completed.returncode)
        time.sleep(5)
        worker = reload_idle_workers.workers().get(TERMINAL_NAME)
        restore_origin = "governed_launcher"
    else:
        if current is not None:
            raise ExportRefused(
                "T1 worker appeared while its lifecycle reservation was live"
            )
        restore_origin = "governed_watchdog_respawn"
    if (
        launcher_exit not in (None, 0)
        or worker is None
        or not reload_idle_workers.idle(TERMINAL_NAME, worker)
    ):
        raise ExportRefused("governed worker launcher/watchdog did not restore idle T1")
    after_identity = _worker_identity(worker)
    after_environment = _process_environment_binding(worker)
    if after_environment != expected_environment:
        raise ExportRefused(
            "restored T1 worker governance environment differs from pre-quiesce worker"
        )
    if (
        after_identity["pid"],
        after_identity["created"],
    ) == (
        before_identity.get("pid"),
        before_identity.get("created"),
    ):
        raise ExportRefused("governed worker launcher did not create a new T1 worker")
    current_after = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    if current_after is not None and current_after.get("reserved_by") != reserved_by:
        raise ExportRefused("T1 reservation changed during worker restoration")
    if current_after is not None:
        released = _release_exact_reservation(reserved_by)
    finished_at = _utc_now()
    restart_receipt = {
        "started_at": started_at,
        "apply": True,
        "worker_sha256": identity_hash.identity_sha256(
            WORKER_SOURCE, kind=identity_hash.TRACKED_TEXT
        ),
        "session_id": after_identity.get("session_id"),
        "reloaded": [
            {
                "terminal": TERMINAL_NAME,
                "old_pid": before_identity.get("pid"),
                "old_created": before_identity.get("created"),
                "old_executable_path": before_identity.get("executable_path"),
                "old_command_line": before_identity.get("command_line"),
                "new_pid": after_identity["pid"],
                "new_created": after_identity["created"],
                "new_executable_path": after_identity["executable_path"],
                "new_command_line": after_identity["command_line"],
                "starter_exit": launcher_exit,
                "restore_origin": restore_origin,
                "environment": after_environment,
                "at_utc": finished_at,
            }
        ],
        "pending": [],
        "finished_at": finished_at,
    }
    return {
        "starter_exit": launcher_exit,
        "restore_origin": restore_origin,
        "new_pid": after_identity["pid"],
        "new_created": after_identity["created"],
        "new_worker_identity": after_identity,
        "worker_environment": after_environment,
        "reservation_state_before_restore": "live" if current is not None else "lapsed",
        "reservation_release": released,
        "restart_receipt": restart_receipt,
    }


def _worker_not_restored_receipt(
    *,
    out: Path,
    reserved_by: str,
    attempts: Sequence[Mapping[str, Any]],
    error: BaseException,
) -> dict[str, Any]:
    current = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    body = {
        "schema": WORKER_NOT_RESTORED_SCHEMA,
        "task_id": TASK_ID,
        "terminal": TERMINAL_NAME,
        "status": "T1_WORKER_NOT_RESTORED",
        "reserved_by": reserved_by,
        "reservation_retained_until_expiry": bool(
            current is not None and current.get("reserved_by") == reserved_by
        ),
        "reservation": current,
        "active_rows": _active_t1_rows(),
        "mt5_processes": _t1_mt5_processes(),
        "worker_present": TERMINAL_NAME in reload_idle_workers.workers(),
        "lock_attempts": [dict(value) for value in attempts],
        "error": f"{type(error).__name__}: {error}",
        "written_at_utc": _utc_now(),
    }
    path = Path(out) / "T1_WORKER_NOT_RESTORED.json"
    _atomic_write_json(path, body)
    return {**body, "path": str(path), "sha256": sha256_file(path)}


def _restore_worker_with_lock(
    *,
    environment: Mapping[str, str],
    reserved_by: str,
    before_identity: Mapping[str, Any],
    out: Path,
    task_id: str = TASK_ID,
    max_wait_seconds: float = RESTORE_LOCK_MAX_WAIT_SECONDS,
    backoff_seconds: float = RESTORE_LOCK_BACKOFF_SECONDS,
) -> dict[str, Any]:
    if max_wait_seconds < 0 or backoff_seconds < 0:
        raise ValueError("restore retry bounds must be non-negative")
    current = farmctl.terminal_reservation(FARM_ROOT, TERMINAL_NAME)
    if current is not None and current.get("reserved_by") != reserved_by:
        error = ExportRefused("T1 reservation changed before restore-lock retry")
        failure = _worker_not_restored_receipt(
            out=out, reserved_by=reserved_by, attempts=[], error=error
        )
        raise ExportRefused(f"{error}; receipt={failure['path']}")
    remaining = _reservation_remaining_seconds(current)
    wait_budget = float(max_wait_seconds)
    if remaining is not None:
        wait_budget = min(wait_budget, max(0.0, remaining - 5.0))
    deadline = time.monotonic() + wait_budget
    attempts: list[dict[str, Any]] = []
    last_error: BaseException = ExportRefused("factory mutation lock was not attempted")
    while True:
        lock = FactoryMutationLock(
            FARM_ROOT / "state/FACTORY_MUTATION.lock",
            owner=f"dwx_2026_band_a_export:{task_id}:restore",
        )
        try:
            lock.__enter__()
        except RuntimeError as exc:
            last_error = exc
            attempts.append(
                {
                    "attempt": len(attempts) + 1,
                    "at_utc": _utc_now(),
                    "result": "LOCK_BUSY",
                    "error": str(exc),
                }
            )
        else:
            attempts.append(
                {
                    "attempt": len(attempts) + 1,
                    "at_utc": _utc_now(),
                    "result": "LOCK_ACQUIRED",
                }
            )
            try:
                restored = _restore_worker(
                    environment, reserved_by, before_identity
                )
            except BaseException as exc:
                last_error = exc
                failure = _worker_not_restored_receipt(
                    out=out,
                    reserved_by=reserved_by,
                    attempts=attempts,
                    error=exc,
                )
                raise ExportRefused(
                    f"T1 worker restore failed; receipt={failure['path']}"
                ) from exc
            finally:
                lock.__exit__(None, None, None)
            restart_path = Path(out) / "worker_restart_receipt.json"
            _atomic_write_json(restart_path, restored["restart_receipt"])
            return {
                **restored,
                "lock_attempts": attempts,
                "restart_receipt_file": _file_binding(restart_path),
            }
        if time.monotonic() >= deadline:
            break
        time.sleep(min(backoff_seconds, max(0.0, deadline - time.monotonic())))
    failure = _worker_not_restored_receipt(
        out=out,
        reserved_by=reserved_by,
        attempts=attempts,
        error=last_error,
    )
    raise ExportRefused(
        f"factory mutation lock remained busy during bounded T1 restore; "
        f"receipt={failure['path']}"
    )


def _manifest_master_snapshot() -> dict[str, Any]:
    activation = custom_history_gate.load_activation(FARM_ROOT)
    if not activation or activation.get("enabled") is not True:
        raise ExportRefused("custom-history activation is absent or disabled")
    manifest_path = Path(str(activation.get("manifest_path") or ""))
    manifest = custom_history_contract.load_manifest(manifest_path, require_owner_approval=True)
    if manifest.get("archive_years") != list(range(2017, 2026)):
        raise ExportRefused("active manifest is not the immutable 2017-2025 v1 baseline")
    master = custom_history_master.load_master_state(FARM_ROOT, manifest=manifest)
    identities: list[dict[str, Any]] = []
    for row in manifest["files"]:
        relative = str(row["relative_path"])
        path = custom_history_master.master_file_path(master["master_root"], relative)
        identity = custom_history_contract.file_identity(path)
        if int(identity["size"]) != int(row["size"]):
            raise ExportRefused(f"v1 master size mismatch: {relative}")
        identities.append(
            {
                "relative_path": relative,
                "size": int(identity["size"]),
                "mtime_ns": int(identity["mtime_ns"]),
                "file_id": str(identity["file_id"]),
                "manifest_sha256": str(row["sha256"]),
            }
        )
    return {
        "activation_sha256": str(activation["activation_sha256"]),
        "manifest": _file_binding(manifest_path),
        "manifest_content_sha256": str(manifest["manifest_sha256"]),
        "t1_signed_archive": governance_guard._signed_archive_snapshot(manifest_path),
        "master_state": _file_binding(custom_history_master.master_state_path(FARM_ROOT)),
        "master_root": str(Path(master["master_root"]).resolve()),
        "master_file_count": len(identities),
        "master_total_bytes": sum(row["size"] for row in identities),
        "master_inventory_sha256": _canonical_sha256(identities),
    }


def _require_tracked_clean_acceptance(path: Path) -> str:
    resolved = Path(path).resolve()
    try:
        resolved.relative_to(TASK_EVIDENCE_ROOT.resolve())
        relative = resolved.relative_to(CANONICAL_REPO.resolve()).as_posix()
    except ValueError as exc:
        raise ExportRefused(
            "headroom acceptance must be under the canonical task evidence directory"
        ) from exc
    _git("ls-files", "--error-unmatch", "--", relative)
    if _git("status", "--porcelain=v1", "--", relative):
        raise ExportRefused("headroom acceptance is not clean in the canonical checkout")
    return relative


def _rehash_calibration_raw_bundle(
    session_receipt_path: Path,
    export_receipt: Mapping[str, Any],
    calibration: Mapping[str, Any],
) -> dict[str, Any]:
    """Re-open every raw file sealed by the calibration session receipt."""

    raw = export_receipt.get("raw")
    if not isinstance(raw, dict):
        raise ExportRefused("calibration session receipt lacks a raw bundle")
    raw_root = (session_receipt_path.parent / "raw").resolve()
    try:
        declared_root = Path(str(raw.get("root") or "")).resolve()
    except OSError as exc:
        raise ExportRefused("calibration raw root is unreadable") from exc
    if declared_root != raw_root or not raw_root.is_dir() or raw_root.is_symlink():
        raise ExportRefused("calibration raw root identity mismatch")
    declared_files = raw.get("files")
    if not isinstance(declared_files, list) or not declared_files:
        raise ExportRefused("calibration raw file list is absent")
    declared_bundle = str(raw.get("bundle_sha256") or "")
    if (
        not SHA256_RE.fullmatch(declared_bundle)
        or _canonical_sha256(declared_files) != declared_bundle
        or calibration.get("raw_bundle_sha256") != declared_bundle
    ):
        raise ExportRefused("calibration raw bundle binding mismatch")

    actual_rows: list[dict[str, Any]] = []
    listed: list[str] = []
    for row in declared_files:
        if not isinstance(row, dict):
            raise ExportRefused("calibration raw file row is malformed")
        relative_text = str(row.get("relative_path") or "")
        relative = PurePosixPath(relative_text)
        if (
            not relative_text
            or relative.is_absolute()
            or "\\" in relative_text
            or ":" in relative_text
            or any(part in {"", ".", ".."} for part in relative.parts)
            or relative.as_posix() != relative_text
        ):
            raise ExportRefused("calibration raw relative path is unsafe")
        actual = raw_root.joinpath(*relative.parts).resolve()
        try:
            actual.relative_to(raw_root)
        except ValueError as exc:
            raise ExportRefused("calibration raw file escapes its session root") from exc
        if not actual.is_file() or actual.is_symlink():
            raise ExportRefused(f"calibration raw file missing: {relative_text}")
        actual_row = {
            "relative_path": relative_text,
            "bytes": actual.stat().st_size,
            "sha256": sha256_file(actual),
        }
        if (
            row.get("relative_path") != actual_row["relative_path"]
            or row.get("bytes") != actual_row["bytes"]
            or row.get("sha256") != actual_row["sha256"]
        ):
            raise ExportRefused(
                f"calibration raw file identity mismatch: {relative_text}"
            )
        listed.append(relative_text)
        actual_rows.append(actual_row)
    if len(listed) != len(set(listed)):
        raise ExportRefused("calibration raw file list contains duplicates")
    discovered = sorted(
        path.relative_to(raw_root).as_posix()
        for path in raw_root.rglob("*")
        if path.is_file()
    )
    if sorted(listed) != discovered:
        raise ExportRefused("calibration raw file set differs from the sealed receipt")
    if _canonical_sha256(actual_rows) != declared_bundle:
        raise ExportRefused("calibration raw bundle re-hash mismatch")
    return {
        "root": str(raw_root),
        "files": actual_rows,
        "bundle_sha256": declared_bundle,
    }


def validate_headroom_acceptance(
    path: Path,
    *,
    symbols: Sequence[str],
    wrapper_sha256: str,
    source_sha256: str,
    terminal_sha256: str,
) -> dict[str, Any]:
    tracked_relative = _require_tracked_clean_acceptance(path)
    value = _load_json(path)
    required = {
        "schema": HEADROOM_ACCEPTANCE_SCHEMA,
        "task_id": TASK_ID,
        "accepted_by": "Fable",
        "accepted_for_band_a": True,
        "wrapper_sha256": wrapper_sha256,
        "source_sha256": source_sha256,
        "terminal_sha256": terminal_sha256,
    }
    if any(value.get(key) != expected for key, expected in required.items()):
        raise ExportRefused("headroom acceptance identity/binding mismatch")
    calibration = value.get("calibration")
    if not isinstance(calibration, dict) or calibration.get("schema") != CALIBRATION_SCHEMA:
        raise ExportRefused("accepted headroom receipt lacks a calibration binding")
    session_receipt_path = Path(str(calibration.get("session_receipt_path") or "")).resolve()
    try:
        relative_session = session_receipt_path.relative_to(ARTIFACT_ROOT.resolve())
    except ValueError as exc:
        raise ExportRefused(
            "calibration session receipt is outside the task source root"
        ) from exc
    if (
        len(relative_session.parts) != 2
        or relative_session.parts[1] != "session_receipt.json"
    ):
        raise ExportRefused(
            "calibration session receipt must be a direct task-source session child"
        )
    calibration_path = session_receipt_path.parent / "headroom_calibration.json"
    actual_calibration = _load_json(calibration_path)
    declared_calibration_sha256 = actual_calibration.get("calibration_sha256")
    unsigned_calibration = dict(actual_calibration)
    unsigned_calibration.pop("calibration_sha256", None)
    if (
        not isinstance(declared_calibration_sha256, str)
        or not SHA256_RE.fullmatch(declared_calibration_sha256)
        or _canonical_sha256(unsigned_calibration) != declared_calibration_sha256
    ):
        raise ExportRefused("headroom calibration self-hash is invalid")
    if calibration != actual_calibration:
        raise ExportRefused("embedded calibration differs from the task-source file")
    if value.get("calibration_sha256") != declared_calibration_sha256:
        raise ExportRefused("headroom acceptance calibration_sha256 mismatch")
    calibration_file_sha256 = sha256_file(calibration_path)
    if value.get("calibration_file_sha256") != calibration_file_sha256:
        raise ExportRefused("headroom acceptance calibration file sha256 mismatch")
    session_receipt_sha256 = sha256_file(session_receipt_path)
    if value.get("session_receipt_sha256") != session_receipt_sha256:
        raise ExportRefused("headroom acceptance session receipt sha256 mismatch")
    session_receipt = _load_json(session_receipt_path)
    export_receipt = session_receipt.get("export")
    if (
        session_receipt.get("status") != "CALIBRATION_REVIEW_REQUIRED"
        or session_receipt.get("v1_manifest_master_unchanged") is not True
        or session_receipt.get("cleanup_errors")
        or not isinstance(export_receipt, dict)
        or export_receipt.get("error")
        or export_receipt.get("cleanup_errors")
        or session_receipt.get("headroom_calibration") != actual_calibration
    ):
        raise ExportRefused("calibration session receipt is not clean and reviewable")
    raw_bundle = _rehash_calibration_raw_bundle(
        session_receipt_path,
        export_receipt,
        actual_calibration,
    )
    calibrated_symbols = tuple(calibration.get("symbols") or [])
    if calibrated_symbols != ("XAUUSD",):
        raise ExportRefused("headroom calibration must be the reviewed XAUUSD first session")
    if (
        calibration.get("wrapper_sha256") != wrapper_sha256
        or calibration.get("source_sha256") != source_sha256
        or calibration.get("terminal_sha256") != terminal_sha256
    ):
        raise ExportRefused("headroom calibration executable binding mismatch")
    try:
        headroom = float(calibration["measured_export_headroom_gib"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ExportRefused("measured export headroom is absent") from exc
    if not math.isfinite(headroom) or headroom <= 0.0:
        raise ExportRefused("measured export headroom must be positive and finite")
    try:
        admission_gib = float(value["admission_gib"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ExportRefused("headroom acceptance admission_gib is absent") from exc
    if not math.isfinite(admission_gib) or admission_gib < MIN_FREE_GIB:
        raise ExportRefused(
            "headroom acceptance admission_gib must be finite and at least 14.0 GiB"
        )
    accepted_symbols = tuple(value.get("allowed_symbols") or BAND_A)
    if any(symbol not in accepted_symbols for symbol in validate_symbols(symbols)):
        raise ExportRefused("headroom acceptance does not cover this symbol batch")
    return {
        "path": str(Path(path).resolve()),
        "tracked_relative_path": tracked_relative,
        "sha256": sha256_file(path),
        "headroom_gib": headroom,
        "admission_gib": admission_gib,
        "calibration_file": _file_binding(calibration_path),
        "session_receipt": _file_binding(session_receipt_path),
        "raw_bundle": raw_bundle,
        "body": value,
    }


def _required_free_gib(accepted_headroom: Mapping[str, object]) -> float:
    """Apply both the calibrated margin and Fable's explicit admission floor."""

    return max(
        float(accepted_headroom["admission_gib"]),
        MIN_FREE_GIB + float(accepted_headroom["headroom_gib"]),
    )


def _free_gib() -> float:
    return psutil.virtual_memory().available / (1024**3)


def _private_bytes_gib(pid: int) -> float:
    try:
        root = psutil.Process(int(pid))
        processes = [root, *root.children(recursive=True)]
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return 0.0
    total = 0
    for process in processes:
        try:
            memory = process.memory_info()
            total += int(getattr(memory, "private", memory.rss))
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return total / (1024**3)


def _copy_and_bind_raw(raw_terminal_dir: Path, out: Path) -> dict[str, Any]:
    destination = out / "raw"
    if destination.exists():
        raise ExportRefused("task raw output destination already exists")
    shutil.copytree(raw_terminal_dir, destination)
    files = []
    for path in sorted(value for value in destination.rglob("*") if value.is_file()):
        files.append(
            {
                "relative_path": path.relative_to(destination).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    if not files:
        raise ExportRefused("export produced no raw files")
    return {"root": str(destination), "files": files, "bundle_sha256": _canonical_sha256(files)}


def _startup_ini_text(
    *,
    login: object,
    server: str,
    script: str,
    preset_name: str,
    symbol: str,
    max_bars: int | None,
) -> str:
    """Build the credential-bearing session startup.ini (deleted in finally).

    ``max_bars`` adds a session-scoped ``[Charts] MaxBars`` override; the only
    accepted value is SESSION_MAX_BARS.  None keeps T1's persisted setting.
    """

    lines = ["[Common]", f"Login={login}", f"Server={server}"]
    if max_bars is not None:
        if int(max_bars) != SESSION_MAX_BARS:
            raise ExportRefused(
                f"session MaxBars override must be exactly {SESSION_MAX_BARS}"
            )
        lines.extend(["[Charts]", f"MaxBars={SESSION_MAX_BARS}"])
    lines.extend(
        [
            "[Experts]",
            "Enabled=0",
            "AllowLiveTrading=0",
            "AllowDllImport=0",
            "[StartUp]",
            f"Script={script}",
            f"ScriptParameters={preset_name}",
            f"Symbol={symbol}",
            "Period=M1",
            "ShutdownTerminal=0",
            "",
        ]
    )
    return "\n".join(lines)


def _decode_ini(raw: bytes) -> str:
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16", errors="replace")
    if len(raw) >= 2 and raw[1:2] == b"\x00":
        return raw.decode("utf-16-le", errors="replace")
    return raw.decode("utf-8-sig", errors="replace")


def _ini_max_bars(raw: bytes | None) -> int | None:
    """Return ``[Charts] MaxBars`` (None if absent, -1 if malformed)."""

    if raw is None:
        return None
    section = ""
    for line in _decode_ini(raw).splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1].strip().casefold()
            continue
        if section == "charts" and "=" in stripped:
            key, value = stripped.split("=", 1)
            if key.strip().casefold() == "maxbars":
                try:
                    return int(value.strip())
                except ValueError:
                    return -1
    return None


def _ini_has_max_bars_key(raw: bytes | None) -> bool:
    if raw is None:
        return False
    return any(
        "=" in line and line.split("=", 1)[0].strip().casefold() == "maxbars"
        for line in _decode_ini(raw).splitlines()
    )


def _bytes_sha256(raw: bytes | None) -> str | None:
    return None if raw is None else hashlib.sha256(raw).hexdigest()


def _read_optional_bytes(path: Path) -> bytes | None:
    return Path(path).read_bytes() if Path(path).is_file() else None


def _atomic_write_bytes(path: Path, raw: bytes) -> None:
    target = Path(path)
    temporary = target.with_name(f".{target.name}.qm_restore.tmp")
    temporary.write_bytes(raw)
    os.replace(temporary, target)


def _snapshot_terminal_config(session_tag: str) -> tuple[dict[str, Any], dict[str, bytes | None]]:
    """Snapshot T1 common.ini (strict restore) and terminal.ini (observe).

    Receipts carry hashes, sizes and the MaxBars integer only; common.ini holds
    Login/Server/Environment and its bytes never leave T1's Config directory.
    The on-disk backup sits beside the original and is removed after a
    verified restore.
    """

    config_dir = TERMINAL_ROOT / TERMINAL_CONFIG_DIR_NAME
    backups: dict[str, bytes | None] = {}
    files: dict[str, dict[str, Any]] = {}
    for name in ("common.ini", "terminal.ini"):
        raw = _read_optional_bytes(config_dir / name)
        backups[name] = raw
        files[name] = {
            "exists": raw is not None,
            "bytes": None if raw is None else len(raw),
            "sha256": _bytes_sha256(raw),
            "max_bars": _ini_max_bars(raw),
            "has_max_bars_key": _ini_has_max_bars_key(raw),
        }
    backup_path: Path | None = None
    if backups["common.ini"] is not None:
        backup_path = config_dir / f"common.ini.qm_band_a_{session_tag}.bak"
        if backup_path.exists():
            raise ExportRefused("common.ini session backup path already exists")
        backup_path.write_bytes(backups["common.ini"])
        if sha256_file(backup_path) != files["common.ini"]["sha256"]:
            raise ExportRefused("common.ini session backup did not verify")
    return (
        {
            "config_dir": str(config_dir),
            "files": files,
            "common_backup_path": None if backup_path is None else str(backup_path),
            "captured_at_utc": _utc_now(),
        },
        backups,
    )


def _config_not_restored_receipt(out: Path, body: Mapping[str, Any]) -> dict[str, Any]:
    path = out / "T1_CONFIG_NOT_RESTORED.json"
    value = {
        "schema": CONFIG_NOT_RESTORED_SCHEMA,
        "task_id": TASK_ID,
        "status": "T1_CONFIG_NOT_RESTORED",
        "written_at_utc": _utc_now(),
        **dict(body),
    }
    _atomic_write_json(path, value)
    return {"path": str(path), "sha256": sha256_file(path)}


def _restore_terminal_config(
    before: Mapping[str, Any],
    backups: Mapping[str, bytes | None],
    out: Path,
    *,
    terminal_terminated: bool,
) -> dict[str, Any]:
    """Restore + verify T1 common.ini; observe terminal.ini.

    Runs only after the owned terminal is confirmed gone (MT5 may persist
    start-config values on exit).  A failed verification writes
    T1_CONFIG_NOT_RESTORED.json, keeps the on-disk backup and raises, which
    fails the session closed while the worker/purge restore still run.
    """

    config_dir = Path(str(before["config_dir"]))
    files_before = before["files"]
    result: dict[str, Any] = {"files": {}, "verified": False}
    if not terminal_terminated or _t1_mt5_processes():
        receipt = _config_not_restored_receipt(
            out,
            {
                "reason": "owned T1 terminal not confirmed terminated; restore deferred",
                "common_backup_path": before.get("common_backup_path"),
                "expected_common_sha256": files_before["common.ini"]["sha256"],
                "expected_max_bars": files_before["common.ini"]["max_bars"],
            },
        )
        raise ExportRefused(f"T1 config restore deferred; receipt={receipt['path']}")

    common_path = config_dir / "common.ini"
    expected_sha = files_before["common.ini"]["sha256"]
    expected_max_bars = files_before["common.ini"]["max_bars"]
    current = _read_optional_bytes(common_path)
    observed_sha = _bytes_sha256(current)
    action = "unchanged"
    if observed_sha != expected_sha:
        prior = backups.get("common.ini")
        if prior is None:
            common_path.unlink(missing_ok=True)
            action = "removed_session_created_file"
        else:
            _atomic_write_bytes(common_path, prior)
            action = "rewritten_from_snapshot"
    final = _read_optional_bytes(common_path)
    common_verified = (
        _bytes_sha256(final) == expected_sha and _ini_max_bars(final) == expected_max_bars
    )
    result["files"]["common.ini"] = {
        "observed_after_session_sha256": observed_sha,
        "observed_after_session_max_bars": _ini_max_bars(current),
        "changed_by_session": observed_sha != expected_sha,
        "action": action,
        "final_sha256": _bytes_sha256(final),
        "final_max_bars": _ini_max_bars(final),
        "verified": common_verified,
    }

    terminal_path = config_dir / "terminal.ini"
    terminal_before = files_before["terminal.ini"]
    terminal_now = _read_optional_bytes(terminal_path)
    terminal_action = "observed_only"
    introduced = _ini_has_max_bars_key(terminal_now) and not terminal_before["has_max_bars_key"]
    if introduced:
        prior = backups.get("terminal.ini")
        if prior is None:
            terminal_path.unlink(missing_ok=True)
        else:
            _atomic_write_bytes(terminal_path, prior)
        terminal_action = "restored_max_bars_key_introduced"
    terminal_final = _read_optional_bytes(terminal_path)
    terminal_verified = _ini_has_max_bars_key(terminal_final) == bool(
        terminal_before["has_max_bars_key"]
    )
    result["files"]["terminal.ini"] = {
        "observed_after_session_sha256": _bytes_sha256(terminal_now),
        "changed_by_session": _bytes_sha256(terminal_now) != terminal_before["sha256"],
        "max_bars_key_introduced": introduced,
        "action": terminal_action,
        "final_sha256": _bytes_sha256(terminal_final),
        "verified": terminal_verified,
    }

    if not (common_verified and terminal_verified):
        receipt = _config_not_restored_receipt(
            out,
            {
                "reason": "post-session T1 config verification failed",
                "common_backup_path": before.get("common_backup_path"),
                "expected_common_sha256": expected_sha,
                "expected_max_bars": expected_max_bars,
                "restore": result,
            },
        )
        raise ExportRefused(f"T1 config restore not verified; receipt={receipt['path']}")

    backup_path = before.get("common_backup_path")
    if backup_path:
        Path(str(backup_path)).unlink(missing_ok=True)
        if Path(str(backup_path)).exists():
            raise ExportRefused("verified common.ini backup could not be removed")
    result["backup_removed"] = bool(backup_path)
    result["verified"] = True
    result["verified_at_utc"] = _utc_now()
    return result


def _broker_wall_iso(epoch: int) -> str | None:
    if not epoch or epoch <= 0:
        return None
    return (
        dt.datetime.fromtimestamp(int(epoch), tz=dt.UTC)
        .replace(tzinfo=None)
        .isoformat(timespec="seconds")
        + " broker"
    )


def _parse_history_depth_csv(
    path: Path,
    *,
    symbols: Sequence[str],
    window_from_broker: int,
    window_to_broker: int,
) -> list[dict[str, Any]]:
    """Runtime half of the probe no-price guard.

    The header must match exactly; every non-enum cell must be an integer.  A
    decimal point anywhere (the shape of a price) refuses the whole output.
    """

    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows or rows[0] != HISTORY_DEPTH_HEADER:
        raise ExportRefused(f"history-depth CSV schema mismatch: {path}")
    parsed: list[dict[str, Any]] = []
    for line in rows[1:]:
        if not line:
            continue
        if len(line) != len(HISTORY_DEPTH_HEADER):
            raise ExportRefused("history-depth CSV row width mismatch")
        row: dict[str, Any] = {}
        for field, value in zip(HISTORY_DEPTH_HEADER, line):
            if field in HISTORY_DEPTH_TEXT_FIELDS:
                row[field] = value
                continue
            if not re.fullmatch(r"-?\d{1,19}", value):
                raise ExportRefused(
                    "history-depth output cell is not an integer "
                    f"(no-price guard): field={field}"
                )
            row[field] = int(value)
        if row["symbol"] not in BAND_A:
            raise ExportRefused("history-depth row carries a non-Band-A symbol")
        if row["phase"] not in HISTORY_DEPTH_PHASES:
            raise ExportRefused("history-depth row carries an unknown phase")
        if row["status"] not in HISTORY_DEPTH_STATUSES or row["reason"] not in HISTORY_DEPTH_REASONS:
            raise ExportRefused("history-depth row carries an unknown status/reason")
        if (
            row["window_from_broker_epoch"] != int(window_from_broker)
            or row["window_to_broker_epoch_exclusive"] != int(window_to_broker)
        ):
            raise ExportRefused("history-depth row window differs from the session window")
        parsed.append(row)
    expected = [(symbol, phase) for symbol in symbols for phase in HISTORY_DEPTH_PHASES]
    if [(row["symbol"], row["phase"]) for row in parsed] != expected:
        raise ExportRefused("history-depth CSV rows do not match symbols x phases")
    return parsed


def _classify_probe_symbol(
    after: Mapping[str, Any],
    *,
    window_from_broker: int,
    requested_max_bars: int | None,
) -> str:
    """Deterministic M1/M2 classification for Fable's adjudication.

    SERIES_SERVER_FIRSTDATE is timeframe-agnostic, so a server first date at or
    before the window start does not prove M1 depth; only a later one proves
    the server lacks the window (M2).
    """

    server_first = int(after["server_firstdate_broker_epoch"])
    if server_first > int(window_from_broker):
        return "M2_SERVER_DEPTH_SHORT"
    covered = (
        after["status"] == "OK"
        and int(after["synchronized"]) == 1
        and 0 < int(after["series_firstdate_broker_epoch"]) <= int(window_from_broker)
        and int(after["bars_in_window"]) > 0
    )
    if covered:
        if requested_max_bars is not None and int(after["terminal_maxbars"]) == int(
            requested_max_bars
        ):
            return "DEPTH_OK_WITH_RAISED_MAXBARS"
        return "DEPTH_OK_AT_CURRENT_MAXBARS"
    if after["reason"] == "MAXBARS_REACHED" or (
        int(after["terminal_maxbars"]) > 0
        and int(after["series_bars_count"]) >= int(after["terminal_maxbars"])
    ):
        return "M1_LOCAL_MAXBARS_LIMIT"
    return "UNRESOLVED"


PROBE_MARKER_RE = re.compile(
    r"^probed=(\d+) covered=(\d+) write_failures=(\d+) terminal=T1 "
    r"server=Darwinex-Live build=(\d+) terminal_maxbars=(-?\d+)$"
)


def _build_probe_receipt(
    *,
    out: Path,
    session_tag: str,
    symbols: Sequence[str],
    cutoff: dt.datetime,
    export: Mapping[str, Any],
    requested_max_bars: int | None,
) -> dict[str, Any]:
    raw = export.get("raw") or {}
    files = raw.get("files") or []
    if [row.get("relative_path") for row in files] != [PROBE_CSV_NAME]:
        raise ExportRefused("probe raw output must be exactly probe.csv")
    probe_path = Path(str(raw["root"])) / PROBE_CSV_NAME
    if sha256_file(probe_path) != files[0].get("sha256"):
        raise ExportRefused("probe.csv changed after hash binding")
    marker_lines = str(export.get("completion") or "").splitlines()
    match = PROBE_MARKER_RE.fullmatch(marker_lines[0].strip()) if marker_lines else None
    if match is None or len([line for line in marker_lines if line.strip()]) != 1:
        raise ExportRefused("probe completion marker did not authenticate")
    window_from = dukascopy_common.broker_epoch_seconds_for_utc(START_UTC)
    window_to = dukascopy_common.broker_epoch_seconds_for_utc(cutoff)
    rows = _parse_history_depth_csv(
        probe_path,
        symbols=symbols,
        window_from_broker=window_from,
        window_to_broker=window_to,
    )
    if int(match.group(1)) != len(symbols) or int(match.group(3)) != 0:
        raise ExportRefused("probe completion marker symbol/write count mismatch")
    per_symbol: dict[str, Any] = {}
    for symbol in symbols:
        before = next(r for r in rows if r["symbol"] == symbol and r["phase"] == "BEFORE_WARMUP")
        after = next(r for r in rows if r["symbol"] == symbol and r["phase"] == "AFTER_WARMUP")
        per_symbol[symbol] = {
            "before_warmup": before,
            "after_warmup": after,
            "after_warmup_dates_broker_wall": {
                key: _broker_wall_iso(int(after[f"{key}_broker_epoch"]))
                for key in ("server_firstdate", "terminal_firstdate", "series_firstdate")
            },
            "classification": _classify_probe_symbol(
                after,
                window_from_broker=window_from,
                requested_max_bars=requested_max_bars,
            ),
        }
    classifications = [value["classification"] for value in per_symbol.values()]
    maxbars_readback = sorted(
        {int(value["after_warmup"]["terminal_maxbars"]) for value in per_symbol.values()}
    )
    honoured = (
        None
        if requested_max_bars is None
        else maxbars_readback == [int(requested_max_bars)]
    )
    if any(value == "M2_SERVER_DEPTH_SHORT" for value in classifications):
        gate = "STOP_M2_SPEC_DECISION"
    elif (
        requested_max_bars is not None
        and honoured
        and all(value == "DEPTH_OK_WITH_RAISED_MAXBARS" for value in classifications)
    ):
        gate = "PROCEED_M1_CONFIRMED"
    elif requested_max_bars is None:
        gate = "RUN_VARIANT_B_RAISED_MAXBARS"
    else:
        gate = "HOLD_UNRESOLVED_FABLE_REVIEW"
    body = {
        "schema": PROBE_SCHEMA,
        "task_id": TASK_ID,
        "session_tag": session_tag,
        "variant": (
            "A_CURRENT_MAXBARS" if requested_max_bars is None else "B_RAISED_MAXBARS"
        ),
        "requested_session_max_bars": requested_max_bars,
        "terminal_maxbars_readback": maxbars_readback,
        "maxbars_override_honoured": honoured,
        "symbols": list(symbols),
        "window_start_utc": START_UTC.isoformat().replace("+00:00", "Z"),
        "window_start_broker_epoch": window_from,
        "cutoff_utc": cutoff.isoformat().replace("+00:00", "Z"),
        "cutoff_broker_epoch_exclusive": window_to,
        "warmup_seconds_per_symbol": WARMUP_SECONDS,
        "marker": {
            "probed": int(match.group(1)),
            "covered": int(match.group(2)),
            "write_failures": int(match.group(3)),
            "build": int(match.group(4)),
            "terminal_maxbars": int(match.group(5)),
        },
        "probe_csv": {
            "path": str(probe_path),
            "bytes": files[0].get("bytes"),
            "sha256": files[0].get("sha256"),
        },
        "per_symbol": per_symbol,
        "rerun_gate": gate,
        "no_price_output": True,
        "created_at_utc": _utc_now(),
    }
    body["receipt_sha256"] = _canonical_sha256(body)
    _atomic_write_json(out / "history_depth_probe.json", body)
    return body


def _completion_rows(completion: object) -> list[dict[str, str]]:
    lines = [line for line in str(completion or "").splitlines() if line.strip()]
    if len(lines) < 2:
        return []
    header = [value.strip() for value in lines[1].split(",")]
    return [
        dict(zip(header, (value.strip() for value in line.split(","))))
        for line in lines[2:]
    ]


def _history_depth_short(completion: object) -> list[dict[str, Any]]:
    """Per-symbol HISTORY_DEPTH_SHORT facts from the completion marker.

    Timestamps (broker epoch) and counts only.
    """

    short: list[dict[str, Any]] = []
    for row in _completion_rows(completion):
        if row.get("status") != "HISTORY_DEPTH_SHORT":
            continue

        def _int(key: str) -> int | None:
            value = row.get(key)
            return int(value) if value is not None and re.fullmatch(r"-?\d+", value) else None

        series_first = _int("series_firstdate_broker_epoch") or 0
        short.append(
            {
                "symbol": row.get("symbol"),
                "history_reason": row.get("history_reason"),
                "terminal_maxbars": _int("terminal_maxbars"),
                "server_firstdate_broker_epoch": _int("server_firstdate_broker_epoch"),
                "terminal_firstdate_broker_epoch": _int("terminal_firstdate_broker_epoch"),
                "series_firstdate_broker_epoch": series_first,
                "first_available_broker_wall": _broker_wall_iso(series_first),
                "series_synchronized": _int("series_synchronized"),
                "bars_in_window": _int("bars_in_window"),
            }
        )
    return short


class HistoryDepthShort(ExportRefused):
    """The terminal's M1 series does not reach the window start."""


class TickGap(ExportRefused):
    """An empty tick chunk could not be proven to be a closed market."""


def _read_int_csv(
    path: Path, header: Sequence[str], text_fields: set[str], label: str
) -> list[dict[str, Any]]:
    """Strict CSV reader for counts/timestamps/enums (no price column exists)."""

    try:
        with Path(path).open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != list(header):
                raise ExportRefused(f"{label} schema mismatch")
            rows: list[dict[str, Any]] = []
            for raw_row in reader:
                if None in raw_row or any(value is None for value in raw_row.values()):
                    raise ExportRefused(f"{label} row has the wrong column count")
                row: dict[str, Any] = {}
                for key, value in raw_row.items():
                    value = str(value).strip()
                    if key in text_fields:
                        row[key] = value
                    elif re.fullmatch(r"-?\d{1,19}", value):
                        row[key] = int(value)
                    else:
                        raise ExportRefused(f"{label} non-integer cell in {key}")
                rows.append(row)
    except OSError as exc:
        raise ExportRefused(f"cannot read {label}: {exc}") from exc
    return rows


def _verify_tick_zero_chunks(
    *,
    export: Mapping[str, Any],
    symbols: Sequence[str],
    start_broker: int,
    cutoff_broker: int,
) -> dict[str, Any]:
    """Re-verify the tick-leg empty-chunk classification after the export.

    Reads only the chunk journal and the ``.tick_zero_chunks.csv`` sidecar
    (counts, timestamps, error codes and enums; neither file has a price
    column), both re-hashed against the raw binding first.  Fails closed on
    any inconsistency between journal, sidecar and completion marker.
    """

    raw = export.get("raw") or {}
    root = raw.get("root")
    if not root:
        raise ExportRefused("tick chunk verification: no raw binding")
    bindings = {
        str(item.get("relative_path")): item for item in raw.get("files") or []
    }
    marker_rows = {
        row.get("symbol"): row for row in _completion_rows(export.get("completion"))
    }
    window_from_msc = int(start_broker) * 1000
    window_to_msc = int(cutoff_broker) * 1000
    per_symbol: dict[str, Any] = {}
    for symbol in symbols:
        stem = f"{symbol}.DWX"
        files: dict[str, Path] = {}
        for kind, relative in (
            ("journal", f"{stem}.chunks.csv"),
            ("zero", f"{stem}.tick_zero_chunks.csv"),
        ):
            binding = bindings.get(relative)
            if binding is None:
                raise ExportRefused(f"tick chunk verification: {relative} not bound")
            path = Path(root) / relative
            if not path.is_file() or sha256_file(path) != binding.get("sha256"):
                raise ExportRefused(
                    f"tick chunk verification: {relative} differs from its binding"
                )
            files[kind] = path
        journal = [
            row
            for row in _read_int_csv(
                files["journal"],
                CHUNK_JOURNAL_HEADER,
                {"symbol", "stream", "status"},
                f"{stem} chunk journal",
            )
            if row["stream"] == "TICKS"
        ]
        zero_rows = _read_int_csv(
            files["zero"],
            TICK_ZERO_HEADER,
            {"symbol", "classification"},
            f"{stem} tick zero sidecar",
        )
        sidecar: dict[tuple[int, int], dict[str, Any]] = {}
        for row in zero_rows:
            key = (row["from_msc"], row["to_msc_exclusive"])
            if row["symbol"] != symbol or key in sidecar:
                raise ExportRefused(
                    f"tick chunk verification: {stem} sidecar symbol/duplicate row"
                )
            sidecar[key] = row
        closed = 0
        gaps: list[dict[str, Any]] = []
        journal_zero_keys: set[tuple[int, int]] = set()
        for row in journal:
            if row["symbol"] != symbol or row["status"] not in TICK_JOURNAL_STATUSES:
                raise ExportRefused(
                    f"tick chunk verification: {stem} unexpected journal status "
                    f"{row['status']!r}"
                )
            if row["status"] not in {"ZERO_CLOSED", "ZERO_GAP"}:
                continue
            key = (row["from"], row["to_exclusive"])
            journal_zero_keys.add(key)
            zero = sidecar.get(key)
            if zero is None or (zero["attempts"], zero["copied"], zero["error"]) != (
                row["attempts"],
                row["copied"],
                row["error"],
            ):
                raise ExportRefused(
                    f"tick chunk verification: {stem} journal/sidecar mismatch at {key}"
                )
            classification = zero["classification"]
            if row["copied"] != 0:
                raise ExportRefused(f"tick chunk verification: {stem} non-empty zero row")
            if row["status"] == "ZERO_CLOSED":
                inside = window_from_msc <= key[0] and key[1] <= window_to_msc
                if (
                    classification != TICK_ZERO_CLOSED
                    or zero["bars_in_window"] != 0
                    or row["attempts"] != 1
                    or row["error"] in RETRYABLE_HISTORY_ERRORS
                    or not inside
                ):
                    raise ExportRefused(
                        f"tick chunk verification: {stem} closed-session claim "
                        f"not proven at {key}"
                    )
                closed += 1
                continue
            # ZERO_GAP: must have run the full backoff and carry a consistent class.
            consistent = (
                (classification == "OPEN_MARKET_GAP" and zero["bars_in_window"] > 0)
                or (classification == "UNPROVEN_WINDOW" and zero["bars_in_window"] == -1)
                or (
                    classification == "HISTORY_ERROR"
                    and zero["bars_in_window"] == 0
                    and row["error"] in RETRYABLE_HISTORY_ERRORS
                )
            )
            if not consistent or row["attempts"] != EXPORT_COPY_ATTEMPTS:
                raise ExportRefused(
                    f"tick chunk verification: {stem} gap row inconsistent at {key}"
                )
            gaps.append(
                {
                    "from_msc": key[0],
                    "to_msc_exclusive": key[1],
                    "from_broker_wall": _broker_wall_iso(key[0] // 1000),
                    "classification": classification,
                    "bars_in_window": zero["bars_in_window"],
                    "attempts": row["attempts"],
                    "error": row["error"],
                }
            )
        if journal_zero_keys != set(sidecar):
            raise ExportRefused(
                f"tick chunk verification: {stem} sidecar rows differ from journal zero rows"
            )
        marker = marker_rows.get(symbol) or {}

        def _marker_int(key: str) -> int:
            value = str(marker.get(key, ""))
            if not re.fullmatch(r"\d{1,19}", value):
                raise ExportRefused(
                    f"tick chunk verification: {symbol} completion marker lacks {key}"
                )
            return int(value)

        counters = {
            "zero_tick_chunks": _marker_int("zero_tick_chunks"),
            "zero_tick_closed_session_chunks": _marker_int(
                "zero_tick_closed_session_chunks"
            ),
            "zero_tick_gap_chunks": _marker_int("zero_tick_gap_chunks"),
            "retry_tick_chunks": _marker_int("retry_tick_chunks"),
        }
        retried = sum(
            1 for row in journal if row["status"] != "CEILING" and row["attempts"] > 1
        )
        if (
            counters["zero_tick_chunks"] != len(journal_zero_keys)
            or counters["zero_tick_closed_session_chunks"] != closed
            or counters["zero_tick_gap_chunks"] != len(gaps)
            or counters["retry_tick_chunks"] != retried
            or (marker.get("status") == "SUCCESS" and gaps)
            or (marker.get("status") == "TICK_GAP" and not gaps)
        ):
            raise ExportRefused(
                f"tick chunk verification: {symbol} marker counters differ from journal"
            )
        per_symbol[symbol] = {
            "marker_status": marker.get("status"),
            "tick_chunks_journalled": len(journal),
            **counters,
            "gaps": gaps,
        }
    return {"verified": True, "symbols": per_symbol}


def _execute_export(
    *,
    out: Path,
    session_tag: str,
    symbols: Sequence[str],
    cutoff: dt.datetime,
    timeout_seconds: int,
    reserved_by: str,
    reservation_until_utc: str,
    mode: str = "export",
    max_bars: int | None = SESSION_MAX_BARS,
    task_id: str = TASK_ID,
    script_source_override: Path | None = None,
    source_binding_override: Mapping[str, Any] | None = None,
    staging_family_override: str | None = None,
    preset_lines_override: Sequence[str] | None = None,
    marker_name_override: str | None = None,
    preset_name_override: str | None = None,
) -> dict[str, Any]:
    if mode not in {"export", "probe", "bar_reference"}:
        raise ExportRefused(f"unknown terminal script mode: {mode}")
    probe = mode == "probe"
    script_source = Path(
        script_source_override or (PROBE_SOURCE if probe else SOURCE)
    )
    source_binding = dict(
        source_binding_override
        or (validate_probe_source() if probe else validate_mql_source())
    )
    staging_family = staging_family_override or (
        "dwx_2026_band_a_probe" if probe else "dwx_2026_band_a"
    )
    if _t1_mt5_processes():
        raise ExportRefused("T1 ceased being process-idle before exporter staging")
    if any(
        boot._windows_path_key(row.get("ExecutablePath", ""))
        == boot._windows_path_key(METAEDITOR_BINARY)
        for row in boot.scan_metaeditor_processes()
    ):
        raise ExportRefused("T1 MetaEditor is already active")
    staged = (
        TERMINAL_ROOT / "MQL5/Scripts/QM" / staging_family / session_tag / script_source.name
    )
    if staged.exists() or staged.with_suffix(".ex5").exists():
        raise ExportRefused("immutable exporter staging path already exists")
    staged.parent.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(script_source, staged)
    compile_log = out / "compile.log"
    compiled = subprocess.run(
        [str(METAEDITOR_BINARY), f"/compile:{staged}", f"/log:{compile_log}"],
        cwd=TERMINAL_ROOT,
        capture_output=True,
        timeout=180,
        creationflags=subprocess.CREATE_NO_WINDOW,
        check=False,
    )
    counts = re.findall(r"(\d+) errors?, (\d+) warnings?", boot._read_text_auto(compile_log))
    ex5 = staged.with_suffix(".ex5")
    if compiled.returncode not in (0, 1) or not counts or counts[-1] != ("0", "0") or not ex5.is_file():
        raise ExportRefused("Band A exporter compile did not pass 0 errors / 0 warnings")
    compiled_dir = out / "compiled"
    compiled_dir.mkdir()
    shutil.copyfile(staged, compiled_dir / staged.name)
    shutil.copyfile(ex5, compiled_dir / ex5.name)

    output_rel = f"QM\\{staging_family}\\{session_tag}"
    raw_terminal_dir = TERMINAL_ROOT / "MQL5/Files/QM" / staging_family / session_tag
    marker_name = marker_name_override or (
        f"QM_DWX_2026_BAND_A_PROBE_COMPLETE_{session_tag}.txt"
        if probe
        else f"QM_DWX_2026_BAND_A_COMPLETE_{session_tag}.txt"
    )
    marker = TERMINAL_ROOT / "MQL5/Files" / marker_name
    preset = TERMINAL_ROOT / "MQL5/Presets" / (preset_name_override or (
        f"QM_DWX_2026_BAND_A_PROBE_{session_tag}.set"
        if probe
        else f"QM_DWX_2026_BAND_A_{session_tag}.set"
    ))
    if raw_terminal_dir.exists() or marker.exists() or preset.exists():
        raise ExportRefused("immutable terminal output/preset path already exists")
    raw_terminal_dir.mkdir(parents=True, exist_ok=False)
    start_broker = dukascopy_common.broker_epoch_seconds_for_utc(START_UTC)
    cutoff_broker = dukascopy_common.broker_epoch_seconds_for_utc(cutoff)
    if preset_lines_override is not None:
        preset_lines = [*preset_lines_override, ""]
    elif probe:
        preset_lines = [
            f"InpSymbols={','.join(symbols)}",
            f"InpOutputDir={output_rel}",
            f"InpCompletion={marker_name}",
            f"InpFromBrokerEpoch={start_broker}",
            f"InpToBrokerEpoch={cutoff_broker}",
            f"InpWarmupSeconds={WARMUP_SECONDS}",
            "",
        ]
    else:
        preset_lines = [
            f"InpSymbols={','.join(symbols)}",
            f"InpOutputDir={output_rel}",
            f"InpCompletion={marker_name}",
            f"InpFromBrokerEpoch={start_broker}",
            f"InpToBrokerEpoch={cutoff_broker}",
            f"InpFromUtcEpoch={int(START_UTC.timestamp())}",
            f"InpToUtcEpoch={int(cutoff.timestamp())}",
            "InpHardCeilingMinutes="
            + ",".join(str(HARD_CEILING_MINUTES[symbol]) for symbol in symbols),
            "InpBarChunkDays=7",
            "InpTickChunkHours=6",
            f"InpCopyAttempts={EXPORT_COPY_ATTEMPTS}",
            f"InpWarmupSeconds={WARMUP_SECONDS}",
            "",
        ]
    boot.atomic_write_text(preset, "\n".join(preset_lines))
    login, server = boot.load_dxz_factory_login()
    if server.casefold() != "darwinex-live":
        raise ExportRefused(f"refused non-Darwinex-Live server: {server}")
    account_fingerprint = hashlib.sha256(f"{server.casefold()}:{login}".encode()).hexdigest()[:16]
    ini = out / "startup.ini"
    boot.atomic_write_text(
        ini,
        _startup_ini_text(
            login=login,
            server=server,
            script=f"QM\\{staging_family}\\{session_tag}\\{script_source.stem}",
            preset_name=preset.name,
            symbol=symbols[0],
            max_bars=max_bars,
        ),
    )
    startup_ini_sha256 = sha256_file(ini)
    startup_ini_removed = False
    config_before: dict[str, Any] | None = None
    config_backups: dict[str, bytes | None] | None = None
    config_restore: dict[str, Any] | None = None
    process: subprocess.Popen[bytes] | None = None
    identity: dict[str, Any] | None = None
    termination: dict[str, Any] | None = None
    raw_binding: dict[str, Any] | None = None
    peak_private_gib = 0.0
    minimum_free_gib = _free_gib()
    minimum_disk_free_gib = _disk_free_gib()
    completion: str | None = None
    stop_reason: str | None = None
    execution_error: str | None = None
    cleanup_errors: list[str] = []
    reservation_heartbeats: list[dict[str, Any]] = []
    started: dt.datetime | None = None
    finished: dt.datetime | None = None
    effective_timeout_seconds = 0.0
    try:
        # Snapshot T1's persisted config before the terminal can touch it.
        # Inside the try so the credential-bearing startup.ini is always
        # removed by the finally, even if the snapshot itself fails.
        config_before, config_backups = _snapshot_terminal_config(session_tag)
        if _t1_mt5_processes():
            raise ExportRefused("T1 ceased being process-idle before launch")
        first_heartbeat = _maintain_reservation_for_task(reserved_by, task_id)
        reservation_heartbeats.append(first_heartbeat)
        started = dt.datetime.now(dt.UTC)
        effective_timeout_seconds = _effective_export_timeout_seconds(
            timeout_seconds,
            reservation_until_utc,
            now=started,
        )
        process = subprocess.Popen(
            [str(TERMINAL_BINARY), "/portable", f"/config:{ini}"],
            cwd=TERMINAL_ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        deadline = time.monotonic() + effective_timeout_seconds
        next_disk_sample = time.monotonic()
        next_reservation_heartbeat = time.monotonic() + (
            RESERVATION_HEARTBEAT_INTERVAL_SECONDS
            if first_heartbeat["status"] == "RENEWED"
            else RESERVATION_HEARTBEAT_RETRY_SECONDS
        )
        while time.monotonic() < deadline:
            matches = [
                value
                for row in boot.scan_terminal_processes()
                if (value := overlap_export._owned_match(row, ini, started))
            ]
            if matches:
                if len(matches) != 1:
                    raise ExportRefused("owned T1 exporter config/path is not unique")
                identity = matches[0]
            observed_pid = int(identity["pid"]) if identity else process.pid
            peak_private_gib = max(peak_private_gib, _private_bytes_gib(observed_pid))
            free_gib = _free_gib()
            minimum_free_gib = min(minimum_free_gib, free_gib)
            if free_gib < MIN_FREE_GIB:
                stop_reason = "physical_free_ram_below_14_gib"
                raise ExportRefused(stop_reason)
            now_monotonic = time.monotonic()
            if now_monotonic >= next_reservation_heartbeat:
                heartbeat = _maintain_reservation_for_task(reserved_by, task_id)
                reservation_heartbeats.append(heartbeat)
                next_reservation_heartbeat = now_monotonic + (
                    RESERVATION_HEARTBEAT_INTERVAL_SECONDS
                    if heartbeat["status"] == "RENEWED"
                    else RESERVATION_HEARTBEAT_RETRY_SECONDS
                )
            if now_monotonic >= next_disk_sample:
                disk_free_gib = _disk_free_gib()
                minimum_disk_free_gib = min(
                    minimum_disk_free_gib, disk_free_gib
                )
                next_disk_sample = now_monotonic + DISK_SAMPLE_SECONDS
                if disk_free_gib < MIN_RUNTIME_DISK_FREE_GIB:
                    stop_reason = "disk_free_below_60_gib"
                    raise ExportRefused(stop_reason)
            if process.poll() is not None and identity is None and dt.datetime.now(dt.UTC) - started > dt.timedelta(seconds=20):
                raise ExportRefused("owned exporter exited before identity binding")
            if marker.is_file() and identity is not None:
                completion = marker.read_text(encoding="utf-8-sig").strip()
                break
            time.sleep(1)
        else:
            stop_reason = "session_timeout"
            raise ExportRefused(stop_reason)
    except BaseException as exc:
        execution_error = f"{type(exc).__name__}: {exc}"
    finally:
        finished = dt.datetime.now(dt.UTC)
        try:
            reservation_heartbeats.append(
                _maintain_reservation_for_task(reserved_by, task_id)
            )
        except BaseException as exc:
            cleanup_errors.append(
                f"reservation_heartbeat_before_cleanup:{type(exc).__name__}:{exc}"
            )
        try:
            if identity is not None:
                termination = overlap_export._terminate_owned(identity, ini)
            elif process is not None and process.poll() is None:
                # This is the exact Popen instance created above.  It has not
                # detached into the identity-checked terminal process, so this
                # handle remains a task-owned termination target.
                process.terminate()
                process.wait(timeout=10)
                termination = {
                    "terminated": True,
                    "pid": process.pid,
                    "binding": "popen",
                }
            elif process is not None:
                termination = {
                    "terminated": True,
                    "pid": process.pid,
                    "binding": "already_exited",
                    "exit_code": process.returncode,
                }
            else:
                termination = {
                    "terminated": True,
                    "pid": None,
                    "binding": "not_started",
                }
        except BaseException as exc:
            cleanup_errors.append(f"owned_process_termination:{type(exc).__name__}:{exc}")
        try:
            # The process identity is bound by the config path, not by reading
            # this file again.  Always remove the credential-bearing file even
            # if termination itself needs operator review.
            ini.unlink(missing_ok=True)
            startup_ini_removed = not ini.exists()
        except OSError as exc:
            cleanup_errors.append(f"startup_ini_remove:{type(exc).__name__}:{exc}")
        if config_before is not None and config_backups is not None:
            try:
                terminated = bool(termination and termination.get("terminated"))
                if terminated:
                    for _ in range(CONFIG_RESTORE_PROCESS_WAIT_SECONDS):
                        if not _t1_mt5_processes():
                            break
                        time.sleep(1)
                config_restore = _restore_terminal_config(
                    config_before,
                    config_backups,
                    out,
                    terminal_terminated=terminated,
                )
            except BaseException as exc:
                cleanup_errors.append(
                    f"terminal_config_restore:{type(exc).__name__}:{exc}"
                )
        if raw_terminal_dir.is_dir():
            try:
                raw_binding = _copy_and_bind_raw(raw_terminal_dir, out)
            except BaseException as exc:
                cleanup_errors.append(f"raw_evidence_copy:{type(exc).__name__}:{exc}")
            try:
                reservation_heartbeats.append(
                    _maintain_reservation_for_task(reserved_by, task_id)
                )
            except BaseException as exc:
                cleanup_errors.append(
                    f"reservation_heartbeat_after_raw_copy:{type(exc).__name__}:{exc}"
                )
    result = {
        "admissible": False,
        "source": source_binding,
        "compile": {
            "exit_code": compiled.returncode,
            "errors": 0,
            "warnings": 0,
            "log": _file_binding(compile_log),
            "source": _file_binding(compiled_dir / staged.name),
            "ex5": _file_binding(compiled_dir / ex5.name),
        },
        "terminal_binary": _file_binding(TERMINAL_BINARY),
        "account_fingerprint": account_fingerprint,
        "server": server,
        "mode": mode,
        "startup_ini_sha256": startup_ini_sha256,
        "startup_ini_removed": startup_ini_removed,
        "session_max_bars": max_bars,
        "terminal_config_before": config_before,
        "terminal_config_restore": config_restore,
        "process_identity": identity,
        "termination": termination,
        "completion": completion,
        "completion_marker": _file_binding(marker) if marker.is_file() else None,
        "stop_reason": stop_reason,
        "started_at_utc": (
            started.isoformat().replace("+00:00", "Z") if started else None
        ),
        "completed_at_utc": (
            finished.isoformat().replace("+00:00", "Z") if finished else None
        ),
        "duration_seconds": (
            round((finished - started).total_seconds(), 6)
            if started is not None and finished is not None
            else None
        ),
        "requested_timeout_seconds": int(timeout_seconds),
        "effective_timeout_seconds": round(effective_timeout_seconds, 6),
        "reservation_until_utc": reservation_until_utc,
        "reservation_cleanup_margin_seconds": RESERVATION_CLEANUP_MARGIN_SECONDS,
        "reservation_deadline_guard_seconds": RESERVATION_DEADLINE_GUARD_SECONDS,
        "reservation_heartbeats": reservation_heartbeats,
        "observed_peak_private_gib": round(peak_private_gib, 6),
        "minimum_physical_free_gib": round(minimum_free_gib, 6),
        "minimum_disk_free_gib": round(minimum_disk_free_gib, 6),
        "raw": raw_binding,
        "error": execution_error or ("; ".join(cleanup_errors) if cleanup_errors else None),
        "cleanup_errors": cleanup_errors,
    }
    _atomic_write_json(out / "export_execution_receipt.json", result)
    return result


def _completion_ok(completion: object, symbol_count: int) -> bool:
    return str(completion or "").startswith(
        f"successes={symbol_count} failures=0 terminal=T1 server=Darwinex-Live"
    )


def run_session(
    *,
    session_tag: str,
    symbols: Sequence[str],
    cutoff_utc: str,
    calibration: bool,
    calibration_admission_gib: float | None,
    headroom_acceptance: Path | None,
    apply: bool,
    probe_history_depth: bool = False,
    probe_max_bars: int | None = None,
) -> dict[str, Any]:
    if not SESSION_TAG_RE.fullmatch(session_tag):
        raise ExportRefused("session tag must be YYYYMMDDTHHMMSSZ_<safe-suffix>")
    selected = validate_symbols(symbols)
    cutoff = _parse_cutoff(cutoff_utc)
    probe = bool(probe_history_depth)
    if probe:
        # Read-only depth probe: same governed launch/reservation/restore
        # path, but no calibration, headroom acceptance or admissible data.
        if calibration or headroom_acceptance is not None or calibration_admission_gib is not None:
            raise ExportRefused(
                "--probe-history-depth excludes --calibration, "
                "--calibration-admission-gib and --headroom-acceptance"
            )
        if probe_max_bars is not None and int(probe_max_bars) != SESSION_MAX_BARS:
            raise ExportRefused(
                f"--probe-max-bars accepts only {SESSION_MAX_BARS} (variant B) or nothing (variant A)"
            )
    elif probe_max_bars is not None:
        raise ExportRefused("--probe-max-bars is valid only with --probe-history-depth")
    minutes = PROBE_RESERVATION_MINUTES if probe else reservation_minutes(selected)
    if calibration and selected != ("XAUUSD",):
        raise ExportRefused("the first non-admissible calibration session must be XAUUSD only")
    if calibration and headroom_acceptance is not None:
        raise ExportRefused("calibration must not consume an existing headroom acceptance")
    if calibration:
        try:
            calibration_admission = float(calibration_admission_gib)
        except (TypeError, ValueError) as exc:
            raise ExportRefused(
                "calibration requires --calibration-admission-gib"
            ) from exc
        if (
            not math.isfinite(calibration_admission)
            or calibration_admission < MIN_FREE_GIB
        ):
            raise ExportRefused(
                "calibration admission must be finite and at least 14.0 GiB"
            )
    else:
        if calibration_admission_gib is not None:
            raise ExportRefused(
                "--calibration-admission-gib is valid only with --calibration"
            )
        calibration_admission = None
    if not probe and not calibration and headroom_acceptance is None:
        raise ExportRefused("admissible export requires a Fable-accepted headroom receipt")
    session_max_bars = (probe_max_bars if probe else SESSION_MAX_BARS)
    plan = {
        "schema": RECEIPT_SCHEMA,
        "task_id": TASK_ID,
        "session_tag": session_tag,
        "symbols": list(selected),
        "cutoff_utc": cutoff.isoformat().replace("+00:00", "Z"),
        "mode": "probe_history_depth" if probe else "export",
        "probe_variant": (
            None
            if not probe
            else ("A_CURRENT_MAXBARS" if probe_max_bars is None else "B_RAISED_MAXBARS")
        ),
        "calibration": bool(calibration),
        "calibration_admission_gib": calibration_admission,
        "admissible": False,
        "session_max_bars": session_max_bars,
        "warmup_seconds_per_symbol": WARMUP_SECONDS,
        "reservation_minutes": minutes,
        "symbol_hard_ceiling_minutes": {
            symbol: HARD_CEILING_MINUTES[symbol] for symbol in selected
        },
        "export_timeout_seconds": (
            PROBE_TIMEOUT_SECONDS if probe else export_timeout_seconds(selected)
        ),
        "reservation_cleanup_margin_seconds": RESERVATION_CLEANUP_MARGIN_SECONDS,
        "reservation_deadline_guard_seconds": RESERVATION_DEADLINE_GUARD_SECONDS,
        "disk_start_floor_gib": MIN_START_DISK_FREE_GIB,
        "disk_runtime_floor_gib": MIN_RUNTIME_DISK_FREE_GIB,
        "apply": bool(apply),
        "created_at_utc": _utc_now(),
    }
    if not apply:
        return {**plan, "status": "PLAN_ONLY"}

    runtime = validate_canonical_runtime()
    authority = validate_a2_authority()
    source = validate_mql_source()
    probe_source = validate_probe_source() if probe else None
    terminal_binding = _file_binding(TERMINAL_BINARY)
    accepted_headroom = None
    measured_headroom = None
    if probe:
        required_free_gib = PROBE_ADMISSION_GIB
    elif calibration:
        required_free_gib = float(calibration_admission)
    else:
        accepted_headroom = validate_headroom_acceptance(
            Path(headroom_acceptance),
            symbols=selected,
            wrapper_sha256=runtime["wrapper"]["sha256"],
            source_sha256=source["sha256"],
            terminal_sha256=terminal_binding["sha256"],
        )
        measured_headroom = float(accepted_headroom["headroom_gib"])
        required_free_gib = _required_free_gib(accepted_headroom)
    free_before = _free_gib()
    if free_before < required_free_gib:
        raise ExportRefused(
            f"RAM gate failed: {free_before:.3f} GiB free < {required_free_gib:.3f} GiB required"
        )
    disk_free_before = _disk_free_gib()
    if disk_free_before < MIN_START_DISK_FREE_GIB:
        raise ExportRefused(
            f"D: disk gate failed: {disk_free_before:.3f} GiB free < "
            f"{MIN_START_DISK_FREE_GIB:.3f} GiB required"
        )

    out = (ARTIFACT_ROOT / session_tag).resolve()
    if out.parent != ARTIFACT_ROOT.resolve() or out.exists():
        raise ExportRefused("session output must be a new direct child of the task source root")
    out.mkdir(parents=True)
    receipt_path = out / "session_receipt.json"
    receipt: dict[str, Any] = {
        **plan,
        "status": "FAIL",
        "runtime": runtime,
        "authority": authority,
        "mql_source": source,
        "probe_source": probe_source,
        "terminal_binary": terminal_binding,
        "ram_preflight": {
            "physical_free_gib": round(free_before, 6),
            "floor_gib": MIN_FREE_GIB,
            "measured_export_headroom_gib": measured_headroom,
            "required_free_gib": round(required_free_gib, 6),
            "accepted_headroom": accepted_headroom,
        },
        "disk_preflight": {
            "free_gib": round(disk_free_before, 6),
            "start_floor_gib": MIN_START_DISK_FREE_GIB,
            "runtime_floor_gib": MIN_RUNTIME_DISK_FREE_GIB,
            "sample_interval_seconds": DISK_SAMPLE_SECONDS,
        },
    }
    _atomic_write_json(receipt_path, receipt)
    purge_before: dict[str, Any] | None = None
    worker_environment: dict[str, str] | None = None
    reserved_by = f"dwx2026:{os.getpid()}:{TASK_ID}"
    reservation_created = False
    worker_stopped = False
    try:
        disk_before_quiesce = _disk_free_gib()
        receipt["disk_preflight"]["free_before_purge_quiesce_gib"] = round(
            disk_before_quiesce, 6
        )
        if disk_before_quiesce < MIN_START_DISK_FREE_GIB:
            raise ExportRefused(
                "D: disk gate failed immediately before purge quiesce: "
                f"{disk_before_quiesce:.3f} GiB free < "
                f"{MIN_START_DISK_FREE_GIB:.3f} GiB required"
            )
        purge_before = _task_snapshot()
        receipt["purge_quiesce"] = _quiesce_purge(purge_before)
        pre_snapshot = _manifest_master_snapshot()
        receipt["v1_pre_snapshot"] = pre_snapshot
        before_lock = _assert_t1_idle()
        with FactoryMutationLock(
            FARM_ROOT / "state/FACTORY_MUTATION.lock",
            owner=f"dwx_2026_band_a_export:{TASK_ID}:reserve",
        ):
            inside_lock = _assert_t1_idle()
            if (
                before_lock["worker_pid"],
                before_lock["worker_created"],
            ) != (
                inside_lock["worker_pid"],
                inside_lock["worker_created"],
            ):
                raise ExportRefused("T1 worker lifecycle changed before reservation")
            free_at_reservation = _free_gib()
            receipt["ram_preflight"]["physical_free_at_reservation_gib"] = round(
                free_at_reservation, 6
            )
            if free_at_reservation < required_free_gib:
                raise ExportRefused(
                    "RAM gate failed immediately before the T1 reservation: "
                    f"{free_at_reservation:.3f} GiB free < "
                    f"{required_free_gib:.3f} GiB required"
                )
            worker_receipt, worker_environment = _quiesce_worker(
                reserved_by, minutes, out
            )
            reservation_created = True
            worker_stopped = True
            receipt["worker_quiesce"] = worker_receipt
        # The global mutation lock is deliberately not held here.
        receipt["export"] = _execute_export(
            out=out,
            session_tag=session_tag,
            symbols=selected,
            cutoff=cutoff,
            timeout_seconds=int(plan["export_timeout_seconds"]),
            reserved_by=reserved_by,
            reservation_until_utc=str(
                receipt["worker_quiesce"]["reservation"]["until_utc"]
            ),
            mode="probe" if probe else "export",
            max_bars=session_max_bars,
        )
        receipt["reservation_heartbeats"] = list(
            receipt["export"].get("reservation_heartbeats") or []
        )
        if receipt["export"].get("error"):
            raise ExportRefused(
                "export execution failed: " + str(receipt["export"]["error"])
            )
        post_snapshot = _manifest_master_snapshot()
        receipt["v1_post_snapshot"] = post_snapshot
        receipt["v1_manifest_master_unchanged"] = pre_snapshot == post_snapshot
        if not receipt["v1_manifest_master_unchanged"]:
            raise ExportRefused("v1 manifest/master snapshot changed during export")
        if probe:
            receipt["history_depth_probe"] = _build_probe_receipt(
                out=out,
                session_tag=session_tag,
                symbols=selected,
                cutoff=cutoff,
                export=receipt["export"],
                requested_max_bars=session_max_bars,
            )
            receipt["history_depth_probe_path"] = str(out / "history_depth_probe.json")
            receipt["status"] = "PROBE_REVIEW_REQUIRED"
        else:
            depth_short = _history_depth_short(receipt["export"].get("completion"))
            if depth_short:
                receipt["history_depth"] = depth_short
                raise HistoryDepthShort(
                    "HISTORY_DEPTH_SHORT: native M1 series does not reach the window start; "
                    + "; ".join(
                        f"{row['symbol']} reason={row['history_reason']} "
                        f"first_available={row['first_available_broker_wall']}"
                        for row in depth_short
                    )
                )
            marker_statuses = {
                row.get("symbol"): row.get("status")
                for row in _completion_rows(receipt["export"].get("completion"))
            }
            gap_symbols = [
                symbol for symbol in selected if marker_statuses.get(symbol) == "TICK_GAP"
            ]
            if gap_symbols:
                verified = [
                    symbol
                    for symbol in selected
                    if marker_statuses.get(symbol) in {"SUCCESS", "TICK_GAP"}
                ]
                verification = _verify_tick_zero_chunks(
                    export=receipt["export"],
                    symbols=verified,
                    start_broker=dukascopy_common.broker_epoch_seconds_for_utc(START_UTC),
                    cutoff_broker=dukascopy_common.broker_epoch_seconds_for_utc(cutoff),
                )
                receipt["tick_chunk_verification"] = verification
                receipt["tick_gaps"] = [
                    {"symbol": symbol, **gap}
                    for symbol in gap_symbols
                    for gap in verification["symbols"][symbol]["gaps"]
                ]
                raise TickGap(
                    "TICK_GAP: empty tick chunk(s) where the market was not proven "
                    "closed; "
                    + "; ".join(
                        f"{gap['symbol']} {gap['classification']} "
                        f"from={gap['from_broker_wall']}"
                        for gap in receipt["tick_gaps"][:10]
                    )
                )
            if not _completion_ok(receipt["export"].get("completion"), len(selected)):
                raise ExportRefused(
                    "export completion marker did not authenticate every selected symbol"
                )
            receipt["tick_chunk_verification"] = _verify_tick_zero_chunks(
                export=receipt["export"],
                symbols=selected,
                start_broker=dukascopy_common.broker_epoch_seconds_for_utc(START_UTC),
                cutoff_broker=dukascopy_common.broker_epoch_seconds_for_utc(cutoff),
            )
        if probe:
            pass
        elif calibration:
            observed = float(receipt["export"].get("observed_peak_private_gib") or 0.0)
            measured = max(0.25, math.ceil(observed * 4.0) / 4.0)
            calibration_body = {
                "schema": CALIBRATION_SCHEMA,
                "task_id": TASK_ID,
                "admissible": False,
                "symbols": list(selected),
                "wrapper_sha256": runtime["wrapper"]["sha256"],
                "source_sha256": source["sha256"],
                "terminal_sha256": terminal_binding["sha256"],
                "observed_peak_private_gib": observed,
                "measured_export_headroom_gib": measured,
                "calibration_admission_gib": calibration_admission,
                "duration_seconds": receipt["export"].get("duration_seconds"),
                "minimum_physical_free_gib": receipt["export"].get(
                    "minimum_physical_free_gib"
                ),
                "minimum_disk_free_gib": receipt["export"].get(
                    "minimum_disk_free_gib"
                ),
                "raw_bundle_sha256": (
                    (receipt["export"].get("raw") or {}).get("bundle_sha256")
                ),
                "v1_manifest_master_unchanged": True,
                "session_receipt_path": str(receipt_path),
                "completed_at_utc": _utc_now(),
            }
            calibration_body["calibration_sha256"] = _canonical_sha256(calibration_body)
            _atomic_write_json(out / "headroom_calibration.json", calibration_body)
            receipt["headroom_calibration"] = calibration_body
            receipt["status"] = "CALIBRATION_REVIEW_REQUIRED"
        else:
            receipt["admissible"] = True
            receipt["status"] = "REVIEW_REQUIRED"
    except BaseException as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
        if isinstance(exc, HistoryDepthShort):
            receipt["status"] = "HISTORY_DEPTH_SHORT"
        elif isinstance(exc, TickGap):
            receipt["status"] = "TICK_GAP"
    finally:
        cleanup_errors: list[str] = []
        if "v1_pre_snapshot" in receipt and "v1_post_snapshot" not in receipt:
            try:
                post_snapshot = _manifest_master_snapshot()
                receipt["v1_post_snapshot"] = post_snapshot
                receipt["v1_manifest_master_unchanged"] = (
                    receipt["v1_pre_snapshot"] == post_snapshot
                )
                if not receipt["v1_manifest_master_unchanged"]:
                    cleanup_errors.append("v1_snapshot:changed_during_failed_session")
            except BaseException as exc:
                cleanup_errors.append(f"v1_snapshot:{type(exc).__name__}:{exc}")
        if worker_stopped or reservation_created:
            try:
                if worker_stopped and worker_environment is not None:
                    try:
                        receipt.setdefault("reservation_heartbeats", []).append(
                            _maintain_terminal_reservation(reserved_by)
                        )
                    except BaseException as exc:
                        cleanup_errors.append(
                            "reservation_heartbeat_before_worker_restore:"
                            f"{type(exc).__name__}:{exc}"
                        )
                    receipt["worker_restore"] = _restore_worker_with_lock(
                        environment=worker_environment,
                        reserved_by=reserved_by,
                        before_identity=receipt["worker_quiesce"]["before"][
                            "worker_identity"
                        ],
                        out=out,
                    )
                    reservation_created = False
                elif reservation_created:
                    with FactoryMutationLock(
                        FARM_ROOT / "state/FACTORY_MUTATION.lock",
                        owner=f"dwx_2026_band_a_export:{TASK_ID}:release",
                    ):
                        receipt["reservation_release"] = _release_exact_reservation(
                            reserved_by
                        )
                        reservation_created = False
            except BaseException as exc:
                cleanup_errors.append(f"worker_restore:{type(exc).__name__}:{exc}")
        if purge_before is not None:
            try:
                receipt["purge_restore"] = _restore_purge(purge_before)
            except BaseException as exc:
                cleanup_errors.append(f"purge_restore:{type(exc).__name__}:{exc}")
        if cleanup_errors:
            receipt["cleanup_errors"] = cleanup_errors
            receipt["status"] = "FAIL"
            receipt["admissible"] = False
        receipt["completed_at_utc"] = _utc_now()
        _atomic_write_json(receipt_path, receipt)
    return receipt


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session-tag", required=True)
    parser.add_argument("--symbols", nargs="+", required=True)
    parser.add_argument("--cutoff-utc", required=True)
    parser.add_argument("--calibration", action="store_true")
    parser.add_argument("--calibration-admission-gib", type=float)
    parser.add_argument("--headroom-acceptance", type=Path)
    parser.add_argument(
        "--probe-history-depth",
        action="store_true",
        help="read-only native M1 depth probe (counts/timestamps only)",
    )
    parser.add_argument(
        "--probe-max-bars",
        type=int,
        help=f"probe variant B: session [Charts] MaxBars={SESSION_MAX_BARS}",
    )
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    result = run_session(
        session_tag=args.session_tag,
        symbols=args.symbols,
        cutoff_utc=args.cutoff_utc,
        calibration=args.calibration,
        calibration_admission_gib=args.calibration_admission_gib,
        headroom_acceptance=args.headroom_acceptance,
        apply=args.apply,
        probe_history_depth=args.probe_history_depth,
        probe_max_bars=args.probe_max_bars,
    )
    summary = {
        "status": result["status"],
        "session_tag": result["session_tag"],
        "admissible": result.get("admissible", False),
        "receipt": str(ARTIFACT_ROOT / args.session_tag / "session_receipt.json")
        if args.apply
        else None,
    }
    if args.probe_history_depth:
        probe_receipt = result.get("history_depth_probe") or {}
        summary["history_depth_probe"] = result.get("history_depth_probe_path")
        summary["rerun_gate"] = probe_receipt.get("rerun_gate")
    if result.get("history_depth"):
        summary["history_depth"] = result["history_depth"]
    if result.get("tick_gaps"):
        summary["tick_gaps"] = result["tick_gaps"][:20]
        summary["tick_gap_count"] = len(result["tick_gaps"])
    print(json.dumps(summary, sort_keys=True))
    return 0 if result["status"] in {
        "PLAN_ONLY",
        "CALIBRATION_REVIEW_REQUIRED",
        "REVIEW_REQUIRED",
        "PROBE_REVIEW_REQUIRED",
    } else 2


if __name__ == "__main__":
    raise SystemExit(main())
