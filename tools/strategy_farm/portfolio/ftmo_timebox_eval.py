#!/usr/bin/env python3
"""Selection-bound FTMO finite-horizon book evaluator.

``prepare-config`` freezes every input identity without reading a sleeve stream.
``evaluate`` first checks the reviewed config digest and only then opens any
bound input.  The evaluator is deliberately read-only with respect to the farm,
terminals, and databases; the sole mutation is an explicitly requested JSON
result written atomically.

Daily sleeve streams are accepted only when every row attests FTMO cost terms.
The existing Q08/Darwinex trade streams can be inventoried, but are refused
instead of silently inheriting a non-FTMO spread model.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import random
import re
import uuid
from dataclasses import dataclass
from pathlib import Path
from statistics import median
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo

try:
    from .ftmo_q09_admission import ADMITTED_REASON, EVIDENCE_MISSING
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_q09_admission import ADMITTED_REASON, EVIDENCE_MISSING  # type: ignore


CONFIG_SCHEMA = "qm.ftmo-timebox-config/v1"
RESULT_SCHEMA = "qm.ftmo-timebox-result/v1"
DAILY_STREAM_SCHEMA = "FTMO_DAILY_NET_V1"
DXZ_STREAM_SCHEMA = "DXZ_Q08_TRADES_V1"
COST_ADJUSTED_STREAM_SCHEMA = "DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1"
CLAIM_LABEL = "HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED"
DECISION_LABEL = "MOVING_BLOCK_BOOTSTRAP_P1_LOWER_BOUND"
NO_CREDIT_LABEL = "NO_EVIDENCE_CREDIT_NOT_ESTIMATED_PROBABILITY"
REFUSED_DXZ_SPREAD = "REFUSED_DXZ_SPREAD_INHERITANCE"
REFUSED_MISSING_SWAP = "REFUSED_MISSING_FTMO_SWAP_TERMS"
REFUSED_COST_ATTESTATION = "REFUSED_FTMO_COST_ATTESTATION"
REFUSED_CORRELATION = "REFUSED_DL083_CORRELATION_AT_OR_ABOVE_0P40"
REFUSED_UNDEFINED_CORRELATION = "REFUSED_DL083_UNDEFINED_CORRELATION"
REFUSED_REGIME_COVERAGE = "REFUSED_FEWER_THAN_20_SHARED_CALENDAR_DAYS"
REFUSED_CALENDAR = "REFUSED_NONIDENTICAL_OR_NONCONTIGUOUS_SHARED_CALENDAR"
REFUSED_COST_ADJUSTED_DECLARATION = "REFUSED_MISSING_EXPLICIT_COST_ADJUSTED_CLASS"
REFUSED_SENSITIVITY = "REFUSED_SPREAD_SENSITIVITY_NON_MONOTONIC"
REFUSED_QUALIFICATION_MISSING = "FTMO_QUALIFICATION_EVIDENCE_MISSING"
REFUSED_QUALIFICATION_NOT_READY = "FTMO_QUALIFICATION_NOT_CHALLENGE_READY"
PRAGUE = ZoneInfo("Europe/Prague")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")

DEFAULT_RULES: dict[str, Any] = {
    "initial_equity": 1.0,
    "phase1_target_fraction": 0.10,
    "phase1_horizon_calendar_days": 60,
    "phase2_target_fraction": 0.05,
    "phase2_horizon_calendar_days": 30,
    "maximum_daily_loss_fraction": 0.05,
    "maximum_total_loss_fraction": 0.10,
    "daily_floor": "BROKER_MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_EQUITY_0P05",
    "total_floor": "INITIAL_EQUITY_TIMES_0P90",
    "breach_operator": "STRICTLY_BELOW",
    "target_operator": "AT_OR_ABOVE_WHILE_FLAT",
    "timezone": "Europe/Prague",
    "broker_day": "NY_CLOSE_GMT_PLUS_2_OR_3",
    "rolling_start": "EVERY_ELIGIBLE_BROKER_CALENDAR_DAY",
    "censoring": "RIGHT_CENSORED_IS_TIMEOUT_NON_PASS",
    "phase_transition": "RESET_TO_INITIAL_EQUITY_NEXT_BROKER_DAY_AFTER_P1_PASS",
    "design_bar_p1": 0.80,
}

DEFAULT_BOOTSTRAP: dict[str, Any] = {
    "replicates": 2_000,
    "seed": 20_260_802,
    "alpha": 0.05,
    "block_calendar_days": 60,
    "ci": "TWO_SIDED_PERCENTILE_95",
}

DEFAULT_CORRELATION: dict[str, Any] = {
    "strong_budget_exclusive": 0.15,
    "maximum_budget_exclusive": 0.40,
    "high_volatility_quantile": 0.75,
    "minimum_shared_calendar_days": 20,
    "effective_correlation": "MAX_FULL_AND_HIGH_VOL_PAIRWISE_ABSOLUTE_PEARSON",
}

DEFAULT_COST_ADJUSTED_DECLARATION: dict[str, Any] = {
    "accepted_class": COST_ADJUSTED_STREAM_SCHEMA,
    "spread_charge_multipliers": [1.0, 1.5, 2.0],
}


class TimeboxEvaluationError(ValueError):
    """Fail-closed configuration, identity, or evaluation error."""


@dataclass(frozen=True)
class DailyPoint:
    day: dt.date
    net_return: float
    intraday_low_return: float
    trade_count: int
    eligible_start: bool
    flat_at_end: bool


def _reject_constant(token: str) -> None:
    raise TimeboxEvaluationError(f"non-finite JSON constant: {token}")


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise TimeboxEvaluationError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def loads_strict(raw: bytes, label: str) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_object_no_duplicates,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise TimeboxEvaluationError(f"{label}: invalid UTF-8/JSON: {exc}") from exc


def load_json(path: Path, label: str) -> Any:
    try:
        return loads_strict(path.read_bytes(), label)
    except OSError as exc:
        raise TimeboxEvaluationError(f"{label}: cannot read {path}: {exc}") from exc


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise TimeboxEvaluationError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _normalized_sha(value: Any, label: str) -> str:
    digest = str(value).strip().lower()
    if not SHA_RE.fullmatch(digest):
        raise TimeboxEvaluationError(f"{label}: expected lowercase SHA-256")
    return digest


def pin_binding(path_value: Any, label: str) -> dict[str, str]:
    if not isinstance(path_value, str) or not path_value.strip():
        raise TimeboxEvaluationError(f"{label}: path must be a non-empty string")
    path = Path(path_value).expanduser().resolve()
    if not path.is_file():
        raise TimeboxEvaluationError(f"{label}: not a file: {path}")
    return {"path": str(path), "sha256": sha256_file(path)}


def verify_binding(binding: Any, label: str) -> Path:
    if not isinstance(binding, Mapping) or set(binding) != {"path", "sha256"}:
        raise TimeboxEvaluationError(f"{label}: binding must contain only path and sha256")
    path = Path(str(binding["path"]))
    expected = _normalized_sha(binding["sha256"], f"{label}.sha256")
    actual = sha256_file(path)
    if actual != expected:
        raise TimeboxEvaluationError(
            f"{label}: SHA-256 mismatch expected={expected} actual={actual} path={path}"
        )
    return path


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise TimeboxEvaluationError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise TimeboxEvaluationError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise TimeboxEvaluationError(f"{label}: expected finite number")
    return number


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise TimeboxEvaluationError(f"{label}: expected positive integer")
    return value


def _contains_mutable_state_reference(value: Any, key: str = "root") -> bool:
    if isinstance(value, Mapping):
        for child_key, child in value.items():
            normalized_key = str(child_key).lower().replace("-", "_")
            if normalized_key in {
                "db",
                "db_path",
                "database",
                "database_path",
                "farm_state",
                "sqlite",
            }:
                return True
            if _contains_mutable_state_reference(child, f"{key}.{child_key}"):
                return True
        return False
    if isinstance(value, (list, tuple)):
        return any(_contains_mutable_state_reference(item, key) for item in value)
    if isinstance(value, str):
        lowered = value.strip().lower().replace("\\", "/")
        return (
            "farm_state" in lowered
            or lowered.startswith("sqlite:")
            or lowered.endswith((".db", ".sqlite", ".sqlite3"))
        )
    return False


def _parse_day(value: Any, label: str) -> dt.date:
    if not isinstance(value, str):
        raise TimeboxEvaluationError(f"{label}: expected YYYY-MM-DD")
    try:
        parsed = dt.date.fromisoformat(value)
    except ValueError as exc:
        raise TimeboxEvaluationError(f"{label}: expected YYYY-MM-DD") from exc
    if parsed.isoformat() != value:
        raise TimeboxEvaluationError(f"{label}: non-canonical date")
    return parsed


def _parse_bool(value: Any, label: str) -> bool:
    if not isinstance(value, bool):
        raise TimeboxEvaluationError(f"{label}: expected boolean")
    return value


def _validate_rules(rules: Any) -> None:
    if rules != DEFAULT_RULES:
        raise TimeboxEvaluationError("rules: binding FTMO rules differ from OWNER time-box contract")


def _validate_bootstrap(bootstrap: Any) -> None:
    if not isinstance(bootstrap, Mapping):
        raise TimeboxEvaluationError("bootstrap: expected object")
    required = set(DEFAULT_BOOTSTRAP)
    if set(bootstrap) != required:
        raise TimeboxEvaluationError("bootstrap: unexpected fields")
    _positive_int(bootstrap["replicates"], "bootstrap.replicates")
    if bootstrap["replicates"] < 100:
        raise TimeboxEvaluationError("bootstrap.replicates: minimum is 100")
    if isinstance(bootstrap["seed"], bool) or not isinstance(bootstrap["seed"], int):
        raise TimeboxEvaluationError("bootstrap.seed: expected integer")
    alpha = _finite(bootstrap["alpha"], "bootstrap.alpha")
    if not 0.0 < alpha < 0.5:
        raise TimeboxEvaluationError("bootstrap.alpha: expected 0 < alpha < 0.5")
    _positive_int(bootstrap["block_calendar_days"], "bootstrap.block_calendar_days")
    if bootstrap["ci"] != DEFAULT_BOOTSTRAP["ci"]:
        raise TimeboxEvaluationError("bootstrap.ci: unsupported interval")


def _validate_correlation(rule: Any) -> None:
    if rule != DEFAULT_CORRELATION:
        raise TimeboxEvaluationError("correlation: DL-083 contract differs from binding defaults")


def _validate_stream_entry(entry: Any, index: int) -> None:
    label = f"inputs.streams[{index}]"
    expected = {"sleeve_id", "symbol", "ftmo_code", "stream_schema", "binding"}
    if not isinstance(entry, Mapping) or set(entry) != expected:
        raise TimeboxEvaluationError(f"{label}: unexpected fields")
    for field in ("sleeve_id", "symbol", "ftmo_code"):
        if not isinstance(entry[field], str) or not entry[field].strip():
            raise TimeboxEvaluationError(f"{label}.{field}: expected non-empty string")
    if entry["stream_schema"] not in {
        DAILY_STREAM_SCHEMA,
        DXZ_STREAM_SCHEMA,
        COST_ADJUSTED_STREAM_SCHEMA,
    }:
        raise TimeboxEvaluationError(f"{label}.stream_schema: unsupported schema")
    binding = entry["binding"]
    if not isinstance(binding, Mapping) or set(binding) != {"path", "sha256"}:
        raise TimeboxEvaluationError(f"{label}.binding: invalid binding")
    _normalized_sha(binding["sha256"], f"{label}.binding.sha256")


def _validate_composition(comp: Any, index: int, known: set[str]) -> None:
    label = f"compositions[{index}]"
    if not isinstance(comp, Mapping) or set(comp) != {"id", "sleeves"}:
        raise TimeboxEvaluationError(f"{label}: unexpected fields")
    if not isinstance(comp["id"], str) or not comp["id"].strip():
        raise TimeboxEvaluationError(f"{label}.id: expected non-empty string")
    sleeves = comp["sleeves"]
    if not isinstance(sleeves, list) or not sleeves:
        raise TimeboxEvaluationError(f"{label}.sleeves: expected non-empty list")
    seen: set[str] = set()
    weight_sum = 0.0
    for sleeve_index, item in enumerate(sleeves):
        item_label = f"{label}.sleeves[{sleeve_index}]"
        if not isinstance(item, Mapping) or set(item) != {"sleeve_id", "weight"}:
            raise TimeboxEvaluationError(f"{item_label}: unexpected fields")
        sleeve_id = item["sleeve_id"]
        if sleeve_id not in known:
            raise TimeboxEvaluationError(f"{item_label}: unknown sleeve_id {sleeve_id!r}")
        if sleeve_id in seen:
            raise TimeboxEvaluationError(f"{item_label}: duplicate sleeve_id")
        seen.add(sleeve_id)
        weight = _finite(item["weight"], f"{item_label}.weight")
        if weight <= 0.0:
            raise TimeboxEvaluationError(f"{item_label}.weight: expected positive")
        weight_sum += weight
    if not math.isclose(weight_sum, 1.0, rel_tol=0.0, abs_tol=1e-12):
        raise TimeboxEvaluationError(f"{label}: weights must sum to exactly 1 within 1e-12")


def validate_config(config: Any) -> None:
    if not isinstance(config, Mapping):
        raise TimeboxEvaluationError("config: expected object")
    if _contains_mutable_state_reference(config):
        raise TimeboxEvaluationError("config: mutable DB/farm-state inputs are forbidden")
    expected = {
        "schema",
        "claim_label",
        "rules",
        "bootstrap",
        "correlation",
        "inputs",
        "compositions",
    }
    optional = {"evidence_class"}
    if not expected.issubset(config) or not set(config).issubset(expected | optional):
        raise TimeboxEvaluationError("config: unexpected fields")
    if config["schema"] != CONFIG_SCHEMA:
        raise TimeboxEvaluationError("config.schema: unsupported schema")
    if config["claim_label"] != CLAIM_LABEL:
        raise TimeboxEvaluationError("config.claim_label: unsupported claim")
    _validate_rules(config["rules"])
    _validate_bootstrap(config["bootstrap"])
    _validate_correlation(config["correlation"])
    if "evidence_class" in config:
        if config["evidence_class"] != DEFAULT_COST_ADJUSTED_DECLARATION:
            raise TimeboxEvaluationError(
                "evidence_class: declaration differs from OWNER-authorized contract"
            )
    inputs = config["inputs"]
    if not isinstance(inputs, Mapping) or set(inputs) != {
        "inventory",
        "fund_scores",
        "ftmo_cost_snapshot",
        "streams",
    }:
        raise TimeboxEvaluationError("inputs: unexpected fields")
    for name in ("inventory", "fund_scores", "ftmo_cost_snapshot"):
        binding = inputs[name]
        if not isinstance(binding, Mapping) or set(binding) != {"path", "sha256"}:
            raise TimeboxEvaluationError(f"inputs.{name}: invalid binding")
        _normalized_sha(binding["sha256"], f"inputs.{name}.sha256")
    streams = inputs["streams"]
    if not isinstance(streams, list) or not streams:
        raise TimeboxEvaluationError("inputs.streams: expected non-empty list")
    sleeve_ids: set[str] = set()
    for index, entry in enumerate(streams):
        _validate_stream_entry(entry, index)
        if entry["sleeve_id"] in sleeve_ids:
            raise TimeboxEvaluationError("inputs.streams: duplicate sleeve_id")
        sleeve_ids.add(entry["sleeve_id"])
    compositions = config["compositions"]
    if not isinstance(compositions, list) or not compositions:
        raise TimeboxEvaluationError("compositions: expected non-empty list")
    comp_ids: set[str] = set()
    for index, comp in enumerate(compositions):
        _validate_composition(comp, index, sleeve_ids)
        if comp["id"] in comp_ids:
            raise TimeboxEvaluationError("compositions: duplicate id")
        comp_ids.add(comp["id"])


def prepare_config(spec: Any) -> dict[str, Any]:
    if not isinstance(spec, Mapping):
        raise TimeboxEvaluationError("spec: expected object")
    if _contains_mutable_state_reference(spec):
        raise TimeboxEvaluationError("spec: mutable DB/farm-state inputs are forbidden")
    expected = {
        "inventory_path",
        "fund_scores_path",
        "ftmo_cost_snapshot_path",
        "streams",
        "compositions",
    }
    optional = {"bootstrap", "evidence_class"}
    if not expected.issubset(spec) or not set(spec).issubset(expected | optional):
        raise TimeboxEvaluationError("spec: unexpected or missing fields")
    streams_value = spec["streams"]
    if not isinstance(streams_value, list) or not streams_value:
        raise TimeboxEvaluationError("spec.streams: expected non-empty list")
    streams: list[dict[str, Any]] = []
    for index, entry in enumerate(streams_value):
        label = f"spec.streams[{index}]"
        expected_stream = {"sleeve_id", "symbol", "ftmo_code", "stream_schema", "path"}
        if not isinstance(entry, Mapping) or set(entry) != expected_stream:
            raise TimeboxEvaluationError(f"{label}: unexpected fields")
        streams.append(
            {
                "sleeve_id": entry["sleeve_id"],
                "symbol": entry["symbol"],
                "ftmo_code": entry["ftmo_code"],
                "stream_schema": entry["stream_schema"],
                "binding": pin_binding(entry["path"], f"{label}.path"),
            }
        )
    bootstrap = dict(DEFAULT_BOOTSTRAP)
    if "bootstrap" in spec:
        if not isinstance(spec["bootstrap"], Mapping):
            raise TimeboxEvaluationError("spec.bootstrap: expected object")
        if not set(spec["bootstrap"]).issubset(DEFAULT_BOOTSTRAP):
            raise TimeboxEvaluationError("spec.bootstrap: unexpected fields")
        bootstrap.update(spec["bootstrap"])
    config = {
        "schema": CONFIG_SCHEMA,
        "claim_label": CLAIM_LABEL,
        "rules": dict(DEFAULT_RULES),
        "bootstrap": bootstrap,
        "correlation": dict(DEFAULT_CORRELATION),
        "inputs": {
            "inventory": pin_binding(spec["inventory_path"], "spec.inventory_path"),
            "fund_scores": pin_binding(spec["fund_scores_path"], "spec.fund_scores_path"),
            "ftmo_cost_snapshot": pin_binding(
                spec["ftmo_cost_snapshot_path"], "spec.ftmo_cost_snapshot_path"
            ),
            "streams": streams,
        },
        "compositions": spec["compositions"],
    }
    if "evidence_class" in spec:
        if spec["evidence_class"] != DEFAULT_COST_ADJUSTED_DECLARATION:
            raise TimeboxEvaluationError(
                "spec.evidence_class: declaration differs from OWNER-authorized contract"
            )
        config["evidence_class"] = {
            "accepted_class": COST_ADJUSTED_STREAM_SCHEMA,
            "spread_charge_multipliers": [1.0, 1.5, 2.0],
        }
    validate_config(config)
    return config


def _load_jsonl(path: Path, label: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        with path.open("rb") as handle:
            for line_number, raw in enumerate(handle, start=1):
                if not raw.strip():
                    raise TimeboxEvaluationError(f"{label}:{line_number}: blank JSONL row")
                row = loads_strict(raw, f"{label}:{line_number}")
                if not isinstance(row, dict):
                    raise TimeboxEvaluationError(f"{label}:{line_number}: expected object")
                rows.append(row)
    except OSError as exc:
        raise TimeboxEvaluationError(f"{label}: cannot read {path}: {exc}") from exc
    if not rows:
        raise TimeboxEvaluationError(f"{label}: empty stream")
    return rows


def _load_ftmo_terms(path: Path) -> dict[str, Mapping[str, Any]]:
    value = load_json(path, "ftmo_cost_snapshot")
    if not isinstance(value, list) or not value:
        raise TimeboxEvaluationError("ftmo_cost_snapshot: expected non-empty instrument list")
    terms: dict[str, Mapping[str, Any]] = {}
    for index, item in enumerate(value):
        if not isinstance(item, Mapping):
            raise TimeboxEvaluationError(f"ftmo_cost_snapshot[{index}]: expected object")
        for field in ("code", "displayCode"):
            code = item.get(field)
            if isinstance(code, str) and code.strip():
                key = code.strip().upper()
                if key in terms and terms[key] != item:
                    raise TimeboxEvaluationError(f"ftmo_cost_snapshot: duplicate code {code}")
                terms[key] = item
    return terms


def _cost_refusal(term: Mapping[str, Any] | None) -> str | None:
    if term is None:
        return REFUSED_COST_ATTESTATION
    for field in ("swapLong", "swapShort"):
        if term.get(field) is None:
            return REFUSED_MISSING_SWAP
        _finite(term[field], f"ftmo_cost_snapshot.{field}")
    if term.get("commission") is None or term.get("commissionType") in (None, ""):
        return REFUSED_COST_ATTESTATION
    _finite(term["commission"], "ftmo_cost_snapshot.commission")
    if term.get("active") is not True:
        return REFUSED_COST_ATTESTATION
    return None


def load_daily_stream(
    entry: Mapping[str, Any], path: Path, cost_sha256: str
) -> list[DailyPoint]:
    rows = _load_jsonl(path, f"stream[{entry['sleeve_id']}]")
    points: list[DailyPoint] = []
    previous_day: dt.date | None = None
    required = {
        "schema",
        "sleeve_id",
        "symbol",
        "date",
        "net_return",
        "intraday_low_return",
        "trade_count",
        "eligible_start",
        "flat_at_end",
        "venue",
        "spread_basis",
        "commission_basis",
        "swap_basis",
        "cost_snapshot_sha256",
    }
    for index, row in enumerate(rows):
        label = f"stream[{entry['sleeve_id']}][{index}]"
        if set(row) != required:
            raise TimeboxEvaluationError(f"{label}: unexpected fields")
        if row["schema"] != DAILY_STREAM_SCHEMA:
            raise TimeboxEvaluationError(f"{label}: wrong row schema")
        if row["sleeve_id"] != entry["sleeve_id"] or row["symbol"] != entry["symbol"]:
            raise TimeboxEvaluationError(f"{label}: sleeve identity mismatch")
        attestation = (
            row["venue"] == "FTMO"
            and row["spread_basis"] == "FTMO_TERMS"
            and row["commission_basis"] == "FTMO_TERMS"
            and row["swap_basis"] == "FTMO_TERMS"
            and str(row["cost_snapshot_sha256"]).lower() == cost_sha256
        )
        if not attestation:
            raise TimeboxEvaluationError(f"{label}: {REFUSED_COST_ATTESTATION}")
        day = _parse_day(row["date"], f"{label}.date")
        if previous_day is not None and day != previous_day + dt.timedelta(days=1):
            raise TimeboxEvaluationError(f"{label}: {REFUSED_CALENDAR}")
        previous_day = day
        net_return = _finite(row["net_return"], f"{label}.net_return")
        low_return = _finite(row["intraday_low_return"], f"{label}.intraday_low_return")
        if net_return <= -1.0 or low_return <= -1.0:
            raise TimeboxEvaluationError(f"{label}: return must be greater than -1")
        if low_return > min(0.0, net_return) + 1e-12:
            raise TimeboxEvaluationError(f"{label}: intraday low is not conservative")
        trade_count = row["trade_count"]
        if isinstance(trade_count, bool) or not isinstance(trade_count, int) or trade_count < 0:
            raise TimeboxEvaluationError(f"{label}.trade_count: expected non-negative integer")
        points.append(
            DailyPoint(
                day=day,
                net_return=net_return,
                intraday_low_return=low_return,
                trade_count=trade_count,
                eligible_start=_parse_bool(row["eligible_start"], f"{label}.eligible_start"),
                flat_at_end=_parse_bool(row["flat_at_end"], f"{label}.flat_at_end"),
            )
        )
    return points


def load_cost_adjusted_stream(
    entry: Mapping[str, Any],
    path: Path,
    cost_sha256: str,
    spread_charge_multiplier: float,
) -> tuple[list[DailyPoint], str]:
    """Load the explicit OWNER-authorized class at one sensitivity point."""

    multiplier = _finite(spread_charge_multiplier, "spread_charge_multiplier")
    if multiplier not in {1.0, 1.5, 2.0}:
        raise TimeboxEvaluationError("spread_charge_multiplier: unsupported sensitivity point")
    rows = _load_jsonl(path, f"stream[{entry['sleeve_id']}]")
    required = {
        "schema",
        "evidence_class",
        "sleeve_id",
        "symbol",
        "date",
        "initial_equity",
        "pre_spread_net_cash",
        "calibrated_spread_charge_cash",
        "intraday_candidates",
        "net_return",
        "intraday_low_return",
        "trade_count",
        "eligible_start",
        "flat_at_end",
        "cost_snapshot_sha256",
        "calibration_sha256",
        "cost_decomposition",
    }
    decomposition_fields = {
        "source_profit_cash",
        "source_fee_cash",
        "source_commission_removed_cash",
        "source_swap_removed_cash",
        "ftmo_entry_commission_cash",
        "ftmo_exit_commission_cash",
        "ftmo_swap_cash",
        "pre_spread_net_cash",
        "calibrated_spread_delta_cash",
        "adjusted_net_cash",
    }
    points: list[DailyPoint] = []
    previous_day: dt.date | None = None
    running_balance: float | None = None
    initial_equity: float | None = None
    calibration_sha: str | None = None
    for index, row in enumerate(rows):
        label = f"stream[{entry['sleeve_id']}][{index}]"
        if set(row) != required:
            raise TimeboxEvaluationError(f"{label}: unexpected fields")
        if (
            row["schema"] != COST_ADJUSTED_STREAM_SCHEMA
            or row["evidence_class"] != COST_ADJUSTED_STREAM_SCHEMA
        ):
            raise TimeboxEvaluationError(f"{label}: wrong evidence class")
        if row["sleeve_id"] != entry["sleeve_id"] or row["symbol"] != entry["symbol"]:
            raise TimeboxEvaluationError(f"{label}: sleeve identity mismatch")
        if str(row["cost_snapshot_sha256"]).lower() != cost_sha256:
            raise TimeboxEvaluationError(f"{label}: {REFUSED_COST_ATTESTATION}")
        row_calibration_sha = _normalized_sha(
            row["calibration_sha256"], f"{label}.calibration_sha256"
        )
        if calibration_sha is None:
            calibration_sha = row_calibration_sha
        elif row_calibration_sha != calibration_sha:
            raise TimeboxEvaluationError(f"{label}: calibration digest changes within stream")
        day = _parse_day(row["date"], f"{label}.date")
        if previous_day is not None and day != previous_day + dt.timedelta(days=1):
            raise TimeboxEvaluationError(f"{label}: {REFUSED_CALENDAR}")
        previous_day = day
        row_initial = _finite(row["initial_equity"], f"{label}.initial_equity")
        if row_initial <= 0.0:
            raise TimeboxEvaluationError(f"{label}.initial_equity: expected positive")
        if initial_equity is None:
            initial_equity = row_initial
            running_balance = row_initial
        elif not math.isclose(row_initial, initial_equity, rel_tol=0.0, abs_tol=1e-9):
            raise TimeboxEvaluationError(f"{label}: initial equity changes within stream")
        assert running_balance is not None
        pre_spread = _finite(row["pre_spread_net_cash"], f"{label}.pre_spread_net_cash")
        spread_charge = _finite(
            row["calibrated_spread_charge_cash"],
            f"{label}.calibrated_spread_charge_cash",
        )
        if spread_charge < 0.0:
            raise TimeboxEvaluationError(f"{label}: spread charge must be non-negative")
        candidates = row["intraday_candidates"]
        if not isinstance(candidates, list) or not candidates:
            raise TimeboxEvaluationError(f"{label}.intraday_candidates: expected non-empty list")
        candidate_lows: list[float] = []
        for candidate_index, candidate in enumerate(candidates):
            candidate_label = f"{label}.intraday_candidates[{candidate_index}]"
            if not isinstance(candidate, Mapping) or set(candidate) != {
                "pre_spread_cash",
                "calibrated_spread_charge_cash",
            }:
                raise TimeboxEvaluationError(f"{candidate_label}: unexpected fields")
            candidate_pre = _finite(candidate["pre_spread_cash"], f"{candidate_label}.pre")
            candidate_charge = _finite(
                candidate["calibrated_spread_charge_cash"],
                f"{candidate_label}.charge",
            )
            if candidate_charge < 0.0:
                raise TimeboxEvaluationError(f"{candidate_label}: charge must be non-negative")
            candidate_lows.append(candidate_pre - multiplier * candidate_charge)
        decomposition = row["cost_decomposition"]
        if not isinstance(decomposition, Mapping) or set(decomposition) != decomposition_fields:
            raise TimeboxEvaluationError(f"{label}.cost_decomposition: unexpected fields")
        for field in decomposition_fields:
            _finite(decomposition[field], f"{label}.cost_decomposition.{field}")
        if not math.isclose(
            float(decomposition["pre_spread_net_cash"]),
            pre_spread,
            rel_tol=0.0,
            abs_tol=1e-8,
        ) or not math.isclose(
            float(decomposition["calibrated_spread_delta_cash"]),
            -spread_charge,
            rel_tol=0.0,
            abs_tol=1e-8,
        ):
            raise TimeboxEvaluationError(f"{label}: cost decomposition does not reconcile")
        base_adjusted = pre_spread - spread_charge
        if not math.isclose(
            float(decomposition["adjusted_net_cash"]),
            base_adjusted,
            rel_tol=0.0,
            abs_tol=1e-8,
        ):
            raise TimeboxEvaluationError(f"{label}: adjusted net decomposition mismatch")

        net_cash = pre_spread - multiplier * spread_charge
        low_cash = min(0.0, net_cash, *candidate_lows)
        net_return = net_cash / running_balance
        low_return = low_cash / running_balance
        if net_return <= -1.0 or low_return <= -1.0:
            raise TimeboxEvaluationError(f"{label}: sensitivity path leaves evaluator domain")
        if multiplier == 1.0:
            provided_net = _finite(row["net_return"], f"{label}.net_return")
            provided_low = _finite(row["intraday_low_return"], f"{label}.intraday_low_return")
            if not math.isclose(provided_net, net_return, rel_tol=0.0, abs_tol=2e-10):
                raise TimeboxEvaluationError(f"{label}: calibrated net return does not reconcile")
            if not math.isclose(provided_low, low_return, rel_tol=0.0, abs_tol=2e-10):
                raise TimeboxEvaluationError(f"{label}: calibrated intraday low does not reconcile")
        trade_count = row["trade_count"]
        if isinstance(trade_count, bool) or not isinstance(trade_count, int) or trade_count < 0:
            raise TimeboxEvaluationError(f"{label}.trade_count: expected non-negative integer")
        points.append(
            DailyPoint(
                day=day,
                net_return=net_return,
                intraday_low_return=low_return,
                trade_count=trade_count,
                eligible_start=_parse_bool(row["eligible_start"], f"{label}.eligible_start"),
                flat_at_end=_parse_bool(row["flat_at_end"], f"{label}.flat_at_end"),
            )
        )
        running_balance += net_cash
        if running_balance <= 0.0:
            raise TimeboxEvaluationError(f"{label}: non-positive adjusted balance")
    assert calibration_sha is not None
    return points, calibration_sha


def combine_streams(
    streams: Mapping[str, Sequence[DailyPoint]], weights: Mapping[str, float]
) -> list[DailyPoint]:
    ordered_ids = list(weights)
    reference = streams[ordered_ids[0]]
    reference_days = [point.day for point in reference]
    for sleeve_id in ordered_ids[1:]:
        if [point.day for point in streams[sleeve_id]] != reference_days:
            raise TimeboxEvaluationError(REFUSED_CALENDAR)
    combined: list[DailyPoint] = []
    for index, day in enumerate(reference_days):
        points = [streams[sleeve_id][index] for sleeve_id in ordered_ids]
        combined.append(
            DailyPoint(
                day=day,
                net_return=sum(weights[sid] * streams[sid][index].net_return for sid in ordered_ids),
                intraday_low_return=sum(
                    weights[sid] * streams[sid][index].intraday_low_return
                    for sid in ordered_ids
                ),
                trade_count=sum(point.trade_count for point in points),
                eligible_start=all(point.eligible_start for point in points),
                flat_at_end=all(point.flat_at_end for point in points),
            )
        )
    return combined


def evaluate_phase(
    days: Sequence[DailyPoint], start_index: int, target_fraction: float, horizon_days: int
) -> dict[str, Any]:
    if start_index < 0 or start_index >= len(days):
        raise TimeboxEvaluationError("phase start index outside trace")
    start_day = days[start_index].day
    deadline = start_day + dt.timedelta(days=horizon_days)
    balance = 1.0
    for index in range(start_index, len(days)):
        point = days[index]
        if point.day >= deadline:
            break
        midnight_balance = balance
        intraday_low = midnight_balance * (1.0 + point.intraday_low_return)
        daily_floor = midnight_balance - DEFAULT_RULES["maximum_daily_loss_fraction"]
        total_floor = 1.0 - DEFAULT_RULES["maximum_total_loss_fraction"]
        if intraday_low < daily_floor:
            return {
                "outcome": "DAILY_LOSS_BREACH",
                "end_index": index,
                "days_elapsed": (point.day - start_day).days + 1,
            }
        if intraday_low < total_floor:
            return {
                "outcome": "MAX_LOSS_BREACH",
                "end_index": index,
                "days_elapsed": (point.day - start_day).days + 1,
            }
        balance *= 1.0 + point.net_return
        if balance >= 1.0 + target_fraction and point.flat_at_end:
            return {
                "outcome": "PASS",
                "end_index": index,
                "days_elapsed": (point.day - start_day).days + 1,
            }
    return {
        "outcome": "TIMEOUT",
        "end_index": None,
        "days_elapsed": horizon_days,
    }


def rolling_outcomes(days: Sequence[DailyPoint]) -> list[dict[str, Any]]:
    outcomes: list[dict[str, Any]] = []
    for start_index, point in enumerate(days):
        if not point.eligible_start:
            continue
        p1 = evaluate_phase(days, start_index, 0.10, 60)
        p2: dict[str, Any] | None = None
        if p1["outcome"] == "PASS":
            p2_start = int(p1["end_index"]) + 1
            if p2_start < len(days):
                p2 = evaluate_phase(days, p2_start, 0.05, 30)
            else:
                p2 = {"outcome": "TIMEOUT", "end_index": None, "days_elapsed": 30}
        outcomes.append(
            {
                "start_index": start_index,
                "start_day": point.day.isoformat(),
                "p1": p1,
                "p2": p2,
                "joint_pass": p1["outcome"] == "PASS"
                and p2 is not None
                and p2["outcome"] == "PASS",
            }
        )
    return outcomes


def _rate(flags: Sequence[bool]) -> float | None:
    if not flags:
        return None
    return sum(bool(flag) for flag in flags) / len(flags)


def _taxonomy(outcomes: Sequence[Mapping[str, Any]], phase: str) -> dict[str, int]:
    counts = {"PASS": 0, "DAILY_LOSS_BREACH": 0, "MAX_LOSS_BREACH": 0, "TIMEOUT": 0}
    for item in outcomes:
        outcome = item.get(phase)
        if outcome is not None:
            counts[str(outcome["outcome"])] += 1
    return counts


def hac_effective_sample_size(flags: Sequence[bool], bandwidth: int | None = None) -> dict[str, Any]:
    values = [1.0 if flag else 0.0 for flag in flags]
    n = len(values)
    if n == 0:
        return {"n": 0, "bandwidth": 0, "effective_n": 0.0, "autocorrelations": []}
    bw = min(n - 1, 59 if bandwidth is None else max(0, bandwidth))
    mean = sum(values) / n
    gamma0 = sum((value - mean) ** 2 for value in values) / n
    if gamma0 <= 0.0:
        return {"n": n, "bandwidth": bw, "effective_n": float(n), "autocorrelations": []}
    correlations: list[float] = []
    inflation = 1.0
    for lag in range(1, bw + 1):
        covariance = sum(
            (values[index] - mean) * (values[index - lag] - mean)
            for index in range(lag, n)
        ) / n
        rho = covariance / gamma0
        correlations.append(rho)
        inflation += 2.0 * (1.0 - lag / (bw + 1.0)) * rho
    effective_n = n / max(1.0, inflation)
    return {
        "n": n,
        "bandwidth": bw,
        "effective_n": max(1.0, min(float(n), effective_n)),
        "autocorrelations": correlations,
    }


def _percentile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise TimeboxEvaluationError("percentile requires values")
    ordered = sorted(values)
    position = probability * (len(ordered) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def _resampled_days(
    days: Sequence[DailyPoint], rng: random.Random, block_days: int
) -> list[DailyPoint]:
    n = len(days)
    block = min(n, block_days)
    sampled: list[DailyPoint] = []
    while len(sampled) < n:
        block_start = rng.randrange(0, n - block + 1)
        sampled.extend(days[block_start : block_start + block])
    start_day = days[0].day
    return [
        DailyPoint(
            day=start_day + dt.timedelta(days=index),
            net_return=point.net_return,
            intraday_low_return=point.intraday_low_return,
            trade_count=point.trade_count,
            eligible_start=point.eligible_start,
            flat_at_end=point.flat_at_end,
        )
        for index, point in enumerate(sampled[:n])
    ]


def moving_block_bootstrap(
    days: Sequence[DailyPoint], bootstrap: Mapping[str, Any]
) -> dict[str, Any]:
    replicates = int(bootstrap["replicates"])
    rng = random.Random(int(bootstrap["seed"]))
    rates: list[float] = []
    for _ in range(replicates):
        sampled = _resampled_days(days, rng, int(bootstrap["block_calendar_days"]))
        outcomes = rolling_outcomes(sampled)
        rate = _rate([item["p1"]["outcome"] == "PASS" for item in outcomes])
        rates.append(0.0 if rate is None else rate)
    alpha = float(bootstrap["alpha"])
    return {
        "method": "MOVING_CALENDAR_DAY_BLOCK_PERCENTILE",
        "replicates": replicates,
        "seed": int(bootstrap["seed"]),
        "block_calendar_days": min(len(days), int(bootstrap["block_calendar_days"])),
        "alpha": alpha,
        "lower": _percentile(rates, alpha / 2.0),
        "median": _percentile(rates, 0.5),
        "upper": _percentile(rates, 1.0 - alpha / 2.0),
    }


def _pearson(left: Sequence[float], right: Sequence[float]) -> float | None:
    if len(left) != len(right) or not left:
        raise TimeboxEvaluationError("correlation vectors must be non-empty and equal length")
    left_mean = sum(left) / len(left)
    right_mean = sum(right) / len(right)
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in zip(left, right))
    left_scale = math.sqrt(sum((a - left_mean) ** 2 for a in left))
    right_scale = math.sqrt(sum((b - right_mean) ** 2 for b in right))
    if left_scale <= 0.0 or right_scale <= 0.0:
        return None
    return numerator / (left_scale * right_scale)


def correlation_diagnostic(
    streams: Mapping[str, Sequence[DailyPoint]], sleeve_ids: Sequence[str]
) -> dict[str, Any]:
    reference_days = [point.day for point in streams[sleeve_ids[0]]]
    if any(
        [point.day for point in streams[sleeve_id]] != reference_days
        for sleeve_id in sleeve_ids[1:]
    ):
        return {
            "status": "REFUSED",
            "label": REFUSED_CALENDAR,
            "shared_calendar_days": 0,
        }
    n = len(reference_days)
    if n < int(DEFAULT_CORRELATION["minimum_shared_calendar_days"]):
        return {
            "status": "REFUSED",
            "label": REFUSED_REGIME_COVERAGE,
            "shared_calendar_days": n,
        }
    if len(sleeve_ids) == 1:
        return {
            "status": "PASS_STRONG",
            "shared_calendar_days": n,
            "maximum_full_correlation": 0.0,
            "maximum_high_volatility_correlation": 0.0,
            "effective_correlation": 0.0,
            "pairs": [],
        }
    volatility = [
        math.sqrt(
            sum(streams[sleeve_id][index].net_return ** 2 for sleeve_id in sleeve_ids)
            / len(sleeve_ids)
        )
        for index in range(n)
    ]
    threshold = _percentile(volatility, float(DEFAULT_CORRELATION["high_volatility_quantile"]))
    high_indices = [index for index, value in enumerate(volatility) if value >= threshold]
    if len(high_indices) < 2:
        high_indices = list(range(n))
    pairs: list[dict[str, Any]] = []
    maximum_full = 0.0
    maximum_high = 0.0
    for left_index, left_id in enumerate(sleeve_ids):
        for right_id in sleeve_ids[left_index + 1 :]:
            left = [point.net_return for point in streams[left_id]]
            right = [point.net_return for point in streams[right_id]]
            full_value = _pearson(left, right)
            high_value = _pearson(
                [left[index] for index in high_indices],
                [right[index] for index in high_indices],
            )
            if full_value is None or high_value is None:
                return {
                    "status": "REFUSED",
                    "label": REFUSED_UNDEFINED_CORRELATION,
                    "shared_calendar_days": n,
                    "undefined_pair": {"left": left_id, "right": right_id},
                }
            full = abs(full_value)
            high = abs(high_value)
            maximum_full = max(maximum_full, full)
            maximum_high = max(maximum_high, high)
            pairs.append({"left": left_id, "right": right_id, "full": full, "high_vol": high})
    effective = max(maximum_full, maximum_high)
    if effective >= float(DEFAULT_CORRELATION["maximum_budget_exclusive"]):
        status = "REFUSED"
        label: str | None = REFUSED_CORRELATION
    elif effective >= float(DEFAULT_CORRELATION["strong_budget_exclusive"]):
        status = "PASS_GREY_BUDGET"
        label = None
    else:
        status = "PASS_STRONG"
        label = None
    return {
        "status": status,
        "label": label,
        "shared_calendar_days": n,
        "high_volatility_days": len(high_indices),
        "maximum_full_correlation": maximum_full,
        "maximum_high_volatility_correlation": maximum_high,
        "effective_correlation": effective,
        "pairs": pairs,
    }


def summarize(days: Sequence[DailyPoint], bootstrap: Mapping[str, Any]) -> dict[str, Any]:
    outcomes = rolling_outcomes(days)
    p1_flags = [item["p1"]["outcome"] == "PASS" for item in outcomes]
    p2_outcomes = [item for item in outcomes if item["p2"] is not None]
    p2_flags = [item["p2"]["outcome"] == "PASS" for item in p2_outcomes]
    joint_flags = [bool(item["joint_pass"]) for item in outcomes]
    p1_days = [item["p1"]["days_elapsed"] for item in outcomes if item["p1"]["outcome"] == "PASS"]
    p2_days = [item["p2"]["days_elapsed"] for item in p2_outcomes if item["p2"]["outcome"] == "PASS"]
    return {
        "rolling_starts": len(outcomes),
        "p1_raw_rate": _rate(p1_flags),
        "p1_hac": hac_effective_sample_size(p1_flags),
        "p1_bootstrap": moving_block_bootstrap(days, bootstrap),
        "p2_given_p1_rate": _rate(p2_flags),
        "joint_rate": _rate(joint_flags),
        "median_days_to_p1_target": median(p1_days) if p1_days else None,
        "median_days_to_p2_target": median(p2_days) if p2_days else None,
        "p1_taxonomy": _taxonomy(outcomes, "p1"),
        "p2_taxonomy_given_p1": _taxonomy(p2_outcomes, "p2"),
        "total_trade_days": sum(point.trade_count > 0 for point in days),
        "trace_calendar_days": len(days),
    }


def _binding_dimension(results: Sequence[Mapping[str, Any]]) -> str:
    accepted = [result for result in results if result["status"] == "EVALUATED"]
    if not accepted:
        correlation_only = results and all(
            any(label.startswith("REFUSED_DL083_") for label in result.get("refusal_labels", []))
            for result in results
        )
        return "CORRELATION" if correlation_only else "DENSITY"
    best = max(accepted, key=lambda result: result["statistics"]["p1_bootstrap"]["lower"])
    taxonomy = best["statistics"]["p1_taxonomy"]
    breaches = taxonomy["DAILY_LOSS_BREACH"] + taxonomy["MAX_LOSS_BREACH"]
    if breaches > taxonomy["TIMEOUT"]:
        return "DD_HEADROOM"
    if taxonomy["TIMEOUT"] > 0:
        return "EXPECTANCY"
    return "DENSITY"


def _inventory_admission_map(inventory: Any) -> dict[str, dict[str, Any]]:
    """Normalize frozen qualification rows into fail-closed sleeve decisions."""

    if not isinstance(inventory, Mapping):
        raise TimeboxEvaluationError("inventory: expected object")
    candidates = inventory.get("candidates")
    if not isinstance(candidates, list):
        return {}
    decisions: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(candidates):
        if not isinstance(row, Mapping):
            raise TimeboxEvaluationError(f"inventory.candidates[{index}]: expected object")
        try:
            ea_id = int(str(row.get("ea_id") or "").upper().removeprefix("QM5_"))
        except ValueError as exc:
            raise TimeboxEvaluationError(
                f"inventory.candidates[{index}].ea_id: invalid"
            ) from exc
        symbol = str(row.get("symbol") or "").strip().upper()
        if symbol.endswith(".DWX"):
            symbol = symbol[:-4]
        if not symbol:
            raise TimeboxEvaluationError(f"inventory.candidates[{index}].symbol: missing")
        sleeve_id = f"{ea_id}:{symbol}"
        if sleeve_id in decisions:
            raise TimeboxEvaluationError(f"inventory: duplicate sleeve {sleeve_id}")
        admission = row.get("ftmo_q09_admission")
        q09_admitted = (
            isinstance(admission, Mapping)
            and admission.get("admitted") is True
            and admission.get("reason_code") == ADMITTED_REASON
        )
        if not q09_admitted:
            reason = (
                str(admission.get("reason_code") or EVIDENCE_MISSING)
                if isinstance(admission, Mapping)
                else EVIDENCE_MISSING
            )
        elif row.get("challenge_ready") is not True:
            reason = REFUSED_QUALIFICATION_NOT_READY
        else:
            reason = ADMITTED_REASON
        decisions[sleeve_id] = {
            "admitted": q09_admitted and row.get("challenge_ready") is True,
            "reason_code": reason,
            "qualification_state": row.get("state"),
            "q09_news_work_item_id": (
                admission.get("q09_news_work_item_id")
                if isinstance(admission, Mapping)
                else None
            ),
            "chosen_temporal": (
                admission.get("chosen_temporal")
                if isinstance(admission, Mapping)
                else None
            ),
            "deployment_compliance": (
                admission.get("deployment_compliance")
                if isinstance(admission, Mapping)
                else None
            ),
        }
    return decisions


def evaluate_config(config: Mapping[str, Any], config_sha256: str) -> dict[str, Any]:
    validate_config(config)
    inputs = config["inputs"]
    inventory_path = verify_binding(inputs["inventory"], "inputs.inventory")
    fund_path = verify_binding(inputs["fund_scores"], "inputs.fund_scores")
    cost_path = verify_binding(inputs["ftmo_cost_snapshot"], "inputs.ftmo_cost_snapshot")
    inventory = load_json(inventory_path, "inventory")
    admission_map = _inventory_admission_map(inventory)
    load_json(fund_path, "fund_scores")
    stream_paths: dict[str, Path] = {}
    entries: dict[str, Mapping[str, Any]] = {}
    for index, entry in enumerate(inputs["streams"]):
        sleeve_id = entry["sleeve_id"]
        stream_paths[sleeve_id] = verify_binding(entry["binding"], f"inputs.streams[{index}]")
        entries[sleeve_id] = entry
    cost_terms = _load_ftmo_terms(cost_path)
    cost_sha = str(inputs["ftmo_cost_snapshot"]["sha256"])
    declaration = config.get("evidence_class")
    declared_class = (
        str(declaration["accepted_class"])
        if isinstance(declaration, Mapping)
        else None
    )
    multipliers = (
        [float(value) for value in declaration["spread_charge_multipliers"]]
        if isinstance(declaration, Mapping)
        else [1.0]
    )
    loaded_by_multiplier: dict[float, dict[str, list[DailyPoint]]] = {
        multiplier: {} for multiplier in multipliers
    }
    calibration_sha256: dict[str, str] = {}
    refusal: dict[str, str] = {}
    sleeve_admission: dict[str, dict[str, Any]] = {}
    for sleeve_id, entry in entries.items():
        admission = admission_map.get(
            sleeve_id,
            {
                "admitted": False,
                "reason_code": REFUSED_QUALIFICATION_MISSING,
                "qualification_state": None,
                "q09_news_work_item_id": None,
                "chosen_temporal": None,
                "deployment_compliance": None,
            },
        )
        sleeve_admission[sleeve_id] = admission
        if admission["admitted"] is not True:
            refusal[sleeve_id] = str(admission["reason_code"])
            continue
        term = cost_terms.get(str(entry["ftmo_code"]).upper())
        cost_reason = _cost_refusal(term)
        if cost_reason is not None:
            refusal[sleeve_id] = cost_reason
            continue
        if entry["stream_schema"] == DXZ_STREAM_SCHEMA:
            refusal[sleeve_id] = REFUSED_DXZ_SPREAD
            continue
        if entry["stream_schema"] == COST_ADJUSTED_STREAM_SCHEMA:
            if declared_class != COST_ADJUSTED_STREAM_SCHEMA:
                refusal[sleeve_id] = REFUSED_COST_ADJUSTED_DECLARATION
                continue
            try:
                for multiplier in multipliers:
                    points, calibration_sha = load_cost_adjusted_stream(
                        entry,
                        stream_paths[sleeve_id],
                        cost_sha,
                        multiplier,
                    )
                    loaded_by_multiplier[multiplier][sleeve_id] = points
                    previous_sha = calibration_sha256.setdefault(sleeve_id, calibration_sha)
                    if previous_sha != calibration_sha:
                        raise TimeboxEvaluationError(
                            f"stream[{sleeve_id}]: calibration digest changes across sensitivity"
                        )
            except TimeboxEvaluationError as exc:
                if REFUSED_COST_ATTESTATION in str(exc):
                    refusal[sleeve_id] = REFUSED_COST_ATTESTATION
                elif REFUSED_CALENDAR in str(exc):
                    refusal[sleeve_id] = REFUSED_CALENDAR
                else:
                    raise
            continue
        if declared_class is not None:
            refusal[sleeve_id] = REFUSED_COST_ADJUSTED_DECLARATION
            continue
        try:
            loaded_by_multiplier[1.0][sleeve_id] = load_daily_stream(
                entry, stream_paths[sleeve_id], cost_sha
            )
        except TimeboxEvaluationError as exc:
            if REFUSED_COST_ATTESTATION in str(exc):
                refusal[sleeve_id] = REFUSED_COST_ATTESTATION
            elif REFUSED_CALENDAR in str(exc):
                refusal[sleeve_id] = REFUSED_CALENDAR
            else:
                raise
    composition_results: list[dict[str, Any]] = []
    for comp in config["compositions"]:
        sleeve_ids = [item["sleeve_id"] for item in comp["sleeves"]]
        labels = sorted({refusal[sleeve_id] for sleeve_id in sleeve_ids if sleeve_id in refusal})
        base: dict[str, Any] = {
            "id": comp["id"],
            "sleeves": comp["sleeves"],
            "refusal_labels": labels,
            "evidence_class": declared_class or "FTMO_VENUE_EXECUTION",
        }
        if labels:
            base["status"] = "REFUSED"
            composition_results.append(base)
            continue
        weights = {item["sleeve_id"]: float(item["weight"]) for item in comp["sleeves"]}
        sensitivity_band: list[dict[str, Any]] = []
        sensitivity_refusal: str | None = None
        for multiplier in multipliers:
            loaded = loaded_by_multiplier[multiplier]
            correlation = correlation_diagnostic(loaded, sleeve_ids)
            point: dict[str, Any] = {
                "spread_charge_multiplier": multiplier,
                "correlation": correlation,
                "evidence_class": declared_class or "FTMO_VENUE_EXECUTION",
            }
            if correlation["status"] == "REFUSED":
                point["status"] = "REFUSED"
                point["refusal_labels"] = [correlation["label"]]
                sensitivity_band.append(point)
                base["correlation"] = correlation
                sensitivity_refusal = str(correlation["label"])
                break
            try:
                days = combine_streams(loaded, weights)
            except TimeboxEvaluationError as exc:
                if REFUSED_CALENDAR not in str(exc):
                    raise
                point["status"] = "REFUSED"
                point["refusal_labels"] = [REFUSED_CALENDAR]
                sensitivity_band.append(point)
                sensitivity_refusal = REFUSED_CALENDAR
                break
            point["status"] = "EVALUATED"
            point["statistics"] = summarize(days, config["bootstrap"])
            sensitivity_band.append(point)
        if sensitivity_refusal is not None:
            base["status"] = "REFUSED"
            base["refusal_labels"] = [sensitivity_refusal]
            if declared_class is not None:
                base["sensitivity_band"] = sensitivity_band
            composition_results.append(base)
            continue
        lowers = [
            float(point["statistics"]["p1_bootstrap"]["lower"])
            for point in sensitivity_band
        ]
        if any(later > earlier + 1e-12 for earlier, later in zip(lowers, lowers[1:])):
            base["status"] = "REFUSED"
            base["refusal_labels"] = [REFUSED_SENSITIVITY]
            base["sensitivity_band"] = sensitivity_band
            composition_results.append(base)
            continue
        pessimistic = min(
            sensitivity_band,
            key=lambda point: (
                float(point["statistics"]["p1_bootstrap"]["lower"]),
                -float(point["spread_charge_multiplier"]),
            ),
        )
        base["status"] = "EVALUATED"
        base["correlation"] = pessimistic["correlation"]
        base["statistics"] = pessimistic["statistics"]
        if declared_class is not None:
            base["sensitivity_band"] = sensitivity_band
            base["decision_spread_charge_multiplier"] = pessimistic[
                "spread_charge_multiplier"
            ]
            base["pessimistic_bootstrap_lower_bound_p1"] = pessimistic[
                "statistics"
            ]["p1_bootstrap"]["lower"]
        composition_results.append(base)
    evaluated = [row for row in composition_results if row["status"] == "EVALUATED"]
    if evaluated:
        best = max(evaluated, key=lambda row: row["statistics"]["p1_bootstrap"]["lower"])
        lower: float | None = best["statistics"]["p1_bootstrap"]["lower"]
        credited = float(lower)
        best_id: str | None = best["id"]
        decision_multiplier: float | None = best.get("decision_spread_charge_multiplier")
        status = "EVALUATED"
        credit_label = DECISION_LABEL
    else:
        lower = None
        credited = 0.0
        best_id = None
        decision_multiplier = None
        status = "NO_ADMISSIBLE_COMPOSITION"
        credit_label = NO_CREDIT_LABEL
    result = {
        "schema": RESULT_SCHEMA,
        "claim_label": CLAIM_LABEL,
        "evidence_class": declared_class or "DEFAULT_FTMO_VENUE_EXECUTION_ONLY",
        "config_sha256": _normalized_sha(config_sha256, "config_sha256"),
        "status": status,
        "rules": config["rules"],
        "correlation_rule": config["correlation"],
        "input_sha256": {
            "inventory": inputs["inventory"]["sha256"],
            "fund_scores": inputs["fund_scores"]["sha256"],
            "ftmo_cost_snapshot": inputs["ftmo_cost_snapshot"]["sha256"],
            "streams": {
                entry["sleeve_id"]: entry["binding"]["sha256"] for entry in inputs["streams"]
            },
            "calibrations": calibration_sha256,
        },
        "sleeve_refusals": refusal,
        "sleeve_admission": sleeve_admission,
        "compositions": composition_results,
        "decision": {
            "label": credit_label,
            "best_composition_id": best_id,
            "best_bootstrap_lower_bound_p1": lower,
            "decision_spread_charge_multiplier": decision_multiplier,
            "evidence_credited_lower_bound_p1": credited,
            "design_bar_p1": 0.80,
            "gap_to_design_bar": max(0.0, 0.80 - credited),
            "binding_dimension": _binding_dimension(composition_results),
            "book_ready": False,
        },
    }
    return result


def evaluate_config_file(config_path: Path, expected_sha256: str) -> dict[str, Any]:
    expected = _normalized_sha(expected_sha256, "expected_config_sha256")
    actual = sha256_file(config_path)
    if actual != expected:
        raise TimeboxEvaluationError(
            f"config SHA-256 mismatch before input access expected={expected} actual={actual}"
        )
    config = load_json(config_path, "config")
    return evaluate_config(config, actual)


def write_json_atomic(path: Path, value: Any) -> str:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    raw = canonical_json_bytes(value)
    try:
        with temporary.open("xb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return hashlib.sha256(raw).hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare = subparsers.add_parser("prepare-config")
    prepare.add_argument("--spec", type=Path, required=True)
    prepare.add_argument("--output", type=Path, required=True)
    evaluate = subparsers.add_parser("evaluate")
    evaluate.add_argument("--config", type=Path, required=True)
    evaluate.add_argument("--expected-config-sha256", required=True)
    evaluate.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "prepare-config":
            spec = load_json(args.spec, "spec")
            config = prepare_config(spec)
            digest = write_json_atomic(args.output, config)
            print(json.dumps({"status": "PREPARED", "path": str(args.output.resolve()), "sha256": digest}))
        else:
            result = evaluate_config_file(args.config, args.expected_config_sha256)
            digest = write_json_atomic(args.output, result)
            print(
                json.dumps(
                    {
                        "status": "EVALUATION_WRITTEN",
                        "path": str(args.output.resolve()),
                        "sha256": digest,
                        "evaluation_status": result["status"],
                    }
                )
            )
        return 0
    except TimeboxEvaluationError as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
