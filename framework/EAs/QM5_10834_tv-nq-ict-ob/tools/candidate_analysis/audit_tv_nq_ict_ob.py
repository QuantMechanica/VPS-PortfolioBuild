#!/usr/bin/env python3
"""Outcome-fenced native candidate runner for QM5_10834.

The command has three deliberately separate trust domains:

* ``pre`` reads only build, configuration, validation, data and runtime bytes.  It
  freezes one authorised symbol and four disjoint windows without opening an MT5
  report or parsing a market outcome.
* ``launch`` requires a short-lived, hash-bound authorisation receipt.  Its
  detached worker checkpoints after every cell and may resume only when an
  interrupted cell left no outcome artefact.  The worker treats native output as
  opaque bytes; it does not adjudicate performance.
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
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time as time_module
from collections import defaultdict
from dataclasses import asdict, dataclass
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


getcontext().prec = 34

TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]

EA_ID = 10834
EA_LABEL = "QM5_10834"
EXPERT_NAME = "QM5_10834_tv-nq-ict-ob"
EXPERT_PATH = rf"QM\{EXPERT_NAME}"
ANALYSIS_ID = "QM5_10834_TV_NQ_ICT_OB_NATIVE_001"
SCHEMA_VERSION = 1
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
RUNNER_PATH = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
REPORT_CORE_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20009_ict-liquidity-portfolio"
    / "tools"
    / "audit_mt5_report.py"
)
REPO_INCLUDE_ROOT = REPO_ROOT / "framework" / "Include"
TERMINAL_INCLUDE_ROOT = Path(r"D:\QM\mt5\T1\MQL5\Include")
TERMINAL_DATA_ROOT = Path(r"D:\QM\mt5\T1\Bases\Custom")
POWERSHELL_PATH = Path(r"C:\Program Files\PowerShell\7\pwsh.exe")
ALLOWED_RUN_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_10834")

EXPECTED_PINE_SHA256 = "015bb5d550a8687f506646de6c33ddfe8b29c3ed5e4ec96f3c66364edfb7f0b5"
MODEL4_MARKER = "generating based on real ticks"
INITIAL_BALANCE = Decimal("100000")
ZERO = Decimal("0")
CENT = Decimal("0.01")
TIMEFRAME = "M5"
DUPLICATES = 2
RUN_TIMEOUT_SECONDS = 28800
NY_ENTRY_START = time(9, 45)
NY_ENTRY_END = time(10, 15)
# A close request is issued at 10:15.  One complete M5 bar is the hard maximum
# execution grace; 10:20 itself is outside the permitted interval.
NY_FLAT_DEADLINE_EXCLUSIVE = time(10, 20)
WORKER_REGISTRATION_TIMEOUT_SECONDS = 30
STALE_WORKER_START_SECONDS = 300

SYMBOL_POLICY: dict[str, str] = {
    "WS30.DWX": "ELIGIBLE_ONLY_WITH_FRESH_PASS_VALIDATION",
    "NDX.DWX": "BLOCKED_SETUP_DATA_MISMATCH_NO_OUTCOME_AUTHORIZATION",
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
        "runner",
        "report_parser",
        "powershell",
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
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return hashlib.sha256(encoded).hexdigest()


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
    if symbol == "NDX.DWX":
        raise InvalidEvidence(SYMBOL_POLICY[symbol])
    if symbol != "WS30.DWX":
        raise InvalidEvidence(
            f"symbol outside the frozen single-index policy: {symbol!r}; "
            "only freshly validated WS30.DWX is eligible"
        )


def _matrix_row(symbol: str, matrix_path: Path = MATRIX_PATH) -> dict[str, str]:
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
    evidence = row.get("evidence_line", "")
    status = row.get("validation_status", "")
    if "FAIL" in evidence.upper() or status.upper() == "FAIL":
        raise InvalidEvidence(f"symbol matrix still carries FAIL evidence: {symbol}")
    if status.upper() != "PASS" and not re.search(r"(?:^|\W)PASS(?:\W|$)", evidence, re.I):
        raise InvalidEvidence(f"symbol matrix has no explicit PASS evidence: {symbol}")
    return row


def validate_validation_receipt(
    path: Path,
    symbol: str,
    data_manifest_sha256: str,
    *,
    now: datetime | None = None,
) -> dict[str, Any]:
    receipt = load_json(path)
    if (
        receipt.get("schema_version") != 1
        or receipt.get("artifact_type") != "QM_CUSTOM_SYMBOL_VALIDATION_RECEIPT"
        or receipt.get("terminal") != "T1"
    ):
        raise InvalidEvidence("custom-symbol validation receipt schema/terminal drift")
    if receipt.get("symbol") != symbol or receipt.get("status") != "PASS":
        raise InvalidEvidence("custom-symbol validation is not an exact PASS for the symbol")
    if receipt.get("classification") not in {"PASS", "VALIDATED"}:
        raise InvalidEvidence("custom-symbol validation classification is not PASS/VALIDATED")
    validated = parse_utc(str(receipt.get("validated_utc", "")), "validated_utc")
    expiry_raw = receipt.get("valid_until_utc", receipt.get("expires_utc", ""))
    expiry = parse_utc(str(expiry_raw), "validation expiry")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if validated > current + timedelta(minutes=5) or current > expiry:
        raise InvalidEvidence("custom-symbol validation receipt is not currently valid")
    if expiry - validated > timedelta(days=90, minutes=5):
        raise InvalidEvidence("custom-symbol validation validity exceeds the 90-day policy")
    if str(receipt.get("data_manifest_sha256", "")).lower() != data_manifest_sha256:
        raise InvalidEvidence("validation receipt/data manifest identity drift")
    evidence = receipt.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        raise InvalidEvidence("validation receipt has no bound evidence")
    for index, item in enumerate(evidence):
        if not isinstance(item, Mapping):
            raise InvalidEvidence("validation evidence binding is not an object")
        assert_binding(item, f"validation evidence[{index}]")
    return receipt


def _required_tick_months() -> set[str]:
    result: set[str] = set()
    cursor = date(2018, 7, 1)
    end = date(2025, 12, 1)
    while cursor <= end:
        result.add(cursor.strftime("%Y%m"))
        cursor = date(cursor.year + (1 if cursor.month == 12 else 0), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return result


def validate_data_manifest(
    path: Path,
    symbol: str,
    *,
    terminal_data_root: Path = TERMINAL_DATA_ROOT,
    verify_file_bindings: bool = True,
) -> dict[str, Any]:
    manifest_binding = file_binding(path)
    manifest = load_json(path)
    if (
        manifest.get("artifact_type") != "QM_CUSTOM_SYMBOL_DATA_MANIFEST"
        or manifest.get("schema_version") != 1
        or manifest.get("symbol") != symbol
        or manifest.get("terminal") != "T1"
    ):
        raise InvalidEvidence("custom-symbol data manifest identity drift")
    coverage = manifest.get("coverage")
    if not isinstance(coverage, Mapping):
        raise InvalidEvidence("data manifest coverage is missing")
    try:
        coverage_from = date.fromisoformat(str(coverage["from_date"]))
        coverage_to = date.fromisoformat(str(coverage["to_date"]))
    except (KeyError, ValueError) as exc:
        raise InvalidEvidence("data manifest coverage is malformed") from exc
    if coverage_from > WINDOWS[0].from_date or coverage_to < WINDOWS[-1].to_date:
        raise InvalidEvidence("data manifest does not cover every preregistered cell")
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise InvalidEvidence("data manifest files are missing")
    history_root = (terminal_data_root / "history" / symbol).resolve()
    ticks_root = (terminal_data_root / "ticks" / symbol).resolve()
    seen_paths: set[Path] = set()
    hcc_years: set[str] = set()
    tick_months: set[str] = set()
    for index, item in enumerate(files):
        if not isinstance(item, Mapping):
            raise InvalidEvidence("data file binding is not an object")
        if verify_file_bindings:
            assert_binding(item, f"data file[{index}]")
        item_path = Path(str(item["path"])).resolve()
        if item_path in seen_paths:
            raise InvalidEvidence(f"duplicate data-file binding: {item_path}")
        seen_paths.add(item_path)
        if _is_within(item_path, history_root) and item_path.suffix.casefold() == ".hcc":
            if re.fullmatch(r"20\d{2}", item_path.stem):
                hcc_years.add(item_path.stem)
        elif _is_within(item_path, ticks_root) and item_path.suffix.casefold() == ".tkc":
            if re.fullmatch(r"20\d{4}", item_path.stem):
                tick_months.add(item_path.stem)
        else:
            raise InvalidEvidence(f"data binding escaped the exact T1 symbol stores: {item_path}")
    required_years = {str(year) for year in range(2018, 2026)}
    if not required_years.issubset(hcc_years):
        raise InvalidEvidence(f"missing HCC years: {sorted(required_years - hcc_years)}")
    required_months = _required_tick_months()
    if not required_months.issubset(tick_months):
        raise InvalidEvidence(f"missing TKC months: {sorted(required_months - tick_months)}")
    return {
        "manifest": manifest_binding,
        "coverage": {"from_date": coverage_from, "to_date": coverage_to},
        "files": [dict(item) for item in files],
    }


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
        "qm_magic_slot_offset": "1",
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "strategy_entry_start_hhmm": "945",
        "strategy_entry_end_hhmm": "1015",
        "strategy_target_r": "2.0",
    }
    drift = {key: (wanted, inputs.get(key)) for key, wanted in expected.items() if inputs.get(key) != wanted}
    if symbol != "WS30.DWX" or metadata.get("symbol") != symbol or metadata.get("timeframe") != TIMEFRAME:
        raise InvalidEvidence("set metadata violates the WS30/M5 single-symbol contract")
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


def resolve_cost_schedule(path: Path, symbol: str) -> dict[str, str]:
    payload = load_json(path)
    symbols = payload.get("symbols")
    if not isinstance(symbols, Mapping):
        raise InvalidEvidence("cost model symbols map is missing")
    key = symbol.split(".", 1)[0]
    row = symbols.get(key)
    if not isinstance(row, Mapping):
        raise InvalidEvidence(f"cost model has no exact symbol row for {symbol}")
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
    return {
        "symbol": symbol,
        "currency": "USD",
        "application": "ROUND_TRIP_PER_CLOSED_LOT_ROUNDED_TO_CENT",
        "dxz_rt_per_lot_usd": _decimal_text(dxz_rate),
        "ftmo_rt_per_lot_usd": _decimal_text(ftmo_rate),
        "worst_rt_per_lot_usd": _decimal_text(calculated),
        "spread": "EMBEDDED_IN_BOUND_REAL_TICKS",
        "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
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
                "set": dict(set_binding),
                "output_root": str((run_root / "native" / window.cell_id).resolve()),
            }
        )
    plan_basis = {
        "single_authorized_symbol": symbol,
        "cells": cells,
        "native_run_count": len(cells) * DUPLICATES,
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
        "runner": RUNNER_PATH,
        "report_parser": REPORT_CORE_PATH,
        "powershell": POWERSHELL_PATH,
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
    validation_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    run_root = _assert_run_root(run_root)
    if run_root.exists() and any(run_root.iterdir()):
        raise InvalidEvidence(f"run root is not empty: {run_root}")
    bindings = _binding_map(symbol)
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
    data = validate_data_manifest(data_manifest_path, symbol)
    validation_receipt = validate_validation_receipt(
        validation_receipt_path, symbol, data["manifest"]["sha256"]
    )
    matrix_row = _matrix_row(symbol)
    cost_schedule = resolve_cost_schedule(COST_PATH, symbol)
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
            "ws30": SYMBOL_POLICY["WS30.DWX"],
            "ndx": SYMBOL_POLICY["NDX.DWX"],
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
        "validation_receipt": file_binding(validation_receipt_path),
        "validation_identity": {
            "validated_utc": validation_receipt["validated_utc"],
            "valid_until_utc": validation_receipt.get(
                "valid_until_utc", validation_receipt.get("expires_utc")
            ),
        },
        "data": data,
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
    for role in ("build_receipt", "validation_receipt"):
        item = pre.get(role)
        if not isinstance(item, Mapping):
            raise InvalidEvidence(f"PRE {role} binding missing")
        assert_binding(item, f"PRE {role}")
    data = pre.get("data")
    if not isinstance(data, Mapping) or not isinstance(data.get("manifest"), Mapping):
        raise InvalidEvidence("PRE data binding missing")
    assert_binding(data["manifest"], "PRE data manifest")
    files = data.get("files")
    if not isinstance(files, list):
        raise InvalidEvidence("PRE data file closure missing")
    for index, item in enumerate(files):
        if not isinstance(item, Mapping):
            raise InvalidEvidence("PRE data binding malformed")
        assert_binding(item, f"PRE data[{index}]")
    validated_data = validate_data_manifest(
        Path(str(data["manifest"]["path"])),
        symbol,
        verify_file_bindings=False,
    )
    if data != _jsonable(validated_data):
        raise InvalidEvidence("PRE/data-manifest semantic closure drift")
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
    if policy.get("matrix_row") != matrix_row:
        raise InvalidEvidence("PRE symbol-matrix PASS row drift")
    created = parse_utc(str(pre.get("created_utc", "")), "PRE created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("PRE creation time is implausibly in the future")
    validation = validate_validation_receipt(
        Path(str(pre["validation_receipt"]["path"])),
        symbol,
        str(data["manifest"]["sha256"]),
        now=created,
    )
    validation_identity = {
        "validated_utc": validation["validated_utc"],
        "valid_until_utc": validation.get(
            "valid_until_utc", validation.get("expires_utc")
        ),
    }
    if pre.get("validation_identity") != validation_identity:
        raise InvalidEvidence("PRE validation identity drift")
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


def validate_current_symbol_gate(pre: Mapping[str, Any]) -> None:
    policy = pre.get("symbol_policy")
    data = pre.get("data")
    validation = pre.get("validation_receipt")
    bindings = pre.get("bindings")
    if (
        not isinstance(policy, Mapping)
        or not isinstance(data, Mapping)
        or not isinstance(data.get("manifest"), Mapping)
        or not isinstance(validation, Mapping)
        or not isinstance(bindings, Mapping)
        or not isinstance(bindings.get("matrix"), Mapping)
    ):
        raise InvalidEvidence("PRE cannot prove a current symbol-validation gate")
    symbol = str(policy.get("authorized_symbol", ""))
    enforce_symbol_policy(symbol)
    validate_validation_receipt(
        Path(str(validation["path"])),
        symbol,
        str(data["manifest"]["sha256"]),
    )
    current_row = _matrix_row(symbol, Path(str(bindings["matrix"]["path"])))
    if current_row != policy.get("matrix_row"):
        raise InvalidEvidence("current symbol-matrix PASS row differs from PRE")


def _dot_date(value: str) -> str:
    return value.replace("-", ".")


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    bindings = pre["bindings"]
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
        "-Terminal",
        "T1",
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
        "-ReportRoot",
        str(Path(str(cell["output_root"])).resolve()),
        "-DispatchPhase",
        "CANDIDATE_ANALYSIS",
        "-DispatchVersion",
        MERIT_CONTRACT_VERSION,
        "-DispatchSubGateHash",
        str(pre["plan"]["plan_sha256"]),
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
        "scope": "QM5_10834_WS30_4_CELLS_X_2_DUPLICATES_MODEL4",
        "authorized_by": "OWNER",
        "authorized_symbol": "WS30.DWX",
        "authorized_cells": [window.cell_id for window in WINDOWS],
        "duplicates_per_cell": DUPLICATES,
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


def initial_launch_state(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    job_binding: Mapping[str, Any],
    authorization: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_10834_NATIVE_LAUNCH_STATE",
        "analysis_id": ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": utc_now(),
        "updated_utc": utc_now(),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "job": dict(job_binding),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
        "worker_pid": None,
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


def _pid_alive(pid: Any) -> bool:
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def resume_eligible(
    state: Mapping[str, Any], *, now: datetime | None = None
) -> bool:
    status = state.get("status")
    if status == "STARTING_WORKER":
        try:
            updated = parse_utc(str(state.get("updated_utc", "")), "state updated_utc")
        except AuditError:
            return False
        current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
        if current - updated < timedelta(seconds=STALE_WORKER_START_SECONDS):
            return False
    elif status not in {"PENDING", "INTERRUPTED_RESUMABLE"}:
        return False
    if _pid_alive(state.get("worker_pid")):
        return False
    cells = state.get("cells")
    if not isinstance(cells, list):
        return False
    for cell in cells:
        if not isinstance(cell, Mapping):
            return False
        if cell.get("status") in {"COMPLETE", "PENDING"}:
            continue
        if cell.get("status") == "INTERRUPTED_NO_OUTCOME":
            attempts = cell.get("attempts", [])
            if not isinstance(attempts, list):
                return False
            if any(
                isinstance(attempt, Mapping)
                and (attempt.get("summary") or attempt.get("outcome_artifacts"))
                for attempt in attempts
            ):
                return False
            continue
        return False
    return True


def _spawn_worker(
    job_path: Path,
    stdout_path: Path,
    stderr_path: Path,
    launch_token: str,
) -> int:
    stdout_path.parent.mkdir(parents=True, exist_ok=True)
    creationflags = 0
    for name in ("CREATE_NEW_PROCESS_GROUP", "DETACHED_PROCESS", "CREATE_NO_WINDOW"):
        creationflags |= int(getattr(subprocess, name, 0))
    child_environment = os.environ.copy()
    child_environment["QM10834_WORKER_LAUNCH_TOKEN"] = launch_token
    with stdout_path.open("ab", buffering=0) as stdout, stderr_path.open("ab", buffering=0) as stderr:
        process = subprocess.Popen(
            [sys.executable, str(TOOL_PATH), "_worker", "--job", str(job_path.resolve())],
            cwd=str(REPO_ROOT),
            stdin=subprocess.DEVNULL,
            stdout=stdout,
            stderr=stderr,
            close_fds=True,
            creationflags=creationflags,
            env=child_environment,
        )
    return int(process.pid)


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    validate_current_symbol_gate(pre)
    expected_state = Path(str(pre["run_root"])).resolve() / "launch_state.json"
    if state_path.resolve() != expected_state:
        raise AuthorizationError(f"state path must be {expected_state}")
    authorization = validate_authorization(authorization_path, pre_sha256)
    job_path = Path(str(pre["run_root"])).resolve() / "launch_job.json"
    worker_stdout = Path(str(pre["run_root"])).resolve() / "worker.stdout.log"
    worker_stderr = Path(str(pre["run_root"])).resolve() / "worker.stderr.log"
    if state_path.exists():
        if not resume:
            raise AuthorizationError("launch state exists; explicit --resume is required")
        state = load_json(state_path)
        if not resume_eligible(state):
            raise AuthorizationError("launch state is not safely resumable")
        assert_binding(state["job"], "resume job")
        job = load_json(job_path)
        if (
            job.get("pre_receipt_sha256") != pre_sha256.lower()
            or job.get("plan_sha256") != pre["plan"]["plan_sha256"]
        ):
            raise AuthorizationError("resume job/PRE drift")
    else:
        if resume:
            raise AuthorizationError("--resume requested without a launch state")
        if job_path.exists():
            raise AuthorizationError(f"orphan launch job exists: {job_path}")
        job = {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "QM5_10834_NATIVE_LAUNCH_JOB",
            "analysis_id": ANALYSIS_ID,
            "created_utc": utc_now(),
            "pre_receipt_path": str(pre_path.resolve()),
            "pre_receipt_sha256": pre_sha256.lower(),
            "state_path": str(state_path.resolve()),
            "plan_sha256": pre["plan"]["plan_sha256"],
            "authorization": {
                "binding": authorization["binding"],
                "payload_sha256": authorization["payload_sha256"],
            },
            "tool": pre["bindings"]["tool"],
        }
        atomic_json(job_path, job, replace=False)
        state = initial_launch_state(
            pre_path, pre_sha256, pre, file_binding(job_path), authorization
        )
        atomic_json(state_path, state, replace=False)
    previous_status = str(state["status"])
    launch_token = secrets.token_hex(32)
    launch_token_sha256 = hashlib.sha256(launch_token.encode("ascii")).hexdigest()
    state["status"] = "STARTING_WORKER"
    state["worker_pid"] = None
    state["launch_token_sha256"] = launch_token_sha256
    state["updated_utc"] = utc_now()
    atomic_json(state_path, state, replace=True)
    try:
        pid = _spawn_worker(job_path, worker_stdout, worker_stderr, launch_token)
    except (OSError, subprocess.SubprocessError):
        state = load_json(state_path)
        if state.get("launch_token_sha256") == launch_token_sha256:
            state["status"] = previous_status
            state["worker_pid"] = None
            state["launch_token_sha256"] = None
            state["updated_utc"] = utc_now()
            atomic_json(state_path, state, replace=True)
        raise
    state = load_json(state_path)
    if (
        state.get("launch_token_sha256") != launch_token_sha256
        or state.get("status") != "STARTING_WORKER"
    ):
        raise AuthorizationError("launch state changed during detached-worker registration")
    state["worker_pid"] = pid
    state["status"] = "RUNNING"
    state["updated_utc"] = utc_now()
    launches = state.setdefault("launches", [])
    if not isinstance(launches, list):
        raise AuthorizationError("launch audit list is malformed")
    launches.append(
        {
            "launch_token_sha256": launch_token_sha256,
            "worker_pid": pid,
            "registered_utc": state["updated_utc"],
            "resume": resume,
            "authorization": {
                "binding": dict(authorization["binding"]),
                "payload_sha256": authorization["payload_sha256"],
            },
        }
    )
    atomic_json(state_path, state, replace=True)
    return {
        "status": "LAUNCHED_DETACHED" if not resume else "RESUMED_DETACHED",
        "worker_pid": pid,
        "state": str(state_path.resolve()),
        "job": str(job_path.resolve()),
    }


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


def _archive_interrupted_no_outcome(
    pre: Mapping[str, Any],
    cell: Mapping[str, Any],
    state_cell: dict[str, Any],
) -> None:
    attempts = state_cell.get("attempts")
    if not isinstance(attempts, list) or not attempts:
        raise InvalidEvidence("interrupted cell has no controller-attempt evidence")
    if any(
        not isinstance(attempt, Mapping)
        or attempt.get("summary")
        or attempt.get("outcome_artifacts")
        for attempt in attempts
    ):
        raise InvalidEvidence("interrupted cell carries outcome evidence and cannot resume")
    output_root = Path(str(cell["output_root"])).resolve()
    if _outcome_artifact_paths(output_root):
        raise InvalidEvidence("outcome artifact appeared after interrupted-state checkpoint")
    interruptions = state_cell.setdefault("interruptions", [])
    if not isinstance(interruptions, list):
        raise InvalidEvidence("interrupted-attempt audit list is malformed")
    archived_root: Path | None = None
    archived_artifacts: list[dict[str, Any]] = []
    if output_root.exists():
        run_root = Path(str(pre["run_root"])).resolve()
        archived_root = (
            run_root
            / "interrupted_no_outcome"
            / str(cell["cell_id"])
            / f"attempt_{len(interruptions) + 1:02d}"
        ).resolve()
        if not _is_within(archived_root, run_root) or archived_root.exists():
            raise InvalidEvidence("unsafe/colliding interrupted-attempt archive path")
        archived_root.parent.mkdir(parents=True, exist_ok=True)
        os.replace(output_root, archived_root)
        archived_artifacts = _opaque_artifacts(archived_root)
    interruptions.append(
        {
            "status": "INTERRUPTED_NO_OUTCOME_ARCHIVED",
            "archived_utc": utc_now(),
            "prior_attempts_sha256": canonical_sha256(attempts),
            "archived_root": str(archived_root) if archived_root else None,
            "artifacts": archived_artifacts,
        }
    )
    state_cell["attempts"] = []
    state_cell["status"] = "PENDING"


def _registered_worker_state(state_path: Path, launch_token: str) -> dict[str, Any]:
    token_sha256 = hashlib.sha256(launch_token.encode("ascii")).hexdigest()
    deadline = time_module.monotonic() + WORKER_REGISTRATION_TIMEOUT_SECONDS
    while time_module.monotonic() < deadline:
        state = load_json(state_path)
        if state.get("launch_token_sha256") != token_sha256:
            raise AuthorizationError("worker launch token/state drift")
        if state.get("worker_pid") == os.getpid() and state.get("status") == "RUNNING":
            return state
        time_module.sleep(0.05)
    raise AuthorizationError("detached worker was not registered by its launcher")


def _safe_error_message(exc: Exception) -> str:
    if isinstance(exc, subprocess.TimeoutExpired):
        return "native controller exceeded the fenced outer timeout"
    if isinstance(exc, subprocess.CalledProcessError):
        return f"native controller returned exit code {exc.returncode}"
    return str(exc)


def _worker_run(job_path: Path, launch_token: str) -> int:
    job_binding = file_binding(job_path)
    job = load_json(job_path)
    if (
        job.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_JOB"
        or job.get("analysis_id") != ANALYSIS_ID
    ):
        raise AuthorizationError("worker job identity drift")
    state_path = Path(str(job["state_path"])).resolve()
    state = _registered_worker_state(state_path, launch_token)
    launches = state.get("launches")
    if not isinstance(launches, list) or not launches or not isinstance(launches[-1], Mapping):
        exc = AuthorizationError("worker launch audit row is missing")
        state["status"] = "INVALID_WORKER_BOOTSTRAP"
        state["worker_pid"] = None
        state["launch_token_sha256"] = None
        state["worker_error"] = {"type": type(exc).__name__, "message": str(exc)}
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        return 2
    active_launch = launches[-1]
    if (
        active_launch.get("worker_pid") != os.getpid()
        or active_launch.get("launch_token_sha256")
        != hashlib.sha256(launch_token.encode("ascii")).hexdigest()
        or not isinstance(active_launch.get("authorization"), Mapping)
        or not isinstance(active_launch["authorization"].get("binding"), Mapping)
    ):
        exc = AuthorizationError("worker launch registration/audit drift")
        state["status"] = "INVALID_WORKER_BOOTSTRAP"
        state["worker_pid"] = None
        state["launch_token_sha256"] = None
        state["worker_error"] = {"type": type(exc).__name__, "message": str(exc)}
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        return 2
    try:
        pre_path = Path(str(job["pre_receipt_path"])).resolve()
        pre_sha = str(job["pre_receipt_sha256"]).lower()
        pre = assert_pre_receipt(pre_path, pre_sha)
        if state_path != Path(str(pre["run_root"])).resolve() / "launch_state.json":
            raise AuthorizationError("worker state path escaped the PRE run root")
        active_authorization = validate_authorization(
            Path(str(active_launch["authorization"]["binding"]["path"])),
            pre_sha,
            now=parse_utc(
                str(active_launch.get("registered_utc", "")), "registered_utc"
            ),
        )
        if active_authorization["payload_sha256"] != active_launch["authorization"].get(
            "payload_sha256"
        ):
            raise AuthorizationError("worker active authorization payload drift")
        validate_authorization(
            Path(str(job["authorization"]["binding"]["path"])),
            pre_sha,
            require_current=False,
        )
        state_job = state.get("job")
        if not isinstance(state_job, Mapping) or state_job.get("sha256") != job_binding["sha256"]:
            raise AuthorizationError("worker state/job binding drift")
        state["worker_pid"] = os.getpid()
        state["status"] = "RUNNING"
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
    except (OSError, subprocess.SubprocessError, AuditError, KeyError, TypeError, ValueError) as exc:
        state["status"] = "INVALID_WORKER_BOOTSTRAP"
        state["worker_pid"] = None
        state["launch_token_sha256"] = None
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
            if state_cell["status"] == "COMPLETE":
                continue
            if state_cell["status"] == "INTERRUPTED_NO_OUTCOME":
                cell = cell_by_id[str(state_cell["cell_id"])]
                _archive_interrupted_no_outcome(pre, cell, state_cell)
                state["updated_utc"] = utc_now()
                atomic_json(state_path, state, replace=True)
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
            attempt: dict[str, Any] = {
                "started_utc": utc_now(),
                "command_sha256": canonical_sha256(command),
                "summary": None,
                "outcome_artifacts": [],
            }
            state_cell["status"] = "RUNNING"
            state_cell["attempts"].append(attempt)
            state["updated_utc"] = utc_now()
            atomic_json(state_path, state, replace=True)
            with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
                completed = subprocess.run(
                    command,
                    cwd=str(REPO_ROOT),
                    stdin=subprocess.DEVNULL,
                    stdout=stdout,
                    stderr=stderr,
                    check=False,
                    timeout=(RUN_TIMEOUT_SECONDS * DUPLICATES) + 1800,
                )
            attempt["finished_utc"] = utc_now()
            attempt["exit_code"] = int(completed.returncode)
            attempt["stdout"] = file_binding(stdout_path)
            attempt["stderr"] = file_binding(stderr_path)
            summaries = list(output_root.rglob("summary.json"))
            outcome_files = [
                path
                for path in _outcome_artifact_paths(output_root)
                if path.name.casefold() != "summary.json"
            ]
            if len(summaries) == 1:
                attempt["summary"] = file_binding(summaries[0])
            attempt["outcome_artifacts"] = [file_binding(path) for path in sorted(outcome_files)]
            if completed.returncode != 0 or len(summaries) != 1:
                state_cell["status"] = (
                    "INVALID_TERMINAL_OUTPUT"
                    if summaries or outcome_files
                    else "INTERRUPTED_NO_OUTCOME"
                )
                state["status"] = (
                    "INVALID_TERMINAL" if summaries or outcome_files else "INTERRUPTED_RESUMABLE"
                )
                state["worker_pid"] = None
                state["launch_token_sha256"] = None
                state["updated_utc"] = utc_now()
                atomic_json(state_path, state, replace=True)
                return 2
            attempt["sealed_artifacts"] = _opaque_artifacts(output_root)
            state_cell["status"] = "COMPLETE"
            state["updated_utc"] = utc_now()
            atomic_json(state_path, state, replace=True)
        state["status"] = "COMPLETE"
        state["worker_pid"] = None
        state["launch_token_sha256"] = None
        state["finished_utc"] = utc_now()
        state["updated_utc"] = utc_now()
        atomic_json(state_path, state, replace=True)
        return 0
    except (OSError, subprocess.SubprocessError, AuditError, KeyError, TypeError, ValueError) as exc:
        current = next((row for row in state.get("cells", []) if row.get("status") == "RUNNING"), None)
        if current is not None:
            attempt = current.get("attempts", [{}])[-1]
            root = Path(str(cell_by_id[str(current["cell_id"])]["output_root"]))
            summaries = list(root.rglob("summary.json")) if root.exists() else []
            reports = [
                path
                for path in _outcome_artifact_paths(root)
                if path.name.casefold() != "summary.json"
            ]
            attempt["error_type"] = type(exc).__name__
            attempt["error"] = _safe_error_message(exc)
            attempt["summary"] = file_binding(summaries[0]) if len(summaries) == 1 else None
            attempt["outcome_artifacts"] = [file_binding(path) for path in reports]
            timed_out = isinstance(exc, subprocess.TimeoutExpired)
            current["status"] = (
                "INVALID_TERMINAL_OUTPUT"
                if timed_out or summaries or reports
                else "INTERRUPTED_NO_OUTCOME"
            )
            state["status"] = (
                "INVALID_TERMINAL"
                if timed_out or summaries or reports
                else "INTERRUPTED_RESUMABLE"
            )
        else:
            state["status"] = "INVALID_TERMINAL"
        state["worker_pid"] = None
        state["launch_token_sha256"] = None
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


def validate_runner_summary(summary: Mapping[str, Any], cell: Mapping[str, Any]) -> None:
    expected = {
        "result": "PASS",
        "ea_id": EA_ID,
        "ea_label": EA_LABEL,
        "expert": EXPERT_PATH,
        "symbol": cell["symbol"],
        "terminal": "T1",
        "model": 4,
        "period": TIMEFRAME,
        "requested_runs": DUPLICATES,
        "attempted_runs": DUPLICATES,
        "non_ok_attempts": 0,
        "deterministic": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": True,
    }
    drift = {key: (wanted, summary.get(key)) for key, wanted in expected.items() if summary.get(key) != wanted}
    if drift:
        raise InvalidEvidence(f"native runner summary drift: {drift}")
    runs = summary.get("runs")
    if (
        not isinstance(runs, list)
        or len(runs) != DUPLICATES
        or [row.get("run") for row in runs if isinstance(row, Mapping)] != ["run_01", "run_02"]
    ):
        raise InvalidEvidence("native runner did not close exactly two named duplicates")
    for row in runs:
        if not isinstance(row, Mapping):
            raise InvalidEvidence("native runner run row malformed")
        if row.get("status") != "OK" or row.get("real_ticks_marker") is not True:
            raise InvalidEvidence("native runner duplicate is not OK with an exact Model-4 marker")


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
    assert_binding(summary_binding, f"{cell['cell_id']} summary")
    summary = load_json(Path(str(summary_binding["path"])))
    validate_runner_summary(summary, cell)
    sealed = _sealed_by_path(attempt)
    output_root = Path(str(cell["output_root"])).resolve()
    sealed_list = attempt.get("sealed_artifacts")
    if sealed_list != _opaque_artifacts(output_root):
        raise InvalidEvidence(f"sealed/current native artifact closure drift: {cell['cell_id']}")
    if any(not _is_within(path, output_root) for path in sealed):
        raise InvalidEvidence(f"sealed artifact escaped cell output root: {cell['cell_id']}")
    summary_path = Path(str(summary_binding["path"])).resolve()
    if summary_path not in sealed or dict(sealed[summary_path]) != dict(summary_binding):
        raise InvalidEvidence(f"cell summary was not exactly sealed: {cell['cell_id']}")
    expected_outcomes = [
        file_binding(path)
        for path in _outcome_artifact_paths(output_root)
        if path.name.casefold() != "summary.json"
    ]
    if attempt.get("outcome_artifacts") != expected_outcomes:
        raise InvalidEvidence(f"opaque outcome-artifact closure drift: {cell['cell_id']}")
    audits: list[NativeRunAudit] = []
    run_receipts: list[dict[str, Any]] = []
    for row in summary["runs"]:
        report_path = Path(str(row.get("report_canonical_path", ""))).resolve()
        log_path = Path(str(row.get("tester_log_path", ""))).resolve()
        ini_path = report_path.parent / "tester.ini"
        for label, path in (("report", report_path), ("tester log", log_path), ("tester.ini", ini_path)):
            if path not in sealed:
                raise InvalidEvidence(f"{cell['cell_id']} {label} was not sealed by launcher: {path}")
        validate_tester_ini(parse_tester_ini(ini_path), cell)
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
        or state.get("status") != "COMPLETE"
        or state.get("worker_pid") is not None
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
    if (
        job.get("artifact_type") != "QM5_10834_NATIVE_LAUNCH_JOB"
        or job.get("pre_receipt_sha256") != pre_sha256.lower()
        or job.get("plan_sha256") != pre["plan"]["plan_sha256"]
        or job.get("state_path") != str(state_path.resolve())
        or job.get("tool") != pre["bindings"]["tool"]
    ):
        raise InvalidEvidence("launch job chain drift")
    authorization = job.get("authorization")
    if not isinstance(authorization, Mapping) or not isinstance(authorization.get("binding"), Mapping):
        raise InvalidEvidence("launch authorization binding missing")
    validated_auth = validate_authorization(
        Path(str(authorization["binding"]["path"])), pre_sha256, require_current=False
    )
    if validated_auth["payload_sha256"] != authorization.get("payload_sha256"):
        raise InvalidEvidence("launch authorization payload drift")
    if (
        state.get("authorization") != authorization
        or state.get("launch_token_sha256") is not None
    ):
        raise InvalidEvidence("launch initial-authorization/token lifecycle drift")
    launches = state.get("launches")
    if not isinstance(launches, list) or not launches:
        raise InvalidEvidence("launch audit chain is missing")
    for index, launch in enumerate(launches):
        if not isinstance(launch, Mapping):
            raise InvalidEvidence("launch audit row is malformed")
        launch_auth = launch.get("authorization")
        token_hash = str(launch.get("launch_token_sha256", ""))
        worker_pid = launch.get("worker_pid")
        if (
            not isinstance(launch_auth, Mapping)
            or not isinstance(launch_auth.get("binding"), Mapping)
            or not re.fullmatch(r"[0-9a-f]{64}", token_hash)
            or not isinstance(worker_pid, int)
            or isinstance(worker_pid, bool)
            or worker_pid <= 0
            or not isinstance(launch.get("resume"), bool)
        ):
            raise InvalidEvidence(f"launch audit row {index} identity drift")
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
        "native_run_count": len(receipts) * DUPLICATES,
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
    pre = sub.add_parser("pre", help="Outcome-blind PRE validation and immutable receipt")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--validation-receipt", type=Path, required=True)
    pre.add_argument("--data-manifest", type=Path, required=True)
    pre.add_argument("--build-receipt", type=Path, required=True)
    pre.add_argument("--run-root", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    launch = sub.add_parser("launch", help="Start or explicitly resume the detached native worker")
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
    worker = sub.add_parser("_worker", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "_worker":
        try:
            launch_token = os.environ.get("QM10834_WORKER_LAUNCH_TOKEN", "")
            if not re.fullmatch(r"[0-9a-f]{64}", launch_token):
                raise AuthorizationError("worker launch token is missing or malformed")
            return _worker_run(args.job, launch_token)
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
        if args.command == "pre":
            payload = preflight(
                args.symbol,
                args.validation_receipt,
                args.data_manifest,
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
