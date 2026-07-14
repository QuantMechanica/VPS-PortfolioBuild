#!/usr/bin/env python3
"""Q03 prospective one-dimensional parameter plateau runner.

The runner consumes a caller-hashed JSON grid specification. It never invents
axes, values, thresholds, or result-dependent tie breaks. Version 1 deliberately
supports exactly one ordered numeric strategy axis so plateau adjacency is
unambiguous.

Grid spec schema (schema_version=1):

{
  "schema_version": 1,
  "phase": "Q03",
  "preregistered_at_utc": "2026-07-13T12:00:00Z",
  "ea_id": 10163,
  "ea_dir_name": "QM5_10163_tv-rsi-macd-long",
  "symbol": "USDJPY.DWX",
  "period": "H1",
  "is_window": {"from": "2017.01.01", "to": "2022.12.31"},
  "model": 4,
  "identity": {
    "card": {"path": "...", "sha256": "..."},
    "mq5": {"path": "...", "sha256": "..."},
    "ex5": {"path": "...", "sha256": "..."},
    "baseline_setfile": {"path": "...", "sha256": "..."}
  },
  "axis": {
    "name": "strategy_atr_period",
    "value_type": "int",
    "active": true,
    "values": [1, 2, 3, "..."]
  },
  "locked_parameters": {
    "strategy_signal_tf": "PERIOD_H1",
    "strategy_other_input": 10
  },
  "profitability": {
    "profit_factor_strictly_greater_than": 1.0,
    "minimum_fraction": 0.5,
    "minimum_trades": 20,
    "maximum_drawdown_money": null
  },
  "plateau": {
    "minimum_contiguous_width": 3,
    "run_selection": "widest_then_lower_start",
    "cell_selection": "median",
    "even_median": "lower"
  },
  "run_contract": {"runs_per_cell": 2}
}

The SHA256 of the exact grid-spec bytes must be supplied separately through
--grid-spec-sha256. Plan mode validates the full contract and prints the plan,
but creates no directories, setfiles, or MT5 evidence.
"""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import math
import os
import re
import socket
import subprocess
import sys
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.q05_stress_medium import (  # noqa: E402
    _normalize_expert,
    _parse_report_float,
    _parse_report_int,
    _report_cell,
    _select_run_summary,
    _text_from_completed_process,
    summary_invalid_reason,
)


SCHEMA_VERSION = 1
PHASE = "Q03"
FIXED_IS_FROM = "2017.01.01"
FIXED_IS_TO = "2022.12.31"
CANONICAL_REPO_ROOT = Path("C:/QM/repo").resolve()
CANONICAL_OUT_ROOT = Path("D:/QM/reports/pipeline").resolve()
TERMINAL_FACTORY_ROOT = Path("D:/QM/mt5")
RUNNER_PATH = Path(__file__).resolve()
CLAIM_FILENAME = "q03_claim.json"
LOCK_FILENAME = ".q03_execution.lock"
SUPPORTED_TERMINALS = frozenset({"T1", "T2", "T3", "T4", "T5"})
SUPPORTED_PERIODS = frozenset(
    {
        "M1", "M2", "M5", "M10", "M15", "M30",
        "H1", "H2", "H3", "H4", "H6", "H8", "H12",
        "D1", "W1", "MN1",
    }
)
MIN_GRID_CELLS = 7
MAX_GRID_CELLS = 100
MIN_PLATEAU_WIDTH = 3
MAX_RUNS_PER_CELL = 10
RUNNER_HEADROOM_SEC = 120

SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
ASSIGNMENT_RE = re.compile(
    r"^\s*(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<value>.*?)\s*$"
)
HEADER_RE = re.compile(
    r"^\s*;\s*(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?P<value>.*?)\s*$"
)
INPUT_RE = re.compile(
    r"^\s*input\s+(?P<type>[A-Za-z_][A-Za-z0-9_]*)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<default>[^;]+);",
    re.MULTILINE,
)


class ContractError(ValueError):
    """The preregistered contract or its evidence is invalid."""


class GateFailure(RuntimeError):
    """All evidence is valid, but the preregistered Q03 gate did not pass."""


@dataclass(frozen=True)
class FileIdentity:
    path: str
    sha256: str


@dataclass(frozen=True)
class AxisContract:
    name: str
    value_type: str
    values: tuple[int | float, ...]


@dataclass(frozen=True)
class ProfitabilityContract:
    profit_factor_gt: float
    minimum_fraction: float
    minimum_trades: int
    maximum_drawdown_money: float | None


@dataclass(frozen=True)
class PlateauContract:
    minimum_contiguous_width: int
    run_selection: str
    even_median: str


@dataclass(frozen=True)
class GridContract:
    spec_path: Path
    spec_sha256: str
    preregistered_at_utc: str
    preregistered_datetime: datetime
    ea_id: int
    ea_dir_name: str
    symbol: str
    period: str
    from_date: str
    to_date: str
    model: int
    identity: Mapping[str, FileIdentity]
    strategy_parameter_names: tuple[str, ...]
    axis: AxisContract
    locked_parameters: Mapping[str, Any]
    profitability: ProfitabilityContract
    plateau: PlateauContract
    runs_per_cell: int

    @property
    def cell_ids(self) -> tuple[str, ...]:
        return tuple(f"cell_{index:03d}" for index in range(len(self.axis.values)))


@dataclass(frozen=True)
class CellMetrics:
    profit_factor: float
    trades: int
    drawdown_money: float


@dataclass(frozen=True)
class CellEvidence:
    cell_id: str
    index: int
    axis_value: int | float
    metrics: CellMetrics
    setfile: Mapping[str, Any]
    deployed_setfile: Mapping[str, Any]
    summary: Mapping[str, Any]
    reports: tuple[Mapping[str, Any], ...] = ()
    tester_inis: tuple[Mapping[str, Any], ...] = ()
    tester_logs: tuple[Mapping[str, Any], ...] = ()


@dataclass(frozen=True)
class GridEvaluation:
    ordered_evidence: tuple[CellEvidence, ...]
    profitable: tuple[bool, ...]
    profitable_count: int
    profitable_fraction: float
    profitable_runs: tuple[tuple[int, int], ...]
    selected_run: tuple[int, int]
    selected_index: int

    @property
    def selected(self) -> CellEvidence:
        return self.ordered_evidence[self.selected_index]


def utc_now_iso() -> str:
    return _now_utc().replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def file_record(path: Path) -> dict[str, Any]:
    resolved = Path(path).resolve(strict=True)
    stat = resolved.stat()
    return {
        "path": str(resolved),
        "sha256": sha256_file(resolved),
        "size_bytes": stat.st_size,
        "modified_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc)
        .isoformat()
        .replace("+00:00", "Z"),
    }


def grid_spec_record(contract: GridContract) -> dict[str, Any]:
    record = file_record(contract.spec_path)
    if record["sha256"] != contract.spec_sha256:
        raise ContractError("grid spec changed after contract validation")
    return record


def _duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path) -> dict[str, Any]:
    try:
        raw = Path(path).read_text(encoding="utf-8-sig")
        value = json.loads(raw, object_pairs_hook=_duplicate_rejecting_object)
    except ContractError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"grid spec unreadable: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError("grid spec root must be an object")
    return value


def _require_keys(value: Mapping[str, Any], *, required: set[str], allowed: set[str], context: str) -> None:
    missing = sorted(required - set(value))
    unknown = sorted(set(value) - allowed)
    if missing:
        raise ContractError(f"{context} missing keys: {','.join(missing)}")
    if unknown:
        raise ContractError(f"{context} unknown keys: {','.join(unknown)}")


def _as_object(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ContractError(f"{context} must be an object")
    return value


def _as_int(value: Any, context: str, *, minimum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ContractError(f"{context} must be an integer")
    if minimum is not None and value < minimum:
        raise ContractError(f"{context} must be >= {minimum}")
    return value


def _as_float(value: Any, context: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ContractError(f"{context} must be numeric")
    parsed = float(value)
    if not math.isfinite(parsed):
        raise ContractError(f"{context} must be finite")
    return parsed


def _parse_preregistered_timestamp(value: Any) -> tuple[str, datetime]:
    if not isinstance(value, str) or not value.strip():
        raise ContractError("preregistered_at_utc must be a non-empty timestamp")
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError as exc:
        raise ContractError("preregistered_at_utc is not ISO-8601") from exc
    if parsed.tzinfo is None:
        raise ContractError("preregistered_at_utc must include a UTC offset")
    if parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ContractError("preregistered_at_utc must be UTC")
    parsed_utc = parsed.astimezone(timezone.utc)
    if parsed_utc > _now_utc():
        raise ContractError("preregistered_at_utc must not be in the future")
    return value.strip(), parsed_utc


def _parse_mt5_date(value: Any, context: str) -> tuple[str, datetime]:
    if not isinstance(value, str):
        raise ContractError(f"{context} must use YYYY.MM.DD")
    try:
        parsed = datetime.strptime(value, "%Y.%m.%d")
    except ValueError as exc:
        raise ContractError(f"{context} must use YYYY.MM.DD") from exc
    return value, parsed


def _parse_file_identity(value: Any, context: str) -> FileIdentity:
    obj = _as_object(value, context)
    _require_keys(obj, required={"path", "sha256"}, allowed={"path", "sha256"}, context=context)
    path = obj["path"]
    digest = obj["sha256"]
    if not isinstance(path, str) or not path.strip():
        raise ContractError(f"{context}.path must be non-empty")
    if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
        raise ContractError(f"{context}.sha256 must be 64 hexadecimal characters")
    return FileIdentity(path=path.strip(), sha256=digest.lower())


def load_grid_contract(spec_path: Path, expected_sha256: str) -> GridContract:
    spec_path = Path(spec_path).resolve(strict=True)
    if not SHA256_RE.fullmatch(str(expected_sha256 or "")):
        raise ContractError("--grid-spec-sha256 must be 64 hexadecimal characters")
    actual_spec_hash = sha256_file(spec_path)
    if actual_spec_hash != expected_sha256.lower():
        raise ContractError(
            f"grid spec hash mismatch: expected={expected_sha256.lower()} actual={actual_spec_hash}"
        )

    raw = load_json_strict(spec_path)
    top_keys = {
        "schema_version", "phase", "preregistered_at_utc", "ea_id", "ea_dir_name",
        "symbol", "period", "is_window", "model", "identity", "axis",
        "strategy_parameter_names", "locked_parameters", "profitability", "plateau",
        "run_contract",
    }
    _require_keys(raw, required=top_keys, allowed=top_keys, context="grid spec")
    if raw["schema_version"] != SCHEMA_VERSION:
        raise ContractError(f"schema_version must be {SCHEMA_VERSION}")
    if raw["phase"] != PHASE:
        raise ContractError(f"phase must be {PHASE}")
    preregistered, preregistered_dt = _parse_preregistered_timestamp(
        raw["preregistered_at_utc"]
    )
    ea_id = _as_int(raw["ea_id"], "ea_id", minimum=1)
    ea_dir_name = raw["ea_dir_name"]
    if not isinstance(ea_dir_name, str) or not re.fullmatch(rf"QM5_{ea_id}_[A-Za-z0-9_-]+", ea_dir_name):
        raise ContractError("ea_dir_name must match the numeric ea_id")
    symbol = raw["symbol"]
    if not isinstance(symbol, str) or not re.fullmatch(r"[A-Z0-9._-]+", symbol):
        raise ContractError("symbol must be an uppercase MT5 symbol")
    period = raw["period"]
    if period not in SUPPORTED_PERIODS:
        raise ContractError(f"unsupported period: {period!r}")
    if raw["model"] != 4:
        raise ContractError("Q03 model must be exactly 4")

    window = _as_object(raw["is_window"], "is_window")
    _require_keys(window, required={"from", "to"}, allowed={"from", "to"}, context="is_window")
    from_date, from_dt = _parse_mt5_date(window["from"], "is_window.from")
    to_date, to_dt = _parse_mt5_date(window["to"], "is_window.to")
    if (from_date, to_date) != (FIXED_IS_FROM, FIXED_IS_TO):
        raise ContractError(
            f"Q03 IS window must be exactly {FIXED_IS_FROM}-{FIXED_IS_TO}"
        )
    if from_dt >= to_dt:  # Defensive if the constants are ever edited incorrectly.
        raise ContractError("fixed Q03 IS window is invalid")

    identity_obj = _as_object(raw["identity"], "identity")
    identity_keys = {"card", "mq5", "ex5", "baseline_setfile"}
    _require_keys(identity_obj, required=identity_keys, allowed=identity_keys, context="identity")
    identities = {key: _parse_file_identity(identity_obj[key], f"identity.{key}") for key in identity_keys}

    axis_obj = _as_object(raw["axis"], "axis")
    axis_keys = {"name", "value_type", "active", "values"}
    _require_keys(axis_obj, required=axis_keys, allowed=axis_keys, context="axis")
    inventory_raw = raw["strategy_parameter_names"]
    if not isinstance(inventory_raw, list) or not inventory_raw:
        raise ContractError("strategy_parameter_names must be a non-empty array")
    strategy_parameter_names: list[str] = []
    for index, name in enumerate(inventory_raw):
        if not isinstance(name, str) or not KEY_RE.fullmatch(name):
            raise ContractError(
                f"strategy_parameter_names[{index}] must be an MQ5 input name"
            )
        if name in strategy_parameter_names:
            raise ContractError(f"duplicate strategy_parameter_names entry: {name}")
        strategy_parameter_names.append(name)

    axis_name = axis_obj["name"]
    if not isinstance(axis_name, str) or not KEY_RE.fullmatch(axis_name):
        raise ContractError("axis.name must be an MQ5 input name")
    if axis_name not in strategy_parameter_names:
        raise ContractError("axis.name must appear in strategy_parameter_names")
    if axis_obj["active"] is not True:
        raise ContractError("axis.active must be true")
    value_type = axis_obj["value_type"]
    if value_type not in {"int", "double"}:
        raise ContractError("axis.value_type must be int or double")
    values_raw = axis_obj["values"]
    if not isinstance(values_raw, list):
        raise ContractError("axis.values must be an array")
    if not MIN_GRID_CELLS <= len(values_raw) <= MAX_GRID_CELLS:
        raise ContractError(
            f"axis.values must declare {MIN_GRID_CELLS}-{MAX_GRID_CELLS} cells"
        )
    parsed_values: list[int | float] = []
    for index, raw_value in enumerate(values_raw):
        if value_type == "int":
            value = _as_int(raw_value, f"axis.values[{index}]")
        else:
            value = _as_float(raw_value, f"axis.values[{index}]")
        if parsed_values and float(value) <= float(parsed_values[-1]):
            raise ContractError("axis.values must be unique and strictly increasing")
        parsed_values.append(value)

    locked = _as_object(raw["locked_parameters"], "locked_parameters")
    if axis_name in locked:
        raise ContractError("active axis must not also appear in locked_parameters")
    for key in locked:
        if not KEY_RE.fullmatch(key):
            raise ContractError(f"locked parameter is not an MQ5 input name: {key}")
    expected_locked_names = set(strategy_parameter_names) - {axis_name}
    if set(locked) != expected_locked_names:
        raise ContractError(
            "locked_parameters must equal strategy_parameter_names minus the active axis; "
            f"missing={sorted(expected_locked_names - set(locked))} "
            f"extra={sorted(set(locked) - expected_locked_names)}"
        )

    profitability_obj = _as_object(raw["profitability"], "profitability")
    profitability_keys = {
        "profit_factor_strictly_greater_than", "minimum_fraction", "minimum_trades",
        "maximum_drawdown_money",
    }
    _require_keys(
        profitability_obj,
        required=profitability_keys,
        allowed=profitability_keys,
        context="profitability",
    )
    pf_gt = _as_float(
        profitability_obj["profit_factor_strictly_greater_than"],
        "profitability.profit_factor_strictly_greater_than",
    )
    if pf_gt < 1.0:
        raise ContractError("profit factor threshold must be >= 1.0")
    minimum_fraction = _as_float(
        profitability_obj["minimum_fraction"], "profitability.minimum_fraction"
    )
    if not 0.5 <= minimum_fraction <= 1:
        raise ContractError("profitability.minimum_fraction must be in [0.5,1]")
    minimum_trades = _as_int(
        profitability_obj["minimum_trades"], "profitability.minimum_trades", minimum=0
    )
    max_dd_raw = profitability_obj["maximum_drawdown_money"]
    maximum_drawdown = None if max_dd_raw is None else _as_float(
        max_dd_raw, "profitability.maximum_drawdown_money"
    )
    if maximum_drawdown is not None and maximum_drawdown <= 0:
        raise ContractError("maximum_drawdown_money must be null or > 0")

    plateau_obj = _as_object(raw["plateau"], "plateau")
    plateau_keys = {
        "minimum_contiguous_width", "run_selection", "cell_selection", "even_median"
    }
    _require_keys(plateau_obj, required=plateau_keys, allowed=plateau_keys, context="plateau")
    minimum_width = _as_int(
        plateau_obj["minimum_contiguous_width"],
        "plateau.minimum_contiguous_width",
        minimum=MIN_PLATEAU_WIDTH,
    )
    if minimum_width > len(parsed_values):
        raise ContractError("minimum_contiguous_width exceeds grid size")
    run_selection = plateau_obj["run_selection"]
    if run_selection not in {"widest_then_lower_start", "widest_then_higher_start"}:
        raise ContractError("unsupported plateau.run_selection")
    if plateau_obj["cell_selection"] != "median":
        raise ContractError("plateau.cell_selection must be median")
    even_median = plateau_obj["even_median"]
    if even_median not in {"lower", "upper"}:
        raise ContractError("plateau.even_median must be lower or upper")

    run_obj = _as_object(raw["run_contract"], "run_contract")
    _require_keys(
        run_obj,
        required={"runs_per_cell"},
        allowed={"runs_per_cell"},
        context="run_contract",
    )
    runs_per_cell = _as_int(run_obj["runs_per_cell"], "run_contract.runs_per_cell", minimum=2)
    if runs_per_cell > MAX_RUNS_PER_CELL:
        raise ContractError(f"runs_per_cell must be <= {MAX_RUNS_PER_CELL}")

    return GridContract(
        spec_path=spec_path,
        spec_sha256=actual_spec_hash,
        preregistered_at_utc=preregistered,
        preregistered_datetime=preregistered_dt,
        ea_id=ea_id,
        ea_dir_name=ea_dir_name,
        symbol=symbol,
        period=period,
        from_date=from_date,
        to_date=to_date,
        model=4,
        identity=identities,
        strategy_parameter_names=tuple(strategy_parameter_names),
        axis=AxisContract(axis_name, value_type, tuple(parsed_values)),
        locked_parameters=dict(locked),
        profitability=ProfitabilityContract(
            pf_gt, minimum_fraction, minimum_trades, maximum_drawdown
        ),
        plateau=PlateauContract(minimum_width, run_selection, even_median),
        runs_per_cell=runs_per_cell,
    )


def _resolve_identity_path(raw_path: str, repo_root: Path) -> Path:
    path = Path(raw_path)
    return (path if path.is_absolute() else Path(repo_root) / path).resolve(strict=True)


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve())) == os.path.normcase(str(right.resolve()))


def _validate_bound_file(
    *, name: str, actual_path: Path, declared: FileIdentity, repo_root: Path
) -> dict[str, Any]:
    actual = Path(actual_path).resolve(strict=True)
    declared_path = _resolve_identity_path(declared.path, repo_root)
    if not _same_path(actual, declared_path):
        raise ContractError(
            f"{name} path mismatch: declared={declared_path} actual={actual}"
        )
    record = file_record(actual)
    if record["sha256"] != declared.sha256:
        raise ContractError(
            f"{name} hash mismatch: declared={declared.sha256} actual={record['sha256']}"
        )
    return record


def parse_mq5_inputs(path: Path) -> dict[str, tuple[str, str]]:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    inputs: dict[str, tuple[str, str]] = {}
    for match in INPUT_RE.finditer(text):
        name = match.group("name")
        if name in inputs:
            raise ContractError(f"duplicate MQ5 input declaration: {name}")
        inputs[name] = (match.group("type"), match.group("default").strip())
    return inputs


def parse_setfile_assignments(path: Path) -> dict[str, list[str]]:
    assignments: dict[str, list[str]] = {}
    for raw in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if raw.lstrip().startswith((";", "#")):
            continue
        match = ASSIGNMENT_RE.match(raw)
        if match:
            assignments.setdefault(match.group("key"), []).append(match.group("value").strip())
    return assignments


def setfile_scalar(value: str) -> str:
    """Return the active scalar from MT5's value||start||step||stop||Y syntax."""
    return str(value).split("||", 1)[0].strip()


def parse_setfile_headers(path: Path) -> dict[str, str]:
    headers: dict[str, str] = {}
    for raw in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        match = HEADER_RE.match(raw)
        if match:
            key = match.group("key").lower()
            if key in headers:
                raise ContractError(f"duplicate setfile header: {key}")
            headers[key] = match.group("value").strip()
    return headers


def _strip_mql_quotes(value: str) -> str:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped[0] == stripped[-1] == '"':
        return stripped[1:-1]
    return stripped


def _typed_value(type_name: str, value: Any, context: str) -> Any:
    normalized_type = type_name.lower()
    if normalized_type in {"int", "uint", "long", "ulong", "short", "ushort"}:
        if isinstance(value, bool):
            raise ContractError(f"{context} must be integer-compatible")
        try:
            parsed = int(str(value).strip())
        except (TypeError, ValueError) as exc:
            raise ContractError(f"{context} must be integer-compatible") from exc
        if str(value).strip() not in {str(parsed), f"+{parsed}"}:
            try:
                if float(str(value).strip()) != parsed:
                    raise ValueError
            except ValueError as exc:
                raise ContractError(f"{context} must be an exact integer") from exc
        return parsed
    if normalized_type in {"double", "float"}:
        try:
            parsed_float = float(str(value).strip())
        except (TypeError, ValueError) as exc:
            raise ContractError(f"{context} must be numeric") from exc
        if not math.isfinite(parsed_float):
            raise ContractError(f"{context} must be finite")
        return parsed_float
    if normalized_type == "bool":
        if isinstance(value, bool):
            return value
        raw = str(value).strip().lower()
        if raw in {"true", "1"}:
            return True
        if raw in {"false", "0"}:
            return False
        raise ContractError(f"{context} must be bool-compatible")
    if normalized_type == "string":
        return _strip_mql_quotes(str(value))
    return str(value).strip()


def _format_set_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ContractError("setfile override must be finite")
        return json.dumps(value, allow_nan=False)
    if isinstance(value, str):
        if "\r" in value or "\n" in value:
            raise ContractError("setfile override string must be single-line")
        return value
    raise ContractError(f"unsupported setfile override type: {type(value).__name__}")


def _is_framework_owned_input(name: str) -> bool:
    lowered = name.casefold()
    return lowered.startswith("qm_") or lowered.startswith("risk_")


def execution_logic_records(repo_root: Path) -> dict[str, Mapping[str, Any]]:
    repo_root = Path(repo_root).resolve(strict=True)
    expected_runner = repo_root / "framework" / "scripts" / "q03_plateau_runner.py"
    run_smoke = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    if not _same_path(RUNNER_PATH, expected_runner):
        raise ContractError(
            f"runner source is not canonical: expected={expected_runner} actual={RUNNER_PATH}"
        )
    return {
        "q03_plateau_runner": file_record(RUNNER_PATH),
        "run_smoke": file_record(run_smoke),
    }


def validate_bound_environment(
    contract: GridContract,
    *,
    repo_root: Path,
    ea_dir: Path,
    card_path: Path,
    baseline_setfile: Path,
) -> dict[str, Any]:
    repo_root = Path(repo_root).resolve(strict=True)
    ea_dir = Path(ea_dir).resolve(strict=True)
    card_path = Path(card_path).resolve(strict=True)
    baseline_setfile = Path(baseline_setfile).resolve(strict=True)
    if not _same_path(repo_root, CANONICAL_REPO_ROOT):
        raise ContractError(
            f"repo root must be canonical {CANONICAL_REPO_ROOT}, got {repo_root}"
        )
    expected_ea_dir = repo_root / "framework" / "EAs" / contract.ea_dir_name
    if not _same_path(ea_dir, expected_ea_dir):
        raise ContractError(
            f"EA directory must be canonical: expected={expected_ea_dir} actual={ea_dir}"
        )
    if ea_dir.name != contract.ea_dir_name:
        raise ContractError(
            f"EA directory mismatch: declared={contract.ea_dir_name} actual={ea_dir.name}"
        )

    mq5s = sorted(ea_dir.glob("*.mq5"))
    ex5s = sorted(ea_dir.glob("*.ex5"))
    if len(mq5s) != 1 or len(ex5s) != 1:
        raise ContractError("EA directory must contain exactly one MQ5 and one EX5")
    mq5_path = mq5s[0]
    ex5_path = ex5s[0]
    if mq5_path.stem != ea_dir.name or ex5_path.stem != ea_dir.name:
        raise ContractError("MQ5/EX5 stem must match EA directory name")
    if ex5_path.stat().st_mtime < mq5_path.stat().st_mtime:
        raise ContractError("EX5 is older than MQ5")

    records = {
        "card": _validate_bound_file(
            name="card", actual_path=card_path, declared=contract.identity["card"], repo_root=repo_root
        ),
        "mq5": _validate_bound_file(
            name="mq5", actual_path=mq5_path, declared=contract.identity["mq5"], repo_root=repo_root
        ),
        "ex5": _validate_bound_file(
            name="ex5", actual_path=ex5_path, declared=contract.identity["ex5"], repo_root=repo_root
        ),
        "baseline_setfile": _validate_bound_file(
            name="baseline_setfile",
            actual_path=baseline_setfile,
            declared=contract.identity["baseline_setfile"],
            repo_root=repo_root,
        ),
    }

    card_text = card_path.read_text(encoding="utf-8-sig", errors="replace")
    if not re.search(r"(?mi)^g0_status:\s*APPROVED\s*$", card_text):
        raise ContractError("card does not declare g0_status: APPROVED")

    inputs = parse_mq5_inputs(mq5_path)
    if "qm_ea_id" not in inputs:
        raise ContractError("MQ5 missing qm_ea_id input")
    if _typed_value(inputs["qm_ea_id"][0], inputs["qm_ea_id"][1], "qm_ea_id") != contract.ea_id:
        raise ContractError("MQ5 qm_ea_id does not match grid spec")
    declared_strategy_names = set(contract.strategy_parameter_names)
    detected_strategy_names = {
        key for key in inputs if not _is_framework_owned_input(key)
    }
    if declared_strategy_names != detected_strategy_names:
        raise ContractError(
            "strategy_parameter_names must inventory every non-framework MQ5 input; "
            f"missing={sorted(detected_strategy_names - declared_strategy_names)} "
            f"extra={sorted(declared_strategy_names - detected_strategy_names)}"
        )
    strategy_inputs = {key: inputs[key] for key in contract.strategy_parameter_names}
    if contract.axis.name not in strategy_inputs:
        raise ContractError(f"axis input missing from MQ5: {contract.axis.name}")
    axis_type = strategy_inputs[contract.axis.name][0].lower()
    expected_axis_types = {"int": {"int", "uint", "long", "ulong", "short", "ushort"}, "double": {"double", "float"}}
    if axis_type not in expected_axis_types[contract.axis.value_type]:
        raise ContractError(
            f"axis type mismatch: spec={contract.axis.value_type} mq5={axis_type}"
        )

    expected_locked = set(strategy_inputs) - {contract.axis.name}
    actual_locked = set(contract.locked_parameters)
    if actual_locked != expected_locked:
        missing = sorted(expected_locked - actual_locked)
        extra = sorted(actual_locked - expected_locked)
        raise ContractError(
            f"locked_parameters must cover every non-axis strategy input; missing={missing} extra={extra}"
        )

    assignments = parse_setfile_assignments(baseline_setfile)
    for key in sorted(strategy_inputs):
        count = len(assignments.get(key, ()))
        if count != 1:
            raise ContractError(
                "baseline setfile must explicitly assign every strategy input exactly once: "
                f"{key} count={count}"
            )
        type_name, _mq5_default = strategy_inputs[key]
        _typed_value(
            type_name,
            setfile_scalar(assignments[key][0]),
            f"effective baseline {key}",
        )

    for key in sorted(expected_locked):
        type_name, _mq5_default = strategy_inputs[key]
        effective = _typed_value(
            type_name,
            setfile_scalar(assignments[key][0]),
            f"effective baseline {key}",
        )
        locked_value = _typed_value(type_name, contract.locked_parameters[key], f"locked_parameters.{key}")
        if effective != locked_value:
            raise ContractError(
                f"locked parameter differs from effective baseline: {key}: baseline={effective!r} locked={locked_value!r}"
            )

    headers = parse_setfile_headers(baseline_setfile)
    required_headers = {"ea_id": str(contract.ea_id), "symbol": contract.symbol, "timeframe": contract.period}
    for key, expected in required_headers.items():
        if headers.get(key) != expected:
            raise ContractError(
                f"baseline setfile header {key} mismatch: expected={expected!r} actual={headers.get(key)!r}"
            )
    risk_fixed = setfile_scalar(assignments.get("RISK_FIXED", [""])[-1])
    risk_percent = setfile_scalar(assignments.get("RISK_PERCENT", [""])[-1])
    try:
        if float(risk_fixed) <= 0 or float(risk_percent) != 0:
            raise ValueError
    except ValueError as exc:
        raise ContractError("baseline setfile must use positive RISK_FIXED and RISK_PERCENT=0") from exc

    return {
        "ea_dir": str(ea_dir),
        "expert": f"QM\\{ea_dir.name}",
        "files": records,
        "strategy_inputs": list(contract.strategy_parameter_names),
        "execution_logic": execution_logic_records(repo_root),
    }


def validate_terminal_contract(terminal: str, allowlist: str) -> tuple[str, tuple[str, ...]]:
    selected = str(terminal or "").strip().upper()
    tokens = [token.strip().upper() for token in str(allowlist or "").split(",") if token.strip()]
    if not tokens:
        raise ContractError("--terminal-allowlist must explicitly name at least one terminal")
    if len(tokens) != len(set(tokens)):
        raise ContractError("--terminal-allowlist contains duplicates")
    unsupported = sorted(set(tokens) - SUPPORTED_TERMINALS)
    if unsupported:
        raise ContractError(
            f"terminal allowlist contains unsupported terminals: {','.join(unsupported)}"
        )
    if selected not in SUPPORTED_TERMINALS:
        raise ContractError(f"terminal must be one of {','.join(sorted(SUPPORTED_TERMINALS))}")
    if selected not in tokens:
        raise ContractError("selected terminal is not in the explicit caller allowlist")
    return selected, tuple(tokens)


def materialize_setfile(source: Path, target: Path, overrides: Mapping[str, Any]) -> Path:
    """Replace all occurrences of each override key with exactly one assignment."""
    source = Path(source)
    target = Path(target)
    if not source.is_file():
        raise ContractError(f"baseline setfile missing: {source}")
    if not overrides:
        raise ContractError("at least one setfile override is required")
    normalized: dict[str, str] = {}
    for key, value in overrides.items():
        if not KEY_RE.fullmatch(key):
            raise ContractError(f"invalid setfile override key: {key!r}")
        normalized[key] = _format_set_value(value)

    lines = source.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    seen: set[str] = set()
    output: list[str] = []
    for line in lines:
        if line.lstrip().startswith((";", "#")):
            output.append(line)
            continue
        match = ASSIGNMENT_RE.match(line)
        key = match.group("key") if match else None
        if key in normalized:
            if key not in seen:
                output.append(f"{key}={normalized[key]}")
                seen.add(key)
            continue
        output.append(line)
    missing = sorted(set(normalized) - seen)
    if missing:
        raise ContractError(
            "setfile overrides are replace-only; source assignments missing: "
            + ",".join(missing)
        )

    counts: dict[str, int] = {key: 0 for key in normalized}
    for line in output:
        match = ASSIGNMENT_RE.match(line)
        if match and match.group("key") in counts:
            counts[match.group("key")] += 1
    bad = {key: count for key, count in counts.items() if count != 1}
    if bad:
        raise ContractError(f"materialized setfile override cardinality failure: {bad}")

    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_name(target.name + ".tmp")
    temp.write_text("\n".join(output) + "\n", encoding="utf-8", newline="\n")
    temp.replace(target)
    return target


def cell_overrides(contract: GridContract, index: int) -> dict[str, Any]:
    if not 0 <= index < len(contract.axis.values):
        raise ContractError(f"cell index out of range: {index}")
    overrides = dict(contract.locked_parameters)
    overrides[contract.axis.name] = contract.axis.values[index]
    return overrides


def profitable_runs(flags: Sequence[bool]) -> tuple[tuple[int, int], ...]:
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        if not flag and start is not None:
            runs.append((start, index - 1))
            start = None
    if start is not None:
        runs.append((start, len(flags) - 1))
    return tuple(runs)


def select_plateau_run(
    runs: Sequence[tuple[int, int]], *, minimum_width: int, run_selection: str
) -> tuple[int, int]:
    eligible = [run for run in runs if run[1] - run[0] + 1 >= minimum_width]
    if not eligible:
        raise GateFailure(f"no profitable contiguous run reaches width {minimum_width}")
    widest = max(run[1] - run[0] + 1 for run in eligible)
    candidates = [run for run in eligible if run[1] - run[0] + 1 == widest]
    if run_selection == "widest_then_lower_start":
        return min(candidates, key=lambda run: run[0])
    if run_selection == "widest_then_higher_start":
        return max(candidates, key=lambda run: run[0])
    raise ContractError(f"unsupported run selection: {run_selection}")


def median_index(run: tuple[int, int], even_median: str) -> int:
    start, end = run
    if start < 0 or end < start:
        raise ContractError(f"invalid plateau run: {run}")
    width = end - start + 1
    if even_median == "lower":
        return start + (width - 1) // 2
    if even_median == "upper":
        return start + width // 2
    raise ContractError(f"unsupported even median rule: {even_median}")


def _cell_is_profitable(evidence: CellEvidence, rule: ProfitabilityContract) -> bool:
    metrics = evidence.metrics
    return (
        metrics.profit_factor > rule.profit_factor_gt
        and metrics.trades >= rule.minimum_trades
        and (
            rule.maximum_drawdown_money is None
            or metrics.drawdown_money <= rule.maximum_drawdown_money
        )
    )


def evaluate_grid(contract: GridContract, evidence: Sequence[CellEvidence]) -> GridEvaluation:
    by_id: dict[str, CellEvidence] = {}
    for item in evidence:
        if item.cell_id in by_id:
            raise ContractError(f"duplicate cell evidence: {item.cell_id}")
        by_id[item.cell_id] = item
    expected = set(contract.cell_ids)
    actual = set(by_id)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        raise ContractError(f"cell evidence mismatch: missing={missing} extra={extra}")

    ordered: list[CellEvidence] = []
    for index, cell_id in enumerate(contract.cell_ids):
        item = by_id[cell_id]
        if item.index != index:
            raise ContractError(f"cell index mismatch for {cell_id}")
        if float(item.axis_value) != float(contract.axis.values[index]):
            raise ContractError(f"axis value mismatch for {cell_id}")
        ordered.append(item)

    flags = tuple(_cell_is_profitable(item, contract.profitability) for item in ordered)
    count = sum(flags)
    fraction = count / len(flags)
    if fraction < contract.profitability.minimum_fraction:
        raise GateFailure(
            f"profitable fraction {fraction:.12g} below required "
            f"{contract.profitability.minimum_fraction:.12g}"
        )
    runs = profitable_runs(flags)
    selected_run = select_plateau_run(
        runs,
        minimum_width=contract.plateau.minimum_contiguous_width,
        run_selection=contract.plateau.run_selection,
    )
    selected_index = median_index(selected_run, contract.plateau.even_median)
    return GridEvaluation(
        ordered_evidence=tuple(ordered),
        profitable=flags,
        profitable_count=count,
        profitable_fraction=fraction,
        profitable_runs=runs,
        selected_run=selected_run,
        selected_index=selected_index,
    )


def _load_ini(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        with Path(path).open("r", encoding="utf-8-sig", errors="replace") as handle:
            parser.read_file(handle)
    except (OSError, configparser.Error) as exc:
        raise ContractError(f"tester.ini unreadable: {path}: {exc}") from exc
    if not parser.has_section("Tester"):
        raise ContractError(f"tester.ini missing [Tester]: {path}")
    return parser


def _require_ini_value(parser: configparser.ConfigParser, key: str, expected: str, path: Path) -> None:
    actual = parser.get("Tester", key, fallback=None)
    if actual != expected:
        raise ContractError(
            f"tester.ini {key} mismatch at {path}: expected={expected!r} actual={actual!r}"
        )


def _metric_float(value: Any, context: str, *, minimum: float = 0.0) -> float:
    parsed = _as_float(value, context)
    if parsed < minimum:
        raise ContractError(f"{context} must be >= {minimum}")
    return parsed


REPORT_LABELS = {
    "Expert": ("Expert", "Expertenprogramm"),
    "Symbol": ("Symbol",),
    "Period": ("Period", "Periode"),
    "Bars": ("Bars", "Balken"),
    "Profit Factor": ("Profit Factor", "Profitfaktor"),
    "Total Trades": ("Total Trades", "Gesamtanzahl Trades"),
    "Equity Drawdown Maximal": (
        "Equity Drawdown Maximal",
        "Rückgang Equity maximal",
    ),
}


def _is_contained(path: Path, root: Path) -> bool:
    try:
        return os.path.commonpath(
            [os.path.normcase(str(path)), os.path.normcase(str(root))]
        ) == os.path.normcase(str(root))
    except ValueError:
        return False


def _fresh_contained_file(
    raw_path: Path | str,
    *,
    root: Path,
    started_at: float,
    label: str,
) -> Path:
    path = Path(raw_path).resolve(strict=True)
    root = Path(root).resolve(strict=True)
    if not _is_contained(path, root):
        raise ContractError(f"{label} escapes current cell root: {path}")
    stat = path.stat()
    if not path.is_file() or stat.st_size <= 0:
        raise ContractError(f"{label} is missing or empty: {path}")
    if stat.st_mtime < started_at:
        raise ContractError(f"{label} predates current cell invocation: {path}")
    return path


def _decode_report(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            candidate = raw.decode(encoding)
        except UnicodeError:
            continue
        if "<html" in candidate[:1000].casefold():
            return candidate
    raise ContractError(f"native report encoding/HTML invalid: {path}")


def _report_value(html: str, logical_label: str) -> str | None:
    for label in REPORT_LABELS[logical_label]:
        value = _report_cell(html, label)
        if value is not None:
            return value
    return None


def parse_native_report_metrics(
    report_path: Path,
    *,
    expected_expert: str,
    expected_symbol: str,
    expected_period: str,
) -> CellMetrics:
    html = _decode_report(report_path)
    expert = _report_value(html, "Expert")
    symbol = _report_value(html, "Symbol")
    period = _report_value(html, "Period")
    bars = _parse_report_int(_report_value(html, "Bars"))
    if not expert or not symbol or not period or bars is None or bars <= 0:
        raise ContractError(f"native report identity/bars invalid: {report_path}")
    report_period = re.split(r"[\s(]", period.strip(), maxsplit=1)[0]
    if (
        _normalize_expert(expert) != _normalize_expert(expected_expert)
        or symbol.strip().casefold() != expected_symbol.strip().casefold()
        or report_period.casefold() != expected_period.strip().casefold()
    ):
        raise ContractError(f"native report identity mismatch: {report_path}")
    pf = _parse_report_float(_report_value(html, "Profit Factor"))
    trades = _parse_report_int(_report_value(html, "Total Trades"))
    drawdown = _parse_report_float(_report_value(html, "Equity Drawdown Maximal"))
    if pf is None or trades is None or drawdown is None:
        raise ContractError(f"native report metrics missing: {report_path}")
    return CellMetrics(
        _metric_float(pf, f"native report PF {report_path}"),
        _as_int(trades, f"native report trades {report_path}", minimum=0),
        _metric_float(drawdown, f"native report drawdown {report_path}"),
    )


def parse_cell_summary(
    summary_path: Path,
    *,
    contract: GridContract,
    cell_id: str,
    index: int,
    axis_value: int | float,
    expert: str,
    terminal: str,
    materialized_setfile: Path,
    deployed_setfile: Path,
    expected_set_sha256: str,
    cell_root: Path,
    invocation_started_at: float,
) -> CellEvidence:
    cell_root = Path(cell_root).resolve(strict=True)
    summary_path = _fresh_contained_file(
        summary_path,
        root=cell_root,
        started_at=invocation_started_at,
        label="summary",
    )
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"summary unreadable: {summary_path}: {exc}") from exc
    if not isinstance(summary, dict):
        raise ContractError(f"summary root is not an object: {summary_path}")
    if str(summary.get("result") or "").upper() != "PASS":
        raise ContractError(f"cell summary result must be PASS: {cell_id}")
    reasons = summary.get("reason_classes")
    if not isinstance(reasons, list) or [str(reason).upper() for reason in reasons] != ["OK"]:
        raise ContractError(f"cell summary reason_classes must be exactly [OK]: {cell_id}")
    invalid_reason = summary_invalid_reason(summary_path)
    if invalid_reason:
        raise ContractError(f"invalid cell summary {cell_id}: {invalid_reason}")
    expected_identity = {
        "ea_id": contract.ea_id,
        "expert": expert,
        "symbol": contract.symbol,
        "period": contract.period,
        "terminal": terminal,
        "model": 4,
    }
    for key, expected in expected_identity.items():
        actual = summary.get(key)
        if str(actual).replace("/", "\\").casefold() != str(expected).replace("/", "\\").casefold():
            raise ContractError(
                f"summary identity mismatch {cell_id}.{key}: expected={expected!r} actual={actual!r}"
            )
    if summary.get("deterministic") is not True:
        raise ContractError(f"nondeterministic cell summary: {cell_id}")
    if summary.get("model4_log_marker_detected") is not True:
        raise ContractError(f"model4 marker missing: {cell_id}")
    if summary.get("oninit_failure_detected") is True:
        raise ContractError(f"OnInit failure detected: {cell_id}")
    if summary.get("log_bomb_detected") is True:
        raise ContractError(f"log bomb detected: {cell_id}")
    if summary.get("requested_runs") != contract.runs_per_cell:
        raise ContractError(f"requested_runs mismatch: {cell_id}")
    runs = summary.get("runs")
    if not isinstance(runs, list) or len(runs) != contract.runs_per_cell:
        raise ContractError(f"incomplete run evidence: {cell_id}")

    metrics: list[CellMetrics] = []
    report_records: list[Mapping[str, Any]] = []
    ini_records: list[Mapping[str, Any]] = []
    log_records: list[Mapping[str, Any]] = []
    seen_reports: set[str] = set()
    for run_index, run in enumerate(runs, start=1):
        if not isinstance(run, dict):
            raise ContractError(f"run evidence is not an object: {cell_id}/run_{run_index:02d}")
        if str(run.get("status") or "").upper() != "OK" or run.get("exit_code") != 0:
            raise ContractError(f"non-OK run evidence: {cell_id}/run_{run_index:02d}")
        if run.get("real_ticks_marker") is not True:
            raise ContractError(f"real-ticks marker missing: {cell_id}/run_{run_index:02d}")
        pf = _metric_float(run.get("profit_factor"), f"{cell_id}.profit_factor")
        dd = _metric_float(run.get("drawdown"), f"{cell_id}.drawdown")
        trades = _as_int(run.get("total_trades"), f"{cell_id}.total_trades", minimum=0)
        metrics.append(CellMetrics(pf, trades, dd))

        report_raw = run.get("report_canonical_path")
        log_raw = run.get("tester_log_path")
        if not isinstance(report_raw, str) or not report_raw:
            raise ContractError(f"report path missing: {cell_id}/run_{run_index:02d}")
        if not isinstance(log_raw, str) or not log_raw:
            raise ContractError(f"tester log path missing: {cell_id}/run_{run_index:02d}")
        report_path = Path(report_raw).resolve(strict=True)
        report_path = _fresh_contained_file(
            report_path,
            root=cell_root,
            started_at=invocation_started_at,
            label=f"report {cell_id}/run_{run_index:02d}",
        )
        log_path = _fresh_contained_file(
            log_raw,
            root=cell_root,
            started_at=invocation_started_at,
            label=f"tester log {cell_id}/run_{run_index:02d}",
        )
        report_key = os.path.normcase(str(report_path))
        if report_key in seen_reports:
            raise ContractError(f"duplicate report evidence: {cell_id}")
        seen_reports.add(report_key)

        ini_path = report_path.parent / "tester.ini"
        ini_path = _fresh_contained_file(
            ini_path,
            root=cell_root,
            started_at=invocation_started_at,
            label=f"tester.ini {cell_id}/run_{run_index:02d}",
        )
        ini = _load_ini(ini_path)
        _require_ini_value(ini, "Expert", expert, ini_path)
        _require_ini_value(ini, "Symbol", contract.symbol, ini_path)
        _require_ini_value(ini, "Period", contract.period, ini_path)
        _require_ini_value(ini, "Model", "4", ini_path)
        _require_ini_value(ini, "FromDate", contract.from_date, ini_path)
        _require_ini_value(ini, "ToDate", contract.to_date, ini_path)
        _require_ini_value(ini, "ExpertParameters", materialized_setfile.name, ini_path)
        report_metrics = parse_native_report_metrics(
            report_path,
            expected_expert=expert,
            expected_symbol=contract.symbol,
            expected_period=contract.period,
        )
        if report_metrics != metrics[-1]:
            raise ContractError(
                f"summary/native report metrics mismatch: {cell_id}/run_{run_index:02d}"
            )
        report_records.append(file_record(report_path))
        ini_records.append(file_record(ini_path))
        log_records.append(file_record(log_path))

    first = metrics[0]
    if any(item != first for item in metrics[1:]):
        raise ContractError(f"nondeterministic metrics across runs: {cell_id}")
    set_record = file_record(materialized_setfile)
    if set_record["sha256"] != expected_set_sha256:
        raise ContractError(f"materialized setfile changed during invocation: {cell_id}")
    deployed_record = file_record(deployed_setfile)
    if deployed_record["sha256"] != expected_set_sha256:
        raise ContractError(f"tester-deployed setfile hash mismatch: {cell_id}")
    if Path(deployed_record["path"]).name != materialized_setfile.name:
        raise ContractError(f"tester-deployed setfile basename mismatch: {cell_id}")
    expected_deployed = (
        TERMINAL_FACTORY_ROOT
        / terminal
        / "MQL5"
        / "Profiles"
        / "Tester"
        / materialized_setfile.name
    ).resolve()
    if not _same_path(Path(str(deployed_record["path"])), expected_deployed):
        raise ContractError(f"tester-deployed setfile path mismatch: {cell_id}")
    return CellEvidence(
        cell_id=cell_id,
        index=index,
        axis_value=axis_value,
        metrics=first,
        setfile=set_record,
        deployed_setfile=deployed_record,
        summary=file_record(summary_path),
        reports=tuple(report_records),
        tester_inis=tuple(ini_records),
        tester_logs=tuple(log_records),
    )


def build_run_smoke_command(
    *,
    repo_root: Path,
    contract: GridContract,
    expert: str,
    terminal: str,
    cell_id: str,
    setfile: Path,
    report_root: Path,
    timeout_sec: int,
) -> list[str]:
    year = contract.to_date.split(".", 1)[0]
    return [
        "pwsh.exe", "-NoProfile", "-File", str(Path(repo_root) / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId", str(contract.ea_id),
        "-Expert", expert,
        "-Symbol", contract.symbol,
        "-Year", year,
        "-FromDate", contract.from_date,
        "-ToDate", contract.to_date,
        "-Terminal", terminal,
        "-Period", contract.period,
        "-DispatchSubGateHash", f"{contract.spec_sha256[:12]}_{cell_id}",
        "-DispatchPhase", PHASE,
        "-DispatchVersion", "q03_plateau_v1",
        "-Runs", str(contract.runs_per_cell),
        # Q03 grades the preregistered trade floor after infrastructure evidence
        # is valid. A smoke-level floor would turn a valid losing cell into FAIL.
        "-MinTrades", "0",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]


def cell_setfile_name(contract: GridContract, cell_id: str) -> str:
    nonce = uuid.uuid4().hex
    return (
        f"QM5_{contract.ea_id}_Q03_{contract.spec_sha256[:20]}_"
        f"{cell_id}_{nonce}.set"
    )


def run_cell(
    *,
    repo_root: Path,
    contract: GridContract,
    environment: Mapping[str, Any],
    terminal: str,
    index: int,
    run_dir: Path,
    timeout_sec: int,
) -> CellEvidence:
    cell_id = contract.cell_ids[index]
    axis_value = contract.axis.values[index]
    cell_set = run_dir / "setfiles" / cell_setfile_name(contract, cell_id)
    baseline = Path(environment["files"]["baseline_setfile"]["path"])
    materialize_setfile(baseline, cell_set, cell_overrides(contract, index))
    prelaunch_set_record = file_record(cell_set)
    deployed_setfile = (
        TERMINAL_FACTORY_ROOT
        / terminal
        / "MQL5"
        / "Profiles"
        / "Tester"
        / cell_set.name
    )
    cell_report_root = run_dir / "reports" / cell_id
    command = build_run_smoke_command(
        repo_root=repo_root,
        contract=contract,
        expert=str(environment["expert"]),
        terminal=terminal,
        cell_id=cell_id,
        setfile=cell_set,
        report_root=cell_report_root,
        timeout_sec=timeout_sec,
    )
    started_at = time.time()
    try:
        proc = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout_sec * contract.runs_per_cell + RUNNER_HEADROOM_SEC,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        output_text = _text_from_completed_process(proc)
        if proc.returncode != 0:
            raise ContractError(
                f"run_smoke returned {proc.returncode} for {cell_id}: {output_text[-2000:]}"
            )
    except subprocess.TimeoutExpired as exc:
        output_text = _text_from_completed_process(exc)
        raise ContractError(f"run_smoke timed out for {cell_id}: {output_text[-2000:]}") from exc
    except OSError as exc:
        raise ContractError(f"failed to launch run_smoke for {cell_id}: {exc}") from exc
    summary = _select_run_summary(
        output_text,
        cell_report_root,
        started_at=started_at,
        ea_id=contract.ea_id,
        ea_expert=str(environment["expert"]),
        symbol=contract.symbol,
        period=contract.period,
        terminal=terminal,
    )
    if summary is None:
        raise ContractError(f"fresh matching summary missing for {cell_id}")
    if sha256_file(cell_set) != prelaunch_set_record["sha256"]:
        raise ContractError(f"materialized setfile changed during invocation: {cell_id}")
    return parse_cell_summary(
        summary,
        contract=contract,
        cell_id=cell_id,
        index=index,
        axis_value=axis_value,
        expert=str(environment["expert"]),
        terminal=terminal,
        materialized_setfile=cell_set,
        deployed_setfile=deployed_setfile,
        expected_set_sha256=str(prelaunch_set_record["sha256"]),
        cell_root=cell_report_root,
        invocation_started_at=started_at,
    )


def build_plan(
    contract: GridContract,
    *,
    environment: Mapping[str, Any],
    terminal: str,
    terminal_allowlist: Sequence[str],
    out_root: Path,
) -> dict[str, Any]:
    canonical_out_root = _validate_out_root(out_root)
    out_dir = canonical_out_root / f"QM5_{contract.ea_id}" / PHASE / contract.symbol.replace(".", "_")
    return {
        "mode": "plan",
        "phase": PHASE,
        "grid_spec": grid_spec_record(contract),
        "preregistered_at_utc": contract.preregistered_at_utc,
        "ea_id": contract.ea_id,
        "ea_dir_name": contract.ea_dir_name,
        "symbol": contract.symbol,
        "period": contract.period,
        "model": contract.model,
        "is_window": {"from": contract.from_date, "to": contract.to_date},
        "axis": {
            "name": contract.axis.name,
            "value_type": contract.axis.value_type,
            "values": list(contract.axis.values),
        },
        "strategy_parameter_names": list(contract.strategy_parameter_names),
        "locked_parameters": dict(contract.locked_parameters),
        "cells": [
            {
                "cell_id": cell_id,
                "index": index,
                "axis_value": contract.axis.values[index],
                "overrides": cell_overrides(contract, index),
            }
            for index, cell_id in enumerate(contract.cell_ids)
        ],
        "terminal": terminal,
        "terminal_allowlist": list(terminal_allowlist),
        "identity": environment["files"],
        "execution_logic": environment["execution_logic"],
        "prospective_claim": {
            "path": str(out_dir / CLAIM_FILENAME),
            "spec_sha256": contract.spec_sha256,
            "preregistered_at_utc": contract.preregistered_at_utc,
            "execution_logic": environment["execution_logic"],
            "exclusive_create_before_cells": True,
        },
        "would_write": {
            "claim": str(out_dir / CLAIM_FILENAME),
            "plateau_pick": str(out_dir / "plateau_pick.json"),
            "selected_set": str(out_dir / "plateau_median.set"),
        },
        "writes_performed": False,
        "mt5_launched": False,
    }


def _evidence_payload(item: CellEvidence, profitable: bool) -> dict[str, Any]:
    return {
        "cell_id": item.cell_id,
        "index": item.index,
        "axis_value": item.axis_value,
        "profitable": profitable,
        "metrics": {
            "profit_factor": item.metrics.profit_factor,
            "trades": item.metrics.trades,
            "drawdown_money": item.metrics.drawdown_money,
        },
        "setfile": dict(item.setfile),
        "deployed_setfile": dict(item.deployed_setfile),
        "summary": dict(item.summary),
        "reports": [dict(record) for record in item.reports],
        "tester_inis": [dict(record) for record in item.tester_inis],
        "tester_logs": [dict(record) for record in item.tester_logs],
    }


def build_plateau_payload(
    contract: GridContract,
    evaluation: GridEvaluation,
    *,
    environment: Mapping[str, Any],
    terminal: str,
    terminal_allowlist: Sequence[str],
    selected_set_record: Mapping[str, Any],
    claim_record: Mapping[str, Any],
) -> dict[str, Any]:
    selected = evaluation.selected
    return {
        "schema_version": 1,
        "phase": PHASE,
        "verdict": "PASS",
        "generated_at_utc": utc_now_iso(),
        "preregistered_at_utc": contract.preregistered_at_utc,
        "ea_id": contract.ea_id,
        "ea_dir_name": contract.ea_dir_name,
        "symbol": contract.symbol,
        "period": contract.period,
        "model": contract.model,
        "is_window": {"from": contract.from_date, "to": contract.to_date},
        "grid_spec": grid_spec_record(contract),
        "identity": environment["files"],
        "execution_logic": environment["execution_logic"],
        "prospective_claim": dict(claim_record),
        "terminal_contract": {
            "selected": terminal,
            "caller_allowlist": list(terminal_allowlist),
            "supported": sorted(SUPPORTED_TERMINALS),
        },
        "axis": {
            "name": contract.axis.name,
            "value_type": contract.axis.value_type,
            "values": list(contract.axis.values),
        },
        "strategy_parameter_names": list(contract.strategy_parameter_names),
        "locked_parameters": dict(contract.locked_parameters),
        "profitability_rule": {
            "profit_factor_strictly_greater_than": contract.profitability.profit_factor_gt,
            "minimum_fraction": contract.profitability.minimum_fraction,
            "minimum_trades": contract.profitability.minimum_trades,
            "maximum_drawdown_money": contract.profitability.maximum_drawdown_money,
        },
        "plateau_rule": {
            "minimum_contiguous_width": contract.plateau.minimum_contiguous_width,
            "run_selection": contract.plateau.run_selection,
            "cell_selection": "median",
            "even_median": contract.plateau.even_median,
        },
        "run_contract": {
            "runs_per_cell": contract.runs_per_cell,
            "require_identical_metrics": True,
            "require_model4_marker": True,
            "require_real_ticks_marker": True,
        },
        "evaluation": {
            "total_cells": len(evaluation.ordered_evidence),
            "profitable_cells": evaluation.profitable_count,
            "profitable_fraction": evaluation.profitable_fraction,
            "profitable_runs": [
                {"start_index": start, "end_index": end, "width": end - start + 1}
                for start, end in evaluation.profitable_runs
            ],
            "selected_run": {
                "start_index": evaluation.selected_run[0],
                "end_index": evaluation.selected_run[1],
                "width": evaluation.selected_run[1] - evaluation.selected_run[0] + 1,
            },
            "selected_cell_id": selected.cell_id,
            "selected_index": selected.index,
            "selected_axis_value": selected.axis_value,
        },
        "params": {contract.axis.name: selected.axis_value},
        "selected_set": dict(selected_set_record),
        "cells": [
            _evidence_payload(item, evaluation.profitable[index])
            for index, item in enumerate(evaluation.ordered_evidence)
        ],
    }


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(text, encoding="utf-8", newline="\n")
    temp.replace(path)


def write_json_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    _atomic_write_text(path, json.dumps(payload, indent=2, sort_keys=True) + "\n")


def _read_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8-sig"),
            object_pairs_hook=_duplicate_rejecting_object,
        )
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"{label} unreadable: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError(f"{label} root must be an object: {path}")
    return value


def _write_json_exclusive(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8")
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o444)
    except FileExistsError:
        raise
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
    except BaseException:
        try:
            path.unlink()
        except OSError:
            pass
        raise


def _pid_is_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def _acquire_execution_lock(out_dir: Path, contract: GridContract) -> tuple[Path, str]:
    lock_path = out_dir / LOCK_FILENAME
    token = uuid.uuid4().hex
    payload = {
        "schema_version": 1,
        "phase": PHASE,
        "spec_sha256": contract.spec_sha256,
        "pid": os.getpid(),
        "hostname": socket.gethostname(),
        "token": token,
        "created_at_utc": utc_now_iso(),
    }
    for attempt in range(2):
        try:
            _write_json_exclusive(lock_path, payload)
            return lock_path, token
        except FileExistsError:
            existing = _read_json_object(lock_path, "Q03 execution lock")
            if str(existing.get("spec_sha256") or "") != contract.spec_sha256:
                raise ContractError("Q03 execution lock belongs to a different grid spec")
            same_host = str(existing.get("hostname") or "") == socket.gethostname()
            try:
                owner_pid = int(existing.get("pid"))
            except (TypeError, ValueError):
                owner_pid = -1
            commit_exists = (out_dir / "plateau_pick.json").exists()
            if attempt == 0 and not commit_exists and same_host and not _pid_is_alive(owner_pid):
                lock_path.unlink()
                continue
            raise ContractError("Q03 execution lock is already held")
    raise ContractError("could not acquire Q03 execution lock")


def _release_execution_lock(lock_path: Path, token: str) -> None:
    try:
        current = _read_json_object(lock_path, "Q03 execution lock")
        if current.get("token") == token:
            lock_path.unlink()
    except (ContractError, FileNotFoundError, OSError):
        pass


def _claim_payload(
    contract: GridContract,
    *,
    out_dir: Path,
    environment: Mapping[str, Any],
    claimed_at: str,
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "phase": PHASE,
        "spec_sha256": contract.spec_sha256,
        "grid_spec": grid_spec_record(contract),
        "preregistered_at_utc": contract.preregistered_at_utc,
        "claimed_at_utc": claimed_at,
        "ea_id": contract.ea_id,
        "ea_dir_name": contract.ea_dir_name,
        "symbol": contract.symbol,
        "out_dir": str(out_dir.resolve()),
        "execution_logic": environment["execution_logic"],
    }


def _claim_matches(
    claim: Mapping[str, Any],
    contract: GridContract,
    *,
    out_dir: Path,
    environment: Mapping[str, Any],
) -> None:
    expected = {
        "schema_version": 1,
        "phase": PHASE,
        "spec_sha256": contract.spec_sha256,
        "preregistered_at_utc": contract.preregistered_at_utc,
        "ea_id": contract.ea_id,
        "ea_dir_name": contract.ea_dir_name,
        "symbol": contract.symbol,
        "out_dir": str(out_dir.resolve()),
        "execution_logic": environment["execution_logic"],
    }
    for key, value in expected.items():
        if claim.get(key) != value:
            raise ContractError(f"immutable Q03 claim mismatch: {key}")
    grid_spec = claim.get("grid_spec")
    if not isinstance(grid_spec, dict) or grid_spec.get("sha256") != contract.spec_sha256:
        raise ContractError("immutable Q03 claim grid spec mismatch")
    claimed_text = claim.get("claimed_at_utc")
    try:
        claimed_at = datetime.fromisoformat(str(claimed_text).replace("Z", "+00:00"))
    except ValueError as exc:
        raise ContractError("immutable Q03 claim timestamp invalid") from exc
    if claimed_at.tzinfo is None or claimed_at.astimezone(timezone.utc) > _now_utc():
        raise ContractError("immutable Q03 claim timestamp is future/naive")
    if contract.preregistered_datetime > claimed_at.astimezone(timezone.utc):
        raise ContractError("grid spec preregistration timestamp is after its immutable claim")


def _recover_same_spec_partials(out_dir: Path) -> None:
    if (out_dir / "plateau_pick.json").exists():
        raise ContractError("canonical Q03 commit marker already exists")
    for path in (
        out_dir / "plateau_median.set",
        out_dir / "plateau_pick.json.sha256",
    ):
        if path.exists():
            path.unlink()


@contextmanager
def prospective_execution_claim(
    contract: GridContract,
    *,
    out_dir: Path,
    environment: Mapping[str, Any],
) -> Iterator[Mapping[str, Any]]:
    lock_path, token = _acquire_execution_lock(out_dir, contract)
    claim_path = out_dir / CLAIM_FILENAME
    try:
        if (out_dir / "plateau_pick.json").exists():
            raise ContractError("canonical Q03 commit marker already exists")
        if claim_path.exists():
            claim = _read_json_object(claim_path, "immutable Q03 claim")
            _claim_matches(
                claim,
                contract,
                out_dir=out_dir,
                environment=environment,
            )
            _recover_same_spec_partials(out_dir)
        else:
            partials = [
                path
                for path in (
                    out_dir / "plateau_median.set",
                    out_dir / "plateau_pick.json.sha256",
                )
                if path.exists()
            ]
            if partials:
                raise ContractError("unclaimed Q03 publication partials require manual review")
            claimed_at = utc_now_iso()
            if contract.preregistered_datetime > datetime.fromisoformat(
                claimed_at.replace("Z", "+00:00")
            ):
                raise ContractError("grid spec timestamp is after claim timestamp")
            claim = _claim_payload(
                contract,
                out_dir=out_dir,
                environment=environment,
                claimed_at=claimed_at,
            )
            try:
                _write_json_exclusive(claim_path, claim)
            except FileExistsError as exc:
                raise ContractError("immutable Q03 claim was created concurrently") from exc
        claim_record = file_record(claim_path)
        yield claim_record
        if file_record(claim_path) != claim_record:
            raise ContractError("immutable Q03 claim changed during execution")
    finally:
        _release_execution_lock(lock_path, token)


def _verify_record_unchanged(record: Mapping[str, Any], label: str) -> None:
    current = file_record(Path(str(record["path"])))
    if (
        current["sha256"] != record.get("sha256")
        or current["size_bytes"] != record.get("size_bytes")
    ):
        raise ContractError(f"{label} changed after validation")


def _verify_evidence_unchanged(evidence: Sequence[CellEvidence]) -> None:
    for item in evidence:
        _verify_record_unchanged(item.setfile, f"{item.cell_id} setfile")
        _verify_record_unchanged(
            item.deployed_setfile, f"{item.cell_id} tester-deployed setfile"
        )
        _verify_record_unchanged(item.summary, f"{item.cell_id} summary")
        for label, records in (
            ("report", item.reports),
            ("tester.ini", item.tester_inis),
            ("tester log", item.tester_logs),
        ):
            for index, record in enumerate(records, start=1):
                _verify_record_unchanged(record, f"{item.cell_id} {label} {index}")


def _validate_out_root(out_root: Path) -> Path:
    resolved = Path(out_root).resolve()
    if not _same_path(resolved, CANONICAL_OUT_ROOT):
        raise ContractError(
            f"out root must be canonical {CANONICAL_OUT_ROOT}, got {resolved}"
        )
    return resolved


def _execute_claimed(
    contract: GridContract,
    *,
    repo_root: Path,
    ea_dir: Path,
    card_path: Path,
    baseline_setfile: Path,
    terminal: str,
    terminal_allowlist: Sequence[str],
    out_dir: Path,
    timeout_sec: int,
    environment: Mapping[str, Any],
    claim_record: Mapping[str, Any],
) -> dict[str, Any]:
    pick_path = out_dir / "plateau_pick.json"
    pick_sha_path = out_dir / "plateau_pick.json.sha256"
    selected_set_path = out_dir / "plateau_median.set"
    run_tag = _now_utc().strftime("%Y%m%d_%H%M%S_%f")
    run_dir = (
        out_dir
        / "runs"
        / f"{run_tag}_{contract.spec_sha256[:12]}_{uuid.uuid4().hex[:12]}"
    )
    evidence = [
        run_cell(
            repo_root=repo_root,
            contract=contract,
            environment=environment,
            terminal=terminal,
            index=index,
            run_dir=run_dir,
            timeout_sec=timeout_sec,
        )
        for index in range(len(contract.axis.values))
    ]
    evaluation = evaluate_grid(contract, evidence)

    if sha256_file(contract.spec_path) != contract.spec_sha256:
        raise ContractError("grid spec changed during execution")
    final_environment = validate_bound_environment(
        contract,
        repo_root=repo_root,
        ea_dir=ea_dir,
        card_path=card_path,
        baseline_setfile=baseline_setfile,
    )
    if final_environment["files"] != environment["files"]:
        raise ContractError("bound EA/card/set artifacts changed during execution")
    if final_environment["execution_logic"] != environment["execution_logic"]:
        raise ContractError("runner or run_smoke changed during execution")
    _verify_record_unchanged(claim_record, "immutable Q03 claim")
    _verify_evidence_unchanged(evidence)

    publication_stage = run_dir / "publication"
    staged_set_path = publication_stage / selected_set_path.name
    staged_pick_path = publication_stage / pick_path.name
    staged_pick_sha_path = publication_stage / pick_sha_path.name
    materialize_setfile(
        baseline_setfile,
        staged_set_path,
        cell_overrides(contract, evaluation.selected_index),
    )
    staged_set_record = file_record(staged_set_path)
    if staged_set_record["sha256"] != evaluation.selected.setfile["sha256"]:
        raise ContractError("selected set does not match the selected cell setfile")
    selected_set_record = dict(staged_set_record)
    selected_set_record["path"] = str(selected_set_path.resolve())
    payload = build_plateau_payload(
        contract,
        evaluation,
        environment=final_environment,
        terminal=terminal,
        terminal_allowlist=terminal_allowlist,
        selected_set_record=selected_set_record,
        claim_record=claim_record,
    )
    write_json_atomic(staged_pick_path, payload)
    pick_hash = sha256_file(staged_pick_path)
    _atomic_write_text(staged_pick_sha_path, f"{pick_hash}  {pick_path.name}\n")

    publish_environment = validate_bound_environment(
        contract,
        repo_root=repo_root,
        ea_dir=ea_dir,
        card_path=card_path,
        baseline_setfile=baseline_setfile,
    )
    if publish_environment["files"] != environment["files"]:
        raise ContractError("bound EA/card/set artifacts changed before publication")
    if publish_environment["execution_logic"] != environment["execution_logic"]:
        raise ContractError("runner or run_smoke changed before publication")
    _verify_record_unchanged(claim_record, "immutable Q03 claim")
    _verify_evidence_unchanged(evidence)

    # Publish the pick last as the commit marker. Every rename is same-volume and
    # atomic; on an earlier failure, no authoritative plateau_pick.json exists.
    published: list[Path] = []
    try:
        out_dir.mkdir(parents=True, exist_ok=True)
        staged_set_path.replace(selected_set_path)
        published.append(selected_set_path)
        final_set_record = file_record(selected_set_path)
        if final_set_record["sha256"] != selected_set_record["sha256"]:
            raise ContractError("published plateau_median.set hash mismatch")
        staged_pick_sha_path.replace(pick_sha_path)
        published.append(pick_sha_path)
        staged_pick_path.replace(pick_path)
        published.append(pick_path)
    except (OSError, ContractError) as exc:
        for path in reversed(published):
            try:
                path.unlink()
            except OSError:
                pass
        if isinstance(exc, ContractError):
            raise
        raise ContractError(f"atomic Q03 publication failed: {exc}") from exc

    return {
        "status": "PASS",
        "plateau_pick": str(pick_path.resolve()),
        "plateau_pick_sha256": pick_hash,
        "plateau_pick_sha256_sidecar": str(pick_sha_path.resolve()),
        "selected_set": final_set_record,
        "selected_cell_id": evaluation.selected.cell_id,
        "selected_axis_value": evaluation.selected.axis_value,
        "run_dir": str(run_dir.resolve()),
    }


def execute(
    contract: GridContract,
    *,
    repo_root: Path,
    ea_dir: Path,
    card_path: Path,
    baseline_setfile: Path,
    terminal: str,
    terminal_allowlist: Sequence[str],
    out_root: Path,
    timeout_sec: int,
) -> dict[str, Any]:
    canonical_out_root = _validate_out_root(out_root)
    out_dir = (
        canonical_out_root
        / f"QM5_{contract.ea_id}"
        / PHASE
        / contract.symbol.replace(".", "_")
    )
    environment = validate_bound_environment(
        contract,
        repo_root=repo_root,
        ea_dir=ea_dir,
        card_path=card_path,
        baseline_setfile=baseline_setfile,
    )
    with prospective_execution_claim(
        contract,
        out_dir=out_dir,
        environment=environment,
    ) as claim_record:
        return _execute_claimed(
            contract,
            repo_root=repo_root,
            ea_dir=ea_dir,
            card_path=card_path,
            baseline_setfile=baseline_setfile,
            terminal=terminal,
            terminal_allowlist=terminal_allowlist,
            out_dir=out_dir,
            timeout_sec=timeout_sec,
            environment=environment,
            claim_record=claim_record,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--grid-spec", type=Path, required=True)
    parser.add_argument("--grid-spec-sha256", required=True)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--ea-dir", type=Path, required=True)
    parser.add_argument("--card", type=Path, required=True)
    parser.add_argument("--baseline-setfile", type=Path, required=True)
    parser.add_argument("--terminal", required=True)
    parser.add_argument(
        "--terminal-allowlist",
        required=True,
        help="Explicit comma-separated caller allowlist; only T1-T5 are supported",
    )
    parser.add_argument("--out-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    parser.add_argument("--timeout-sec", type=int, default=1800)
    parser.add_argument("--plan", "--dry-run", action="store_true", dest="plan")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.timeout_sec <= 0:
            raise ContractError("--timeout-sec must be > 0")
        contract = load_grid_contract(args.grid_spec, args.grid_spec_sha256)
        terminal, terminal_allowlist = validate_terminal_contract(
            args.terminal, args.terminal_allowlist
        )
        environment = validate_bound_environment(
            contract,
            repo_root=args.repo_root,
            ea_dir=args.ea_dir,
            card_path=args.card,
            baseline_setfile=args.baseline_setfile,
        )
        if args.plan:
            print(
                json.dumps(
                    build_plan(
                        contract,
                        environment=environment,
                        terminal=terminal,
                        terminal_allowlist=terminal_allowlist,
                        out_root=args.out_root,
                    ),
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        result = execute(
            contract,
            repo_root=args.repo_root,
            ea_dir=args.ea_dir,
            card_path=args.card,
            baseline_setfile=args.baseline_setfile,
            terminal=terminal,
            terminal_allowlist=terminal_allowlist,
            out_root=args.out_root,
            timeout_sec=args.timeout_sec,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except GateFailure as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, sort_keys=True), file=sys.stderr)
        return 1
    except (ContractError, FileNotFoundError) as exc:
        print(json.dumps({"status": "INVALID", "reason": str(exc)}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
