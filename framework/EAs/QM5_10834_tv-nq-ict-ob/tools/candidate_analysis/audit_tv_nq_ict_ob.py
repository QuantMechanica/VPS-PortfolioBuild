#!/usr/bin/env python3
"""Outcome-fenced native candidate runner for QM5_10834.

The command has three deliberately separate trust domains:

* ``freeze-data`` hashes the exact isolated DEV2 ``NDX.DWX`` research corpus and the Factory
  namespace/rebuild authorities without opening an MT5 report or parsing a market
  outcome.
* ``pre`` reads only build, configuration, frozen data and runtime bytes.  It
  freezes one authorised symbol and four disjoint windows without opening an MT5
  report or parsing a market outcome.
* ``launch`` requires a short-lived, hash-bound authorisation receipt.  A
  triggerless S4U/Highest Scheduled Task owns the persistent worker beyond the
  caller's session lifetime.  Resume is permitted only before the first native
  cell crosses the outcome fence.  The worker treats native output as opaque
  bytes; it does not adjudicate performance.
* ``post`` accepts only a COMPLETE launch state.  It verifies Model 4 twice per
  cell, exact Deal-sequence equality, session/lifecycle invariants, the bound
  worst-of-DXZ/FTMO cost ledger and the frozen merit contract.

Evidence/infra defects are ``INVALID``.  A valid run that misses a merit gate is
``FAIL``.  There is no Model-4 waiver and no command-line merit override.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import math
import msvcrt
import os
import re
import subprocess
import sys
import tempfile
import time as time_module
from collections import defaultdict
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from pathlib import Path
from typing import Any, Iterable, Iterator, Mapping, Sequence


getcontext().prec = 34

TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]

EA_ID = 10834
EA_LABEL = "QM5_10834"
EXPERT_NAME = "QM5_10834_tv-nq-ict-ob"
EXPERT_PATH = rf"QM\{EXPERT_NAME}"
ANALYSIS_ID = "QM5_10834_TV_NQ_ICT_OB_NATIVE_001"
SCHEMA_VERSION = 2
MERIT_CONTRACT_VERSION = "QM5_10834_MERIT_V1_20260720"

CARD_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_10834_tv-nq-ict-ob.md"
)
PINE_PATH = EA_ROOT / "docs" / "candidate-analysis" / "primary_source_pine_v1.pine"
SPEC_PATH = EA_ROOT / "SPEC.md"
MQ5_PATH = EA_ROOT / f"{EXPERT_NAME}.mq5"
EX5_PATH = EA_ROOT / f"{EXPERT_NAME}.ex5"
MATRIX_PATH = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
COST_PATH = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"
LIVE_COMMISSION_PATH = REPO_ROOT / "framework" / "registry" / "live_commission.json"
V5_FRAMEWORK_PATH = REPO_ROOT / "framework" / "V5_FRAMEWORK_DESIGN.md"
BACKTEST_RULES_PATH = Path(
    r"C:\QM\worktrees\docs-km\decisions\2026-04-28_seven_backtest_rules.md"
)
ALIASES_PATH = REPO_ROOT / "framework" / "registry" / "execution_symbol_aliases_v1.json"
NDX_REBUILD_ROOT = Path(
    r"D:\QM\reports\setup\tick-data-timezone\NDX.DWX_20260720"
)
NDX_REBUILD_DONE_PATH = NDX_REBUILD_ROOT / "NDX_DUKASCOPY_REIMPORT.DONE"
NDX_REBUILD_SOURCE_PATH = NDX_REBUILD_ROOT / "QM_NDX_Reimport_20260718.mq5"
SCHEDULED_TASK_HELPER_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "run_outcome_fenced_task.ps1"
)
PYTHON_PATH = Path(sys.executable).resolve()
RUNNER_PATH = REPO_ROOT / "framework" / "scripts" / "run_dev2_smoke.ps1"
RUNNER_CHILD_PATH = REPO_ROOT / "framework" / "scripts" / "invoke_dev2_smoke_task.ps1"
DEV2_CLEANUP_HELPER_PATH = (
    REPO_ROOT / "framework" / "scripts" / "cleanup_dev2_account_lease.ps1"
)
RUN_SMOKE_PATH = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
DEV2_LANE_CONTRACT_PATH = REPO_ROOT / "framework" / "registry" / "dev2_lane_contract.json"
TESTER_GROUPS_CANONICAL_PATH = (
    REPO_ROOT
    / "framework"
    / "registry"
    / "tester_groups"
    / "Darwinex-Live_real.canonical.txt"
)
INFRA_RETRY_CONTRACT_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "infra_retry_contract_20260720.json"
)
REPORT_CORE_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20009_ict-liquidity-portfolio"
    / "tools"
    / "audit_mt5_report.py"
)
REPO_INCLUDE_ROOT = REPO_ROOT / "framework" / "Include"
EXECUTION_TERMINAL = "DEV2"
TERMINAL_ROOT = Path(r"D:\QM\mt5\DEV2")
TERMINAL_INCLUDE_ROOT = TERMINAL_ROOT / "MQL5" / "Include"
TERMINAL_DATA_ROOT = TERMINAL_ROOT / "Bases" / "Custom"
TERMINAL_SYMBOL_DATABASE_PATH = TERMINAL_ROOT / "Bases" / "symbols.custom.dat"
TESTER_GROUPS_DEV2_PATH = (
    TERMINAL_ROOT / "MQL5" / "Profiles" / "Tester" / "Groups" / "Darwinex-Live_real.txt"
)
DEV2_RUNS_ROOT = Path(r"D:\QM\reports\dev2\runs")
POWERSHELL_PATH = Path(r"C:\Program Files\PowerShell\7\pwsh.exe")
ALLOWED_RUN_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_10834")
NATIVE_ATTEMPT_CLAIM_PATH = (
    ALLOWED_RUN_ROOT / "claims" / f"{ANALYSIS_ID}_DEV2_NATIVE_ATTEMPT_001.json"
)
NATIVE_LAUNCH_LOCK_PATH = (
    ALLOWED_RUN_ROOT / "claims" / f"{ANALYSIS_ID}_NATIVE_LAUNCH.lock"
)

EXPECTED_PINE_SHA256 = "015bb5d550a8687f506646de6c33ddfe8b29c3ed5e4ec96f3c66364edfb7f0b5"
MODEL4_MARKER = "generating based on real ticks"
INITIAL_BALANCE = Decimal("100000")
ZERO = Decimal("0")
CENT = Decimal("0.01")
TIMEFRAME = "M5"
DUPLICATES = 2
MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL = 2
MAX_ATTEMPTS_PER_CELL = DUPLICATES + MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL
RUN_TIMEOUT_SECONDS = 28800
RUN_ATTEMPT_OVERHEAD_SECONDS = 600
CELL_CONTROLLER_TIMEOUT_SECONDS = (
    MAX_ATTEMPTS_PER_CELL * (RUN_TIMEOUT_SECONDS + RUN_ATTEMPT_OVERHEAD_SECONDS)
) + 1800
LAUNCHER_REVISION = 3
SCHEDULED_TASK_PREFIX = "QM_QM10834_AUDIT_"
MAX_SCHEDULED_TASK_SECONDS = 777600
NY_ENTRY_START = time(9, 45)
NY_ENTRY_END = time(10, 15)
# A close request is issued at 10:15.  One complete M5 bar is the hard maximum
# execution grace; 10:20 itself is outside the permitted interval.
NY_FLAT_DEADLINE_EXCLUSIVE = time(10, 20)
RESEARCH_SYMBOL = "NDX.DWX"
DATA_RECEIPT_ARTIFACT_TYPE = "QM5_10834_BACKTEST_DATA_RECEIPT"
DATA_COVERAGE_FROM = date(2018, 7, 2)
DATA_COVERAGE_TO = date(2025, 12, 31)
PRIOR_INFRA_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runs\NDX_ICT_OB_FULL_DEV_001"
)
PRIOR_INFRA_PRE_SHA256 = "78d7d2d3fe45665d79a794adc60a4a4e57e747584236f24622b8ed2cbbeb1172"
PRIOR_INFRA_STATE_SHA256 = "7bfbfc9da034fc930870817b138d92f8339c1b336fff2c0f852899b3fd58ef95"
CONTROLLER_PREFLIGHT_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\runs\NDX_ICT_OB_FULL_DEV2_INFRA_RETRY_001"
)
CONTROLLER_PREFLIGHT_PRE_SHA256 = "377cc789829c5fd5ad8107d977e29d8d7bc987f774c4414769999e44b8a8ee64"
CONTROLLER_PREFLIGHT_STATE_SHA256 = "6711df22476d20c40b6ef109729bed20ddcaf106597e4a53c767bb7dd2464011"

INFRA_RETRY_POLICY: dict[str, Any] = {
    "execution_lane": EXECUTION_TERMINAL,
    "maximum_alternate_attempts": 1,
    "prior_alternate_attempts": 0,
    "same_ea_binary_required": True,
    "same_set_required": True,
    "same_symbol_required": True,
    "same_dates_required": True,
    "same_model4_required": True,
    "same_duplicate_count_required": True,
    "same_merit_gates_required": True,
    "same_cost_schedule_required": True,
    "parameter_tuning_forbidden": True,
    "terminal_hopping_after_dev2_forbidden": True,
}

SYMBOL_POLICY: dict[str, str] = {
    RESEARCH_SYMBOL: "FACTORY_DWX_RESEARCH_BACKTEST_SYMBOL",
}

REQUIRED_BINDING_ROLES = frozenset(
    {
        "card",
        "pine",
        "spec",
        "mq5",
        "ex5",
        "set",
        "matrix",
        "cost",
        "live_commission",
        "v5_framework",
        "backtest_rules",
        "aliases",
        "rebuild_done",
        "rebuild_source",
        "runner",
        "runner_child",
        "dev2_cleanup_helper",
        "runner_smoke",
        "dev2_lane_contract",
        "tester_groups_canonical",
        "tester_groups_dev2",
        "dev2_symbol_database",
        "infra_retry_contract",
        "report_parser",
        "powershell",
        "python",
        "scheduled_task_helper",
        "tool",
    }
)


@dataclass(frozen=True)
class Window:
    cell_id: str
    cohort: str
    from_date: date
    to_date: date


WINDOWS: tuple[Window, ...] = (
    Window("DEV", "DEV", date(2018, 7, 2), date(2022, 12, 31)),
    Window("OOS_2023", "OOS", date(2023, 1, 1), date(2023, 12, 31)),
    Window("OOS_2024", "OOS", date(2024, 1, 1), date(2024, 12, 31)),
    Window("OOS_2025", "OOS", date(2025, 1, 1), date(2025, 12, 31)),
)

# These values are part of the tool's versioned contract.  They are intentionally
# absent from every public CLI parser.
MERIT_GATES: dict[str, Any] = {
    "version": MERIT_CONTRACT_VERSION,
    "dev": {
        "minimum_trades": 80,
        "minimum_cost_profit_factor": "1.20",
        "net_must_be_strictly_positive": True,
        "maximum_close_drawdown_percent": "10.0",
    },
    "each_oos_year": {
        "minimum_trades": 12,
        "minimum_cost_profit_factor_strict": "1.00",
        "net_must_be_strictly_positive": True,
    },
    "oos_pooled": {
        "minimum_trades": 45,
        "minimum_cost_profit_factor": "1.20",
        "net_must_be_strictly_positive": True,
        "maximum_close_drawdown_percent": "10.0",
    },
    "leave_best_oos_year_out": {
        "minimum_cost_profit_factor": "1.05",
        "net_must_be_strictly_positive": True,
        "best_year_basis": "highest_cost_adjusted_net",
    },
    "maximum_single_year_share_of_positive_oos_gross_profit": "0.60",
    "maximum_new_york_day_loss_percent_of_100k": "3.0",
    "top_five_percent_winners_removed": {
        "minimum_cost_profit_factor": "1.00",
        "removal_count": "ceil(0.05 * positive_winner_count)",
    },
}


class AuditError(RuntimeError):
    """Base fail-closed error."""


class InvalidEvidence(AuditError):
    """Infrastructure, lineage or evidence is unusable for merit."""


class AuthorizationError(AuditError):
    """A native launch is not exactly and currently authorised."""


@dataclass(frozen=True)
class TradeRecord:
    sequence: int
    symbol: str
    side: str
    entry_deal: str
    exit_deals: tuple[str, ...]
    entry_time_broker: datetime
    exit_time_broker: datetime
    entry_time_ny: datetime
    exit_time_ny: datetime
    new_york_day: str
    volume: Decimal
    native_net_usd: Decimal
    venue_cost_usd: Decimal
    adjusted_net_usd: Decimal


@dataclass
class NativeRunAudit:
    receipt: dict[str, Any]
    deals_sha256: str
    fingerprint_sha256: str
    trades: list[TradeRecord]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_utc(value: str, label: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise InvalidEvidence(f"invalid {label}: {value!r}") from exc
    if parsed.tzinfo is None:
        raise InvalidEvidence(f"{label} must carry an explicit UTC offset")
    return parsed.astimezone(timezone.utc)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        _jsonable(value), sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _decimal_text(value: Decimal) -> str:
    rendered = format(value, "f")
    if "." in rendered:
        rendered = rendered.rstrip("0").rstrip(".")
    return rendered or "0"


def _money(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def _money_text(value: Decimal) -> str:
    return format(_money(value), ".2f")


def _jsonable(value: Any) -> Any:
    if isinstance(value, Decimal):
        return _decimal_text(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, Mapping):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonable(item) for item in value]
    return value


def atomic_json(path: Path, payload: Mapping[str, Any], *, replace: bool) -> str:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not replace:
        raise InvalidEvidence(f"refusing to replace evidence: {path}")
    encoded = (
        json.dumps(_jsonable(payload), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        if replace:
            os.replace(temporary, path)
        else:
            try:
                os.link(temporary, path)
            except FileExistsError as exc:
                raise InvalidEvidence(f"refusing to replace evidence: {path}") from exc
            os.unlink(temporary)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return hashlib.sha256(encoded).hexdigest()


@contextmanager
def native_launch_lock(timeout_seconds: float = 30.0) -> Iterator[None]:
    NATIVE_LAUNCH_LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(NATIVE_LAUNCH_LOCK_PATH, os.O_CREAT | os.O_RDWR, 0o600)
    locked = False
    try:
        if os.fstat(descriptor).st_size < 1:
            os.ftruncate(descriptor, 1)
            os.fsync(descriptor)
        deadline = time_module.monotonic() + timeout_seconds
        while True:
            try:
                os.lseek(descriptor, 0, os.SEEK_SET)
                msvcrt.locking(descriptor, msvcrt.LK_NBLCK, 1)
                locked = True
                break
            except OSError as exc:
                if time_module.monotonic() >= deadline:
                    raise AuthorizationError(
                        "timed out acquiring the global native launch/resume lock"
                    ) from exc
                time_module.sleep(0.1)
        yield
    finally:
        if locked:
            os.lseek(descriptor, 0, os.SEEK_SET)
            msvcrt.locking(descriptor, msvcrt.LK_UNLCK, 1)
        os.close(descriptor)


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InvalidEvidence(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise InvalidEvidence(f"JSON root must be an object: {path}")
    return payload


def file_binding(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    path = path.resolve()
    if not path.is_file():
        raise InvalidEvidence(f"required file missing: {path}")
    observed = sha256_file(path)
    if expected_sha256 and observed != expected_sha256.lower():
        raise InvalidEvidence(
            f"SHA-256 drift for {path}: {observed} != {expected_sha256.lower()}"
        )
    return {"path": str(path), "size": path.stat().st_size, "sha256": observed}


def stable_file_binding(path: Path) -> dict[str, Any]:
    """Hash a non-empty file while proving it did not change during the read."""
    path = path.resolve()
    if not path.is_file():
        raise InvalidEvidence(f"required file missing: {path}")
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        before = os.fstat(handle.fileno())
        if before.st_size <= 0:
            raise InvalidEvidence(f"required file is empty: {path}")
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
        after = os.fstat(handle.fileno())
    path_after = path.stat()
    identity_before = (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
    )
    identity_after = (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
    )
    identity_path = (
        path_after.st_dev,
        path_after.st_ino,
        path_after.st_size,
        path_after.st_mtime_ns,
    )
    if identity_before != identity_after or identity_before != identity_path:
        raise InvalidEvidence(f"file changed while hashing: {path}")
    return {"path": str(path), "size": after.st_size, "sha256": digest.hexdigest()}


def assert_binding(binding: Mapping[str, Any], label: str) -> None:
    try:
        path = Path(str(binding["path"])).resolve()
        size = int(binding["size"])
        expected = str(binding["sha256"]).lower()
    except (KeyError, TypeError, ValueError) as exc:
        raise InvalidEvidence(f"malformed binding: {label}") from exc
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise InvalidEvidence(f"malformed SHA-256 in binding: {label}")
    if not path.is_file() or path.stat().st_size != size:
        raise InvalidEvidence(f"missing/size drift: {label}: {path}")
    observed = sha256_file(path)
    if observed != expected:
        raise InvalidEvidence(f"SHA-256 drift: {label}: {observed} != {expected}")


def assert_stable_binding(binding: Mapping[str, Any], label: str) -> None:
    try:
        expected_path = Path(str(binding["path"])).resolve()
        expected_size = int(binding["size"])
        expected_sha256 = str(binding["sha256"]).lower()
    except (KeyError, TypeError, ValueError) as exc:
        raise InvalidEvidence(f"malformed binding: {label}") from exc
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256) or expected_size <= 0:
        raise InvalidEvidence(f"malformed non-empty binding: {label}")
    observed = stable_file_binding(expected_path)
    if (
        observed["size"] != expected_size
        or observed["sha256"] != expected_sha256
    ):
        raise InvalidEvidence(f"size/SHA-256 drift: {label}: {expected_path}")


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _assert_run_root(path: Path) -> Path:
    resolved = path.resolve()
    if not _is_within(resolved, ALLOWED_RUN_ROOT) or resolved == ALLOWED_RUN_ROOT.resolve():
        raise InvalidEvidence(f"run root must be a child of {ALLOWED_RUN_ROOT}: {resolved}")
    return resolved


def _strict_decimal(value: Any, label: str) -> Decimal:
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise InvalidEvidence(f"invalid decimal {label}: {value!r}") from exc
    if not result.is_finite():
        raise InvalidEvidence(f"non-finite decimal {label}: {value!r}")
    return result


def validate_window_contract(windows: Sequence[Window] = WINDOWS) -> None:
    expected = (
        ("DEV", "DEV", "2018-07-02", "2022-12-31"),
        ("OOS_2023", "OOS", "2023-01-01", "2023-12-31"),
        ("OOS_2024", "OOS", "2024-01-01", "2024-12-31"),
        ("OOS_2025", "OOS", "2025-01-01", "2025-12-31"),
    )
    observed = tuple(
        (row.cell_id, row.cohort, row.from_date.isoformat(), row.to_date.isoformat())
        for row in windows
    )
    if observed != expected:
        raise InvalidEvidence(f"window contract drift: {observed!r}")
    for previous, current in zip(windows, windows[1:]):
        if previous.to_date >= current.from_date:
            raise InvalidEvidence("DEV/OOS windows are not disjoint")


def enforce_symbol_policy(symbol: str) -> None:
    if symbol != RESEARCH_SYMBOL:
        raise InvalidEvidence(
            f"symbol outside the frozen single-index policy: {symbol!r}; "
            f"only Factory research symbol {RESEARCH_SYMBOL} is eligible"
        )


def _matrix_row(symbol: str, matrix_path: Path = MATRIX_PATH) -> dict[str, str]:
    enforce_symbol_policy(symbol)
    try:
        with matrix_path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = [row for row in csv.DictReader(handle) if row.get("symbol") == symbol]
    except OSError as exc:
        raise InvalidEvidence(f"cannot read symbol matrix: {exc}") from exc
    if len(rows) != 1:
        raise InvalidEvidence(f"symbol matrix must contain exactly one {symbol} row")
    row = {str(key): str(value or "") for key, value in rows[0].items()}
    if row.get("canonical_name_verified", "").casefold() != "true":
        raise InvalidEvidence(f"symbol matrix canonical-name gate is not true: {symbol}")
    if row.get("asset_class", "").casefold() != "indices":
        raise InvalidEvidence(f"symbol matrix asset class is not indices: {symbol}")
    import_path = re.sub(r"/+", "/", row.get("import_log_path", "").replace("\\", "/"))
    if import_path != "Custom/Indices/Index 3/NDX.DWX":
        raise InvalidEvidence(f"symbol matrix import path drift: {import_path!r}")
    # Live OHLC/tail/parity evidence is intentionally excluded from the research
    # namespace contract.  The full matrix byte identity is hash-bound separately.
    return {
        "symbol": symbol,
        "asset_class": "indices",
        "import_log_path": import_path,
        "canonical_name_verified": "true",
    }


def _required_tick_months() -> tuple[str, ...]:
    result: list[str] = []
    cursor = date(2018, 7, 1)
    end = date(2025, 12, 1)
    while cursor <= end:
        result.append(cursor.strftime("%Y%m"))
        cursor = date(
            cursor.year + (1 if cursor.month == 12 else 0),
            1 if cursor.month == 12 else cursor.month + 1,
            1,
        )
    return tuple(result)


def _required_history_years() -> tuple[str, ...]:
    return tuple(str(year) for year in range(2018, 2026))


DATA_FACTORY_EVIDENCE_ROLES = frozenset(
    {
        "v5_framework",
        "backtest_rules",
        "aliases",
        "matrix",
        "cost",
        "rebuild_done",
        "rebuild_source",
    }
)


def _factory_evidence_paths(
    overrides: Mapping[str, Path] | None = None,
) -> dict[str, Path]:
    paths = {
        "v5_framework": V5_FRAMEWORK_PATH,
        "backtest_rules": BACKTEST_RULES_PATH,
        "aliases": ALIASES_PATH,
        "matrix": MATRIX_PATH,
        "cost": COST_PATH,
        "rebuild_done": NDX_REBUILD_DONE_PATH,
        "rebuild_source": NDX_REBUILD_SOURCE_PATH,
    }
    if overrides is not None:
        if set(overrides) != DATA_FACTORY_EVIDENCE_ROLES:
            raise InvalidEvidence("Factory evidence-role closure drift")
        paths = {role: Path(path) for role, path in overrides.items()}
    return {role: path.resolve() for role, path in paths.items()}


def _read_contract_text(path: Path, label: str) -> str:
    try:
        return path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        raise InvalidEvidence(f"cannot read {label}: {path}: {exc}") from exc


def _validate_factory_contracts(
    symbol: str,
    evidence_paths: Mapping[str, Path],
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    if set(evidence_paths) != DATA_FACTORY_EVIDENCE_ROLES:
        raise InvalidEvidence("Factory evidence-role closure drift")

    design = _read_contract_text(evidence_paths["v5_framework"], "V5 framework")
    if not re.search(
        r"Symbols\s+carry\s+`\.DWX`\s+in\s+research\s+and\s+backtest,\s+"
        r"stripped\s+only\s+at\s+deploy\s+packaging",
        design,
        re.I,
    ):
        raise InvalidEvidence("V5 .DWX research/deploy contract is missing")

    rules = _read_contract_text(evidence_paths["backtest_rules"], "backtest Rule 1")
    if (
        "Rule 1 — Test ONLY on `.DWX` symbols" not in rules
        or "Every backtest run uses the `.DWX`-suffixed custom symbols, never native broker symbols."
        not in rules
    ):
        raise InvalidEvidence("binding .DWX-only backtest Rule 1 is missing")

    aliases = load_json(evidence_paths["aliases"])
    if (
        aliases.get("schema_version") != 1
        or aliases.get("artifact_type") != "QM_EXECUTION_SYMBOL_ALIASES"
        or aliases.get("status") != "ACTIVE"
    ):
        raise InvalidEvidence("execution-symbol alias registry identity drift")
    venues = aliases.get("venues")
    if not isinstance(venues, list):
        raise InvalidEvidence("execution-symbol alias venues are missing")
    expected_aliases = {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"}
    observed_aliases: dict[str, str] = {}
    for venue_id, expected_raw in expected_aliases.items():
        venue_rows = [
            venue
            for venue in venues
            if isinstance(venue, Mapping) and venue.get("venue_id") == venue_id
        ]
        if len(venue_rows) != 1 or not isinstance(venue_rows[0].get("symbols"), list):
            raise InvalidEvidence(f"alias registry must contain exactly one {venue_id} venue")
        symbol_rows = [
            row
            for row in venue_rows[0]["symbols"]
            if isinstance(row, Mapping) and row.get("logical_symbol") == symbol
        ]
        if len(symbol_rows) != 1 or symbol_rows[0].get("raw_symbol") != expected_raw:
            raise InvalidEvidence(f"{venue_id} alias drift for {symbol}")
        observed_aliases[venue_id] = expected_raw

    matrix_row = _matrix_row(symbol, evidence_paths["matrix"])
    cost_schedule = resolve_cost_schedule(evidence_paths["cost"], symbol)

    done_text = _read_contract_text(evidence_paths["rebuild_done"], "NDX rebuild DONE")
    done: dict[str, str] = {}
    for line in done_text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            done[key.strip()] = value.strip()
    required_done = {"status", "target", "ticks_added", "bars_updated"}
    if not required_done.issubset(done):
        raise InvalidEvidence("NDX rebuild DONE is incomplete")
    try:
        ticks_added = int(done["ticks_added"])
        bars_updated = int(done["bars_updated"])
    except ValueError as exc:
        raise InvalidEvidence("NDX rebuild counts are malformed") from exc
    if done["status"] != "OK" or done["target"] != symbol:
        raise InvalidEvidence("NDX rebuild DONE identity/status drift")
    if ticks_added <= 0 or bars_updated <= 0:
        raise InvalidEvidence("NDX rebuild did not add positive ticks/bars")

    source = _read_contract_text(evidence_paths["rebuild_source"], "NDX rebuild source")
    if not re.search(r'#define\s+TARGET\s+"NDX\.DWX"', source):
        raise InvalidEvidence("NDX rebuild source target drift")
    if "CustomTicksAdd" not in source or "CustomRatesUpdate" not in source:
        raise InvalidEvidence("NDX rebuild source lacks tick/bar rebuild operations")

    return {
        "namespace_contract": {
            "research_backtest_symbol": symbol,
            "dwx_required_in_research_backtest": True,
            "suffix_stripped_only_at_deploy_packaging": True,
            "live_aliases": observed_aliases,
            "live_ohlc_tail_parity_required_for_research_merit": False,
            "matrix_row": matrix_row,
        },
        "cost_schedule": cost_schedule,
        "rebuild_contract": {
            "status": "OK",
            "target": symbol,
            "ticks_added": ticks_added,
            "bars_updated": bars_updated,
            "uses_custom_ticks_add": True,
            "uses_custom_rates_update": True,
        },
    }


def _expected_data_files(
    symbol: str,
    terminal_data_root: Path,
) -> list[tuple[str, str, Path]]:
    enforce_symbol_policy(symbol)
    root = terminal_data_root.resolve()
    history_root = (root / "history" / symbol).resolve()
    ticks_root = (root / "ticks" / symbol).resolve()
    result = [
        ("history", year, (history_root / f"{year}.hcc").resolve())
        for year in _required_history_years()
    ]
    result.extend(
        ("ticks", month, (ticks_root / f"{month}.tkc").resolve())
        for month in _required_tick_months()
    )
    return result


def _data_coverage_contract() -> dict[str, Any]:
    return {
        "from_date": DATA_COVERAGE_FROM.isoformat(),
        "to_date": DATA_COVERAGE_TO.isoformat(),
        "history_year_first": 2018,
        "history_year_last": 2025,
        "history_file_count": len(_required_history_years()),
        "tick_month_first": "201807",
        "tick_month_last": "202512",
        "tick_file_count": len(_required_tick_months()),
    }


def freeze_backtest_data(
    symbol: str,
    *,
    terminal_data_root: Path = TERMINAL_DATA_ROOT,
    evidence_paths: Mapping[str, Path] | None = None,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    root = terminal_data_root.resolve()
    factory_paths = _factory_evidence_paths(evidence_paths)
    factory_evidence = {
        role: stable_file_binding(path) for role, path in sorted(factory_paths.items())
    }
    contracts = _validate_factory_contracts(symbol, factory_paths)

    files: list[dict[str, Any]] = []
    history_bytes = 0
    tick_bytes = 0
    for kind, period, path in _expected_data_files(symbol, root):
        item = {"kind": kind, "period": period, **stable_file_binding(path)}
        files.append(item)
        if kind == "history":
            history_bytes += int(item["size"])
        else:
            tick_bytes += int(item["size"])
    return {
        "schema_version": 2,
        "artifact_type": DATA_RECEIPT_ARTIFACT_TYPE,
        "created_utc": utc_now(),
        "terminal": EXECUTION_TERMINAL,
        "symbol": symbol,
        "coverage": _data_coverage_contract(),
        "store_roots": {
            "history": str((root / "history" / symbol).resolve()),
            "ticks": str((root / "ticks" / symbol).resolve()),
        },
        "files": files,
        "totals": {
            "history_files": len(_required_history_years()),
            "tick_files": len(_required_tick_months()),
            "files": len(files),
            "history_bytes": history_bytes,
            "tick_bytes": tick_bytes,
            "bytes": history_bytes + tick_bytes,
        },
        "factory_evidence": factory_evidence,
        **contracts,
        "outcome_fence": {
            "strategy_outcomes_read": False,
            "native_reports_opened": False,
            "mt5_terminal_started": False,
            "metatester_started": False,
        },
    }


def validate_backtest_data_receipt(
    path: Path,
    symbol: str,
    *,
    terminal_data_root: Path = TERMINAL_DATA_ROOT,
    evidence_paths: Mapping[str, Path] | None = None,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    receipt_binding = stable_file_binding(path)
    receipt = load_json(path)
    expected_keys = {
        "schema_version",
        "artifact_type",
        "created_utc",
        "terminal",
        "symbol",
        "coverage",
        "store_roots",
        "files",
        "totals",
        "factory_evidence",
        "namespace_contract",
        "cost_schedule",
        "rebuild_contract",
        "outcome_fence",
    }
    if set(receipt) != expected_keys:
        raise InvalidEvidence("backtest-data receipt field closure drift")
    if (
        receipt.get("schema_version") != 2
        or receipt.get("artifact_type") != DATA_RECEIPT_ARTIFACT_TYPE
        or receipt.get("terminal") != EXECUTION_TERMINAL
        or receipt.get("symbol") != symbol
    ):
        raise InvalidEvidence("backtest-data receipt identity drift")
    created = parse_utc(str(receipt.get("created_utc", "")), "data receipt created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("backtest-data receipt creation time is implausibly in the future")
    if receipt.get("coverage") != _data_coverage_contract():
        raise InvalidEvidence("backtest-data receipt coverage is not exactly 201807..202512")

    root = terminal_data_root.resolve()
    expected_roots = {
        "history": str((root / "history" / symbol).resolve()),
        "ticks": str((root / "ticks" / symbol).resolve()),
    }
    if receipt.get("store_roots") != expected_roots:
        raise InvalidEvidence("backtest-data receipt DEV2 store-root drift")

    expected_factory_paths = _factory_evidence_paths(evidence_paths)
    factory_evidence = receipt.get("factory_evidence")
    if not isinstance(factory_evidence, Mapping) or set(factory_evidence) != DATA_FACTORY_EVIDENCE_ROLES:
        raise InvalidEvidence("backtest-data Factory evidence closure drift")
    for role, expected_path in expected_factory_paths.items():
        item = factory_evidence.get(role)
        if not isinstance(item, Mapping) or set(item) != {"path", "size", "sha256"}:
            raise InvalidEvidence(f"malformed Factory evidence binding: {role}")
        if Path(str(item["path"])).resolve() != expected_path:
            raise InvalidEvidence(f"Factory evidence path drift: {role}")
        assert_stable_binding(item, f"Factory evidence {role}")
    contracts = _validate_factory_contracts(symbol, expected_factory_paths)
    for key, value in contracts.items():
        if receipt.get(key) != value:
            raise InvalidEvidence(f"backtest-data {key} semantic drift")

    files = receipt.get("files")
    expected_files = _expected_data_files(symbol, root)
    if not isinstance(files, list) or len(files) != len(expected_files):
        raise InvalidEvidence("backtest-data receipt must bind exactly 98 files")
    history_bytes = 0
    tick_bytes = 0
    for index, ((kind, period, expected_path), item) in enumerate(
        zip(expected_files, files)
    ):
        if not isinstance(item, Mapping) or set(item) != {
            "kind",
            "period",
            "path",
            "size",
            "sha256",
        }:
            raise InvalidEvidence(f"malformed data binding[{index}]")
        if (
            item.get("kind") != kind
            or item.get("period") != period
            or Path(str(item.get("path", ""))).resolve() != expected_path
        ):
            raise InvalidEvidence(f"backtest-data exact file-set/order drift at index {index}")
        assert_stable_binding(item, f"backtest data[{index}]")
        if kind == "history":
            history_bytes += int(item["size"])
        else:
            tick_bytes += int(item["size"])
    expected_totals = {
        "history_files": len(_required_history_years()),
        "tick_files": len(_required_tick_months()),
        "files": len(expected_files),
        "history_bytes": history_bytes,
        "tick_bytes": tick_bytes,
        "bytes": history_bytes + tick_bytes,
    }
    if receipt.get("totals") != expected_totals:
        raise InvalidEvidence("backtest-data receipt size totals drift")
    expected_fence = {
        "strategy_outcomes_read": False,
        "native_reports_opened": False,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }
    if receipt.get("outcome_fence") != expected_fence:
        raise InvalidEvidence("backtest-data receipt outcome fence drift")
    return {"receipt": receipt_binding, **receipt}


INCLUDE_RE = re.compile(r'^\s*#include\s*[<"]([^>"]+)[>"]', re.M)


def _resolve_include(name: str, parent: Path, roots: Sequence[Path]) -> Path:
    normalized = name.replace("\\", "/")
    candidates = [(parent / normalized).resolve()]
    candidates.extend((root / normalized).resolve() for root in roots)
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise InvalidEvidence(f"unresolved compile include {name!r} from {parent}")


def include_closure(
    source: Path,
    roots: Sequence[Path] = (REPO_INCLUDE_ROOT, TERMINAL_INCLUDE_ROOT),
) -> list[dict[str, Any]]:
    pending = [source.resolve()]
    visited: set[Path] = {source.resolve()}
    includes: set[Path] = set()
    while pending:
        current = pending.pop()
        try:
            text = current.read_text(encoding="utf-8-sig", errors="strict")
        except (OSError, UnicodeError) as exc:
            raise InvalidEvidence(f"cannot read compile input {current}: {exc}") from exc
        for name in INCLUDE_RE.findall(text):
            resolved = _resolve_include(name, current.parent, roots)
            if resolved not in visited:
                visited.add(resolved)
                includes.add(resolved)
                pending.append(resolved)
    return [file_binding(path) for path in sorted(includes, key=lambda item: str(item).casefold())]


def parse_set(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except OSError as exc:
        raise InvalidEvidence(f"cannot read set file {path}: {exc}") from exc
    metadata: dict[str, str] = {}
    inputs: dict[str, str] = {}
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if ":" in body:
                key, value = body.split(":", 1)
                key = key.strip()
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                    metadata[key] = value.strip()
            continue
        if "=" not in line:
            raise InvalidEvidence(f"malformed set line: {raw!r}")
        key, value = (part.strip() for part in line.split("=", 1))
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) or key in inputs:
            raise InvalidEvidence(f"invalid/duplicate set key: {key!r}")
        inputs[key] = value
    return metadata, inputs


ENUM_RE = re.compile(r"\benum\s+[A-Za-z_]\w*\s*\{(?P<body>.*?)\}\s*;", re.S)
INPUT_RE = re.compile(
    r"^\s*input\s+(?!group\b)(?P<type>[A-Za-z_]\w*)\s+"
    r"(?P<name>[A-Za-z_]\w*)\s*=\s*(?P<value>[^;]+);",
    re.M,
)


def _enum_values(texts: Iterable[str]) -> dict[str, int]:
    values: dict[str, int] = {}
    for text in texts:
        for match in ENUM_RE.finditer(text):
            next_value = 0
            for raw in match.group("body").split(","):
                token = re.sub(r"//.*", "", raw).strip()
                if not token:
                    continue
                if "=" in token:
                    name, rendered = (part.strip() for part in token.split("=", 1))
                    try:
                        next_value = int(rendered, 0)
                    except ValueError as exc:
                        raise InvalidEvidence(f"unsupported enum value: {token!r}") from exc
                else:
                    name = token
                if not re.fullmatch(r"[A-Za-z_]\w*", name):
                    raise InvalidEvidence(f"unsupported enum member: {name!r}")
                if name in values and values[name] != next_value:
                    raise InvalidEvidence(f"ambiguous enum member: {name}")
                values[name] = next_value
                next_value += 1
    return values


def _canonical_input(value: str, input_type: str, enums: Mapping[str, int]) -> str:
    raw = re.sub(r"//.*", "", value).strip()
    if input_type == "string" and len(raw) >= 2 and raw[0] == raw[-1] == '"':
        return raw[1:-1]
    if raw.casefold() in {"true", "false"}:
        return raw.casefold()
    if raw in enums:
        return str(enums[raw])
    try:
        return _decimal_text(Decimal(raw))
    except InvalidOperation:
        return raw


def effective_input_contract(
    source: Path,
    include_bindings: Sequence[Mapping[str, Any]],
    set_inputs: Mapping[str, str],
) -> dict[str, dict[str, str]]:
    paths = [source.resolve()] + [Path(str(item["path"])).resolve() for item in include_bindings]
    texts = [path.read_text(encoding="utf-8-sig", errors="strict") for path in paths]
    enums = _enum_values(texts)
    defaults: dict[str, tuple[str, str]] = {}
    for text in texts:
        for match in INPUT_RE.finditer(text):
            name = match.group("name")
            value = match.group("value").strip()
            input_type = match.group("type")
            candidate = (input_type, value)
            if name in defaults and defaults[name] != candidate:
                raise InvalidEvidence(f"duplicate input declaration drift: {name}")
            defaults[name] = candidate
    unknown = sorted(set(set_inputs) - set(defaults))
    if unknown:
        raise InvalidEvidence(f"set contains inputs absent from bound source/include closure: {unknown}")
    result: dict[str, dict[str, str]] = {}
    for name, (input_type, default) in sorted(defaults.items()):
        raw = set_inputs.get(name, default)
        result[name] = {
            "type": input_type,
            "raw": raw,
            "canonical": _canonical_input(raw, input_type, enums),
        }
    return result


def _validate_set_contract(symbol: str, metadata: Mapping[str, str], inputs: Mapping[str, str]) -> None:
    expected = {
        "qm_ea_id": "10834",
        "qm_magic_slot_offset": "0",
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "strategy_entry_start_hhmm": "945",
        "strategy_entry_end_hhmm": "1015",
        "strategy_target_r": "2.0",
    }
    drift = {key: (wanted, inputs.get(key)) for key, wanted in expected.items() if inputs.get(key) != wanted}
    if symbol != RESEARCH_SYMBOL or metadata.get("symbol") != symbol or metadata.get("timeframe") != TIMEFRAME:
        raise InvalidEvidence("set metadata violates the NDX.DWX/M5 single-symbol contract")
    if drift:
        raise InvalidEvidence(f"set input contract drift: {drift}")


def validate_build_receipt(
    path: Path,
    symbol: str,
    bindings: Mapping[str, Mapping[str, Any]],
) -> dict[str, Any]:
    receipt = load_json(path)
    if (
        receipt.get("ea_id") != "QM5_10834"
        or receipt.get("build_check_passed") is not True
        or receipt.get("compile_succeeded") is not True
    ):
        raise InvalidEvidence("build receipt is not a successful QM5_10834 build")
    expected_hashes = {
        "source_sha256": bindings["mq5"]["sha256"],
        "ex5_sha256": bindings["ex5"]["sha256"],
        "spec_sha256": bindings["spec"]["sha256"],
        "primary_source_sha256": bindings["pine"]["sha256"],
    }
    drift = {
        key: (wanted, str(receipt.get(key, "")).lower())
        for key, wanted in expected_hashes.items()
        if str(receipt.get(key, "")).lower() != wanted
    }
    set_hashes = receipt.get("setfile_sha256")
    if not isinstance(set_hashes, Mapping) or str(set_hashes.get(symbol, "")).lower() != bindings["set"]["sha256"]:
        drift["setfile_sha256"] = (bindings["set"]["sha256"], set_hashes)
    commit = str(receipt.get("build_commit", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        drift["build_commit"] = ("40 lowercase hex", commit)
    if drift:
        raise InvalidEvidence(f"build receipt/hash binding drift: {drift}")
    return receipt


def resolve_cost_schedule(path: Path, symbol: str) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    payload = load_json(path)
    symbols = payload.get("symbols")
    if not isinstance(symbols, Mapping):
        raise InvalidEvidence("cost model symbols map is missing")
    key = symbol.split(".", 1)[0]
    row = symbols.get(key)
    if not isinstance(row, Mapping):
        raise InvalidEvidence(f"cost model has no exact symbol row for {symbol}")
    alias_chain = [key]
    visited = {key}
    while row.get("alias_of") is not None:
        target = str(row.get("alias_of", ""))
        if not target or target in visited:
            raise InvalidEvidence(f"cost model alias cycle/malformed target for {symbol}")
        target_row = symbols.get(target)
        if not isinstance(target_row, Mapping):
            raise InvalidEvidence(f"cost model alias target is missing: {target}")
        visited.add(target)
        alias_chain.append(target)
        key = target
        row = target_row
    if alias_chain != ["NDX", "US100"]:
        raise InvalidEvidence(f"NDX cost alias chain drift: {alias_chain}")
    if row.get("dwx_symbol") != symbol or row.get("asset_class") != "index":
        raise InvalidEvidence(f"cost model row is not the exact index contract for {symbol}")
    dxz = row.get("dxz")
    ftmo = row.get("ftmo")
    if not isinstance(dxz, Mapping) or not isinstance(ftmo, Mapping):
        raise InvalidEvidence(f"cost model lacks both venues for {symbol}")

    def venue_rate(venue: Mapping[str, Any], label: str) -> Decimal:
        for field in ("commission_rt_per_lot_usd", "commission_rt_per_lot_usd_indicative"):
            if venue.get(field) is not None:
                value = _strict_decimal(venue[field], f"{symbol}.{label}.{field}")
                if value < ZERO:
                    raise InvalidEvidence("negative venue cost")
                return value
        raise InvalidEvidence(f"unresolved per-lot venue cost: {symbol}/{label}")

    dxz_rate = venue_rate(dxz, "dxz")
    ftmo_rate = venue_rate(ftmo, "ftmo")
    worst = _strict_decimal(row.get("worst_case_rt_per_lot_usd"), "worst_case_rt_per_lot_usd")
    calculated = max(dxz_rate, ftmo_rate)
    if _money(worst) != _money(calculated):
        raise InvalidEvidence(
            f"cost model worst-case drift for {symbol}: {worst} != max({dxz_rate},{ftmo_rate})"
        )
    if (
        _money(dxz_rate) != Decimal("5.50")
        or _money(ftmo_rate) != Decimal("0.00")
        or _money(worst) != Decimal("5.50")
    ):
        raise InvalidEvidence("NDX venue-cost contract must be DXZ 5.50 / FTMO 0 / worst 5.50")
    spread_source = str(dxz.get("spread_source", ""))
    spread_normalized = spread_source.casefold()
    if not all(token in spread_normalized for token in ("embedded", ".dwx", "real-tick")):
        raise InvalidEvidence("NDX spread must be embedded in .DWX real-tick history")
    return {
        "symbol": symbol,
        "cost_lookup_key": "NDX",
        "cost_resolved_key": key,
        "alias_chain": alias_chain,
        "currency": "USD",
        "application": "ROUND_TRIP_PER_CLOSED_LOT_ROUNDED_TO_CENT",
        "dxz_rt_per_lot_usd": _decimal_text(dxz_rate),
        "ftmo_rt_per_lot_usd": _decimal_text(ftmo_rate),
        "worst_rt_per_lot_usd": _decimal_text(calculated),
        "spread": "EMBEDDED_IN_BOUND_REAL_TICKS",
        "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
    }


def validate_infra_retry_contract(path: Path = INFRA_RETRY_CONTRACT_PATH) -> dict[str, Any]:
    payload = load_json(path)
    expected_keys = {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "candidate",
        "prior_attempt",
        "controller_preflight",
        "retry",
        "classification",
    }
    if set(payload) != expected_keys:
        raise InvalidEvidence("infra-retry contract field closure drift")
    if (
        payload.get("schema_version") != 1
        or payload.get("artifact_type") != "QM5_10834_INFRA_RETRY_CONTRACT"
        or payload.get("status") != "AUTHORIZED_ONCE"
        or payload.get("classification") != "OUTCOME_BLIND_INFRASTRUCTURE_RETRY_ONLY"
    ):
        raise InvalidEvidence("infra-retry contract identity/status drift")
    created = parse_utc(str(payload.get("created_utc", "")), "infra-retry created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("infra-retry contract creation time is implausibly in the future")
    expected_candidate = {
        "ea_id": "QM5_10834",
        "analysis_id": ANALYSIS_ID,
        "symbol": RESEARCH_SYMBOL,
        "timeframe": TIMEFRAME,
        "model": 4,
    }
    if payload.get("candidate") != expected_candidate:
        raise InvalidEvidence("infra-retry candidate identity drift")
    expected_prior = {
        "terminal": "T1",
        "run_root": str(PRIOR_INFRA_RUN_ROOT),
        "pre_receipt_sha256": PRIOR_INFRA_PRE_SHA256,
        "launch_state_sha256": PRIOR_INFRA_STATE_SHA256,
        "terminal_status": "INVALID_TERMINAL",
        "reason_classes": [
            "BARS_ZERO",
            "INCOMPLETE_RUNS",
            "HISTORY_SYNCHRONIZATION_ERROR",
        ],
        "completed_cells": 0,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
    }
    if payload.get("prior_attempt") != expected_prior:
        raise InvalidEvidence("infra-retry prior-attempt classification drift")
    expected_controller_preflight = {
        "run_root": str(CONTROLLER_PREFLIGHT_RUN_ROOT),
        "pre_receipt_sha256": CONTROLLER_PREFLIGHT_PRE_SHA256,
        "launch_state_sha256": CONTROLLER_PREFLIGHT_STATE_SHA256,
        "terminal_status": "INVALID_TERMINAL",
        "cause": "QMDEV2_ACCOUNT_DISABLED_AT_REST",
        "dev2_process_started": False,
        "dev2_run_directory_created": False,
        "native_report_created": False,
        "strategy_outcomes_read": False,
        "counts_toward_alternate_attempts": False,
        "remediation": "CONTROLLER_JIT_ENABLE_WITH_SYSTEM_TTL_CLEANUP_LEASE_AND_VERIFIED_DISARM",
    }
    if payload.get("controller_preflight") != expected_controller_preflight:
        raise InvalidEvidence("infra-retry controller-preflight classification drift")
    if payload.get("retry") != INFRA_RETRY_POLICY:
        raise InvalidEvidence("infra-retry one-shot policy drift")
    file_binding(PRIOR_INFRA_RUN_ROOT / "pre_receipt.json", PRIOR_INFRA_PRE_SHA256)
    file_binding(PRIOR_INFRA_RUN_ROOT / "launch_state.json", PRIOR_INFRA_STATE_SHA256)
    file_binding(
        CONTROLLER_PREFLIGHT_RUN_ROOT / "pre_receipt.json",
        CONTROLLER_PREFLIGHT_PRE_SHA256,
    )
    file_binding(
        CONTROLLER_PREFLIGHT_RUN_ROOT / "launch_state.json",
        CONTROLLER_PREFLIGHT_STATE_SHA256,
    )
    return payload


def execution_contract() -> dict[str, Any]:
    return {
        "terminal": EXECUTION_TERMINAL,
        "terminal_root": str(TERMINAL_ROOT.resolve()),
        "terminal_data_root": str(TERMINAL_DATA_ROOT.resolve()),
        "terminal_symbol_database": str(TERMINAL_SYMBOL_DATABASE_PATH.resolve()),
        "native_runs_root": str(DEV2_RUNS_ROOT.resolve()),
        "controller": "ISOLATED_DEV2_SCHEDULED_TASK_LANE",
        "controller_mutex": "Global\\QM_DEV2_SMOKE_CONTROLLER",
        "factory_terminal_pool_used": False,
        "maximum_alternate_attempts": 1,
        "accepted_duplicates_per_cell": DUPLICATES,
        "maximum_postflight_acceptable_infrastructure_warmups_per_cell": MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL,
        "maximum_attempts_per_cell": MAX_ATTEMPTS_PER_CELL,
        "maximum_native_starts": len(WINDOWS) * MAX_ATTEMPTS_PER_CELL,
        "native_start_budget_is_outcome_independent": True,
        "postflight_acceptable_infrastructure_warmup_verdicts": ["BARS_ZERO", "NO_HISTORY"],
        "postflight_rejects_every_nonprefix_or_nonzero_warmup": True,
        "native_attempt_claim_path": str(NATIVE_ATTEMPT_CLAIM_PATH.resolve()),
        "native_attempt_claim_mode": "ATOMIC_CREATE_ONCE_BEFORE_FIRST_CONTROLLER_EXECUTION",
        "native_launch_lock_path": str(NATIVE_LAUNCH_LOCK_PATH.resolve()),
        "native_launch_lock_mode": "GLOBAL_WINDOWS_BYTE_LOCK_AROUND_LAUNCH_AND_RESUME",
    }


def build_plan(symbol: str, set_binding: Mapping[str, Any], run_root: Path) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    validate_window_contract()
    cells = []
    for window in WINDOWS:
        cells.append(
            {
                "cell_id": f"{symbol.replace('.', '_')}_{window.cell_id}",
                "symbol": symbol,
                "cohort": window.cohort,
                "from_date": window.from_date.isoformat(),
                "to_date": window.to_date.isoformat(),
                "timeframe": TIMEFRAME,
                "model": 4,
                "duplicates": DUPLICATES,
                "maximum_postflight_acceptable_infrastructure_warmups": MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL,
                "maximum_attempts": MAX_ATTEMPTS_PER_CELL,
                "native_start_budget_is_outcome_independent": True,
                "set": dict(set_binding),
                "output_root": str((run_root / "native" / window.cell_id).resolve()),
            }
        )
    plan_basis = {
        "single_authorized_symbol": symbol,
        "cells": cells,
        "accepted_duplicate_run_count": len(cells) * DUPLICATES,
        "maximum_native_starts": len(cells) * MAX_ATTEMPTS_PER_CELL,
        "technical_prescreen": {
            "authorized": False,
            "merit_eligible": False,
            "note": "Any future prescreen requires a separate receipt and cannot enter these gates.",
        },
    }
    return {**plan_basis, "plan_sha256": canonical_sha256(plan_basis)}


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    set_path = EA_ROOT / "sets" / f"{EXPERT_NAME}_{symbol}_M5_backtest.set"
    return {
        "card": CARD_PATH,
        "pine": PINE_PATH,
        "spec": SPEC_PATH,
        "mq5": MQ5_PATH,
        "ex5": EX5_PATH,
        "set": set_path,
        "matrix": MATRIX_PATH,
        "cost": COST_PATH,
        "live_commission": LIVE_COMMISSION_PATH,
        "v5_framework": V5_FRAMEWORK_PATH,
        "backtest_rules": BACKTEST_RULES_PATH,
        "aliases": ALIASES_PATH,
        "rebuild_done": NDX_REBUILD_DONE_PATH,
        "rebuild_source": NDX_REBUILD_SOURCE_PATH,
        "runner": RUNNER_PATH,
        "runner_child": RUNNER_CHILD_PATH,
        "dev2_cleanup_helper": DEV2_CLEANUP_HELPER_PATH,
        "runner_smoke": RUN_SMOKE_PATH,
        "dev2_lane_contract": DEV2_LANE_CONTRACT_PATH,
        "tester_groups_canonical": TESTER_GROUPS_CANONICAL_PATH,
        "tester_groups_dev2": TESTER_GROUPS_DEV2_PATH,
        "dev2_symbol_database": TERMINAL_SYMBOL_DATABASE_PATH,
        "infra_retry_contract": INFRA_RETRY_CONTRACT_PATH,
        "report_parser": REPORT_CORE_PATH,
        "powershell": POWERSHELL_PATH,
        "python": PYTHON_PATH,
        "scheduled_task_helper": SCHEDULED_TASK_HELPER_PATH,
        "tool": TOOL_PATH,
    }


def _binding_map(symbol: str) -> dict[str, dict[str, Any]]:
    paths = _expected_binding_paths(symbol)
    return {
        role: file_binding(path, EXPECTED_PINE_SHA256 if role == "pine" else None)
        for role, path in paths.items()
    }


def preflight(
    symbol: str,
    data_receipt_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    run_root = _assert_run_root(run_root)
    _assert_native_attempt_unclaimed("PRE")
    if run_root.exists() and any(run_root.iterdir()):
        raise InvalidEvidence(f"run root is not empty: {run_root}")
    bindings = _binding_map(symbol)
    if bindings["tester_groups_dev2"]["sha256"] != bindings["tester_groups_canonical"]["sha256"]:
        raise InvalidEvidence("DEV2 tester groups are not canonical before PRE")
    card_text = CARD_PATH.read_text(encoding="utf-8-sig")
    if "ea_id: QM5_10834" not in card_text or "g0_status: APPROVED" not in card_text:
        raise InvalidEvidence("approved Card identity/status drift")
    spec_text = SPEC_PATH.read_text(encoding="utf-8-sig")
    if EXPECTED_PINE_SHA256 not in spec_text or "d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7" not in spec_text:
        raise InvalidEvidence("SPEC no longer binds the frozen Pine/source identity")
    includes = include_closure(MQ5_PATH)
    metadata, set_inputs = parse_set(Path(bindings["set"]["path"]))
    _validate_set_contract(symbol, metadata, set_inputs)
    effective_inputs = effective_input_contract(MQ5_PATH, includes, set_inputs)
    if effective_inputs.get("InpQMSimCommissionPerLot", {}).get("canonical") != "0":
        raise InvalidEvidence("EA-side simulated commission must be zero for external cost ledger")
    build_receipt = validate_build_receipt(build_receipt_path, symbol, bindings)
    data = validate_backtest_data_receipt(data_receipt_path, symbol)
    infra_retry = validate_infra_retry_contract()
    if bindings["infra_retry_contract"] != file_binding(INFRA_RETRY_CONTRACT_PATH):
        raise InvalidEvidence("PRE infra-retry contract binding drift")
    factory_binding_drift = {
        role: (bindings[role], data["factory_evidence"].get(role))
        for role in DATA_FACTORY_EVIDENCE_ROLES
        if bindings[role] != data["factory_evidence"].get(role)
    }
    if factory_binding_drift:
        raise InvalidEvidence(
            f"PRE/data-receipt Factory binding drift: {factory_binding_drift}"
        )
    matrix_row = _matrix_row(symbol)
    cost_schedule = resolve_cost_schedule(COST_PATH, symbol)
    if data["namespace_contract"].get("matrix_row") != matrix_row:
        raise InvalidEvidence("data receipt/matrix research namespace drift")
    if data["cost_schedule"] != cost_schedule:
        raise InvalidEvidence("data receipt/current venue cost contract drift")
    plan = build_plan(symbol, bindings["set"], run_root)
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_10834_OUTCOME_FENCED_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "run_root": str(run_root),
        "symbol_policy": {
            "authorized_symbols_exactly_one": True,
            "authorized_symbol": symbol,
            "research_backtest_policy": SYMBOL_POLICY[symbol],
            "dwx_suffix_removed_only_at_deploy_packaging": True,
            "live_aliases": {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"},
            "live_ohlc_tail_parity_required_for_research_merit": False,
            "matrix_row": matrix_row,
        },
        "outcome_fence": {
            "native_reports_opened": False,
            "deal_rows_parsed": False,
            "market_values_parsed": False,
            "mt5_terminal_started": False,
            "metatester_started": False,
        },
        "bindings": bindings,
        "include_closure": includes,
        "build_receipt": file_binding(build_receipt_path),
        "build_commit": build_receipt["build_commit"],
        "backtest_data_receipt": data["receipt"],
        "data": data,
        "execution_contract": execution_contract(),
        "infra_retry": infra_retry,
        "effective_inputs": effective_inputs,
        "cost_schedule": cost_schedule,
        "merit_contract": MERIT_GATES,
        "plan": plan,
    }


def _assert_plan(pre: Mapping[str, Any]) -> None:
    if pre.get("merit_contract") != MERIT_GATES:
        raise InvalidEvidence("PRE merit contract drift")
    policy = pre.get("symbol_policy")
    if not isinstance(policy, Mapping):
        raise InvalidEvidence("PRE symbol policy missing")
    symbol = str(policy.get("authorized_symbol", ""))
    enforce_symbol_policy(symbol)
    run_root = _assert_run_root(Path(str(pre.get("run_root", ""))))
    bindings = pre.get("bindings")
    if not isinstance(bindings, Mapping) or not isinstance(bindings.get("set"), Mapping):
        raise InvalidEvidence("PRE set binding missing")
    expected = build_plan(symbol, bindings["set"], run_root)
    if pre.get("plan") != expected:
        raise InvalidEvidence("PRE plan/cell closure drift")


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    binding = file_binding(path, expected_sha256)
    pre = load_json(path)
    expected_fence = {
        "native_reports_opened": False,
        "deal_rows_parsed": False,
        "market_values_parsed": False,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }
    if (
        pre.get("schema_version") != SCHEMA_VERSION
        or pre.get("artifact_type") != "QM5_10834_OUTCOME_FENCED_PRE_RECEIPT"
        or pre.get("status") != "PASS"
        or pre.get("analysis_id") != ANALYSIS_ID
        or pre.get("outcome_fence") != expected_fence
    ):
        raise InvalidEvidence("PRE identity/outcome fence drift")
    _assert_plan(pre)
    bindings = pre.get("bindings")
    if not isinstance(bindings, Mapping):
        raise InvalidEvidence("PRE bindings missing")
    if set(bindings) != REQUIRED_BINDING_ROLES:
        raise InvalidEvidence(f"PRE binding-role closure drift: {sorted(bindings)}")
    for role, item in bindings.items():
        if not isinstance(item, Mapping):
            raise InvalidEvidence(f"PRE binding is not an object: {role}")
        assert_binding(item, f"PRE {role}")
    policy = pre["symbol_policy"]
    symbol = str(policy["authorized_symbol"])
    expected_paths = _expected_binding_paths(symbol)
    path_drift = {
        role: (str(expected_paths[role].resolve()), str(Path(str(item["path"])).resolve()))
        for role, item in bindings.items()
        if Path(str(item["path"])).resolve() != expected_paths[role].resolve()
    }
    if path_drift:
        raise InvalidEvidence(f"PRE role/path identity drift: {path_drift}")
    if bindings["tool"]["sha256"] != sha256_file(TOOL_PATH):
        raise InvalidEvidence("executing tool differs from PRE-bound runner")
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("PRE isolated DEV2 execution contract drift")
    current_retry = validate_infra_retry_contract()
    if pre.get("infra_retry") != current_retry:
        raise InvalidEvidence("PRE one-shot infra-retry contract drift")
    if bindings["infra_retry_contract"] != file_binding(INFRA_RETRY_CONTRACT_PATH):
        raise InvalidEvidence("PRE infra-retry byte binding drift")
    includes = pre.get("include_closure")
    if not isinstance(includes, list) or not includes:
        raise InvalidEvidence("PRE include closure missing")
    for index, item in enumerate(includes):
        if not isinstance(item, Mapping):
            raise InvalidEvidence("PRE include binding malformed")
        assert_binding(item, f"PRE include[{index}]")
    expected_includes = include_closure(MQ5_PATH)
    if includes != expected_includes:
        raise InvalidEvidence("PRE recursive include closure drift")
    for role in ("build_receipt", "backtest_data_receipt"):
        item = pre.get(role)
        if not isinstance(item, Mapping):
            raise InvalidEvidence(f"PRE {role} binding missing")
        assert_binding(item, f"PRE {role}")
    data = pre.get("data")
    if not isinstance(data, Mapping) or not isinstance(data.get("receipt"), Mapping):
        raise InvalidEvidence("PRE data binding missing")
    if pre["backtest_data_receipt"] != data["receipt"]:
        raise InvalidEvidence("PRE backtest-data receipt binding drift")
    validated_data = validate_backtest_data_receipt(
        Path(str(data["receipt"]["path"])),
        symbol,
    )
    if data != _jsonable(validated_data):
        raise InvalidEvidence("PRE/backtest-data semantic closure drift")
    for role in DATA_FACTORY_EVIDENCE_ROLES:
        if bindings[role] != data["factory_evidence"].get(role):
            raise InvalidEvidence(f"PRE/data-receipt Factory binding drift: {role}")
    metadata, set_inputs = parse_set(Path(str(bindings["set"]["path"])))
    _validate_set_contract(symbol, metadata, set_inputs)
    expected_inputs = effective_input_contract(MQ5_PATH, includes, set_inputs)
    if pre.get("effective_inputs") != expected_inputs:
        raise InvalidEvidence("PRE effective input closure drift")
    build = validate_build_receipt(
        Path(str(pre["build_receipt"]["path"])), symbol, bindings
    )
    if pre.get("build_commit") != build["build_commit"]:
        raise InvalidEvidence("PRE build-commit binding drift")
    expected_cost = resolve_cost_schedule(Path(str(bindings["cost"]["path"])), symbol)
    if pre.get("cost_schedule") != expected_cost:
        raise InvalidEvidence("PRE worst-venue cost schedule drift")
    matrix_row = _matrix_row(symbol, Path(str(bindings["matrix"]["path"])))
    expected_policy = {
        "authorized_symbols_exactly_one": True,
        "authorized_symbol": symbol,
        "research_backtest_policy": SYMBOL_POLICY[symbol],
        "dwx_suffix_removed_only_at_deploy_packaging": True,
        "live_aliases": {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"},
        "live_ohlc_tail_parity_required_for_research_merit": False,
        "matrix_row": matrix_row,
    }
    if policy != expected_policy:
        raise InvalidEvidence("PRE Factory research-symbol policy drift")
    created = parse_utc(str(pre.get("created_utc", "")), "PRE created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("PRE creation time is implausibly in the future")
    card_text = CARD_PATH.read_text(encoding="utf-8-sig")
    if "ea_id: QM5_10834" not in card_text or "g0_status: APPROVED" not in card_text:
        raise InvalidEvidence("PRE-bound Card is no longer approved/exact")
    spec_text = SPEC_PATH.read_text(encoding="utf-8-sig")
    if EXPECTED_PINE_SHA256 not in spec_text or "d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7" not in spec_text:
        raise InvalidEvidence("PRE-bound SPEC/source identity drift")
    if binding["sha256"] != expected_sha256.lower():
        raise InvalidEvidence("PRE binding mismatch")
    assert_binding(binding, "stable PRE receipt")
    return pre


def validate_current_research_data_gate(pre: Mapping[str, Any]) -> None:
    policy = pre.get("symbol_policy")
    data = pre.get("data")
    bindings = pre.get("bindings")
    if (
        not isinstance(policy, Mapping)
        or not isinstance(data, Mapping)
        or not isinstance(data.get("receipt"), Mapping)
        or not isinstance(bindings, Mapping)
        or not isinstance(bindings.get("matrix"), Mapping)
    ):
        raise InvalidEvidence("PRE cannot prove the current Factory research-data gate")
    symbol = str(policy.get("authorized_symbol", ""))
    enforce_symbol_policy(symbol)
    current_data = validate_backtest_data_receipt(
        Path(str(data["receipt"]["path"])),
        symbol,
    )
    if current_data != data:
        raise InvalidEvidence("current backtest-data receipt/byte closure differs from PRE")
    for role in DATA_FACTORY_EVIDENCE_ROLES:
        if bindings.get(role) != data["factory_evidence"].get(role):
            raise InvalidEvidence(f"current Factory binding differs from PRE: {role}")
    current_row = _matrix_row(symbol, Path(str(bindings["matrix"]["path"])))
    if current_row != policy.get("matrix_row"):
        raise InvalidEvidence("current research namespace row differs from PRE")
    current_cost = resolve_cost_schedule(Path(str(bindings["cost"]["path"])), symbol)
    if current_cost != data.get("cost_schedule") or current_cost != pre.get("cost_schedule"):
        raise InvalidEvidence("current venue-cost contract differs from PRE")


def _dot_date(value: str) -> str:
    return value.replace("-", ".")


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    bindings = pre["bindings"]
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("runner command requires the immutable DEV2 execution contract")
    return [
        str(Path(str(bindings["powershell"]["path"])).resolve()),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(Path(str(bindings["runner"]["path"])).resolve()),
        "-EAId",
        str(EA_ID),
        "-EALabel",
        EA_LABEL,
        "-Symbol",
        str(cell["symbol"]),
        "-Year",
        str(date.fromisoformat(str(cell["from_date"])).year),
        "-FromDate",
        _dot_date(str(cell["from_date"])),
        "-ToDate",
        _dot_date(str(cell["to_date"])),
        "-Expert",
        EXPERT_PATH,
        "-Period",
        TIMEFRAME,
        "-Runs",
        str(DUPLICATES),
        "-MinTrades",
        "0",
        "-Model",
        "4",
        "-TimeoutSeconds",
        str(RUN_TIMEOUT_SECONDS),
        "-SetFile",
        str(Path(str(cell["set"]["path"])).resolve()),
        "-CommissionPerLot",
        "0",
        "-CommissionPerSideNative",
        "0",
        "-TesterCurrencyOverride",
        "USD",
        "-TesterDepositOverride",
        str(INITIAL_BALANCE),
        "-SmokeMode",
    ]


def validate_authorization(
    path: Path,
    pre_sha256: str,
    *,
    require_current: bool = True,
    now: datetime | None = None,
) -> dict[str, Any]:
    binding = file_binding(path)
    payload = load_json(path)
    expected = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": "QM5_10834_NDX_4_CELLS_X_2_ACCEPTED_DUPLICATES_MAX_4_NATIVE_STARTS_POSTFLIGHT_MAX_2_ACCEPTABLE_INFRA_WARMUPS_MODEL4",
        "authorized_by": "OWNER",
        "authorized_symbol": RESEARCH_SYMBOL,
        "authorized_cells": [window.cell_id for window in WINDOWS],
        "duplicates_per_cell": DUPLICATES,
        "maximum_postflight_acceptable_infrastructure_warmups_per_cell": MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL,
        "maximum_attempts_per_cell": MAX_ATTEMPTS_PER_CELL,
        "maximum_native_starts": len(WINDOWS) * MAX_ATTEMPTS_PER_CELL,
        "native_start_budget_is_outcome_independent": True,
        "postflight_acceptable_infrastructure_warmup_verdicts": ["BARS_ZERO", "NO_HISTORY"],
        "postflight_warmups_must_precede_accepted_duplicates": True,
        "postflight_warmups_must_be_zero_trade_zero_result": True,
        "postflight_rejects_every_nonprefix_or_nonzero_warmup": True,
        "model": 4,
        "authorize_native_outcomes": True,
    }
    drift = {key: (wanted, payload.get(key)) for key, wanted in expected.items() if payload.get(key) != wanted}
    if drift:
        raise AuthorizationError(f"native authorization drift: {drift}")
    created = parse_utc(str(payload.get("created_utc", "")), "authorization created_utc")
    expires = parse_utc(str(payload.get("expires_utc", "")), "authorization expires_utc")
    if expires <= created or expires - created > timedelta(hours=24):
        raise AuthorizationError("authorization lifetime must be >0 and <=24 hours")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if require_current and not (created - timedelta(minutes=5) <= current <= expires):
        raise AuthorizationError("native authorization is not currently valid")
    return {"binding": binding, "payload_sha256": canonical_sha256(payload), "payload": payload}


def _assert_native_attempt_unclaimed(stage: str) -> None:
    if NATIVE_ATTEMPT_CLAIM_PATH.exists():
        raise AuthorizationError(
            f"the one-shot DEV2 native attempt is already claimed at {stage}"
        )


def _native_attempt_claim_basis(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_10834_DEV2_NATIVE_ATTEMPT_CLAIM",
        "analysis_id": ANALYSIS_ID,
        "attempt_number": 1,
        "maximum_alternate_attempts": 1,
        "accepted_duplicates_per_cell": DUPLICATES,
        "maximum_postflight_acceptable_infrastructure_warmups_per_cell": MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL,
        "maximum_attempts_per_cell": MAX_ATTEMPTS_PER_CELL,
        "maximum_native_starts": len(WINDOWS) * MAX_ATTEMPTS_PER_CELL,
        "native_start_budget_is_outcome_independent": True,
        "postflight_rejects_every_nonprefix_or_nonzero_warmup": True,
        "classification": "ATOMIC_GLOBAL_ONE_SHOT_NATIVE_EXECUTION_CLAIM",
        "pre_receipt": file_binding(pre_path, pre_sha256),
        "run_root": str(Path(str(pre["run_root"])).resolve()),
        "launch_state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "infra_retry_contract": dict(pre["bindings"]["infra_retry_contract"]),
        "ea_binary": dict(pre["bindings"]["ex5"]),
        "set": dict(pre["bindings"]["set"]),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
    }


def claim_native_attempt(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
) -> dict[str, Any]:
    payload = {
        **_native_attempt_claim_basis(
            pre_path, pre_sha256, pre, state_path, authorization
        ),
        "created_utc": utc_now(),
    }
    atomic_json(NATIVE_ATTEMPT_CLAIM_PATH, payload, replace=False)
    return file_binding(NATIVE_ATTEMPT_CLAIM_PATH)


def validate_native_attempt_claim(
    binding: Mapping[str, Any],
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
) -> dict[str, Any]:
    if Path(str(binding.get("path", ""))).resolve() != NATIVE_ATTEMPT_CLAIM_PATH.resolve():
        raise InvalidEvidence("native-attempt claim path drift")
    assert_binding(binding, "global native-attempt claim")
    payload = load_json(NATIVE_ATTEMPT_CLAIM_PATH)
    created = parse_utc(str(payload.get("created_utc", "")), "native-attempt claim created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("native-attempt claim timestamp is in the future")
    basis = dict(payload)
    basis.pop("created_utc", None)
    expected = _native_attempt_claim_basis(
        pre_path, pre_sha256, pre, state_path, authorization
    )
    if basis != expected:
        raise InvalidEvidence("native-attempt global one-shot claim drift")
    return payload


def initial_launch_state(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    job_binding: Mapping[str, Any],
    authorization: Mapping[str, Any],
    scheduler: Mapping[str, Any],
) -> dict[str, Any]:
    now = utc_now()
    return {
        "schema_version": SCHEMA_VERSION,
        "launcher_revision": LAUNCHER_REVISION,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_STATE",
        "analysis_id": ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": now,
        "updated_utc": now,
        "started_utc": None,
        "finished_utc": None,
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "job": dict(job_binding),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
        "scheduler": dict(scheduler),
        "worker_pid": None,
        "resume_count": 0,
        "active_cell": None,
        "attempt_claim": None,
        "outcome_possible_since_utc": None,
        "launches": [],
        "outcome_fence": {
            "worker_parses_market_values": False,
            "worker_parses_native_reports": False,
            "worker_seals_opaque_artifacts_only": True,
        },
        "cells": [
            {
                "cell_id": cell["cell_id"],
                "status": "PENDING",
                "command_sha256": canonical_sha256(runner_command(pre, cell)),
                "attempts": [],
            }
            for cell in pre["plan"]["cells"]
        ],
    }


def resume_eligible(state: Mapping[str, Any]) -> bool:
    """Return true only before any native cell could have produced an outcome."""
    if state.get("launcher_revision") != LAUNCHER_REVISION:
        return False
    if state.get("status") not in {"PENDING", "PENDING_RESUME", "RUNNING"}:
        return False
    if (
        state.get("finished_utc")
        or state.get("error")
        or state.get("error_type")
        or state.get("worker_error")
        or state.get("active_cell") is not None
        or state.get("attempt_claim") is not None
        or state.get("outcome_possible_since_utc") is not None
    ):
        return False
    cells = state.get("cells")
    if not isinstance(cells, list) or len(cells) != len(WINDOWS):
        return False
    for cell in cells:
        if (
            not isinstance(cell, Mapping)
            or cell.get("status") != "PENDING"
            or cell.get("attempts") != []
        ):
            return False
    return True


def scheduled_task_name(pre_sha256: str, state_path: Path) -> str:
    digest = canonical_sha256(
        {
            "analysis_id": ANALYSIS_ID,
            "pre_receipt_sha256": pre_sha256.lower(),
            "state_path": str(state_path.resolve()),
        }
    )
    return f"{SCHEDULED_TASK_PREFIX}{digest[:24]}"


def required_scheduled_task_timeout(pre: Mapping[str, Any]) -> int:
    cells = pre.get("plan", {}).get("cells") if isinstance(pre.get("plan"), Mapping) else None
    if not isinstance(cells, list) or len(cells) != len(WINDOWS):
        raise AuthorizationError("scheduled-task plan cell closure drift")
    seconds = len(cells) * CELL_CONTROLLER_TIMEOUT_SECONDS + 3600
    if not 60 <= seconds <= MAX_SCHEDULED_TASK_SECONDS:
        raise AuthorizationError("scheduled-task execution limit outside launcher contract")
    return seconds


def _parse_scheduler_json(text: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    candidates: list[dict[str, Any]] = []
    for match in re.finditer(r"\{", text):
        try:
            value, _ = decoder.raw_decode(text[match.start() :])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            candidates.append(value)
    if not candidates:
        raise AuthorizationError("persisted scheduler returned no JSON object")
    return candidates[-1]


def _scheduler_call(
    pre: Mapping[str, Any],
    operation: str,
    job: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    bindings = pre["bindings"]
    command = [
        str(bindings["powershell"]["path"]),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(bindings["scheduled_task_helper"]["path"]),
        "-Operation",
        operation,
    ]
    scheduler: Mapping[str, Any] | None = None
    if operation != "Identity":
        if job is None or not isinstance(job.get("scheduler"), Mapping):
            raise AuthorizationError("scheduled-task job contract is missing")
        scheduler = job["scheduler"]
        command.extend(
            [
                "-TaskName",
                str(scheduler["task_name"]),
                "-PythonExe",
                str(bindings["python"]["path"]),
                "-ToolPath",
                str(bindings["tool"]["path"]),
                "-JobPath",
                str(Path(str(job["state_path"])).with_name("launch_job.json")),
                "-RepoRoot",
                str(REPO_ROOT),
                "-ExecutionLimitSeconds",
                str(scheduler["execution_limit_seconds"]),
            ]
        )
    completed = subprocess.run(
        command,
        cwd=str(REPO_ROOT),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=30,
        check=False,
    )
    if completed.returncode != 0:
        raise AuthorizationError(
            f"persisted scheduler {operation!r} failed with exit {completed.returncode}"
        )
    payload = _parse_scheduler_json(completed.stdout)
    if payload.get("operation") != operation:
        raise AuthorizationError("persisted scheduler returned an unexpected operation")
    if operation == "Identity":
        if (
            not str(payload.get("principal_sid", "")).startswith("S-1-")
            or payload.get("logon_type") != "S4U"
            or payload.get("run_level") != "Highest"
        ):
            raise AuthorizationError("persisted scheduler identity contract drift")
    elif scheduler is not None:
        if (
            payload.get("task_name") != scheduler["task_name"]
            or payload.get("principal_sid") != scheduler["principal_sid"]
            or payload.get("logon_type") != "S4U"
            or payload.get("run_level") != "Highest"
            or payload.get("multiple_instances") != "IgnoreNew"
            or int(payload.get("execution_limit_seconds", 0))
            != int(scheduler["execution_limit_seconds"])
        ):
            raise AuthorizationError("persisted scheduler task metadata drift")
        if operation == "Start" and payload.get("fresh_start_ack") is not True:
            raise AuthorizationError("persisted scheduler did not prove a fresh task start")
    return payload


def _validate_launch_job(
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
) -> None:
    scheduler = job.get("scheduler")
    expected_scheduler = {
        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
        "task_name": scheduled_task_name(pre_sha256, state_path),
        "task_path": "\\",
        "principal_sid": str(scheduler.get("principal_sid", ""))
        if isinstance(scheduler, Mapping)
        else "",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": required_scheduled_task_timeout(pre),
        "helper": pre["bindings"]["scheduled_task_helper"],
        "python": pre["bindings"]["python"],
    }
    expected = {
        "schema_version": SCHEMA_VERSION,
        "launcher_revision": LAUNCHER_REVISION,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_JOB",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "tool": pre["bindings"]["tool"],
        "scheduler": expected_scheduler,
    }
    allowed_keys = set(expected) | {"created_utc", "authorization"}
    if set(job) != allowed_keys:
        raise AuthorizationError("persisted launch job field closure drift")
    drift = {
        key: (value, job.get(key))
        for key, value in expected.items()
        if job.get(key) != value
    }
    if drift:
        raise AuthorizationError(
            f"persisted launch job identity/plan/tool drift: {sorted(drift)}"
        )
    if not expected_scheduler["principal_sid"].startswith("S-1-"):
        raise AuthorizationError("persisted launch job principal SID is malformed")
    created = parse_utc(str(job.get("created_utc", "")), "launch job created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuthorizationError("persisted launch job timestamp is in the future")
    authorization = job.get("authorization")
    if (
        not isinstance(authorization, Mapping)
        or set(authorization) != {"binding", "payload_sha256"}
        or not isinstance(authorization.get("binding"), Mapping)
        or not re.fullmatch(r"[0-9a-f]{64}", str(authorization.get("payload_sha256", "")))
    ):
        raise AuthorizationError("persisted launch authorization identity is malformed")


def _assert_resume_outcome_fence(
    state: Mapping[str, Any],
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    state_path: Path,
) -> None:
    if not resume_eligible(state):
        raise AuthorizationError("launch state crossed the pre-outcome resume fence")
    if (
        state.get("job") != file_binding(state_path.with_name("launch_job.json"))
        or state.get("authorization") != job.get("authorization")
        or state.get("scheduler") != job.get("scheduler")
        or state.get("pre_receipt_path") != job.get("pre_receipt_path")
        or state.get("pre_receipt_sha256") != job.get("pre_receipt_sha256")
        or state.get("plan_sha256") != job.get("plan_sha256")
    ):
        raise AuthorizationError("resume state/immutable launch job drift")
    for cell in pre["plan"]["cells"]:
        output_root = Path(str(cell["output_root"])).resolve()
        if output_root.exists() and next(output_root.rglob("*"), None) is not None:
            raise AuthorizationError("native worker artifact tree is non-empty; resume is forbidden")


def _refresh_resume_state_after_inspect(
    inspected: Mapping[str, Any],
    state_path: Path,
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    pre_path: Path,
    pre_sha256: str,
    authorization_identity: Mapping[str, Any],
) -> dict[str, Any]:
    if inspected.get("state") != "Ready":
        raise AuthorizationError(
            f"persisted audit task is not exactly Ready: {inspected.get('state')!r}"
        )
    # Inspect may race a previous launcher invocation or the scheduled worker.
    # Re-read all mutable state while the global launcher lock is still held,
    # then repeat every pre-outcome/CAS guard immediately before replacement.
    state = load_json(state_path)
    _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    if job.get("authorization") != authorization_identity:
        raise AuthorizationError("resume authorization differs from immutable launch job")
    _assert_resume_outcome_fence(state, job, pre, state_path)
    _assert_native_attempt_unclaimed("native resume CAS")
    return state


def _launch_detached_locked(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    validate_current_research_data_gate(pre)
    expected_state = Path(str(pre["run_root"])).resolve() / "launch_state.json"
    if state_path.resolve() != expected_state:
        raise AuthorizationError(f"state path must be {expected_state}")
    authorization = validate_authorization(authorization_path, pre_sha256)
    authorization_identity = {
        "binding": authorization["binding"],
        "payload_sha256": authorization["payload_sha256"],
    }
    _assert_native_attempt_unclaimed("native launch")
    job_path = Path(str(pre["run_root"])).resolve() / "launch_job.json"
    if resume:
        if not state_path.is_file() or not job_path.is_file():
            raise AuthorizationError("resume requires the existing state and immutable job")
        job = load_json(job_path)
        state = load_json(state_path)
        _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
        if job.get("authorization") != authorization_identity:
            raise AuthorizationError("resume authorization differs from immutable launch job")
        _assert_resume_outcome_fence(state, job, pre, state_path)
        _scheduler_call(pre, "Register", job)
        inspected = _scheduler_call(pre, "Inspect", job)
        state = _refresh_resume_state_after_inspect(
            inspected,
            state_path,
            job,
            pre,
            pre_path,
            pre_sha256,
            authorization_identity,
        )
        state["status"] = "PENDING_RESUME"
        state["worker_pid"] = None
        state["resume_count"] = int(state.get("resume_count", 0)) + 1
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        started = _scheduler_call(pre, "Start", job)
        observed = load_json(state_path)
        return {
            "status": "RESUMED_PERSISTED_TASK",
            "task_name": job["scheduler"]["task_name"],
            "scheduler_state": started.get("state"),
            "worker_pid": observed.get("worker_pid"),
            "state": str(state_path),
            "job": str(job_path),
        }

    if state_path.exists():
        raise AuthorizationError(f"refusing to replace launch state: {state_path}")
    if job_path.exists():
        raise AuthorizationError(f"refusing to replace launch job: {job_path}")
    identity = _scheduler_call(pre, "Identity")
    scheduler = {
        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
        "task_name": scheduled_task_name(pre_sha256, state_path),
        "task_path": "\\",
        "principal_sid": identity["principal_sid"],
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": required_scheduled_task_timeout(pre),
        "helper": pre["bindings"]["scheduled_task_helper"],
        "python": pre["bindings"]["python"],
    }
    job = {
        "schema_version": SCHEMA_VERSION,
        "launcher_revision": LAUNCHER_REVISION,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_JOB",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "authorization": authorization_identity,
        "tool": pre["bindings"]["tool"],
        "scheduler": scheduler,
    }
    _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    atomic_json(job_path, job, replace=False)
    state = initial_launch_state(
        pre_path,
        pre_sha256,
        pre,
        file_binding(job_path),
        authorization,
        scheduler,
    )
    atomic_json(state_path, state, replace=False)
    _scheduler_call(pre, "Register", job)
    started = _scheduler_call(pre, "Start", job)
    observed = load_json(state_path)
    return {
        "status": "LAUNCHED_PERSISTED_TASK",
        "task_name": scheduler["task_name"],
        "scheduler_state": started.get("state"),
        "worker_pid": observed.get("worker_pid"),
        "state": str(state_path.resolve()),
        "job": str(job_path.resolve()),
    }


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    with native_launch_lock():
        return _launch_detached_locked(
            pre_path,
            pre_sha256,
            authorization_path,
            state_path,
            resume=resume,
        )


def _opaque_artifacts(root: Path) -> list[dict[str, Any]]:
    if not root.is_dir():
        return []
    return [
        file_binding(path)
        for path in sorted(root.rglob("*"), key=lambda item: str(item).casefold())
        if path.is_file()
    ]


def _outcome_artifact_paths(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(
        (
            path
            for path in root.rglob("*")
            if path.is_file()
            and (path.name.casefold() == "summary.json" or path.suffix.casefold() in {".htm", ".html"})
        ),
        key=lambda item: str(item).casefold(),
    )


def _safe_error_message(exc: Exception) -> str:
    if isinstance(exc, subprocess.TimeoutExpired):
        return "native controller exceeded the fenced outer timeout"
    if isinstance(exc, subprocess.CalledProcessError):
        return f"native controller returned exit code {exc.returncode}"
    return str(exc)


def _parse_dev2_controller_json(text: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    required_keys = {
        "schema_version",
        "run_id",
        "success",
        "run_smoke_exit_code",
        "lane_contract_sha256",
        "child_sha256",
        "run_smoke_sha256",
        "agent_port_proof",
        "tester_groups_post_child_sha256",
        "tester_groups_restored_sha256",
        "dev2_account_initially_enabled",
        "dev2_account_restored_disabled",
    }
    candidates: list[dict[str, Any]] = []
    for match in re.finditer(r"\{", text):
        try:
            value, _ = decoder.raw_decode(text[match.start() :])
        except json.JSONDecodeError:
            continue
        if (
            isinstance(value, dict)
            and required_keys.issubset(value)
            and value.get("schema_version") == 2
            and type(value.get("success")) is bool
            and re.fullmatch(
                r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", str(value.get("run_id", ""))
            )
            and isinstance(value.get("agent_port_proof"), Mapping)
        ):
            candidates.append(value)
    if len(candidates) != 1:
        raise InvalidEvidence(
            "DEV2 controller stdout must contain exactly one controller result "
            f"envelope; found {len(candidates)}"
        )
    return candidates[0]


def validate_dev2_controller_result(
    result: Mapping[str, Any], pre: Mapping[str, Any]
) -> str:
    if (
        result.get("schema_version") != 2
        or result.get("success") is not True
        or result.get("run_smoke_exit_code") != 0
    ):
        raise InvalidEvidence("DEV2 controller did not return a successful run_smoke result")
    run_id = str(result.get("run_id", ""))
    if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", run_id):
        raise InvalidEvidence("DEV2 controller returned a malformed run_id")
    bindings = pre["bindings"]
    expected_hashes = {
        "lane_contract_sha256": bindings["dev2_lane_contract"]["sha256"],
        "child_sha256": bindings["runner_child"]["sha256"],
        "run_smoke_sha256": bindings["runner_smoke"]["sha256"],
        "cleanup_helper_sha256": bindings["dev2_cleanup_helper"]["sha256"],
    }
    drift = {
        key: (expected, str(result.get(key, "")).lower())
        for key, expected in expected_hashes.items()
        if str(result.get(key, "")).lower() != expected
    }
    if drift:
        raise InvalidEvidence(f"DEV2 controller runtime binding drift: {drift}")
    expected_group_hash = bindings["tester_groups_canonical"]["sha256"]
    group_hashes = {
        str(result.get("tester_groups_post_child_sha256", "")).lower(),
        str(result.get("tester_groups_restored_sha256", "")).lower(),
    }
    if group_hashes != {expected_group_hash}:
        raise InvalidEvidence("DEV2 tester-groups restore proof drift")
    if (
        result.get("dev2_account_initially_enabled") is not False
        or result.get("dev2_account_enabled_by_controller") is not True
        or result.get("dev2_account_restored_disabled") is not True
        or result.get("cleanup_lease_registered") is not True
        or result.get("cleanup_lease_disarmed") is not True
    ):
        raise InvalidEvidence("DEV2 disabled-at-rest cleanup-lease lifecycle proof drift")
    return run_id


def _dev2_native_root(run_id: str) -> Path:
    if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", run_id):
        raise InvalidEvidence("malformed DEV2 run_id")
    root = (DEV2_RUNS_ROOT / run_id).resolve()
    if not _is_within(root, DEV2_RUNS_ROOT):
        raise InvalidEvidence("DEV2 native run root escaped its isolated lane")
    return root


def _find_dev2_summary(run_id: str) -> Path:
    root = _dev2_native_root(run_id) / "output" / "smoke"
    summaries = sorted(
        summary.resolve()
        for ea_dir in (f"QM5_{EA_ID}", EXPERT_NAME)
        for summary in (root / ea_dir).glob("*/summary.json")
    )
    if len(summaries) != 1:
        raise InvalidEvidence(
            f"expected one QM5_10834 DEV2 summary for {run_id}, found {len(summaries)}"
        )
    return summaries[0]


def _claim_worker_bootstrap_state(
    state_path: Path,
    job_binding: Mapping[str, Any],
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    authorization_identity: Mapping[str, Any],
) -> dict[str, Any]:
    with native_launch_lock():
        state = load_json(state_path)
        if state.get("status") not in {"PENDING", "PENDING_RESUME"}:
            raise AuthorizationError("scheduled worker was not armed by the launcher")
        _assert_resume_outcome_fence(state, job, pre, state_path)
        if state.get("job") != job_binding:
            raise AuthorizationError("worker state/job byte binding drift")
        was_resume = state["status"] == "PENDING_RESUME"
        now = utc_now()
        state["worker_pid"] = os.getpid()
        state["status"] = "RUNNING"
        state["started_utc"] = state.get("started_utc") or now
        state["updated_utc"] = now
        launches = state.get("launches")
        if not isinstance(launches, list):
            raise AuthorizationError("worker launch audit list is malformed")
        launches.append(
            {
                "worker_pid": os.getpid(),
                "started_utc": now,
                "resume": was_resume,
                "authorization": dict(authorization_identity),
                "scheduler": job["scheduler"],
            }
        )
        atomic_json(state_path, state, replace=True)
        return state


def _worker_run(job_path: Path) -> int:
    state: dict[str, Any] | None = None
    state_path: Path | None = None
    try:
        job_path = job_path.resolve()
        job_binding = file_binding(job_path)
        job = load_json(job_path)
        state_path = Path(str(job["state_path"])).resolve()
        pre_path = Path(str(job["pre_receipt_path"])).resolve()
        pre_sha = str(job["pre_receipt_sha256"]).lower()
        pre = assert_pre_receipt(pre_path, pre_sha)
        validate_current_research_data_gate(pre)
        if state_path != Path(str(pre["run_root"])).resolve() / "launch_state.json":
            raise AuthorizationError("worker state path escaped the PRE run root")
        _validate_launch_job(job, pre, pre_path, pre_sha, state_path)
        active_authorization = validate_authorization(
            Path(str(job["authorization"]["binding"]["path"])), pre_sha
        )
        authorization_identity = {
            "binding": active_authorization["binding"],
            "payload_sha256": active_authorization["payload_sha256"],
        }
        if authorization_identity != job["authorization"]:
            raise AuthorizationError("persisted worker authorization drift")
        state = _claim_worker_bootstrap_state(
            state_path,
            job_binding,
            job,
            pre,
            authorization_identity,
        )
    except (OSError, subprocess.SubprocessError, AuditError, KeyError, TypeError, ValueError) as exc:
        if state is not None and state_path is not None:
            state["status"] = "INVALID_WORKER_BOOTSTRAP"
            state["worker_pid"] = None
            state["worker_error"] = {
                "type": type(exc).__name__,
                "message": _safe_error_message(exc),
            }
            state["updated_utc"] = utc_now()
            atomic_json(state_path, state, replace=True)
        return 2
    cell_by_id = {str(cell["cell_id"]): cell for cell in pre["plan"]["cells"]}
    try:
        for state_cell in state["cells"]:
            # Re-seal every moving PRE/data/runtime byte before each native cell.
            assert_pre_receipt(pre_path, pre_sha)
            validate_current_research_data_gate(pre)
            if file_binding(job_path) != job_binding:
                raise InvalidEvidence("immutable launch job drift before native cell")
            if state_cell["status"] != "PENDING":
                raise InvalidEvidence(f"worker encountered non-resumable cell: {state_cell}")
            cell = cell_by_id[str(state_cell["cell_id"])]
            command = runner_command(pre, cell)
            if canonical_sha256(command) != state_cell["command_sha256"]:
                raise InvalidEvidence("worker command binding drift")
            output_root = Path(str(cell["output_root"])).resolve()
            if output_root.exists() and any(output_root.iterdir()):
                raise InvalidEvidence(f"cell output root is not empty: {output_root}")
            output_root.mkdir(parents=True, exist_ok=True)
            stdout_path = output_root / "controller.stdout.log"
            stderr_path = output_root / "controller.stderr.log"
            started = utc_now()
            attempt: dict[str, Any] = {
                "started_utc": started,
                "command_sha256": canonical_sha256(command),
                "summary": None,
                "outcome_artifacts": [],
                "native_root": None,
                "runner_result": None,
            }
            state_cell["status"] = "RUNNING"
            state_cell["attempts"].append(attempt)
            state["active_cell"] = {
                "cell_id": state_cell["cell_id"],
                "command_sha256": state_cell["command_sha256"],
                "started_utc": started,
                "status": "OUTCOME_POSSIBLE_NO_RESUME",
            }
            state["outcome_possible_since_utc"] = (
                state.get("outcome_possible_since_utc") or started
            )
            state["updated_utc"] = started
            # This atomic checkpoint precedes subprocess.run.  Once present, no
            # launch/resume path may execute a native cell again.
            atomic_json(state_path, state, replace=True)
            if state.get("attempt_claim") is None:
                state["attempt_claim"] = claim_native_attempt(
                    pre_path,
                    pre_sha,
                    pre,
                    state_path,
                    authorization_identity,
                )
                state["updated_utc"] = utc_now()
                atomic_json(state_path, state, replace=True)
            else:
                validate_native_attempt_claim(
                    state["attempt_claim"],
                    pre_path,
                    pre_sha,
                    pre,
                    state_path,
                    authorization_identity,
                )
            with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
                completed = subprocess.run(
                    command,
                    cwd=str(REPO_ROOT),
                    stdin=subprocess.DEVNULL,
                    stdout=stdout,
                    stderr=stderr,
                    check=False,
                    timeout=CELL_CONTROLLER_TIMEOUT_SECONDS,
                )
            attempt["finished_utc"] = utc_now()
            attempt["exit_code"] = int(completed.returncode)
            attempt["stdout"] = file_binding(stdout_path)
            attempt["stderr"] = file_binding(stderr_path)
            if completed.returncode != 0:
                state_cell["status"] = "INVALID_TERMINAL_OUTPUT"
                state["status"] = "INVALID_TERMINAL"
                state["worker_pid"] = None
                state["updated_utc"] = utc_now()
                atomic_json(state_path, state, replace=True)
                return 2
            runner_result = _parse_dev2_controller_json(
                stdout_path.read_text(encoding="utf-8-sig", errors="replace")
            )
            run_id = validate_dev2_controller_result(runner_result, pre)
            native_root = _dev2_native_root(run_id)
            summary_path = _find_dev2_summary(run_id)
            outcome_files = [
                path
                for path in _outcome_artifact_paths(native_root)
                if path.name.casefold() != "summary.json"
            ]
            attempt["runner_result"] = runner_result
            attempt["native_root"] = str(native_root)
            attempt["summary"] = file_binding(summary_path)
            attempt["outcome_artifacts"] = [
                file_binding(path) for path in sorted(outcome_files)
            ]
            attempt["sealed_artifacts"] = sorted(
                _opaque_artifacts(output_root) + _opaque_artifacts(native_root),
                key=lambda item: str(item["path"]).casefold(),
            )
            state_cell["status"] = "COMPLETE"
            state["active_cell"] = None
            state["updated_utc"] = utc_now()
            atomic_json(state_path, state, replace=True)
        state["status"] = "COMPLETE"
        state["worker_pid"] = None
        state["active_cell"] = None
        state["finished_utc"] = utc_now()
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        return 0
    except (OSError, subprocess.SubprocessError, AuditError, KeyError, TypeError, ValueError) as exc:
        current = next((row for row in state.get("cells", []) if row.get("status") == "RUNNING"), None)
        if current is not None:
            attempt = current.get("attempts", [{}])[-1]
            native_value = attempt.get("native_root") if isinstance(attempt, Mapping) else None
            native_root = Path(str(native_value)).resolve() if native_value else None
            summaries = (
                list(native_root.rglob("summary.json"))
                if native_root is not None and native_root.exists()
                else []
            )
            reports = [
                path
                for path in _outcome_artifact_paths(native_root)
                if path.name.casefold() != "summary.json"
            ] if native_root is not None else []
            attempt["error_type"] = type(exc).__name__
            attempt["error"] = _safe_error_message(exc)
            attempt["summary"] = file_binding(summaries[0]) if len(summaries) == 1 else None
            attempt["outcome_artifacts"] = [file_binding(path) for path in reports]
            current["status"] = "INVALID_TERMINAL_OUTPUT"
            state["status"] = "INVALID_TERMINAL"
        else:
            state["status"] = "INVALID_TERMINAL"
        state["worker_pid"] = None
        state["worker_error"] = {
            "type": type(exc).__name__,
            "message": _safe_error_message(exc),
        }
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        return 2


def _load_report_core(pre: Mapping[str, Any]) -> Any:
    binding = pre["bindings"]["report_parser"]
    assert_binding(binding, "report parser")
    spec = importlib.util.spec_from_file_location("qm10834_bound_report_core", binding["path"])
    if spec is None or spec.loader is None:
        raise InvalidEvidence("cannot load bound MT5 report parser")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _report_inputs(core: Any, settings: Sequence[Sequence[str]]) -> tuple[list[str], dict[str, str]]:
    start: tuple[int, int] | None = None
    for row_index, row in enumerate(settings):
        for cell_index, cell in enumerate(row):
            if core._norm(cell) in core.FIELD_ALIASES["inputs"]:
                if start is not None:
                    raise InvalidEvidence("multiple native report Inputs sections")
                start = (row_index, cell_index)
    if start is None:
        raise InvalidEvidence("native report Inputs section is missing")
    row_index, cell_index = start
    values = [
        core._clean_text(value)
        for value in settings[row_index][cell_index + 1 :]
        if core._clean_text(value)
    ]
    for row in settings[row_index + 1 :]:
        if row and core._clean_text(row[0]):
            break
        values.extend(
            core._clean_text(value) for value in row[1:] if core._clean_text(value)
        )
    if not values:
        raise InvalidEvidence("native report Inputs section is empty")
    mapping: dict[str, str] = {}
    ordered: list[str] = []
    for value in values:
        text = core._clean_text(str(value))
        ordered.append(text)
        if "=" not in text:
            continue
        key, rendered = text.split("=", 1)
        key = key.strip()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if key in mapping:
            raise InvalidEvidence(f"duplicate report input: {key}")
        mapping[key] = rendered.strip()
    return ordered, mapping


def _field_after(core: Any, rows: Sequence[Sequence[str]], aliases: Iterable[str]) -> str | None:
    normalized = {core._norm(value) for value in aliases}
    found: list[str] = []
    for row in rows:
        for index, cell in enumerate(row[:-1]):
            if core._norm(cell) in normalized:
                value = core._clean_text(row[index + 1])
                if value:
                    found.append(value)
    unique = list(dict.fromkeys(found))
    if len(unique) > 1:
        raise InvalidEvidence(f"ambiguous report field {sorted(normalized)}: {unique}")
    return unique[0] if unique else None


def _actual_input_canonical(value: str, contract: Mapping[str, str]) -> str:
    rendered = value.strip()
    expected_raw = str(contract["raw"])
    expected_canonical = str(contract["canonical"])
    if rendered == expected_raw or rendered == expected_canonical:
        return expected_canonical
    if rendered.casefold() in {"true", "false"}:
        return rendered.casefold()
    try:
        return _decimal_text(Decimal(rendered))
    except InvalidOperation:
        return rendered


def broker_to_new_york(broker_time: datetime) -> datetime:
    # Darwinex New-York-close server time is UTC+2/+3 while New York is UTC-5/-4.
    # Both transitions follow the US calendar, so the difference is always 7h.
    return broker_time - timedelta(hours=7)


def _reconstruct_trades(
    deals: Sequence[Any], symbol: str, cost_rt_per_lot: Decimal
) -> list[TradeRecord]:
    trades: list[TradeRecord] = []
    open_lot: dict[str, Any] | None = None
    for deal in deals:
        if not deal.direction:
            continue
        if deal.symbol != symbol or deal.volume is None or deal.volume <= ZERO:
            raise InvalidEvidence(f"invalid/cross-symbol trading Deal: {deal.deal}")
        if deal.commission != ZERO:
            raise InvalidEvidence(f"DOUBLE_COUNT_REJECT native commission: Deal {deal.deal}")
        if deal.swap != ZERO:
            raise InvalidEvidence(f"intraday candidate has non-zero swap: Deal {deal.deal}")
        if deal.direction == "in":
            if open_lot is not None:
                raise InvalidEvidence("overlapping/pyramided opening Deals are forbidden")
            if deal.kind not in {"buy", "sell"}:
                raise InvalidEvidence(f"opening Deal has unsupported type: {deal.kind}")
            open_lot = {
                "deal": deal.deal,
                "side": deal.kind,
                "entry_time": deal.time,
                "initial_volume": deal.volume,
                "remaining": deal.volume,
                "native_net": deal.raw_net,
                "exit_deals": [],
            }
            continue
        if deal.direction != "out" or open_lot is None:
            raise InvalidEvidence(f"orphan/unsupported closing Deal: {deal.deal}")
        if deal.volume > open_lot["remaining"]:
            raise InvalidEvidence(f"closing volume exceeds open volume: Deal {deal.deal}")
        open_lot["remaining"] -= deal.volume
        open_lot["native_net"] += deal.raw_net
        open_lot["exit_deals"].append(deal.deal)
        if open_lot["remaining"] == ZERO:
            entry_ny = broker_to_new_york(open_lot["entry_time"])
            exit_ny = broker_to_new_york(deal.time)
            cost = _money(cost_rt_per_lot * open_lot["initial_volume"])
            native_net = _money(open_lot["native_net"])
            trades.append(
                TradeRecord(
                    sequence=len(trades) + 1,
                    symbol=symbol,
                    side=open_lot["side"],
                    entry_deal=open_lot["deal"],
                    exit_deals=tuple(open_lot["exit_deals"]),
                    entry_time_broker=open_lot["entry_time"],
                    exit_time_broker=deal.time,
                    entry_time_ny=entry_ny,
                    exit_time_ny=exit_ny,
                    new_york_day=entry_ny.date().isoformat(),
                    volume=open_lot["initial_volume"],
                    native_net_usd=native_net,
                    venue_cost_usd=cost,
                    adjusted_net_usd=_money(native_net - cost),
                )
            )
            open_lot = None
    if open_lot is not None:
        raise InvalidEvidence(f"position remains open after report end: {open_lot['deal']}")
    return trades


def validate_trade_semantics(trades: Sequence[TradeRecord]) -> dict[str, Any]:
    per_day: dict[str, int] = defaultdict(int)
    for trade in trades:
        entry_clock = trade.entry_time_ny.time()
        exit_clock = trade.exit_time_ny.time()
        if not (NY_ENTRY_START <= entry_clock < NY_ENTRY_END):
            raise InvalidEvidence(
                f"entry outside half-open NY session: {trade.entry_deal}/{entry_clock}"
            )
        if trade.entry_time_ny.date() != trade.exit_time_ny.date():
            raise InvalidEvidence(f"position was not flat on its NY entry day: {trade.entry_deal}")
        if exit_clock >= NY_FLAT_DEADLINE_EXCLUSIVE:
            raise InvalidEvidence(
                f"position not flat inside the one-M5-bar execution grace: {trade.entry_deal}/{exit_clock}"
            )
        if trade.exit_time_broker < trade.entry_time_broker:
            raise InvalidEvidence(f"negative holding time: {trade.entry_deal}")
        per_day[trade.new_york_day] += 1
    offenders = {day: count for day, count in per_day.items() if count > 1}
    if offenders:
        raise InvalidEvidence(f"more than one entry per New York day: {offenders}")
    return {
        "status": "PASS",
        "one_entry_per_new_york_day": True,
        "entries_inside_0945_1015_half_open": True,
        "flat_same_new_york_day": True,
        "flat_before_1020_execution_grace": True,
        "trading_days": len(per_day),
    }


def audit_native_report(
    report_path: Path,
    cell: Mapping[str, Any],
    pre: Mapping[str, Any],
    core: Any,
) -> NativeRunAudit:
    report_binding = file_binding(report_path)
    rows = core._rows(report_path)
    settings = core._settings_rows(rows)
    expert = core._canonical_expert(str(core._field_value(settings, "expert")))
    symbol = str(core._field_value(settings, "symbol")).upper()
    timeframe, from_date, to_date = core._parse_period(str(core._field_value(settings, "period")))
    currency = str(core._field_value(settings, "currency")).upper()
    deposit = core._parse_decimal(str(core._field_value(settings, "deposit")), "Initial Deposit")
    expected_header = (
        EXPERT_NAME,
        str(cell["symbol"]),
        TIMEFRAME,
        str(cell["from_date"]),
        str(cell["to_date"]),
        "USD",
        INITIAL_BALANCE,
    )
    actual_header = (
        expert,
        symbol,
        timeframe,
        from_date.isoformat(),
        to_date.isoformat(),
        currency,
        deposit,
    )
    if actual_header != expected_header:
        raise InvalidEvidence(f"native report header drift: {actual_header!r} != {expected_header!r}")
    quality = _field_after(
        core,
        settings,
        ["History Quality", "Qualität der Historie", "Qualitaet der Historie"],
    )
    if quality is None or not re.fullmatch(r"100(?:\.0+)?%\s+real ticks", quality.strip(), re.I):
        raise InvalidEvidence(f"native report is not 100% real ticks: {quality!r}")
    ordered_inputs, actual_inputs = _report_inputs(core, settings)
    expected_inputs = pre.get("effective_inputs")
    if not isinstance(expected_inputs, Mapping):
        raise InvalidEvidence("PRE effective input contract missing")
    if set(actual_inputs) != set(expected_inputs):
        raise InvalidEvidence(
            "native report input closure drift: "
            f"missing={sorted(set(expected_inputs)-set(actual_inputs))}, "
            f"extra={sorted(set(actual_inputs)-set(expected_inputs))}"
        )
    drift = []
    for key, contract in expected_inputs.items():
        if not isinstance(contract, Mapping):
            raise InvalidEvidence("malformed PRE effective input")
        if _actual_input_canonical(actual_inputs[key], contract) != contract["canonical"]:
            drift.append(key)
    if drift:
        raise InvalidEvidence(f"native report input value drift: {drift}")
    if expected_inputs["InpQMSimCommissionPerLot"]["canonical"] != "0":
        raise InvalidEvidence("DOUBLE_COUNT_REJECT simulated commission input")
    deals = core._parse_deals(rows)
    if not deals:
        raise InvalidEvidence("native Deals ledger is empty")
    initial = deals[0]
    if initial.kind != "balance" or initial.direction or initial.symbol:
        raise InvalidEvidence("first Deals row is not the initial balance")
    if initial.commission != ZERO or initial.swap != ZERO:
        raise InvalidEvidence("initial balance Deal has commission/swap")
    if _money(initial.profit) != _money(deposit) or _money(initial.balance) != _money(deposit):
        raise InvalidEvidence("initial balance/deposit drift")
    nontrade = [deal for deal in deals if not deal.direction]
    if len(nontrade) != 1:
        raise InvalidEvidence("unexpected non-trading Deals in ledger")
    running = deposit
    for deal in deals[1:]:
        if not (from_date <= deal.time.date() <= to_date):
            raise InvalidEvidence(f"Deal outside cell window: {deal.deal}")
        running += deal.raw_net
        if _money(running) != _money(deal.balance):
            raise InvalidEvidence(f"native balance recurrence drift: Deal {deal.deal}")
    report_net = core._parse_decimal(str(core._field_value(settings, "net_profit")), "Total Net Profit")
    ledger_net = sum((deal.raw_net for deal in deals[1:]), ZERO)
    if _money(report_net) != _money(ledger_net):
        raise InvalidEvidence("Total Net Profit/deal-ledger drift")
    rate = _strict_decimal(pre["cost_schedule"]["worst_rt_per_lot_usd"], "bound cost rate")
    trades = _reconstruct_trades(deals[1:], symbol, rate)
    validate_trade_semantics(trades)
    reported_trades_raw = core._field_value(settings, "total_trades", required=False)
    if reported_trades_raw is None:
        raise InvalidEvidence("native Total Trades is missing")
    reported_trades = core._parse_decimal(str(reported_trades_raw), "Total Trades")
    if reported_trades != reported_trades.to_integral_value() or int(reported_trades) != len(trades):
        raise InvalidEvidence(
            f"native Total Trades/lifecycle drift: {reported_trades} != {len(trades)}"
        )
    deals_sha = canonical_sha256([deal.canonical() for deal in deals])
    fingerprint = canonical_sha256(
        {
            "expert": expert,
            "symbol": symbol,
            "timeframe": timeframe,
            "from_date": from_date,
            "to_date": to_date,
            "currency": currency,
            "deposit": deposit,
            "inputs": dict(sorted(actual_inputs.items())),
            "deals_sha256": deals_sha,
        }
    )
    ledger = [
        {
            **asdict(trade),
            "native_net_usd": _money_text(trade.native_net_usd),
            "venue_cost_usd": _money_text(trade.venue_cost_usd),
            "adjusted_net_usd": _money_text(trade.adjusted_net_usd),
            "volume": _decimal_text(trade.volume),
        }
        for trade in trades
    ]
    receipt = {
        "status": "PASS",
        "report": report_binding,
        "header": {
            "expert": expert,
            "symbol": symbol,
            "timeframe": timeframe,
            "from_date": from_date,
            "to_date": to_date,
            "currency": currency,
            "deposit": deposit,
            "history_quality": quality,
            "inputs_ordered": ordered_inputs,
        },
        "identity": {
            "canonical_deal_sequence_sha256": deals_sha,
            "run_fingerprint_sha256": fingerprint,
        },
        "integrity": {
            "native_commission_exactly_zero": True,
            "native_swap_exactly_zero": True,
            "simulated_commission_exactly_zero": True,
            "balance_recurrence": "PASS_CENT_EXACT",
            "total_net_reconciliation": "PASS_CENT_EXACT",
            "session_and_flat_checks": validate_trade_semantics(trades),
        },
        "cost_ledger": {
            "schedule": pre["cost_schedule"],
            "trades": ledger,
            "native_net_usd": _money_text(sum((row.native_net_usd for row in trades), ZERO)),
            "venue_cost_usd": _money_text(sum((row.venue_cost_usd for row in trades), ZERO)),
            "adjusted_net_usd": _money_text(sum((row.adjusted_net_usd for row in trades), ZERO)),
        },
    }
    return NativeRunAudit(receipt, deals_sha, fingerprint, trades)


def parse_tester_ini(path: Path) -> dict[str, str]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise InvalidEvidence(f"unsupported tester.ini encoding: {path}")
    section = ""
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "Tester" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in values:
            raise InvalidEvidence(f"duplicate tester.ini key: {key}")
        values[key] = value
    return values


def validate_tester_ini(values: Mapping[str, str], cell: Mapping[str, Any]) -> None:
    expected = {
        "Expert": EXPERT_PATH,
        "Symbol": str(cell["symbol"]),
        "Period": TIMEFRAME,
        "Model": "4",
        "ExecutionMode": "0",
        "Optimization": "0",
        "FromDate": _dot_date(str(cell["from_date"])),
        "ToDate": _dot_date(str(cell["to_date"])),
        "Deposit": str(INITIAL_BALANCE),
        "Currency": "USD",
        "Leverage": "100",
        "Visual": "0",
        "ShutdownTerminal": "1",
    }
    drift = {key: (wanted, values.get(key)) for key, wanted in expected.items() if values.get(key) != wanted}
    if drift:
        raise InvalidEvidence(f"tester.ini contract drift: {drift}")


def validate_runner_summary(
    summary: Mapping[str, Any], cell: Mapping[str, Any]
) -> tuple[list[Mapping[str, Any]], list[Mapping[str, Any]]]:
    expected = {
        "result": "PASS",
        "ea_id": EA_ID,
        "ea_label": EA_LABEL,
        "expert": EXPERT_PATH,
        "symbol": cell["symbol"],
        "terminal": EXECUTION_TERMINAL,
        "model": 4,
        "period": TIMEFRAME,
        "requested_runs": DUPLICATES,
        "max_run_attempts": MAX_ATTEMPTS_PER_CELL,
        "deterministic": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": True,
    }
    drift = {key: (wanted, summary.get(key)) for key, wanted in expected.items() if summary.get(key) != wanted}
    if drift:
        raise InvalidEvidence(f"native runner summary drift: {drift}")
    runs = summary.get("runs")
    if not isinstance(runs, list) or not DUPLICATES <= len(runs) <= MAX_ATTEMPTS_PER_CELL:
        raise InvalidEvidence("native runner attempt count escaped the bounded warm-up contract")
    if any(not isinstance(row, Mapping) for row in runs):
        raise InvalidEvidence("native runner run row malformed")
    expected_names = [f"run_{index:02d}" for index in range(1, len(runs) + 1)]
    if [row.get("run") for row in runs] != expected_names:
        raise InvalidEvidence("native runner attempt naming/order drift")
    attempted = summary.get("attempted_runs")
    non_ok = summary.get("non_ok_attempts")
    if (
        isinstance(attempted, bool)
        or not isinstance(attempted, int)
        or attempted != len(runs)
        or isinstance(non_ok, bool)
        or not isinstance(non_ok, int)
        or non_ok != len(runs) - DUPLICATES
        or not 0 <= non_ok <= MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL
    ):
        raise InvalidEvidence("native runner warm-up attempt counters drift")
    warmups = runs[:non_ok]
    accepted = runs[non_ok:]
    allowed_reasons = {
        "BARS_ZERO": {"BARS_ZERO", "M0_1970_PERIOD"},
        "NO_HISTORY": {
            "NO_HISTORY_LOG",
            "HISTORY_CONTEXT_INVALID",
            "BARS_ZERO",
            "M0_1970_PERIOD",
        },
    }
    for row in warmups:
        failure = str(row.get("failure", ""))
        reasons = row.get("invalid_report_reasons")
        if (
            row.get("status") != "INVALID"
            or failure not in allowed_reasons
            or not isinstance(reasons, list)
            or not reasons
            or any(not isinstance(reason, str) for reason in reasons)
            or len(reasons) != len(set(reasons))
            or not set(reasons).issubset(allowed_reasons[failure])
            or (failure == "BARS_ZERO" and "BARS_ZERO" not in reasons)
            or (
                failure == "NO_HISTORY"
                and not {"NO_HISTORY_LOG", "HISTORY_CONTEXT_INVALID"}.intersection(reasons)
            )
        ):
            raise InvalidEvidence("native runner contains a non-infrastructure warm-up")
        total_trades = row.get("total_trades")
        if isinstance(total_trades, bool) or not isinstance(total_trades, int) or total_trades != 0:
            raise InvalidEvidence("native runner warm-up is not zero-trade")
        for field in ("profit_factor", "drawdown", "net_profit"):
            if row.get(f"{field}_raw") is None or _strict_decimal(
                row.get(field), f"warm-up {field}"
            ) != ZERO:
                raise InvalidEvidence("native runner warm-up is not zero-result")
        exit_code = row.get("exit_code")
        if (
            isinstance(exit_code, bool)
            or not isinstance(exit_code, int)
            or exit_code != 0
            or isinstance(row.get("report_size_bytes"), bool)
            or not isinstance(row.get("report_size_bytes"), int)
            or int(row["report_size_bytes"]) <= 0
            or not str(row.get("report_canonical_path", ""))
            or not str(row.get("tester_log_path", ""))
        ):
            raise InvalidEvidence("native runner warm-up lacks complete native artifact identity")
    if len(accepted) != DUPLICATES:
        raise InvalidEvidence("native runner did not close exactly two accepted duplicates")
    for row in accepted:
        if not isinstance(row, Mapping):
            raise InvalidEvidence("native runner run row malformed")
        if row.get("status") != "OK" or row.get("real_ticks_marker") is not True:
            raise InvalidEvidence("native runner duplicate is not OK with an exact Model-4 marker")
    return warmups, accepted


def require_duplicate_identity(audits: Sequence[NativeRunAudit]) -> None:
    if len(audits) != DUPLICATES:
        raise InvalidEvidence(f"exactly {DUPLICATES} audited duplicates are required")
    if len({row.deals_sha256 for row in audits}) != 1:
        raise InvalidEvidence("duplicate canonical Deal sequence drift")
    if len({row.fingerprint_sha256 for row in audits}) != 1:
        raise InvalidEvidence("duplicate run fingerprint drift")


def _sealed_by_path(attempt: Mapping[str, Any]) -> dict[Path, Mapping[str, Any]]:
    sealed = attempt.get("sealed_artifacts")
    if not isinstance(sealed, list):
        raise InvalidEvidence("launch state omitted sealed opaque artifacts")
    result: dict[Path, Mapping[str, Any]] = {}
    for item in sealed:
        if not isinstance(item, Mapping):
            raise InvalidEvidence("sealed artifact binding malformed")
        assert_binding(item, "sealed native artifact")
        path = Path(str(item["path"])).resolve()
        if path in result:
            raise InvalidEvidence(f"duplicate sealed artifact path: {path}")
        result[path] = item
    return result


def _bound_native_run_artifacts(
    row: Mapping[str, Any],
    sealed: Mapping[Path, Mapping[str, Any]],
    cell: Mapping[str, Any],
    expected_raw_directory: Path,
) -> tuple[Path, Path, Path]:
    run_name = str(row.get("run", ""))
    if not re.fullmatch(r"run_[0-9]{2}", run_name):
        raise InvalidEvidence("native run name is malformed")
    report_path = Path(str(row.get("report_canonical_path", ""))).resolve()
    log_path = Path(str(row.get("tester_log_path", ""))).resolve()
    run_directory = report_path.parent
    ini_path = run_directory / "tester.ini"
    expected_raw_directory = expected_raw_directory.resolve()
    if (
        report_path.name.casefold() != "report.htm"
        or run_directory.name != run_name
        or run_directory.parent != expected_raw_directory
        or log_path.parent != run_directory
        or len({report_path, log_path, ini_path}) != 3
    ):
        raise InvalidEvidence(
            f"native artifacts are not bound to their exact raw/{run_name} directory"
        )
    for label, path in (
        ("report", report_path),
        ("tester log", log_path),
        ("tester.ini", ini_path),
    ):
        if path not in sealed:
            raise InvalidEvidence(
                f"{cell['cell_id']} {label} was not sealed by launcher: {path}"
            )
    report_size = row.get("report_size_bytes")
    if (
        isinstance(report_size, bool)
        or not isinstance(report_size, int)
        or report_size <= 0
        or sealed[report_path].get("size") != report_size
    ):
        raise InvalidEvidence(
            f"{cell['cell_id']} native report size differs from its sealed binding"
        )
    validate_tester_ini(parse_tester_ini(ini_path), cell)
    return report_path, log_path, ini_path


def _audit_cell(
    pre: Mapping[str, Any],
    cell: Mapping[str, Any],
    state_cell: Mapping[str, Any],
    core: Any,
) -> tuple[dict[str, Any], list[TradeRecord]]:
    if state_cell.get("cell_id") != cell["cell_id"] or state_cell.get("status") != "COMPLETE":
        raise InvalidEvidence(f"launch cell is not COMPLETE/bound: {cell['cell_id']}")
    if state_cell.get("command_sha256") != canonical_sha256(runner_command(pre, cell)):
        raise InvalidEvidence(f"launch command drift: {cell['cell_id']}")
    attempts = state_cell.get("attempts")
    if not isinstance(attempts, list) or len(attempts) != 1:
        raise InvalidEvidence(f"accepted cell must have exactly one controller attempt: {cell['cell_id']}")
    attempt = attempts[0]
    if not isinstance(attempt, Mapping) or attempt.get("exit_code") != 0:
        raise InvalidEvidence(f"controller attempt is not successful: {cell['cell_id']}")
    summary_binding = attempt.get("summary")
    if not isinstance(summary_binding, Mapping):
        raise InvalidEvidence(f"cell summary binding missing: {cell['cell_id']}")
    runner_result = attempt.get("runner_result")
    if not isinstance(runner_result, Mapping):
        raise InvalidEvidence(f"cell DEV2 controller result missing: {cell['cell_id']}")
    run_id = validate_dev2_controller_result(runner_result, pre)
    native_root = _dev2_native_root(run_id)
    if Path(str(attempt.get("native_root", ""))).resolve() != native_root:
        raise InvalidEvidence(f"cell DEV2 native-root binding drift: {cell['cell_id']}")
    assert_binding(summary_binding, f"{cell['cell_id']} summary")
    summary = load_json(Path(str(summary_binding["path"])))
    warmup_runs, accepted_runs = validate_runner_summary(summary, cell)
    sealed = _sealed_by_path(attempt)
    output_root = Path(str(cell["output_root"])).resolve()
    sealed_list = attempt.get("sealed_artifacts")
    expected_sealed = sorted(
        _opaque_artifacts(output_root) + _opaque_artifacts(native_root),
        key=lambda item: str(item["path"]).casefold(),
    )
    if sealed_list != expected_sealed:
        raise InvalidEvidence(f"sealed/current native artifact closure drift: {cell['cell_id']}")
    if any(
        not _is_within(path, output_root) and not _is_within(path, native_root)
        for path in sealed
    ):
        raise InvalidEvidence(f"sealed artifact escaped controller/native roots: {cell['cell_id']}")
    summary_path = Path(str(summary_binding["path"])).resolve()
    if summary_path != _find_dev2_summary(run_id):
        raise InvalidEvidence(f"cell DEV2 summary identity drift: {cell['cell_id']}")
    if summary_path not in sealed or dict(sealed[summary_path]) != dict(summary_binding):
        raise InvalidEvidence(f"cell summary was not exactly sealed: {cell['cell_id']}")
    expected_raw_directory = summary_path.parent / "raw"
    expected_outcomes = [
        file_binding(path)
        for path in _outcome_artifact_paths(native_root)
        if path.name.casefold() != "summary.json"
    ]
    if attempt.get("outcome_artifacts") != expected_outcomes:
        raise InvalidEvidence(f"opaque outcome-artifact closure drift: {cell['cell_id']}")
    seen_run_artifacts: set[Path] = set()
    warmup_receipts: list[dict[str, Any]] = []
    for row in warmup_runs:
        report_path, log_path, ini_path = _bound_native_run_artifacts(
            row, sealed, cell, expected_raw_directory
        )
        paths = {report_path, log_path, ini_path}
        if seen_run_artifacts.intersection(paths):
            raise InvalidEvidence(f"native run artifact reuse: {cell['cell_id']}/{row['run']}")
        seen_run_artifacts.update(paths)
        warmup_receipts.append(
            {
                "run": row["run"],
                "classification": "OUTCOME_BLIND_INFRASTRUCTURE_WARMUP",
                "failure": row["failure"],
                "invalid_report_reasons": row["invalid_report_reasons"],
                "total_trades": 0,
                "profit_factor": "0",
                "drawdown": "0",
                "net_profit": "0",
                "tester_ini": sealed[ini_path],
                "tester_log": sealed[log_path],
                "native_report_opaque": sealed[report_path],
            }
        )
    audits: list[NativeRunAudit] = []
    run_receipts: list[dict[str, Any]] = []
    for row in accepted_runs:
        report_path, log_path, ini_path = _bound_native_run_artifacts(
            row, sealed, cell, expected_raw_directory
        )
        paths = {report_path, log_path, ini_path}
        if seen_run_artifacts.intersection(paths):
            raise InvalidEvidence(f"native run artifact reuse: {cell['cell_id']}/{row['run']}")
        seen_run_artifacts.update(paths)
        log_text = log_path.read_text(encoding="utf-8-sig", errors="replace")
        if MODEL4_MARKER not in log_text.casefold():
            raise InvalidEvidence(f"raw tester log lacks Model-4 marker: {cell['cell_id']}/{row['run']}")
        if str(cell["symbol"]).casefold() not in log_text.casefold() or EXPERT_NAME.casefold() not in log_text.casefold():
            raise InvalidEvidence(f"raw tester log lacks exact symbol/expert context: {cell['cell_id']}/{row['run']}")
        audit = audit_native_report(report_path, cell, pre, core)
        audits.append(audit)
        run_receipts.append(
            {
                "run": row["run"],
                "tester_ini": sealed[ini_path],
                "tester_log": sealed[log_path],
                "model4_marker": "PASS_EXACT_NO_WAIVER",
                "native_report": audit.receipt,
            }
        )
    require_duplicate_identity(audits)
    return (
        {
            "cell_id": cell["cell_id"],
            "symbol": cell["symbol"],
            "cohort": cell["cohort"],
            "from_date": cell["from_date"],
            "to_date": cell["to_date"],
            "duplicate_deal_sequence": "PASS_EXACT",
            "canonical_deal_sequence_sha256": audits[0].deals_sha256,
            "attempted_runs": len(warmup_runs) + len(accepted_runs),
            "accepted_duplicate_runs": len(accepted_runs),
            "infrastructure_warmup_count": len(warmup_runs),
            "infrastructure_warmups": warmup_receipts,
            "runs": run_receipts,
        },
        audits[0].trades,
    )


def performance(trades: Sequence[TradeRecord]) -> dict[str, Any]:
    ordered = sorted(trades, key=lambda row: (row.exit_time_broker, row.sequence))
    profits = [row.adjusted_net_usd for row in ordered]
    gross_profit = sum((max(value, ZERO) for value in profits), ZERO)
    gross_loss = sum((min(value, ZERO) for value in profits), ZERO)
    net = sum(profits, ZERO)
    if gross_loss < ZERO:
        pf: Decimal | None = gross_profit / -gross_loss
        pf_state = "FINITE"
    elif gross_profit > ZERO:
        pf = None
        pf_state = "INFINITE_NO_LOSSES"
    else:
        pf = None
        pf_state = "UNDEFINED"
    balance = peak = INITIAL_BALANCE
    max_dd = ZERO
    max_dd_percent = ZERO
    for value in profits:
        balance += value
        peak = max(peak, balance)
        drawdown = peak - balance
        max_dd = max(max_dd, drawdown)
        if peak > ZERO:
            max_dd_percent = max(max_dd_percent, drawdown / peak * Decimal("100"))
    return {
        "trades": len(ordered),
        "cost_adjusted_net_usd": _money_text(net),
        "cost_adjusted_gross_profit_usd": _money_text(gross_profit),
        "cost_adjusted_gross_loss_usd": _money_text(gross_loss),
        "cost_adjusted_profit_factor": _decimal_text(pf) if pf is not None else None,
        "profit_factor_state": pf_state,
        "maximum_close_drawdown_usd": _money_text(max_dd),
        "maximum_close_drawdown_percent": _decimal_text(max_dd_percent),
    }


def _pf_at_least(metrics: Mapping[str, Any], floor: Decimal, *, strict: bool = False) -> bool:
    state = metrics["profit_factor_state"]
    if state == "INFINITE_NO_LOSSES":
        return True
    if state != "FINITE" or metrics["cost_adjusted_profit_factor"] is None:
        return False
    observed = Decimal(str(metrics["cost_adjusted_profit_factor"]))
    return observed > floor if strict else observed >= floor


def _gate(gate_id: str, passed: bool, observed: Any, rule: str) -> dict[str, Any]:
    return {"gate_id": gate_id, "status": "PASS" if passed else "FAIL", "observed": observed, "rule": rule}


def evaluate_merit(cells: Mapping[str, Sequence[TradeRecord]]) -> dict[str, Any]:
    expected = {window.cell_id for window in WINDOWS}
    if set(cells) != expected:
        raise InvalidEvidence(f"merit cell closure drift: {sorted(cells)}")
    dev = list(cells["DEV"])
    oos_by_year = {year: list(cells[f"OOS_{year}"]) for year in (2023, 2024, 2025)}
    oos = [trade for year in (2023, 2024, 2025) for trade in oos_by_year[year]]
    dev_metrics = performance(dev)
    yearly = {str(year): performance(rows) for year, rows in oos_by_year.items()}
    pooled = performance(oos)
    gates: list[dict[str, Any]] = []
    gates.extend(
        [
            _gate("DEV_MIN_TRADES", len(dev) >= 80, len(dev), ">=80"),
            _gate("DEV_COST_PF", _pf_at_least(dev_metrics, Decimal("1.20")), dev_metrics["cost_adjusted_profit_factor"], ">=1.20"),
            _gate("DEV_NET", Decimal(dev_metrics["cost_adjusted_net_usd"]) > ZERO, dev_metrics["cost_adjusted_net_usd"], ">0"),
            _gate("DEV_DD", Decimal(dev_metrics["maximum_close_drawdown_percent"]) <= Decimal("10"), dev_metrics["maximum_close_drawdown_percent"], "<=10%"),
        ]
    )
    for year in (2023, 2024, 2025):
        metrics = yearly[str(year)]
        gates.extend(
            [
                _gate(f"OOS_{year}_MIN_TRADES", len(oos_by_year[year]) >= 12, len(oos_by_year[year]), ">=12"),
                _gate(f"OOS_{year}_COST_PF", _pf_at_least(metrics, Decimal("1.00"), strict=True), metrics["cost_adjusted_profit_factor"], ">1.00"),
                _gate(f"OOS_{year}_NET", Decimal(metrics["cost_adjusted_net_usd"]) > ZERO, metrics["cost_adjusted_net_usd"], ">0"),
            ]
        )
    gates.extend(
        [
            _gate("OOS_POOLED_MIN_TRADES", len(oos) >= 45, len(oos), ">=45"),
            _gate("OOS_POOLED_COST_PF", _pf_at_least(pooled, Decimal("1.20")), pooled["cost_adjusted_profit_factor"], ">=1.20"),
            _gate("OOS_POOLED_NET", Decimal(pooled["cost_adjusted_net_usd"]) > ZERO, pooled["cost_adjusted_net_usd"], ">0"),
            _gate("OOS_POOLED_DD", Decimal(pooled["maximum_close_drawdown_percent"]) <= Decimal("10"), pooled["maximum_close_drawdown_percent"], "<=10%"),
        ]
    )
    best_year = max(
        (2023, 2024, 2025),
        key=lambda year: Decimal(yearly[str(year)]["cost_adjusted_net_usd"]),
    )
    leave_best = performance(
        [trade for year, rows in oos_by_year.items() if year != best_year for trade in rows]
    )
    leave_pass = _pf_at_least(leave_best, Decimal("1.05")) and Decimal(leave_best["cost_adjusted_net_usd"]) > ZERO
    gates.append(
        _gate(
            "LEAVE_BEST_OOS_YEAR_OUT",
            leave_pass,
            {"removed_year": best_year, "metrics": leave_best},
            "PF>=1.05 and Net>0 after removing highest-net OOS year",
        )
    )
    positive_by_year = {
        str(year): sum((max(row.adjusted_net_usd, ZERO) for row in rows), ZERO)
        for year, rows in oos_by_year.items()
    }
    total_positive = sum(positive_by_year.values(), ZERO)
    shares = {
        year: (value / total_positive if total_positive > ZERO else Decimal("1"))
        for year, value in positive_by_year.items()
    }
    max_share = max(shares.values(), default=Decimal("1"))
    gates.append(
        _gate(
            "OOS_YEAR_POSITIVE_GROSS_CONCENTRATION",
            total_positive > ZERO and max_share <= Decimal("0.60"),
            {year: _decimal_text(value) for year, value in shares.items()},
            "each year <=60% of positive pooled OOS gross profit",
        )
    )
    day_net: dict[str, Decimal] = defaultdict(lambda: ZERO)
    for trade in dev + oos:
        day_net[trade.new_york_day] += trade.adjusted_net_usd
    worst_day = min(day_net.items(), key=lambda item: item[1]) if day_net else (None, ZERO)
    gates.append(
        _gate(
            "MAX_NY_DAY_LOSS",
            worst_day[1] >= -Decimal("3000"),
            {"new_york_day": worst_day[0], "adjusted_net_usd": _money_text(worst_day[1])},
            ">=-3000 USD (3% of 100k)",
        )
    )
    winners = sorted(
        (row for row in oos if row.adjusted_net_usd > ZERO),
        key=lambda row: row.adjusted_net_usd,
        reverse=True,
    )
    remove_count = math.ceil(len(winners) * 0.05) if winners else 0
    removed_ids = {(row.new_york_day, row.entry_deal) for row in winners[:remove_count]}
    chopped = [row for row in oos if (row.new_york_day, row.entry_deal) not in removed_ids]
    chopped_metrics = performance(chopped)
    gates.append(
        _gate(
            "TOP_5_PERCENT_WINNERS_REMOVED",
            bool(winners) and _pf_at_least(chopped_metrics, Decimal("1.00")),
            {"removed_winners": remove_count, "metrics": chopped_metrics},
            "remove ceil(5% of positive winners), remaining PF>=1.00",
        )
    )
    return {
        "contract": MERIT_GATES,
        "dev": dev_metrics,
        "oos_by_year": yearly,
        "oos_pooled": pooled,
        "gates": gates,
        "status": "PASS" if all(row["status"] == "PASS" for row in gates) else "FAIL",
    }


def _validate_launch_state(
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
    pre: Mapping[str, Any],
) -> dict[str, Any]:
    state = load_json(state_path)
    if (
        state.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_STATE"
        or state.get("analysis_id") != ANALYSIS_ID
        or state.get("launcher_revision") != LAUNCHER_REVISION
        or state.get("status") != "COMPLETE"
        or state.get("worker_pid") is not None
        or state.get("active_cell") is not None
        or state.get("pre_receipt_sha256") != pre_sha256.lower()
        or state.get("pre_receipt_path") != str(pre_path.resolve())
        or state.get("plan_sha256") != pre["plan"]["plan_sha256"]
    ):
        raise InvalidEvidence("launch state is not COMPLETE and exactly PRE-bound")
    if state.get("outcome_fence") != {
        "worker_parses_market_values": False,
        "worker_parses_native_reports": False,
        "worker_seals_opaque_artifacts_only": True,
    }:
        raise InvalidEvidence("launch worker outcome-fence drift")
    job_binding = state.get("job")
    if not isinstance(job_binding, Mapping):
        raise InvalidEvidence("launch job binding missing")
    assert_binding(job_binding, "launch job")
    job = load_json(Path(str(job_binding["path"])))
    try:
        _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    except AuthorizationError as exc:
        raise InvalidEvidence(str(exc)) from exc
    authorization = job.get("authorization")
    if not isinstance(authorization, Mapping) or not isinstance(authorization.get("binding"), Mapping):
        raise InvalidEvidence("launch authorization binding missing")
    validated_auth = validate_authorization(
        Path(str(authorization["binding"]["path"])), pre_sha256, require_current=False
    )
    if validated_auth["payload_sha256"] != authorization.get("payload_sha256"):
        raise InvalidEvidence("launch authorization payload drift")
    expected_authorization = {
        "binding": validated_auth["binding"],
        "payload_sha256": validated_auth["payload_sha256"],
    }
    if authorization != expected_authorization or state.get("authorization") != authorization:
        raise InvalidEvidence("launch authorization lifecycle drift")
    attempt_claim = state.get("attempt_claim")
    if not isinstance(attempt_claim, Mapping):
        raise InvalidEvidence("launch state global native-attempt claim is missing")
    validate_native_attempt_claim(
        attempt_claim,
        pre_path,
        pre_sha256,
        pre,
        state_path,
        expected_authorization,
    )
    if state.get("scheduler") != job.get("scheduler"):
        raise InvalidEvidence("launch scheduler identity drift")
    launches = state.get("launches")
    if not isinstance(launches, list) or not launches:
        raise InvalidEvidence("launch audit chain is missing")
    for index, launch in enumerate(launches):
        if not isinstance(launch, Mapping):
            raise InvalidEvidence("launch audit row is malformed")
        launch_auth = launch.get("authorization")
        worker_pid = launch.get("worker_pid")
        if (
            set(launch) != {
                "worker_pid",
                "started_utc",
                "resume",
                "authorization",
                "scheduler",
            }
            or not isinstance(launch_auth, Mapping)
            or not isinstance(launch_auth.get("binding"), Mapping)
            or not isinstance(worker_pid, int)
            or isinstance(worker_pid, bool)
            or worker_pid <= 0
            or not isinstance(launch.get("resume"), bool)
            or launch.get("scheduler") != job.get("scheduler")
        ):
            raise InvalidEvidence(f"launch audit row {index} identity drift")
        parse_utc(str(launch.get("started_utc", "")), f"launch[{index}] started_utc")
        observed_auth = validate_authorization(
            Path(str(launch_auth["binding"]["path"])),
            pre_sha256,
            require_current=False,
        )
        if (
            dict(observed_auth["binding"]) != dict(launch_auth["binding"])
            or observed_auth["payload_sha256"] != launch_auth.get("payload_sha256")
        ):
            raise InvalidEvidence(f"launch audit row {index} authorization drift")
    if launches[0]["authorization"] != authorization or launches[0]["resume"] is not False:
        raise InvalidEvidence("first launch is not exactly initial-job authorized")
    if any(launch["resume"] is not True for launch in launches[1:]):
        raise InvalidEvidence("subsequent launch audit row is not an explicit resume")
    started = parse_utc(str(state.get("started_utc", "")), "launch state started_utc")
    finished = parse_utc(str(state.get("finished_utc", "")), "launch state finished_utc")
    outcome_possible = parse_utc(
        str(state.get("outcome_possible_since_utc", "")),
        "launch outcome_possible_since_utc",
    )
    if not started <= outcome_possible <= finished:
        raise InvalidEvidence("launch state outcome-fence chronology drift")
    cells = state.get("cells")
    expected_ids = [cell["cell_id"] for cell in pre["plan"]["cells"]]
    if (
        not isinstance(cells, list)
        or len(cells) != len(expected_ids)
        or [row.get("cell_id") for row in cells if isinstance(row, Mapping)] != expected_ids
    ):
        raise InvalidEvidence("launch state cell order/closure drift")
    return state


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    state_binding = file_binding(state_path)
    state = _validate_launch_state(pre_path, pre_sha256, state_path, pre)
    core = _load_report_core(pre)
    receipts: list[dict[str, Any]] = []
    merit_cells: dict[str, list[TradeRecord]] = {}
    for cell, state_cell in zip(pre["plan"]["cells"], state["cells"]):
        receipt, trades = _audit_cell(pre, cell, state_cell, core)
        receipts.append(receipt)
        window_id = str(cell["cell_id"]).removeprefix(f"{cell['symbol'].replace('.', '_')}_")
        merit_cells[window_id] = trades
    merit = evaluate_merit(merit_cells)
    assert_binding(state_binding, "stable COMPLETE launch state")
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_10834_OUTCOME_FENCED_POST_RECEIPT",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "status": merit["status"],
        "integrity_status": "PASS",
        "pre_receipt": file_binding(pre_path, pre_sha256),
        "launch_state": state_binding,
        "authorized_symbol": pre["symbol_policy"]["authorized_symbol"],
        "accepted_duplicate_run_count": sum(
            int(receipt["accepted_duplicate_runs"]) for receipt in receipts
        ),
        "infrastructure_warmup_count": sum(
            int(receipt["infrastructure_warmup_count"]) for receipt in receipts
        ),
        "attempted_native_start_count": sum(
            int(receipt["attempted_runs"]) for receipt in receipts
        ),
        "maximum_authorized_native_starts": len(receipts) * MAX_ATTEMPTS_PER_CELL,
        "cells": receipts,
        "merit": merit,
        "decision": "ADVANCE_CANDIDATE" if merit["status"] == "PASS" else "REJECT_ON_MERIT",
    }


def invalid_receipt(phase: str, exc: Exception) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": f"QM5_10834_{phase}_INVALID",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "status": "INVALID",
        "error_type": type(exc).__name__,
        "error": _safe_error_message(exc),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    freeze = sub.add_parser(
        "freeze-data",
        help="Hash the exact isolated DEV2 NDX.DWX 201807..202512 corpus without starting MT5",
    )
    freeze.add_argument("--symbol", required=True)
    freeze.add_argument("--receipt", type=Path, required=True)
    pre = sub.add_parser("pre", help="Outcome-blind PRE validation and immutable receipt")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--data-receipt", type=Path, required=True)
    pre.add_argument("--build-receipt", type=Path, required=True)
    pre.add_argument("--run-root", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    launch = sub.add_parser(
        "launch", help="Start or pre-outcome resume the persistent S4U native worker"
    )
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.add_argument("--resume", action="store_true")
    post = sub.add_parser("post", help="Audit COMPLETE evidence and apply frozen merit gates")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    status = sub.add_parser("status", help="Read launch state without starting anything")
    status.add_argument("--state", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "_run-plan":
        try:
            return _worker_run(args.job)
        except (AuditError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
            print(json.dumps(invalid_receipt("WORKER", exc), sort_keys=True), file=sys.stderr)
            return 2
    if args.command == "status":
        try:
            state = load_json(args.state)
            print(json.dumps({
                "status": state.get("status"),
                "worker_pid": state.get("worker_pid"),
                "cells": [
                    {"cell_id": row.get("cell_id"), "status": row.get("status")}
                    for row in state.get("cells", []) if isinstance(row, Mapping)
                ],
            }, indent=2, sort_keys=True))
            return 0
        except (AuditError, OSError, ValueError, KeyError, TypeError) as exc:
            print(json.dumps(invalid_receipt("STATUS", exc), sort_keys=True), file=sys.stderr)
            return 2
    try:
        if args.command == "freeze-data":
            payload = freeze_backtest_data(args.symbol)
            digest = atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": "PASS",
                "receipt": str(args.receipt.resolve()),
                "sha256": digest,
                "symbol": payload["symbol"],
                "files": payload["totals"]["files"],
                "bytes": payload["totals"]["bytes"],
            }
            code = 0
        elif args.command == "pre":
            payload = preflight(
                args.symbol,
                args.data_receipt,
                args.build_receipt,
                args.run_root,
            )
            digest = atomic_json(args.receipt, payload, replace=False)
            output = {"status": "PASS", "receipt": str(args.receipt.resolve()), "sha256": digest}
            code = 0
        elif args.command == "launch":
            output = launch_detached(
                args.pre_receipt,
                args.pre_sha256,
                args.authorization,
                args.state,
                resume=args.resume,
            )
            code = 0
        else:
            payload = postflight(args.pre_receipt, args.pre_sha256, args.state)
            digest = atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": payload["status"],
                "receipt": str(args.receipt.resolve()),
                "sha256": digest,
                "decision": payload["decision"],
            }
            code = 0 if payload["status"] == "PASS" else 1
        print(json.dumps(output, indent=2, sort_keys=True))
        return code
    except (AuditError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        payload = invalid_receipt(args.command.upper(), exc)
        receipt = getattr(args, "receipt", None)
        if receipt:
            try:
                atomic_json(receipt, payload, replace=False)
            except (AuditError, OSError):
                pass
        print(json.dumps(payload, indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
