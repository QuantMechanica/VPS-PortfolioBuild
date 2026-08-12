#!/usr/bin/env python3
"""Read-only two-run reproducibility gate for TARGET_BINARY_REQUAL.

The gate never starts MT5 and never mutates either source run.  It verifies two
schema-v2 FULL summaries through caller-provided file hashes and immutable
sidecars, checks that their qualification contracts are identical, and then
compares explicit per-sleeve identity axes.  Missing axes fail closed.

The current runner emits explicit trade, signal, lot, outcome-sign and
exact-PnL sequence descriptors.  Its telemetry does not yet certify entry
side/price, exit reason, daily/intraday mark-to-market or margin sequences.
Receipts close those gaps with this contract::

    "reproducibility_identity": {
      "schema_version": 1,
      "trades":  {"complete": true, "count": 4, "sha256": "..."},
      "signals": {"complete": true, "count": 4, "sha256": "..."},
      "entries": {"complete": true, "count": 4, "sha256": "..."},
      "exits":   {"complete": true, "count": 4, "sha256": "..."},
      "lots":    {"complete": true, "count": 4, "sha256": "..."},
      "outcome_signs": {"complete": true, "count": 4, "sha256": "..."},
      "pnl":     {"complete": true, "count": 4, "sha256": "..."},
      "daily_mtm": {"complete": true, "count": 40, "sha256": "..."},
      "mtm":     {"complete": true, "count": 100, "sha256": "..."},
      "margin":  {"complete": true, "count": 100, "sha256": "..."}
    }

Every SHA-256 above is the canonical hash of the ordered sequence represented
by that axis.  ``complete`` means no event/observation was omitted.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping, Sequence


ARTIFACT_TYPE = "DXZ_TARGET_BINARY_REQUAL_REPRODUCIBILITY_PAIR"
QUALIFICATION_MODE = "TARGET_BINARY_REQUAL"
TARGET_ARTIFACT_SOURCE = "SHA_BOUND_TARGET_BINARY_OVERRIDE"
SINGLE_RUN_QUALIFICATION_STATUS = "REPRODUCIBILITY_PENDING"
SCHEMA_VERSION = 1
INPUT_SCHEMA_VERSION = 2
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
VARIANT_ID_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
PROMOTION_SYMBOL_RE = re.compile(r"^[A-Z][A-Z0-9]{1,15}\.DWX$")
TF_RE = re.compile(r"^(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)$")
SIDECAR_RE = re.compile(r"^([0-9a-fA-F]{64})(?:\s+\*?(.+?))?$")
FORBIDDEN_SANDBOX_PART_RE = re.compile(
    r"^(?:T_Live|T(?:10|[1-9]))$", re.IGNORECASE
)
REQUIRED_COST_AXES = (
    "commission",
    "historical_tester_spread",
    "current_broker_spread_parity",
    "current_broker_swap_rate_parity",
    "slippage_stress",
)
REQUIRED_IDENTITY_AXES = (
    "trades",
    "signals",
    "entries",
    "exits",
    "lots",
    "outcome_signs",
    "pnl",
    "daily_mtm",
    "mtm",
    "margin",
)
VARIANT_UNSPECIFIED = "VARIANT_UNSPECIFIED"
SleeveKey = tuple[int, str, str, str]
AXIS_ALIASES = {
    "trades": ("trades", "trade", "trade_sequence", "trade_identity"),
    "signals": ("signals", "signal", "signal_sequence", "signal_identity"),
    "entries": (
        "entries",
        "entry",
        "entry_sequence",
        "entry_identity",
    ),
    "exits": (
        "exits",
        "exit",
        "exit_sequence",
        "exit_identity",
        "exit_reason_sequence",
    ),
    "lots": ("lots", "lot", "lot_sequence", "lot_identity", "lot_size_sequence"),
    "outcome_signs": (
        "outcome_signs",
        "outcome_sign",
        "outcome_sign_sequence",
    ),
    "pnl": ("pnl", "pnl_sequence", "pnl_identity", "profit_loss"),
    "daily_mtm": (
        "daily_mtm",
        "daily_mtm_sequence",
        "daily_mark_to_market",
    ),
    "mtm": (
        "mtm",
        "mtm_sequence",
        "mtm_identity",
        "mark_to_market",
        "mark_to_market_sequence",
    ),
    "margin": (
        "margin",
        "margin_sequence",
        "used_free_stressed_margin_sequence",
    ),
}


def canonical_json_sha(payload: Any) -> str:
    encoded = json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def embedded_hash(payload: Mapping[str, Any], field: str) -> str:
    unsigned = dict(payload)
    unsigned.pop(field, None)
    return canonical_json_sha(unsigned)


def _valid_sha(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value.lower()) is not None


def _path_id(path: Path) -> str:
    try:
        resolved = path.resolve(strict=False)
    except OSError:
        resolved = path.absolute()
    return str(resolved).replace("/", "\\").rstrip("\\").casefold()


def _paths_overlap(left: Path, right: Path) -> bool:
    left_id = _path_id(left)
    right_id = _path_id(right)
    return (
        left_id == right_id
        or left_id.startswith(right_id + "\\")
        or right_id.startswith(left_id + "\\")
    )


def _is_forbidden_sandbox(path: Path) -> bool:
    try:
        parts = path.resolve(strict=False).parts
    except OSError:
        parts = path.absolute().parts
    return any(FORBIDDEN_SANDBOX_PART_RE.fullmatch(part) for part in parts)


def _load_json_object(path: Path) -> dict[str, Any]:
    payload = _strict_json_value(
        path.read_text(encoding="utf-8-sig", errors="strict")
    )
    if not isinstance(payload, dict):
        raise ValueError("JSON root is not an object")
    return payload


def _read_sidecar(sidecar: Path, source: Path) -> tuple[str | None, list[str]]:
    issues: list[str] = []
    try:
        lines = [line.strip() for line in sidecar.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    except (OSError, UnicodeError):
        return None, ["SIDECAR_MISSING_OR_UNREADABLE"]
    if len(lines) != 1:
        return None, ["SIDECAR_MUST_CONTAIN_EXACTLY_ONE_BINDING"]
    match = SIDECAR_RE.fullmatch(lines[0])
    if match is None:
        return None, ["SIDECAR_BINDING_INVALID"]
    declared = match.group(1).lower()
    declared_name = match.group(2)
    if declared_name and Path(declared_name.strip()).name.casefold() != source.name.casefold():
        issues.append("SIDECAR_FILENAME_MISMATCH")
    return declared, issues


def load_summary_binding(
    label: str,
    path: Path,
    expected_file_sha256: str,
    sidecar: Path | None = None,
) -> tuple[dict[str, Any], dict[str, Any] | None, list[str]]:
    """Load one summary without changing it and verify all outer bindings."""

    prefix = f"SUMMARY_{label.upper()}"
    resolved = path.resolve()
    sidecar_path = (sidecar or path.with_name(path.name + ".sha256")).resolve()
    issues: list[str] = []
    expected = expected_file_sha256.lower()
    actual: str | None = None
    sidecar_declared: str | None = None
    sidecar_file_sha: str | None = None
    payload: dict[str, Any] | None = None
    payload_sha: str | None = None
    declared_payload_sha: Any = None

    if _is_forbidden_sandbox(resolved):
        issues.append(f"{prefix}_PATH_BELOW_TIER_OR_LIVE_ROOT")
    if not _valid_sha(expected):
        issues.append(f"{prefix}_EXPECTED_FILE_SHA256_INVALID")
    if not resolved.is_file():
        issues.append(f"{prefix}_FILE_MISSING")
    else:
        actual = sha256_file(resolved)
        if _valid_sha(expected) and actual != expected:
            issues.append(f"{prefix}_FILE_SHA256_MISMATCH")
        try:
            payload = _load_json_object(resolved)
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
            issues.append(f"{prefix}_JSON_INVALID")
        if payload is not None:
            declared_payload_sha = payload.get("summary_sha256")
            payload_sha = embedded_hash(payload, "summary_sha256")
            if not _valid_sha(declared_payload_sha):
                issues.append(f"{prefix}_PAYLOAD_SHA256_MISSING_OR_INVALID")
            elif str(declared_payload_sha).lower() != payload_sha:
                issues.append(f"{prefix}_PAYLOAD_SHA256_MISMATCH")

    sidecar_declared, sidecar_issues = _read_sidecar(sidecar_path, resolved)
    issues.extend(f"{prefix}_{issue}" for issue in sidecar_issues)
    if sidecar_path.is_file():
        sidecar_file_sha = sha256_file(sidecar_path)
    if sidecar_declared is not None and actual is not None and sidecar_declared != actual:
        issues.append(f"{prefix}_SIDECAR_FILE_SHA256_MISMATCH")
    if sidecar_declared is not None and _valid_sha(expected) and sidecar_declared != expected:
        issues.append(f"{prefix}_SIDECAR_EXPECTED_SHA256_MISMATCH")

    binding = {
        "path": str(resolved),
        "file_sha256": actual,
        "payload_sha256": payload_sha,
        "declared_payload_sha256": (
            str(declared_payload_sha).lower() if _valid_sha(declared_payload_sha) else None
        ),
        "run_id": payload.get("run_id") if payload else None,
        "sidecar_path": str(sidecar_path),
        "sidecar_file_sha256": sidecar_file_sha,
        "sidecar_declared_sha256": sidecar_declared,
    }
    return binding, payload, sorted(set(issues))


def _normalized_variant(job: Mapping[str, Any]) -> str | None:
    if "variant_id" not in job:
        return None
    raw = job.get("variant_id")
    if not isinstance(raw, str) or not VARIANT_ID_RE.fullmatch(raw):
        return None
    return raw


def _sleeve_key(receipt: Mapping[str, Any]) -> SleeveKey | None:
    job = receipt.get("job")
    if not isinstance(job, Mapping):
        return None
    ea_id = job.get("ea_id")
    symbol = job.get("symbol")
    timeframe = job.get("timeframe")
    variant_id = _normalized_variant(job)
    if (
        type(ea_id) is not int
        or ea_id <= 0
        or not isinstance(symbol, str)
        or not symbol
        or symbol != symbol.strip()
        or symbol != symbol.upper()
        or PROMOTION_SYMBOL_RE.fullmatch(symbol) is None
        or not isinstance(timeframe, str)
        or not timeframe
        or timeframe != timeframe.strip()
        or timeframe != timeframe.upper()
        or TF_RE.fullmatch(timeframe) is None
        or variant_id is None
    ):
        return None
    return ea_id, symbol, timeframe, variant_id


def _key_text(key: SleeveKey) -> str:
    return f"{key[0]}:{key[1]}:{key[2]}:{key[3]}"


def _normalized_job_contract(receipt: Mapping[str, Any]) -> dict[str, Any] | None:
    job = receipt.get("job")
    if not isinstance(job, Mapping):
        return None
    variant_id = _normalized_variant(job)
    if variant_id is None:
        return None
    normalized = dict(job)
    normalized["variant_id"] = variant_id
    return normalized


def _cost_issues(prefix: str, payload: Mapping[str, Any]) -> list[str]:
    issues: list[str] = []
    if payload.get("cost_certified") is not True:
        issues.append(f"{prefix}_COST_NOT_CERTIFIED")
    evidence = payload.get("cost_evidence")
    if not isinstance(evidence, Mapping):
        return issues + [f"{prefix}_COST_EVIDENCE_MISSING"]
    if evidence.get("status") != "CERTIFIED":
        issues.append(f"{prefix}_COST_STATUS_NOT_CERTIFIED")
    if evidence.get("cost_certified") is not True:
        issues.append(f"{prefix}_COST_EVIDENCE_FLAG_FALSE")
    axes = evidence.get("axes")
    if not isinstance(axes, Mapping) or set(axes) != set(REQUIRED_COST_AXES):
        issues.append(f"{prefix}_COST_AXES_INCOMPLETE")
        return issues
    for axis in REQUIRED_COST_AXES:
        row = axes.get(axis)
        if not isinstance(row, Mapping) or row.get("status") != "PASS":
            issues.append(f"{prefix}_COST_AXIS_NOT_PASS:{axis}")
    return issues


def _manifest_sleeve_identity(raw: Any) -> SleeveKey | None:
    """Return a manifest identity only when every raw field is canonical."""

    if not isinstance(raw, Mapping):
        return None
    ea_id = raw.get("ea_id")
    symbol = raw.get("symbol")
    variant_id = raw.get("variant_id")
    timeframes = [
        raw.get(field)
        for field in ("timeframe", "host_timeframe")
        if raw.get(field) is not None
    ]
    if (
        type(ea_id) is not int
        or ea_id <= 0
        or not isinstance(symbol, str)
        or not symbol
        or symbol != symbol.strip()
        or symbol != symbol.upper()
        or PROMOTION_SYMBOL_RE.fullmatch(symbol) is None
        or not timeframes
        or any(
            not isinstance(value, str)
            or not value
            or value != value.strip()
            or value != value.upper()
            or TF_RE.fullmatch(value) is None
            for value in timeframes
        )
        or len(set(timeframes)) != 1
        or not isinstance(variant_id, str)
        or VARIANT_ID_RE.fullmatch(variant_id) is None
    ):
        return None
    return ea_id, symbol, timeframes[0], variant_id


def _expected_magic_manifest_issues(
    prefix: str,
    key: SleeveKey,
    job: Mapping[str, Any],
    source: Mapping[str, Any],
    summary_manifest_sha256: Any,
) -> list[str]:
    """Open the declared source manifest and verify its designated sleeve."""

    issues: list[str] = []
    raw_path = source.get("manifest_path")
    manifest_path: Path | None = None
    if not isinstance(raw_path, str) or not raw_path.strip():
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_PATH_MISSING")
    elif not Path(raw_path).is_absolute():
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_PATH_NOT_ABSOLUTE")
    else:
        try:
            manifest_path = Path(raw_path).resolve(strict=True)
        except (OSError, RuntimeError):
            issues.append(
                f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_MISSING_OR_UNREADABLE"
            )
    if manifest_path is None or not manifest_path.is_file():
        return issues

    try:
        actual_sha256 = sha256_file(manifest_path)
    except OSError:
        return issues + [
            f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_MISSING_OR_UNREADABLE"
        ]
    if (
        actual_sha256 != source.get("manifest_sha256")
        or actual_sha256 != summary_manifest_sha256
    ):
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_FILE_SHA256_MISMATCH")
        return issues
    try:
        manifest = _strict_json_value(
            manifest_path.read_text(encoding="utf-8-sig", errors="strict")
        )
        if not isinstance(manifest, dict):
            raise ValueError("manifest root is not an object")
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
        return issues + [f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_JSON_INVALID"]
    sleeves = manifest.get("sleeves")
    if not isinstance(sleeves, list):
        return issues + [f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_SLEEVES_INVALID"]

    ordinal = source.get("sleeve_ordinal")
    if type(ordinal) is not int or ordinal < 1 or ordinal > len(sleeves):
        return issues + [
            f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_ORDINAL_OUT_OF_RANGE"
        ]

    selected = sleeves[ordinal - 1]
    if _manifest_sleeve_identity(selected) != key:
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_SLEEVE_IDENTITY_MISMATCH")
    expected_magic = job.get("expected_magic")
    if (
        not isinstance(selected, Mapping)
        or type(selected.get("magic_number")) is not int
        or selected.get("magic_number") != expected_magic
    ):
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_SLEEVE_MAGIC_MISMATCH")
    if sum(_manifest_sleeve_identity(row) == key for row in sleeves) != 1:
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_SLEEVE_NOT_UNIQUE")
    return issues


def _validate_receipt(
    label: str,
    key: SleeveKey,
    receipt: Mapping[str, Any],
    summary_manifest_sha256: Any,
    summary_runner_sha256: Any,
) -> list[str]:
    prefix = f"SUMMARY_{label}_RECEIPT:{_key_text(key)}"
    issues: list[str] = []
    if receipt.get("schema_version") != INPUT_SCHEMA_VERSION:
        issues.append(f"{prefix}:SCHEMA_VERSION_NOT_2")
    if receipt.get("qualification_mode") != QUALIFICATION_MODE:
        issues.append(f"{prefix}:QUALIFICATION_MODE_INVALID")
    if receipt.get("qualification_status") != SINGLE_RUN_QUALIFICATION_STATUS:
        issues.append(
            f"{prefix}:QUALIFICATION_STATUS_NOT_REPRODUCIBILITY_PENDING"
        )
    if receipt.get("status") != "PASS":
        issues.append(f"{prefix}:STATUS_NOT_PASS")
    if receipt.get("technical_status") != "PASS":
        issues.append(f"{prefix}:TECHNICAL_STATUS_NOT_PASS")
    if receipt.get("deployment_eligible") is not False:
        issues.append(f"{prefix}:DEPLOYMENT_ELIGIBLE_NOT_FALSE")
    if receipt.get("artifact_source") != TARGET_ARTIFACT_SOURCE:
        issues.append(f"{prefix}:ARTIFACT_SOURCE_NOT_TARGET_OVERRIDE")
    receipt_runner_sha256 = receipt.get("runner_sha256")
    if not _valid_sha(receipt_runner_sha256):
        issues.append(f"{prefix}:RUNNER_SHA256_MISSING_OR_INVALID")
    elif receipt_runner_sha256 != summary_runner_sha256:
        issues.append(f"{prefix}:RUNNER_SHA256_SUMMARY_BINDING_MISMATCH")
    artifact_override = receipt.get("artifact_override_manifest")
    if not isinstance(artifact_override, Mapping) or not _contract_has_hash(artifact_override):
        issues.append(f"{prefix}:ARTIFACT_OVERRIDE_MISSING_OR_UNBOUND")
    else:
        bound_rows = artifact_override.get("bound_artifacts")
        exact_matches = [
            row
            for row in (bound_rows if isinstance(bound_rows, list) else [])
            if isinstance(row, Mapping)
            and row.get("ea_id") == key[0]
            and str(row.get("symbol") or "").upper() == key[1]
            and str(row.get("timeframe") or "").upper() == key[2]
            and row.get("variant_id") == key[3]
        ]
        if len(exact_matches) != 1:
            issues.append(f"{prefix}:ARTIFACT_OVERRIDE_FOUR_PART_IDENTITY_UNBOUND")
    blockers = receipt.get("blockers")
    if not isinstance(blockers, list) or blockers:
        issues.append(f"{prefix}:BLOCKERS_PRESENT_OR_INVALID")
    card_contract = receipt.get("card_contract")
    if (
        not isinstance(card_contract, Mapping)
        or not card_contract
        or not _contract_has_hash(card_contract)
    ):
        issues.append(f"{prefix}:CARD_CONTRACT_MISSING_OR_UNBOUND")
    identity = receipt.get("identity")
    if not isinstance(identity, Mapping) or identity.get("card_contract_unchanged") is not True:
        issues.append(f"{prefix}:CARD_CONTRACT_NOT_PROVEN_UNCHANGED")
    elif (
        identity.get("card_contract") != card_contract
        or identity.get("card_contract_end") != card_contract
    ):
        issues.append(f"{prefix}:CARD_CONTRACT_RECEIPT_BINDING_MISMATCH")
    if isinstance(identity, Mapping):
        if identity.get("artifact_source") != TARGET_ARTIFACT_SOURCE:
            issues.append(f"{prefix}:IDENTITY_ARTIFACT_SOURCE_NOT_TARGET_OVERRIDE")
        if identity.get("artifact_override_manifest") != artifact_override:
            issues.append(f"{prefix}:IDENTITY_ARTIFACT_OVERRIDE_BINDING_MISMATCH")

    job = receipt.get("job")
    expected_magic = job.get("expected_magic") if isinstance(job, Mapping) else None
    if type(expected_magic) is not int or expected_magic <= 0:
        issues.append(f"{prefix}:EXPECTED_MAGIC_MISSING_OR_INVALID")
    identity_magic = (
        identity.get("expected_magic") if isinstance(identity, Mapping) else None
    )
    if type(identity_magic) is not int or identity_magic != expected_magic:
        issues.append(f"{prefix}:IDENTITY_EXPECTED_MAGIC_BINDING_MISMATCH")

    source = job.get("expected_magic_source") if isinstance(job, Mapping) else None
    identity_source = (
        identity.get("expected_magic_source")
        if isinstance(identity, Mapping)
        else None
    )
    if not isinstance(source, Mapping):
        issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_MISSING_OR_INVALID")
    else:
        if source.get("authority") != "HASH_BOUND_SOURCE_MANIFEST_SLEEVE":
            issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_AUTHORITY_INVALID")
        if source.get("field") != "magic_number":
            issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_FIELD_INVALID")
        ordinal = job.get("ordinal") if isinstance(job, Mapping) else None
        if (
            type(ordinal) is not int
            or ordinal <= 0
            or type(source.get("sleeve_ordinal")) is not int
            or source.get("sleeve_ordinal") != ordinal
        ):
            issues.append(
                f"{prefix}:EXPECTED_MAGIC_SOURCE_SLEEVE_ORDINAL_MISMATCH"
            )
        if source.get("promotion_identity") != _key_text(key):
            issues.append(
                f"{prefix}:EXPECTED_MAGIC_SOURCE_PROMOTION_IDENTITY_MISMATCH"
            )
        if (
            type(source.get("expected_magic")) is not int
            or source.get("expected_magic") != expected_magic
        ):
            issues.append(f"{prefix}:EXPECTED_MAGIC_SOURCE_VALUE_MISMATCH")
        if source.get("manifest_sha256") != summary_manifest_sha256:
            issues.append(
                f"{prefix}:EXPECTED_MAGIC_SOURCE_MANIFEST_SHA256_MISMATCH"
            )
        issues.extend(
            _expected_magic_manifest_issues(
                prefix, key, job if isinstance(job, Mapping) else {}, source,
                summary_manifest_sha256,
            )
        )
    if not isinstance(identity_source, Mapping) or identity_source != source:
        issues.append(f"{prefix}:IDENTITY_EXPECTED_MAGIC_SOURCE_BINDING_MISMATCH")
    declared = receipt.get("receipt_sha256")
    if not _valid_sha(declared):
        issues.append(f"{prefix}:RECEIPT_SHA256_MISSING_OR_INVALID")
    elif str(declared).lower() != embedded_hash(receipt, "receipt_sha256"):
        issues.append(f"{prefix}:RECEIPT_SHA256_MISMATCH")
    issues.extend(_cost_issues(prefix, receipt))
    return issues


RUNTIME_ARTIFACT_FIELDS = {
    "runtime_log": (
        "runtime_log_path",
        "runtime_log_sha256",
        "runtime_log.jsonl",
    ),
    "runtime_telemetry": (
        "runtime_telemetry_path",
        "runtime_telemetry_sha256",
        "runtime_telemetry.json",
    ),
    "runtime_log_transaction": (
        "runtime_log_transaction_path",
        "runtime_log_transaction_sha256",
        "runtime_log_transaction.json",
    ),
}


def _canonical_decimal_text(value: Any) -> str | None:
    try:
        parsed = Decimal(str(value).strip())
    except (InvalidOperation, ValueError, TypeError):
        return None
    if not parsed.is_finite():
        return None
    if parsed == 0:
        return "0"
    return format(parsed.normalize(), "f")


def _row_time(row: Mapping[str, Any]) -> int | None:
    value = row.get("time") or row.get("close_time") or row.get("ts_utc")
    if value is None:
        return None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return int(value / 1000 if value > 10_000_000_000 else value)
    text = str(value).strip().replace("Z", "+00:00")
    if text.isdigit():
        return _row_time({"time": int(text)})
    try:
        stamp = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=dt.UTC)
    return int(stamp.timestamp())


def _row_entry_time(row: Mapping[str, Any]) -> int | None:
    value = row.get("entry_time")
    return None if value is None else _row_time({"time": value})


def _strict_json_value(text: str) -> Any:
    def reject_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON constant: {value}")

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(
        text,
        parse_constant=reject_constant,
        object_pairs_hook=unique_object,
    )


def _load_strict_json_object(path: Path) -> dict[str, Any]:
    payload = _strict_json_value(
        path.read_text(encoding="utf-8-sig", errors="strict")
    )
    if not isinstance(payload, dict):
        raise ValueError("JSON root is not an object")
    return payload


def _load_q08_stream_strict(
    path: Path,
    key: SleeveKey,
    expected_magic: Any,
) -> tuple[list[dict[str, Any]], list[str]]:
    """Load the exact flat JSONL schema emitted by QM_Common.mqh."""

    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    expected_fields = {
        "event",
        "magic",
        "time",
        "entry_time",
        "mae_acct",
        "net",
        "profit",
        "swap",
        "commission",
        "volume",
        "notional",
        "symbol",
    }
    try:
        lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError):
        return [], ["Q08_STREAM_READ_ERROR"]
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            raw = _strict_json_value(line)
        except (json.JSONDecodeError, ValueError):
            errors.append(f"Q08_STREAM_JSON_INVALID_AT_LINE:{line_number}")
            continue
        if (
            not isinstance(raw, dict)
            or set(raw) != expected_fields
            or raw.get("event") != "TRADE_CLOSED"
        ):
            errors.append(f"Q08_STREAM_EVENT_INVALID_AT_LINE:{line_number}")
            continue
        row = dict(raw)
        numeric_fields = (
            "mae_acct",
            "net",
            "profit",
            "swap",
            "commission",
            "volume",
            "notional",
        )
        numeric_values = {
            field: _strict_runtime_decimal(row.get(field)) for field in numeric_fields
        }
        if any(value is None for value in numeric_values.values()):
            errors.append(f"Q08_STREAM_NUMERIC_SCHEMA_INVALID_AT_LINE:{line_number}")
        if (
            type(row.get("entry_time")) is not int
            or row.get("entry_time") <= 0
            or type(row.get("time")) is not int
            or row.get("time") <= 0
            or not isinstance(row.get("symbol"), str)
            or not row.get("symbol")
            or row.get("symbol") != row.get("symbol").strip()
            or numeric_values["volume"] is None
            or Decimal(numeric_values["volume"]) <= 0
        ):
            errors.append(f"Q08_STREAM_REQUIRED_IDENTITY_INVALID_AT_LINE:{line_number}")
            continue
        if row.get("symbol") != key[1]:
            errors.append(f"Q08_STREAM_SYMBOL_MISMATCH_AT_LINE:{line_number}")
        if (
            type(row.get("magic")) is not int
            or row.get("magic") != expected_magic
        ):
            errors.append(f"Q08_STREAM_EXPECTED_MAGIC_MISMATCH_AT_LINE:{line_number}")
        rows.append(row)
    if not rows:
        errors.append("Q08_STREAM_EMPTY")
    return rows, sorted(set(errors))


def _runtime_log_stamp(value: Any) -> int | None:
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        return None
    try:
        stamp = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=dt.UTC)
    return int(stamp.timestamp())


def _strict_runtime_decimal(value: Any) -> str | None:
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        return None
    return _canonical_decimal_text(value)


def _load_runtime_log_semantics(
    path: Path,
    key: SleeveKey,
    expected_magic: Any,
) -> dict[str, Any]:
    """Strictly rederive runner telemetry from the physically opened JSONL log."""

    entries: list[list[Any]] = []
    exits: list[list[Any]] = []
    equity: list[list[Any]] = []
    errors: list[str] = []
    line_count = 0
    init_count = 0
    init_ok_count = 0
    observed_magics: set[int] = set()
    relevant_timestamps: list[int] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError):
        lines = []
        errors.append("RUNTIME_LOG_READ_ERROR")
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        line_count += 1
        try:
            raw = _strict_json_value(line)
        except (json.JSONDecodeError, ValueError):
            errors.append(f"RUNTIME_LOG_JSON_INVALID_AT_LINE:{line_number}")
            continue
        if not isinstance(raw, dict):
            errors.append(f"RUNTIME_LOG_ROW_NOT_OBJECT_AT_LINE:{line_number}")
            continue
        event = raw.get("event")
        if not isinstance(event, str) or not event:
            errors.append(f"RUNTIME_LOG_EVENT_INVALID_AT_LINE:{line_number}")
            continue
        if type(raw.get("ea_id")) is not int or raw.get("ea_id") != key[0]:
            errors.append(f"RUNTIME_LOG_EA_ID_MISMATCH_AT_LINE:{line_number}")
        if raw.get("symbol") != key[1]:
            errors.append(f"RUNTIME_LOG_SYMBOL_MISMATCH_AT_LINE:{line_number}")
        if raw.get("tf") != key[2]:
            errors.append(f"RUNTIME_LOG_TIMEFRAME_MISMATCH_AT_LINE:{line_number}")
        row_magic = raw.get("magic")
        if type(row_magic) is not int or row_magic != expected_magic:
            errors.append(f"RUNTIME_LOG_MAGIC_MISMATCH_AT_LINE:{line_number}")
        else:
            observed_magics.add(row_magic)
        payload = raw.get("payload")
        if event == "INIT":
            init_count += 1
            if not isinstance(payload, Mapping):
                errors.append(f"RUNTIME_LOG_INIT_PAYLOAD_INVALID_AT_LINE:{line_number}")
            else:
                if "magic" in payload and payload.get("magic") != expected_magic:
                    errors.append(f"RUNTIME_LOG_INIT_MAGIC_MISMATCH_AT_LINE:{line_number}")
                if "symbol" in payload and payload.get("symbol") != key[1]:
                    errors.append(f"RUNTIME_LOG_INIT_SYMBOL_MISMATCH_AT_LINE:{line_number}")
            continue
        if event == "INIT_OK":
            init_ok_count += 1
            continue
        if event not in {
            "ENTRY_ACCEPTED",
            "TM_CLOSE",
            "TM_PARTIAL_CLOSE",
            "EQUITY_SNAPSHOT",
        }:
            continue
        if not isinstance(payload, Mapping):
            errors.append(f"RUNTIME_LOG_PAYLOAD_INVALID_AT_LINE:{line_number}")
            continue
        stamp = _runtime_log_stamp(raw.get("ts_broker"))
        if stamp is None:
            errors.append(f"RUNTIME_LOG_TIMESTAMP_INVALID_AT_LINE:{line_number}")
            continue
        relevant_timestamps.append(stamp)
        if payload.get("symbol") != key[1]:
            errors.append(f"RUNTIME_LOG_PAYLOAD_SYMBOL_MISMATCH_AT_LINE:{line_number}")
        if "magic" in payload and (
            type(payload.get("magic")) is not int
            or payload.get("magic") != expected_magic
        ):
            errors.append(f"RUNTIME_LOG_PAYLOAD_MAGIC_MISMATCH_AT_LINE:{line_number}")

        if event == "ENTRY_ACCEPTED":
            side = {
                "QM_BUY": "BUY",
                "BUY": "BUY",
                "QM_SELL": "SELL",
                "SELL": "SELL",
            }.get(payload.get("type"))
            volume = _strict_runtime_decimal(payload.get("lots"))
            price = _strict_runtime_decimal(payload.get("price"))
            ticket = payload.get("ticket")
            reason = payload.get("reason")
            valid = (
                type(payload.get("magic")) is int
                and payload.get("magic") == expected_magic
                and type(ticket) is int
                and ticket > 0
                and side is not None
                and volume is not None
                and Decimal(volume) > 0
                and price is not None
                and Decimal(price) > 0
                and isinstance(reason, str)
                and bool(reason.strip())
            )
            if not valid:
                errors.append(f"RUNTIME_LOG_ENTRY_SCHEMA_INVALID_AT_LINE:{line_number}")
            else:
                entries.append(
                    [
                        stamp,
                        key[1],
                        volume,
                        side,
                        price,
                        ticket,
                        reason.strip(),
                        expected_magic,
                    ]
                )
        elif event in {"TM_CLOSE", "TM_PARTIAL_CLOSE"}:
            volume = _strict_runtime_decimal(payload.get("lots"))
            ticket = payload.get("ticket")
            reason = payload.get("reason")
            partial = event == "TM_PARTIAL_CLOSE"
            valid = (
                type(ticket) is int
                and ticket > 0
                and volume is not None
                and Decimal(volume) > 0
                and isinstance(reason, str)
                and bool(reason.strip())
                and payload.get("ok") is True
                and payload.get("partial") is partial
            )
            if not valid:
                errors.append(f"RUNTIME_LOG_EXIT_SCHEMA_INVALID_AT_LINE:{line_number}")
            else:
                exits.append(
                    [
                        stamp,
                        key[1],
                        volume,
                        reason.strip(),
                        ticket,
                        event,
                        expected_magic,
                    ]
                )
        else:
            day_key = payload.get("day_key")
            month_key = payload.get("month_key")
            equity_value = _strict_runtime_decimal(payload.get("equity"))
            day_pnl = _strict_runtime_decimal(payload.get("day_pnl"))
            month_pnl = _strict_runtime_decimal(payload.get("month_pnl"))
            atr_regime = payload.get("atr_regime")
            try:
                day_date = (
                    dt.datetime.strptime(str(day_key), "%Y%m%d").date()
                    if type(day_key) is int
                    else None
                )
            except ValueError:
                day_date = None
            valid = (
                day_date is not None
                and type(month_key) is int
                and month_key == day_date.year * 100 + day_date.month
                and equity_value is not None
                and Decimal(equity_value) > 0
                and day_pnl is not None
                and month_pnl is not None
                and isinstance(atr_regime, str)
                and bool(atr_regime.strip())
            )
            if not valid:
                errors.append(f"RUNTIME_LOG_EQUITY_SCHEMA_INVALID_AT_LINE:{line_number}")
            else:
                equity.append(
                    [
                        stamp,
                        day_key,
                        key[1],
                        equity_value,
                        day_pnl,
                        month_pnl,
                        atr_regime.strip(),
                        expected_magic,
                    ]
                )
    if line_count == 0:
        errors.append("RUNTIME_LOG_EMPTY")
    if init_count != 1:
        errors.append(f"RUNTIME_LOG_INIT_COUNT_INVALID:{init_count}")
    if init_ok_count != 1:
        errors.append(f"RUNTIME_LOG_INIT_OK_COUNT_INVALID:{init_ok_count}")
    if observed_magics != {expected_magic}:
        errors.append("RUNTIME_LOG_MAGIC_IDENTITY_NOT_UNIQUE")
    if any(
        later < earlier
        for earlier, later in zip(relevant_timestamps, relevant_timestamps[1:])
    ):
        errors.append("RUNTIME_LOG_EVENT_TIME_NOT_MONOTONIC")
    day_keys = [row[1] for row in equity]
    if not equity:
        errors.append("RUNTIME_LOG_EQUITY_SEQUENCE_EMPTY")
    if len(day_keys) != len(set(day_keys)):
        errors.append("RUNTIME_LOG_EQUITY_DAY_DUPLICATE")
    if any(later <= earlier for earlier, later in zip(day_keys, day_keys[1:])):
        errors.append("RUNTIME_LOG_EQUITY_DAY_NOT_STRICTLY_INCREASING")
    return {
        "entries": entries,
        "exits": exits,
        "equity": equity,
        "line_count": line_count,
        "relevant_event_count": len(entries) + len(exits) + len(equity),
        "magic": expected_magic if observed_magics == {expected_magic} else None,
        "errors": sorted(set(errors)),
    }


def _runtime_telemetry_semantic_issues(
    prefix: str,
    key: SleeveKey,
    receipt: Mapping[str, Any],
    wrapper: Mapping[str, Any],
    runtime_semantics: Mapping[str, Any],
    q08_rows: Sequence[Mapping[str, Any]],
) -> list[str]:
    issues: list[str] = []
    job = receipt.get("job")
    expected_magic = job.get("expected_magic") if isinstance(job, Mapping) else None
    expected_magic_source = (
        job.get("expected_magic_source") if isinstance(job, Mapping) else None
    )
    if wrapper.get("expected_magic") != expected_magic:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:EXPECTED_MAGIC_BINDING_MISMATCH")
    if wrapper.get("expected_magic_source") != expected_magic_source:
        issues.append(
            f"{prefix}:RUNTIME_TELEMETRY:EXPECTED_MAGIC_SOURCE_BINDING_MISMATCH"
        )
    if set(wrapper) != {
        "schema_version",
        "capture_sha256",
        "job_identity",
        "expected_magic",
        "expected_magic_source",
        "telemetry",
        "q08_binding",
    }:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:WRAPPER_SCHEMA_FIELDS_INVALID")
    telemetry = wrapper.get("telemetry")
    if not isinstance(telemetry, Mapping):
        return issues + [f"{prefix}:RUNTIME_TELEMETRY:TELEMETRY_OBJECT_INVALID"]
    if set(telemetry) != {
        "schema_version",
        "status",
        "errors",
        "line_count",
        "relevant_event_count",
        "identity",
        "entries",
        "exits",
        "equity",
    }:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:NESTED_SCHEMA_FIELDS_INVALID")
    if telemetry.get("schema_version") != 1:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:NESTED_SCHEMA_VERSION_NOT_1")
    if runtime_semantics.get("errors") != []:
        issues.append(f"{prefix}:RUNTIME_LOG:SEMANTIC_REDERIVATION_FAILED")
    if telemetry.get("status") != "PASS":
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:NESTED_STATUS_NOT_PASS")
    if telemetry.get("errors") != []:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:NESTED_ERRORS_PRESENT_OR_INVALID")
    if telemetry.get("line_count") != runtime_semantics.get("line_count"):
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:LINE_COUNT_REDERIVATION_MISMATCH")
    if telemetry.get("relevant_event_count") != runtime_semantics.get(
        "relevant_event_count"
    ):
        issues.append(
            f"{prefix}:RUNTIME_TELEMETRY:RELEVANT_EVENT_COUNT_REDERIVATION_MISMATCH"
        )

    descriptor_contracts = {
        "entries": {
            "complete": True,
            "basis": (
                "framework_ENTRY_ACCEPTED_broker_time_symbol_volume_side_"
                "requested_price_not_fill_price"
            ),
            "reasons": [],
        },
        "exits": {
            "complete": True,
            "basis": "framework_TM_CLOSE_broker_time_symbol_volume_reason",
            "reasons": [],
        },
        "equity": {
            "complete": False,
            "basis": "framework_EQUITY_SNAPSHOT_partial_observation_sequence",
            "reasons": [
                "INITIAL_AND_FINAL_EQUITY_BOUNDARY_SNAPSHOTS_NOT_EMITTED"
            ],
        },
    }
    for field, contract in descriptor_contracts.items():
        sequence = runtime_semantics.get(field)
        expected_descriptor = {
            "complete": contract["complete"],
            "count": len(sequence) if isinstance(sequence, list) else 0,
            "sha256": canonical_json_sha(sequence if isinstance(sequence, list) else []),
            "basis": contract["basis"],
            "reasons": contract["reasons"],
            "sequence": sequence if isinstance(sequence, list) else [],
        }
        if telemetry.get(field) != expected_descriptor:
            issues.append(
                f"{prefix}:RUNTIME_TELEMETRY:{field.upper()}_PHYSICAL_REDERIVATION_MISMATCH"
            )
    identity = telemetry.get("identity")
    if not isinstance(identity, Mapping):
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:IDENTITY_MISSING_OR_INVALID")
    else:
        expected_identity: dict[str, Any] = {
            "ea_id": key[0],
            "symbol": key[1],
            "timeframe": key[2],
            "magic": expected_magic,
            "magic_unique": True,
            "expected_magic": expected_magic,
            "expected_magic_valid": True,
            "expected_magic_source": expected_magic_source,
            "observed_magic_matches_expected": True,
        }
        if dict(identity) != expected_identity or runtime_semantics.get("magic") != expected_magic:
            issues.append(f"{prefix}:RUNTIME_TELEMETRY:IDENTITY_BINDING_MISMATCH")
    q08_binding = wrapper.get("q08_binding")
    if not isinstance(q08_binding, Mapping):
        return issues + [f"{prefix}:RUNTIME_TELEMETRY:Q08_BINDING_INVALID"]
    if q08_binding.get("status") != "INCOMPLETE":
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_STATUS_NOT_INCOMPLETE")
    if q08_binding.get("integrity_status") != "PASS":
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_INTEGRITY_STATUS_NOT_PASS")
    if q08_binding.get("blockers") != ["ENTRY_FILL_PRICE_NOT_EMITTED"]:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_BLOCKER_SET_INVALID")
    if q08_binding.get("expected_magic_valid") is not True:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_EXPECTED_MAGIC_VALID_NOT_TRUE")

    entries = runtime_semantics.get("entries")
    exits = runtime_semantics.get("exits")
    entry_map: dict[tuple[Any, Any, Any], list[Any]] = {}
    exit_map: dict[tuple[Any, Any, Any], list[Any]] = {}
    entry_keys = [(row[0], row[1], row[2]) for row in entries] if isinstance(entries, list) else []
    exit_keys = [(row[0], row[1], row[2]) for row in exits] if isinstance(exits, list) else []
    q08_entry_keys: list[tuple[Any, Any, Any]] = []
    q08_exit_keys: list[tuple[Any, Any, Any]] = []
    q08_magics: list[Any] = []
    for row in q08_rows:
        q08_entry_keys.append(
            (_row_entry_time(row), row.get("symbol"), _canonical_decimal_text(row.get("volume")))
        )
        q08_exit_keys.append(
            (_row_time(row), row.get("symbol"), _canonical_decimal_text(row.get("volume")))
        )
        q08_magics.append(row.get("magic"))
    entry_join_complete = (
        bool(q08_rows)
        and len(entry_keys) == len(q08_entry_keys)
        and len(set(entry_keys)) == len(entry_keys)
        and collections.Counter(entry_keys) == collections.Counter(q08_entry_keys)
    )
    exit_join_complete = (
        bool(q08_rows)
        and len(exit_keys) == len(q08_exit_keys)
        and len(set(exit_keys)) == len(exit_keys)
        and collections.Counter(exit_keys) == collections.Counter(q08_exit_keys)
    )
    if entry_join_complete:
        entry_map = {key_value: row for key_value, row in zip(entry_keys, entries)}
    if exit_join_complete:
        exit_map = {key_value: row for key_value, row in zip(exit_keys, exits)}
    enriched: list[dict[str, Any]] = []
    for row, entry_key, exit_key in zip(q08_rows, q08_entry_keys, q08_exit_keys):
        current = dict(row)
        if entry_join_complete:
            entry_row = entry_map[entry_key]
            current["side"] = entry_row[3]
            current["requested_entry_price"] = entry_row[4]
        if exit_join_complete:
            current["exit_reason"] = exit_map[exit_key][3]
        enriched.append(current)
    magic_valid = type(expected_magic) is int and expected_magic > 0
    magic_bound = (
        magic_valid
        and runtime_semantics.get("magic") == expected_magic
        and bool(q08_rows)
        and all(type(value) is int and value == expected_magic for value in q08_magics)
    )
    expected_q08_binding = {
        "status": "INCOMPLETE",
        "integrity_status": "PASS",
        "blockers": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
        "entries_complete": False,
        "entry_join_complete": True,
        "exits_complete": True,
        "exit_join_complete": True,
        "entry_axis_reasons": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
        "exit_axis_reasons": [],
        "enriched_rows": enriched,
        "magic_bound": True,
        "authoritative_expected_magic_bound": True,
        "expected_magic": expected_magic,
        "expected_magic_valid": True,
        "runtime_magic_matches_expected": True,
        "q08_magic_matches_expected": True,
        "magic_cross_stream_consistent": True,
        "observed_magic": expected_magic,
        "entry_join_basis": (
            "exact_broker_time_symbol_canonical_volume_bijection; "
            "price_is_request_not_fill"
        ),
        "exit_join_basis": "exact_broker_time_symbol_canonical_volume_bijection",
    }
    if not entry_join_complete or not exit_join_complete or not magic_bound:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_PHYSICAL_JOIN_INVALID")
    if dict(q08_binding) != expected_q08_binding:
        issues.append(f"{prefix}:RUNTIME_TELEMETRY:Q08_BINDING_CONTRACT_MISMATCH")
    return issues


def _physical_axis_descriptors(
    q08_rows: list[dict[str, Any]],
    q08_errors: Sequence[str],
    telemetry_wrapper: Mapping[str, Any] | None,
    *,
    telemetry_semantic_valid: bool,
) -> dict[str, dict[str, Any]]:
    """Recompute the pair axes solely from physically opened run artifacts."""

    def descriptor(sequence: list[Any], complete: bool, basis: str) -> dict[str, Any]:
        return {
            "complete": bool(complete),
            "count": len(sequence),
            "sha256": canonical_json_sha(sequence),
            "basis": basis,
        }

    stream_complete = bool(q08_rows) and not q08_errors
    signals: list[list[Any]] = []
    lots: list[list[Any]] = []
    outcomes: list[list[Any]] = []
    pnl: list[list[Any]] = []
    signals_valid = lots_valid = pnl_valid = True
    for index, row in enumerate(q08_rows):
        entry_time = _row_entry_time(row)
        close_time = _row_time(row)
        symbol = str(row.get("symbol") or "").strip().upper()
        if entry_time is None or close_time is None or not symbol:
            signals_valid = False
        else:
            signals.append([entry_time, close_time, symbol])
        volume = _canonical_decimal_text(row.get("volume"))
        if volume is None or Decimal(volume) <= 0:
            lots_valid = False
        else:
            lots.append([index, volume])
        net = _canonical_decimal_text(row.get("net"))
        if net is None:
            pnl_valid = False
        else:
            pnl.append([index, net])
            numeric_net = Decimal(net)
            outcomes.append(
                [index, 1 if numeric_net > 0 else (-1 if numeric_net < 0 else 0)]
            )

    axes = {
        "trades": descriptor(q08_rows, stream_complete, "physical_q08_stream"),
        "signals": descriptor(
            signals,
            stream_complete and signals_valid and len(signals) == len(q08_rows),
            "physical_q08_signal_sequence",
        ),
        "lots": descriptor(
            lots,
            stream_complete and lots_valid and len(lots) == len(q08_rows),
            "physical_q08_lot_sequence",
        ),
        "outcome_signs": descriptor(
            outcomes,
            stream_complete and pnl_valid and len(outcomes) == len(q08_rows),
            "physical_q08_outcome_sign_sequence",
        ),
        "pnl": descriptor(
            pnl,
            stream_complete and pnl_valid and len(pnl) == len(q08_rows),
            "physical_q08_pnl_sequence",
        ),
    }

    telemetry = (
        telemetry_wrapper.get("telemetry")
        if isinstance(telemetry_wrapper, Mapping)
        else None
    )
    q08_binding = (
        telemetry_wrapper.get("q08_binding")
        if isinstance(telemetry_wrapper, Mapping)
        else None
    )
    enriched = (
        q08_binding.get("enriched_rows")
        if isinstance(q08_binding, Mapping)
        else None
    )
    enriched_valid = (
        isinstance(enriched, list)
        and len(enriched) == len(q08_rows)
        and all(
            isinstance(enriched_row, Mapping)
            and all(enriched_row.get(field) == value for field, value in q08_row.items())
            for enriched_row, q08_row in zip(enriched, q08_rows)
        )
    )
    entries: list[list[Any]] = []
    exits: list[list[Any]] = []
    entry_values_valid = exit_values_valid = enriched_valid
    if isinstance(enriched, list) and enriched_valid:
        for index, row in enumerate(enriched):
            side = {
                "LONG": "BUY",
                "BUY": "BUY",
                "SHORT": "SELL",
                "SELL": "SELL",
            }.get(str(row.get("side") or "").strip().upper())
            entry_price = _canonical_decimal_text(row.get("entry_price"))
            if (
                side is None
                or entry_price is None
                or Decimal(entry_price) <= 0
                or _row_entry_time(row) is None
            ):
                entry_values_valid = False
            else:
                entries.append(
                    [index, _row_entry_time(row), str(row.get("symbol") or "").strip().upper(), side, entry_price]
                )
            exit_reason = row.get("exit_reason")
            if (
                not isinstance(exit_reason, str)
                or not exit_reason.strip()
                or _row_time(row) is None
            ):
                exit_values_valid = False
            else:
                exits.append([index, _row_time(row), exit_reason.strip()])
    entries_complete = (
        telemetry_semantic_valid
        and stream_complete
        and isinstance(q08_binding, Mapping)
        and q08_binding.get("entries_complete") is True
        and entry_values_valid
        and len(entries) == len(q08_rows)
    )
    exits_complete = (
        telemetry_semantic_valid
        and stream_complete
        and isinstance(q08_binding, Mapping)
        and q08_binding.get("exits_complete") is True
        and q08_binding.get("authoritative_expected_magic_bound") is True
        and exit_values_valid
        and len(exits) == len(q08_rows)
    )
    axes["entries"] = descriptor(
        entries, entries_complete, "physical_q08_runtime_enriched_entries"
    )
    axes["exits"] = descriptor(
        exits, exits_complete, "physical_q08_runtime_enriched_exits"
    )

    for axis, telemetry_field in (
        ("daily_mtm", "equity"),
        ("mtm", "mtm"),
        ("margin", "margin"),
    ):
        row = telemetry.get(telemetry_field) if isinstance(telemetry, Mapping) else None
        sequence = row.get("sequence") if isinstance(row, Mapping) else None
        complete = (
            telemetry_semantic_valid
            and isinstance(sequence, list)
            and row.get("complete") is True
        )
        axes[axis] = descriptor(
            sequence if isinstance(sequence, list) else [],
            complete,
            f"physical_runtime_{telemetry_field}_sequence",
        )
    return axes


def _strict_runtime_artifact(
    prefix: str,
    artifact_name: str,
    raw_path: Any,
    raw_sha256: Any,
    expected_basename: str,
    runs_root: Path | None,
    expected_run_dir: Path | None,
    sandbox: Path | None,
) -> tuple[dict[str, Any], Path | None, list[str]]:
    """Verify one receipt-declared runtime artifact without leaving its run root."""

    artifact_prefix = f"{prefix}:{artifact_name.upper()}"
    issues: list[str] = []
    binding: dict[str, Any] = {
        "status": "FAIL",
        "path": raw_path if isinstance(raw_path, str) else None,
        "resolved_path": None,
        "expected_basename": expected_basename,
        "declared_sha256": (
            str(raw_sha256).lower() if _valid_sha(raw_sha256) else None
        ),
        "file_sha256": None,
    }
    if not isinstance(raw_path, str) or not raw_path.strip():
        issues.append(f"{artifact_prefix}:PATH_MISSING_OR_INVALID")
        if not _valid_sha(raw_sha256):
            issues.append(f"{artifact_prefix}:SHA256_MISSING_OR_INVALID")
        return binding, None, issues

    declared_path = Path(raw_path)
    if not declared_path.is_absolute():
        issues.append(f"{artifact_prefix}:PATH_NOT_ABSOLUTE")
    if declared_path.name != expected_basename:
        issues.append(f"{artifact_prefix}:BASENAME_INVALID")
    if not _valid_sha(raw_sha256):
        issues.append(f"{artifact_prefix}:SHA256_MISSING_OR_INVALID")

    resolved: Path | None = None
    try:
        resolved = declared_path.resolve(strict=True)
    except (OSError, RuntimeError):
        issues.append(f"{artifact_prefix}:FILE_MISSING_OR_UNREADABLE")
    if resolved is not None:
        binding["resolved_path"] = str(resolved)
        if not resolved.is_file():
            issues.append(f"{artifact_prefix}:NOT_A_REGULAR_FILE")
        if resolved.name != expected_basename:
            issues.append(f"{artifact_prefix}:RESOLVED_BASENAME_INVALID")
        if runs_root is None:
            issues.append(f"{artifact_prefix}:RUNS_ROOT_UNAVAILABLE")
        else:
            try:
                resolved.relative_to(runs_root)
            except ValueError:
                issues.append(f"{artifact_prefix}:PATH_OUTSIDE_OR_ESCAPES_RUNS_ROOT")
        if expected_run_dir is None:
            issues.append(f"{artifact_prefix}:EXPECTED_RUN_DIR_UNAVAILABLE")
        elif resolved.parent != expected_run_dir:
            issues.append(f"{artifact_prefix}:PARENT_NOT_EXACT_EXPECTED_RUN_DIR")
        if sandbox is not None and _paths_overlap(resolved, sandbox):
            issues.append(f"{artifact_prefix}:PATH_OVERLAPS_EXECUTION_SANDBOX")

    # Do not read a caller-selected file until its strict physical location has
    # passed the containment and sandbox-isolation checks above.
    location_safe = (
        resolved is not None
        and resolved.is_file()
        and runs_root is not None
        and not any(
            issue.endswith(
                (
                    "PATH_OUTSIDE_OR_ESCAPES_RUNS_ROOT",
                    "PATH_OVERLAPS_EXECUTION_SANDBOX",
                    "RESOLVED_BASENAME_INVALID",
                    "PARENT_NOT_EXACT_EXPECTED_RUN_DIR",
                )
            )
            for issue in issues
        )
    )
    if location_safe:
        try:
            actual_sha256 = sha256_file(resolved)
        except OSError:
            issues.append(f"{artifact_prefix}:FILE_MISSING_OR_UNREADABLE")
        else:
            binding["file_sha256"] = actual_sha256
            if _valid_sha(raw_sha256) and actual_sha256 != str(raw_sha256).lower():
                issues.append(f"{artifact_prefix}:FILE_SHA256_MISMATCH")

    if not issues:
        binding["status"] = "PASS"
    return binding, resolved if binding["status"] == "PASS" else None, issues


def _runtime_artifact_bindings_for_summary(
    label: str,
    binding: Mapping[str, Any],
    receipts: Mapping[SleeveKey, Mapping[str, Any]],
) -> tuple[
    dict[str, Any],
    list[str],
    dict[SleeveKey, dict[str, dict[str, Any]]],
]:
    """Physically bind runtime artifacts and derive independently hashed axes."""

    summary_prefix = f"SUMMARY_{label.upper()}"
    issues: list[str] = []
    raw_summary_path = binding.get("path")
    summary_path: Path | None = None
    runs_root: Path | None = None
    if not isinstance(raw_summary_path, str) or not Path(raw_summary_path).is_absolute():
        issues.append(f"{summary_prefix}_RUNTIME_ARTIFACT_SUMMARY_PATH_INVALID")
    else:
        try:
            summary_path = Path(raw_summary_path).resolve(strict=True)
        except (OSError, RuntimeError):
            issues.append(f"{summary_prefix}_RUNTIME_ARTIFACT_SUMMARY_PATH_UNREADABLE")
        if summary_path is not None:
            try:
                runs_root = (summary_path.parent / "runs").resolve(strict=True)
            except (OSError, RuntimeError):
                issues.append(f"{summary_prefix}_RUNTIME_ARTIFACT_RUNS_ROOT_UNREADABLE")
            else:
                if (
                    not runs_root.is_dir()
                    or runs_root.parent != summary_path.parent
                    or runs_root.name != "runs"
                ):
                    issues.append(
                        f"{summary_prefix}_RUNTIME_ARTIFACT_RUNS_ROOT_NOT_EXACT_OR_ESCAPED"
                    )
                    runs_root = None

    result: dict[str, Any] = {
        "summary_path": str(summary_path) if summary_path is not None else None,
        "runs_root": str(runs_root) if runs_root is not None else None,
        "receipts": [],
    }
    physical_axes_by_receipt: dict[SleeveKey, dict[str, dict[str, Any]]] = {}
    for key, receipt in sorted(receipts.items()):
        prefix = f"{summary_prefix}_RECEIPT:{_key_text(key)}"
        receipt_issues: list[str] = []
        identity = receipt.get("identity")
        if not isinstance(identity, Mapping):
            identity = {}
            receipt_issues.append(f"{prefix}:RUNTIME_ARTIFACT_IDENTITY_MISSING")
        execution = receipt.get("execution")
        raw_sandbox = execution.get("sandbox") if isinstance(execution, Mapping) else None
        sandbox = (
            Path(raw_sandbox).resolve(strict=False)
            if isinstance(raw_sandbox, str) and Path(raw_sandbox).is_absolute()
            else None
        )
        job = receipt.get("job")
        ordinal = job.get("ordinal") if isinstance(job, Mapping) else None
        expected_run_dir: Path | None = None
        expected_run_dir_name: str | None = None
        if (
            not isinstance(ordinal, int)
            or isinstance(ordinal, bool)
            or ordinal <= 0
        ):
            receipt_issues.append(f"{prefix}:JOB_ORDINAL_MISSING_OR_INVALID")
        elif runs_root is not None:
            expected_run_dir_name = (
                f"{ordinal:02d}_{key[0]}_{key[1].replace('.', '_')}_"
                f"{key[2]}_{key[3]}"
            )
            try:
                candidate_run_dir = (
                    runs_root / expected_run_dir_name
                ).resolve(strict=True)
            except (OSError, RuntimeError):
                receipt_issues.append(f"{prefix}:EXPECTED_RUN_DIR_UNREADABLE")
            else:
                if (
                    not candidate_run_dir.is_dir()
                    or candidate_run_dir.parent != runs_root
                    or candidate_run_dir.name != expected_run_dir_name
                ):
                    receipt_issues.append(
                        f"{prefix}:EXPECTED_RUN_DIR_NOT_EXACT_OR_ESCAPED"
                    )
                else:
                    expected_run_dir = candidate_run_dir

        artifacts: dict[str, Any] = {}
        resolved_files: dict[str, Path | None] = {}
        for artifact_name, (
            path_field,
            sha_field,
            expected_basename,
        ) in RUNTIME_ARTIFACT_FIELDS.items():
            artifact_binding, resolved, artifact_issues = _strict_runtime_artifact(
                prefix,
                artifact_name,
                identity.get(path_field),
                identity.get(sha_field),
                expected_basename,
                runs_root,
                expected_run_dir,
                sandbox,
            )
            artifacts[artifact_name] = artifact_binding
            resolved_files[artifact_name] = resolved
            receipt_issues.extend(artifact_issues)

        q08_path = (
            str(expected_run_dir / "q08_stream.jsonl")
            if expected_run_dir is not None
            else None
        )
        q08_artifact, q08_resolved, q08_artifact_issues = _strict_runtime_artifact(
            prefix,
            "q08_stream",
            q08_path,
            identity.get("q08_stream_sha256"),
            "q08_stream.jsonl",
            runs_root,
            expected_run_dir,
            sandbox,
        )
        artifacts["q08_stream"] = q08_artifact
        resolved_files["q08_stream"] = q08_resolved
        receipt_issues.extend(q08_artifact_issues)

        transaction_status = "FAIL"
        transaction_path = resolved_files.get("runtime_log_transaction")
        runtime_log_path = resolved_files.get("runtime_log")
        if transaction_path is not None:
            try:
                transaction = _load_strict_json_object(transaction_path)
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
                receipt_issues.append(f"{prefix}:RUNTIME_LOG_TRANSACTION:JSON_INVALID")
            else:
                marker_issues: list[str] = []
                if set(transaction) != {
                    "schema_version",
                    "status",
                    "sandbox",
                    "ea_id",
                    "job_identity",
                    "pattern",
                    "prepared_epoch_ns",
                    "pre_run_logs",
                    "completed_utc",
                    "capture",
                }:
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:TOP_LEVEL_SCHEMA_FIELDS_INVALID"
                    )
                if transaction.get("schema_version") != 1:
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:SCHEMA_VERSION_NOT_1"
                    )
                if transaction.get("status") != "CAPTURED_AND_RESTORED":
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:STATUS_NOT_CAPTURED_AND_RESTORED"
                    )
                if (
                    type(transaction.get("prepared_epoch_ns")) is not int
                    or transaction.get("prepared_epoch_ns") <= 0
                ):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:FRESHNESS_BOUNDARY_INVALID"
                    )
                if transaction.get("pattern") != rf"^QM5_{key[0]}_.+\.log$":
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:PATTERN_BINDING_INVALID"
                    )
                try:
                    completed = dt.datetime.fromisoformat(
                        str(transaction.get("completed_utc")).replace("Z", "+00:00")
                    )
                except (TypeError, ValueError):
                    completed = None
                if (
                    completed is None
                    or completed.tzinfo is None
                    or type(transaction.get("prepared_epoch_ns")) is not int
                    or transaction.get("prepared_epoch_ns")
                    > int(completed.timestamp() * 1_000_000_000)
                ):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:COMPLETION_TIME_INVALID"
                    )
                if (
                    not isinstance(transaction.get("ea_id"), int)
                    or isinstance(transaction.get("ea_id"), bool)
                    or transaction.get("ea_id") != key[0]
                ):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:EA_ID_BINDING_MISMATCH"
                    )
                if transaction.get("job_identity") != _key_text(key):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:JOB_IDENTITY_BINDING_MISMATCH"
                    )
                marker_sandbox = transaction.get("sandbox")
                if (
                    sandbox is None
                    or not isinstance(marker_sandbox, str)
                    or not Path(marker_sandbox).is_absolute()
                    or _path_id(Path(marker_sandbox)) != _path_id(sandbox)
                ):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:SANDBOX_BINDING_MISMATCH"
                    )

                capture = transaction.get("capture")
                if not isinstance(capture, Mapping):
                    marker_issues.append(
                        f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_MISSING_OR_INVALID"
                    )
                else:
                    if set(capture) != {
                        "status",
                        "captured",
                        "fresh",
                        "ambiguous",
                        "restored",
                        "blockers",
                        "candidates",
                        "preserved_post_run_logs",
                        "late_rescans",
                        "evidence_path",
                        "source_path",
                        "sha256",
                        "size",
                        "restore_errors",
                        "restored_pre_run_logs",
                        "post_restore_quiescence",
                        "residual_concurrency_risk",
                    }:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_SCHEMA_FIELDS_INVALID"
                        )
                    if capture.get("status") != "PASS":
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_STATUS_NOT_PASS"
                        )
                    for field in ("captured", "fresh", "restored"):
                        if capture.get(field) is not True:
                            marker_issues.append(
                                f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_{field.upper()}_NOT_TRUE"
                            )
                    if capture.get("ambiguous") is not False:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_AMBIGUOUS_NOT_FALSE"
                        )
                    if capture.get("blockers") != []:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_BLOCKERS_PRESENT_OR_INVALID"
                        )
                    candidates = capture.get("candidates")
                    if not isinstance(candidates, list) or len(candidates) != 1:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CANDIDATE_SET_NOT_EXACT_ONE"
                        )
                    else:
                        candidate = candidates[0]
                        candidate_valid = (
                            isinstance(candidate, Mapping)
                            and candidate.get("fresh") is True
                            and candidate.get("stable") is True
                            and type(candidate.get("stability_observations")) is int
                            and type(candidate.get("required_stability_observations")) is int
                            and candidate.get("required_stability_observations") >= 3
                            and candidate.get("stability_observations")
                            == candidate.get("required_stability_observations")
                            and _valid_sha(candidate.get("sha256"))
                            and candidate.get("sha256") == capture.get("sha256")
                            and type(candidate.get("size")) is int
                            and candidate.get("size") > 0
                            and candidate.get("size") == capture.get("size")
                            and candidate.get("late_writer") is not True
                        )
                        if not candidate_valid:
                            marker_issues.append(
                                f"{prefix}:RUNTIME_LOG_TRANSACTION:CANDIDATE_STABILITY_INVALID"
                            )
                    if capture.get("late_rescans") != 3:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:LATE_RESCANS_INVALID"
                        )
                    quiescence = capture.get("post_restore_quiescence")
                    if (
                        not isinstance(quiescence, Mapping)
                        or quiescence.get("confirmed") is not True
                        or type(quiescence.get("stable_observations")) is not int
                        or type(quiescence.get("required_stable_observations")) is not int
                        or quiescence.get("required_stable_observations") < 3
                        or quiescence.get("stable_observations")
                        != quiescence.get("required_stable_observations")
                        or type(quiescence.get("scans")) is not int
                        or quiescence.get("scans")
                        < quiescence.get("required_stable_observations", 3)
                        or quiescence.get("incidents") != []
                    ):
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:POST_RESTORE_QUIESCENCE_INVALID"
                        )
                    if capture.get("restore_errors") != []:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:RESTORE_ERRORS_PRESENT_OR_INVALID"
                        )
                    pre_run_logs = transaction.get("pre_run_logs")
                    restored_logs = capture.get("restored_pre_run_logs")
                    if not isinstance(pre_run_logs, list) or not isinstance(
                        restored_logs, list
                    ):
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:PRESTATE_LEDGER_INVALID"
                        )
                    else:
                        expected_restored: list[dict[str, Any]] = []
                        for row in pre_run_logs:
                            if (
                                not isinstance(row, Mapping)
                                or not isinstance(row.get("path"), str)
                                or not isinstance(row.get("backup_path"), str)
                                or not _valid_sha(row.get("sha256"))
                                or type(row.get("size")) is not int
                                or row.get("size") < 0
                                or row.get("moved") is not True
                            ):
                                marker_issues.append(
                                    f"{prefix}:RUNTIME_LOG_TRANSACTION:PRESTATE_ROW_INVALID"
                                )
                                continue
                            expected_restored.append(
                                {
                                    "path": row.get("path"),
                                    "sha256": row.get("sha256"),
                                    "verified": True,
                                }
                            )
                        if restored_logs != expected_restored:
                            marker_issues.append(
                                f"{prefix}:RUNTIME_LOG_TRANSACTION:RESTORED_PRESTATE_MISMATCH"
                            )
                    if capture.get("preserved_post_run_logs") != candidates:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:PRESERVED_POST_RUN_SET_INVALID"
                        )
                    if capture.get("residual_concurrency_risk") != (
                        "FINITE_QUIESCENCE_WINDOW_CANNOT_PREVENT_A_NON_RUN_UNIQUE_"
                        "LOG_WRITER_FROM_REOPENING_AFTER_TRANSACTION_COMPLETION"
                    ):
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:RESIDUAL_RISK_DECLARATION_INVALID"
                        )
                    evidence_path = capture.get("evidence_path")
                    evidence_resolved: Path | None = None
                    if isinstance(evidence_path, str) and Path(evidence_path).is_absolute():
                        try:
                            evidence_resolved = Path(evidence_path).resolve(strict=True)
                        except (OSError, RuntimeError):
                            evidence_resolved = None
                    if runtime_log_path is None or evidence_resolved != runtime_log_path:
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_EVIDENCE_PATH_BINDING_MISMATCH"
                        )
                    log_sha = identity.get("runtime_log_sha256")
                    if (
                        not _valid_sha(capture.get("sha256"))
                        or not _valid_sha(log_sha)
                        or str(capture.get("sha256")).lower() != str(log_sha).lower()
                        or artifacts["runtime_log"].get("file_sha256")
                        != str(log_sha).lower()
                    ):
                        marker_issues.append(
                            f"{prefix}:RUNTIME_LOG_TRANSACTION:CAPTURE_SHA256_BINDING_MISMATCH"
                        )
                receipt_issues.extend(marker_issues)
                if not marker_issues:
                    transaction_status = "PASS"

        expected_magic = job.get("expected_magic") if isinstance(job, Mapping) else None
        q08_rows: list[dict[str, Any]] = []
        q08_errors: list[str] = []
        q08_stream_path = resolved_files.get("q08_stream")
        if q08_stream_path is not None:
            q08_rows, q08_errors = _load_q08_stream_strict(
                q08_stream_path, key, expected_magic
            )
            receipt_issues.extend(
                f"{prefix}:Q08_STREAM:{error}" for error in q08_errors
            )
        else:
            q08_errors = ["Q08_STREAM_PHYSICAL_BINDING_UNAVAILABLE"]

        runtime_semantics: dict[str, Any] = {
            "entries": [],
            "exits": [],
            "equity": [],
            "line_count": 0,
            "relevant_event_count": 0,
            "magic": None,
            "errors": ["RUNTIME_LOG_PHYSICAL_BINDING_UNAVAILABLE"],
        }
        if runtime_log_path is not None:
            runtime_semantics = _load_runtime_log_semantics(
                runtime_log_path, key, expected_magic
            )
            receipt_issues.extend(
                f"{prefix}:RUNTIME_LOG:{error}"
                for error in runtime_semantics.get("errors", [])
            )

        telemetry_status = "FAIL"
        telemetry: dict[str, Any] | None = None
        telemetry_path = resolved_files.get("runtime_telemetry")
        if telemetry_path is not None:
            try:
                telemetry = _load_strict_json_object(telemetry_path)
            except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
                receipt_issues.append(f"{prefix}:RUNTIME_TELEMETRY:JSON_INVALID")
            else:
                telemetry_issues: list[str] = []
                if telemetry.get("schema_version") != 1:
                    telemetry_issues.append(
                        f"{prefix}:RUNTIME_TELEMETRY:SCHEMA_VERSION_NOT_1"
                    )
                log_sha = identity.get("runtime_log_sha256")
                if (
                    not _valid_sha(telemetry.get("capture_sha256"))
                    or not _valid_sha(log_sha)
                    or str(telemetry.get("capture_sha256")).lower()
                    != str(log_sha).lower()
                    or artifacts["runtime_log"].get("file_sha256")
                    != str(log_sha).lower()
                ):
                    telemetry_issues.append(
                        f"{prefix}:RUNTIME_TELEMETRY:CAPTURE_SHA256_BINDING_MISMATCH"
                    )
                if telemetry.get("job_identity") != _key_text(key):
                    telemetry_issues.append(
                        f"{prefix}:RUNTIME_TELEMETRY:JOB_IDENTITY_BINDING_MISMATCH"
                    )
                telemetry_issues.extend(
                    _runtime_telemetry_semantic_issues(
                        prefix,
                        key,
                        receipt,
                        telemetry,
                        runtime_semantics,
                        q08_rows,
                    )
                )
                receipt_issues.extend(telemetry_issues)
                if not telemetry_issues:
                    telemetry_status = "PASS"

        physical_axes = _physical_axis_descriptors(
            q08_rows,
            q08_errors,
            telemetry,
            telemetry_semantic_valid=telemetry_status == "PASS",
        )
        physical_axes_by_receipt[key] = physical_axes

        issues.extend(receipt_issues)
        result["receipts"].append(
            {
                "ea_id": key[0],
                "symbol": key[1],
                "timeframe": key[2],
                "variant_id": key[3],
                "status": "FAIL" if receipt_issues else "PASS",
                "expected_run_dir": (
                    str(expected_run_dir) if expected_run_dir is not None else None
                ),
                "expected_run_dir_name": expected_run_dir_name,
                "artifacts": artifacts,
                "transaction_contract_status": transaction_status,
                "telemetry_contract_status": telemetry_status,
                "physical_axis_descriptors": physical_axes,
                "issues": sorted(set(receipt_issues)),
            }
        )
    return result, sorted(set(issues)), physical_axes_by_receipt


def _full_manifest_receipt_issues(
    prefix: str,
    payload: Mapping[str, Any],
    receipts: Mapping[SleeveKey, Mapping[str, Any]],
) -> list[str]:
    """Bind FULL counters and receipts to every sleeve in the opened manifest."""

    issues: list[str] = []
    source_paths: set[Path] = set()
    for receipt in receipts.values():
        job = receipt.get("job")
        source = job.get("expected_magic_source") if isinstance(job, Mapping) else None
        raw_source_path = (
            source.get("manifest_path") if isinstance(source, Mapping) else None
        )
        if (
            not isinstance(raw_source_path, str)
            or not raw_source_path
            or raw_source_path != raw_source_path.strip()
            or not Path(raw_source_path).is_absolute()
        ):
            issues.append(f"{prefix}_RECEIPT_SOURCE_MANIFEST_PATH_INVALID")
            continue
        try:
            source_paths.add(Path(raw_source_path).resolve(strict=True))
        except (OSError, RuntimeError):
            issues.append(f"{prefix}_RECEIPT_SOURCE_MANIFEST_UNREADABLE")
    raw_path = payload.get("manifest_path")
    manifest_path: Path | None = None
    if len(source_paths) != 1:
        issues.append(f"{prefix}_RECEIPT_SOURCE_MANIFEST_PATH_SET_NOT_EXACT_ONE")
    else:
        manifest_path = next(iter(source_paths))
    if raw_path is not None:
        if (
            not isinstance(raw_path, str)
            or not raw_path
            or raw_path != raw_path.strip()
            or not Path(raw_path).is_absolute()
        ):
            issues.append(f"{prefix}_MANIFEST_PATH_INVALID")
        else:
            try:
                declared_path = Path(raw_path).resolve(strict=True)
            except (OSError, RuntimeError):
                issues.append(f"{prefix}_MANIFEST_FILE_MISSING_OR_UNREADABLE")
            else:
                if manifest_path is not None and declared_path != manifest_path:
                    issues.append(f"{prefix}_MANIFEST_PATH_RECEIPT_SOURCE_MISMATCH")
                manifest_path = declared_path if manifest_path is None else manifest_path
    if manifest_path is not None:
        try:
            manifest_path = manifest_path.resolve(strict=True)
        except (OSError, RuntimeError):
            issues.append(f"{prefix}_MANIFEST_FILE_MISSING_OR_UNREADABLE")
            manifest_path = None
    if manifest_path is None or not manifest_path.is_file():
        return issues

    manifest_sha = payload.get("manifest_sha256")
    try:
        actual_sha = sha256_file(manifest_path)
    except OSError:
        return issues + [f"{prefix}_MANIFEST_FILE_MISSING_OR_UNREADABLE"]
    if not _valid_sha(manifest_sha) or actual_sha != manifest_sha:
        issues.append(f"{prefix}_MANIFEST_FILE_SHA256_MISMATCH")
        return issues
    try:
        manifest = _load_strict_json_object(manifest_path)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
        return issues + [f"{prefix}_MANIFEST_JSON_INVALID"]
    sleeves = manifest.get("sleeves")
    if not isinstance(sleeves, list) or not sleeves:
        return issues + [f"{prefix}_MANIFEST_SLEEVES_MISSING_OR_EMPTY"]

    manifest_keys: list[SleeveKey] = []
    for ordinal, sleeve in enumerate(sleeves, start=1):
        key = _manifest_sleeve_identity(sleeve)
        if key is None:
            issues.append(f"{prefix}_MANIFEST_SLEEVE_IDENTITY_INVALID:{ordinal}")
            continue
        if (
            not isinstance(sleeve, Mapping)
            or type(sleeve.get("magic_number")) is not int
            or sleeve.get("magic_number") <= 0
        ):
            issues.append(f"{prefix}_MANIFEST_SLEEVE_MAGIC_INVALID:{ordinal}")
        manifest_keys.append(key)
    if len(set(manifest_keys)) != len(manifest_keys):
        issues.append(f"{prefix}_MANIFEST_SLEEVE_IDENTITY_DUPLICATE")
    if set(manifest_keys) != set(receipts) or len(manifest_keys) != len(receipts):
        issues.append(f"{prefix}_FULL_MANIFEST_RECEIPT_SET_MISMATCH")

    receipt_ordinals: list[int] = []
    for key, receipt in receipts.items():
        job = receipt.get("job")
        ordinal = job.get("ordinal") if isinstance(job, Mapping) else None
        if type(ordinal) is not int or ordinal <= 0:
            continue
        receipt_ordinals.append(ordinal)
        if ordinal > len(manifest_keys) or manifest_keys[ordinal - 1] != key:
            issues.append(
                f"{prefix}_MANIFEST_RECEIPT_ORDINAL_IDENTITY_MISMATCH:{_key_text(key)}"
            )
        source = job.get("expected_magic_source")
        source_path = source.get("manifest_path") if isinstance(source, Mapping) else None
        try:
            source_resolved = (
                Path(source_path).resolve(strict=True)
                if isinstance(source_path, str) and Path(source_path).is_absolute()
                else None
            )
        except (OSError, RuntimeError):
            source_resolved = None
        if source_resolved != manifest_path:
            issues.append(
                f"{prefix}_RECEIPT_SOURCE_MANIFEST_PATH_MISMATCH:{_key_text(key)}"
            )
    if sorted(receipt_ordinals) != list(range(1, len(sleeves) + 1)):
        issues.append(f"{prefix}_FULL_RECEIPT_ORDINAL_SET_MISMATCH")

    for field in ("n_jobs", "manifest_jobs"):
        value = payload.get(field)
        if type(value) is not int or value <= 0 or value != len(sleeves):
            issues.append(f"{prefix}_{field.upper()}_NOT_EXACT_MANIFEST_COUNT")
    return sorted(set(issues))


def validate_summary(
    label: str, payload: Mapping[str, Any] | None
) -> tuple[dict[SleeveKey, Mapping[str, Any]], list[str]]:
    prefix = f"SUMMARY_{label.upper()}"
    if payload is None:
        return {}, [f"{prefix}_PAYLOAD_UNAVAILABLE"]
    issues: list[str] = []
    if payload.get("schema_version") != INPUT_SCHEMA_VERSION:
        issues.append(f"{prefix}_SCHEMA_VERSION_NOT_2")
    if payload.get("scope") != "FULL":
        issues.append(f"{prefix}_SCOPE_NOT_FULL")
    if payload.get("qualification_mode") != QUALIFICATION_MODE:
        issues.append(f"{prefix}_QUALIFICATION_MODE_INVALID")
    # A target run is technically complete but cannot qualify itself.  Only a
    # separate two-run gate can close REPRODUCIBILITY_PENDING.
    if payload.get("qualification_status") != SINGLE_RUN_QUALIFICATION_STATUS:
        issues.append(
            f"{prefix}_QUALIFICATION_STATUS_NOT_REPRODUCIBILITY_PENDING"
        )
    if payload.get("status") != "PASS":
        issues.append(f"{prefix}_STATUS_NOT_PASS")
    if payload.get("technical_status") != "PASS":
        issues.append(f"{prefix}_TECHNICAL_STATUS_NOT_PASS")
    if payload.get("deployment_eligible") is not False:
        issues.append(f"{prefix}_DEPLOYMENT_ELIGIBLE_NOT_FALSE")
    if payload.get("canonical_live_artifacts_used") is not False:
        issues.append(f"{prefix}_CANONICAL_LIVE_ARTIFACTS_USED_OR_UNDECLARED")
    if payload.get("canonical_live_root_pinned") is not True:
        issues.append(f"{prefix}_CANONICAL_LIVE_ROOT_NOT_PINNED")
    if payload.get("manifest_unchanged") is not True:
        issues.append(f"{prefix}_MANIFEST_NOT_UNCHANGED")
    manifest_sha = payload.get("manifest_sha256")
    if not _valid_sha(manifest_sha):
        issues.append(f"{prefix}_MANIFEST_SHA256_INVALID")
    if payload.get("manifest_sha256_end") != manifest_sha:
        issues.append(f"{prefix}_MANIFEST_END_SHA256_MISMATCH")
    if payload.get("runner_unchanged") is not True:
        issues.append(f"{prefix}_RUNNER_NOT_UNCHANGED")
    runner_sha256 = payload.get("runner_sha256")
    runner_sha256_start = payload.get("runner_sha256_start")
    runner_sha256_end = payload.get("runner_sha256_end")
    if not all(
        _valid_sha(value)
        for value in (runner_sha256, runner_sha256_start, runner_sha256_end)
    ):
        issues.append(f"{prefix}_RUNNER_SHA256_CHAIN_MISSING_OR_INVALID")
    elif not (
        runner_sha256 == runner_sha256_start == runner_sha256_end
    ):
        issues.append(f"{prefix}_RUNNER_SHA256_CHAIN_MISMATCH")
    if payload.get("reference_snapshot_unchanged") is not True:
        issues.append(f"{prefix}_REFERENCE_NOT_UNCHANGED")
    if payload.get("artifact_override_manifest_unchanged") is not True:
        issues.append(f"{prefix}_ARTIFACT_OVERRIDE_NOT_UNCHANGED")
    if payload.get("sandbox_derivations_unchanged") is not True:
        issues.append(f"{prefix}_SANDBOX_DERIVATION_NOT_UNCHANGED")
    if payload.get("live_source_unchanged") is not True:
        issues.append(f"{prefix}_LIVE_SOURCE_NOT_UNCHANGED")
    blockers = payload.get("global_blockers")
    if not isinstance(blockers, list) or blockers:
        issues.append(f"{prefix}_GLOBAL_BLOCKERS_PRESENT_OR_INVALID")
    issues.extend(_cost_issues(prefix, payload))

    receipts_raw = payload.get("receipts")
    receipts: dict[SleeveKey, Mapping[str, Any]] = {}
    if not isinstance(receipts_raw, list) or not receipts_raw:
        issues.append(f"{prefix}_RECEIPTS_MISSING_OR_EMPTY")
        return receipts, sorted(set(issues))
    for raw in receipts_raw:
        if not isinstance(raw, Mapping):
            issues.append(f"{prefix}_RECEIPT_NOT_OBJECT")
            continue
        key = _sleeve_key(raw)
        if key is None:
            issues.append(f"{prefix}_RECEIPT_SLEEVE_KEY_INVALID")
            continue
        if key in receipts:
            issues.append(f"{prefix}_DUPLICATE_RECEIPT:{_key_text(key)}")
            continue
        receipts[key] = raw
        issues.extend(
            _validate_receipt(
                label.upper(),
                key,
                raw,
                manifest_sha,
                payload.get("runner_sha256"),
            )
        )
    issues.extend(_full_manifest_receipt_issues(prefix, payload, receipts))
    n_jobs = payload.get("n_jobs")
    manifest_jobs = payload.get("manifest_jobs")
    if (
        type(n_jobs) is not int
        or type(manifest_jobs) is not int
        or n_jobs != len(receipts)
        or manifest_jobs != len(receipts)
    ):
        issues.append(f"{prefix}_FULL_JOB_COUNT_MISMATCH")
    counts = payload.get("counts")
    technical_counts = payload.get("technical_counts")
    if (
        not isinstance(counts, Mapping)
        or set(counts) != {"PASS"}
        or type(counts.get("PASS")) is not int
        or counts.get("PASS") != len(receipts)
    ):
        issues.append(f"{prefix}_COUNTS_NOT_ALL_PASS")
    if (
        not isinstance(technical_counts, Mapping)
        or set(technical_counts) != {"PASS"}
        or type(technical_counts.get("PASS")) is not int
        or technical_counts.get("PASS") != len(receipts)
    ):
        issues.append(f"{prefix}_TECHNICAL_COUNTS_NOT_ALL_PASS")
    return receipts, sorted(set(issues))


def _contract_has_hash(value: Any) -> bool:
    if isinstance(value, Mapping):
        for key, child in value.items():
            if "sha256" in str(key).casefold() and _valid_sha(child):
                return True
            if _contract_has_hash(child):
                return True
    elif isinstance(value, list):
        return any(_contract_has_hash(item) for item in value)
    return False


def _card_contract(
    summary: Mapping[str, Any],
    receipts: Mapping[SleeveKey, Mapping[str, Any]],
) -> Any:
    for field in ("card_contract", "card_contracts"):
        value = summary.get(field)
        if isinstance(value, (Mapping, list)) and value:
            return value
    by_sleeve: dict[str, Any] = {}
    for key, receipt in receipts.items():
        value = receipt.get("card_contract")
        job = receipt.get("job")
        if not isinstance(value, Mapping) and isinstance(job, Mapping):
            value = job.get("card_contract")
        if not isinstance(value, Mapping) or not value:
            return None
        by_sleeve[_key_text(key)] = value
    return by_sleeve or None


def _expected_magic_manifest_contract(
    receipts: Mapping[SleeveKey, Mapping[str, Any]],
) -> dict[str, Any] | None:
    result: dict[str, Any] = {}
    for key, receipt in receipts.items():
        job = receipt.get("job")
        source = job.get("expected_magic_source") if isinstance(job, Mapping) else None
        raw_path = source.get("manifest_path") if isinstance(source, Mapping) else None
        if not isinstance(raw_path, str) or not Path(raw_path).is_absolute():
            return None
        try:
            resolved = Path(raw_path).resolve(strict=True)
        except (OSError, RuntimeError):
            return None
        result[_key_text(key)] = {
            "path": str(resolved),
            "sha256": source.get("manifest_sha256"),
        }
    return result or None


def _compare_contracts(
    summary_a: Mapping[str, Any],
    summary_b: Mapping[str, Any],
    receipts_a: Mapping[SleeveKey, Mapping[str, Any]],
    receipts_b: Mapping[SleeveKey, Mapping[str, Any]],
) -> tuple[str | None, dict[str, dict[str, Any]], list[str]]:
    issues: list[str] = []
    manifest_a = summary_a.get("manifest_sha256")
    manifest_b = summary_b.get("manifest_sha256")
    source_manifest = str(manifest_a).lower() if _valid_sha(manifest_a) and manifest_a == manifest_b else None
    if source_manifest is None:
        issues.append("SOURCE_MANIFEST_CONTRACT_MISMATCH_OR_INVALID")

    contracts: dict[str, tuple[Any, Any]] = {
        "runner": (
            {"runner_sha256": summary_a.get("runner_sha256")},
            {"runner_sha256": summary_b.get("runner_sha256")},
        ),
        "expected_magic_manifest": (
            _expected_magic_manifest_contract(receipts_a),
            _expected_magic_manifest_contract(receipts_b),
        ),
        "card": (
            _card_contract(summary_a, receipts_a),
            _card_contract(summary_b, receipts_b),
        ),
        "artifact_override": (
            summary_a.get("artifact_override_manifest"),
            summary_b.get("artifact_override_manifest"),
        ),
        "reference": (
            summary_a.get("reference_snapshot"),
            summary_b.get("reference_snapshot"),
        ),
        "cost": (
            summary_a.get("execution_cost_evidence_manifest"),
            summary_b.get("execution_cost_evidence_manifest"),
        ),
        "window": (summary_a.get("window_contract"), summary_b.get("window_contract")),
    }
    results: dict[str, dict[str, Any]] = {}
    for name, (left, right) in contracts.items():
        left_present = isinstance(left, (Mapping, list)) and bool(left)
        right_present = isinstance(right, (Mapping, list)) and bool(right)
        left_hash = canonical_json_sha(left) if left_present else None
        right_hash = canonical_json_sha(right) if right_present else None
        hash_bound = True if name == "window" else (
            left_present and right_present and _contract_has_hash(left) and _contract_has_hash(right)
        )
        matched = left_present and right_present and left_hash == right_hash
        status = "PASS" if matched and hash_bound else "FAIL"
        results[name] = {
            "status": status,
            "summary_a_contract_sha256": left_hash,
            "summary_b_contract_sha256": right_hash,
            "hash_bound": hash_bound,
        }
        if not left_present or not right_present:
            issues.append(f"{name.upper()}_CONTRACT_MISSING")
        elif not hash_bound:
            issues.append(f"{name.upper()}_CONTRACT_NOT_HASH_BOUND")
        elif not matched:
            issues.append(f"{name.upper()}_CONTRACT_MISMATCH")

    for label, summary in (("A", summary_a), ("B", summary_b)):
        artifact = summary.get("artifact_override_manifest")
        if isinstance(artifact, Mapping):
            if artifact.get("source_manifest_sha256") != summary.get("manifest_sha256"):
                issues.append(f"SUMMARY_{label}_ARTIFACT_OVERRIDE_SOURCE_MANIFEST_MISMATCH")
        cost = summary.get("execution_cost_evidence_manifest")
        if isinstance(cost, Mapping):
            if cost.get("source_manifest_sha256") != summary.get("manifest_sha256"):
                issues.append(f"SUMMARY_{label}_COST_SOURCE_MANIFEST_MISMATCH")
    return source_manifest, results, sorted(set(issues))


def _sandbox_paths(
    label: str,
    summary: Mapping[str, Any],
    receipts: Mapping[SleeveKey, Mapping[str, Any]],
) -> tuple[list[Path], Path | None, list[str]]:
    issues: list[str] = []
    paths: list[Path] = []
    for key, receipt in receipts.items():
        execution = receipt.get("execution")
        raw = execution.get("sandbox") if isinstance(execution, Mapping) else None
        if not isinstance(raw, str) or not raw.strip():
            issues.append(f"SUMMARY_{label}_SANDBOX_MISSING:{_key_text(key)}")
            continue
        path = Path(raw).resolve()
        if _is_forbidden_sandbox(path):
            issues.append(f"SUMMARY_{label}_SANDBOX_FORBIDDEN:{_key_text(key)}")
        paths.append(path)
    unique = {_path_id(path): path for path in paths}
    common_raw = summary.get("common_root")
    common = Path(common_raw).resolve() if isinstance(common_raw, str) and common_raw.strip() else None
    if common is None:
        issues.append(f"SUMMARY_{label}_COMMON_ROOT_MISSING")
    if summary.get("common_root_isolated_from_live") is not True:
        issues.append(f"SUMMARY_{label}_COMMON_ROOT_NOT_ISOLATED_FROM_LIVE")
    return sorted(unique.values(), key=_path_id), common, sorted(set(issues))


def _run_interval(
    label: str,
    receipts: Mapping[tuple[int, str, str, str], Mapping[str, Any]],
) -> tuple[dict[str, Any] | None, list[str]]:
    """Return the complete receipt interval for one designated run."""

    starts: list[dt.datetime] = []
    finishes: list[dt.datetime] = []
    issues: list[str] = []
    for key, receipt in receipts.items():
        execution = receipt.get("execution")
        if not isinstance(execution, Mapping):
            issues.append(f"SUMMARY_{label}_EXECUTION_INTERVAL_MISSING:{_key_text(key)}")
            continue
        parsed: list[dt.datetime] = []
        for field in ("started_utc", "finished_utc"):
            raw = execution.get(field)
            try:
                stamp = dt.datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
            except (TypeError, ValueError):
                issues.append(
                    f"SUMMARY_{label}_EXECUTION_{field.upper()}_INVALID:{_key_text(key)}"
                )
                parsed = []
                break
            if stamp.tzinfo is None:
                issues.append(
                    f"SUMMARY_{label}_EXECUTION_{field.upper()}_NOT_UTC:{_key_text(key)}"
                )
                parsed = []
                break
            parsed.append(stamp.astimezone(dt.UTC))
        if len(parsed) != 2:
            continue
        if parsed[0] > parsed[1]:
            issues.append(f"SUMMARY_{label}_EXECUTION_INTERVAL_REVERSED:{_key_text(key)}")
            continue
        starts.append(parsed[0])
        finishes.append(parsed[1])
    if issues or len(starts) != len(receipts) or not starts:
        return None, sorted(set(issues or [f"SUMMARY_{label}_EXECUTION_INTERVAL_INCOMPLETE"]))
    return {
        "started_utc": min(starts).isoformat(),
        "finished_utc": max(finishes).isoformat(),
        "receipt_count": len(receipts),
    }, []


def _descriptor_from_explicit(receipt: Mapping[str, Any], axis: str) -> tuple[dict[str, Any] | None, str | None]:
    containers = (
        "reproducibility_identity",
        "reproducibility_identity_axes",
        "identity_axes",
    )
    declarations: list[tuple[str, Any]] = []
    for container_name in containers:
        container = receipt.get(container_name)
        if not isinstance(container, Mapping):
            continue
        for alias in AXIS_ALIASES[axis]:
            if alias in container:
                declarations.append(
                    (f"{container_name}.{alias}", container.get(alias))
                )
    if len(declarations) > 1:
        return {
            "__declaration_error__": "multiple explicit declarations for one axis"
        }, ",".join(name for name, _value in declarations)
    if declarations:
        name, value = declarations[0]
        if not isinstance(value, Mapping):
            return {"__declaration_error__": "explicit declaration is not an object"}, name
        return dict(value), name
    return None, None


def _descriptor_value(raw: Mapping[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    if "__declaration_error__" in raw:
        return None, str(raw["__declaration_error__"])
    complete = raw.get("complete") is True
    count_fields = [
        field
        for field in (
            "count",
            "row_count",
            "identity_count",
            "event_count",
            "observation_count",
        )
        if field in raw
    ]
    sha_fields = [
        field
        for field in (
            "sha256",
            "sequence_sha256",
            "identity_sha256",
            "events_sha256",
            "observations_sha256",
        )
        if field in raw
    ]
    if len(count_fields) != 1:
        return None, "descriptor must declare exactly one count field"
    if len(sha_fields) != 1:
        return None, "descriptor must declare exactly one SHA-256 field"
    count = raw.get(count_fields[0])
    identity_sha = raw.get(sha_fields[0])
    if not complete:
        return None, "complete flag is not true"
    if not isinstance(count, int) or isinstance(count, bool) or count <= 0:
        return None, "count is missing, non-integer, or zero"
    if not _valid_sha(identity_sha):
        return None, "identity SHA-256 is missing or invalid"
    return {
        "count": count,
        "sha256": str(identity_sha).lower(),
        "descriptor_sha256": canonical_json_sha(raw),
    }, None


def _fallback_axis(receipt: Mapping[str, Any], axis: str) -> tuple[dict[str, Any] | None, dict[str, Any] | None, str | None]:
    """Return (complete descriptor, partial observation, source field)."""

    q08_identity = receipt.get("q08_signal_identity")
    q08_stats = receipt.get("q08_trade_stats")
    identity = receipt.get("identity")
    if axis == "trades" and isinstance(q08_identity, Mapping) and isinstance(q08_stats, Mapping) and isinstance(identity, Mapping):
        count = q08_stats.get("trades")
        stream_sha = identity.get("q08_stream_sha256")
        if (
            isinstance(count, int)
            and count > 0
            and q08_identity.get("row_count") == count
            and _valid_sha(stream_sha)
        ):
            return {"count": count, "sha256": str(stream_sha).lower(), "descriptor_sha256": canonical_json_sha({"count": count, "sha256": str(stream_sha).lower(), "basis": "complete_q08_trade_stream"})}, None, "identity.q08_stream_sha256"
    if axis == "signals" and isinstance(q08_identity, Mapping):
        count = q08_identity.get("identity_count")
        signal_sha = q08_identity.get("identity_sha256")
        if q08_identity.get("identity_complete") is True and isinstance(count, int) and count > 0 and _valid_sha(signal_sha):
            return {"count": count, "sha256": str(signal_sha).lower(), "descriptor_sha256": canonical_json_sha({"count": count, "sha256": str(signal_sha).lower(), "basis": "q08_entry_close_symbol_identity"})}, None, "q08_signal_identity"
    if axis == "entries" and isinstance(q08_identity, Mapping):
        partial = {
            "signal_identity_count": q08_identity.get("identity_count"),
            "signal_identity_sha256": q08_identity.get("identity_sha256"),
            "missing": "ordered entry side and entry-price identity",
        }
        return None, partial, "q08_signal_identity"
    if axis == "exits" and isinstance(q08_stats, Mapping):
        partial = {
            "close_time_count": q08_stats.get("close_time_count"),
            "close_times_sha256": q08_stats.get("close_times_sha256"),
            "missing": "ordered exit-reason identity",
        }
        return None, partial, "q08_trade_stats"
    if axis == "pnl" and isinstance(q08_identity, Mapping) and isinstance(q08_stats, Mapping):
        partial = {
            "aggregate_net": q08_stats.get("net"),
            "outcome_sign_count": q08_identity.get("outcome_sign_count"),
            "outcome_sign_sha256": q08_identity.get("outcome_sign_sha256"),
            "missing": "ordered exact per-trade PnL identity",
        }
        return None, partial, "q08_signal_identity+q08_trade_stats"
    if axis == "outcome_signs" and isinstance(q08_identity, Mapping):
        count = q08_identity.get("outcome_sign_count")
        outcome_sha = q08_identity.get("outcome_sign_sha256")
        if (
            q08_identity.get("outcome_sign_complete") is True
            and isinstance(count, int)
            and count > 0
            and _valid_sha(outcome_sha)
        ):
            return {
                "count": count,
                "sha256": str(outcome_sha).lower(),
                "descriptor_sha256": canonical_json_sha(
                    {
                        "count": count,
                        "sha256": str(outcome_sha).lower(),
                        "basis": "q08_ordered_outcome_sign_identity",
                    }
                ),
            }, None, "q08_signal_identity"
    if axis == "lots":
        return None, {"missing": "ordered lot-size identity"}, None
    if axis == "mtm":
        return None, {"missing": "ordered mark-to-market identity"}, None
    if axis == "daily_mtm":
        return None, {"missing": "ordered daily mark-to-market identity"}, None
    if axis == "margin":
        return None, {"missing": "ordered used/free/stressed margin identity"}, None
    return None, None, None


def _axis_for_receipt(
    receipt: Mapping[str, Any],
    axis: str,
    physical: Mapping[str, Any] | None,
) -> dict[str, Any]:
    raw, source = _descriptor_from_explicit(receipt, axis)
    if raw is not None:
        value, error = _descriptor_value(raw)
        physical_issue: str | None = None
        if value is not None:
            if not isinstance(physical, Mapping) or physical.get("complete") is not True:
                error = "complete descriptor has no complete physical sequence"
                physical_issue = "PHYSICAL_SEQUENCE_UNAVAILABLE"
                value = None
            elif (
                physical.get("count") != value.get("count")
                or physical.get("sha256") != value.get("sha256")
            ):
                error = "complete descriptor count/SHA-256 differs from physical sequence"
                physical_issue = "PHYSICAL_SEQUENCE_MISMATCH"
                value = None
        return {
            "complete": value is not None,
            "value": value,
            "source_field": source,
            "partial_observation": None,
            "error": error,
            "physical_issue": physical_issue,
        }
    _value, partial, source = _fallback_axis(receipt, axis)
    return {
        "complete": False,
        "value": None,
        "source_field": source,
        "partial_observation": partial,
        "error": "required explicit complete axis is unavailable",
        "physical_issue": None,
    }


def _compare_identity_axes(
    receipts_a: Mapping[SleeveKey, Mapping[str, Any]],
    receipts_b: Mapping[SleeveKey, Mapping[str, Any]],
    physical_a: Mapping[SleeveKey, Mapping[str, Mapping[str, Any]]],
    physical_b: Mapping[SleeveKey, Mapping[str, Mapping[str, Any]]],
) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]], list[str]]:
    issues: list[str] = []
    keys_a = set(receipts_a)
    keys_b = set(receipts_b)
    all_keys = sorted(keys_a | keys_b)
    if keys_a != keys_b:
        issues.append("COMPARED_SLEEVE_SET_MISMATCH")
    axis_results: dict[str, dict[str, Any]] = {}
    sleeve_rows: dict[SleeveKey, dict[str, Any]] = {
        key: {
            "ea_id": key[0],
            "symbol": key[1],
            "timeframe": key[2],
            "variant_id": key[3],
            "status": "PASS",
            "identity_axes": {},
        }
        for key in all_keys
    }
    for key in sorted(keys_a & keys_b):
        job_a = _normalized_job_contract(receipts_a[key])
        job_b = _normalized_job_contract(receipts_b[key])
        if job_a != job_b:
            issues.append(f"SLEEVE_JOB_CONTRACT_MISMATCH:{_key_text(key)}")
            sleeve_rows[key]["status"] = "FAIL"
    for axis in REQUIRED_IDENTITY_AXES:
        matched: list[str] = []
        missing: list[str] = []
        mismatched: list[str] = []
        invalid: list[str] = []
        source_fields: set[str] = set()
        partial_observations: dict[str, Any] = {}
        physical_validation_errors: dict[str, Any] = {}
        for key in all_keys:
            key_text = _key_text(key)
            if key not in receipts_a or key not in receipts_b:
                missing.append(key_text)
                sleeve_rows[key]["identity_axes"][axis] = "MISSING"
                sleeve_rows[key]["status"] = "FAIL"
                continue
            left = _axis_for_receipt(
                receipts_a[key], axis, physical_a.get(key, {}).get(axis)
            )
            right = _axis_for_receipt(
                receipts_b[key], axis, physical_b.get(key, {}).get(axis)
            )
            for label, observation in (("A", left), ("B", right)):
                physical_issue = observation.get("physical_issue")
                if physical_issue:
                    issues.append(
                        f"SUMMARY_{label}_IDENTITY_AXIS_{physical_issue}:"
                        f"{axis}:{key_text}"
                    )
                    physical_validation_errors.setdefault(key_text, {})[
                        f"summary_{label.lower()}"
                    ] = observation.get("error")
            if left.get("source_field"):
                source_fields.add(str(left["source_field"]))
            if right.get("source_field"):
                source_fields.add(str(right["source_field"]))
            if left.get("partial_observation") is not None or right.get("partial_observation") is not None:
                partial_observations[key_text] = {
                    "summary_a": left.get("partial_observation"),
                    "summary_b": right.get("partial_observation"),
                    "partial_match": left.get("partial_observation") == right.get("partial_observation"),
                }
            if not left["complete"] or not right["complete"]:
                missing.append(key_text)
                if left.get("error") != "required explicit complete axis is unavailable" or right.get("error") != "required explicit complete axis is unavailable":
                    invalid.append(key_text)
                sleeve_rows[key]["identity_axes"][axis] = "MISSING"
                sleeve_rows[key]["status"] = "FAIL"
            elif left["value"] != right["value"]:
                mismatched.append(key_text)
                sleeve_rows[key]["identity_axes"][axis] = "MISMATCH"
                sleeve_rows[key]["status"] = "FAIL"
            else:
                matched.append(key_text)
                sleeve_rows[key]["identity_axes"][axis] = "PASS"
        status = "PASS" if len(matched) == len(all_keys) and all_keys else "FAIL"
        axis_results[axis] = {
            "status": status,
            "required": True,
            "matched_sleeves": matched,
            "missing_sleeves": sorted(set(missing)),
            "mismatched_sleeves": sorted(set(mismatched)),
            "invalid_sleeves": sorted(set(invalid)),
            "source_fields": sorted(source_fields),
            "partial_observations": partial_observations,
            "physical_validation_errors": physical_validation_errors,
        }
        if missing:
            issues.append(f"IDENTITY_AXIS_MISSING:{axis}")
        if invalid:
            issues.append(f"IDENTITY_AXIS_INVALID:{axis}")
        if mismatched:
            issues.append(f"IDENTITY_AXIS_MISMATCH:{axis}")

    # Trade-like sequence counts must agree inside each receipt.  MTM has a
    # denser sampling cadence and is intentionally excluded from this equality.
    for label, receipts, physical in (
        ("A", receipts_a, physical_a),
        ("B", receipts_b, physical_b),
    ):
        for key, receipt in receipts.items():
            counts: dict[str, int] = {}
            for axis in (
                "trades",
                "signals",
                "entries",
                "exits",
                "lots",
                "outcome_signs",
                "pnl",
            ):
                result = _axis_for_receipt(
                    receipt, axis, physical.get(key, {}).get(axis)
                )
                value = result.get("value")
                if isinstance(value, Mapping) and isinstance(value.get("count"), int):
                    counts[axis] = int(value["count"])
            if len(counts) == 7 and len(set(counts.values())) != 1:
                issues.append(f"SUMMARY_{label}_IDENTITY_AXIS_COUNT_MISMATCH:{_key_text(key)}")

    return axis_results, [sleeve_rows[key] for key in all_keys], sorted(set(issues))


def evaluate_pair(
    binding_a: Mapping[str, Any],
    summary_a: Mapping[str, Any] | None,
    binding_b: Mapping[str, Any],
    summary_b: Mapping[str, Any] | None,
    initial_issues: Sequence[str] = (),
) -> dict[str, Any]:
    issues = list(initial_issues)
    receipts_a, summary_a_issues = validate_summary("A", summary_a)
    receipts_b, summary_b_issues = validate_summary("B", summary_b)
    issues.extend(summary_a_issues)
    issues.extend(summary_b_issues)
    (
        runtime_bindings_a,
        runtime_issues_a,
        physical_axes_a,
    ) = _runtime_artifact_bindings_for_summary("A", binding_a, receipts_a)
    (
        runtime_bindings_b,
        runtime_issues_b,
        physical_axes_b,
    ) = _runtime_artifact_bindings_for_summary("B", binding_b, receipts_b)
    issues.extend(runtime_issues_a)
    issues.extend(runtime_issues_b)

    source_manifest: str | None = None
    contracts: dict[str, dict[str, Any]] = {}
    identity_axes: dict[str, dict[str, Any]] = {
        axis: {
            "status": "FAIL",
            "required": True,
            "matched_sleeves": [],
            "missing_sleeves": [],
            "mismatched_sleeves": [],
            "invalid_sleeves": [],
            "source_fields": [],
            "partial_observations": {},
            "physical_validation_errors": {},
        }
        for axis in REQUIRED_IDENTITY_AXES
    }
    compared_sleeves: list[dict[str, Any]] = []
    run_intervals: dict[str, Any] = {
        "summary_a": None,
        "summary_b": None,
        "serial_non_overlapping": False,
    }
    if summary_a is not None and summary_b is not None:
        run_a = summary_a.get("run_id")
        run_b = summary_b.get("run_id")
        if not isinstance(run_a, str) or not run_a.strip() or not isinstance(run_b, str) or not run_b.strip():
            issues.append("RUN_ID_MISSING")
        elif run_a == run_b:
            issues.append("RUN_ID_NOT_DISTINCT")

        source_manifest, contracts, contract_issues = _compare_contracts(
            summary_a, summary_b, receipts_a, receipts_b
        )
        issues.extend(contract_issues)
        sandboxes_a, common_a, sandbox_issues_a = _sandbox_paths(
            "A", summary_a, receipts_a
        )
        sandboxes_b, common_b, sandbox_issues_b = _sandbox_paths(
            "B", summary_b, receipts_b
        )
        issues.extend(sandbox_issues_a)
        issues.extend(sandbox_issues_b)
        interval_a, interval_issues_a = _run_interval("A", receipts_a)
        interval_b, interval_issues_b = _run_interval("B", receipts_b)
        issues.extend(interval_issues_a)
        issues.extend(interval_issues_b)
        serial_non_overlapping = False
        if interval_a is not None and interval_b is not None:
            end_a = dt.datetime.fromisoformat(interval_a["finished_utc"])
            start_a = dt.datetime.fromisoformat(interval_a["started_utc"])
            end_b = dt.datetime.fromisoformat(interval_b["finished_utc"])
            start_b = dt.datetime.fromisoformat(interval_b["started_utc"])
            serial_non_overlapping = end_a <= start_b or end_b <= start_a
            if not serial_non_overlapping:
                issues.append("DESIGNATED_RUN_INTERVALS_OVERLAP")
        run_intervals = {
            "summary_a": interval_a,
            "summary_b": interval_b,
            "serial_non_overlapping": serial_non_overlapping,
        }
        for left in sandboxes_a:
            for right in sandboxes_b:
                if _paths_overlap(left, right):
                    issues.append("RUN_SANDBOXES_NOT_ISOLATED")
        if common_a is not None and common_b is not None:
            if _paths_overlap(common_a, common_b):
                issues.append("RUN_COMMON_ROOTS_NOT_ISOLATED")
            for sandbox in sandboxes_a:
                if _paths_overlap(common_a, sandbox):
                    issues.append("SUMMARY_A_COMMON_ROOT_OVERLAPS_SANDBOX")
            for sandbox in sandboxes_b:
                if _paths_overlap(common_b, sandbox):
                    issues.append("SUMMARY_B_COMMON_ROOT_OVERLAPS_SANDBOX")
            for sandbox in sandboxes_b:
                if _paths_overlap(common_a, sandbox):
                    issues.append(
                        "SUMMARY_A_COMMON_ROOT_OVERLAPS_SUMMARY_B_SANDBOX"
                    )
            for sandbox in sandboxes_a:
                if _paths_overlap(common_b, sandbox):
                    issues.append(
                        "SUMMARY_B_COMMON_ROOT_OVERLAPS_SUMMARY_A_SANDBOX"
                    )

        identity_axes, compared_sleeves, identity_issues = _compare_identity_axes(
            receipts_a, receipts_b, physical_axes_a, physical_axes_b
        )
        issues.extend(identity_issues)

    issues = sorted(set(issues))
    runner_gaps = [
        axis
        for axis, row in identity_axes.items()
        if row.get("missing_sleeves")
    ]
    result: dict[str, Any] = {
        "artifact_type": ARTIFACT_TYPE,
        "schema_version": SCHEMA_VERSION,
        "status": "FAIL" if issues else "PASS",
        "qualification_mode": QUALIFICATION_MODE,
        "source_manifest_sha256": source_manifest,
        "summary_a": dict(binding_a),
        "summary_b": dict(binding_b),
        "compared_sleeves": compared_sleeves,
        "run_intervals": run_intervals,
        "contracts": contracts,
        "runtime_artifact_bindings": {
            "summary_a": runtime_bindings_a,
            "summary_b": runtime_bindings_b,
        },
        "identity_axes": identity_axes,
        "runner_contract_gap": {
            "status": "OPEN" if runner_gaps else "CLOSED",
            "missing_required_axes": runner_gaps,
            "required_receipt_field": "reproducibility_identity",
            "note": (
                "The runner emits complete trade, signal, exit-time/reason, lot, "
                "outcome-sign and exact per-trade PnL sequence hashes when the physical "
                "Q08/log join is bijective. Actual entry fill price, daily/intraday MTM "
                "and used/free/stressed margin still need explicit complete telemetry."
                if runner_gaps
                else "All required per-sleeve identity axes were supplied explicitly or by a complete receipt field."
            ),
        },
        "issues": issues,
        "deployment_eligible": False,
    }
    result["pair_payload_sha256"] = embedded_hash(result, "pair_payload_sha256")
    return result


def write_immutable_result(path: Path, payload: Mapping[str, Any]) -> tuple[Path, Path]:
    resolved = path.resolve()
    if _is_forbidden_sandbox(resolved):
        raise PermissionError(
            f"refusing gate output below T_Live or T1-T10: {resolved}"
        )
    sidecar = resolved.with_name(resolved.name + ".sha256")
    if resolved.exists() or sidecar.exists():
        raise FileExistsError("refusing to overwrite immutable gate output or sidecar")
    if not resolved.parent.is_dir():
        raise FileNotFoundError(f"output parent does not exist: {resolved.parent}")
    encoded = (json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
    with resolved.open("xb") as handle:
        handle.write(encoded)
    file_sha = sha256_file(resolved)
    with sidecar.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(f"{file_sha}  {resolved.name}\n")
    return resolved, sidecar


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary-a", type=Path, required=True)
    parser.add_argument("--summary-a-sha256", required=True)
    parser.add_argument("--summary-a-sidecar", type=Path)
    parser.add_argument("--summary-b", type=Path, required=True)
    parser.add_argument("--summary-b-sha256", required=True)
    parser.add_argument("--summary-b-sidecar", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    binding_a, summary_a, issues_a = load_summary_binding(
        "A", args.summary_a, args.summary_a_sha256, args.summary_a_sidecar
    )
    binding_b, summary_b, issues_b = load_summary_binding(
        "B", args.summary_b, args.summary_b_sha256, args.summary_b_sidecar
    )
    result = evaluate_pair(
        binding_a,
        summary_a,
        binding_b,
        summary_b,
        [*issues_a, *issues_b],
    )
    try:
        output, sidecar = write_immutable_result(args.output, result)
    except (FileExistsError, FileNotFoundError, PermissionError, OSError) as exc:
        print(json.dumps({"status": "ERROR", "error": str(exc)}), file=sys.stderr)
        return 3
    print(
        json.dumps(
            {
                "status": result["status"],
                "output": str(output),
                "sidecar": str(sidecar),
                "issues": len(result["issues"]),
            },
            sort_keys=True,
        )
    )
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
