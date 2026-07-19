#!/usr/bin/env python3
"""Read-only validator for the DXZ 12567 XAUUSD.DWX D1 repair packet.

The module never starts MT5 and never writes into a terminal.  A qualifying
bundle needs two unreferenced serial baselines, an OWNER seal outside every run
root, and two later serial reproductions of the sealed consensus.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import datetime as dt
import hashlib
import json
import math
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
except ImportError:  # pragma: no cover - qualification must fail closed
    InvalidSignature = Exception  # type: ignore[assignment,misc]
    Ed25519PublicKey = None  # type: ignore[assignment,misc]

try:
    from .dxz_as_live_requal import (
        RequalError,
        load_execution_cost_evidence_manifest,
        verify_execution_cost_evidence_unchanged,
    )
    from .dxz_cost_evidence import (
        CostEvidenceError,
        _report_rows,
        _report_stats,
        extract_round_trips,
    )
except ImportError:  # pragma: no cover - direct script execution
    try:
        from dxz_as_live_requal import (  # type: ignore
            RequalError,
            load_execution_cost_evidence_manifest,
            verify_execution_cost_evidence_unchanged,
        )
        from dxz_cost_evidence import (  # type: ignore
            CostEvidenceError,
            _report_rows,
            _report_stats,
            extract_round_trips,
        )
    except ImportError:  # pragma: no cover - qualification must fail closed
        RequalError = Exception  # type: ignore[assignment,misc]
        CostEvidenceError = Exception  # type: ignore[assignment,misc]
        load_execution_cost_evidence_manifest = None  # type: ignore[assignment]
        verify_execution_cost_evidence_unchanged = None  # type: ignore[assignment]
        _report_rows = None  # type: ignore[assignment]
        _report_stats = None  # type: ignore[assignment]
        extract_round_trips = None  # type: ignore[assignment]


SPEC_ARTIFACT = "DXZ_12567_XAUUSD_D1_REPAIR_SPEC"
BUNDLE_ARTIFACT = "DXZ_12567_XAUUSD_D1_REQUAL_BUNDLE"
RECEIPT_ARTIFACT = "DXZ_12567_XAUUSD_D1_SEGMENTED_RUN_RECEIPT"
SEAL_ARTIFACT = "DXZ_12567_XAUUSD_D1_OWNER_SEAL"
SEALED_INPUT_ARTIFACT = "DXZ_12567_XAUUSD_D1_SEALED_INPUT_MANIFEST"
COST_AXIS_ARTIFACT = "DXZ_EXECUTION_COST_AXIS_EVIDENCE"
DATA_MANIFEST_ARTIFACT = "DXZ_LITERAL_DWX_DATA_FILE_MANIFEST"
INSTRUMENT_SNAPSHOT_ARTIFACT = "DXZ_XAU_EUR_INSTRUMENT_SNAPSHOT"
EXTRACTOR_RECEIPT_ARTIFACT = "DXZ_IDENTITY_EXTRACTOR_EXECUTION_RECEIPT"
OWNER_DECISION_ARTIFACT = "DXZ_OWNER_SIGNED_DECISION"
COST_SOURCE_MANIFEST_ARTIFACT = "DXZ_12567_XAUUSD_D1_COST_SOURCE_MANIFEST"
WEEKEND_CALENDAR_ARTIFACT = "DXZ_XAU_WEEKEND_FLAT_BROKER_CALENDAR"
WEEKEND_CALENDAR_SOURCE_ARTIFACT = "DXZ_BROKER_TRADABLE_SESSION_CALENDAR_EXPORT"
PACKET_ID = "DXZ-12567-XAUUSD-DWX-D1-20260716"
WEEKEND_CUTOFF_POLICY = (
    "MIN_FRIDAY_21_BROKER_AND_LAST_TRADABLE_SESSION_CLOSE_BEFORE_WEEKEND"
)
WEEKEND_RUNTIME_MARKER = "QM_WEEKEND_FLAT_DEADLINE_V1"
WEEKEND_RUNTIME_HANDLER = "QM_EnforceWeekendFlatDeadline"

CANONICAL_COST_V3_SHA256 = (
    "98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd"
)
CANONICAL_COST_V3_PAYLOAD_SHA256 = (
    "a3cd2748ddffd571152203bf6485eaeb8b1285614715929523e4e9ce2314fbb6"
)
CANONICAL_COST_RATE_UNIT = (
    "0.00005 decimal = 0.005 percent = 0.5 basis points round-trip"
)
QUALIFICATION_WINDOW = {
    "requested_from_date": "2018-03-01",
    "requested_to_date": "2025-12-31",
    "effective_from_date": "2018-03-01",
    "effective_to_date": "2025-12-31",
}

SHA_RE = re.compile(r"^[0-9a-f]{64}$")
BROKER_TIME_RE = re.compile(
    r"^[0-9]{4}\.[0-9]{2}\.[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
)
SANDBOX_RE = re.compile(r"^DXZ_Truth_[A-Za-z0-9_-]+$", re.IGNORECASE)
FORBIDDEN_ROOT_RE = re.compile(r"^(?:T(?:10|[1-9])|T_Live)$", re.IGNORECASE)
FORBIDDEN_SELF_KEYS = {
    "self_path",
    "self_sha256",
    "bundle_path",
    "bundle_sha256",
}
SPEC_SELF_KEYS = FORBIDDEN_SELF_KEYS | {"spec_path", "spec_sha256"}
COMMON_DUMMY_SHA256 = {
    character * 64 for character in "0123456789abcdef"
} | {
    "0123456789abcdef" * 4,
    "abcdef0123456789" * 4,
    "deadbeef" * 8,
}

SEGMENTS = ("S0", "S1", "S2", "S3")
SEGMENT_ROLES = {
    "S0": "INFERENCE",
    "S1": "INFERENCE",
    "S2": "CONTINUITY_ONLY",
    "S3": "CONTINUITY_ONLY",
}
SEGMENT_NATIVE_DATA_WINDOWS = {
    "S0": ("2017-10-02", "2023-12-13"),
    "S1": ("2023-12-18", "2025-10-09"),
    "S2": ("2025-11-03", "2025-12-18"),
    "S3": ("2025-12-22", "2026-01-01"),
}
REQUIRED_DWX = ("EURUSD.DWX", "XAUUSD.DWX")
IDENTITY_FIELDS = (
    "segment_id",
    "trade_index",
    "symbol",
    "side",
    "signal_bar_open_mt5_server",
    "signal_value",
    "entry_time_mt5_server",
    "entry_price",
    "entry_reason",
    "initial_stop",
    "initial_target",
    "exit_time_mt5_server",
    "exit_price",
    "exit_reason",
    "volume",
    "gross_profit",
    "swap",
    "commission",
    "net_profit",
    "gross_profit_sign",
)
IDENTITY_AXES = (
    "signal_identity_sha256",
    "entry_identity_sha256",
    "exit_identity_sha256",
    "outcome_sign_sha256",
    "lot_identity_sha256",
    "pnl_identity_sha256",
    "full_round_trip_identity_sha256",
)
COST_AXES = (
    "commission",
    "historical_tester_spread",
    "current_broker_spread_parity",
    "current_broker_swap_rate_parity",
    "slippage_stress",
)
OWNER_GATE_IDS = (
    "SOURCE_SEMANTICS_AND_CARD_V2",
    "FRIDAY_CLOSE_POLICY",
    "NEWS_POLICY",
    "AS_LIVE_RISK_CONTRACT",
    "SOURCE_OF_RECORD_BUILD",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha(value: Any) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _load_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON object {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def _valid_sha(value: Any) -> bool:
    return (
        isinstance(value, str)
        and SHA_RE.fullmatch(value.lower()) is not None
        and value.lower() not in COMMON_DUMMY_SHA256
    )


def _parse_utc(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(dt.timezone.utc)


def _parse_broker_time(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or BROKER_TIME_RE.fullmatch(value) is None:
        return None
    try:
        return dt.datetime.strptime(value, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return None


def _decimal(value: Any) -> Decimal | None:
    if isinstance(value, bool):
        return None
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    return parsed if parsed.is_finite() else None


def _path_key(path: Path) -> str:
    return str(path.resolve(strict=False)).replace("/", "\\").casefold()


def _within(child: Path, parent: Path) -> bool:
    child_key = _path_key(child)
    parent_key = _path_key(parent).rstrip("\\")
    return child_key == parent_key or child_key.startswith(parent_key + "\\")


def _forbidden_execution_path(path: Path) -> bool:
    return any(FORBIDDEN_ROOT_RE.fullmatch(part) for part in path.parts)


def _under_mt5_tree(path: Path) -> bool:
    """Identify terminal/export trees, without relying on a particular drive."""

    return any(part.casefold() == "mt5" for part in path.resolve(strict=False).parts)


def _strictly_nested(left: Path, right: Path) -> bool:
    return _path_key(left) != _path_key(right) and (
        _within(left, right) or _within(right, left)
    )


def _require_within_own_output(
    path: Path, output_root: Path, *, label: str, checks: "Checks"
) -> None:
    checks.require(
        _within(path, output_root),
        "SEGMENT_ARTIFACT_OUTSIDE_OWN_OUTPUT_ROOT",
        f"{label}:{path}",
    )


def _find_forbidden_self_keys(
    value: Any,
    prefix: str = "$",
    *,
    forbidden: set[str] = FORBIDDEN_SELF_KEYS,
) -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).casefold() in forbidden:
                found.append(f"{prefix}.{key}")
            found.extend(
                _find_forbidden_self_keys(child, f"{prefix}.{key}", forbidden=forbidden)
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(
                _find_forbidden_self_keys(child, f"{prefix}[{index}]", forbidden=forbidden)
            )
    return found


class Checks:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.verified_bindings = 0
        self.unique_paths: dict[str, str] = {}
        self.external_paths: dict[str, Path] = {}
        self.binding_paths: list[tuple[str, Path]] = []

    def require(self, condition: bool, code: str, detail: str = "") -> None:
        if not condition:
            self.errors.append(f"{code}: {detail}" if detail else code)

    def binding(
        self,
        raw: Any,
        *,
        label: str,
        base_dir: Path,
        unique: bool = False,
        json_object: bool = False,
        external: bool = False,
    ) -> tuple[Path | None, str | None, dict[str, Any] | None]:
        if not isinstance(raw, Mapping):
            self.errors.append(f"BINDING_INVALID: {label}")
            return None, None, None
        path_text = str(raw.get("path") or "").strip()
        expected = str(raw.get("sha256") or "").strip().lower()
        if not path_text or not _valid_sha(expected):
            self.errors.append(f"BINDING_FIELDS_INVALID: {label}")
            return None, None, None
        path = Path(path_text)
        if not path.is_absolute():
            path = base_dir / path
        path = path.resolve(strict=False)
        self.binding_paths.append((label, path))
        if not path.is_file():
            self.errors.append(f"BINDING_MISSING: {label} -> {path}")
            return path, expected, None
        actual = sha256_file(path)
        if actual != expected:
            self.errors.append(
                f"BINDING_HASH_MISMATCH: {label} expected={expected} actual={actual}"
            )
        if raw.get("bytes") is not None:
            try:
                size_ok = path.stat().st_size == int(raw["bytes"])
            except (TypeError, ValueError):
                size_ok = False
            self.require(size_ok, "BINDING_SIZE_MISMATCH", label)
        if unique:
            key = _path_key(path)
            prior = self.unique_paths.get(key)
            if prior is not None:
                self.errors.append(f"ARTIFACT_PATH_REUSED: {label} also={prior}")
            else:
                self.unique_paths[key] = label
        if external:
            key = _path_key(path)
            prior = self.external_paths.get(label)
            self.require(prior is None, "EXTERNAL_BINDING_LABEL_REUSED", label)
            self.external_paths[label] = path
            self.require(not _forbidden_execution_path(path), "EXTERNAL_ARTIFACT_IN_MT5_ROOT", label)
            self.require(not _under_mt5_tree(path), "EXTERNAL_CONTROL_ARTIFACT_IN_MT5_TREE", label)
        payload: dict[str, Any] | None = None
        if json_object:
            try:
                payload = _load_object(path)
            except ValueError as exc:
                self.errors.append(f"BINDING_JSON_INVALID: {label}: {exc}")
        self.verified_bindings += 1
        return path, actual, payload

    def report(self, **extra: Any) -> dict[str, Any]:
        return {
            "status": "PASS" if not self.errors else "FAIL",
            "error_count": len(self.errors),
            "errors": self.errors,
            "verified_bindings": self.verified_bindings,
            "execution_performed": False,
            **extra,
        }


def _validate_spec_payload(
    spec: Mapping[str, Any], spec_path: Path, checks: Checks, *, verify_anchors: bool
) -> None:
    checks.require(spec.get("schema_version") == 1, "SPEC_SCHEMA_INVALID")
    checks.require(spec.get("artifact_type") == SPEC_ARTIFACT, "SPEC_TYPE_INVALID")
    checks.require(spec.get("packet_id") == PACKET_ID, "SPEC_PACKET_ID_INVALID")
    checks.require(spec.get("deployment_eligible") is False, "SPEC_DEPLOYMENT_SCOPE_INVALID")
    checks.require(
        not _find_forbidden_self_keys(spec, forbidden=SPEC_SELF_KEYS),
        "SPEC_SELF_REFERENCE_FORBIDDEN",
    )

    scope = spec.get("scope") or {}
    expected_scope = {
        "ea_id": 12567,
        "symbol": "XAUUSD.DWX",
        "timeframe": "D1",
        "magic": 125670003,
        "mutation_authority": "NONE",
        "mt5_execution_authority": "NONE",
    }
    for key, value in expected_scope.items():
        checks.require(scope.get(key) == value, "SPEC_SCOPE_INVALID", key)
    checks.require(scope.get("allowed_history") == "literal .DWX only", "SPEC_DATA_SCOPE_INVALID")

    source = spec.get("source_semantics") or {}
    checks.require(source.get("source_archived_copy_present") is False, "SPEC_SOURCE_ARCHIVE_BASELINE_INVALID")
    checks.require(
        source.get("classification")
        == "QM_INTERPRETATION_COMMODITY_PORT_NOT_VERBATIM_SOURCE_STRATEGY",
        "SPEC_SOURCE_CLASSIFICATION_INVALID",
    )
    checks.require(len(source.get("source_defined_rules") or []) == 2, "SPEC_SOURCE_RULES_INVALID")
    checks.require(len(source.get("not_defined_by_cited_page") or []) >= 9, "SPEC_QM_RULES_INCOMPLETE")
    runtime_repair = spec.get("source_runtime_remediation_contract") or {}
    checks.require(
        runtime_repair
        == {
            "status": "BLOCKING_REMEDIATION_REQUIRED",
            "observed_source_sha256": "e40bea7e231ca7366feaa7e4ce0e9f6cc823a39cd6640535a157fe8747bb4025",
            "observed_defect": "NEWS_RETURNS_PRECEDE_MANDATORY_FRIDAY_CLOSE",
            "required_runtime_marker": WEEKEND_RUNTIME_MARKER,
            "required_weekend_handler": WEEKEND_RUNTIME_HANDLER,
            "required_order": [
                "KILL_SWITCH_GUARD_WITH_BOUND_FLATTEN_AND_60S_RETRY",
                "WEEKEND_DEADLINE_HANDLER",
                "FRAMEWORK_FRIDAY_21_HANDLER",
                "NEWS_AND_ENTRY_FILTERS",
            ],
            "current_source_qualification_eligible": False,
        },
        "SPEC_SOURCE_RUNTIME_REMEDIATION_INVALID",
    )

    diagnostic = (spec.get("baseline") or {}).get("legacy_identity_diagnostic") or {}
    expected_identity = {
        "native_round_trips": 73,
        "old_reference_rows": 73,
        "entry_timestamp_matches": 73,
        "exit_timestamp_matches": 73,
        "gross_outcome_sign_matches": 73,
        "lot_matches": 9,
        "old_reference_admissible": False,
    }
    for key, value in expected_identity.items():
        checks.require(diagnostic.get(key) == value, "SPEC_BASELINE_IDENTITY_INVALID", key)
    commission = (spec.get("baseline") or {}).get("commission_adjusted_v3") or {}
    checks.require(commission.get("commission_status") == "COMPLETE", "SPEC_COMMISSION_STATUS_INVALID")
    checks.require(commission.get("qualification_use") is False, "SPEC_COMMISSION_SCOPE_INVALID")
    checks.require(
        math.isclose(float(commission.get("conservative_profit_factor", 0)), 1.5743318807),
        "SPEC_CONSERVATIVE_PF_INVALID",
    )

    candidates = spec.get("risk_contract_candidates") or []
    checks.require(len(candidates) == 3, "SPEC_RISK_CANDIDATE_COUNT_INVALID")
    candidate_ids: set[str] = set()
    for row in candidates:
        if not isinstance(row, Mapping):
            checks.errors.append("SPEC_RISK_CANDIDATE_INVALID")
            continue
        identifier = str(row.get("contract_id") or "")
        checks.require(bool(identifier) and identifier not in candidate_ids, "SPEC_RISK_ID_INVALID", identifier)
        candidate_ids.add(identifier)
        rp = _decimal(row.get("RISK_PERCENT"))
        fixed = _decimal(row.get("RISK_FIXED"))
        weight = _decimal(row.get("PORTFOLIO_WEIGHT"))
        effective = _decimal(row.get("effective_risk_percent"))
        initial = _decimal(row.get("initial_continuous_target_risk_eur"))
        valid_numbers = None not in (rp, fixed, weight, effective, initial)
        checks.require(valid_numbers and fixed == Decimal("0"), "SPEC_RISK_MATH_INVALID", identifier)
        if valid_numbers:
            assert rp is not None and weight is not None and effective is not None and initial is not None
            checks.require(effective == rp * weight, "SPEC_RISK_EFFECTIVE_INVALID", identifier)
            checks.require(
                initial == Decimal("100000") * effective / Decimal("100"),
                "SPEC_RISK_EUR_INVALID",
                identifier,
            )
            if weight == Decimal("1"):
                checks.require(row.get("owner_selectable") is True, "SPEC_SELECTABLE_RISK_INVALID", identifier)
            else:
                checks.require(
                    row.get("owner_selectable") is False
                    and row.get("qualification_class") == "REJECTED_DIMENSIONAL_DOUBLE_SCALING",
                    "SPEC_DOUBLE_SCALING_NOT_REJECTED",
                    identifier,
                )

    gates = spec.get("owner_gates") or []
    gate_ids = tuple(row.get("gate_id") for row in gates if isinstance(row, Mapping))
    checks.require(gate_ids == OWNER_GATE_IDS, "SPEC_OWNER_GATE_SET_INVALID")
    expected_gate_status = {
        "SOURCE_SEMANTICS_AND_CARD_V2": "PENDING",
        "FRIDAY_CLOSE_POLICY": "OWNER_DIRECTIVE_RECORDED_UNSEALED",
        "NEWS_POLICY": "PENDING",
        "AS_LIVE_RISK_CONTRACT": "PENDING",
        "SOURCE_OF_RECORD_BUILD": "PENDING",
    }
    checks.require(
        all(
            row.get("status") == expected_gate_status.get(str(row.get("gate_id")))
            for row in gates
            if isinstance(row, Mapping)
        ),
        "SPEC_OWNER_GATE_BASELINE_STATUS_INVALID",
    )
    friday_gate = next(
        (row for row in gates if isinstance(row, Mapping) and row.get("gate_id") == "FRIDAY_CLOSE_POLICY"),
        {},
    )
    checks.require(
        friday_gate.get("required_decision") == "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER"
        and "allowed_decisions" not in friday_gate,
        "SPEC_FRIDAY_OWNER_DIRECTIVE_INVALID",
    )
    checks.require(
        _parse_utc(friday_gate.get("directive_recorded_utc")) is not None
        and "No weekend holdings" in str(friday_gate.get("directive_basis") or "")
        and "broker hour 21" in str(friday_gate.get("directive_basis") or ""),
        "SPEC_FRIDAY_OWNER_DIRECTIVE_EVIDENCE_INVALID",
    )
    weekend_contract = spec.get("weekend_flat_calendar_contract") or {}
    checks.require(
        weekend_contract
        == {
            "artifact_type": WEEKEND_CALENDAR_ARTIFACT,
            "symbol": "XAUUSD.DWX",
            "timezone_basis": "MT5_BROKER_SERVER_TIME",
            "regular_cutoff": "FRIDAY_21:00:00",
            "effective_cutoff_rule": WEEKEND_CUTOFF_POLICY,
            "coverage": QUALIFICATION_WINDOW,
            "qualification_rule": "EVERY_ROUND_TRIP_FLAT_BY_EFFECTIVE_CUTOFF",
        },
        "SPEC_WEEKEND_CALENDAR_CONTRACT_INVALID",
    )
    trust = spec.get("owner_trust_contract") or {}
    trust_common = (
        trust.get("algorithm") == "ED25519"
        and trust.get("public_key_format") == "RAW_32_BYTES"
        and trust.get("signature_encoding") == "BASE64"
        and "independently supplies" in str(trust.get("rule") or "")
        and "self-pinning is not a trust anchor" in str(trust.get("rule") or "")
    )
    trust_pending = (
        trust.get("status") == "PENDING_OWNER_KEY_REGISTRATION"
        and trust.get("trusted_public_key_sha256") is None
    )
    trust_registered = (
        trust.get("status") == "REGISTERED_OUT_OF_BAND"
        and _valid_sha(trust.get("trusted_public_key_sha256"))
    )
    checks.require(
        trust_common and (trust_pending or trust_registered),
        "SPEC_OWNER_TRUST_CONTRACT_INVALID",
    )
    machine_gates = set(spec.get("machine_gates") or [])
    checks.require(
        {
            "BOUND_COMPLETE_BROKER_SESSION_CALENDAR_WITH_EARLY_CLOSE_FALLBACK",
            "WEEKEND_DEADLINE_AND_FRAMEWORK_FRIDAY_CLOSE_PRECEDE_NEWS_AND_ENTRY_FILTERS",
            "BOUND_KILL_SWITCH_TRIP_FLATTEN_AND_HALTED_60S_RETRY_SEMANTICS",
            "OUT_OF_BAND_PINNED_ED25519_OWNER_SIGNATURES",
            "FULL_Q08_VERSUS_NATIVE_SIGNAL_ENTRY_EXIT_OUTCOME_LOT_PNL_IDENTITY",
        }.issubset(machine_gates),
        "SPEC_MACHINE_GATES_INCOMPLETE",
    )

    history = spec.get("history_contract") or {}
    checks.require(tuple(history.get("required_symbols") or []) == REQUIRED_DWX, "SPEC_DWX_DEPENDENCIES_INVALID")
    checks.require(all(symbol.endswith(".DWX") for symbol in history.get("required_symbols") or []), "SPEC_NON_DWX_DEPENDENCY")
    checks.require(history.get("minimum_warmup_d1_bars") == 200, "SPEC_D1_WARMUP_INVALID")
    gaps = history.get("exceptional_dependency_gaps") or []
    observed_gaps = [
        (
            row.get("gap_id"),
            row.get("last_bar_open_utc"),
            row.get("next_bar_open_utc"),
            row.get("delta_hours"),
        )
        for row in gaps
        if isinstance(row, Mapping)
    ]
    checks.require(
        observed_gaps
        == [
            ("B", "2023-12-12T00:00:00Z", "2023-12-18T00:00:00Z", 144),
            ("C", "2025-10-08T00:00:00Z", "2025-11-03T00:00:00Z", 624),
            ("D", "2025-12-17T00:00:00Z", "2025-12-22T00:00:00Z", 120),
        ],
        "SPEC_GAPS_INVALID",
    )
    segments = history.get("segments") or []
    checks.require(tuple(row.get("segment_id") for row in segments) == SEGMENTS, "SPEC_SEGMENTS_INVALID")
    expected_counts = {"S0": 1600, "S1": 467, "S2": 33, "S3": 7}
    expected_score = {"S0": "2018-07-12T00:00:00Z", "S1": "2024-09-26T00:00:00Z", "S2": None, "S3": None}
    for row in segments:
        segment_id = str(row.get("segment_id"))
        checks.require(row.get("role") == SEGMENT_ROLES.get(segment_id), "SPEC_SEGMENT_ROLE_INVALID", segment_id)
        checks.require(row.get("intersection_d1_bars") == expected_counts.get(segment_id), "SPEC_SEGMENT_BAR_COUNT_INVALID", segment_id)
        checks.require(row.get("score_from_utc") == expected_score.get(segment_id), "SPEC_SEGMENT_SCORE_START_INVALID", segment_id)
        native_window = SEGMENT_NATIVE_DATA_WINDOWS.get(segment_id)
        if native_window is not None:
            checks.require(
                row.get("warmup_start_utc") == f"{native_window[0]}T00:00:00Z"
                and row.get("score_to_exclusive_utc")
                == f"{native_window[1]}T00:00:00Z",
                "SPEC_SEGMENT_NATIVE_WINDOW_INVALID",
                segment_id,
            )
        if SEGMENT_ROLES.get(segment_id) == "INFERENCE":
            checks.require(row.get("warmup_d1_bars") == 200, "SPEC_SEGMENT_WARMUP_INVALID", segment_id)
            checks.require(row.get("requires_nonempty_identity") is True, "SPEC_INFERENCE_EMPTY_ALLOWED", segment_id)
        else:
            checks.require(row.get("warmup_d1_bars", 999) < 200, "SPEC_CONTINUITY_WARMUP_INVALID", segment_id)
            checks.require(row.get("requires_nonempty_identity") is False, "SPEC_CONTINUITY_IDENTITY_INVALID", segment_id)

    identity = spec.get("identity_contract") or {}
    checks.require(tuple(identity.get("required_fields") or []) == IDENTITY_FIELDS, "SPEC_IDENTITY_FIELDS_INVALID")
    checks.require(tuple(identity.get("identity_axes") or []) == IDENTITY_AXES, "SPEC_IDENTITY_AXES_INVALID")
    protocol = spec.get("repeat_protocol") or {}
    expected_protocol = {
        "baseline_repeat_count": 2,
        "baseline_mode": "DISCOVERY_COMPLETE_UNREFERENCED",
        "baseline_is_qualifying": False,
        "seal_provenance": "OWNER_SEALED_POST_CONSENSUS_BASELINE",
        "seal_is_independent_market_reference": False,
        "qualification_repeat_count": 2,
        "qualification_mode": "AS_LIVE_REQUAL",
        "all_runs_serial": True,
    }
    for key, value in expected_protocol.items():
        checks.require(protocol.get(key) == value, "SPEC_REPEAT_PROTOCOL_INVALID", key)
    costs = spec.get("execution_cost_contract") or {}
    checks.require(tuple(costs.get("required_axes") or []) == COST_AXES, "SPEC_COST_AXES_INVALID")
    checks.require(costs.get("all_axes_must_be_xau_specific") is True, "SPEC_COST_SCOPE_INVALID")
    canonical_cost = costs.get("canonical_commission_v3") or {}
    checks.require(
        canonical_cost.get("sha256") == CANONICAL_COST_V3_SHA256
        and canonical_cost.get("payload_sha256") == CANONICAL_COST_V3_PAYLOAD_SHA256
        and canonical_cost.get("schema_version") == 3
        and canonical_cost.get("rate_unit_contract") == CANONICAL_COST_RATE_UNIT
        and canonical_cost.get("qualification_role") == "COMMISSION_AXIS_BASELINE_ONLY",
        "SPEC_CANONICAL_COMMISSION_V3_INVALID",
    )
    minima = costs.get("fixed_minima") or {}
    checks.require(float(minima.get("commission_rate_round_trip_decimal", 0)) == 0.00005, "SPEC_COMMISSION_RATE_INVALID")
    checks.require(minima.get("historical_spread_min_samples") == 100, "SPEC_SPREAD_MIN_INVALID")
    checks.require(minima.get("slippage_min_samples") == 30, "SPEC_SLIPPAGE_MIN_INVALID")

    anchors = spec.get("anchor_files") or []
    ids: set[str] = set()
    for index, raw in enumerate(anchors):
        if not isinstance(raw, Mapping):
            checks.errors.append(f"SPEC_ANCHOR_INVALID: {index}")
            continue
        anchor_id = str(raw.get("id") or "")
        checks.require(bool(anchor_id) and anchor_id not in ids, "SPEC_ANCHOR_ID_INVALID", anchor_id)
        ids.add(anchor_id)
        if verify_anchors:
            checks.binding(raw, label=f"spec.anchor.{anchor_id}", base_dir=spec_path.parent)
    checks.require(
        {"approved_card_v1", "deployed_ex5_read_only", "deployed_preset_read_only", "cost_evidence_v3", "xau_d1_literal_export", "eur_d1_literal_export", "risk_sizer"}.issubset(ids),
        "SPEC_ANCHORS_INCOMPLETE",
    )


def validate_spec(spec_path: Path, *, verify_anchors: bool = True) -> dict[str, Any]:
    checks = Checks()
    try:
        spec = _load_object(spec_path)
    except ValueError as exc:
        checks.errors.append(f"SPEC_READ_ERROR: {exc}")
        return checks.report(spec_path=str(spec_path.resolve()))
    _validate_spec_payload(spec, spec_path, checks, verify_anchors=verify_anchors)
    report = checks.report(spec_path=str(spec_path.resolve()), spec_sha256=sha256_file(spec_path))
    if report["status"] == "PASS":
        report["status"] = "BLOCKED_OWNER_AND_NEW_EVIDENCE"
        report["qualification_ready"] = False
    return report


def _validate_card_v2(path: Path | None, checks: Checks) -> None:
    if path is None or not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"CARD_V2_READ_ERROR: {exc}")
        return
    patterns = {
        "CARD_V2_SCHEMA_MISSING": r"(?m)^card_schema_version:\s*2\s*$",
        "CARD_V2_EA_ID_MISSING": r"(?m)^ea_id:\s*QM5_12567\s*$",
        "CARD_V2_G0_NOT_APPROVED": r"(?m)^g0_status:\s*APPROVED\s*$",
        "CARD_V2_EXECUTION_CONTRACT_NOT_APPROVED": r"(?m)^execution_contract_status:\s*APPROVED\s*$",
        "CARD_V2_VARIANT_NOT_APPROVED": r"(?m)^variant_classification:\s*QM_INTERPRETATION_COMMODITY_VARIANT_APPROVED\s*$",
        "CARD_V2_WEEKEND_POLICY_MISSING": r"(?m)^weekend_flat_policy:\s*NO_WEEKEND_HOLDINGS\s*$",
        "CARD_V2_WEEKEND_CUTOFF_RULE_MISSING": rf"(?m)^weekend_cutoff_rule:\s*{WEEKEND_CUTOFF_POLICY}\s*$",
    }
    for code, pattern in patterns.items():
        checks.require(re.search(pattern, text) is not None, code)
    for heading in (
        "## Source-defined rules",
        "## QM interpretations",
        "## Framework execution overrides",
        "## Exit precedence",
        "## Runtime data dependencies",
        "## Falsification and requalification",
    ):
        checks.require(heading in text, "CARD_V2_SECTION_MISSING", heading)


def _parse_set(path: Path | None) -> dict[str, str]:
    if path is None or not path.is_file():
        return {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig", errors="strict").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _validate_approved_preset(
    path: Path | None,
    *,
    candidate: Mapping[str, Any] | None,
    decisions: Mapping[str, str],
    checks: Checks,
) -> None:
    if path is None or not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"PRESET_READ_ERROR: {exc}")
        return
    values: dict[str, str] = {}
    duplicates: set[str] = set()
    headers: dict[str, str] = {}
    for line_number, raw in enumerate(text.splitlines(), start=1):
        stripped = raw.strip()
        header = re.match(r";\s*([A-Za-z0-9_ -]+?)\s*:\s*(.*?)\s*$", stripped)
        if header:
            key = re.sub(r"[^a-z0-9]+", "_", header.group(1).casefold()).strip("_")
            if key in headers:
                checks.errors.append(f"PRESET_HEADER_DUPLICATE: {key}:{line_number}")
            headers[key] = header.group(2).strip()
            continue
        if not stripped or stripped.startswith(";"):
            continue
        if "=" not in stripped:
            checks.errors.append(f"PRESET_LINE_INVALID: {line_number}")
            continue
        key, value = (item.strip() for item in stripped.split("=", 1))
        if not key or key in values:
            duplicates.add(key)
        values[key] = value
    checks.require(not duplicates, "PRESET_DUPLICATE_INPUT", ",".join(sorted(duplicates)))
    checks.require(
        headers.get("ea_id") == "12567"
        and headers.get("symbol") == "XAUUSD.DWX"
        and headers.get("timeframe") == "D1"
        and headers.get("environment", "").casefold() == "live"
        and headers.get("magic_slot") == "3",
        "PRESET_HEADER_SCOPE_INVALID",
    )
    checks.require(
        not any(key.casefold().startswith("qm_filter_") for key in values),
        "PRESET_INERT_FILTER_KEYS_FORBIDDEN",
    )

    def equal_decimal(key: str, expected: Any) -> bool:
        actual = _decimal(values.get(key))
        wanted = _decimal(expected)
        return actual is not None and wanted is not None and actual == wanted

    checks.require(values.get("qm_magic_slot_offset") == "3", "PRESET_MAGIC_SLOT_INVALID")
    if candidate is None:
        checks.errors.append("PRESET_RISK_CANDIDATE_MISSING")
    else:
        checks.require(equal_decimal("RISK_PERCENT", candidate.get("RISK_PERCENT")), "PRESET_RISK_PERCENT_INVALID")
        checks.require(equal_decimal("RISK_FIXED", 0), "PRESET_RISK_FIXED_INVALID")
        checks.require(equal_decimal("PORTFOLIO_WEIGHT", 1), "PRESET_PORTFOLIO_WEIGHT_INVALID")
    checks.require(
        values.get("qm_friday_close_enabled", "").casefold() in {"1", "true"}
        and values.get("qm_friday_close_hour_broker") == "21",
        "PRESET_FRIDAY_DIRECTIVE_INVALID",
    )
    if decisions.get("NEWS_POLICY") == "DXZ_PRE30_POST30":
        checks.require(
            values.get("qm_news_temporal") == "3"
            and values.get("qm_news_compliance") == "1",
            "PRESET_NEWS_CONTRACT_INVALID",
        )
    else:
        checks.require(
            values.get("qm_news_temporal") == "0"
            and values.get("qm_news_compliance") == "0",
            "PRESET_NEWS_CONTRACT_INVALID",
        )
    required_strategy = {
        "strategy_rsi_period": 2,
        "strategy_cum_window": 2,
        "strategy_cum_rsi_entry": 35,
        "strategy_rsi_exit": 65,
        "strategy_sma_period": 200,
        "strategy_atr_period": 14,
        "strategy_atr_sl_mult": 2.5,
        "strategy_max_hold_bars": 5,
        "strategy_max_spread_points": 300,
    }
    for key, expected in required_strategy.items():
        checks.require(equal_decimal(key, expected), "PRESET_STRATEGY_INPUT_INVALID", key)


def _validate_source_of_record_runtime_order(path: Path, checks: Checks) -> None:
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"SOURCE_RUNTIME_READ_ERROR: {exc}")
        return
    start = re.search(r"(?m)^\s*void\s+OnTick\s*\(\s*\)\s*\{", text)
    if start is None:
        checks.errors.append("SOURCE_ONTICK_MISSING")
        return
    next_function = re.search(
        r"(?m)^\s*(?:void|int|bool|double|string|datetime)\s+[A-Za-z_]\w*\s*\(",
        text[start.end() :],
    )
    finish = (
        start.end() + next_function.start()
        if next_function is not None
        else len(text)
    )
    body = text[start.end() : finish]
    early = body.find(WEEKEND_RUNTIME_HANDLER)
    friday = body.find("QM_FrameworkHandleFridayClose")
    news_positions = [
        position
        for token in (
            "Strategy_NewsFilterHook",
            "QM_NewsAllowsTrade2",
            "QM_NewsAllowsTrade",
            "Strategy_NoTradeFilter",
        )
        if (position := body.find(token)) >= 0
    ]
    checks.require(
        WEEKEND_RUNTIME_MARKER in text,
        "SOURCE_WEEKEND_RUNTIME_MARKER_MISSING",
    )
    checks.require(
        early >= 0,
        "SOURCE_WEEKEND_DEADLINE_HANDLER_MISSING",
    )
    if early >= 0:
        before_deadline = body[:early]
        kill_guard = re.search(
            r"if\s*\(\s*!\s*QM_KillSwitchCheck\s*\(\s*\)\s*\)\s*return\s*;",
            before_deadline,
            flags=re.DOTALL,
        )
        residual = (
            before_deadline[: kill_guard.start()]
            + before_deadline[kill_guard.end() :]
            if kill_guard is not None
            else before_deadline
        )
        checks.require(
            re.search(r"\breturn\s*;", residual) is None,
            "SOURCE_RETURN_BEFORE_WEEKEND_DEADLINE",
        )
        checks.require(
            re.search(
                rf"if\s*\(\s*{re.escape(WEEKEND_RUNTIME_HANDLER)}\s*\([^)]*\)\s*\)\s*return\s*;",
                body,
                flags=re.DOTALL,
            )
            is not None,
            "SOURCE_WEEKEND_DEADLINE_NOT_ENFORCED",
        )
    checks.require(
        friday >= 0
        and (early < friday if early >= 0 else False)
        and (not news_positions or friday < min(news_positions)),
        "SOURCE_FRIDAY_CLOSE_AFTER_ENTRY_OR_NEWS_FILTER",
    )
    checks.require(
        re.search(
            r"if\s*\(\s*QM_FrameworkHandleFridayClose\s*\(\s*\)\s*\)\s*return\s*;",
            body,
            flags=re.DOTALL,
        )
        is not None,
        "SOURCE_FRIDAY_CLOSE_NOT_ENFORCED",
    )


def _validate_kill_switch_flatten_semantics(path: Path, checks: Checks) -> None:
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"KILL_SWITCH_SOURCE_READ_ERROR: {exc}")
        return
    checks.require(
        re.search(
            r"void\s+QM_KillSwitchTrip\s*\([^)]*\).*?"
            r"QM_KillSwitchSaveState\s*\(\s*\).*?"
            r"QM_KillSwitchCloseOwnedPositions\s*\(\s*\).*?"
            r"QM_KillSwitchDeleteOwnedPendings\s*\(\s*\)",
            text,
            flags=re.DOTALL,
        )
        is not None,
        "KILL_SWITCH_TRIP_FLATTEN_SEMANTICS_INVALID",
    )
    checks.require(
        re.search(
            r"if\s*\(\s*g_qm_ks_halted\s*\).*?"
            r"now_retry\s*-\s*g_qm_ks_halt_retry_ts\s*>=\s*60.*?"
            r"QM_KillSwitchOwnedExposureExists\s*\(\s*\).*?"
            r"QM_KillSwitchCloseOwnedPositions\s*\(\s*\).*?"
            r"QM_KillSwitchDeleteOwnedPendings\s*\(\s*\).*?"
            r"return\s+false\s*;",
            text,
            flags=re.DOTALL,
        )
        is not None,
        "KILL_SWITCH_HALT_RETRY_SEMANTICS_INVALID",
    )


def _validate_source_closure_manifest(
    payload: Mapping[str, Any] | None,
    *,
    base_dir: Path,
    checks: Checks,
) -> str:
    if payload is None:
        return ""
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "scope",
            "files",
            "artifact_payload_sha256",
        },
        "SOURCE_CLOSURE_FIELDS_INVALID",
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == "DXZ_12567_SOURCE_INCLUDE_CLOSURE"
        and payload.get("packet_id") == PACKET_ID
        and payload.get("scope")
        == {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1"},
        "SOURCE_CLOSURE_SCOPE_INVALID",
    )
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "SOURCE_CLOSURE_PAYLOAD_HASH_INVALID",
    )
    rows = payload.get("files") or []
    checks.require(isinstance(rows, list) and bool(rows), "SOURCE_CLOSURE_EMPTY")
    roles: list[str] = []
    source_of_record_sha = ""
    kill_switch_paths: list[Path] = []
    source_of_record_path: Path | None = None
    closure_paths: list[Path] = []
    closure_entries: list[tuple[str, Path]] = []
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            checks.errors.append(f"SOURCE_CLOSURE_FILE_INVALID: {index}")
            continue
        checks.require(
            set(row) == {"role", "path", "sha256", "bytes"},
            "SOURCE_CLOSURE_FILE_FIELDS_INVALID",
            str(index),
        )
        role = str(row.get("role") or "")
        roles.append(role)
        path, digest, _ = checks.binding(
            row,
            label=f"source_closure.{index}.{role}",
            base_dir=base_dir,
            unique=True,
            external=True,
        )
        if path is not None:
            closure_paths.append(path)
            closure_entries.append((role, path))
            checks.require(
                (role == "SOURCE_OF_RECORD" and path.suffix.casefold() == ".mq5")
                or (role == "RECURSIVE_INCLUDE" and path.suffix.casefold() == ".mqh"),
                "SOURCE_CLOSURE_FILE_TYPE_INVALID",
                str(path),
            )
        if role == "SOURCE_OF_RECORD" and digest is not None:
            source_of_record_sha = digest
            if path is not None:
                source_of_record_path = path
                _validate_source_of_record_runtime_order(path, checks)
        if (
            role == "RECURSIVE_INCLUDE"
            and path is not None
            and path.name.casefold() == "qm_killswitch.mqh"
        ):
            kill_switch_paths.append(path)
    checks.require(roles.count("SOURCE_OF_RECORD") == 1, "SOURCE_CLOSURE_ROOT_COUNT_INVALID")
    checks.require(all(role in {"SOURCE_OF_RECORD", "RECURSIVE_INCLUDE"} for role in roles), "SOURCE_CLOSURE_ROLE_INVALID")
    checks.require(
        len(kill_switch_paths) == 1,
        "SOURCE_CLOSURE_KILL_SWITCH_INCLUDE_INVALID",
    )
    by_name: dict[str, Path] = {}
    for path in closure_paths:
        name = path.name.casefold()
        checks.require(
            name not in by_name,
            "SOURCE_CLOSURE_BASENAME_COLLISION",
            path.name,
        )
        by_name.setdefault(name, path)
    reachable: set[str] = set()
    pending: list[Path] = [source_of_record_path] if source_of_record_path else []
    while pending:
        current = pending.pop()
        key = _path_key(current)
        if key in reachable:
            continue
        reachable.add(key)
        try:
            text = current.read_text(encoding="utf-8-sig", errors="strict")
        except (OSError, UnicodeError) as exc:
            checks.errors.append(f"SOURCE_CLOSURE_GRAPH_READ_ERROR: {current}: {exc}")
            continue
        for token in re.findall(r"(?m)^\s*#include\s*[<\"]([^>\"]+)[>\"]", text):
            basename = Path(token.replace("\\", "/")).name.casefold()
            target = by_name.get(basename)
            if target is not None:
                pending.append(target)
            elif basename.startswith("qm_"):
                checks.errors.append(
                    f"SOURCE_CLOSURE_QM_INCLUDE_MISSING: {current}:{token}"
                )
    recursive_keys = {
        _path_key(path)
        for role, path in closure_entries
        if role == "RECURSIVE_INCLUDE"
    }
    checks.require(
        recursive_keys.issubset(reachable),
        "SOURCE_CLOSURE_UNREACHABLE_INCLUDE",
    )
    if len(kill_switch_paths) == 1:
        checks.require(
            _path_key(kill_switch_paths[0]) in reachable,
            "SOURCE_CLOSURE_KILL_SWITCH_NOT_REACHABLE",
        )
        _validate_kill_switch_flatten_semantics(kill_switch_paths[0], checks)
    return source_of_record_sha


def _load_owner_trust_anchor(
    spec: Mapping[str, Any],
    bundle: Mapping[str, Any],
    base_dir: Path,
    checks: Checks,
    *,
    out_of_band_path: Path | None,
    out_of_band_sha256: str | None,
) -> tuple[bytes | None, str | None]:
    trust = spec.get("owner_trust_contract") or {}
    pinned = trust.get("trusted_public_key_sha256")
    if trust.get("status") != "REGISTERED_OUT_OF_BAND" or not _valid_sha(pinned):
        checks.errors.append("OWNER_TRUST_ANCHOR_NOT_REGISTERED_OUT_OF_BAND")
        return None, None
    expected = str(out_of_band_sha256 or "").strip().lower()
    if out_of_band_path is None or not out_of_band_path.is_absolute():
        checks.errors.append("OWNER_TRUST_ANCHOR_OUT_OF_BAND_ABSOLUTE_PATH_REQUIRED")
        return None, None
    resolved_out_of_band = out_of_band_path.resolve(strict=False)
    checks.require(
        _valid_sha(expected),
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_HASH_REQUIRED",
    )
    checks.require(
        not _within(resolved_out_of_band, base_dir),
        "OWNER_TRUST_ANCHOR_INSIDE_BUNDLE_ROOT",
    )
    checks.require(
        not _forbidden_execution_path(resolved_out_of_band)
        and not _under_mt5_tree(resolved_out_of_band),
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_PATH_INVALID",
    )
    path, actual, _ = checks.binding(
        bundle.get("owner_trust_anchor"),
        label="bundle.owner_trust_anchor",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    checks.require(
        path is not None and _path_key(path) == _path_key(resolved_out_of_band),
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_PATH_MISMATCH",
    )
    checks.require(
        actual == pinned == expected,
        "OWNER_TRUST_ANCHOR_HASH_MISMATCH",
    )
    if path is None or not path.is_file():
        return None, actual
    raw = path.read_bytes()
    checks.require(len(raw) == 32, "OWNER_TRUST_ANCHOR_LENGTH_INVALID")
    return (
        raw if len(raw) == 32 and actual == pinned == expected else None
    ), actual


def _verify_owner_signed_payload(
    payload: Mapping[str, Any] | None,
    *,
    expected_decision_type: str,
    public_key: bytes | None,
    checks: Checks,
    label: str,
) -> None:
    if payload is None:
        return
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "decision_type",
            "status",
            "signed_utc",
            "decision",
            "signature_base64",
        },
        "OWNER_SIGNED_PAYLOAD_FIELDS_INVALID",
        label,
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == OWNER_DECISION_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("decision_type") == expected_decision_type
        and payload.get("status") == "APPROVED",
        "OWNER_SIGNED_PAYLOAD_SCOPE_INVALID",
        label,
    )
    checks.require(_parse_utc(payload.get("signed_utc")) is not None, "OWNER_SIGNED_TIME_INVALID", label)
    checks.require(isinstance(payload.get("decision"), Mapping), "OWNER_SIGNED_DECISION_INVALID", label)
    signed = dict(payload)
    signature_text = signed.pop("signature_base64", None)
    checks.require(isinstance(signature_text, str) and bool(signature_text), "OWNER_SIGNATURE_MISSING", label)
    if public_key is None or not isinstance(signature_text, str) or Ed25519PublicKey is None:
        checks.errors.append(f"OWNER_SIGNATURE_TRUST_UNAVAILABLE: {label}")
        return
    try:
        signature = base64.b64decode(signature_text, validate=True)
        Ed25519PublicKey.from_public_bytes(public_key).verify(
            signature,
            json.dumps(
                signed, sort_keys=True, separators=(",", ":"), ensure_ascii=False
            ).encode("utf-8"),
        )
    except (ValueError, binascii.Error, InvalidSignature):
        checks.errors.append(f"OWNER_SIGNATURE_INVALID: {label}")


def _validate_owner_gates(
    spec: Mapping[str, Any],
    bundle: Mapping[str, Any],
    base_dir: Path,
    public_key: bytes | None,
    checks: Checks,
) -> tuple[dict[str, str], dict[str, str]]:
    expected = {str(row["gate_id"]): row for row in spec.get("owner_gates", [])}
    raw = bundle.get("owner_gates") or []
    actual = {str(row.get("gate_id")): row for row in raw if isinstance(row, Mapping)}
    checks.require(
        isinstance(raw, list)
        and len(raw) == len(OWNER_GATE_IDS)
        and all(isinstance(row, Mapping) for row in raw)
        and tuple(actual) == OWNER_GATE_IDS,
        "OWNER_GATE_SET_INVALID",
    )
    decisions: dict[str, str] = {}
    receipt_hashes: dict[str, str] = {}
    for gate_id, contract in expected.items():
        row = actual.get(gate_id)
        if not isinstance(row, Mapping):
            checks.errors.append(f"OWNER_GATE_MISSING: {gate_id}")
            continue
        checks.require(row.get("status") == "APPROVED", "OWNER_GATE_NOT_APPROVED", gate_id)
        decision = str(row.get("decision") or "")
        if contract.get("required_decision") is not None:
            checks.require(decision == contract["required_decision"], "OWNER_GATE_DECISION_INVALID", gate_id)
        else:
            checks.require(decision in (contract.get("allowed_decisions") or []), "OWNER_GATE_DECISION_INVALID", gate_id)
        decisions[gate_id] = decision
        _, receipt_sha, receipt = checks.binding(
            row.get("receipt"),
            label=f"owner_gate.{gate_id}.receipt",
            base_dir=base_dir,
            unique=True,
            json_object=True,
            external=True,
        )
        if receipt_sha is not None:
            receipt_hashes[gate_id] = receipt_sha
        _verify_owner_signed_payload(
            receipt,
            expected_decision_type=f"OWNER_GATE:{gate_id}",
            public_key=public_key,
            checks=checks,
            label=gate_id,
        )
        if isinstance(receipt, Mapping):
            signed_payload = receipt.get("decision")
            checks.require(
                isinstance(signed_payload, Mapping)
                and set(signed_payload) == {"value"},
                "OWNER_SIGNED_GATE_FIELDS_INVALID",
                gate_id,
            )
            signed_decision = signed_payload.get("value") if isinstance(signed_payload, Mapping) else None
            checks.require(signed_decision == decision, "OWNER_SIGNED_DECISION_MISMATCH", gate_id)
    return decisions, receipt_hashes


def _validate_effective_contract(
    spec: Mapping[str, Any], bundle: Mapping[str, Any], decisions: Mapping[str, str], checks: Checks
) -> tuple[dict[str, Any], str]:
    contract = bundle.get("effective_contract")
    if not isinstance(contract, dict):
        checks.errors.append("EFFECTIVE_CONTRACT_INVALID")
        return {}, ""
    declared = str(bundle.get("effective_contract_sha256") or "").lower()
    actual = canonical_json_sha(contract)
    checks.require(_valid_sha(declared) and declared == actual, "EFFECTIVE_CONTRACT_HASH_INVALID")
    checks.require(contract.get("ea_id") == 12567 and contract.get("symbol") == "XAUUSD.DWX" and contract.get("timeframe") == "D1", "EFFECTIVE_SCOPE_INVALID")
    risk = contract.get("risk") or {}
    selected = decisions.get("AS_LIVE_RISK_CONTRACT")
    candidates = {
        str(row["contract_id"]): row
        for row in spec.get("risk_contract_candidates", [])
        if isinstance(row, Mapping)
    }
    candidate = candidates.get(selected or "")
    checks.require(candidate is not None and candidate.get("owner_selectable") is True, "EFFECTIVE_RISK_OWNER_INVALID")
    if candidate is not None:
        checks.require(risk.get("mode") == "PERCENT", "EFFECTIVE_RISK_MODE_INVALID")
        checks.require(str(risk.get("percent")) == str(candidate["RISK_PERCENT"]), "EFFECTIVE_RISK_PERCENT_INVALID")
        checks.require(str(risk.get("fixed")) == "0", "EFFECTIVE_RISK_FIXED_INVALID")
        checks.require(str(risk.get("portfolio_weight")) in {"1", "1.0"}, "EFFECTIVE_PORTFOLIO_WEIGHT_INVALID")
        checks.require(risk.get("deposit") == 100000 and risk.get("account_currency") == "EUR", "EFFECTIVE_ACCOUNT_INVALID")
    friday = contract.get("friday") or {}
    if decisions.get("FRIDAY_CLOSE_POLICY") == "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER":
        checks.require(
            friday
            == {
                "enabled": True,
                "hour_broker": 21,
                "weekend_holdings": False,
                "effective_cutoff_rule": WEEKEND_CUTOFF_POLICY,
                "bound_calendar_required": True,
            },
            "EFFECTIVE_FRIDAY_INVALID",
        )
    else:
        checks.require(friday.get("enabled") is False, "EFFECTIVE_FRIDAY_INVALID")
    news = contract.get("news") or {}
    if decisions.get("NEWS_POLICY") == "DXZ_PRE30_POST30":
        checks.require(news.get("temporal") == 3 and news.get("compliance") == 1, "EFFECTIVE_NEWS_INVALID")
    else:
        checks.require(news.get("temporal") == 0 and news.get("compliance") == 0, "EFFECTIVE_NEWS_INVALID")
    expected_strategy = {
        "rsi_period": 2,
        "cum_window": 2,
        "cum_rsi_entry": 35.0,
        "rsi_exit": 65.0,
        "sma_period": 200,
        "atr_period": 14,
        "atr_sl_mult": 2.5,
        "max_hold_bars": 5,
        "max_spread_points": 300,
    }
    checks.require(contract.get("strategy") == expected_strategy, "EFFECTIVE_STRATEGY_INVALID")
    return contract, declared


def _cost_scope_ok(payload: Mapping[str, Any], axis: str) -> bool:
    scope = payload.get("scope") or {}
    return (
        payload.get("schema_version") == 2
        and payload.get("artifact_type") == COST_AXIS_ARTIFACT
        and payload.get("axis") == axis
        and payload.get("status") == "CERTIFIED"
        and scope.get("ea_id") == 12567
        and scope.get("symbol") == "XAUUSD.DWX"
        and scope.get("timeframe") == "D1"
        and scope.get("account_currency") == "EUR"
        and scope.get("from_date") == "2018-03-01"
        and scope.get("to_date") == "2025-12-31"
        and scope.get("segment_ids") == ["S0", "S1"]
        and scope.get("coverage") == "EXACT_KEY_NO_GLOBAL_FALLBACK"
    )


def _fresh_enough(observed: Any, as_of: dt.datetime | None, max_days: int = 7) -> bool:
    measured = _parse_utc(observed)
    return (
        measured is not None
        and as_of is not None
        and dt.timedelta(0) <= as_of - measured <= dt.timedelta(days=max_days)
    )


def _validate_cost_axis(
    axis: str, payload: Mapping[str, Any], as_of: dt.datetime | None, checks: Checks
) -> None:
    checks.require(_cost_scope_ok(payload, axis), "COST_AXIS_SCOPE_INVALID", axis)
    measurements = payload.get("measurements") or {}
    if axis == "commission":
        checks.require(float(measurements.get("round_trip_notional_rate", 0)) == 0.00005, "COST_COMMISSION_RATE_INVALID")
        checks.require(measurements.get("commodity_nominal_bound") is True, "COST_COMMODITY_NOMINAL_UNBOUND")
        checks.require(measurements.get("eur_conversion_bound") is True, "COST_COMMISSION_CONVERSION_UNBOUND")
        checks.require(measurements.get("ambiguous_trade_count") == 0 and measurements.get("unbounded_trade_count") == 0, "COST_COMMISSION_INCOMPLETE")
        checks.require(measurements.get("official_source") == "https://help.darwinex.com/execution-costs", "COST_COMMISSION_SOURCE_INVALID")
    elif axis in {"historical_tester_spread", "current_broker_spread_parity"}:
        checks.require(isinstance(measurements.get("sample_count"), int) and measurements["sample_count"] >= 100, "COST_SPREAD_SAMPLE_SHORT", axis)
        quantile = _decimal(measurements.get("quantile"))
        observed = _decimal(measurements.get("observed_quantile_points"))
        applied = _decimal(measurements.get("applied_points"))
        checks.require(quantile is not None and quantile >= Decimal("0.95"), "COST_SPREAD_QUANTILE_INVALID", axis)
        checks.require(observed is not None and observed > 0 and applied is not None and applied >= observed, "COST_SPREAD_STRESS_INVALID", axis)
        if axis == "historical_tester_spread":
            checks.require(measurements.get("history_quality") == "100% real ticks", "COST_HISTORY_QUALITY_INVALID")
            checks.require(measurements.get("segment_ids") == ["S0", "S1"], "COST_HISTORY_SEGMENTS_INVALID")
        else:
            checks.require(_fresh_enough(payload.get("observed_as_of_utc"), as_of), "COST_CURRENT_SPREAD_STALE")
    elif axis == "current_broker_swap_rate_parity":
        checks.require(_fresh_enough(payload.get("observed_as_of_utc"), as_of), "COST_SWAP_STALE")
        checks.require(isinstance(measurements.get("sample_days"), int) and measurements["sample_days"] >= 5, "COST_SWAP_SAMPLE_SHORT")
        checks.require(measurements.get("sides") == ["LONG", "SHORT"], "COST_SWAP_SIDES_INVALID")
        checks.require(measurements.get("triple_rollover_verified") is True, "COST_SWAP_TRIPLE_UNVERIFIED")
        checks.require(_decimal(measurements.get("long_rate")) is not None and _decimal(measurements.get("short_rate")) is not None, "COST_SWAP_RATE_INVALID")
        adverse = _decimal(measurements.get("applied_adverse_eur_per_lot_day"))
        checks.require(adverse is not None and adverse > 0, "COST_SWAP_ADVERSE_INVALID")
    elif axis == "slippage_stress":
        checks.require(isinstance(measurements.get("sample_count"), int) and measurements["sample_count"] >= 30, "COST_SLIPPAGE_SAMPLE_SHORT")
        quantile = _decimal(measurements.get("quantile"))
        observed = _decimal(measurements.get("observed_adverse_points"))
        gap = _decimal(measurements.get("gap_component_points"))
        multiplier = _decimal(measurements.get("adverse_multiplier"))
        applied = _decimal(measurements.get("applied_points"))
        valid = None not in (quantile, observed, gap, multiplier, applied)
        checks.require(valid, "COST_SLIPPAGE_VALUES_INVALID")
        if valid:
            assert quantile is not None and observed is not None and gap is not None and multiplier is not None and applied is not None
            checks.require(quantile >= Decimal("0.95") and observed > 0 and gap >= 0 and multiplier >= 1, "COST_SLIPPAGE_POLICY_INVALID")
            checks.require(applied >= (observed + gap) * multiplier, "COST_SLIPPAGE_STRESS_INVALID")


def _validate_cost_source_manifest(
    payload: Mapping[str, Any] | None,
    *,
    expected_hashes: Mapping[str, str],
    checks: Checks,
) -> None:
    if payload is None:
        return
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "status",
            "immutable",
            "scope",
            "covered_sleeves",
            "evaluation_window",
            "input_hashes",
            "artifact_payload_sha256",
        },
        "COST_SOURCE_MANIFEST_FIELDS_INVALID",
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == COST_SOURCE_MANIFEST_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("status") == "FROZEN"
        and payload.get("immutable") is True,
        "COST_SOURCE_MANIFEST_SCOPE_INVALID",
    )
    checks.require(
        payload.get("scope")
        == {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1", "magic": 125670003},
        "COST_SOURCE_MANIFEST_SCOPE_INVALID",
    )
    checks.require(
        payload.get("covered_sleeves")
        == [{"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1"}],
        "COST_SOURCE_MANIFEST_COVERAGE_INVALID",
    )
    checks.require(
        payload.get("evaluation_window") == QUALIFICATION_WINDOW,
        "COST_SOURCE_MANIFEST_WINDOW_INVALID",
    )
    expected_inputs = {
        key: expected_hashes[key]
        for key in (
            "binary_sha256",
            "preset_sha256",
            "effective_contract_sha256",
            "source_closure_sha256",
        )
    }
    checks.require(payload.get("input_hashes") == expected_inputs, "COST_SOURCE_INPUT_HASHES_INVALID")
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "COST_SOURCE_PAYLOAD_HASH_INVALID",
    )


def _validate_canonical_cost_v3(
    binding: Any, *, base_dir: Path, checks: Checks
) -> None:
    if not isinstance(binding, Mapping):
        checks.errors.append("COST_COMMISSION_V3_BINDING_INVALID")
        return
    checks.require(
        binding.get("sha256") == CANONICAL_COST_V3_SHA256
        and binding.get("payload_sha256") == CANONICAL_COST_V3_PAYLOAD_SHA256,
        "COST_COMMISSION_V3_CANONICAL_HASH_INVALID",
    )
    path, digest, payload = checks.binding(
        binding,
        label="execution_costs.commission.canonical_v3",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    if payload is None or path is None:
        return
    checks.require(digest == CANONICAL_COST_V3_SHA256, "COST_COMMISSION_V3_FILE_HASH_INVALID")
    checks.require(
        payload.get("schema_version") == 3
        and payload.get("artifact_type") == "DXZ_STANDALONE_COST_EVIDENCE"
        and payload.get("deployment_eligible") is False,
        "COST_COMMISSION_V3_SCHEMA_INVALID",
    )
    policy = payload.get("policy") or {}
    checks.require(
        policy.get("round_trip_notional_rate") == 0.00005
        and policy.get("round_trip_notional_percent") == 0.005
        and policy.get("round_trip_notional_basis_points") == 0.5
        and policy.get("rate_unit_contract") == CANONICAL_COST_RATE_UNIT,
        "COST_COMMISSION_V3_RATE_UNIT_INVALID",
    )
    integrity = payload.get("integrity") or {}
    unsigned = dict(payload)
    unsigned.pop("integrity", None)
    checks.require(
        integrity.get("payload_sha256") == CANONICAL_COST_V3_PAYLOAD_SHA256
        and canonical_json_sha(unsigned) == CANONICAL_COST_V3_PAYLOAD_SHA256,
        "COST_COMMISSION_V3_PAYLOAD_HASH_INVALID",
    )
    sleeves = [
        row
        for row in payload.get("sleeves") or []
        if isinstance(row, Mapping)
        and (row.get("sleeve") or {}).get("ea_id") == 12567
        and (row.get("sleeve") or {}).get("symbol") == "XAUUSD.DWX"
        and (row.get("sleeve") or {}).get("timeframe") == "D1"
    ]
    checks.require(len(sleeves) == 1, "COST_COMMISSION_V3_SLEEVE_MISSING")
    if len(sleeves) == 1:
        checks.require(
            sleeves[0].get("commission_evidence_status") == "COMPLETE"
            and sleeves[0].get("ambiguous_trade_count") == 0
            and sleeves[0].get("unbounded_trade_count") == 0
            and (sleeves[0].get("scope") or {}).get("commission", {}).get("rate_round_trip")
            == 0.00005,
            "COST_COMMISSION_V3_SLEEVE_INCOMPLETE",
        )
    sidecar = path.with_name(path.name + ".sha256")
    checks.binding(
        {"path": str(sidecar), "sha256": sha256_file(sidecar) if sidecar.is_file() else ""},
        label="execution_costs.commission.canonical_v3_sidecar",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    if sidecar.is_file():
        try:
            token = sidecar.read_text(encoding="ascii", errors="strict").split()[0].lower()
        except (OSError, UnicodeError, IndexError):
            token = ""
        checks.require(token == CANONICAL_COST_V3_SHA256, "COST_COMMISSION_V3_SIDECAR_INVALID")


def _validate_costs(
    bundle: Mapping[str, Any],
    base_dir: Path,
    as_of: dt.datetime | None,
    *,
    source_manifest_sha256: str,
    checks: Checks,
) -> str:
    costs = bundle.get("execution_costs")
    if not isinstance(costs, Mapping):
        checks.errors.append("EXECUTION_COSTS_INVALID")
        return ""
    checks.require(
        set(costs) == {"status", "manifest"} and costs.get("status") == "CERTIFIED",
        "EXECUTION_COSTS_CONTRACT_INVALID",
    )
    manifest_path, manifest_sha, _ = checks.binding(
        costs.get("manifest"),
        label="execution_costs.manifest",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    if (
        manifest_path is None
        or manifest_sha is None
        or as_of is None
        or load_execution_cost_evidence_manifest is None
    ):
        checks.errors.append("EXECUTION_COSTS_VALIDATOR_UNAVAILABLE")
        return manifest_sha or ""
    try:
        metadata, contracts = load_execution_cost_evidence_manifest(
            manifest_path,
            source_manifest_sha256=source_manifest_sha256,
            as_of_utc=as_of,
            required_sleeves=[{"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1"}],
            window_contract=QUALIFICATION_WINDOW,
        )
    except (RequalError, OSError, ValueError) as exc:
        checks.errors.append(f"EXECUTION_COST_MANIFEST_INVALID: {exc}")
        return manifest_sha
    checks.require(
        set(contracts) == {"12567:XAUUSD.DWX"},
        "EXECUTION_COST_CONTRACT_COVERAGE_INVALID",
    )
    contract = contracts.get("12567:XAUUSD.DWX") or {}
    axes = contract.get("axes") or {}
    checks.require(tuple(axes) == COST_AXES, "EXECUTION_COST_AXIS_SET_INVALID")
    commission = axes.get("commission") or {}
    params = commission.get("parameters") or {}
    checks.require(
        params.get("rate") == 0.00005
        and params.get("rate_percent") == 0.005
        and params.get("rate_basis_points") == 0.5
        and params.get("rate_unit_contract") == CANONICAL_COST_RATE_UNIT,
        "COST_COMMISSION_RATE_UNIT_INVALID",
    )
    _validate_canonical_cost_v3(
        params.get("canonical_commission_artifact"), base_dir=manifest_path.parent, checks=checks
    )
    for label, path_field, sha_field in (
        ("execution_costs.manifest_sidecar", "sidecar_path", "sidecar_sha256"),
    ):
        checks.binding(
            {"path": metadata.get(path_field), "sha256": metadata.get(sha_field)},
            label=label,
            base_dir=manifest_path.parent,
            unique=True,
            external=True,
        )
    for artifact in metadata.get("bound_artifacts") or []:
        axis = str(artifact.get("axis") or "")
        checks.binding(
            {"path": artifact.get("path"), "sha256": artifact.get("sha256")},
            label=f"execution_costs.{axis}.structured_evidence",
            base_dir=manifest_path.parent,
            unique=True,
            external=True,
        )
        checks.binding(
            {
                "path": artifact.get("sidecar_path"),
                "sha256": artifact.get("sidecar_sha256"),
            },
            label=f"execution_costs.{axis}.structured_evidence_sidecar",
            base_dir=manifest_path.parent,
            unique=True,
            external=True,
        )
    unchanged, errors = verify_execution_cost_evidence_unchanged(metadata)
    checks.require(unchanged, "EXECUTION_COST_ARTIFACT_CHANGED", ",".join(errors))
    return manifest_sha


def _read_identity_rows(
    path: Path | None, *, segment_id: str, label: str, checks: Checks
) -> list[dict[str, Any]]:
    if path is None or not path.is_file():
        return []
    try:
        lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"IDENTITY_STREAM_READ_ERROR: {label}: {exc}")
        return []
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            checks.errors.append(f"IDENTITY_JSON_INVALID: {label}:{line_number}: {exc.msg}")
            continue
        if not isinstance(row, dict) or set(row) != set(IDENTITY_FIELDS):
            checks.errors.append(f"IDENTITY_FIELDS_INVALID: {label}:{line_number}")
            continue
        checks.require(row.get("segment_id") == segment_id, "IDENTITY_SEGMENT_INVALID", f"{label}:{line_number}")
        checks.require(row.get("symbol") == "XAUUSD.DWX", "IDENTITY_SYMBOL_INVALID", f"{label}:{line_number}")
        checks.require(row.get("side") == "BUY", "IDENTITY_SIDE_INVALID", f"{label}:{line_number}")
        checks.require(isinstance(row.get("trade_index"), int) and row["trade_index"] > 0, "IDENTITY_INDEX_INVALID", f"{label}:{line_number}")
        signal_time = _parse_broker_time(row.get("signal_bar_open_mt5_server"))
        entry_time = _parse_broker_time(row.get("entry_time_mt5_server"))
        exit_time = _parse_broker_time(row.get("exit_time_mt5_server"))
        checks.require(signal_time is not None and entry_time is not None and exit_time is not None, "IDENTITY_TIME_INVALID", f"{label}:{line_number}")
        if None not in (signal_time, entry_time, exit_time):
            assert signal_time is not None and entry_time is not None and exit_time is not None
            checks.require(signal_time <= entry_time <= exit_time, "IDENTITY_TIME_ORDER_INVALID", f"{label}:{line_number}")
        positive_fields = ("entry_price", "initial_stop", "exit_price", "volume")
        for field in positive_fields:
            value = _decimal(row.get(field))
            checks.require(value is not None and value > 0, "IDENTITY_DECIMAL_INVALID", f"{label}:{line_number}:{field}")
        target = _decimal(row.get("initial_target"))
        signal = _decimal(row.get("signal_value"))
        checks.require(target is not None and target >= 0, "IDENTITY_TARGET_INVALID", f"{label}:{line_number}")
        checks.require(signal is not None and 0 <= signal < 35, "IDENTITY_SIGNAL_INVALID", f"{label}:{line_number}")
        for field in ("gross_profit", "swap", "commission", "net_profit"):
            checks.require(_decimal(row.get(field)) is not None, "IDENTITY_PNL_INVALID", f"{label}:{line_number}:{field}")
        gross = _decimal(row.get("gross_profit"))
        swap = _decimal(row.get("swap"))
        commission = _decimal(row.get("commission"))
        net = _decimal(row.get("net_profit"))
        if None not in (gross, swap, commission, net):
            assert gross is not None and swap is not None and commission is not None and net is not None
            checks.require(abs((gross + swap + commission) - net) <= Decimal("0.01"), "IDENTITY_PNL_RECONCILIATION_FAIL", f"{label}:{line_number}")
            sign = 1 if gross > 0 else -1 if gross < 0 else 0
            checks.require(row.get("gross_profit_sign") == sign, "IDENTITY_OUTCOME_SIGN_INVALID", f"{label}:{line_number}")
        for field in ("entry_reason", "exit_reason"):
            checks.require(isinstance(row.get(field), str) and bool(row[field].strip()), "IDENTITY_REASON_INVALID", f"{label}:{line_number}:{field}")
        rows.append(row)
    checks.require([row["trade_index"] for row in rows] == list(range(1, len(rows) + 1)), "IDENTITY_INDEX_SEQUENCE_INVALID", label)
    return rows


def _identity_digests(rows: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    materialized = list(rows)
    selections = {
        "signal_identity_sha256": ("trade_index", "signal_bar_open_mt5_server", "signal_value"),
        "entry_identity_sha256": ("trade_index", "side", "entry_time_mt5_server", "entry_price", "entry_reason", "initial_stop", "initial_target"),
        "exit_identity_sha256": ("trade_index", "exit_time_mt5_server", "exit_price", "exit_reason"),
        "outcome_sign_sha256": ("trade_index", "gross_profit_sign"),
        "lot_identity_sha256": ("trade_index", "volume"),
        "pnl_identity_sha256": ("trade_index", "gross_profit", "swap", "commission", "net_profit"),
        "full_round_trip_identity_sha256": IDENTITY_FIELDS,
    }
    result: dict[str, Any] = {"trade_count": len(materialized)}
    for axis, fields in selections.items():
        result[axis] = canonical_json_sha([[row[field] for field in fields] for row in materialized])
    return result


def _expected_weekend_fridays() -> list[dt.date]:
    cursor = dt.date.fromisoformat(QUALIFICATION_WINDOW["requested_from_date"])
    finish = dt.date.fromisoformat(QUALIFICATION_WINDOW["requested_to_date"])
    cursor += dt.timedelta(days=(4 - cursor.weekday()) % 7)
    result: list[dt.date] = []
    while cursor <= finish:
        result.append(cursor)
        cursor += dt.timedelta(days=7)
    return result


def _validate_weekend_flat_calendar(
    payload: Mapping[str, Any] | None,
    *,
    base_dir: Path,
    checks: Checks,
    as_of: dt.datetime | None = None,
) -> list[dt.datetime]:
    if payload is None:
        checks.errors.append("WEEKEND_CALENDAR_MISSING")
        return []
    calendar_generated = _parse_utc(payload.get("generated_utc"))
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "status",
            "immutable",
            "generated_utc",
            "scope",
            "policy",
            "source_session_export",
            "entries",
            "artifact_payload_sha256",
        },
        "WEEKEND_CALENDAR_FIELDS_INVALID",
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == WEEKEND_CALENDAR_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("status") == "FROZEN"
        and payload.get("immutable") is True
        and calendar_generated is not None
        and (as_of is None or calendar_generated <= as_of),
        "WEEKEND_CALENDAR_SCOPE_INVALID",
    )
    checks.require(
        payload.get("scope")
        == {
            "symbol": "XAUUSD.DWX",
            "timezone_basis": "MT5_BROKER_SERVER_TIME",
            "window": QUALIFICATION_WINDOW,
        }
        and payload.get("policy") == WEEKEND_CUTOFF_POLICY,
        "WEEKEND_CALENDAR_SCOPE_INVALID",
    )
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "WEEKEND_CALENDAR_PAYLOAD_HASH_INVALID",
    )

    _, _, source = checks.binding(
        payload.get("source_session_export"),
        label="weekend_calendar.source_session_export",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    source_sessions: Any = None
    if isinstance(source, Mapping):
        source_generated = _parse_utc(source.get("generated_utc"))
        checks.require(
            set(source)
            == {
                "schema_version",
                "artifact_type",
                "packet_id",
                "status",
                "generated_utc",
                "scope",
                "provenance",
                "sessions",
                "artifact_payload_sha256",
            },
            "WEEKEND_CALENDAR_SOURCE_FIELDS_INVALID",
        )
        source_unsigned = dict(source)
        source_declared = str(
            source_unsigned.pop("artifact_payload_sha256", "") or ""
        ).lower()
        checks.require(
            source.get("schema_version") == 1
            and source.get("artifact_type") == WEEKEND_CALENDAR_SOURCE_ARTIFACT
            and source.get("packet_id") == PACKET_ID
            and source.get("status") == "FROZEN"
            and source_generated is not None
            and (
                calendar_generated is None
                or source_generated is None
                or source_generated <= calendar_generated
            )
            and source.get("scope")
            == {
                "symbol": "XAUUSD.DWX",
                "timezone_basis": "MT5_BROKER_SERVER_TIME",
                "window": QUALIFICATION_WINDOW,
            }
            and source.get("provenance")
            == {
                "terminal": "DarwinexZero MT5",
                "literal_dwx": True,
                "method": "BROKER_SESSION_PLUS_LITERAL_DWX_TICK_CALENDAR",
            },
            "WEEKEND_CALENDAR_SOURCE_SCOPE_INVALID",
        )
        checks.require(
            _valid_sha(source_declared)
            and canonical_json_sha(source_unsigned) == source_declared,
            "WEEKEND_CALENDAR_SOURCE_PAYLOAD_HASH_INVALID",
        )
        source_sessions = source.get("sessions")

    expected_fridays = _expected_weekend_fridays()
    entries = payload.get("entries")
    checks.require(
        isinstance(entries, list) and len(entries) == len(expected_fridays),
        "WEEKEND_CALENDAR_COVERAGE_INVALID",
    )
    cutoffs: list[dt.datetime] = []
    projected_source: list[dict[str, str]] = []
    if isinstance(entries, list):
        for index, friday in enumerate(expected_fridays):
            if index >= len(entries) or not isinstance(entries[index], Mapping):
                checks.errors.append(f"WEEKEND_CALENDAR_ENTRY_INVALID: {friday}")
                continue
            row = entries[index]
            label = str(friday)
            checks.require(
                set(row)
                == {
                    "week_friday_date",
                    "regular_cutoff_broker",
                    "last_tradable_session_close_broker",
                    "effective_cutoff_broker",
                    "early_close",
                },
                "WEEKEND_CALENDAR_ENTRY_FIELDS_INVALID",
                label,
            )
            regular = _parse_broker_time(row.get("regular_cutoff_broker"))
            last_tradable = _parse_broker_time(
                row.get("last_tradable_session_close_broker")
            )
            effective = _parse_broker_time(row.get("effective_cutoff_broker"))
            expected_regular = dt.datetime.combine(friday, dt.time(hour=21))
            checks.require(
                row.get("week_friday_date") == friday.isoformat()
                and regular == expected_regular,
                "WEEKEND_CALENDAR_REGULAR_CUTOFF_INVALID",
                label,
            )
            checks.require(
                last_tradable is not None
                and expected_regular - dt.timedelta(days=7) < last_tradable
                <= expected_regular
                and last_tradable.weekday() <= 4,
                "WEEKEND_CALENDAR_LAST_TRADABLE_INVALID",
                label,
            )
            expected_effective = (
                min(expected_regular, last_tradable)
                if last_tradable is not None
                else None
            )
            checks.require(
                effective == expected_effective
                and row.get("early_close")
                is (last_tradable is not None and last_tradable < expected_regular),
                "WEEKEND_CALENDAR_EFFECTIVE_CUTOFF_INVALID",
                label,
            )
            if effective is not None:
                cutoffs.append(effective)
            projected_source.append(
                {
                    "week_friday_date": friday.isoformat(),
                    "last_tradable_session_close_broker": str(
                        row.get("last_tradable_session_close_broker") or ""
                    ),
                }
            )
    checks.require(
        isinstance(source_sessions, list) and source_sessions == projected_source,
        "WEEKEND_CALENDAR_SOURCE_SESSIONS_MISMATCH",
    )
    return cutoffs


def _validate_no_weekend_holdings(
    rows: Sequence[Mapping[str, Any]],
    *,
    cutoffs: Sequence[dt.datetime],
    label: str,
    checks: Checks,
) -> None:
    """Prove the effective Friday-21 directive from broker-time round trips.

    A declared preset flag is insufficient: a stale or mismatched binary could
    ignore it.  Any position interval that remains open after a Friday 21:00
    broker-time cutoff is therefore qualification-fatal.
    """

    checks.require(bool(cutoffs) or not rows, "WEEKEND_CALENDAR_CUTOFFS_UNAVAILABLE", label)
    for index, row in enumerate(rows, start=1):
        entry = _parse_broker_time(row.get("entry_time_mt5_server"))
        exit_time = _parse_broker_time(row.get("exit_time_mt5_server"))
        if entry is None or exit_time is None:
            continue
        detail = f"{label}:{index}"
        checks.require(entry <= exit_time, "FRIDAY_FLAT_TIME_ORDER_INVALID", detail)
        checks.require(
            not (entry.weekday() == 4 and entry.hour >= 21),
            "FRIDAY_ENTRY_AT_OR_AFTER_CUTOFF",
            detail,
        )
        for cutoff in cutoffs:
            if entry.date() - dt.timedelta(days=7) > cutoff.date():
                continue
            if cutoff.date() > exit_time.date():
                break
            checks.require(
                not (entry < cutoff < exit_time),
                "WEEKEND_HOLDING_AFTER_EFFECTIVE_CUTOFF",
                detail,
            )


def _read_q08_raw_identity_rows(
    path: Path | None, *, segment_id: str, label: str, checks: Checks
) -> list[dict[str, Any]]:
    if path is None or not path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"Q08_RAW_READ_ERROR: {label}: {exc}")
        return rows
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            checks.errors.append(f"Q08_RAW_JSON_INVALID: {label}:{line_number}:{exc.msg}")
            continue
        if not isinstance(event, Mapping):
            checks.errors.append(f"Q08_RAW_EVENT_INVALID: {label}:{line_number}")
            continue
        event_name = str(event.get("event") or "")
        if event_name != "DXZ_12567_FULL_ROUND_TRIP":
            checks.require(
                not event_name.startswith("DXZ_12567_"),
                "Q08_RAW_UNKNOWN_12567_EVENT",
                f"{label}:{line_number}:{event_name}",
            )
            continue
        payload = event.get("payload")
        checks.require(
            isinstance(payload, Mapping) and set(payload) == set(IDENTITY_FIELDS),
            "Q08_RAW_IDENTITY_FIELDS_INVALID",
            f"{label}:{line_number}",
        )
        if isinstance(payload, Mapping) and set(payload) == set(IDENTITY_FIELDS):
            rows.append(dict(payload))
    # Reuse the full semantic checks on the exact raw payload, not only its hash.
    if rows:
        temporary_digest = _identity_digests(rows)
        checks.require(
            temporary_digest["trade_count"] == len(rows),
            "Q08_RAW_IDENTITY_PARSE_INVALID",
            label,
        )
    checks.require(
        all(row.get("segment_id") == segment_id for row in rows),
        "Q08_RAW_SEGMENT_INVALID",
        label,
    )
    return rows


def _validate_native_html_semantics(
    report_path: Path | None,
    native_rows: Sequence[Mapping[str, Any]],
    *,
    inference: bool,
    label: str,
    checks: Checks,
    segment_id: str | None = None,
) -> None:
    if report_path is None or not report_path.is_file():
        return
    if _report_rows is None or _report_stats is None or extract_round_trips is None:
        checks.errors.append(f"NATIVE_HTML_PARSER_UNAVAILABLE: {label}")
        return
    try:
        stats = _report_stats(_report_rows(report_path))
    except (CostEvidenceError, OSError, ValueError) as exc:
        checks.errors.append(f"NATIVE_HTML_SEMANTIC_PARSE_FAILED: {label}: {exc}")
        return
    checks.require(
        str(stats.get("host_symbol") or "").upper() == "XAUUSD.DWX",
        "NATIVE_HTML_SYMBOL_INVALID",
        label,
    )
    checks.require(
        str(stats.get("account_currency") or "").upper() == "EUR",
        "NATIVE_HTML_ACCOUNT_CURRENCY_INVALID",
        label,
    )
    checks.require(
        "12567" in str(stats.get("expert") or ""),
        "NATIVE_HTML_EXPERT_INVALID",
        label,
    )
    checks.require(
        stats.get("report_total_trades") == len(native_rows),
        "NATIVE_HTML_TRADE_COUNT_INVALID",
        label,
    )
    checks.require(
        "100% real ticks" == " ".join(str(stats.get("history_quality") or "").split()).casefold(),
        "NATIVE_HTML_HISTORY_QUALITY_INVALID",
        label,
    )
    if segment_id is not None:
        window = SEGMENT_NATIVE_DATA_WINDOWS.get(segment_id)
        if window is None:
            checks.errors.append(f"NATIVE_HTML_SEGMENT_WINDOW_UNKNOWN: {label}:{segment_id}")
        else:
            start = dt.date.fromisoformat(window[0])
            finish = dt.date.fromisoformat(window[1]) - dt.timedelta(days=1)
            expected_period = (
                f"Daily ({start.strftime('%Y.%m.%d')} - {finish.strftime('%Y.%m.%d')})"
            )
            checks.require(
                " ".join(str(stats.get("period") or "").split()) == expected_period,
                "NATIVE_HTML_PERIOD_INVALID",
                label,
            )
    try:
        trips, _ = extract_round_trips(report_path)
    except (CostEvidenceError, OSError, ValueError) as exc:
        checks.errors.append(f"NATIVE_HTML_ROUND_TRIP_PARSE_FAILED: {label}: {exc}")
        return
    checks.require(len(trips) == len(native_rows), "NATIVE_HTML_ROUND_TRIP_COUNT_INVALID", label)
    if not inference:
        checks.require(
            len(native_rows) == 0 and len(trips) == 0,
            "NATIVE_HTML_CONTINUITY_TRADES_INVALID",
            label,
        )
        return

    def numeric_equal(raw: Any, expected: float, tolerance: float = 1e-8) -> bool:
        parsed = _decimal(raw)
        return parsed is not None and abs(float(parsed) - expected) <= tolerance

    for index, (trade, row) in enumerate(zip(trips, native_rows), start=1):
        prefix = f"{label}:{index}"
        checks.require(row.get("trade_index") == index, "NATIVE_HTML_INDEX_INVALID", prefix)
        checks.require(str(row.get("symbol") or "").upper() == trade.symbol.upper(), "NATIVE_HTML_SYMBOL_MISMATCH", prefix)
        checks.require(str(row.get("side") or "").casefold() == trade.side.casefold(), "NATIVE_HTML_SIDE_MISMATCH", prefix)
        checks.require(row.get("entry_time_mt5_server") == trade.entry_time, "NATIVE_HTML_ENTRY_TIME_MISMATCH", prefix)
        checks.require(row.get("exit_time_mt5_server") == trade.exit_time, "NATIVE_HTML_EXIT_TIME_MISMATCH", prefix)
        for field, value, tolerance in (
            ("entry_price", trade.entry_price, 1e-8),
            ("exit_price", trade.exit_price, 1e-8),
            ("volume", trade.volume, 1e-8),
            ("gross_profit", trade.gross_pnl, 0.011),
            ("swap", trade.recorded_swap, 0.011),
            ("commission", trade.native_commission, 0.011),
        ):
            checks.require(
                numeric_equal(row.get(field), value, tolerance),
                "NATIVE_HTML_VALUE_MISMATCH",
                f"{prefix}:{field}",
            )
        expected_net = trade.gross_pnl + trade.recorded_swap + trade.native_commission
        checks.require(
            numeric_equal(row.get("net_profit"), expected_net, 0.011),
            "NATIVE_HTML_VALUE_MISMATCH",
            f"{prefix}:net_profit",
        )


def _validate_extractor_receipt(
    payload: Mapping[str, Any] | None,
    *,
    producer: str,
    run_id: str,
    segment_id: str,
    extractor_sha256: str | None,
    input_path: Path | None,
    input_sha256: str | None,
    output_path: Path | None,
    output_sha256: str | None,
    segment_start: dt.datetime | None,
    segment_finish: dt.datetime | None,
    label: str,
    checks: Checks,
) -> None:
    if payload is None:
        return
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "run_id",
            "segment_id",
            "producer",
            "extractor_sha256",
            "input",
            "output",
            "canonicalization_contract",
            "deterministic",
            "exit_code",
            "started_utc",
            "finished_utc",
        },
        "EXTRACTOR_RECEIPT_FIELDS_INVALID",
        label,
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == EXTRACTOR_RECEIPT_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("run_id") == run_id
        and payload.get("segment_id") == segment_id
        and payload.get("producer") == producer,
        "EXTRACTOR_RECEIPT_SCOPE_INVALID",
        label,
    )
    checks.require(
        payload.get("extractor_sha256") == extractor_sha256
        and payload.get("input") == {"path": str(input_path), "sha256": input_sha256}
        and payload.get("output") == {"path": str(output_path), "sha256": output_sha256},
        "EXTRACTOR_RECEIPT_BINDING_INVALID",
        label,
    )
    checks.require(
        payload.get("canonicalization_contract") == "DXZ_12567_FULL_ROUND_TRIP_IDENTITY_V1"
        and payload.get("deterministic") is True
        and payload.get("exit_code") == 0,
        "EXTRACTOR_RECEIPT_EXECUTION_INVALID",
        label,
    )
    started = _parse_utc(payload.get("started_utc"))
    finished = _parse_utc(payload.get("finished_utc"))
    checks.require(
        started is not None
        and finished is not None
        and started < finished
        and (segment_start is None or segment_start <= started)
        and (segment_finish is None or finished <= segment_finish),
        "EXTRACTOR_RECEIPT_TIME_INVALID",
        label,
    )


def _validate_mt5_native_history_file(
    path: Path, *, symbol: str, kind: str, label: str, checks: Checks
) -> None:
    expected = {
        "HCC": (b"\xf6\x01\x00\x00", "History"),
        "TKC": (b"\xfd\x01\x00\x00", "Ticks"),
    }.get(kind)
    if expected is None:
        return
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            raw = handle.read(4096)
    except OSError as exc:
        checks.errors.append(f"DATA_NATIVE_READ_ERROR: {label}: {exc}")
        return
    magic, marker = expected
    checks.require(
        size >= 256 and raw.startswith(magic),
        "DATA_NATIVE_MAGIC_OR_LENGTH_INVALID",
        label,
    )
    header_bytes = raw[4 : min(len(raw), 4096)]
    if len(header_bytes) % 2:
        header_bytes = header_bytes[:-1]
    try:
        header = header_bytes.decode("utf-16-le", errors="strict")
    except UnicodeError:
        checks.errors.append(f"DATA_NATIVE_HEADER_INVALID: {label}")
        return
    checks.require(
        marker in header and symbol in header,
        "DATA_NATIVE_SYMBOL_OR_KIND_INVALID",
        label,
    )


def _required_native_periods(segment_id: str) -> tuple[set[str], set[str]]:
    window = SEGMENT_NATIVE_DATA_WINDOWS.get(segment_id)
    if window is None:
        return set(), set()
    start = dt.date.fromisoformat(window[0])
    last = dt.date.fromisoformat(window[1]) - dt.timedelta(days=1)
    years = {f"{year:04d}.hcc" for year in range(start.year, last.year + 1)}
    months: set[str] = set()
    cursor = dt.date(start.year, start.month, 1)
    last_month = dt.date(last.year, last.month, 1)
    while cursor <= last_month:
        months.add(f"{cursor.year:04d}{cursor.month:02d}.tkc")
        cursor = (
            dt.date(cursor.year + 1, 1, 1)
            if cursor.month == 12
            else dt.date(cursor.year, cursor.month + 1, 1)
        )
    return years, months


def _validate_data_file_manifest(
    payload: Mapping[str, Any] | None,
    *,
    run_id: str,
    segment_id: str,
    run_root: Path,
    base_dir: Path,
    label: str,
    checks: Checks,
) -> None:
    if payload is None:
        return
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "run_id",
            "segment_id",
            "immutable",
            "required_symbols",
            "files",
            "artifact_payload_sha256",
        },
        "DATA_MANIFEST_FIELDS_INVALID",
        label,
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == DATA_MANIFEST_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("run_id") == run_id
        and payload.get("segment_id") == segment_id
        and payload.get("immutable") is True
        and payload.get("required_symbols") == list(REQUIRED_DWX),
        "DATA_MANIFEST_SCOPE_INVALID",
        label,
    )
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "DATA_MANIFEST_PAYLOAD_HASH_INVALID",
        label,
    )
    files = payload.get("files") or []
    required_hcc, required_tkc = _required_native_periods(segment_id)
    expected = {
        (symbol, "HCC", period)
        for symbol in REQUIRED_DWX
        for period in required_hcc
    } | {
        (symbol, "TKC", period)
        for symbol in REQUIRED_DWX
        for period in required_tkc
    } | {(symbol, "SEGMENTATION_CSV", "CSV") for symbol in REQUIRED_DWX}
    observed: set[tuple[str, str, str]] = set()
    digests: dict[tuple[str, str, str], str] = {}
    for index, row in enumerate(files):
        if not isinstance(row, Mapping):
            checks.errors.append(f"DATA_MANIFEST_FILE_INVALID: {label}:{index}")
            continue
        checks.require(
            set(row) == {"symbol", "kind", "path", "sha256", "bytes"},
            "DATA_MANIFEST_FILE_FIELDS_INVALID",
            f"{label}:{index}",
        )
        symbol = str(row.get("symbol") or "")
        kind = str(row.get("kind") or "")
        path, digest, _ = checks.binding(
            row,
            label=f"{label}.{index}.{symbol}.{kind}",
            base_dir=base_dir,
            unique=True,
        )
        period = "CSV" if kind == "SEGMENTATION_CSV" else path.name.casefold() if path is not None else ""
        identity = (symbol, kind, period)
        checks.require(
            identity in expected and identity not in observed,
            "DATA_MANIFEST_FILE_ID_INVALID",
            f"{label}:{identity}",
        )
        if identity in expected and identity not in observed:
            observed.add(identity)
            if digest is not None:
                digests[identity] = digest
        if path is not None:
            checks.require(_within(path, run_root), "DATA_FILE_OUTSIDE_RUN_ROOT", str(path))
            expected_suffix = {"HCC": ".hcc", "TKC": ".tkc", "SEGMENTATION_CSV": ".csv"}.get(kind)
            checks.require(path.suffix.casefold() == expected_suffix, "DATA_FILE_EXTENSION_INVALID", str(path))
            if kind in {"HCC", "TKC"}:
                expected_parent = "history" if kind == "HCC" else "ticks"
                checks.require(
                    path.parent.name == symbol
                    and path.parent.parent.name.casefold() == expected_parent,
                    "DATA_NATIVE_PATH_SCOPE_INVALID",
                    str(path),
                )
                _validate_mt5_native_history_file(
                    path,
                    symbol=symbol,
                    kind=kind,
                    label=f"{label}.{symbol}.{kind}.{period}",
                    checks=checks,
                )
            if kind == "SEGMENTATION_CSV":
                checks.require(
                    symbol.casefold().replace(".", "_")
                    in path.stem.casefold().replace(".", "_"),
                    "DATA_CSV_SYMBOL_FILENAME_INVALID",
                    str(path),
                )
                try:
                    lines = path.read_text(encoding="utf-8-sig", errors="strict").splitlines()
                except (OSError, UnicodeError) as exc:
                    checks.errors.append(f"DATA_CSV_READ_ERROR: {path}: {exc}")
                else:
                    checks.require(
                        len(lines) > 1
                        and lines[0].strip().casefold() == "time,open,high,low,close,tickvol",
                        "DATA_CSV_SEMANTICS_INVALID",
                        str(path),
                    )
                    timestamps: list[int] = []
                    rows_valid = True
                    for line_number, line in enumerate(lines[1:], start=2):
                        cells = line.split(",")
                        if len(cells) != 6:
                            rows_valid = False
                            continue
                        try:
                            stamp = int(cells[0])
                            open_, high, low, close, tickvol = (
                                Decimal(cell) for cell in cells[1:]
                            )
                        except (ValueError, InvalidOperation):
                            rows_valid = False
                            continue
                        if not (
                            stamp > 0
                            and all(value.is_finite() for value in (open_, high, low, close, tickvol))
                            and low > 0
                            and low <= min(open_, close)
                            and high >= max(open_, close)
                            and tickvol >= 0
                        ):
                            rows_valid = False
                        timestamps.append(stamp)
                    checks.require(rows_valid, "DATA_CSV_ROW_SEMANTICS_INVALID", str(path))
                    checks.require(
                        timestamps == sorted(set(timestamps)),
                        "DATA_CSV_TIME_ORDER_INVALID",
                        str(path),
                    )
                    window = SEGMENT_NATIVE_DATA_WINDOWS.get(segment_id)
                    if timestamps and window is not None:
                        start_epoch = int(
                            dt.datetime.fromisoformat(window[0])
                            .replace(tzinfo=dt.timezone.utc)
                            .timestamp()
                        )
                        end_epoch = int(
                            (
                                dt.datetime.fromisoformat(window[1])
                                .replace(tzinfo=dt.timezone.utc)
                                - dt.timedelta(days=1)
                            ).timestamp()
                        )
                        checks.require(
                            timestamps[0] <= start_epoch and timestamps[-1] >= end_epoch,
                            "DATA_CSV_WINDOW_COVERAGE_INVALID",
                            str(path),
                        )
    checks.require(observed == expected, "DATA_MANIFEST_COVERAGE_INVALID", label)
    for kind, period in sorted({(kind, period) for _, kind, period in expected}):
        checks.require(
            digests.get(("EURUSD.DWX", kind, period))
            != digests.get(("XAUUSD.DWX", kind, period)),
            "DATA_CROSS_SYMBOL_BYTES_REUSED",
            f"{label}:{kind}:{period}",
        )


def _validate_instrument_snapshot(
    payload: Mapping[str, Any] | None,
    *,
    run_id: str,
    segment_id: str,
    run_root: Path,
    base_dir: Path,
    label: str,
    checks: Checks,
    segment_start: dt.datetime | None = None,
    segment_finish: dt.datetime | None = None,
) -> None:
    if payload is None:
        return
    observed_utc = _parse_utc(payload.get("observed_utc"))
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "run_id",
            "segment_id",
            "account_currency",
            "observed_utc",
            "records",
            "artifact_payload_sha256",
        },
        "INSTRUMENT_SNAPSHOT_FIELDS_INVALID",
        label,
    )
    checks.require(
        payload.get("schema_version") == 1
        and payload.get("artifact_type") == INSTRUMENT_SNAPSHOT_ARTIFACT
        and payload.get("packet_id") == PACKET_ID
        and payload.get("run_id") == run_id
        and payload.get("segment_id") == segment_id
        and payload.get("account_currency") == "EUR"
        and observed_utc is not None
        and (segment_start is None or segment_start <= observed_utc)
        and (segment_finish is None or observed_utc <= segment_finish),
        "INSTRUMENT_SNAPSHOT_SCOPE_INVALID",
        label,
    )
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "INSTRUMENT_SNAPSHOT_PAYLOAD_HASH_INVALID",
        label,
    )
    records = payload.get("records") or []
    by_symbol = {
        str(row.get("symbol") or ""): row for row in records if isinstance(row, Mapping)
    }
    checks.require(set(by_symbol) == set(REQUIRED_DWX) and len(records) == 2, "INSTRUMENT_SNAPSHOT_COVERAGE_INVALID", label)
    required_property_keys = {
        "digits",
        "point",
        "tick_size",
        "tick_value",
        "contract_size",
        "currency_base",
        "currency_profit",
        "currency_margin",
        "trade_calc_mode",
    }
    for symbol in REQUIRED_DWX:
        row = by_symbol.get(symbol)
        if not isinstance(row, Mapping):
            continue
        checks.require(set(row) == {"symbol", "source", "properties"}, "INSTRUMENT_RECORD_FIELDS_INVALID", symbol)
        source_path, _, source_payload = checks.binding(
            row.get("source"),
            label=f"{label}.{symbol}.source",
            base_dir=base_dir,
            unique=True,
            json_object=True,
        )
        if source_path is not None:
            checks.require(_within(source_path, run_root), "INSTRUMENT_SOURCE_OUTSIDE_RUN_ROOT", str(source_path))
        properties = row.get("properties")
        checks.require(isinstance(properties, Mapping) and set(properties) == required_property_keys, "INSTRUMENT_PROPERTIES_INVALID", symbol)
        checks.require(
            isinstance(source_payload, Mapping)
            and set(source_payload)
            == {"schema_version", "artifact_type", "symbol", "properties"}
            and source_payload.get("schema_version") == 1
            and source_payload.get("artifact_type") == "DXZ_MT5_SYMBOL_SPEC_EXPORT"
            and source_payload.get("symbol") == symbol
            and source_payload.get("properties") == properties,
            "INSTRUMENT_SOURCE_SEMANTICS_INVALID",
            symbol,
        )
        if isinstance(properties, Mapping):
            for field in ("digits", "point", "tick_size", "tick_value", "contract_size"):
                value = _decimal(properties.get(field))
                checks.require(value is not None and value > 0, "INSTRUMENT_NUMERIC_PROPERTY_INVALID", f"{symbol}:{field}")
            digits = properties.get("digits")
            point = _decimal(properties.get("point"))
            tick_size = _decimal(properties.get("tick_size"))
            checks.require(
                isinstance(digits, int)
                and 0 <= digits <= 10
                and point == Decimal(1).scaleb(-digits),
                "INSTRUMENT_POINT_DIGITS_INCONSISTENT",
                symbol,
            )
            checks.require(
                point is not None
                and tick_size is not None
                and tick_size >= point
                and (tick_size / point) == (tick_size / point).to_integral_value(),
                "INSTRUMENT_TICK_SIZE_INCONSISTENT",
                symbol,
            )
            checks.require(properties.get("currency_profit") == "USD", "INSTRUMENT_PROFIT_CURRENCY_INVALID", symbol)
            if symbol == "XAUUSD.DWX":
                checks.require(properties.get("currency_base") == "XAU", "INSTRUMENT_BASE_CURRENCY_INVALID", symbol)
            else:
                checks.require(properties.get("currency_base") == "EUR", "INSTRUMENT_BASE_CURRENCY_INVALID", symbol)


def _validate_run_receipt(
    binding: Any,
    *,
    label: str,
    expected_phase: str,
    expected_mode: str,
    spec: Mapping[str, Any],
    base_dir: Path,
    expected_hashes: Mapping[str, str],
    q08_extractor_sha256: str | None,
    native_extractor_sha256: str | None,
    weekend_cutoffs: Sequence[dt.datetime],
    seal_path: Path | None,
    seal_sha: str | None,
    checks: Checks,
) -> dict[str, Any] | None:
    receipt_path, receipt_sha, receipt = checks.binding(
        binding, label=f"{label}.receipt", base_dir=base_dir, unique=True, json_object=True
    )
    if receipt is None or receipt_path is None or receipt_sha is None:
        return None
    checks.require(receipt.get("schema_version") == 2 and receipt.get("artifact_type") == RECEIPT_ARTIFACT, "RECEIPT_SCHEMA_INVALID", label)
    checks.require(receipt.get("packet_id") == PACKET_ID, "RECEIPT_PACKET_INVALID", label)
    checks.require(receipt.get("phase") == expected_phase and receipt.get("mode") == expected_mode, "RECEIPT_MODE_INVALID", label)
    scope = receipt.get("scope") or {}
    checks.require(scope == {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1", "magic": 125670003}, "RECEIPT_SCOPE_INVALID", label)
    run_id = str(receipt.get("run_id") or "")
    isolation_id = str(receipt.get("isolation_id") or "")
    execution_id = str(receipt.get("execution_id") or "")
    checks.require(bool(run_id) and bool(isolation_id) and bool(execution_id), "RECEIPT_IDS_INVALID", label)
    root_text = str(receipt.get("run_root") or "")
    root = Path(root_text)
    checks.require(root.is_absolute() and root.is_dir() and not _forbidden_execution_path(root), "RUN_ROOT_INVALID", label)
    checks.require(receipt.get("output_root") == root_text, "RUN_OUTPUT_ROOT_INVALID", label)
    checks.require(_within(receipt_path, root), "RECEIPT_OUTSIDE_RUN_ROOT", label)
    start = _parse_utc(receipt.get("started_utc"))
    finish = _parse_utc(receipt.get("finished_utc"))
    checks.require(start is not None and finish is not None and start < finish, "RECEIPT_TIME_INVALID", label)
    checks.require(receipt.get("collision_free") is True and receipt.get("source_inputs_unchanged") is True, "RECEIPT_ISOLATION_INVALID", label)
    hashes = receipt.get("input_hashes") or {}
    checks.require(hashes == dict(expected_hashes), "RECEIPT_INPUT_HASHES_INVALID", label)
    reference = receipt.get("reference") or {}
    if expected_phase == "BASELINE":
        checks.require(reference.get("selected") is False and reference.get("path") is None and reference.get("sha256") is None, "BASELINE_REFERENCE_SELECTED", label)
    else:
        reference_path = Path(str(reference.get("path") or ""))
        if not reference_path.is_absolute():
            reference_path = base_dir / reference_path
        checks.require(
            reference.get("selected") is True
            and reference.get("sha256") == seal_sha
            and seal_path is not None
            and _path_key(reference_path) == _path_key(seal_path),
            "QUALIFICATION_REFERENCE_INVALID",
            label,
        )

    expected_segments = (spec.get("history_contract") or {}).get("segments") or []
    raw_segments = receipt.get("segments") or []
    checks.require(len(raw_segments) == 4, "RUN_SEGMENT_COUNT_INVALID", label)
    results: dict[str, Any] = {}
    segment_windows: list[tuple[dt.datetime, dt.datetime, str]] = []
    segment_execution_ids: list[str] = []
    sandbox_ids: list[str] = []
    segment_output_roots: list[Path] = []
    for index, expected in enumerate(expected_segments):
        if index >= len(raw_segments) or not isinstance(raw_segments[index], Mapping):
            checks.errors.append(f"RUN_SEGMENT_INVALID: {label}:{index}")
            continue
        segment = raw_segments[index]
        segment_id = str(expected.get("segment_id"))
        role = str(expected.get("role"))
        seg_label = f"{label}.{segment_id}"
        checks.require(segment.get("segment_id") == segment_id and segment.get("role") == role, "RUN_SEGMENT_ORDER_INVALID", seg_label)
        segment_execution_id = str(segment.get("execution_id") or "")
        sandbox_id = str(segment.get("sandbox_id") or "")
        checks.require(bool(segment_execution_id), "RUN_SEGMENT_EXECUTION_ID_INVALID", seg_label)
        checks.require(SANDBOX_RE.fullmatch(sandbox_id) is not None, "RUN_SEGMENT_SANDBOX_INVALID", seg_label)
        segment_execution_ids.append(segment_execution_id)
        sandbox_ids.append(sandbox_id)
        output = Path(str(segment.get("output_root") or ""))
        checks.require(
            output.is_absolute()
            and output.is_dir()
            and not _forbidden_execution_path(output)
            and _within(output, root)
            and _path_key(output) != _path_key(root),
            "RUN_SEGMENT_OUTPUT_INVALID",
            seg_label,
        )
        segment_output_roots.append(output)
        seg_start = _parse_utc(segment.get("started_utc"))
        seg_finish = _parse_utc(segment.get("finished_utc"))
        checks.require(seg_start is not None and seg_finish is not None and seg_start < seg_finish, "RUN_SEGMENT_TIME_INVALID", seg_label)
        if seg_start is not None and seg_finish is not None:
            checks.require((start is None or start <= seg_start) and (finish is None or seg_finish <= finish), "RUN_SEGMENT_OUTSIDE_RUN", seg_label)
            segment_windows.append((seg_start, seg_finish, seg_label))
        history = segment.get("history") or {}
        checks.require(history.get("literal_dwx_only") is True and history.get("required_symbols") == list(REQUIRED_DWX), "HISTORY_DWX_SCOPE_INVALID", seg_label)
        checks.require(history.get("fresh_process") is True and history.get("indicator_state_reset") is True and history.get("rolling_state_reset") is True, "HISTORY_STATE_NOT_RESET", seg_label)
        checks.require(history.get("entries_during_warmup") == 0, "HISTORY_WARMUP_ENTRY", seg_label)
        for field in ("position_at_start", "position_at_end", "pending_orders_at_start", "pending_orders_at_end", "tester_forced_exit_count"):
            checks.require(history.get(field) == 0, "HISTORY_ENDPOINT_INVALID", f"{seg_label}.{field}")
        checks.require(history.get("input_manifest_start_sha256") == history.get("input_manifest_end_sha256") and _valid_sha(history.get("input_manifest_start_sha256")), "HISTORY_INPUT_CHANGED", seg_label)
        inference = role == "INFERENCE"
        checks.require(history.get("score_enabled") is inference and history.get("economics_used") is inference, "HISTORY_ROLE_INVALID", seg_label)
        if inference:
            checks.require(isinstance(history.get("warmup_d1_bars"), int) and history["warmup_d1_bars"] >= 200 and history.get("warmup_complete") is True, "HISTORY_D1_WARMUP_SHORT", seg_label)
        else:
            checks.require(history.get("warmup_complete") is False, "CONTINUITY_MARKED_WARM", seg_label)

        artifacts = segment.get("artifacts") or {}
        bound: dict[str, tuple[Path | None, str | None]] = {}
        structured: dict[str, dict[str, Any] | None] = {}
        for name in (
            "history_receipt",
            "reset_receipt",
            "native_report",
            "q08_raw",
            "q08_identity_stream",
            "native_identity_stream",
            "data_file_manifest",
            "instrument_snapshot",
            "q08_extractor_receipt",
            "native_extractor_receipt",
        ):
            json_object = name in {
                "data_file_manifest",
                "instrument_snapshot",
                "q08_extractor_receipt",
                "native_extractor_receipt",
            }
            path, digest, payload = checks.binding(
                artifacts.get(name),
                label=f"{seg_label}.{name}",
                base_dir=base_dir,
                unique=True,
                json_object=json_object,
            )
            bound[name] = (path, digest)
            structured[name] = payload
            if path is not None:
                _require_within_own_output(
                    path,
                    output,
                    label=f"{seg_label}.{name}",
                    checks=checks,
                )
        _validate_data_file_manifest(
            structured.get("data_file_manifest"),
            run_id=run_id,
            segment_id=segment_id,
            run_root=output,
            base_dir=base_dir,
            label=f"{seg_label}.data_file_manifest",
            checks=checks,
        )
        _validate_instrument_snapshot(
            structured.get("instrument_snapshot"),
            run_id=run_id,
            segment_id=segment_id,
            run_root=output,
            base_dir=base_dir,
            label=f"{seg_label}.instrument_snapshot",
            checks=checks,
            segment_start=seg_start,
            segment_finish=seg_finish,
        )
        expected_history_hash = canonical_json_sha(
            {
                "data_file_manifest_sha256": bound["data_file_manifest"][1],
                "instrument_snapshot_sha256": bound["instrument_snapshot"][1],
            }
        )
        checks.require(
            history.get("data_file_manifest_sha256") == bound["data_file_manifest"][1]
            and history.get("instrument_snapshot_sha256") == bound["instrument_snapshot"][1]
            and history.get("input_manifest_start_sha256") == expected_history_hash,
            "HISTORY_ACTUAL_MANIFEST_BINDING_INVALID",
            seg_label,
        )
        q08_meta = segment.get("q08_identity") or {}
        native_meta = segment.get("native_identity") or {}
        checks.require(q08_meta.get("producer") == "Q08_INSTRUMENTED_EXTRACTOR" and q08_meta.get("source_sha256") == bound["q08_raw"][1], "Q08_PRODUCER_INVALID", seg_label)
        checks.require(native_meta.get("producer") == "NATIVE_REPORT_INDEPENDENT_EXTRACTOR" and native_meta.get("source_sha256") == bound["native_report"][1], "NATIVE_PRODUCER_INVALID", seg_label)
        checks.require(bound["q08_identity_stream"][0] != bound["native_identity_stream"][0], "IDENTITY_STREAMS_NOT_INDEPENDENT", seg_label)
        q08_rows = _read_identity_rows(bound["q08_identity_stream"][0], segment_id=segment_id, label=f"{seg_label}.q08", checks=checks)
        native_rows = _read_identity_rows(bound["native_identity_stream"][0], segment_id=segment_id, label=f"{seg_label}.native", checks=checks)
        raw_q08_rows = _read_q08_raw_identity_rows(
            bound["q08_raw"][0], segment_id=segment_id, label=f"{seg_label}.q08_raw", checks=checks
        )
        checks.require(raw_q08_rows == q08_rows, "Q08_RAW_NORMALIZED_IDENTITY_MISMATCH", seg_label)
        _validate_native_html_semantics(
            bound["native_report"][0],
            native_rows,
            inference=inference,
            label=seg_label,
            checks=checks,
            segment_id=segment_id,
        )
        _validate_no_weekend_holdings(
            native_rows,
            cutoffs=weekend_cutoffs,
            label=seg_label,
            checks=checks,
        )
        _validate_extractor_receipt(
            structured.get("q08_extractor_receipt"),
            producer="Q08_INSTRUMENTED_EXTRACTOR",
            run_id=run_id,
            segment_id=segment_id,
            extractor_sha256=q08_extractor_sha256,
            input_path=bound["q08_raw"][0],
            input_sha256=bound["q08_raw"][1],
            output_path=bound["q08_identity_stream"][0],
            output_sha256=bound["q08_identity_stream"][1],
            segment_start=seg_start,
            segment_finish=seg_finish,
            label=f"{seg_label}.q08_extractor_receipt",
            checks=checks,
        )
        _validate_extractor_receipt(
            structured.get("native_extractor_receipt"),
            producer="NATIVE_REPORT_INDEPENDENT_EXTRACTOR",
            run_id=run_id,
            segment_id=segment_id,
            extractor_sha256=native_extractor_sha256,
            input_path=bound["native_report"][0],
            input_sha256=bound["native_report"][1],
            output_path=bound["native_identity_stream"][0],
            output_sha256=bound["native_identity_stream"][1],
            segment_start=seg_start,
            segment_finish=seg_finish,
            label=f"{seg_label}.native_extractor_receipt",
            checks=checks,
        )
        q08_digest = _identity_digests(q08_rows)
        native_digest = _identity_digests(native_rows)
        checks.require(q08_digest == native_digest, "Q08_NATIVE_FULL_IDENTITY_MISMATCH", seg_label)
        declared_q08 = {"trade_count": q08_meta.get("trade_count"), **{axis: q08_meta.get(axis) for axis in IDENTITY_AXES}}
        declared_native = {"trade_count": native_meta.get("trade_count"), **{axis: native_meta.get(axis) for axis in IDENTITY_AXES}}
        checks.require(declared_q08 == q08_digest, "Q08_DECLARED_DIGEST_INVALID", seg_label)
        checks.require(declared_native == native_digest, "NATIVE_DECLARED_DIGEST_INVALID", seg_label)
        checks.require(q08_digest["trade_count"] > 0 if inference else q08_digest["trade_count"] == 0, "SEGMENT_TRADE_COUNT_INVALID", seg_label)
        results[segment_id] = {"identity": q08_digest, "history_input_sha256": history.get("input_manifest_start_sha256")}
    segment_windows.sort()
    for left, right in zip(segment_windows, segment_windows[1:]):
        checks.require(left[1] <= right[0], "RUN_SEGMENTS_NOT_SERIAL", f"{left[2]}->{right[2]}")
    return {
        "label": label,
        "run_id": run_id,
        "isolation_id": isolation_id,
        "execution_id": execution_id,
        "run_root": root,
        "receipt_path": receipt_path,
        "receipt_sha256": receipt_sha,
        "start": start,
        "finish": finish,
        "segments": results,
        "segment_execution_ids": segment_execution_ids,
        "sandbox_ids": sandbox_ids,
        "segment_output_roots": segment_output_roots,
    }


def _validate_sealed_input(
    payload: Mapping[str, Any] | None, expected_hashes: Mapping[str, str], checks: Checks
) -> None:
    if payload is None:
        return
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "immutable",
            "scope",
            "required_symbols",
            "segment_ids",
            "input_hashes",
            "artifact_payload_sha256",
        },
        "SEALED_INPUT_FIELDS_INVALID",
    )
    checks.require(payload.get("schema_version") == 3 and payload.get("artifact_type") == SEALED_INPUT_ARTIFACT, "SEALED_INPUT_SCHEMA_INVALID")
    checks.require(payload.get("packet_id") == PACKET_ID and payload.get("immutable") is True, "SEALED_INPUT_SCOPE_INVALID")
    checks.require(payload.get("scope") == {"ea_id": 12567, "symbol": "XAUUSD.DWX", "timeframe": "D1", "magic": 125670003}, "SEALED_INPUT_SCOPE_INVALID")
    checks.require(payload.get("required_symbols") == list(REQUIRED_DWX), "SEALED_INPUT_DWX_INVALID")
    checks.require(payload.get("segment_ids") == list(SEGMENTS), "SEALED_INPUT_SEGMENTS_INVALID")
    checks.require(payload.get("input_hashes") == dict(expected_hashes), "SEALED_INPUT_HASHES_INVALID")
    declared = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    checks.require(
        _valid_sha(declared) and canonical_json_sha(unsigned) == declared,
        "SEALED_INPUT_PAYLOAD_HASH_INVALID",
    )


def _validate_seal(
    binding: Any,
    *,
    base_dir: Path,
    baselines: Sequence[dict[str, Any]],
    expected_hashes: Mapping[str, str],
    public_key: bytes | None,
    checks: Checks,
) -> tuple[Path | None, str | None, dict[str, Any] | None, dt.datetime | None]:
    path, digest, seal = checks.binding(
        binding,
        label="bundle.owner_seal",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    if seal is None:
        return path, digest, seal, None
    checks.require(
        set(seal)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "status",
            "qualification_reference_eligible",
            "independent_market_reference",
            "created_utc",
            "baseline_receipts",
            "input_hashes",
            "consensus",
            "consensus_sha256",
            "owner_approval",
        },
        "SEAL_FIELDS_INVALID",
    )
    checks.require(not _find_forbidden_self_keys(seal), "SEAL_SELF_REFERENCE_FORBIDDEN")
    checks.require(seal.get("schema_version") == 2 and seal.get("artifact_type") == SEAL_ARTIFACT, "SEAL_SCHEMA_INVALID")
    checks.require(seal.get("packet_id") == PACKET_ID and seal.get("status") == "OWNER_SEALED", "SEAL_STATUS_INVALID")
    checks.require(seal.get("qualification_reference_eligible") is True, "SEAL_NOT_REFERENCE_ELIGIBLE")
    checks.require(seal.get("independent_market_reference") is False, "SEAL_INDEPENDENCE_OVERCLAIM")
    created = _parse_utc(seal.get("created_utc"))
    checks.require(created is not None, "SEAL_TIME_INVALID")
    declared = seal.get("baseline_receipts") or []
    expected = [{"path": str(row["receipt_path"]), "sha256": row["receipt_sha256"]} for row in baselines]
    checks.require(declared == expected, "SEAL_BASELINE_BINDINGS_INVALID")
    checks.require(seal.get("input_hashes") == dict(expected_hashes), "SEAL_INPUT_HASHES_INVALID")
    consensus = seal.get("consensus") or {}
    if len(baselines) == 2:
        for segment_id in SEGMENTS:
            left = baselines[0]["segments"].get(segment_id, {}).get("identity")
            right = baselines[1]["segments"].get(segment_id, {}).get("identity")
            checks.require(left == right and consensus.get(segment_id) == left, "SEAL_CONSENSUS_INVALID", segment_id)
    consensus_sha = canonical_json_sha(consensus)
    checks.require(seal.get("consensus_sha256") == consensus_sha, "SEAL_CONSENSUS_HASH_INVALID")
    _, _, approval = checks.binding(
        seal.get("owner_approval"),
        label="seal.owner_approval",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    _verify_owner_signed_payload(
        approval,
        expected_decision_type="QUALIFICATION_REFERENCE_SEAL",
        public_key=public_key,
        checks=checks,
        label="qualification_reference_seal",
    )
    if isinstance(approval, Mapping):
        checks.require(
            approval.get("decision")
            == {
                "baseline_receipt_sha256": [row["receipt_sha256"] for row in baselines],
                "consensus_sha256": consensus_sha,
                "input_hashes_sha256": canonical_json_sha(dict(expected_hashes)),
                "seal_created_utc": seal.get("created_utc"),
            },
            "SEAL_OWNER_SIGNED_DECISION_MISMATCH",
        )
        signed = _parse_utc(approval.get("signed_utc"))
        checks.require(
            signed is not None and created is not None and signed >= created,
            "SEAL_OWNER_SIGNATURE_TIME_INVALID",
        )
    return path, digest, seal, created


def validate_bundle(
    spec_path: Path,
    bundle_path: Path,
    *,
    verify_anchors: bool = True,
    owner_trust_anchor_path: Path | None = None,
    owner_trust_anchor_sha256: str | None = None,
) -> dict[str, Any]:
    checks = Checks()
    try:
        spec = _load_object(spec_path)
    except ValueError as exc:
        checks.errors.append(f"SPEC_READ_ERROR: {exc}")
        return checks.report()
    _validate_spec_payload(spec, spec_path, checks, verify_anchors=verify_anchors)
    try:
        bundle = _load_object(bundle_path)
    except ValueError as exc:
        checks.errors.append(f"BUNDLE_READ_ERROR: {exc}")
        return checks.report(spec_sha256=sha256_file(spec_path))
    base_dir = bundle_path.parent
    spec_sha = sha256_file(spec_path)
    checks.require(bundle.get("schema_version") == 1 and bundle.get("artifact_type") == BUNDLE_ARTIFACT, "BUNDLE_SCHEMA_INVALID")
    checks.require(bundle.get("packet_id") == PACKET_ID and bundle.get("spec_sha256") == spec_sha, "BUNDLE_SPEC_BINDING_INVALID")
    checks.require(bundle.get("status") == "READY_FOR_QUALIFICATION_VALIDATION", "BUNDLE_STATUS_INVALID")
    checks.require(bundle.get("deployment_eligible") is False, "BUNDLE_DEPLOYMENT_SCOPE_INVALID")
    checks.require(
        not _find_forbidden_self_keys(bundle),
        "BUNDLE_SELF_REFERENCE_FORBIDDEN",
    )
    as_of = _parse_utc(bundle.get("generated_utc"))
    checks.require(as_of is not None, "BUNDLE_TIME_INVALID")

    owner_public_key, owner_trust_sha = _load_owner_trust_anchor(
        spec,
        bundle,
        base_dir,
        checks,
        out_of_band_path=owner_trust_anchor_path,
        out_of_band_sha256=owner_trust_anchor_sha256,
    )
    _, source_capture_sha, _ = checks.binding(
        bundle.get("source_capture"),
        label="bundle.source_capture",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    card_path, card_sha, _ = checks.binding(
        bundle.get("card_v2"),
        label="bundle.card_v2",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    _validate_card_v2(card_path, checks)
    decisions, owner_receipt_hashes = _validate_owner_gates(
        spec, bundle, base_dir, owner_public_key, checks
    )
    _, effective_sha = _validate_effective_contract(spec, bundle, decisions, checks)

    build = bundle.get("build") or {}
    checks.require(build.get("clean_compile") is True and build.get("compile_pass") is True and build.get("recursive_include_closure_bound") is True, "BUILD_INVALID")
    _, closure_sha, closure_payload = checks.binding(
        build.get("source_closure_manifest"),
        label="build.source_closure_manifest",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    source_of_record_sha = _validate_source_closure_manifest(
        closure_payload, base_dir=base_dir, checks=checks
    )
    compile_log_path, compile_log_sha, _ = checks.binding(
        build.get("compile_log"),
        label="build.compile_log",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    _, ex5_sha, _ = checks.binding(
        build.get("ex5"),
        label="build.ex5",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    checks.require(
        build.get("source_closure_manifest_sha256") == closure_sha
        and build.get("source_of_record_sha256") == source_of_record_sha,
        "BUILD_SOURCE_OF_RECORD_INVALID",
    )
    checks.require(build.get("compiled_ex5_sha256") == ex5_sha, "BUILD_EX5_BINDING_INVALID")
    if compile_log_path is not None:
        try:
            compile_text = compile_log_path.read_text(encoding="utf-8-sig", errors="strict")
        except (OSError, UnicodeError) as exc:
            checks.errors.append(f"BUILD_COMPILE_LOG_READ_ERROR: {exc}")
        else:
            checks.require(
                "12567" in compile_text
                and re.search(r"(?i)\b0\s+errors?\s*[,;]\s*0\s+warnings?\b", compile_text)
                is not None,
                "BUILD_COMPILE_LOG_SEMANTICS_INVALID",
            )
    preset_path, preset_sha, _ = checks.binding(
        bundle.get("approved_preset"),
        label="bundle.approved_preset",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    risk_choice = decisions.get("AS_LIVE_RISK_CONTRACT")
    candidate = next((row for row in spec.get("risk_contract_candidates", []) if row.get("contract_id") == risk_choice), None)
    _validate_approved_preset(
        preset_path,
        candidate=candidate if isinstance(candidate, Mapping) else None,
        decisions=decisions,
        checks=checks,
    )
    q08_path, q08_extractor_sha, _ = checks.binding(
        bundle.get("q08_extractor"),
        label="bundle.q08_extractor",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    native_path, native_extractor_sha, _ = checks.binding(
        bundle.get("native_extractor"),
        label="bundle.native_extractor",
        base_dir=base_dir,
        unique=True,
        external=True,
    )
    checks.require(q08_path != native_path and q08_extractor_sha != native_extractor_sha, "IDENTITY_EXTRACTORS_NOT_INDEPENDENT")
    _, weekend_calendar_sha, weekend_calendar_payload = checks.binding(
        bundle.get("weekend_flat_calendar"),
        label="bundle.weekend_flat_calendar",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    weekend_cutoffs = _validate_weekend_flat_calendar(
        weekend_calendar_payload,
        base_dir=base_dir,
        checks=checks,
        as_of=as_of,
    )
    pre_cost_hashes = {
        "spec_sha256": spec_sha,
        "owner_trust_anchor_sha256": owner_trust_sha or "",
        "owner_gate_receipts_sha256": canonical_json_sha(owner_receipt_hashes),
        "source_capture_sha256": source_capture_sha or "",
        "card_v2_sha256": card_sha or "",
        "binary_sha256": ex5_sha or "",
        "preset_sha256": preset_sha or "",
        "effective_contract_sha256": effective_sha,
        "source_closure_sha256": closure_sha or "",
        "source_of_record_sha256": source_of_record_sha,
        "compile_log_sha256": compile_log_sha or "",
        "q08_extractor_sha256": q08_extractor_sha or "",
        "native_extractor_sha256": native_extractor_sha or "",
        "weekend_flat_calendar_sha256": weekend_calendar_sha or "",
        "segment_contract_sha256": canonical_json_sha(
            (spec.get("history_contract") or {}).get("segments") or []
        ),
        "data_contract_sha256": canonical_json_sha(
            {
                "required_symbols": list(REQUIRED_DWX),
                "required_native_artifacts": ["HCC", "TKC"],
                "segmentation_oracles": ["EURUSD.DWX_D1.csv", "XAUUSD.DWX_D1.csv"],
                "exceptional_dependency_gaps": (spec.get("history_contract") or {}).get(
                    "exceptional_dependency_gaps"
                )
                or [],
            }
        ),
    }
    cost_source_path, cost_source_sha, cost_source_payload = checks.binding(
        bundle.get("cost_source_manifest"),
        label="bundle.cost_source_manifest",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    _validate_cost_source_manifest(
        cost_source_payload, expected_hashes=pre_cost_hashes, checks=checks
    )
    cost_manifest_sha = _validate_costs(
        bundle,
        base_dir,
        as_of,
        source_manifest_sha256=cost_source_sha or "",
        checks=checks,
    )
    preseal_hashes = {
        **pre_cost_hashes,
        "cost_source_manifest_sha256": cost_source_sha or "",
        "execution_cost_manifest_sha256": cost_manifest_sha,
    }
    sealed_path, sealed_sha, sealed_payload = checks.binding(
        bundle.get("sealed_input_manifest"),
        label="bundle.sealed_input_manifest",
        base_dir=base_dir,
        unique=True,
        json_object=True,
        external=True,
    )
    checks.require(
        all(_valid_sha(value) for value in preseal_hashes.values()),
        "BUNDLE_REQUIRED_HASH_EMPTY_OR_DUMMY",
    )
    _validate_sealed_input(sealed_payload, preseal_hashes, checks)
    expected_hashes = {
        "sealed_input_manifest_sha256": sealed_sha or "",
        **preseal_hashes,
    }
    checks.require(
        all(_valid_sha(value) for value in expected_hashes.values()),
        "BUNDLE_REQUIRED_HASH_EMPTY_OR_DUMMY",
    )

    baseline_raw = bundle.get("baseline_runs") or []
    checks.require(len(baseline_raw) == 2, "BASELINE_RUN_COUNT_INVALID")
    baselines: list[dict[str, Any]] = []
    for index, raw in enumerate(baseline_raw[:2], start=1):
        result = _validate_run_receipt(
            raw,
            label=f"baseline_{index}",
            expected_phase="BASELINE",
            expected_mode="DISCOVERY_COMPLETE_UNREFERENCED",
            spec=spec,
            base_dir=base_dir,
            expected_hashes=expected_hashes,
            q08_extractor_sha256=q08_extractor_sha,
            native_extractor_sha256=native_extractor_sha,
            weekend_cutoffs=weekend_cutoffs,
            seal_path=None,
            seal_sha=None,
            checks=checks,
        )
        if result is not None:
            baselines.append(result)
    seal_path, seal_sha, seal_payload, seal_created = _validate_seal(
        bundle.get("owner_seal"),
        base_dir=base_dir,
        baselines=baselines,
        expected_hashes=expected_hashes,
        public_key=owner_public_key,
        checks=checks,
    )
    qualification_raw = bundle.get("qualification_runs") or []
    checks.require(len(qualification_raw) == 2, "QUALIFICATION_RUN_COUNT_INVALID")
    qualifications: list[dict[str, Any]] = []
    for index, raw in enumerate(qualification_raw[:2], start=1):
        result = _validate_run_receipt(
            raw,
            label=f"qualification_{index}",
            expected_phase="QUALIFICATION",
            expected_mode="AS_LIVE_REQUAL",
            spec=spec,
            base_dir=base_dir,
            expected_hashes=expected_hashes,
            q08_extractor_sha256=q08_extractor_sha,
            native_extractor_sha256=native_extractor_sha,
            weekend_cutoffs=weekend_cutoffs,
            seal_path=seal_path,
            seal_sha=seal_sha,
            checks=checks,
        )
        if result is not None:
            qualifications.append(result)

    runs = baselines + qualifications
    checks.require(len(runs) == 4, "RUN_SET_INCOMPLETE")
    all_identifiers: list[str] = []
    for field in ("run_id", "isolation_id", "execution_id"):
        values = [str(row[field]) for row in runs]
        checks.require(
            len(values) == 4 and len({value.casefold() for value in values}) == 4,
            "RUN_IDS_NOT_INDEPENDENT",
            field,
        )
        all_identifiers.extend(values)
    for row in runs:
        all_identifiers.extend(row["segment_execution_ids"])
        all_identifiers.extend(row["sandbox_ids"])
    checks.require(
        len({value.casefold() for value in all_identifiers}) == len(all_identifiers),
        "GLOBAL_IDS_NOT_INDEPENDENT_CASEFOLD",
    )
    root_keys = [_path_key(row["run_root"]) for row in runs]
    checks.require(len(root_keys) == 4 and len(set(root_keys)) == 4, "RUN_ROOTS_NOT_INDEPENDENT")
    for index, left in enumerate(runs):
        for right in runs[index + 1 :]:
            checks.require(
                not _strictly_nested(left["run_root"], right["run_root"]),
                "RUN_ROOTS_NESTED",
                f"{left['label']}:{right['label']}",
            )
    all_outputs = [path for row in runs for path in row["segment_output_roots"]]
    output_keys = [_path_key(path) for path in all_outputs]
    checks.require(
        len(output_keys) == 16 and len(set(output_keys)) == 16,
        "SEGMENT_OUTPUT_ROOTS_NOT_INDEPENDENT",
    )
    for index, left in enumerate(all_outputs):
        for right in all_outputs[index + 1 :]:
            checks.require(
                not _strictly_nested(left, right),
                "SEGMENT_OUTPUT_ROOTS_NESTED",
                f"{left}:{right}",
            )
    if seal_path is not None:
        checks.require(all(not _within(seal_path, row["run_root"]) for row in runs), "SEAL_INSIDE_RUN_ROOT")
    for external_label, external_path in checks.external_paths.items():
        checks.require(
            all(
                not _within(external_path, row["run_root"])
                and all(not _within(external_path, output) for output in row["segment_output_roots"])
                for row in runs
            ),
            "EXTERNAL_CONTROL_ARTIFACT_INSIDE_RUN_ROOT",
            external_label,
        )
    for control_label, control_path in (
        ("spec", spec_path.resolve(strict=False)),
        ("bundle", bundle_path.resolve(strict=False)),
    ):
        checks.require(
            not _forbidden_execution_path(control_path)
            and not _under_mt5_tree(control_path),
            "PRIMARY_CONTROL_ARTIFACT_IN_MT5_TREE",
            control_label,
        )
        checks.require(
            all(
                not _within(control_path, row["run_root"])
                and all(
                    not _within(control_path, output)
                    for output in row["segment_output_roots"]
                )
                for row in runs
            ),
            "PRIMARY_CONTROL_ARTIFACT_INSIDE_RUN_ROOT",
            control_label,
        )
    reserved_paths = {_path_key(spec_path), _path_key(bundle_path)}
    for binding_label, binding_path in checks.binding_paths:
        checks.require(
            _path_key(binding_path) not in reserved_paths,
            "SELF_REFERENTIAL_ARTIFACT_BINDING",
            binding_label,
        )
    if len(runs) == 4:
        for left, right in zip(runs, runs[1:]):
            checks.require(left["finish"] is not None and right["start"] is not None and left["finish"] <= right["start"], "RUNS_NOT_SERIAL", f"{left['label']}->{right['label']}")
        checks.require(seal_created is not None and baselines[1]["finish"] <= seal_created <= qualifications[0]["start"], "SEAL_NOT_BETWEEN_BASELINE_AND_QUALIFICATION")
    consensus = (seal_payload or {}).get("consensus") or {}
    for segment_id in SEGMENTS:
        identities = [row["segments"].get(segment_id, {}).get("identity") for row in runs]
        checks.require(len(identities) == 4 and identities[0] == identities[1] == identities[2] == identities[3] == consensus.get(segment_id), "CROSS_RUN_FULL_IDENTITY_MISMATCH", segment_id)
        input_hashes = [row["segments"].get(segment_id, {}).get("history_input_sha256") for row in runs]
        checks.require(len(set(input_hashes)) == 1 and _valid_sha(input_hashes[0]), "CROSS_RUN_HISTORY_HASH_MISMATCH", segment_id)
    return checks.report(
        spec_path=str(spec_path.resolve()),
        spec_sha256=spec_sha,
        bundle_path=str(bundle_path.resolve()),
        bundle_sha256=sha256_file(bundle_path),
        run_count_validated=len(runs),
        seal_sha256=seal_sha,
        qualified=not checks.errors,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument(
        "--owner-trust-anchor",
        type=Path,
        help="Absolute out-of-band OWNER Ed25519 public-key path (required with --bundle).",
    )
    parser.add_argument(
        "--owner-trust-anchor-sha256",
        help="Expected OWNER public-key SHA-256 supplied independently of spec/bundle.",
    )
    parser.add_argument(
        "--skip-anchor-files",
        action="store_true",
        help="Validate structure without re-hashing static baseline anchors.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.bundle is None:
        result = validate_spec(args.spec, verify_anchors=not args.skip_anchor_files)
        ok = result["status"] == "BLOCKED_OWNER_AND_NEW_EVIDENCE"
    else:
        result = validate_bundle(
            args.spec,
            args.bundle,
            verify_anchors=not args.skip_anchor_files,
            owner_trust_anchor_path=args.owner_trust_anchor,
            owner_trust_anchor_sha256=args.owner_trust_anchor_sha256,
        )
        ok = result["status"] == "PASS"
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
