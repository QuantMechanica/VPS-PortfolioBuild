#!/usr/bin/env python3
"""DL-084 Q15 challenger-build and parameter-freeze validator.

The validator is intentionally analytic.  It never launches MT5.  Builders
provide already-produced DEV sweep and default-OFF smoke evidence; this script
checks those sealed artifacts, the new EA identity, registry/resolver state,
source wiring, and fixed-risk setfile.  Dry-run is the default.

``--apply`` atomically writes the immutable freeze addendum, closes the trial
ledger, appends a done Q15 ``CHALLENGER_SPAWNED`` work item with an authenticated
Q14 dependency, and appends exactly one pending standard Q02 seed.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
import re
import sqlite3
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence


OPT_CARD_SCHEMA = "qm.opt-card/v1"
TRIAL_LEDGER_SCHEMA = "qm.opt-trial-ledger/v1"
DEV_SWEEP_SCHEMA = "qm.opt-dev-sweep/v1"
EQUIVALENCE_SCHEMA = "qm.q15-default-off-equivalence/v1"
TRADE_BEHAVIOR_SCHEMA = "qm.trade-behavior/v1"
FREEZE_SCHEMA = "qm.opt-card-freeze/v1"
Q15_PAYLOAD_SCHEMA = "qm.q15-challenger-freeze/v1"
Q02_PAYLOAD_SCHEMA = "qm.q15-q02-seed/v1"
RESULT_SCHEMA = "qm.q15-freeze-check-result/v1"

RISK_FIXED = 1000.0
RISK_PERCENT = 0.0
LEVER_ENABLE_INPUT = "strategy_opt_enabled"
PLATEAU_RELATIVE_TOLERANCE = 0.05
PREDICATE_ABLATION_LEVER = "PREDICATE_ABLATION"
CATEGORICAL_SURFACE_TYPE = "CATEGORICAL"
NUMERIC_SURFACE_TYPE = "NUMERIC"
PREDICATE_DIRECTIONS = {"BUY", "SELL"}

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FARM_ROOT = Path(os.environ.get("QM_STRATEGY_FARM_ROOT", r"D:\QM\strategy_farm"))
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\opt_track")


class Q15Error(RuntimeError):
    """A fail-closed Q15 contract or mutation error."""


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise Q15Error(f"{label} is missing or invalid: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise Q15Error(f"{label} must be a JSON object: {path}")
    return value


def _binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise Q15Error(f"bound file is missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _planned_binding(path: Path, body: bytes) -> dict[str, Any]:
    return {"path": str(path.resolve()), "sha256": _sha256_bytes(body), "size_bytes": len(body)}


def _validate_binding(
    raw: Any,
    label: str,
    *,
    base: Path | None = None,
    expected_path: Path | None = None,
) -> tuple[Path, dict[str, Any]]:
    if not isinstance(raw, Mapping):
        raise Q15Error(f"{label} binding must be an object")
    declared_path = str(raw.get("path") or "").strip()
    declared_sha = str(raw.get("sha256") or "").strip().lower()
    try:
        declared_size = int(raw.get("size_bytes"))
    except (TypeError, ValueError) as exc:
        raise Q15Error(f"{label} binding size_bytes is invalid") from exc
    if not declared_path or not re.fullmatch(r"[0-9a-f]{64}", declared_sha) or declared_size < 0:
        raise Q15Error(f"{label} binding is incomplete")
    path = Path(declared_path).expanduser()
    if not path.is_absolute():
        if base is None:
            raise Q15Error(f"{label} binding path must be absolute")
        path = base / path
    path = path.resolve()
    if expected_path is not None and path != expected_path.resolve():
        raise Q15Error(f"{label} binding path differs from the sealed path")
    if not path.is_file():
        raise Q15Error(f"{label} bound file is missing: {path}")
    actual = _binding(path)
    if actual["sha256"] != declared_sha:
        raise Q15Error(f"{label} SHA-256 mismatch: expected={declared_sha} actual={actual['sha256']}")
    if actual["size_bytes"] != declared_size:
        raise Q15Error(f"{label} size mismatch: expected={declared_size} actual={actual['size_bytes']}")
    return path, actual


def _card_id(value: str) -> str:
    token = str(value or "").strip()
    if not re.fullmatch(r"OPT-[A-Za-z0-9][A-Za-z0-9-]{5,180}", token):
        raise Q15Error(f"invalid opt-card id: {value!r}")
    return token


def _ea_numeric(value: Any, label: str = "EA id") -> int:
    match = re.fullmatch(r"(?:QM5[_-]?)?(\d+)", str(value or "").strip(), re.IGNORECASE)
    if not match:
        raise Q15Error(f"invalid {label}: {value!r}")
    return int(match.group(1))


def _iso_date(value: Any, label: str) -> dt.date:
    try:
        return dt.date.fromisoformat(str(value))
    except ValueError as exc:
        raise Q15Error(f"{label} must be an ISO date") from exc


def _same_scalar(actual: str, expected: Any) -> bool:
    token = str(actual).strip()
    if isinstance(expected, bool):
        return token.lower() in ({"true", "1"} if expected else {"false", "0"})
    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        try:
            return float(token) == float(expected)
        except ValueError:
            return False
    return token == str(expected)


def _read_setfile(path: Path, label: str) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        raise Q15Error(f"{label} is unreadable: {path}: {exc}") from exc
    values: dict[str, str] = {}
    for line_no, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith((";", "#")) or "=" not in line:
            continue
        name, value = line.split("=", 1)
        key = name.strip()
        if not re.fullmatch(r"[A-Za-z_]\w*", key):
            continue
        if key in values:
            raise Q15Error(f"{label} repeats {key} at line {line_no}")
        values[key] = value.split("||", 1)[0].strip()
    return values


def _require_risk(values: Mapping[str, str], label: str) -> None:
    for key, expected in (("RISK_FIXED", RISK_FIXED), ("RISK_PERCENT", RISK_PERCENT)):
        if key not in values or not _same_scalar(values[key], expected):
            raise Q15Error(f"{label} must use RISK_FIXED=1000 and RISK_PERCENT=0")


def _strip_mql_noncode(text: str) -> str:
    without_blocks = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    without_lines = re.sub(r"//[^\r\n]*", " ", without_blocks)
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', without_lines)


def _input_declaration(code: str, name: str) -> tuple[re.Match[str], str]:
    pattern = re.compile(
        rf"(?m)^[ \t]*input[ \t]+(?:[A-Za-z_]\w*(?:::\w+)?[ \t]+)+"
        rf"{re.escape(name)}[ \t]*=[ \t]*(?P<default>[^;\r\n]+);"
    )
    matches = list(pattern.finditer(code))
    if len(matches) != 1:
        raise Q15Error(f"challenger source must declare input {name} exactly once; found {len(matches)}")
    return matches[0], matches[0].group("default").strip()


def _validate_source_wiring(
    source: Path,
    *,
    parameter_name: str,
    incumbent: Any,
) -> dict[str, Any]:
    try:
        code = _strip_mql_noncode(source.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError) as exc:
        raise Q15Error(f"challenger source is unreadable: {source}: {exc}") from exc
    param_decl, param_default = _input_declaration(code, parameter_name)
    if incumbent is not None and not _same_scalar(param_default, incumbent):
        raise Q15Error(
            f"challenger input {parameter_name} default must equal card incumbent {incumbent!r}"
        )
    enabled_decl, enabled_default = _input_declaration(code, LEVER_ENABLE_INPUT)
    if enabled_default.lower() not in {"false", "0"}:
        raise Q15Error(f"{LEVER_ENABLE_INPUT} must default OFF (false/0)")
    for name, declaration in ((parameter_name, param_decl), (LEVER_ENABLE_INPUT, enabled_decl)):
        without_declaration = code[: declaration.start()] + " " + code[declaration.end() :]
        reads = len(re.findall(rf"\b{re.escape(name)}\b", without_declaration))
        if reads < 1:
            raise Q15Error(f"unwired input: {name} is declared but never read in challenger source")
    return {
        "parameter": parameter_name,
        "parameter_default": param_default,
        "enable_input": LEVER_ENABLE_INPUT,
        "enable_default": enabled_default,
    }


def _csv_dicts(path: Path, label: str) -> list[dict[str, str]]:
    if not path.is_file():
        raise Q15Error(f"{label} is missing: {path}")
    try:
        with path.open(encoding="utf-8-sig", newline="") as handle:
            return [dict(row) for row in csv.DictReader(handle)]
    except (OSError, UnicodeDecodeError, csv.Error) as exc:
        raise Q15Error(f"{label} is invalid: {path}: {exc}") from exc


def _parse_resolver_array(text: str, name: str, *, strings: bool = False) -> list[Any]:
    match = re.search(
        rf"QM_MAGIC_REG_{name}\[QM_MAGIC_REGISTRY_ROWS\]\s*=\s*\{{(?P<body>[^}}]*)\}};",
        text,
    )
    if not match:
        raise Q15Error(f"magic resolver lacks QM_MAGIC_REG_{name}")
    body = match.group("body")
    if strings:
        try:
            return next(csv.reader([body], skipinitialspace=True)) if body.strip() else []
        except csv.Error as exc:
            raise Q15Error(f"magic resolver {name} array is invalid") from exc
    try:
        return [int(value.strip()) for value in body.split(",") if value.strip()]
    except ValueError as exc:
        raise Q15Error(f"magic resolver {name} array contains a non-integer") from exc


def _validate_identity(challenger_dir: Path, repo_root: Path, target_symbol: str) -> dict[str, Any]:
    ea_root = (repo_root / "framework" / "EAs").resolve()
    directory = challenger_dir.resolve()
    if directory.parent != ea_root:
        raise Q15Error(f"challenger directory must be a direct child of {ea_root}")
    match = re.fullmatch(r"QM5_(\d{4,5})_([a-z0-9][a-z0-9-]*[a-z0-9])", directory.name)
    if not match:
        raise Q15Error(f"challenger directory has invalid identity: {directory.name}")
    ea_number = int(match.group(1))
    slug = match.group(2)
    source = directory / f"{directory.name}.mq5"
    binary = directory / f"{directory.name}.ex5"
    if not source.is_file() or not binary.is_file():
        raise Q15Error("challenger directory must contain same-name .mq5 and .ex5 files")

    registry_dir = repo_root / "framework" / "registry"
    ea_registry_path = registry_dir / "ea_id_registry.csv"
    magic_path = registry_dir / "magic_numbers.csv"
    resolver_path = repo_root / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    ea_rows = _csv_dicts(ea_registry_path, "EA-ID registry")
    active_ea_rows = [
        row for row in ea_rows
        if str(row.get("status") or "").strip().lower() != "retired"
    ]
    id_rows = [row for row in active_ea_rows if str(row.get("ea_id") or "").strip() == str(ea_number)]
    slug_rows = [row for row in active_ea_rows if str(row.get("slug") or "").strip() == slug]
    if len(id_rows) != 1 or len(slug_rows) != 1 or id_rows[0] is not slug_rows[0]:
        raise Q15Error("challenger new EA identity is not unique in ea_id_registry.csv")
    if str(id_rows[0].get("slug") or "").strip() != slug:
        raise Q15Error("challenger directory slug differs from ea_id_registry.csv")

    raw_magic_rows = _csv_dicts(magic_path, "magic registry")
    expected_rows: list[tuple[int, int, str, int]] = []
    challenger_rows: list[dict[str, str]] = []
    seen_slots: set[tuple[int, int]] = set()
    seen_magics: set[int] = set()
    for row in raw_magic_rows:
        if str(row.get("status") or "").strip().lower() == "retired":
            continue
        try:
            row_ea = int(str(row.get("ea_id") or "").strip())
            slot = int(str(row.get("symbol_slot") or row.get("slot") or "").strip())
            magic = int(str(row.get("magic") or "").strip())
        except ValueError as exc:
            raise Q15Error("active magic registry row has invalid numeric fields") from exc
        symbol = str(row.get("symbol") or "").strip().upper()
        if not symbol or magic <= 0:
            raise Q15Error("active magic registry row is incomplete")
        if (row_ea, slot) in seen_slots or magic in seen_magics:
            raise Q15Error("magic registry contains duplicate active slot or magic")
        if magic != row_ea * 10000 + slot:
            raise Q15Error(f"magic registry formula mismatch for EA {row_ea} slot {slot}")
        seen_slots.add((row_ea, slot))
        seen_magics.add(magic)
        expected_rows.append((row_ea, slot, symbol, magic))
        if row_ea == ea_number:
            challenger_rows.append(row)
            row_slug = str(row.get("ea_slug") or row.get("slug") or "").strip()
            if row_slug != slug:
                raise Q15Error("challenger magic row slug differs from directory identity")
    if not challenger_rows:
        raise Q15Error("challenger has no active magic_numbers.csv rows")
    if not any(str(row.get("symbol") or "").strip().upper() == target_symbol for row in challenger_rows):
        raise Q15Error(f"challenger has no active magic row for {target_symbol}")

    expected_rows.sort(key=lambda row: (row[0], row[1]))
    try:
        resolver_text = resolver_path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError) as exc:
        raise Q15Error(f"magic resolver is missing or unreadable: {resolver_path}: {exc}") from exc
    registry_hash = hashlib.sha256(magic_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest().upper()
    hash_match = re.search(r'#define\s+QM_MAGIC_REGISTRY_SHA256\s+"([0-9A-Fa-f]{64})"', resolver_text)
    rows_match = re.search(r"#define\s+QM_MAGIC_REGISTRY_ROWS\s+(\d+)", resolver_text)
    if not hash_match or hash_match.group(1).upper() != registry_hash:
        raise Q15Error("QM_MagicResolver.mqh was not regenerated from the current magic registry")
    if not rows_match or int(rows_match.group(1)) != len(expected_rows):
        raise Q15Error("QM_MagicResolver.mqh row count differs from the active magic registry")
    resolved_rows = list(zip(
        _parse_resolver_array(resolver_text, "EA_ID"),
        _parse_resolver_array(resolver_text, "SLOT"),
        [str(value).upper() for value in _parse_resolver_array(resolver_text, "SYMBOL", strings=True)],
        _parse_resolver_array(resolver_text, "MAGIC"),
    ))
    if resolved_rows != expected_rows:
        raise Q15Error("QM_MagicResolver.mqh arrays differ from the active magic registry")
    return {
        "ea_id": f"QM5_{ea_number}",
        "ea_number": ea_number,
        "slug": slug,
        "directory": str(directory),
        "source_path": source,
        "binary_path": binary,
        "ea_registry": _binding(ea_registry_path),
        "magic_registry": _binding(magic_path),
        "magic_resolver": _binding(resolver_path),
        "magic_rows": len(challenger_rows),
    }


def _validate_card(card: Mapping[str, Any], card_id: str) -> dict[str, Any]:
    if card.get("schema") != OPT_CARD_SCHEMA or card.get("card_id") != card_id:
        raise Q15Error(f"opt-card must use {OPT_CARD_SCHEMA} and match {card_id}")
    parent = card.get("parent")
    if not isinstance(parent, Mapping):
        raise Q15Error("opt-card parent is missing")
    parent_ea = _ea_numeric(parent.get("ea_id"), "parent EA id")
    symbol = str(parent.get("symbol") or "").strip().upper()
    if not re.fullmatch(r"[A-Z0-9_]+\.DWX", symbol):
        raise Q15Error("opt-card parent symbol is invalid")
    surface = card.get("parameter_surface")
    if not isinstance(surface, Mapping):
        raise Q15Error("opt-card parameter_surface is missing")
    lever = str(card.get("lever") or "").strip().upper()
    surface_type = str(surface.get("surface_type") or NUMERIC_SURFACE_TYPE).strip().upper()
    categorical = lever == PREDICATE_ABLATION_LEVER
    if categorical != (surface_type == CATEGORICAL_SURFACE_TYPE):
        raise Q15Error(
            f"{PREDICATE_ABLATION_LEVER} cards and {CATEGORICAL_SURFACE_TYPE} surfaces must be paired"
        )
    parameters = surface.get("parameters")
    parameter: dict[str, Any] | None
    name: str | None
    values: list[Any]
    numeric_values: list[float]
    predicate_trials: list[dict[str, str]]
    minimum_dev_fire_count: int | None
    if categorical:
        if not isinstance(parameters, list) or parameters:
            raise Q15Error("categorical predicate surface must declare parameters=[]")
        raw_trials = surface.get("predicate_trials")
        if not isinstance(raw_trials, list) or len(raw_trials) < 2:
            raise Q15Error("categorical predicate surface requires at least two predicate_trials")
        predicate_trials = []
        seen_trials: set[tuple[str, str]] = set()
        for index, raw_trial in enumerate(raw_trials):
            if not isinstance(raw_trial, Mapping):
                raise Q15Error(f"predicate_trials[{index}] must be an object")
            predicate_id = str(raw_trial.get("predicate_id") or "").strip()
            direction = str(raw_trial.get("direction") or "").strip().upper()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", predicate_id):
                raise Q15Error(f"predicate_trials[{index}] predicate_id is invalid")
            if direction not in PREDICATE_DIRECTIONS:
                raise Q15Error(f"predicate_trials[{index}] direction must be BUY or SELL")
            key = (predicate_id, direction)
            if key in seen_trials:
                raise Q15Error(f"categorical predicate surface repeats {predicate_id}/{direction}")
            seen_trials.add(key)
            predicate_trials.append({"predicate_id": predicate_id, "direction": direction})
        raw_minimum_fire_count = surface.get("minimum_dev_fire_count")
        if (
            isinstance(raw_minimum_fire_count, bool)
            or not isinstance(raw_minimum_fire_count, int)
            or raw_minimum_fire_count <= 0
        ):
            raise Q15Error("categorical predicate surface requires a positive integer minimum_dev_fire_count")
        minimum_dev_fire_count = raw_minimum_fire_count
        parameter = None
        name = None
        values = []
        numeric_values = []
    else:
        if surface_type != NUMERIC_SURFACE_TYPE:
            raise Q15Error(f"unsupported opt-card surface_type: {surface_type!r}")
        if not isinstance(parameters, list) or len(parameters) != 1 or not isinstance(parameters[0], Mapping):
            raise Q15Error("Q15 requires exactly one tunable lever parameter")
        parameter = dict(parameters[0])
        name = str(parameter.get("name") or "").strip()
        values = parameter.get("candidate_values")
        if not re.fullmatch(r"[A-Za-z_]\w*", name) or not isinstance(values, list) or len(values) < 2:
            raise Q15Error("single lever parameter needs a valid name and at least two candidate values")
        try:
            numeric_values = [float(value) for value in values]
        except (TypeError, ValueError) as exc:
            raise Q15Error("Q15 plateau validation requires numeric candidate values") from exc
        if len(set(numeric_values)) != len(numeric_values):
            raise Q15Error("lever candidate values must be unique")
        predicate_trials = []
        minimum_dev_fire_count = None
    success = card.get("success_metric")
    if not isinstance(success, Mapping) or str(success.get("direction") or "").upper() != "MAXIMIZE":
        raise Q15Error("Q15 currently requires a MAXIMIZE success metric")
    metric_name = str(success.get("primary") or "").strip()
    if not metric_name:
        raise Q15Error("opt-card success_metric.primary is required")
    minimum_improvement: float | None = None
    if categorical:
        if "minimum_improvement" not in success:
            raise Q15Error("categorical success_metric.minimum_improvement must be declared")
        try:
            minimum_improvement = float(success["minimum_improvement"])
        except (TypeError, ValueError) as exc:
            raise Q15Error("categorical success_metric.minimum_improvement must be numeric") from exc
        if not math.isfinite(minimum_improvement) or minimum_improvement < 0:
            raise Q15Error("categorical success_metric.minimum_improvement must be finite and non-negative")
    windows = card.get("comparison_windows")
    if not isinstance(windows, list) or not windows:
        raise Q15Error("opt-card comparison windows are missing")
    oos_starts = []
    for index, raw in enumerate(windows):
        if not isinstance(raw, Mapping):
            raise Q15Error(f"comparison_windows[{index}] must be an object")
        oos_starts.append(_iso_date(raw.get("start"), f"comparison_windows[{index}].start"))
    return {
        "parent": parent,
        "parent_ea_number": parent_ea,
        "symbol": symbol,
        "lever": lever,
        "surface_type": surface_type,
        "categorical": categorical,
        "parameter": parameter,
        "parameter_name": name,
        "candidate_values": list(values),
        "candidate_numeric": numeric_values,
        "predicate_trials": predicate_trials,
        "minimum_dev_fire_count": minimum_dev_fire_count,
        "minimum_improvement": minimum_improvement,
        "metric_name": metric_name,
        "first_oos_start": min(oos_starts),
    }


def _validate_ledger(ledger: Mapping[str, Any], *, card_id: str, expected_path: Path) -> dict[str, Any]:
    if ledger.get("schema") != TRIAL_LEDGER_SCHEMA or ledger.get("card_id") != card_id:
        raise Q15Error(f"trial ledger must use {TRIAL_LEDGER_SCHEMA} and match the opt-card")
    if str(ledger.get("status") or "").upper() not in {"OPENED", "CLOSED"}:
        raise Q15Error("trial ledger status must be OPENED or the identical prior CLOSED result")
    planned = ledger.get("planned_trials")
    if not isinstance(planned, list) or not planned:
        raise Q15Error("trial ledger planned_trials are missing")
    try:
        declared = int(ledger.get("declared_trial_count"))
    except (TypeError, ValueError) as exc:
        raise Q15Error("trial ledger declared_trial_count is invalid") from exc
    if declared != len(planned):
        raise Q15Error("trial ledger declared count differs from planned_trials")
    ids = [str(row.get("trial_id") or "") for row in planned if isinstance(row, Mapping)]
    if len(ids) != len(planned) or any(not value for value in ids) or len(set(ids)) != len(ids):
        raise Q15Error("trial ledger planned trials need unique non-empty trial ids")
    return {"path": expected_path, "declared": declared, "planned": planned}


def _finite_float(value: Any, label: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise Q15Error(f"{label} must be numeric") from exc
    if not math.isfinite(result):
        raise Q15Error(f"{label} must be finite")
    return result


def _nonnegative_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise Q15Error(f"{label} must be a non-negative integer")
    return value


def _validate_categorical_incumbent(
    raw: Any,
    *,
    base: Path,
    window_start: dt.date,
    window_end: dt.date,
) -> dict[str, Any]:
    if not isinstance(raw, Mapping):
        raise Q15Error("categorical DEV sweep incumbent control is missing")
    metric_value = _finite_float(raw.get("metric_value"), "categorical incumbent metric_value")
    _, evidence = _validate_binding(raw.get("evidence"), "categorical incumbent evidence", base=base)
    thirds = raw.get("time_thirds")
    if not isinstance(thirds, list) or len(thirds) != 3:
        raise Q15Error("categorical incumbent must declare exactly three DEV time_thirds")
    normalized: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for index, third in enumerate(thirds):
        if not isinstance(third, Mapping):
            raise Q15Error(f"categorical incumbent time_thirds[{index}] must be an object")
        third_id = str(third.get("id") or "").strip()
        if not third_id or third_id in seen_ids:
            raise Q15Error("categorical incumbent time_thirds need unique non-empty ids")
        start = _iso_date(third.get("start"), f"categorical incumbent time_thirds[{index}].start")
        end = _iso_date(third.get("end"), f"categorical incumbent time_thirds[{index}].end")
        if start > end:
            raise Q15Error(f"categorical incumbent time_thirds[{index}] starts after it ends")
        seen_ids.add(third_id)
        normalized.append({
            "id": third_id,
            "start": start,
            "end": end,
            "metric_value": _finite_float(
                third.get("metric_value"),
                f"categorical incumbent time_thirds[{index}].metric_value",
            ),
        })
    normalized.sort(key=lambda item: (item["start"], item["end"], item["id"]))
    if normalized[0]["start"] != window_start or normalized[-1]["end"] != window_end:
        raise Q15Error("categorical incumbent time_thirds must cover the complete DEV window")
    for left, right in zip(normalized, normalized[1:]):
        if right["start"] != left["end"] + dt.timedelta(days=1):
            raise Q15Error("categorical incumbent time_thirds must be disjoint and contiguous")
    durations = [(item["end"] - item["start"]).days + 1 for item in normalized]
    if max(durations) - min(durations) > 1:
        raise Q15Error("categorical incumbent DEV time_thirds must be equal-sized to within one day")
    return {
        "metric_value": metric_value,
        "evidence": evidence,
        "time_thirds": [
            {
                "id": item["id"],
                "start": item["start"].isoformat(),
                "end": item["end"].isoformat(),
                "metric_value": item["metric_value"],
            }
            for item in normalized
        ],
        "third_metric_by_id": {item["id"]: item["metric_value"] for item in normalized},
    }


def _validate_candidate_thirds(raw: Any, *, trial_id: str, expected_ids: set[str]) -> dict[str, float]:
    if not isinstance(raw, list) or len(raw) != 3:
        raise Q15Error(f"categorical DEV trial {trial_id} must declare exactly three time_thirds")
    result: dict[str, float] = {}
    for index, third in enumerate(raw):
        if not isinstance(third, Mapping):
            raise Q15Error(f"categorical DEV trial {trial_id} time_thirds[{index}] must be an object")
        third_id = str(third.get("id") or "").strip()
        if not third_id or third_id in result:
            raise Q15Error(f"categorical DEV trial {trial_id} time_thirds need unique non-empty ids")
        result[third_id] = _finite_float(
            third.get("metric_value"),
            f"categorical DEV trial {trial_id} time_thirds[{index}].metric_value",
        )
    if set(result) != expected_ids:
        raise Q15Error(f"categorical DEV trial {trial_id} time_thirds differ from the incumbent partition")
    return result


def _validate_numeric_selection(
    observed: Mapping[str, Mapping[str, Any]],
    *,
    card_info: Mapping[str, Any],
    chosen_id: str,
) -> dict[str, Any]:
    chosen = observed[chosen_id]
    chosen_parameters = chosen["parameters"]
    parameter_name = card_info["parameter_name"]
    if not isinstance(chosen_parameters, Mapping) or set(chosen_parameters) != {parameter_name}:
        raise Q15Error("chosen DEV trial must contain exactly the card lever parameter")
    chosen_value = chosen_parameters[parameter_name]
    candidates = card_info["candidate_values"]
    if not any(_same_scalar(str(chosen_value), value) for value in candidates):
        raise Q15Error("chosen DEV value is outside the opt-card candidate surface")
    by_value: dict[float, Mapping[str, Any]] = {}
    for trial in observed.values():
        params = trial["parameters"]
        if not isinstance(params, Mapping) or set(params) != {parameter_name}:
            raise Q15Error("every DEV trial must contain exactly the card lever parameter")
        try:
            key = float(params[parameter_name])
        except (TypeError, ValueError) as exc:
            raise Q15Error("DEV trial lever values must be numeric") from exc
        if key in by_value:
            raise Q15Error("DEV sweep repeats a candidate lever value")
        by_value[key] = trial
    expected_values = sorted(card_info["candidate_numeric"])
    if sorted(by_value) != expected_values:
        raise Q15Error("DEV sweep values differ from the complete opt-card candidate surface")
    best = max(trial["metric_value"] for trial in observed.values())
    scale = max(abs(best), 1e-12)
    plateau_values = {
        value for value, trial in by_value.items()
        if (best - trial["metric_value"]) / scale <= PLATEAU_RELATIVE_TOLERANCE + 1e-12
    }
    chosen_numeric = float(chosen_value)
    if chosen_numeric not in plateau_values:
        raise Q15Error("chosen DEV value is below the permitted 5% plateau")
    chosen_index = expected_values.index(chosen_numeric)
    neighbors = {
        expected_values[index]
        for index in (chosen_index - 1, chosen_index + 1)
        if 0 <= index < len(expected_values)
    }
    if not neighbors.intersection(plateau_values):
        raise Q15Error("chosen DEV value is not supported by an adjacent plateau value")
    return {
        "chosen_parameters": dict(chosen_parameters),
        "chosen_value": chosen_value,
        "best_metric_value": best,
        "plateau_trial_ids": sorted(
            trial["trial_id"] for value, trial in by_value.items() if value in plateau_values
        ),
        "selection_contract": {
            "type": "ORDERED_NUMERIC_PLATEAU",
            "plateau_relative_tolerance": PLATEAU_RELATIVE_TOLERANCE,
        },
    }


def _validate_categorical_selection(
    observed: Mapping[str, Mapping[str, Any]],
    *,
    card_info: Mapping[str, Any],
    incumbent: Mapping[str, Any],
    chosen_id: str,
) -> dict[str, Any]:
    chosen = observed[chosen_id]
    minimum_fire_count = int(card_info["minimum_dev_fire_count"])
    eligible_trials = {
        trial_id: trial
        for trial_id, trial in observed.items()
        if trial["fire_count"] >= minimum_fire_count
    }
    if chosen_id not in eligible_trials:
        raise Q15Error(
            f"chosen categorical predicate is not candidate-eligible: DEV fire_count "
            f"{chosen['fire_count']} is below declared minimum {minimum_fire_count}"
        )

    minimum_improvement = float(card_info["minimum_improvement"])
    observed_improvement = chosen["metric_value"] - incumbent["metric_value"]
    if observed_improvement + 1e-12 < minimum_improvement:
        raise Q15Error(
            "chosen categorical predicate does not beat the DEV incumbent by the declared minimum improvement"
        )

    incumbent_thirds = incumbent["third_metric_by_id"]
    chosen_thirds = chosen["third_metric_by_id"]
    leading_thirds = sorted(
        third_id
        for third_id, candidate_value in chosen_thirds.items()
        if candidate_value > incumbent_thirds[third_id]
    )
    if len(leading_thirds) < 2:
        raise Q15Error("chosen categorical predicate does not lead in at least 2 of 3 DEV time_thirds")

    eligible_trial_ids = sorted(eligible_trials)
    return {
        "chosen_parameters": {
            "predicate_id": chosen["predicate_id"],
            "direction": chosen["direction"],
        },
        "chosen_value": f"{chosen['predicate_id']}:{chosen['direction']}",
        "best_metric_value": max(trial["metric_value"] for trial in eligible_trials.values()),
        "plateau_trial_ids": [],
        "selection_contract": {
            "type": "CATEGORICAL_PREDICATE_ROBUSTNESS",
            "incumbent_metric_value": incumbent["metric_value"],
            "selected_metric_value": chosen["metric_value"],
            "minimum_improvement": minimum_improvement,
            "observed_improvement": observed_improvement,
            "minimum_dev_fire_count": minimum_fire_count,
            "selected_dev_fire_count": chosen["fire_count"],
            "eligible_trial_ids": eligible_trial_ids,
            "leading_time_thirds": leading_thirds,
            "required_leading_time_thirds": 2,
            "time_thirds": incumbent["time_thirds"],
        },
    }


def _validate_sweep(
    path: Path,
    *,
    card_info: Mapping[str, Any],
    ledger_info: Mapping[str, Any],
    card_id: str,
) -> dict[str, Any]:
    sweep = _read_json(path, "DEV sweep evidence")
    if sweep.get("schema") != DEV_SWEEP_SCHEMA or sweep.get("card_id") != card_id:
        raise Q15Error(f"DEV sweep evidence must use {DEV_SWEEP_SCHEMA} and match the opt-card")
    window = sweep.get("window")
    if not isinstance(window, Mapping) or str(window.get("kind") or "").upper() != "DEV_IS":
        raise Q15Error("DEV sweep evidence requires window.kind=DEV_IS")
    start = _iso_date(window.get("start"), "DEV window start")
    end = _iso_date(window.get("end"), "DEV window end")
    if start > end or end >= card_info["first_oos_start"]:
        raise Q15Error("DEV sweep window must end before every sealed OOS window")
    metric = sweep.get("selection_metric")
    if (
        not isinstance(metric, Mapping)
        or str(metric.get("name") or "") != card_info["metric_name"]
        or str(metric.get("direction") or "").upper() != "MAXIMIZE"
    ):
        raise Q15Error("DEV sweep selection metric differs from the opt-card")
    trials = sweep.get("trials")
    if not isinstance(trials, list) or len(trials) != ledger_info["declared"]:
        raise Q15Error("DEV sweep must contain exactly the declared trial count")
    planned_by_id = {
        str(row["trial_id"]): row for row in ledger_info["planned"] if isinstance(row, Mapping)
    }
    categorical = bool(card_info["categorical"])
    incumbent: dict[str, Any] | None = None
    if categorical:
        planned_identity: list[dict[str, str]] = []
        for index, planned in enumerate(ledger_info["planned"]):
            if not isinstance(planned, Mapping) or set(planned) != {"trial_id", "predicate_id", "direction"}:
                raise Q15Error(
                    f"categorical ledger planned_trials[{index}] must contain exactly "
                    "trial_id, predicate_id, and direction"
                )
            predicate_id = str(planned.get("predicate_id") or "").strip()
            direction = str(planned.get("direction") or "").strip().upper()
            planned_identity.append({"predicate_id": predicate_id, "direction": direction})
        if planned_identity != card_info["predicate_trials"]:
            raise Q15Error("categorical ledger planned trials differ from the opt-card predicate surface")
        incumbent = _validate_categorical_incumbent(
            sweep.get("incumbent"),
            base=path.parent,
            window_start=start,
            window_end=end,
        )
    observed: dict[str, dict[str, Any]] = {}
    for index, raw in enumerate(trials):
        if not isinstance(raw, Mapping):
            raise Q15Error(f"DEV sweep trial[{index}] must be an object")
        trial_id = str(raw.get("trial_id") or "")
        if trial_id not in planned_by_id or trial_id in observed:
            raise Q15Error(f"DEV sweep has undeclared or duplicate trial id: {trial_id!r}")
        try:
            metric_value = float(raw.get("metric_value"))
        except (TypeError, ValueError) as exc:
            raise Q15Error(f"DEV sweep trial {trial_id} metric_value is invalid") from exc
        evidence_path, evidence_binding = _validate_binding(
            raw.get("evidence"), f"DEV sweep trial {trial_id} evidence", base=path.parent
        )
        if categorical:
            if not math.isfinite(metric_value):
                raise Q15Error(f"categorical DEV sweep trial {trial_id} metric_value must be finite")
            planned = planned_by_id[trial_id]
            predicate_id = str(raw.get("predicate_id") or "").strip()
            direction = str(raw.get("direction") or "").strip().upper()
            if predicate_id != planned["predicate_id"] or direction != planned["direction"]:
                raise Q15Error(f"categorical DEV sweep identity differs from planned trial {trial_id}")
            assert incumbent is not None
            third_metric_by_id = _validate_candidate_thirds(
                raw.get("time_thirds"),
                trial_id=trial_id,
                expected_ids=set(incumbent["third_metric_by_id"]),
            )
            observed[trial_id] = {
                "trial_id": trial_id,
                "predicate_id": predicate_id,
                "direction": direction,
                "parameters": {"predicate_id": predicate_id, "direction": direction},
                "metric_value": metric_value,
                "fire_count": _nonnegative_int(
                    raw.get("fire_count"), f"categorical DEV trial {trial_id} fire_count"
                ),
                "time_thirds": [
                    {"id": third_id, "metric_value": third_metric_by_id[third_id]}
                    for third_id in sorted(third_metric_by_id)
                ],
                "third_metric_by_id": third_metric_by_id,
                "evidence": evidence_binding,
                "evidence_path": evidence_path,
            }
        else:
            parameters = raw.get("parameters")
            planned_parameters = planned_by_id[trial_id].get("parameters")
            if parameters != planned_parameters:
                raise Q15Error(f"DEV sweep parameters differ from planned trial {trial_id}")
            observed[trial_id] = {
                "trial_id": trial_id,
                "parameters": dict(parameters) if isinstance(parameters, Mapping) else parameters,
                "metric_value": metric_value,
                "evidence": evidence_binding,
                "evidence_path": evidence_path,
            }
    if set(observed) != set(planned_by_id):
        raise Q15Error("DEV sweep does not cover every declared trial")
    selection = sweep.get("selection")
    if not isinstance(selection, Mapping):
        raise Q15Error("DEV sweep selection is missing")
    chosen_id = str(selection.get("chosen_trial_id") or "")
    if chosen_id not in observed:
        raise Q15Error("DEV sweep chosen_trial_id is not a declared observed trial")
    if categorical:
        assert incumbent is not None
        selection_result = _validate_categorical_selection(
            observed,
            card_info=card_info,
            incumbent=incumbent,
            chosen_id=chosen_id,
        )
    else:
        selection_result = _validate_numeric_selection(
            observed,
            card_info=card_info,
            chosen_id=chosen_id,
        )
    return {
        "body": sweep,
        "binding": _binding(path),
        "window": {"kind": "DEV_IS", "start": start.isoformat(), "end": end.isoformat()},
        "chosen_trial_id": chosen_id,
        **selection_result,
        "ledger_trials": [
            {
                key: value
                for key, value in observed[str(row["trial_id"])].items()
                if key not in {"evidence_path", "third_metric_by_id"}
            }
            for row in ledger_info["planned"]
        ],
    }


def _validate_equivalence(
    path: Path,
    *,
    card_id: str,
    card_info: Mapping[str, Any],
    identity: Mapping[str, Any],
    parent_binary: Mapping[str, Any],
    parent_setfile: Mapping[str, Any],
) -> dict[str, Any]:
    evidence = _read_json(path, "default-OFF equivalence evidence")
    if evidence.get("schema") != EQUIVALENCE_SCHEMA or evidence.get("card_id") != card_id:
        raise Q15Error(f"equivalence evidence must use {EQUIVALENCE_SCHEMA} and match the opt-card")
    control = evidence.get("lever_control")
    if (
        not isinstance(control, Mapping)
        or control.get("name") != LEVER_ENABLE_INPUT
        or control.get("value") is not False
    ):
        raise Q15Error(f"equivalence evidence must declare {LEVER_ENABLE_INPUT}=false")
    window = evidence.get("smoke_window")
    if not isinstance(window, Mapping):
        raise Q15Error("equivalence smoke_window is missing")
    if str(window.get("symbol") or "").upper() != card_info["symbol"]:
        raise Q15Error("equivalence smoke symbol differs from the opt-card")
    start = _iso_date(window.get("start"), "equivalence smoke start")
    end = _iso_date(window.get("end"), "equivalence smoke end")
    if start > end:
        raise Q15Error("equivalence smoke window starts after it ends")
    parent = evidence.get("parent")
    challenger = evidence.get("challenger")
    if not isinstance(parent, Mapping) or not isinstance(challenger, Mapping):
        raise Q15Error("equivalence evidence needs parent and challenger objects")
    _, observed_parent_binary = _validate_binding(parent.get("binary"), "equivalence parent binary", base=path.parent)
    _, observed_parent_set = _validate_binding(parent.get("setfile"), "equivalence parent setfile", base=path.parent)
    if observed_parent_binary != parent_binary or observed_parent_set != parent_setfile:
        raise Q15Error("equivalence parent binary/setfile differ from the opt-card frozen bindings")
    _, observed_challenger_binary = _validate_binding(
        challenger.get("binary"),
        "equivalence challenger binary",
        base=path.parent,
        expected_path=identity["binary_path"],
    )
    if observed_challenger_binary["sha256"] != _sha256_file(identity["binary_path"]):
        raise Q15Error("equivalence challenger binary differs from the built challenger")
    off_set_path, off_set_binding = _validate_binding(
        challenger.get("setfile"), "equivalence challenger OFF setfile", base=path.parent
    )
    if off_set_path.parent.resolve() != (Path(identity["directory"]) / "sets").resolve():
        raise Q15Error("equivalence challenger OFF setfile must live in the challenger sets directory")
    off_values = _read_setfile(off_set_path, "challenger default-OFF setfile")
    _require_risk(off_values, "challenger default-OFF setfile")
    if off_values.get(LEVER_ENABLE_INPUT, "").lower() not in {"false", "0"}:
        raise Q15Error(f"challenger default-OFF setfile must use {LEVER_ENABLE_INPUT}=false")
    incumbent = card_info["parameter"].get("incumbent")
    parameter_name = card_info["parameter_name"]
    if incumbent is not None and (
        parameter_name not in off_values or not _same_scalar(off_values[parameter_name], incumbent)
    ):
        raise Q15Error("challenger default-OFF setfile must retain the card incumbent lever value")
    parent_trace, parent_trace_binding = _validate_binding(
        parent.get("behavior_trace"), "equivalence parent behavior trace", base=path.parent
    )
    challenger_trace, challenger_trace_binding = _validate_binding(
        challenger.get("behavior_trace"), "equivalence challenger behavior trace", base=path.parent
    )
    parent_bytes = parent_trace.read_bytes()
    challenger_bytes = challenger_trace.read_bytes()
    if parent_bytes != challenger_bytes:
        raise Q15Error("default-OFF smoke trade behavior is not byte-identical to the parent")
    trace = _read_json(parent_trace, "normalized trade-behavior trace")
    events = trace.get("events")
    if trace.get("schema") != TRADE_BEHAVIOR_SCHEMA or not isinstance(events, list) or not events:
        raise Q15Error("equivalence trace must be a non-empty qm.trade-behavior/v1 artifact")
    return {
        "body": evidence,
        "binding": _binding(path),
        "off_setfile": off_set_binding,
        "parent_trace": parent_trace_binding,
        "challenger_trace": challenger_trace_binding,
        "event_count": len(events),
        "smoke_window": {
            "symbol": card_info["symbol"],
            "timeframe": str(window.get("timeframe") or "").upper(),
            "start": start.isoformat(),
            "end": end.isoformat(),
        },
    }


def _infer_backtest_set(challenger_dir: Path, symbol: str) -> Path:
    matches = sorted((challenger_dir / "sets").glob(f"*_{symbol}_*_backtest.set"))
    if len(matches) != 1:
        raise Q15Error(
            f"expected exactly one {symbol} challenger backtest set; found {len(matches)}; use --backtest-set"
        )
    return matches[0]


def _timeframe_from_set(path: Path, symbol: str) -> str:
    match = re.search(
        rf"_{re.escape(symbol)}_(M1|M5|M15|M30|H1|H4|D1|W1|MN1)_backtest\.set$",
        path.name,
        re.IGNORECASE,
    )
    if not match:
        raise Q15Error("challenger backtest set filename must include symbol, timeframe, and _backtest.set")
    return match.group(1).upper()


def _lookup_q14(conn: sqlite3.Connection, *, card_id: str, card_path: Path, card_sha256: str) -> sqlite3.Row:
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        "SELECT * FROM work_items WHERE upper(phase)='Q14' AND upper(coalesce(verdict,''))='OPT_ELIGIBLE'"
    ).fetchall()
    matches: list[sqlite3.Row] = []
    for row in rows:
        try:
            payload = json.loads(str(row["payload_json"] or "{}"))
        except json.JSONDecodeError:
            continue
        if isinstance(payload, Mapping) and payload.get("card_id") == card_id:
            matches.append(row)
    if len(matches) != 1:
        raise Q15Error(f"expected exactly one OPT_ELIGIBLE Q14 row for {card_id}; found {len(matches)}")
    row = matches[0]
    payload = json.loads(str(row["payload_json"]))
    evidence_path = Path(str(row["evidence_path"] or "")).resolve()
    payload_path = Path(str(payload.get("opt_card_path") or "")).resolve()
    if evidence_path != card_path.resolve() or payload_path != card_path.resolve():
        raise Q15Error("Q14 row does not bind the requested opt-card path")
    if str(payload.get("opt_card_sha256") or "").lower() != card_sha256:
        raise Q15Error("Q14 row opt-card SHA-256 differs from the requested card")
    if _sha256_file(evidence_path) != card_sha256:
        raise Q15Error("Q14 evidence path no longer matches its opt-card SHA-256")
    return row


def _open_ro_database(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise Q15Error(f"farm database is missing: {path}")
    try:
        conn = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True, timeout=30)
    except sqlite3.Error as exc:
        raise Q15Error(f"farm database cannot be opened read-only: {path}: {exc}") from exc
    conn.row_factory = sqlite3.Row
    return conn


def build_freeze_plan(
    *,
    card_id: str,
    challenger_dir: Path,
    repo_root: Path,
    farm_root: Path,
    report_root: Path,
    sweep_evidence_path: Path | None = None,
    equivalence_evidence_path: Path | None = None,
    backtest_set_path: Path | None = None,
    freeze_addendum_path: Path | None = None,
) -> dict[str, Any]:
    card_id = _card_id(card_id)
    repo_root = Path(repo_root).resolve()
    farm_root = Path(farm_root).resolve()
    card_dir = (Path(report_root).resolve() / card_id).resolve()
    card_path = card_dir / "opt_card.json"
    card = _read_json(card_path, "opt-card")
    card_info = _validate_card(card, card_id)
    parent_binary_path, parent_binary = _validate_binding(card_info["parent"].get("binary"), "opt-card parent binary")
    parent_set_path, parent_set = _validate_binding(card_info["parent"].get("setfile"), "opt-card parent setfile")
    _require_risk(_read_setfile(parent_set_path, "opt-card parent setfile"), "opt-card parent setfile")
    identity = _validate_identity(Path(challenger_dir), repo_root, card_info["symbol"])
    if identity["ea_number"] == card_info["parent_ea_number"]:
        raise Q15Error("challenger must use a NEW EA identity distinct from the opt-card parent")
    source_wiring = _validate_source_wiring(
        identity["source_path"],
        parameter_name=card_info["parameter_name"],
        incumbent=card_info["parameter"].get("incumbent"),
    )
    ledger_path = Path(str(card.get("trial_ledger_path") or "")).resolve()
    expected_ledger_path = (card_dir / "trial_ledger.json").resolve()
    if ledger_path != expected_ledger_path:
        raise Q15Error("opt-card trial_ledger_path must resolve inside its card directory")
    ledger = _read_json(ledger_path, "trial ledger")
    ledger_info = _validate_ledger(ledger, card_id=card_id, expected_path=ledger_path)
    sweep_path = Path(sweep_evidence_path).resolve() if sweep_evidence_path else card_dir / "dev_sweep.json"
    equivalence_path = (
        Path(equivalence_evidence_path).resolve()
        if equivalence_evidence_path
        else card_dir / "default_off_equivalence.json"
    )
    sweep = _validate_sweep(
        sweep_path, card_info=card_info, ledger_info=ledger_info, card_id=card_id
    )
    equivalence = _validate_equivalence(
        equivalence_path,
        card_id=card_id,
        card_info=card_info,
        identity=identity,
        parent_binary=parent_binary,
        parent_setfile=parent_set,
    )
    q02_set = Path(backtest_set_path).resolve() if backtest_set_path else _infer_backtest_set(Path(identity["directory"]), card_info["symbol"])
    if q02_set.parent.resolve() != (Path(identity["directory"]) / "sets").resolve():
        raise Q15Error("challenger backtest set must live in the challenger sets directory")
    q02_values = _read_setfile(q02_set, "challenger Q02 backtest set")
    _require_risk(q02_values, "challenger Q02 backtest set")
    if q02_values.get(LEVER_ENABLE_INPUT, "").lower() not in {"true", "1"}:
        raise Q15Error(f"challenger Q02 backtest set must use {LEVER_ENABLE_INPUT}=true")
    parameter_name = card_info["parameter_name"]
    chosen_value = sweep["chosen_value"]
    if parameter_name not in q02_values or not _same_scalar(q02_values[parameter_name], chosen_value):
        raise Q15Error("challenger Q02 backtest set does not freeze the chosen DEV lever value")
    timeframe = _timeframe_from_set(q02_set, card_info["symbol"])
    card_sha = _sha256_file(card_path)
    db_path = farm_root / "state" / "farm_state.sqlite"
    with _open_ro_database(db_path) as conn:
        q14_row = _lookup_q14(conn, card_id=card_id, card_path=card_path, card_sha256=card_sha)
        q14 = {key: q14_row[key] for key in q14_row.keys()}
    if str(q14["ea_id"]).upper() != f"QM5_{card_info['parent_ea_number']}" or str(q14["symbol"]).upper() != card_info["symbol"]:
        raise Q15Error("Q14 row parent identity differs from the opt-card")
    addendum_path = Path(freeze_addendum_path).resolve() if freeze_addendum_path else card_dir / "freeze_addendum.json"
    if addendum_path.parent.resolve() != card_dir:
        raise Q15Error("freeze addendum must live in the opt-card directory")
    addendum = {
        "schema": FREEZE_SCHEMA,
        "card_id": card_id,
        "opt_card": _binding(card_path),
        "q14_admission": {
            "work_item_id": str(q14["id"]),
            "verdict": "OPT_ELIGIBLE",
            "evidence_sha256": card_sha,
        },
        "parent": {
            "ea_id": f"QM5_{card_info['parent_ea_number']}",
            "symbol": card_info["symbol"],
            "binary": parent_binary,
            "setfile": parent_set,
        },
        "challenger": {
            "ea_id": identity["ea_id"],
            "slug": identity["slug"],
            "symbol": card_info["symbol"],
            "source": _binding(identity["source_path"]),
            "binary": _binding(identity["binary_path"]),
            "backtest_setfile": _binding(q02_set),
            "timeframe": timeframe,
            "registries": {
                "ea_id_registry": identity["ea_registry"],
                "magic_numbers": identity["magic_registry"],
                "magic_resolver": identity["magic_resolver"],
            },
        },
        "lever": {
            "name": card_info["lever"],
            "enable_input": LEVER_ENABLE_INPUT,
            "parameter": parameter_name,
            "chosen_trial_id": sweep["chosen_trial_id"],
            "chosen_value": chosen_value,
            "chosen_parameters": sweep["chosen_parameters"],
        },
        "dev_selection": {
            "evidence": sweep["binding"],
            "window": sweep["window"],
            "metric": card_info["metric_name"],
            "best_metric_value": sweep["best_metric_value"],
            "plateau_relative_tolerance": PLATEAU_RELATIVE_TOLERANCE,
            "plateau_trial_ids": sweep["plateau_trial_ids"],
        },
        "default_off_equivalence": {
            "evidence": equivalence["binding"],
            "behavior_sha256": equivalence["parent_trace"]["sha256"],
            "event_count": equivalence["event_count"],
            "smoke_window": equivalence["smoke_window"],
        },
        "trial_ledger": {
            "path": str(ledger_path),
            "declared_trial_count": ledger_info["declared"],
        },
        "risk_contract": {"RISK_FIXED": RISK_FIXED, "RISK_PERCENT": RISK_PERCENT},
    }
    addendum_bytes = _canonical_bytes(addendum)
    addendum_binding = _planned_binding(addendum_path, addendum_bytes)
    q15_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm:q15:{card_id}:{identity['ea_id']}:{addendum_binding['sha256']}"))
    q02_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"qm:q15:q02:{q15_id}"))
    q15_payload = {
        "schema": Q15_PAYLOAD_SCHEMA,
        "phase": "Q15",
        "card_id": card_id,
        "source_q14_work_item_id": str(q14["id"]),
        "challenger_ea_id": identity["ea_id"],
        "symbol": card_info["symbol"],
        "freeze_addendum": addendum_binding,
        "trial_ledger_path": str(ledger_path),
        "q02_work_item_id": q02_id,
        "execution_lane": "DEVELOPMENT_NO_TERMINAL",
    }
    q02_payload = {
        "schema": Q02_PAYLOAD_SCHEMA,
        "card_id": card_id,
        "source_q15_work_item_id": q15_id,
        "source_q14_work_item_id": str(q14["id"]),
        "freeze_addendum_sha256": addendum_binding["sha256"],
        "enqueued_by": "q15_freeze_check",
        "priority_track": True,
        "evidence_binding_required": True,
        "ea_dir_name": Path(identity["directory"]).name,
        "expected_expert": f"QM\\{Path(identity['directory']).name}",
        "expected_ex5_path": str(identity["binary_path"].resolve()),
        "expected_ex5_sha256": _sha256_file(identity["binary_path"]),
        "expected_mq5_sha256": _sha256_file(identity["source_path"]),
        "expected_setfile_sha256": _sha256_file(q02_set),
        "expected_symbol": card_info["symbol"],
        "expected_period": timeframe,
        "opt_trial_ledger_declared_count": ledger_info["declared"],
    }
    final_ledger = dict(ledger)
    final_ledger["status"] = "CLOSED"
    final_ledger["trials"] = sweep["ledger_trials"]
    final_ledger["freeze"] = {
        "schema": FREEZE_SCHEMA,
        "addendum": addendum_binding,
        "chosen_trial_id": sweep["chosen_trial_id"],
        "chosen_parameters": sweep["chosen_parameters"],
        "q15_work_item_id": q15_id,
        "q02_work_item_id": q02_id,
    }
    final_ledger_bytes = _canonical_bytes(final_ledger)
    if addendum_path.exists() and addendum_path.read_bytes() != addendum_bytes:
        raise Q15Error("existing immutable Q15 freeze addendum differs from the validated plan")
    if str(ledger.get("status") or "").upper() == "CLOSED" and ledger_path.read_bytes() != final_ledger_bytes:
        raise Q15Error("existing CLOSED trial ledger differs from the validated plan")
    return {
        "schema": RESULT_SCHEMA,
        "verdict": "CHALLENGER_SPAWNED",
        "card_id": card_id,
        "parent_ea_id": f"QM5_{card_info['parent_ea_number']}",
        "challenger_ea_id": identity["ea_id"],
        "symbol": card_info["symbol"],
        "chosen_parameters": sweep["chosen_parameters"],
        "plateau_trial_ids": sweep["plateau_trial_ids"],
        "q14_work_item_id": str(q14["id"]),
        "q15_work_item_id": q15_id,
        "q02_work_item_id": q02_id,
        "freeze_addendum_path": str(addendum_path),
        "freeze_addendum_sha256": addendum_binding["sha256"],
        "trial_ledger_path": str(ledger_path),
        "backtest_setfile": str(q02_set),
        "dry_run": True,
        "applied": False,
        "_private": {
            "addendum_path": addendum_path,
            "addendum_bytes": addendum_bytes,
            "ledger_path": ledger_path,
            "ledger_bytes": final_ledger_bytes,
            "q15_payload": q15_payload,
            "q02_payload": q02_payload,
            "q02_set": q02_set,
            "timeframe": timeframe,
            "card_sha256": card_sha,
            "farm_root": farm_root,
        },
    }


def _atomic_write_or_match(path: Path, body: bytes, *, immutable: bool) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != body:
            qualifier = "immutable " if immutable else ""
            raise Q15Error(f"existing {qualifier}artifact differs from validated body: {path}")
        return False
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(body)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
    return True


def _atomic_replace(path: Path, body: bytes) -> bool:
    if path.exists() and path.read_bytes() == body:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(body)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
    return True


def _assert_apply_guards(*, repo_root: Path, farm_root: Path) -> None:
    if not os.environ.get("QM_ALLOW_NONCANONICAL"):
        canonical = Path(os.environ.get("QM_CANONICAL_REPO_ROOT", r"C:\QM\repo")).resolve()
        if repo_root.resolve() != canonical:
            raise Q15Error(f"--apply must run from the canonical checkout: {canonical}")
    off_flag = farm_root / "state" / "FACTORY_OFF.flag"
    if off_flag.is_file():
        raise Q15Error(f"--apply is blocked while FACTORY_OFF.flag exists: {off_flag}")


def _ensure_dependency(
    conn: sqlite3.Connection,
    *,
    child_id: str,
    parent_id: str,
    parent_sha: str,
    farmctl: Any,
) -> bool:
    existing = conn.execute(
        """
        SELECT parent_work_item_id,parent_evidence_sha256,required_verdicts_json
        FROM work_item_dependencies
        WHERE child_work_item_id=? AND dependency_role='Q14_ADMISSION'
        """,
        (child_id,),
    ).fetchone()
    if existing is not None:
        try:
            required = json.loads(str(existing["required_verdicts_json"]))
        except (TypeError, json.JSONDecodeError) as exc:
            raise Q15Error("existing Q14_ADMISSION dependency has invalid verdict JSON") from exc
        if (
            str(existing["parent_work_item_id"]) != parent_id
            or str(existing["parent_evidence_sha256"]).lower() != parent_sha
            or required != ["OPT_ELIGIBLE"]
        ):
            raise Q15Error("existing Q14_ADMISSION dependency differs from the sealed Q15 plan")
        return False
    farmctl.add_q09_dependency(
        conn,
        child_work_item_id=child_id,
        dependency_role="Q14_ADMISSION",
        parent_work_item_id=parent_id,
        parent_evidence_sha256=parent_sha,
        required_verdicts=["OPT_ELIGIBLE"],
    )
    return True


def apply_freeze_plan(plan: Mapping[str, Any], *, enforce_apply_guards: bool = True) -> dict[str, Any]:
    private = plan.get("_private")
    if not isinstance(private, Mapping):
        raise Q15Error("freeze plan lacks private mutation state")
    farm_root = Path(private["farm_root"]).resolve()
    if enforce_apply_guards:
        _assert_apply_guards(repo_root=REPO_ROOT, farm_root=farm_root)
    strategy_path = REPO_ROOT / "tools" / "strategy_farm"
    if str(strategy_path) not in sys.path:
        sys.path.insert(0, str(strategy_path))
    import farmctl  # type: ignore  # noqa: WPS433

    farmctl.init_db(farm_root)
    q15_id = str(plan["q15_work_item_id"])
    q02_id = str(plan["q02_work_item_id"])
    q14_id = str(plan["q14_work_item_id"])
    q15_payload_json = json.dumps(private["q15_payload"], sort_keys=True)
    q02_payload_json = json.dumps(private["q02_payload"], sort_keys=True)
    q02_set = Path(private["q02_set"])
    with farmctl.connect(farm_root) as conn:
        conn.execute("BEGIN IMMEDIATE")
        try:
            q14 = conn.execute("SELECT * FROM work_items WHERE id=?", (q14_id,)).fetchone()
            if q14 is None:
                raise Q15Error("Q14 dependency disappeared before apply")
            if (
                str(q14["phase"]).upper() != "Q14"
                or str(q14["status"]).lower() != "done"
                or str(q14["verdict"] or "").upper() != "OPT_ELIGIBLE"
                or _sha256_file(Path(str(q14["evidence_path"]))) != private["card_sha256"]
            ):
                raise Q15Error("Q14 dependency is no longer the sealed OPT_ELIGIBLE row")
            q15_existing = conn.execute("SELECT * FROM work_items WHERE id=?", (q15_id,)).fetchone()
            if q15_existing is not None and (
                str(q15_existing["phase"]).upper() != "Q15"
                or str(q15_existing["status"]).lower() != "done"
                or str(q15_existing["verdict"] or "").upper() != "CHALLENGER_SPAWNED"
                or str(q15_existing["payload_json"]) != q15_payload_json
                or Path(str(q15_existing["evidence_path"])).resolve() != Path(plan["freeze_addendum_path"]).resolve()
            ):
                raise Q15Error("deterministic Q15 work-item id collides with different state")
            q02_rows = conn.execute(
                "SELECT * FROM work_items WHERE ea_id=? AND upper(phase)='Q02' AND upper(symbol)=?",
                (plan["challenger_ea_id"], plan["symbol"]),
            ).fetchall()
            if any(str(row["id"]) != q02_id for row in q02_rows):
                raise Q15Error("challenger already has a non-Q15 Q02 row for the frozen symbol")
            q02_existing = next((row for row in q02_rows if str(row["id"]) == q02_id), None)
            if q02_existing is not None and (
                str(q02_existing["status"]).lower() not in {"pending", "active", "done", "failed"}
                or str(q02_existing["payload_json"]) != q02_payload_json
                or Path(str(q02_existing["setfile_path"])).resolve() != q02_set.resolve()
            ):
                raise Q15Error("deterministic Q02 work-item id collides with different state")

            created_addendum = _atomic_write_or_match(
                Path(private["addendum_path"]), private["addendum_bytes"], immutable=True
            )
            updated_ledger = _atomic_replace(Path(private["ledger_path"]), private["ledger_bytes"])
            now = farmctl.utc_now()
            created_q15 = False
            if q15_existing is None:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                        created_at,updated_at
                    ) VALUES(?,?,?,?,?,?,'done','CHALLENGER_SPAWNED',0,NULL,?,NULL,?,?,?)
                    """,
                    (
                        q15_id, "development", "Q15", plan["challenger_ea_id"], plan["symbol"],
                        str(q02_set), plan["freeze_addendum_path"], q15_payload_json, now, now,
                    ),
                )
                created_q15 = True
            created_dependency = _ensure_dependency(
                conn,
                child_id=q15_id,
                parent_id=q14_id,
                parent_sha=str(private["card_sha256"]),
                farmctl=farmctl,
            )
            created_q02 = False
            if q02_existing is None:
                conn.execute(
                    """
                    INSERT INTO work_items(
                        id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                        attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                        created_at,updated_at
                    ) VALUES(?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?)
                    """,
                    (
                        q02_id, "backtest", "Q02", plan["challenger_ea_id"], plan["symbol"],
                        str(q02_set), q02_payload_json, now, now,
                    ),
                )
                created_q02 = True
            if any((created_addendum, updated_ledger, created_q15, created_dependency, created_q02)):
                farmctl.event(conn, "work_item", q15_id, "q15_challenger_frozen", {
                    "card_id": plan["card_id"],
                    "q14_work_item_id": q14_id,
                    "q02_work_item_id": q02_id,
                    "freeze_addendum_sha256": plan["freeze_addendum_sha256"],
                })
            conn.commit()
        except Exception:
            conn.rollback()
            raise
    public = {key: value for key, value in plan.items() if key != "_private"}
    public.update({
        "dry_run": False,
        "applied": True,
        "created_freeze_addendum": created_addendum,
        "updated_trial_ledger": updated_ledger,
        "created_q15_work_item": created_q15,
        "created_q14_dependency": created_dependency,
        "created_q02_work_item": created_q02,
        "idempotent": not any((created_addendum, updated_ledger, created_q15, created_dependency, created_q02)),
    })
    return public


def run_freeze_check(
    *,
    card_id: str,
    challenger_dir: Path,
    repo_root: Path = REPO_ROOT,
    farm_root: Path = DEFAULT_FARM_ROOT,
    report_root: Path = DEFAULT_REPORT_ROOT,
    sweep_evidence_path: Path | None = None,
    equivalence_evidence_path: Path | None = None,
    backtest_set_path: Path | None = None,
    freeze_addendum_path: Path | None = None,
    apply: bool = False,
    enforce_apply_guards: bool = True,
) -> dict[str, Any]:
    plan = build_freeze_plan(
        card_id=card_id,
        challenger_dir=challenger_dir,
        repo_root=repo_root,
        farm_root=farm_root,
        report_root=report_root,
        sweep_evidence_path=sweep_evidence_path,
        equivalence_evidence_path=equivalence_evidence_path,
        backtest_set_path=backtest_set_path,
        freeze_addendum_path=freeze_addendum_path,
    )
    if not apply:
        return {key: value for key, value in plan.items() if key != "_private"}
    if Path(repo_root).resolve() != REPO_ROOT.resolve():
        # The CLI/apply path is deliberately tied to the code-bearing canonical
        # repository. Tests use apply_freeze_plan(..., enforce_apply_guards=False)
        # against hermetic fixtures after building the plan.
        if enforce_apply_guards:
            raise Q15Error("--apply repo_root must be the repository containing q15_freeze_check.py")
    return apply_freeze_plan(plan, enforce_apply_guards=enforce_apply_guards)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Q15 challenger build/freeze validator (dry-run default)")
    parser.add_argument("--card-id", required=True)
    parser.add_argument("--challenger-dir", required=True)
    parser.add_argument("--repo-root", default=str(REPO_ROOT))
    parser.add_argument("--farm-root", default=str(DEFAULT_FARM_ROOT))
    parser.add_argument("--report-root", default=str(DEFAULT_REPORT_ROOT))
    parser.add_argument("--sweep-evidence")
    parser.add_argument("--equivalence-evidence")
    parser.add_argument("--backtest-set")
    parser.add_argument("--freeze-addendum")
    parser.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = run_freeze_check(
            card_id=args.card_id,
            challenger_dir=Path(args.challenger_dir),
            repo_root=Path(args.repo_root),
            farm_root=Path(args.farm_root),
            report_root=Path(args.report_root),
            sweep_evidence_path=Path(args.sweep_evidence) if args.sweep_evidence else None,
            equivalence_evidence_path=Path(args.equivalence_evidence) if args.equivalence_evidence else None,
            backtest_set_path=Path(args.backtest_set) if args.backtest_set else None,
            freeze_addendum_path=Path(args.freeze_addendum) if args.freeze_addendum else None,
            apply=bool(args.apply),
        )
    except (Q15Error, sqlite3.Error) as exc:
        print(json.dumps({"schema": RESULT_SCHEMA, "verdict": "FAIL", "error": str(exc)}, indent=2, sort_keys=True))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
