#!/usr/bin/env python3
"""Hash-bound FTMO Book3 conservative diagnostic evaluator.

The evaluator is intentionally unable to produce a selection-sealed claim from
the historical Book3 bytes.  ``prepare-config`` freezes an IS-derived dependence
contract and file identities; ``evaluate`` requires the reviewed config digest
before it opens a stream.  Both commands are pure with respect to factory/DB/live
state: their only optional mutation is writing the explicitly requested JSON
artifact.
"""

from __future__ import annotations

import argparse
import collections
import copy
import datetime as dt
import hashlib
import json
import math
import os
import random
import re
import uuid
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo


CONFIG_SCHEMA = "qm.book3-conservative-bound-config/v1"
RESULT_SCHEMA = "qm.book3-conservative-bound-result/v1"
CLAIM_LABEL = "HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED"
TRACE_LABEL = "CONSERVATIVE_LIFETIME_MAE_BOUND"
MONEY_BASIS = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
TRIAL_LEDGER = "UNKNOWN_LOWER_BOUND_165"
COST_LABEL = "FIXED_CURRENT_TERMS_COUNTERFACTUAL_NOT_HISTORICAL_REALIZED_SWAP"
STRICT_QUALIFICATION = "UNVERIFIED"
PAID_CHALLENGE = "NO_GO"
PRAGUE = ZoneInfo("Europe/Prague")
BOOK_SYMBOLS = ("USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX")
COMPONENT_TOLERANCE = 0.021
HISTORICAL_START_DAY = dt.date(2022, 9, 16)
HISTORICAL_END_DAY = dt.date(2025, 12, 30)
HISTORICAL_COST_SNAPSHOT_SHA256 = (
    "7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280"
)
EVALUATION_MANIFEST_SHA256 = (
    "fdd26cc9d794c8420ab2f2914aa147f60dc3bdc3a7c4df8bd3c05d2ad91081ab"
)
HISTORICAL_STREAM_CONTRACT: dict[str, dict[str, Any]] = {
    "9936": {
        "symbol": "USDJPY.DWX",
        "expected_rows": 1_143,
        "sha256": "1593ee930e1550236f1c851805d3a71ccdb4c2a244de6994b3dbbf4bf450f7ff",
        "lineage": {
            "summary": "d7109154486d5ec7ce8b7fb11a19b2a809bd9c3332868278c2dddc8093b97717",
            "report": "fab231b70a53bf41173dccc8f4a1dd46cf46a2302cc0f06d28c54905abeb9253",
            "receipt": "4c8a19073504728c4531ef9139a08badfd77308f18729c8d27a10ba48a28e768",
            "evaluation_manifest": EVALUATION_MANIFEST_SHA256,
        },
    },
    "10145": {
        "symbol": "XAUUSD.DWX",
        "expected_rows": 291,
        "sha256": "cba8eac2aab23b68c6846ac7848e7da818cc4608912a9dd83e4f89e75d4af425",
        "lineage": {
            "summary": "2bea34250474f6f31912158c781c7d85de87c4f7894297089c669b30f85c9620",
            "report": "325467c2d139a04966ae9a2dcf775bb98b80ca19c8c77d0a4e8030e2d2547daf",
            "receipt": "caadc31ea7e4603b000af3206868279c68d49c960fa7b4c14667bb0cfb42b3cf",
            "evaluation_manifest": EVALUATION_MANIFEST_SHA256,
        },
    },
    "13108": {
        "symbol": "XTIUSD.DWX",
        "expected_rows": 548,
        "sha256": "136cc04da36b766572843cd496a3770aca694d2eb279f389be4cc2d36ca72179",
        "lineage": {
            "summary": "adc7785eb438d9b74912917e18fa5fb905958fec17856629cd032537ce6670ad",
            "report": "6656847def8114a8e50efc6ac2792ec165154307da163d4c98f66097b4279974",
            "receipt": "742a86159c25c03ca9f9722740301bf4b4c1881be0a331570a7a22f5f7415c68",
            "evaluation_manifest": EVALUATION_MANIFEST_SHA256,
        },
    },
}

DEFAULT_RULES: dict[str, Any] = {
    "initial_capital": 100_000.0,
    "maximum_daily_loss_fraction": 0.05,
    "maximum_total_loss_fraction": 0.10,
    "daily_floor": "MIDNIGHT_BALANCE_MINUS_FIXED_INITIAL_CAPITAL_AMOUNT",
    "total_floor": "INITIAL_CAPITAL_TIMES_0P90",
    "breach_operator": "STRICTLY_BELOW",
    "target_operator": "AT_OR_ABOVE_WHILE_FLAT",
    "timezone": "Europe/Prague",
    "lifetime_interval": "HALF_OPEN_ENTRY_INCLUSIVE_CLOSE_EXCLUSIVE",
    "equal_timestamp_order": ["DAY_BOUNDARY", "CLOSE", "OPEN"],
    "start_eligibility": "SIMULTANEOUS_ACCOUNT_FLAT_PRAGUE_DAY_WITH_NEW_POSITION",
    "censoring": "RIGHT_CENSORED_IS_NON_PASS",
    "trading_day": "PRAGUE_DAY_WITH_POSITION_OPENED",
    "minimum_trading_days_per_phase": 4,
    "phase_transition": "RESET_TO_INITIAL_CAPITAL_NEXT_PRAGUE_DAY_AFTER_FLAT_PASS",
}

DEFAULT_SCENARIOS: list[dict[str, Any]] = [
    {
        "id": "official_raw_1x",
        "phase1_target_fraction": 0.10,
        "phase2_target_fraction": 0.05,
        "phase1_risk_multiplier": 1.0,
        "phase2_risk_multiplier": 1.0,
        "claim_scope": "OFFICIAL_RAW_TARGETS",
    },
    {
        "id": "internal_policy_phase2_0p75",
        "phase1_target_fraction": 0.10,
        "phase2_target_fraction": 0.05,
        "phase1_risk_multiplier": 1.0,
        "phase2_risk_multiplier": 0.75,
        "claim_scope": "INTERNAL_POLICY_SCENARIO_NOT_OFFICIAL_RAW",
    },
]

DEFAULT_BOOTSTRAP: dict[str, Any] = {
    "replicates": 2_000,
    "seed": 20_260_731,
    "alpha": 0.05,
    "minimum_block_days": 20,
    "is_autocorrelation_rule": "LAST_ABS_RHO_AT_OR_ABOVE_1P96_OVER_SQRT_N",
    "max_lag_days": 60,
    "isolated_significant_lag": "INCLUDED",
    "tie_rule": "LARGEST_LAG",
    "bootstrap_path_length": "AT_LEAST_ORIGINAL_DAYS_NO_OPEN_POSITION_TRUNCATION",
    "reference_lower_bound": 0.80,
    "reference_status": "SUPPLEMENTAL_UNRATIFIED_NOT_A_GATE_REDEFINITION",
}


class BoundEvaluationError(ValueError):
    """Fail-closed configuration, identity, coverage, or evaluation error."""


@dataclass(frozen=True)
class RawTrade:
    row_id: str
    sleeve_id: str
    symbol: str
    side: str
    entry_utc: dt.datetime
    close_utc: dt.datetime
    entry_price: float
    exit_price: float
    mae_acct: float
    net: float
    profit: float
    swap: float
    fee: float
    commission: float
    entry_commission: float
    exit_commission: float
    volume: float
    notional: float


@dataclass(frozen=True)
class RepricedTrade:
    row_id: str
    sleeve_id: str
    symbol: str
    side: str
    entry_utc: dt.datetime
    close_utc: dt.datetime
    target_net: float
    lifetime_mae_bound: float
    target_commission: float
    target_entry_commission: float
    target_swap: float
    source_commission_removed: float
    source_swap_removed: float
    equivalent_target_volume: float
    margin_at_entry: float


@dataclass(frozen=True)
class DayComponent:
    day: dt.date
    realized_pnl: float
    pessimistic_low_from_midnight: float
    opened_positions: int
    flat_at_start: bool
    flat_at_end: bool
    peak_margin: float


def _reject_constant(token: str) -> None:
    raise BoundEvaluationError(f"non-finite JSON constant: {token}")


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise BoundEvaluationError(f"duplicate JSON key: {key}")
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
        raise BoundEvaluationError(f"{label}: invalid UTF-8/JSON: {exc}") from exc


def load_json(path: Path, label: str) -> Any:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise BoundEvaluationError(f"{label}: cannot read {path}: {exc}") from exc
    return loads_strict(raw, label)


def canonical_json_bytes(value: Any) -> bytes:
    try:
        text = json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise BoundEvaluationError(f"value is not canonical JSON: {exc}") from exc
    return text.encode("utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    except OSError as exc:
        raise BoundEvaluationError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _normalized_sha(value: Any, label: str) -> str:
    token = str(value or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", token):
        raise BoundEvaluationError(f"{label}: expected lowercase/uppercase SHA-256")
    return token


def verify_binding(binding: Mapping[str, Any], label: str) -> tuple[Path, str]:
    path = Path(str(binding.get("path") or "")).expanduser().resolve()
    if not path.is_file():
        raise BoundEvaluationError(f"{label}: bound file missing: {path}")
    expected = _normalized_sha(binding.get("sha256"), f"{label}:sha256")
    actual = sha256_file(path)
    if actual != expected:
        raise BoundEvaluationError(
            f"{label}: SHA-256 mismatch: expected={expected} actual={actual} path={path}"
        )
    return path, actual


def pin_binding(binding: Mapping[str, Any], label: str) -> dict[str, Any]:
    path = Path(str(binding.get("path") or "")).expanduser().resolve()
    if not path.is_file():
        raise BoundEvaluationError(f"{label}: file missing: {path}")
    actual = sha256_file(path)
    supplied = binding.get("sha256")
    if supplied is not None and _normalized_sha(supplied, f"{label}:sha256") != actual:
        raise BoundEvaluationError(f"{label}: supplied SHA-256 does not match {path}")
    out = copy.deepcopy(dict(binding))
    out["path"] = str(path)
    out["sha256"] = actual
    return out


def _validate_historical_stream_contract(streams: Any) -> None:
    if not isinstance(streams, list) or len(streams) != len(HISTORICAL_STREAM_CONTRACT):
        raise BoundEvaluationError("config requires the exact three historical streams")
    seen: set[str] = set()
    for index, stream in enumerate(streams):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError(f"stream[{index}] must be an object")
        sleeve_id = str(stream.get("sleeve_id") or "").strip()
        expected = HISTORICAL_STREAM_CONTRACT.get(sleeve_id)
        if expected is None or sleeve_id in seen:
            raise BoundEvaluationError(f"stream[{index}]: unexpected/duplicate sleeve {sleeve_id}")
        seen.add(sleeve_id)
        if stream.get("symbol") != expected["symbol"]:
            raise BoundEvaluationError(f"stream[{index}]: historical symbol mismatch")
        if stream.get("expected_rows") != expected["expected_rows"]:
            raise BoundEvaluationError(f"stream[{index}]: historical row-count contract mismatch")
        if _normalized_sha(stream.get("sha256"), f"stream[{index}]:sha256") != expected["sha256"]:
            raise BoundEvaluationError(f"stream[{index}]: historical stream digest mismatch")
        lineage = stream.get("lineage")
        if not isinstance(lineage, list):
            raise BoundEvaluationError(f"stream[{index}].lineage must be a list")
        by_role: dict[str, Mapping[str, Any]] = {}
        for artifact_index, artifact in enumerate(lineage):
            if not isinstance(artifact, Mapping):
                raise BoundEvaluationError(
                    f"stream[{index}].lineage[{artifact_index}] must be an object"
                )
            role = str(artifact.get("role") or "").strip()
            if not role or role in by_role:
                raise BoundEvaluationError(f"stream[{index}]: duplicate/empty lineage role")
            by_role[role] = artifact
        for role, digest in expected["lineage"].items():
            artifact = by_role.get(role)
            if artifact is None:
                raise BoundEvaluationError(f"stream[{index}]: missing lineage role {role}")
            if _normalized_sha(
                artifact.get("sha256"), f"stream[{index}].lineage:{role}:sha256"
            ) != digest:
                raise BoundEvaluationError(f"stream[{index}]: lineage digest mismatch for {role}")
    if seen != set(HISTORICAL_STREAM_CONTRACT):
        raise BoundEvaluationError("historical stream sleeve set mismatch")


def _validate_is_stream_contract(is_streams: Any) -> None:
    if not isinstance(is_streams, list) or len(is_streams) != len(HISTORICAL_STREAM_CONTRACT):
        raise BoundEvaluationError("config requires three separately truncated IS streams")
    seen: set[str] = set()
    for index, stream in enumerate(is_streams):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError(f"is_stream[{index}] must be an object")
        sleeve_id = str(stream.get("sleeve_id") or "").strip()
        expected = HISTORICAL_STREAM_CONTRACT.get(sleeve_id)
        if expected is None or sleeve_id in seen:
            raise BoundEvaluationError(f"is_stream[{index}]: unexpected/duplicate sleeve {sleeve_id}")
        seen.add(sleeve_id)
        if stream.get("symbol") != expected["symbol"]:
            raise BoundEvaluationError(f"is_stream[{index}]: symbol mismatch")
        _positive_int(stream.get("expected_rows"), f"is_stream[{index}].expected_rows")
        if _normalized_sha(
            stream.get("parent_stream_sha256"),
            f"is_stream[{index}].parent_stream_sha256",
        ) != expected["sha256"]:
            raise BoundEvaluationError(f"is_stream[{index}]: parent stream mismatch")
        if stream.get("derivation") != "IS_ONLY_ENTRY_AND_CLOSE_WITHIN_WINDOW":
            raise BoundEvaluationError(f"is_stream[{index}]: derivation contract mismatch")
        _normalized_sha(stream.get("sha256"), f"is_stream[{index}].sha256")
    if seen != set(HISTORICAL_STREAM_CONTRACT):
        raise BoundEvaluationError("IS stream sleeve set mismatch")


def _validate_cost_binding(binding: Any) -> None:
    if not isinstance(binding, Mapping):
        raise BoundEvaluationError("cost snapshot binding must be an object")
    if _normalized_sha(binding.get("sha256"), "cost_snapshot.sha256") != HISTORICAL_COST_SNAPSHOT_SHA256:
        raise BoundEvaluationError("cost snapshot is not the reviewed fixed-current-terms artifact")


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise BoundEvaluationError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise BoundEvaluationError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise BoundEvaluationError(f"{label}: expected finite number")
    return number


def _positive(value: Any, label: str) -> float:
    number = _finite(value, label)
    if number <= 0.0:
        raise BoundEvaluationError(f"{label}: expected > 0")
    return number


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise BoundEvaluationError(f"{label}: expected positive integer")
    return value


def parse_utc(value: Any, label: str) -> dt.datetime:
    if isinstance(value, bool):
        raise BoundEvaluationError(f"{label}: invalid timestamp")
    if isinstance(value, (int, float)):
        number = _finite(value, label)
        try:
            return dt.datetime.fromtimestamp(number, tz=dt.UTC)
        except (OverflowError, OSError, ValueError) as exc:
            raise BoundEvaluationError(f"{label}: invalid epoch timestamp") from exc
    token = str(value or "").strip()
    if not token:
        raise BoundEvaluationError(f"{label}: missing timestamp")
    try:
        parsed = dt.datetime.fromisoformat(token.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BoundEvaluationError(f"{label}: invalid ISO timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        raise BoundEvaluationError(f"{label}: timestamp must be explicit UTC")
    return parsed.astimezone(dt.UTC)


def utc_z(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _date_range(first: dt.date, last: dt.date) -> Iterable[dt.date]:
    day = first
    while day <= last:
        yield day
        day += dt.timedelta(days=1)


def _local_midnight_utc(day: dt.date, zone: ZoneInfo = PRAGUE) -> dt.datetime:
    return dt.datetime.combine(day, dt.time.min, tzinfo=zone).astimezone(dt.UTC)


def rollover_session_days(
    entry_utc: dt.datetime,
    close_utc: dt.datetime,
    zone: ZoneInfo = PRAGUE,
) -> list[dt.date]:
    """Return local session dates whose ending midnight was crossed.

    Local-date iteration (rather than fixed 24-hour buckets) preserves the
    23/25-hour Europe/Prague DST transition days.
    """

    if close_utc <= entry_utc:
        raise BoundEvaluationError("trade lifetime must be a positive half-open interval")
    first = entry_utc.astimezone(zone).date()
    last_exclusive = close_utc.astimezone(zone).date()
    return list(_date_range(first, last_exclusive - dt.timedelta(days=1))) if first < last_exclusive else []


def _lineage_bindings(config: Mapping[str, Any]) -> Iterable[tuple[Mapping[str, Any], str]]:
    inputs = config.get("inputs")
    if not isinstance(inputs, Mapping):
        raise BoundEvaluationError("config:inputs must be an object")
    streams = inputs.get("streams")
    if not isinstance(streams, list):
        raise BoundEvaluationError("config:inputs.streams must be a list")
    for index, stream in enumerate(streams):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError(f"config:stream[{index}] must be an object")
        yield stream, f"stream[{index}]"
        lineage = stream.get("lineage", [])
        if not isinstance(lineage, list):
            raise BoundEvaluationError(f"stream[{index}].lineage must be a list")
        for lineage_index, artifact in enumerate(lineage):
            if not isinstance(artifact, Mapping):
                raise BoundEvaluationError("lineage binding must be an object")
            yield artifact, f"stream[{index}].lineage[{lineage_index}]"
    is_streams = inputs.get("is_streams")
    if not isinstance(is_streams, list):
        raise BoundEvaluationError("config:inputs.is_streams must be a list")
    for index, stream in enumerate(is_streams):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError(f"config:is_stream[{index}] must be an object")
        yield stream, f"is_stream[{index}]"
    cost = inputs.get("cost_snapshot")
    if not isinstance(cost, Mapping):
        raise BoundEvaluationError("config:inputs.cost_snapshot must be an object")
    yield cost, "cost_snapshot"


def verify_all_inputs(config: Mapping[str, Any]) -> None:
    for binding, label in _lineage_bindings(config):
        verify_binding(binding, label)


def _load_jsonl_rows(path: Path, label: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        with path.open("rb") as handle:
            for line_number, raw in enumerate(handle, start=1):
                if not raw.strip():
                    continue
                value = loads_strict(raw, f"{label}:line:{line_number}")
                if not isinstance(value, dict):
                    raise BoundEvaluationError(f"{label}:line:{line_number}: expected object")
                rows.append(value)
    except OSError as exc:
        raise BoundEvaluationError(f"{label}: cannot read JSONL: {exc}") from exc
    if not rows:
        raise BoundEvaluationError(f"{label}: stream is empty")
    return rows


def load_raw_stream(binding: Mapping[str, Any], index: int) -> tuple[list[RawTrade], dict[str, Any]]:
    path, digest = verify_binding(binding, f"stream[{index}]")
    sleeve_id = str(binding.get("sleeve_id") or "").strip()
    expected_symbol = str(binding.get("symbol") or "").strip()
    if not sleeve_id or expected_symbol not in BOOK_SYMBOLS:
        raise BoundEvaluationError(f"stream[{index}]: invalid sleeve/symbol identity")
    raw_rows = _load_jsonl_rows(path, f"stream[{index}]")
    expected_rows = binding.get("expected_rows")
    if expected_rows is not None and _positive_int(expected_rows, "expected_rows") != len(raw_rows):
        raise BoundEvaluationError(
            f"stream[{index}]: row-count mismatch expected={expected_rows} actual={len(raw_rows)}"
        )

    required = {
        "event", "money_basis", "side", "entry_price", "exit_price", "time",
        "entry_time", "mae_acct", "net", "profit", "swap", "fee",
        "commission", "entry_commission", "exit_commission", "volume",
        "notional", "symbol",
    }
    trades: list[RawTrade] = []
    for row_number, row in enumerate(raw_rows, start=1):
        missing = sorted(required - set(row))
        if missing:
            raise BoundEvaluationError(
                f"stream[{index}]:line:{row_number}: missing fields {','.join(missing)}"
            )
        if row.get("event") != "TRADE_CLOSED" or row.get("money_basis") != MONEY_BASIS:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: money/event basis mismatch")
        symbol = str(row.get("symbol") or "")
        side = str(row.get("side") or "").upper()
        if symbol != expected_symbol or side not in {"BUY", "SELL"}:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: symbol/side mismatch")
        entry = parse_utc(row["entry_time"], f"stream[{index}]:entry_time")
        close = parse_utc(row["time"], f"stream[{index}]:time")
        if close <= entry:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: non-positive lifetime")
        values = {
            key: _finite(row[key], f"stream[{index}]:line:{row_number}:{key}")
            for key in (
                "entry_price", "exit_price", "mae_acct", "net", "profit", "swap",
                "fee", "commission", "entry_commission", "exit_commission",
                "volume", "notional",
            )
        }
        if values["entry_price"] <= 0 or values["exit_price"] <= 0 or values["volume"] <= 0:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: non-positive price/volume")
        reconciled = values["profit"] + values["swap"] + values["fee"] + values["commission"]
        if abs(values["net"] - reconciled) > COMPONENT_TOLERANCE:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: net component mismatch")
        if abs(
            values["commission"]
            - values["entry_commission"]
            - values["exit_commission"]
        ) > COMPONENT_TOLERANCE:
            raise BoundEvaluationError(f"stream[{index}]:line:{row_number}: commission split mismatch")
        trades.append(
            RawTrade(
                row_id=f"{sleeve_id}:{row_number}",
                sleeve_id=sleeve_id,
                symbol=symbol,
                side=side,
                entry_utc=entry,
                close_utc=close,
                entry_price=values["entry_price"],
                exit_price=values["exit_price"],
                mae_acct=values["mae_acct"],
                net=values["net"],
                profit=values["profit"],
                swap=values["swap"],
                fee=values["fee"],
                commission=values["commission"],
                entry_commission=values["entry_commission"],
                exit_commission=values["exit_commission"],
                volume=values["volume"],
                notional=values["notional"],
            )
        )
    coverage = {
        "sleeve_id": sleeve_id,
        "symbol": expected_symbol,
        "rows": len(trades),
        "sha256": digest,
        "first_entry_utc": utc_z(min(row.entry_utc for row in trades)),
        "last_close_utc": utc_z(max(row.close_utc for row in trades)),
        "money_basis": MONEY_BASIS,
        "required_field_coverage_percent": 100.0,
    }
    return trades, coverage


def _trade_contract_tuple(trade: RawTrade) -> tuple[Any, ...]:
    return (
        trade.sleeve_id,
        trade.symbol,
        trade.side,
        trade.entry_utc,
        trade.close_utc,
        trade.entry_price,
        trade.exit_price,
        trade.mae_acct,
        trade.net,
        trade.profit,
        trade.swap,
        trade.fee,
        trade.commission,
        trade.entry_commission,
        trade.exit_commission,
        trade.volume,
        trade.notional,
    )


def verify_is_derivation(
    full_streams: Sequence[tuple[list[RawTrade], dict[str, Any]]],
    is_streams: Sequence[tuple[list[RawTrade], dict[str, Any]]],
    is_start: dt.datetime,
    is_end: dt.datetime,
) -> dict[str, int]:
    full_by_sleeve = {coverage["sleeve_id"]: rows for rows, coverage in full_streams}
    is_by_sleeve = {coverage["sleeve_id"]: rows for rows, coverage in is_streams}
    if set(full_by_sleeve) != set(is_by_sleeve):
        raise BoundEvaluationError("IS/full stream sleeve identity mismatch")
    verified: dict[str, int] = {}
    for sleeve_id, full_rows in full_by_sleeve.items():
        expected = collections.Counter(
            _trade_contract_tuple(row)
            for row in full_rows
            if row.entry_utc >= is_start and row.close_utc <= is_end
        )
        observed = collections.Counter(_trade_contract_tuple(row) for row in is_by_sleeve[sleeve_id])
        if not expected or observed != expected:
            raise BoundEvaluationError(
                f"IS stream is not the exact entry-and-close window derivation: {sleeve_id}"
            )
        verified[sleeve_id] = sum(observed.values())
    return dict(sorted(verified.items()))


def load_cost_snapshot(binding: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    path, digest = verify_binding(binding, "cost_snapshot")
    raw = load_json(path, "cost_snapshot")
    if not isinstance(raw, dict) or raw.get("schema") != "qm.ftmo-book3-symbol-cost-snapshot/v1":
        raise BoundEvaluationError("cost_snapshot: schema mismatch")
    rows = raw.get("selected_provider_rows")
    normalizations = raw.get("book3_normalization")
    if not isinstance(rows, list) or not isinstance(normalizations, list):
        raise BoundEvaluationError("cost_snapshot: provider/normalization rows missing")
    provider_by_code = {
        str(row.get("code")): row for row in rows if isinstance(row, dict)
    }
    costs: dict[str, dict[str, Any]] = {}
    for normalized in normalizations:
        if not isinstance(normalized, dict):
            raise BoundEvaluationError("cost_snapshot: normalization row is not an object")
        symbol = str(normalized.get("dwx_symbol") or "")
        if symbol not in BOOK_SYMBOLS or symbol in costs:
            raise BoundEvaluationError(f"cost_snapshot: invalid/duplicate symbol {symbol}")
        provider_symbol = str(normalized.get("provider_symbol") or "")
        provider = provider_by_code.get(provider_symbol)
        if provider is None:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: provider row missing")
        required_normalized = (
            "source_contract_size", "target_contract_size", "commission_model",
            "flat_round_trip_commission_per_lot", "commission_percent_per_side",
            "swap_long_points", "swap_short_points", "digits",
            "profit_currency_to_account_rate", "triple_weekday",
        )
        missing = [key for key in required_normalized if normalized.get(key) is None]
        if missing or provider.get("swapLong") is None or provider.get("swapShort") is None:
            raise BoundEvaluationError(
                f"cost_snapshot:{symbol}: missing cost fields {','.join(missing) or 'provider_swap'}"
            )
        source_contract = _positive(normalized["source_contract_size"], "source_contract_size")
        target_contract = _positive(normalized["target_contract_size"], "target_contract_size")
        digits = int(_finite(normalized["digits"], "digits"))
        triple = int(_finite(normalized["triple_weekday"], "triple_weekday"))
        if digits < 0 or not 0 <= triple <= 6:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: invalid digits/triple weekday")
        leverage = _positive(provider.get("leverageSwing"), f"cost_snapshot:{symbol}:leverageSwing")
        margin_mode = str(provider.get("marginCalculation") or "")
        if margin_mode not in {"forex", "cfd_leverage"}:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: unsupported margin calculation")
        costs[symbol] = {
            **copy.deepcopy(normalized),
            "source_contract_size": source_contract,
            "target_contract_size": target_contract,
            "flat_round_trip_commission_per_lot": _finite(
                normalized["flat_round_trip_commission_per_lot"], "flat commission"
            ),
            "commission_percent_per_side": _finite(
                normalized["commission_percent_per_side"], "percent commission"
            ),
            "swap_long_points": _finite(normalized["swap_long_points"], "swap long"),
            "swap_short_points": _finite(normalized["swap_short_points"], "swap short"),
            "profit_currency_to_account_rate": _positive(
                normalized["profit_currency_to_account_rate"], "profit conversion"
            ),
            "digits": digits,
            "triple_weekday": triple,
            "leverage_swing": leverage,
            "margin_calculation": margin_mode,
            "margin_currency": str(provider.get("marginCurrency") or ""),
            "margin_currency_to_account_rate": 1.0
            if str(provider.get("marginCurrency") or "").upper() == "USD"
            else None,
            "provider_swap_long": _finite(provider["swapLong"], "provider swap long"),
            "provider_swap_short": _finite(provider["swapShort"], "provider swap short"),
            "snapshot_sha256": digest,
        }
        if costs[symbol]["margin_currency_to_account_rate"] is None:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: margin conversion missing")
        if abs(costs[symbol]["provider_swap_long"] - costs[symbol]["swap_long_points"]) > 1e-12:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: normalized long swap mismatch")
        if abs(costs[symbol]["provider_swap_short"] - costs[symbol]["swap_short_points"]) > 1e-12:
            raise BoundEvaluationError(f"cost_snapshot:{symbol}: normalized short swap mismatch")
    if set(costs) != set(BOOK_SYMBOLS):
        raise BoundEvaluationError("cost_snapshot: exact Book3 symbol set missing")
    return costs


def _commission_components(trade: RawTrade, cost: Mapping[str, Any]) -> tuple[float, float]:
    equivalent_volume = trade.volume * float(cost["source_contract_size"]) / float(
        cost["target_contract_size"]
    )
    model = str(cost.get("commission_model") or "")
    if model == "flat_round_trip_per_target_lot_usd":
        total = -float(cost["flat_round_trip_commission_per_lot"]) * equivalent_volume
        return total / 2.0, total / 2.0
    if model == "percent_of_notional_per_side":
        fraction = float(cost["commission_percent_per_side"]) / 100.0
        entry_notional = trade.entry_price * float(cost["target_contract_size"]) * equivalent_volume
        exit_notional = trade.exit_price * float(cost["target_contract_size"]) * equivalent_volume
        return -entry_notional * fraction, -exit_notional * fraction
    if model == "commission_free":
        return 0.0, 0.0
    raise BoundEvaluationError(f"cost:{trade.symbol}: unsupported commission model {model}")


def _target_swap(trade: RawTrade, cost: Mapping[str, Any]) -> float:
    points = (
        float(cost["swap_long_points"])
        if trade.side == "BUY"
        else float(cost["swap_short_points"])
    )
    equivalent_volume = trade.volume * float(cost["source_contract_size"]) / float(
        cost["target_contract_size"]
    )
    point_value = (
        10.0 ** (-int(cost["digits"]))
        * float(cost["target_contract_size"])
        * equivalent_volume
        * float(cost["profit_currency_to_account_rate"])
    )
    total = 0.0
    for session_day in rollover_session_days(trade.entry_utc, trade.close_utc):
        if session_day.weekday() >= 5:
            continue
        multiplier = 3.0 if session_day.weekday() == int(cost["triple_weekday"]) else 1.0
        total += points * point_value * multiplier
    return total


def _margin_at_entry(trade: RawTrade, cost: Mapping[str, Any]) -> float:
    equivalent_volume = trade.volume * float(cost["source_contract_size"]) / float(
        cost["target_contract_size"]
    )
    contract = float(cost["target_contract_size"])
    leverage = float(cost["leverage_swing"])
    if cost["margin_calculation"] == "forex" and str(cost["margin_currency"]).upper() == "USD":
        basis = equivalent_volume * contract
    else:
        basis = equivalent_volume * contract * trade.entry_price
    return basis / leverage * float(cost["margin_currency_to_account_rate"])


def reprice_trade(trade: RawTrade, cost: Mapping[str, Any]) -> RepricedTrade:
    entry_commission, exit_commission = _commission_components(trade, cost)
    target_commission = entry_commission + exit_commission
    target_swap = _target_swap(trade, cost)
    target_net = trade.profit + trade.fee + target_commission + target_swap
    # ``mae_acct`` is the framework's observed floating/lifecycle lower operand.
    # Preserve it rather than raising a close-capped value whose exact floating
    # minimum is unknowable.  Add target entry commission and all negative
    # lifetime swap up front; this can only make the bound more conservative.
    lifetime_bound = trade.mae_acct + entry_commission + min(0.0, target_swap)
    equivalent_volume = trade.volume * float(cost["source_contract_size"]) / float(
        cost["target_contract_size"]
    )
    return RepricedTrade(
        row_id=trade.row_id,
        sleeve_id=trade.sleeve_id,
        symbol=trade.symbol,
        side=trade.side,
        entry_utc=trade.entry_utc,
        close_utc=trade.close_utc,
        target_net=target_net,
        lifetime_mae_bound=lifetime_bound,
        target_commission=target_commission,
        target_entry_commission=entry_commission,
        target_swap=target_swap,
        source_commission_removed=trade.commission,
        source_swap_removed=trade.swap,
        equivalent_target_volume=equivalent_volume,
        margin_at_entry=_margin_at_entry(trade, cost),
    )


def build_daily_components(
    trades: Sequence[RepricedTrade],
    start_utc: dt.datetime,
    end_utc: dt.datetime,
    zone: ZoneInfo = PRAGUE,
) -> list[DayComponent]:
    if end_utc < start_utc:
        raise BoundEvaluationError("evaluation window end precedes start")
    start_day = start_utc.astimezone(zone).date()
    end_day = end_utc.astimezone(zone).date()
    end_exclusive = end_utc + dt.timedelta(microseconds=1)
    relevant = [
        row for row in trades
        if row.entry_utc < end_exclusive and row.close_utc > start_utc
    ]
    by_id = {row.row_id: row for row in relevant}
    if len(by_id) != len(relevant):
        raise BoundEvaluationError("duplicate repriced trade row_id")
    active: dict[str, RepricedTrade] = {
        row.row_id: row
        for row in relevant
        if row.entry_utc < start_utc < row.close_utc
    }
    events_by_day: dict[dt.date, list[tuple[dt.datetime, int, str]]] = collections.defaultdict(list)
    for row in relevant:
        if start_utc < row.close_utc < end_exclusive:
            events_by_day[row.close_utc.astimezone(zone).date()].append(
                (row.close_utc, 0, row.row_id)
            )
        if start_utc <= row.entry_utc < end_exclusive:
            events_by_day[row.entry_utc.astimezone(zone).date()].append(
                (row.entry_utc, 1, row.row_id)
            )

    days: list[DayComponent] = []
    for day in _date_range(start_day, end_day):
        flat_start = not active
        intra_realized = 0.0
        opened = 0
        low = min(0.0, sum(row.lifetime_mae_bound for row in active.values()))
        peak_margin = sum(row.margin_at_entry for row in active.values())
        for _timestamp, event_order, row_id in sorted(
            events_by_day.get(day, []), key=lambda item: (item[0], item[1], item[2])
        ):
            row = by_id[row_id]
            if event_order == 0:  # CLOSE precedes OPEN at equal timestamps.
                active.pop(row_id, None)
                intra_realized += row.target_net
            else:
                if row_id in active:
                    raise BoundEvaluationError(f"duplicate open event: {row_id}")
                active[row_id] = row
                opened += 1
            open_bound = sum(item.lifetime_mae_bound for item in active.values())
            low = min(low, intra_realized + open_bound)
            peak_margin = max(
                peak_margin,
                sum(item.margin_at_entry for item in active.values()),
            )
        days.append(
            DayComponent(
                day=day,
                realized_pnl=intra_realized,
                pessimistic_low_from_midnight=low,
                opened_positions=opened,
                flat_at_start=flat_start,
                flat_at_end=not active,
                peak_margin=peak_margin,
            )
        )
    return days


def evaluate_phase(
    days: Sequence[DayComponent],
    start_index: int,
    *,
    target_fraction: float,
    risk_multiplier: float,
    rules: Mapping[str, Any],
) -> dict[str, Any]:
    if start_index < 0 or start_index >= len(days) or not days[start_index].flat_at_start:
        raise BoundEvaluationError("phase start must be an in-range all-flat day")
    initial = _positive(rules.get("initial_capital"), "rules.initial_capital")
    daily_amount = initial * _finite(
        rules.get("maximum_daily_loss_fraction"), "rules.maximum_daily_loss_fraction"
    )
    total_floor = initial * (
        1.0 - _finite(rules.get("maximum_total_loss_fraction"), "rules.maximum_total_loss_fraction")
    )
    minimum_days = _positive_int(
        rules.get("minimum_trading_days_per_phase"), "rules.minimum_trading_days_per_phase"
    )
    target = initial * (1.0 + _finite(target_fraction, "phase.target_fraction"))
    multiplier = _positive(risk_multiplier, "phase.risk_multiplier")
    balance = initial
    trading_days = 0
    for index in range(start_index, len(days)):
        row = days[index]
        midnight_balance = balance
        minimum_equity = midnight_balance + multiplier * row.pessimistic_low_from_midnight
        daily_floor = midnight_balance - daily_amount
        if minimum_equity < daily_floor:
            return {
                "outcome": "daily_loss_breach",
                "start_index": start_index,
                "end_index": index,
                "end_day": row.day.isoformat(),
                "minimum_equity": minimum_equity,
                "floor": daily_floor,
                "trading_days": trading_days,
            }
        if minimum_equity < total_floor:
            return {
                "outcome": "total_loss_breach",
                "start_index": start_index,
                "end_index": index,
                "end_day": row.day.isoformat(),
                "minimum_equity": minimum_equity,
                "floor": total_floor,
                "trading_days": trading_days,
            }
        balance += multiplier * row.realized_pnl
        if row.opened_positions > 0:
            trading_days += 1
        if balance >= target and row.flat_at_end and trading_days >= minimum_days:
            return {
                "outcome": "passed",
                "start_index": start_index,
                "end_index": index,
                "end_day": row.day.isoformat(),
                "end_balance": balance,
                "trading_days": trading_days,
            }
    return {
        "outcome": "right_censored",
        "start_index": start_index,
        "end_index": len(days) - 1,
        "end_day": days[-1].day.isoformat(),
        "end_balance": balance,
        "trading_days": trading_days,
    }


def evaluate_two_phase(
    days: Sequence[DayComponent],
    start_index: int,
    scenario: Mapping[str, Any],
    rules: Mapping[str, Any],
) -> dict[str, Any]:
    phase1 = evaluate_phase(
        days,
        start_index,
        target_fraction=_finite(scenario.get("phase1_target_fraction"), "scenario.phase1_target"),
        risk_multiplier=_positive(scenario.get("phase1_risk_multiplier"), "scenario.phase1_multiplier"),
        rules=rules,
    )
    if phase1["outcome"] != "passed":
        return {
            "outcome": f"phase1_{phase1['outcome']}",
            "start_index": start_index,
            "end_index": phase1["end_index"],
            "phase1": phase1,
            "phase2": None,
        }
    phase2_start = int(phase1["end_index"]) + 1
    if phase2_start >= len(days):
        return {
            "outcome": "phase2_right_censored",
            "start_index": start_index,
            "end_index": len(days) - 1,
            "phase1": phase1,
            "phase2": None,
        }
    phase2 = evaluate_phase(
        days,
        phase2_start,
        target_fraction=_finite(scenario.get("phase2_target_fraction"), "scenario.phase2_target"),
        risk_multiplier=_positive(scenario.get("phase2_risk_multiplier"), "scenario.phase2_multiplier"),
        rules=rules,
    )
    return {
        "outcome": "passed" if phase2["outcome"] == "passed" else f"phase2_{phase2['outcome']}",
        "start_index": start_index,
        "end_index": phase2["end_index"],
        "phase1": phase1,
        "phase2": phase2,
    }


def historical_outcomes(
    days: Sequence[DayComponent],
    scenario: Mapping[str, Any],
    rules: Mapping[str, Any],
) -> list[dict[str, Any]]:
    starts = [
        index for index, row in enumerate(days)
        if row.flat_at_start and row.opened_positions > 0
    ]
    return [evaluate_two_phase(days, index, scenario, rules) for index in starts]


def _rate(outcomes: Sequence[Mapping[str, Any]]) -> float:
    if not outcomes:
        raise BoundEvaluationError("no eligible simultaneous-flat starts")
    return sum(row.get("outcome") == "passed" for row in outcomes) / len(outcomes)


def greedy_nonoverlap(outcomes: Sequence[Mapping[str, Any]]) -> list[Mapping[str, Any]]:
    selected: list[Mapping[str, Any]] = []
    last_end = -1
    for row in sorted(outcomes, key=lambda item: int(item["start_index"])):
        if int(row["start_index"]) > last_end:
            selected.append(row)
            last_end = int(row["end_index"])
    return selected


def autocorrelations(values: Sequence[float], bandwidth: int) -> list[float]:
    n = len(values)
    if n < 2:
        return []
    mean = sum(values) / n
    denominator = sum((value - mean) ** 2 for value in values)
    if denominator <= 0.0:
        return [0.0 for _ in range(min(bandwidth, n - 1))]
    out = []
    for lag in range(1, min(bandwidth, n - 1) + 1):
        numerator = sum(
            (values[index] - mean) * (values[index + lag] - mean)
            for index in range(n - lag)
        )
        out.append(numerator / denominator)
    return out


def hac_ess(outcomes: Sequence[Mapping[str, Any]], bandwidth: int) -> dict[str, Any]:
    indicators = [1.0 if row.get("outcome") == "passed" else 0.0 for row in outcomes]
    n = len(indicators)
    if n == 0:
        raise BoundEvaluationError("HAC ESS requires outcomes")
    k = min(max(0, int(bandwidth)), max(0, n - 1))
    rhos = autocorrelations(indicators, k)
    denominator = 1.0 + 2.0 * sum(
        (1.0 - lag / (k + 1.0)) * rho
        for lag, rho in enumerate(rhos, start=1)
    )
    raw = n / denominator if denominator > 0.0 else float(n)
    return {
        "N": n,
        "K": k,
        "rho": rhos,
        "formula": "N/(1+2*sum((1-k/(K+1))*rho_k))",
        "ess": min(float(n), max(1.0, raw)),
    }


def _flat_boundary_blocks(days: Sequence[DayComponent], target_days: int) -> list[list[DayComponent]]:
    if target_days <= 0:
        raise BoundEvaluationError("bootstrap target block days must be positive")
    blocks: list[list[DayComponent]] = []
    for start in range(len(days)):
        if not days[start].flat_at_start:
            continue
        end = start + target_days - 1
        if end >= len(days):
            continue
        while end < len(days) and not days[end].flat_at_end:
            end += 1
        if end < len(days):
            blocks.append(list(days[start : end + 1]))
    if not blocks:
        raise BoundEvaluationError(
            f"no all-flat moving block can satisfy target_days={target_days}"
        )
    return blocks


def _percentile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise BoundEvaluationError("percentile requires values")
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    low = int(math.floor(position))
    high = int(math.ceil(position))
    if low == high:
        return ordered[low]
    weight = position - low
    return ordered[low] * (1.0 - weight) + ordered[high] * weight


def moving_block_bootstrap(
    days: Sequence[DayComponent],
    scenario: Mapping[str, Any],
    rules: Mapping[str, Any],
    *,
    target_days: int,
    replicates: int,
    seed: int,
    alpha: float,
) -> dict[str, Any]:
    blocks = _flat_boundary_blocks(days, target_days)
    rng = random.Random(seed + target_days * 1_000_003)
    rates: list[float] = []
    sampled_lengths: list[int] = []
    for _ in range(replicates):
        sampled: list[DayComponent] = []
        while len(sampled) < len(days):
            sampled.extend(rng.choice(blocks))
        outcomes = historical_outcomes(sampled, scenario, rules)
        rates.append(_rate(outcomes))
        sampled_lengths.append(len(sampled))
    return {
        "target_days": target_days,
        "candidate_blocks": len(blocks),
        "replicates": replicates,
        "seed": seed,
        "alpha": alpha,
        "ci_lower": _percentile(rates, alpha / 2.0),
        "ci_upper": _percentile(rates, 1.0 - alpha / 2.0),
        "median": _percentile(rates, 0.5),
        "minimum_sampled_days": min(sampled_lengths),
        "maximum_sampled_days": max(sampled_lengths),
        "full_two_phase_re_evaluation": True,
        "open_position_truncation": False,
    }


def summarize_scenario(
    days: Sequence[DayComponent],
    scenario: Mapping[str, Any],
    rules: Mapping[str, Any],
    bootstrap: Mapping[str, Any],
) -> dict[str, Any]:
    outcomes = historical_outcomes(days, scenario, rules)
    if not outcomes:
        raise BoundEvaluationError("scenario has no eligible starts")
    selected = greedy_nonoverlap(outcomes)
    counts = collections.Counter(str(row["outcome"]) for row in outcomes)
    target_days = _positive_int(bootstrap.get("target_days"), "bootstrap.target_days")
    lengths = [
        _positive_int(value, "bootstrap.sensitivity_days")
        for value in bootstrap.get("sensitivity_days", [])
    ]
    replicates = _positive_int(bootstrap.get("replicates"), "bootstrap.replicates")
    seed = int(bootstrap.get("seed"))
    alpha = _finite(bootstrap.get("alpha"), "bootstrap.alpha")
    if not 0.0 < alpha < 1.0:
        raise BoundEvaluationError("bootstrap.alpha must be between zero and one")
    primary = moving_block_bootstrap(
        days,
        scenario,
        rules,
        target_days=target_days,
        replicates=replicates,
        seed=seed,
        alpha=alpha,
    )
    sensitivity = [
        moving_block_bootstrap(
            days,
            scenario,
            rules,
            target_days=length,
            replicates=replicates,
            seed=seed,
            alpha=alpha,
        )
        for length in lengths
    ]
    reference = _finite(bootstrap.get("reference_lower_bound"), "reference_lower_bound")
    return {
        "scenario": copy.deepcopy(dict(scenario)),
        "raw_overlapping": {
            "starts": len(outcomes),
            "passes": counts.get("passed", 0),
            "pass_rate": _rate(outcomes),
            "outcome_counts": dict(sorted(counts.items())),
            "right_censored_counted_as_non_pass": True,
        },
        "greedy_non_overlapping": {
            "starts": len(selected),
            "passes": sum(row.get("outcome") == "passed" for row in selected),
            "pass_rate": _rate(selected),
            "selection_rule": "EARLIEST_START_THEN_NEXT_START_STRICTLY_AFTER_PRIOR_OUTCOME_END",
        },
        "hac_ess": hac_ess(outcomes, int(bootstrap.get("hac_bandwidth", 0))),
        "moving_block_bootstrap": {
            "primary": primary,
            "sensitivity": sensitivity,
        },
        "supplemental_reference": {
            "line": reference,
            "status": str(bootstrap.get("reference_status")),
            "lower_bound_at_or_above_reference": primary["ci_lower"] >= reference,
            "changes_strict_qualification": False,
        },
        "outcomes": outcomes,
    }


def _autocorrelation_candidate(values: Sequence[float], max_lag: int) -> dict[str, Any]:
    if len(values) < 3:
        raise BoundEvaluationError("IS autocorrelation series needs at least three days")
    threshold = 1.96 / math.sqrt(len(values))
    rhos = autocorrelations(values, max_lag)
    significant = [index for index, rho in enumerate(rhos, start=1) if abs(rho) >= threshold]
    candidate = max(significant) if significant else 1
    return {
        "N": len(values),
        "threshold": threshold,
        "max_lag_evaluated": len(rhos),
        "rho": rhos,
        "significant_lags": significant,
        "candidate_days": candidate,
    }


def _is_daily_series(days: Sequence[DayComponent]) -> tuple[list[float], list[float], list[str]]:
    """Expose the same joint day operands used by the eventual evaluation.

    The caller must construct ``days`` exclusively from separately truncated IS
    streams.  This prevents a convenient close-day proxy (or holdout-derived
    lifetime information) from silently choosing the dependence contract.
    """

    if not days or not any(row.opened_positions for row in days):
        raise BoundEvaluationError("prepare-config: no IS trades in pinned window")
    return (
        [row.realized_pnl for row in days],
        [row.pessimistic_low_from_midnight for row in days],
        [row.day.isoformat() for row in days],
    )


def _contains_mutable_state_reference(value: Any) -> bool:
    forbidden = ("database", "farm_state", "sqlite")
    if isinstance(value, Mapping):
        return any(
            any(token in str(key).casefold() for token in forbidden)
            or _contains_mutable_state_reference(item)
            for key, item in value.items()
        )
    if isinstance(value, list):
        return any(_contains_mutable_state_reference(item) for item in value)
    if isinstance(value, str):
        folded = value.casefold()
        return "farm_state.sqlite" in folded or folded.endswith((".sqlite", ".sqlite3", ".db"))
    return False


def _validate_frozen_dependence_rule(rule: Any, label: str) -> int:
    if not isinstance(rule, Mapping):
        raise BoundEvaluationError(f"{label}: IS freeze rule missing")
    n = _positive_int(rule.get("N"), f"{label}.N")
    threshold = _positive(rule.get("threshold"), f"{label}.threshold")
    expected_threshold = 1.96 / math.sqrt(n)
    if abs(threshold - expected_threshold) > 1e-12:
        raise BoundEvaluationError(f"{label}: significance threshold mismatch")
    rhos = rule.get("rho")
    if not isinstance(rhos, list):
        raise BoundEvaluationError(f"{label}: rho series missing")
    finite_rhos = [_finite(value, f"{label}.rho") for value in rhos]
    if any(abs(value) > 1.0 + 1e-12 for value in finite_rhos):
        raise BoundEvaluationError(f"{label}: invalid autocorrelation")
    if rule.get("max_lag_evaluated") != len(finite_rhos):
        raise BoundEvaluationError(f"{label}: evaluated-lag count mismatch")
    significant = [index for index, rho in enumerate(finite_rhos, start=1) if abs(rho) >= threshold]
    if rule.get("significant_lags") != significant:
        raise BoundEvaluationError(f"{label}: significant-lag list mismatch")
    candidate = max(significant) if significant else 1
    if rule.get("candidate_days") != candidate:
        raise BoundEvaluationError(f"{label}: candidate length mismatch")
    return candidate


def validate_config(config: Mapping[str, Any]) -> None:
    if config.get("schema_version") != CONFIG_SCHEMA:
        raise BoundEvaluationError("config schema mismatch")
    claim = config.get("claim")
    if not isinstance(claim, Mapping):
        raise BoundEvaluationError("config claim missing")
    exact_claim = {
        "label": CLAIM_LABEL,
        "trace_label": TRACE_LABEL,
        "n_trials": TRIAL_LEDGER,
        "strict_qualification": STRICT_QUALIFICATION,
        "paid_challenge": PAID_CHALLENGE,
        "selection_sealed": False,
    }
    for key, expected in exact_claim.items():
        if claim.get(key) != expected:
            raise BoundEvaluationError(f"config claim mismatch: {key}")
    if config.get("cost_contract") != COST_LABEL:
        raise BoundEvaluationError("config cost contract label mismatch")
    rules = config.get("rules")
    if not isinstance(rules, Mapping):
        raise BoundEvaluationError("config rules missing")
    for key, expected in DEFAULT_RULES.items():
        if rules.get(key) != expected:
            raise BoundEvaluationError(f"config rule mismatch: {key}")
    scenarios = config.get("scenarios")
    if scenarios != DEFAULT_SCENARIOS:
        raise BoundEvaluationError("config scenarios must be the exact no-search pair")
    windows = config.get("windows")
    if not isinstance(windows, Mapping):
        raise BoundEvaluationError("config windows missing")
    is_start = parse_utc(windows.get("is_start_utc"), "windows.is_start_utc")
    is_end = parse_utc(windows.get("is_end_utc"), "windows.is_end_utc")
    evaluation_start = parse_utc(
        windows.get("evaluation_start_utc"), "windows.evaluation_start_utc"
    )
    evaluation_end = parse_utc(
        windows.get("evaluation_end_utc"), "windows.evaluation_end_utc"
    )
    if not is_start < is_end < evaluation_start <= evaluation_end:
        raise BoundEvaluationError("config IS/evaluation window ordering invalid")
    start_local = evaluation_start.astimezone(PRAGUE)
    if start_local.date() != HISTORICAL_START_DAY or start_local.time() != dt.time.min:
        raise BoundEvaluationError(
            "historical evaluation must start at Prague midnight on 2022-09-16"
        )
    if evaluation_end.astimezone(PRAGUE).date() != HISTORICAL_END_DAY:
        raise BoundEvaluationError("historical evaluation must end on Prague day 2025-12-30")
    if is_end.astimezone(PRAGUE).date() >= HISTORICAL_START_DAY:
        raise BoundEvaluationError("IS bytes must end before the historical evaluation day")
    inputs = config.get("inputs")
    if not isinstance(inputs, Mapping) or _contains_mutable_state_reference(inputs):
        raise BoundEvaluationError("config inputs may not include mutable database state")
    streams = inputs.get("streams")
    _validate_historical_stream_contract(streams)
    _validate_is_stream_contract(inputs.get("is_streams"))
    _validate_cost_binding(inputs.get("cost_snapshot"))
    bootstrap = config.get("bootstrap")
    if not isinstance(bootstrap, Mapping):
        raise BoundEvaluationError("config bootstrap contract missing")
    for key in (
        "replicates", "seed", "alpha", "minimum_block_days", "target_days",
        "sensitivity_days", "hac_bandwidth", "is_freeze",
    ):
        if key not in bootstrap:
            raise BoundEvaluationError(f"config bootstrap field missing: {key}")
    replicates = _positive_int(bootstrap.get("replicates"), "bootstrap.replicates")
    if replicates < 100:
        raise BoundEvaluationError("bootstrap.replicates must be at least 100")
    if isinstance(bootstrap.get("seed"), bool) or not isinstance(bootstrap.get("seed"), int):
        raise BoundEvaluationError("bootstrap.seed must be an integer")
    alpha = _finite(bootstrap.get("alpha"), "bootstrap.alpha")
    if not 0.0 < alpha < 1.0:
        raise BoundEvaluationError("bootstrap.alpha must be between zero and one")
    minimum = _positive_int(bootstrap.get("minimum_block_days"), "minimum_block_days")
    target = _positive_int(bootstrap.get("target_days"), "target_days")
    max_lag = _positive_int(bootstrap.get("max_lag_days"), "max_lag_days")
    if target < minimum:
        raise BoundEvaluationError("bootstrap target is below its frozen minimum")
    sensitivity = bootstrap.get("sensitivity_days")
    if sensitivity != sorted({max(1, target // 2), target * 2}):
        raise BoundEvaluationError("bootstrap sensitivity must be frozen half/double lengths")
    freeze = bootstrap.get("is_freeze")
    if not isinstance(freeze, Mapping) or freeze.get("holdout_metrics_read") is not False:
        raise BoundEvaluationError("bootstrap IS freeze must attest no holdout metric read")
    if parse_utc(freeze.get("window_start_utc"), "is_freeze.window_start") != is_start:
        raise BoundEvaluationError("IS freeze start does not match config window")
    if parse_utc(freeze.get("window_end_utc"), "is_freeze.window_end") != is_end:
        raise BoundEvaluationError("IS freeze end does not match config window")
    realized_candidate = _validate_frozen_dependence_rule(
        freeze.get("realized_pnl_rule"), "is_freeze.realized_pnl_rule"
    )
    pessimistic_candidate = _validate_frozen_dependence_rule(
        freeze.get("pessimistic_low_rule"), "is_freeze.pessimistic_low_rule"
    )
    if target != max(minimum, realized_candidate, pessimistic_candidate):
        raise BoundEvaluationError("bootstrap target does not match frozen IS rules")
    if bootstrap.get("hac_bandwidth") != max(realized_candidate, pessimistic_candidate):
        raise BoundEvaluationError("HAC bandwidth does not match frozen IS rules")
    first_is_day = is_start.astimezone(PRAGUE).date()
    last_is_day = is_end.astimezone(PRAGUE).date()
    expected_is_days = (last_is_day - first_is_day).days + 1
    if (
        freeze.get("calendar_day_count") != expected_is_days
        or freeze.get("first_prague_day") != first_is_day.isoformat()
        or freeze.get("last_prague_day") != last_is_day.isoformat()
    ):
        raise BoundEvaluationError("IS freeze calendar coverage mismatch")
    for label in ("realized_pnl_rule", "pessimistic_low_rule"):
        rule = freeze[label]
        if rule.get("N") != expected_is_days:
            raise BoundEvaluationError(f"IS freeze sample-size mismatch: {label}")
        expected_lags = min(max_lag, int(rule["N"]) - 1)
        if rule.get("max_lag_evaluated") != expected_lags:
            raise BoundEvaluationError(f"IS freeze max-lag mismatch: {label}")
    for key in (
        "is_autocorrelation_rule", "isolated_significant_lag", "tie_rule",
        "bootstrap_path_length", "reference_lower_bound", "reference_status",
    ):
        if bootstrap.get(key) != DEFAULT_BOOTSTRAP[key]:
            raise BoundEvaluationError(f"bootstrap fixed contract mismatch: {key}")
    parse_utc(config.get("prepared_at_utc"), "prepared_at_utc")


def prepare_config(spec: Mapping[str, Any]) -> dict[str, Any]:
    """Pin artifacts and freeze the dependence rule using IS rows only."""

    if not isinstance(spec, Mapping):
        raise BoundEvaluationError("prepare spec must be an object")
    windows = copy.deepcopy(spec.get("windows"))
    if not isinstance(windows, dict):
        raise BoundEvaluationError("prepare spec windows missing")
    is_start = parse_utc(windows.get("is_start_utc"), "windows.is_start_utc")
    is_end = parse_utc(windows.get("is_end_utc"), "windows.is_end_utc")
    evaluation_start = parse_utc(
        windows.get("evaluation_start_utc"), "windows.evaluation_start_utc"
    )
    evaluation_end = parse_utc(
        windows.get("evaluation_end_utc"), "windows.evaluation_end_utc"
    )
    if not is_start < is_end < evaluation_start <= evaluation_end:
        raise BoundEvaluationError("prepare spec window ordering invalid")
    inputs = spec.get("inputs")
    if not isinstance(inputs, Mapping) or _contains_mutable_state_reference(inputs):
        raise BoundEvaluationError("prepare spec inputs missing")
    stream_specs = inputs.get("streams")
    if not isinstance(stream_specs, list) or len(stream_specs) != 3:
        raise BoundEvaluationError("prepare spec requires three streams")
    pinned_streams = []
    for index, stream in enumerate(stream_specs):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError("prepare stream binding must be an object")
        pinned = pin_binding(stream, f"stream[{index}]")
        lineage = stream.get("lineage", [])
        if not isinstance(lineage, list):
            raise BoundEvaluationError("prepare lineage must be a list")
        pinned_lineage = []
        for lineage_index, item in enumerate(lineage):
            if not isinstance(item, Mapping):
                raise BoundEvaluationError("prepare lineage binding must be an object")
            pinned_lineage.append(
                pin_binding(item, f"stream[{index}].lineage[{lineage_index}]")
            )
        pinned["lineage"] = pinned_lineage
        pinned_streams.append(pinned)
    _validate_historical_stream_contract(pinned_streams)

    is_stream_specs = inputs.get("is_streams")
    if not isinstance(is_stream_specs, list) or len(is_stream_specs) != 3:
        raise BoundEvaluationError("prepare spec requires three separately truncated IS streams")
    pinned_is_streams = []
    for index, stream in enumerate(is_stream_specs):
        if not isinstance(stream, Mapping):
            raise BoundEvaluationError("prepare IS stream binding must be an object")
        pinned_is_streams.append(pin_binding(stream, f"is_stream[{index}]"))
    _validate_is_stream_contract(pinned_is_streams)

    cost_spec = inputs.get("cost_snapshot")
    if not isinstance(cost_spec, Mapping):
        raise BoundEvaluationError("prepare cost snapshot missing")
    pinned_cost = pin_binding(cost_spec, "cost_snapshot")
    _validate_cost_binding(pinned_cost)
    prepared_inputs = {
        "streams": pinned_streams,
        "is_streams": pinned_is_streams,
        "cost_snapshot": pinned_cost,
    }
    provisional = {
        "schema_version": CONFIG_SCHEMA,
        "claim": {
            "label": CLAIM_LABEL,
            "trace_label": TRACE_LABEL,
            "n_trials": TRIAL_LEDGER,
            "strict_qualification": STRICT_QUALIFICATION,
            "paid_challenge": PAID_CHALLENGE,
            "selection_sealed": False,
            "prospective_route": "OWNER_AUTHORIZED_EXACT_PROFILE_TRIAL_OR_SHADOW_BYTES_POST_SEAL",
        },
        "cost_contract": COST_LABEL,
        "windows": windows,
        "inputs": prepared_inputs,
        "rules": copy.deepcopy(DEFAULT_RULES),
        "scenarios": copy.deepcopy(DEFAULT_SCENARIOS),
    }
    # Only separately truncated IS rows are parsed here.  The historical stream
    # bytes above are identity-pinned but their holdout metrics are not opened.
    loaded_is = [
        load_raw_stream(binding, index) for index, binding in enumerate(pinned_is_streams)
    ]
    for trades, coverage in loaded_is:
        if any(row.entry_utc < is_start or row.close_utc > is_end for row in trades):
            raise BoundEvaluationError(
                f"prepare-config: IS stream contains out-of-window row: {coverage['sleeve_id']}"
            )
    costs = load_cost_snapshot(pinned_cost)
    repriced_is = [
        reprice_trade(trade, costs[trade.symbol])
        for trades, _coverage in loaded_is
        for trade in trades
    ]
    is_components = build_daily_components(repriced_is, is_start, is_end)
    realized, pessimistic, is_days = _is_daily_series(is_components)
    requested = copy.deepcopy(DEFAULT_BOOTSTRAP)
    overrides = spec.get("bootstrap", {})
    if not isinstance(overrides, Mapping):
        raise BoundEvaluationError("prepare bootstrap overrides must be an object")
    for key in ("replicates", "seed", "alpha", "minimum_block_days", "max_lag_days"):
        if key in overrides:
            requested[key] = overrides[key]
    replicates = _positive_int(requested["replicates"], "bootstrap.replicates")
    seed = int(requested["seed"])
    alpha = _finite(requested["alpha"], "bootstrap.alpha")
    minimum = _positive_int(requested["minimum_block_days"], "minimum_block_days")
    max_lag = _positive_int(requested["max_lag_days"], "max_lag_days")
    realized_rule = _autocorrelation_candidate(realized, max_lag)
    pessimistic_rule = _autocorrelation_candidate(pessimistic, max_lag)
    target = max(minimum, realized_rule["candidate_days"], pessimistic_rule["candidate_days"])
    sensitivity = sorted({max(1, target // 2), target * 2})
    hac_bandwidth = max(realized_rule["candidate_days"], pessimistic_rule["candidate_days"])
    provisional["bootstrap"] = {
        **requested,
        "replicates": replicates,
        "seed": seed,
        "alpha": alpha,
        "minimum_block_days": minimum,
        "max_lag_days": max_lag,
        "target_days": target,
        "sensitivity_days": sensitivity,
        "hac_bandwidth": hac_bandwidth,
        "is_freeze": {
            "window_start_utc": utc_z(is_start),
            "window_end_utc": utc_z(is_end),
            "calendar_day_count": len(is_days),
            "first_prague_day": is_days[0],
            "last_prague_day": is_days[-1],
            "realized_pnl_rule": realized_rule,
            "pessimistic_low_rule": pessimistic_rule,
            "holdout_metrics_read": False,
        },
    }
    provisional["prepared_at_utc"] = str(
        spec.get("prepared_at_utc")
        or dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    )
    validate_config(provisional)
    return provisional


def evaluate_bound(config: Mapping[str, Any], config_sha256: str) -> dict[str, Any]:
    validate_config(config)
    verify_all_inputs(config)
    costs = load_cost_snapshot(config["inputs"]["cost_snapshot"])
    loaded = [
        load_raw_stream(binding, index)
        for index, binding in enumerate(config["inputs"]["streams"])
    ]
    loaded_is = [
        load_raw_stream(binding, index)
        for index, binding in enumerate(config["inputs"]["is_streams"])
    ]
    is_start = parse_utc(config["windows"]["is_start_utc"], "is_start_utc")
    is_end = parse_utc(config["windows"]["is_end_utc"], "is_end_utc")
    is_derivation = verify_is_derivation(loaded, loaded_is, is_start, is_end)
    evaluation_start = parse_utc(
        config["windows"]["evaluation_start_utc"], "evaluation_start_utc"
    )
    evaluation_end = parse_utc(
        config["windows"]["evaluation_end_utc"], "evaluation_end_utc"
    )
    for _trades, coverage in loaded:
        if parse_utc(coverage["first_entry_utc"], "coverage.first") > evaluation_start:
            raise BoundEvaluationError(
                f"window starts before stream coverage: {coverage['sleeve_id']}"
            )
        if parse_utc(coverage["last_close_utc"], "coverage.last") < evaluation_end:
            raise BoundEvaluationError(
                f"window ends after stream coverage: {coverage['sleeve_id']}"
            )
    repriced = [
        reprice_trade(trade, costs[trade.symbol])
        for trades, _coverage in loaded
        for trade in trades
    ]
    days = build_daily_components(repriced, evaluation_start, evaluation_end)
    if not days:
        raise BoundEvaluationError("evaluation produced no Prague days")
    scenario_rows = [
        summarize_scenario(days, scenario, config["rules"], config["bootstrap"])
        for scenario in config["scenarios"]
    ]
    cost_reconciliation = {
        "source_commission_removed": sum(row.source_commission_removed for row in repriced),
        "source_swap_removed": sum(row.source_swap_removed for row in repriced),
        "target_commission_inserted": sum(row.target_commission for row in repriced),
        "target_swap_inserted": sum(row.target_swap for row in repriced),
        "realized_formula": "profit + source_fee + target_commission + target_swap",
        "mae_formula": "source_mae_acct + target_entry_commission + min(0,target_lifetime_swap)",
        "source_close_cost_cap_retained_when_unidentifiable": True,
    }
    return {
        "schema_version": RESULT_SCHEMA,
        "config_sha256": config_sha256,
        "claim": copy.deepcopy(config["claim"]),
        "cost_contract": COST_LABEL,
        "window": {
            "start_utc": utc_z(evaluation_start),
            "end_utc": utc_z(evaluation_end),
            "prague_days": len(days),
        },
        "stream_coverage": [coverage for _trades, coverage in loaded],
        "is_derivation_verification": {
            "status": "PASS",
            "rule": "EXACT_FULL_STREAM_SUBSET_ENTRY_AND_CLOSE_WITHIN_IS_WINDOW",
            "rows_by_sleeve": is_derivation,
        },
        "cost_reconciliation": cost_reconciliation,
        "margin_diagnostic": {
            "profile": "Swing",
            "peak_base_margin": max(row.peak_margin for row in days),
            "used_as_pass_criterion": False,
            "required_operands": [
                "side", "equivalent_target_volume", "entry_price", "contract_size",
                "margin_calculation", "margin_currency_to_account_rate", "leverageSwing",
            ],
        },
        "scenarios": scenario_rows,
        "final_status": {
            "strict_qualification": STRICT_QUALIFICATION,
            "paid_challenge": PAID_CHALLENGE,
            "selection_sealed_blocker_open": True,
            "exact_event_trace_blocker_open": True,
        },
        "purity": {
            "verdict_inputs": "CONFIG_JSON_AND_HASH_BOUND_ARTIFACTS_ONLY",
            "live_database_read": False,
            "factory_or_live_mutation": False,
        },
    }


def evaluate_config_file(config_path: Path, expected_sha256: str) -> dict[str, Any]:
    expected = _normalized_sha(expected_sha256, "expected_config_sha256")
    actual = sha256_file(config_path)
    if actual != expected:
        raise BoundEvaluationError(
            f"config SHA-256 mismatch before stream access: expected={expected} actual={actual}"
        )
    config = load_json(config_path, "config")
    if not isinstance(config, dict):
        raise BoundEvaluationError("config root must be an object")
    return evaluate_bound(config, actual)


def write_json_atomic(path: Path, value: Any) -> str:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(
        value,
        indent=2,
        sort_keys=True,
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8") + b"\n"
    temp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temp.open("xb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        try:
            temp.unlink()
        except FileNotFoundError:
            pass
    return hashlib.sha256(raw).hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare-config")
    prepare.add_argument("--spec", type=Path, required=True)
    prepare.add_argument("--output", type=Path, required=True)
    evaluate = sub.add_parser("evaluate")
    evaluate.add_argument("--config", type=Path, required=True)
    evaluate.add_argument("--expected-config-sha256", required=True)
    evaluate.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "prepare-config":
        spec = load_json(args.spec.resolve(), "prepare_spec")
        config = prepare_config(spec)
        digest = write_json_atomic(args.output, config)
        print(json.dumps({"status": "PREPARED", "path": str(args.output.resolve()), "sha256": digest}))
        return 0
    result = evaluate_config_file(args.config.resolve(), args.expected_config_sha256)
    digest = write_json_atomic(args.output, result)
    print(json.dumps({"status": "DIAGNOSTIC_WRITTEN", "path": str(args.output.resolve()), "sha256": digest}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
