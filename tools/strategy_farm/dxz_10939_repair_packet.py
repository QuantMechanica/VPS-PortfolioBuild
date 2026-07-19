#!/usr/bin/env python3
"""Read-only validator for the DXZ 10939 GBPUSD H4 repair packet.

The validator does not start MT5 and does not write to any terminal.  It checks
an already-produced evidence bundle against the content-addressed repair spec.
Qualification deliberately requires three run groups: one reference producer
sealed first, followed by two independent serial verification groups.
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
from typing import Any, Iterable, Mapping

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
except ImportError:  # fail closed when qualification trust support is unavailable
    InvalidSignature = ValueError  # type: ignore[assignment]
    Ed25519PublicKey = None  # type: ignore[assignment,misc]

try:
    from tools.strategy_farm import dxz_as_live_requal as hardened_requal
    from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import (
        extract_round_trips,
    )
    from tools.strategy_farm.portfolio.prop_challenge_optimizer import (
        _extract_report_stats,
        _normalize_cell,
        _report_rows,
    )
except ModuleNotFoundError:  # direct ``python path/to/script.py`` invocation
    import dxz_as_live_requal as hardened_requal
    from portfolio.ftmo_report_cost_reconcile import extract_round_trips
    from portfolio.prop_challenge_optimizer import (
        _extract_report_stats,
        _normalize_cell,
        _report_rows,
    )


SPEC_ARTIFACT = "DXZ_10939_GBPUSD_H4_REPAIR_SPEC"
BUNDLE_ARTIFACT = "DXZ_10939_GBPUSD_H4_REQUAL_BUNDLE"
PACKET_ID = "DXZ-10939-GBPUSD-DWX-H4-20260716"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
DECIMAL_RE = re.compile(r"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")
BROKER_TIME_RE = re.compile(r"^[0-9]{4}\.[0-9]{2}\.[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
FORBIDDEN_ROOT_RE = re.compile(r"^(?:t(?:10|[1-9])|t_live)$", re.IGNORECASE)
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$")

IDENTITY_FIELDS = (
    "segment_id",
    "trade_index",
    "symbol",
    "side",
    "entry_time_mt5_server",
    "entry_price",
    "entry_reason",
    "initial_stop",
    "initial_target",
    "exit_time_mt5_server",
    "exit_price",
    "exit_reason",
    "volume",
    "gross_profit_sign",
)

COST_AXES = (
    "commission",
    "historical_tester_spread",
    "current_broker_spread_parity",
    "current_broker_swap_rate_parity",
    "slippage_stress",
)

SEALED_INPUT_ARTIFACT = "DXZ_10939_SEALED_INPUT_MANIFEST"
SOURCE_MANIFEST_ARTIFACT = "DXZ_10939_SOURCE_MANIFEST"
DATA_MANIFEST_ARTIFACT = "DXZ_10939_DWX_DATA_MANIFEST"
INSTRUMENT_MANIFEST_ARTIFACT = "DXZ_10939_INSTRUMENT_MANIFEST"
INSTRUMENT_FILE_ARTIFACT = "DXZ_10939_DWX_INSTRUMENT_FILE"
DATA_SERIES_FILE_MANIFEST_ARTIFACT = "DXZ_10939_DWX_SERIES_FILE_MANIFEST"
SESSION_CALENDAR_ARTIFACT = "DXZ_10939_SESSION_CALENDAR"
SEGMENT_MANIFEST_ARTIFACT = "DXZ_10939_SEGMENT_BOUNDARY_MANIFEST"
SOURCE_CLOSURE_ARTIFACT = "DXZ_10939_SOURCE_CLOSURE_MANIFEST"
OWNER_RECEIPT_ARTIFACT = "DXZ_OWNER_DECISION_RECEIPT"
REFERENCE_SEAL_ARTIFACT = "DXZ_10939_REFERENCE_SEAL"
OWNER_TRUST_ANCHOR_ARTIFACT = "DXZ_10939_OWNER_TRUST_ANCHOR"
EXECUTION_RECEIPT_ARTIFACT = "DXZ_10939_EXECUTION_RECEIPT"
HISTORY_RECEIPT_ARTIFACT = "DXZ_10939_HISTORY_RECEIPT"
RESET_RECEIPT_ARTIFACT = "DXZ_10939_RESET_RECEIPT"
COMMISSION_RESOLUTION_ARTIFACT = "DXZ_10939_COMMISSION_RESOLUTION"
CANONICAL_COST_V3_SHA256 = (
    "98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd"
)
CANONICAL_COST_V3_PATH = (
    "D:/QM/reports/portfolio/dxz_cost_evidence_20260716_v3/report.json"
)

RUN_BINDINGS = (
    "history_receipt",
    "reset_receipt",
    "receipt",
    "native_report",
    "q08_raw",
    "q08_identity_stream",
    "native_identity_stream",
)

ENTRY_REASON_TOKENS = {
    "GCPBL": ("BUY", "GRIMES_CONTEXT_PB_LONG"),
    "GCPBS": ("SELL", "GRIMES_CONTEXT_PB_SHORT"),
}
EXIT_REASON_TOKENS = {
    "TP": "TAKE_PROFIT",
    "SL": "STOP_LOSS",
    "BE": "BREAKEVEN",
    "T18": "TIME_EXIT_18_H4_BARS",
    "A618": "ADVERSE_CLOSE_61_8",
    "F21": "FRIDAY_CLOSE_21_BROKER",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha(value: Any) -> str:
    payload = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _load_object(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read JSON object {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return payload


def _parse_utc(value: Any, label: str) -> dt.datetime | None:
    try:
        text = str(value).strip().replace("Z", "+00:00")
        parsed = dt.datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            return None
        return parsed.astimezone(dt.UTC)
    except (TypeError, ValueError):
        return None


def _parse_broker_time(value: Any) -> dt.datetime | None:
    text = str(value or "")
    if not BROKER_TIME_RE.fullmatch(text):
        return None
    try:
        return dt.datetime.strptime(text, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return None


def _path_key(path: Path) -> str:
    return str(path.resolve()).replace("/", "\\").casefold()


def _is_forbidden_execution_path(path: Path) -> bool:
    return any(FORBIDDEN_ROOT_RE.fullmatch(part) for part in path.resolve().parts)


def _paths_overlap_or_nested(left_key: str, right_key: str) -> bool:
    left = left_key.rstrip("\\")
    right = right_key.rstrip("\\")
    return (
        left == right
        or left.startswith(right + "\\")
        or right.startswith(left + "\\")
    )


class Checks:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.verified_bindings = 0
        self._run_artifact_paths: dict[str, str] = {}
        self._global_output_roots: dict[str, str] = {}
        self._global_mt5_roots: dict[str, str] = {}
        self._global_execution_ids: dict[str, str] = {}
        self._global_sandbox_ids: dict[str, str] = {}
        self._global_run_ids: dict[str, str] = {}
        self._global_isolation_ids: dict[str, str] = {}
        self._control_artifact_paths: dict[str, str] = {}
        self._run_artifact_roots: dict[str, str] = {}

    def require(self, condition: bool, code: str, detail: str = "") -> None:
        if not condition:
            suffix = f": {detail}" if detail else ""
            self.errors.append(f"{code}{suffix}")

    def binding(
        self,
        raw: Any,
        *,
        label: str,
        base_dir: Path,
        unique_run_artifact: bool = False,
        run_root: Path | None = None,
    ) -> tuple[Path | None, str | None]:
        if not isinstance(raw, Mapping):
            self.errors.append(f"BINDING_INVALID: {label}")
            return None, None
        path_text = str(raw.get("path") or "").strip()
        expected = str(raw.get("sha256") or "").strip().lower()
        if not path_text or not SHA_RE.fullmatch(expected):
            self.errors.append(f"BINDING_FIELDS_INVALID: {label}")
            return None, None
        path = Path(path_text)
        if not path.is_absolute():
            path = base_dir / path
        path = path.resolve()
        if not path.is_file():
            self.errors.append(f"BINDING_MISSING: {label} -> {path}")
            return path, expected
        actual = sha256_file(path)
        if actual != expected:
            self.errors.append(
                f"BINDING_HASH_MISMATCH: {label} expected={expected} actual={actual}"
            )
        expected_bytes = raw.get("bytes")
        if expected_bytes is not None:
            try:
                bytes_ok = path.stat().st_size == int(expected_bytes)
            except (TypeError, ValueError):
                bytes_ok = False
            self.require(bytes_ok, "BINDING_SIZE_MISMATCH", label)
        if unique_run_artifact:
            key = _path_key(path)
            for prior_key, prior in self._run_artifact_paths.items():
                if _paths_overlap_or_nested(key, prior_key):
                    self.errors.append(
                        f"RUN_ARTIFACT_PATH_REUSED_OR_NESTED: {label} also={prior}"
                    )
                    break
            else:
                self._run_artifact_paths[key] = label
            if run_root is None:
                self.errors.append(f"RUN_ARTIFACT_OWNER_ROOT_MISSING: {label}")
            else:
                root_key = _path_key(run_root)
                self.require(
                    key.startswith(root_key.rstrip("\\") + "\\"),
                    "RUN_ARTIFACT_OUTSIDE_OWN_OUTPUT_ROOT",
                    label,
                )
                self._run_artifact_roots[key] = root_key
        self.verified_bindings += 1
        return path, expected

    def unique_global(self, category: str, value: str, label: str) -> None:
        registries = {
            "output_root": self._global_output_roots,
            "mt5_root": self._global_mt5_roots,
            "execution_id": self._global_execution_ids,
            "sandbox_id": self._global_sandbox_ids,
            "run_id": self._global_run_ids,
            "isolation_id": self._global_isolation_ids,
        }
        registry = registries[category]
        key = value.casefold()
        if category in {"output_root", "mt5_root"}:
            for prior_key, prior_label in registry.items():
                if _paths_overlap_or_nested(key, prior_key):
                    self.errors.append(
                        f"RUN_{category.upper()}_REUSED_OR_NESTED: {label} also={prior_label}"
                    )
                    return
        prior = registry.get(key)
        if prior is not None:
            self.errors.append(
                f"RUN_{category.upper()}_REUSED_GLOBALLY: {label} also={prior}"
            )
        else:
            registry[key] = label

    def control_artifact(self, path: Path | None, label: str) -> None:
        if path is None:
            return
        resolved = path.resolve()
        if _is_forbidden_execution_path(resolved):
            self.errors.append(f"CONTROL_ARTIFACT_FORBIDDEN_ROOT: {label} -> {resolved}")
        key = _path_key(resolved)
        prior = self._control_artifact_paths.get(key)
        if prior is not None and prior != label:
            self.errors.append(f"CONTROL_ARTIFACT_PATH_REUSED: {label} also={prior}")
        else:
            self._control_artifact_paths[key] = label

    def validate_path_topology(self) -> None:
        for control_key, control_label in self._control_artifact_paths.items():
            for category, roots in (
                ("RUN", self._global_output_roots),
                ("MT5", self._global_mt5_roots),
            ):
                for root_key, root_label in roots.items():
                    if _paths_overlap_or_nested(control_key, root_key):
                        self.errors.append(
                            f"CONTROL_ARTIFACT_INSIDE_OR_CONTAINS_{category}_ROOT: "
                            f"{control_label} also={root_label}"
                        )
            prior_run = self._run_artifact_paths.get(control_key)
            if prior_run is not None:
                self.errors.append(
                    f"CONTROL_ARTIFACT_REUSES_RUN_ARTIFACT: {control_label} also={prior_run}"
                )
        for artifact_key, artifact_label in self._run_artifact_paths.items():
            owner_root = self._run_artifact_roots.get(artifact_key, "")
            for root_key, root_label in self._global_output_roots.items():
                if root_key != owner_root and _paths_overlap_or_nested(artifact_key, root_key):
                    self.errors.append(
                        "RUN_ARTIFACT_INSIDE_OR_CONTAINS_FOREIGN_OUTPUT_ROOT: "
                        f"{artifact_label} also={root_label}"
                    )

    def report(self, **extra: Any) -> dict[str, Any]:
        return {
            "status": "PASS" if not self.errors else "FAIL",
            "error_count": len(self.errors),
            "errors": self.errors,
            "verified_bindings": self.verified_bindings,
            **extra,
        }


def _validate_spec_payload(
    spec: Mapping[str, Any], spec_path: Path, checks: Checks, *, verify_files: bool
) -> None:
    checks.require(spec.get("schema_version") == 1, "SPEC_SCHEMA_INVALID")
    checks.require(spec.get("artifact_type") == SPEC_ARTIFACT, "SPEC_TYPE_INVALID")
    checks.require(spec.get("packet_id") == PACKET_ID, "SPEC_PACKET_ID_INVALID")
    scope = spec.get("scope") or {}
    checks.require(scope.get("ea_id") == 10939, "SPEC_EA_INVALID")
    checks.require(scope.get("symbol") == "GBPUSD.DWX", "SPEC_SYMBOL_INVALID")
    checks.require(scope.get("timeframe") == "H4", "SPEC_TIMEFRAME_INVALID")
    checks.require(scope.get("execution_authorized") is False, "SPEC_EXECUTION_SCOPE_INVALID")
    directive = spec.get("owner_directive") or {}
    checks.require(
        directive.get("status") == "OWNER_DIRECTIVE_RECORDED_UNSEALED"
        and directive.get("directive") == "NO_WEEKEND_HOLDINGS"
        and directive.get("required_friday_contract")
        == {
            "enabled": True,
            "hour_broker": 21,
            "decision": "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER",
        },
        "SPEC_OWNER_FRIDAY_DIRECTIVE_INVALID",
    )
    owner_gates = {
        str(row.get("gate_id")): row
        for row in spec.get("owner_gates") or []
        if isinstance(row, Mapping)
    }
    checks.require(
        set(owner_gates)
        == {
            "CARD_V2_SEMANTICS",
            "FRIDAY_CLOSE_POLICY",
            "NEWS_POLICY",
            "AS_LIVE_RISK_CONTRACT",
            "SOURCE_OF_RECORD",
        },
        "SPEC_OWNER_GATE_SET_INVALID",
    )
    friday_gate = owner_gates.get("FRIDAY_CLOSE_POLICY") or {}
    checks.require(
        friday_gate.get("required_decision")
        == "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER"
        and "allowed_decisions" not in friday_gate,
        "SPEC_FRIDAY_OWNER_GATE_NOT_FIXED",
    )
    checks.require(
        (spec.get("owner_receipt_contract") or {}).get("trust_anchor_artifact_type")
        == OWNER_TRUST_ANCHOR_ARTIFACT,
        "SPEC_OWNER_TRUST_ANCHOR_CONTRACT_INVALID",
    )
    trust = spec.get("owner_trust_contract") or {}
    checks.require(
        trust
        == {
            "status": "PENDING_OUT_OF_BAND_KEY_REGISTRATION",
            "algorithm": "ED25519",
            "public_key_format": "RAW_32_BYTES",
            "signature_encoding": "BASE64",
            "required_external_validator_inputs": [
                "owner_public_key_path",
                "owner_public_key_sha256",
                "owner_trust_anchor_path",
                "owner_trust_anchor_sha256",
            ],
        },
        "SPEC_OWNER_TRUST_CONTRACT_INVALID",
    )

    fields = tuple((spec.get("identity_contract") or {}).get("required_fields") or [])
    checks.require(fields == IDENTITY_FIELDS, "SPEC_IDENTITY_FIELDS_INVALID")
    segments = (spec.get("history_contract") or {}).get("segments") or []
    segment_map = {
        str(row.get("segment_id")): row for row in segments if isinstance(row, Mapping)
    }
    checks.require(
        tuple(segment_map) == ("pre_B", "post_B_pre_C", "post_C_pre_D", "post_D_tail"),
        "SPEC_SEGMENTS_INVALID",
    )
    checks.require(
        segment_map.get("pre_B", {}).get("role") == "INFERENCE"
        and segment_map.get("post_B_pre_C", {}).get("role") == "INFERENCE"
        and segment_map.get("post_C_pre_D", {}).get("role") == "CONTINUITY_ONLY"
        and segment_map.get("post_D_tail", {}).get("role") == "CONTINUITY_ONLY",
        "SPEC_SEGMENT_ROLES_INVALID",
    )
    checks.require(
        tuple((spec.get("execution_cost_contract") or {}).get("required_axes") or [])
        == COST_AXES,
        "SPEC_COST_AXES_INVALID",
    )
    cost_contract = spec.get("execution_cost_contract") or {}
    checks.require(
        cost_contract.get("commission_rate_decimal_round_trip") == 0.00005
        and cost_contract.get("commission_rate_percent_round_trip") == 0.005
        and cost_contract.get("commission_rate_basis_points_round_trip") == 0.5,
        "SPEC_COMMISSION_UNIT_CONTRACT_INVALID",
    )
    canonical_cost = cost_contract.get("canonical_standalone_commission_evidence") or {}
    checks.require(
        canonical_cost.get("schema_version") == 3
        and canonical_cost.get("artifact_type") == "DXZ_STANDALONE_COST_EVIDENCE"
        and canonical_cost.get("path") == CANONICAL_COST_V3_PATH
        and canonical_cost.get("sha256") == CANONICAL_COST_V3_SHA256,
        "SPEC_CANONICAL_COST_V3_INVALID",
    )
    checks.require(
        cost_contract.get("superseded_v2_qualification_use") is False,
        "SPEC_COST_V2_NOT_SUPERSEDED",
    )

    ambiguities = spec.get("commission_ambiguities") or []
    checks.require(len(ambiguities) == 6, "SPEC_COMMISSION_ROWS_INVALID")
    checks.require(
        len({row.get("index") for row in ambiguities if isinstance(row, Mapping)}) == 6,
        "SPEC_COMMISSION_INDEX_DUPLICATE",
    )

    bindings = (spec.get("baseline") or {}).get("hash_bindings") or []
    binding_ids: set[str] = set()
    for index, binding in enumerate(bindings):
        if not isinstance(binding, Mapping):
            checks.errors.append(f"SPEC_BASELINE_BINDING_INVALID: index={index}")
            continue
        binding_id = str(binding.get("id") or "")
        checks.require(bool(binding_id), "SPEC_BASELINE_BINDING_ID_MISSING", str(index))
        checks.require(binding_id not in binding_ids, "SPEC_BASELINE_BINDING_ID_DUPLICATE", binding_id)
        binding_ids.add(binding_id)
        if verify_files:
            checks.binding(
                binding,
                label=f"spec.baseline.{binding_id}",
                base_dir=spec_path.parent,
            )


def validate_spec(spec_path: Path, *, verify_files: bool = True) -> dict[str, Any]:
    checks = Checks()
    try:
        spec = _load_object(spec_path)
    except ValueError as exc:
        checks.errors.append(f"SPEC_READ_ERROR: {exc}")
        return checks.report(spec_path=str(spec_path.resolve()))
    _validate_spec_payload(spec, spec_path, checks, verify_files=verify_files)
    result = checks.report(
        spec_path=str(spec_path.resolve()), spec_sha256=sha256_file(spec_path)
    )
    if result["status"] == "PASS":
        result["status"] = "BLOCKED_OWNER_TRUST_UNREGISTERED"
        result["qualification_eligible"] = False
    return result


def _structured_payload(
    path: Path | None,
    *,
    artifact_type: str,
    hash_field: str,
    label: str,
    checks: Checks,
) -> dict[str, Any] | None:
    if path is None or not path.is_file():
        return None
    try:
        payload = _load_object(path)
    except ValueError as exc:
        checks.errors.append(f"STRUCTURED_ARTIFACT_READ_ERROR: {label}: {exc}")
        return None
    checks.require(payload.get("schema_version") == 1, "STRUCTURED_ARTIFACT_SCHEMA_INVALID", label)
    checks.require(payload.get("artifact_type") == artifact_type, "STRUCTURED_ARTIFACT_TYPE_INVALID", label)
    declared = str(payload.get(hash_field) or "").lower()
    unsigned = dict(payload)
    unsigned.pop(hash_field, None)
    checks.require(
        SHA_RE.fullmatch(declared) is not None and declared == canonical_json_sha(unsigned),
        "STRUCTURED_ARTIFACT_PAYLOAD_HASH_INVALID",
        label,
    )
    return payload


def _verify_ed25519_payload(
    payload: Mapping[str, Any] | None,
    *,
    public_key: bytes | None,
    expected_public_key_sha256: str,
    payload_hash_field: str,
    label: str,
    checks: Checks,
) -> None:
    """Verify a detached-authority payload, not merely its self-declared hash."""

    if payload is None:
        return
    checks.require(
        payload.get("signer_public_key_sha256") == expected_public_key_sha256,
        "SIGNED_PAYLOAD_KEY_HASH_MISMATCH",
        label,
    )
    signature_text = payload.get("signature_base64")
    checks.require(
        isinstance(signature_text, str) and bool(signature_text),
        "SIGNED_PAYLOAD_SIGNATURE_MISSING",
        label,
    )
    if (
        public_key is None
        or Ed25519PublicKey is None
        or not isinstance(signature_text, str)
    ):
        checks.errors.append(f"SIGNED_PAYLOAD_TRUST_UNAVAILABLE: {label}")
        return
    signed = dict(payload)
    signed.pop(payload_hash_field, None)
    signed.pop("signature_base64", None)
    try:
        signature = base64.b64decode(signature_text, validate=True)
        Ed25519PublicKey.from_public_bytes(public_key).verify(
            signature,
            json.dumps(
                signed, sort_keys=True, separators=(",", ":"), ensure_ascii=False
            ).encode("utf-8"),
        )
    except (ValueError, binascii.Error, InvalidSignature):
        checks.errors.append(f"SIGNED_PAYLOAD_SIGNATURE_INVALID: {label}")


def _binding_equal(left: Any, right: Any) -> bool:
    if not isinstance(left, Mapping) or not isinstance(right, Mapping):
        return False
    try:
        left_path = _path_key(Path(str(left.get("path") or "")))
        right_path = _path_key(Path(str(right.get("path") or "")))
    except (OSError, RuntimeError, ValueError):
        return False
    return (
        left_path == right_path
        and str(left.get("sha256") or "").lower()
        == str(right.get("sha256") or "").lower()
    )


def _validate_preset(
    path: Path | None, effective_contract: Mapping[str, Any], checks: Checks
) -> None:
    if path is None or not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"PRESET_READ_ERROR: {exc}")
        return
    assignments: dict[str, list[str]] = {}
    metadata: dict[str, list[str]] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(";"):
            header = stripped[1:].strip()
            if ":" in header:
                key, value = header.split(":", 1)
                metadata.setdefault(key.strip().casefold(), []).append(value.strip())
            continue
        if "=" in stripped:
            key, value = stripped.split("=", 1)
            assignments.setdefault(key.strip().upper(), []).append(value.strip())
    checks.require(
        [value.casefold() for value in metadata.get("environment", [])] == ["live"],
        "PRESET_ENVIRONMENT_NOT_LIVE",
    )
    checks.require(
        [value.upper() for value in metadata.get("symbol", [])] == ["GBPUSD.DWX"],
        "PRESET_SYMBOL_INVALID",
    )
    checks.require(
        [value.upper() for value in metadata.get("timeframe", [])] == ["H4"],
        "PRESET_TIMEFRAME_INVALID",
    )
    risk = effective_contract.get("risk") or {}
    checks.require(
        assignments.get("RISK_FIXED") in (["0"], ["0.0"], ["0.00"]),
        "PRESET_RISK_FIXED_INVALID",
    )
    try:
        percent_values = assignments.get("RISK_PERCENT") or []
        preset_percent = float(percent_values[0]) if len(percent_values) == 1 else math.nan
        expected_percent = float(risk.get("percent"))
        percent_match = math.isfinite(preset_percent) and preset_percent == expected_percent
    except (TypeError, ValueError):
        percent_match = False
    checks.require(percent_match, "PRESET_RISK_PERCENT_MISMATCH")
    try:
        weight_values = assignments.get("PORTFOLIO_WEIGHT") or []
        weight = float(weight_values[0]) if len(weight_values) == 1 else math.nan
    except ValueError:
        weight = math.nan
    checks.require(math.isfinite(weight) and weight == 1.0, "PRESET_PORTFOLIO_WEIGHT_INVALID")
    checks.require(
        assignments.get("QM_FRIDAY_CLOSE_ENABLED") in (["true"], ["1"]),
        "PRESET_FRIDAY_ENABLED_INVALID",
    )
    checks.require(
        assignments.get("QM_FRIDAY_CLOSE_HOUR_BROKER") == ["21"],
        "PRESET_FRIDAY_HOUR_INVALID",
    )
    news = effective_contract.get("news") or {}
    checks.require(
        assignments.get("QM_NEWS_TEMPORAL") == [str(news.get("temporal"))],
        "PRESET_NEWS_TEMPORAL_INVALID",
    )
    checks.require(
        assignments.get("QM_NEWS_COMPLIANCE") == [str(news.get("compliance"))],
        "PRESET_NEWS_COMPLIANCE_INVALID",
    )
    checks.require(
        assignments.get("QM_NEWS_MODE_LEGACY") == ["0"],
        "PRESET_LEGACY_NEWS_MODE_NOT_OFF",
    )
    checks.require(
        not any(key.startswith("QM_FILTER_") for key in assignments),
        "PRESET_INEFFECTIVE_QM_FILTER_OVERRIDE_FORBIDDEN",
    )


def _validate_source_manifest(
    path: Path | None, *, label: str, checks: Checks
) -> dict[str, Any] | None:
    payload = _structured_payload(
        path,
        artifact_type=SOURCE_MANIFEST_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label=label,
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "SOURCE_MANIFEST_PACKET_INVALID")
    checks.require(
        payload.get("sleeves")
        == [{"ea_id": 10939, "symbol": "GBPUSD.DWX", "timeframe": "H4"}],
        "SOURCE_MANIFEST_SLEEVE_INVALID",
    )
    window = payload.get("evaluation_window") or {}
    checks.require(
        set(window) == set(hardened_requal.WINDOW_FIELDS)
        and all(isinstance(window.get(key), str) for key in hardened_requal.WINDOW_FIELDS),
        "SOURCE_MANIFEST_WINDOW_INVALID",
    )
    return payload


def _validate_session_calendar(path: Path | None, checks: Checks) -> dict[str, Any] | None:
    payload = _structured_payload(
        path,
        artifact_type=SESSION_CALENDAR_ARTIFACT,
        hash_field="calendar_payload_sha256",
        label="data_manifest.session_calendar",
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "SESSION_CALENDAR_PACKET_INVALID")
    checks.require(
        payload.get("broker_server") == "DarwinexZero"
        and payload.get("timezone_contract") == "MT5_SERVER_TIME"
        and payload.get("literal_dwx_only") is True,
        "SESSION_CALENDAR_PROVENANCE_INVALID",
    )
    checks.require(
        payload.get("covered_symbols") == ["EURUSD.DWX", "GBPUSD.DWX"],
        "SESSION_CALENDAR_SYMBOLS_INVALID",
    )
    sessions = payload.get("weekly_sessions") or []
    checks.require(
        isinstance(sessions, list)
        and [row.get("weekday") for row in sessions if isinstance(row, Mapping)]
        == [0, 1, 2, 3, 4]
        and all(
            re.fullmatch(r"[0-2][0-9]:[0-5][0-9]", str(row.get("open_mt5") or ""))
            and re.fullmatch(r"[0-2][0-9]:[0-5][0-9]", str(row.get("close_mt5") or ""))
            for row in sessions
            if isinstance(row, Mapping)
        ),
        "SESSION_CALENDAR_WEEKLY_SESSIONS_INVALID",
    )
    transitions = payload.get("dst_transitions") or []
    checks.require(
        isinstance(transitions, list)
        and bool(transitions)
        and all(
            isinstance(row, Mapping)
            and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", str(row.get("date") or ""))
            and str(row.get("utc_offset_before") or "")
            and str(row.get("utc_offset_after") or "")
            for row in transitions
        ),
        "SESSION_CALENDAR_DST_TRANSITIONS_INVALID",
    )
    try:
        coverage_from = dt.date.fromisoformat(str(payload.get("coverage_from_date") or ""))
        coverage_to = dt.date.fromisoformat(str(payload.get("coverage_to_date") or ""))
    except ValueError:
        coverage_from = coverage_to = None
    checks.require(
        coverage_from is not None
        and coverage_to is not None
        and coverage_from <= coverage_to,
        "SESSION_CALENDAR_COVERAGE_INVALID",
    )
    cutoffs = payload.get("weekend_flat_cutoffs") or []
    cutoff_dates: list[str] = []
    for index, row in enumerate(cutoffs):
        if not isinstance(row, Mapping):
            checks.errors.append(f"SESSION_CALENDAR_WEEKEND_CUTOFF_INVALID: {index}")
            continue
        weekend_id = str(row.get("weekend_friday") or "")
        cutoff = _parse_broker_time(row.get("last_tradable_mt5_server"))
        next_open = _parse_broker_time(row.get("next_tradable_mt5_server"))
        try:
            friday = dt.date.fromisoformat(weekend_id)
        except ValueError:
            friday = None
        valid = (
            friday is not None
            and friday.weekday() == 4
            and cutoff is not None
            and next_open is not None
            and dt.datetime.combine(friday - dt.timedelta(days=4), dt.time())
            <= cutoff
            <= dt.datetime.combine(friday, dt.time(hour=21))
            and cutoff < next_open
            <= dt.datetime.combine(friday + dt.timedelta(days=7), dt.time(hour=23, minute=59, second=59))
            and row.get("source") == "DARWINEXZERO_MT5_SESSION_EXPORT"
        )
        checks.require(valid, "SESSION_CALENDAR_WEEKEND_CUTOFF_INVALID", str(index))
        if friday is not None:
            cutoff_dates.append(weekend_id)
    if coverage_from is not None and coverage_to is not None:
        cursor = coverage_from
        while cursor.weekday() != 4:
            cursor += dt.timedelta(days=1)
        expected_fridays: list[str] = []
        while cursor <= coverage_to:
            expected_fridays.append(cursor.isoformat())
            cursor += dt.timedelta(days=7)
        checks.require(
            cutoff_dates == expected_fridays,
            "SESSION_CALENDAR_WEEKEND_CUTOFF_COVERAGE_INVALID",
        )
    return payload


def _validate_instrument_manifest(
    path: Path | None, *, base_dir: Path, checks: Checks
) -> dict[str, Any] | None:
    payload = _structured_payload(
        path,
        artifact_type=INSTRUMENT_MANIFEST_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label="data_manifest.instrument_manifest",
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "INSTRUMENT_MANIFEST_PACKET_INVALID")
    checks.require(
        payload.get("broker_server") == "DarwinexZero"
        and payload.get("literal_dwx_only") is True,
        "INSTRUMENT_MANIFEST_PROVENANCE_INVALID",
    )
    instruments = payload.get("instruments") or []
    expected = {
        ("GBPUSD.DWX", "TRADED"),
        ("EURUSD.DWX", "EUR_ACCOUNT_CONVERSION"),
    }
    observed: set[tuple[str, str]] = set()
    for index, row in enumerate(instruments):
        if not isinstance(row, Mapping):
            checks.errors.append(f"INSTRUMENT_MANIFEST_ROW_INVALID: {index}")
            continue
        symbol = str(row.get("symbol") or "")
        role = str(row.get("role") or "")
        observed.add((symbol, role))
        instrument_path, instrument_sha = checks.binding(
            row.get("instrument_file"),
            label=f"instrument_manifest.instruments.{index}",
            base_dir=base_dir,
        )
        checks.control_artifact(instrument_path, f"instrument_manifest.instruments.{index}")
        instrument = _structured_payload(
            instrument_path,
            artifact_type=INSTRUMENT_FILE_ARTIFACT,
            hash_field="instrument_payload_sha256",
            label=f"instrument_manifest.instruments.{index}",
            checks=checks,
        )
        if instrument is None:
            continue
        checks.require(
            instrument.get("packet_id") == PACKET_ID
            and instrument.get("symbol") == symbol
            and instrument.get("broker_server") == "DarwinexZero"
            and instrument.get("literal_dwx") is True,
            "INSTRUMENT_FILE_IDENTITY_INVALID",
            symbol,
        )
        checks.require(
            isinstance(instrument.get("digits"), int)
            and instrument["digits"] > 0
            and _decimal_ok(instrument.get("point"), positive=True)
            and _decimal_ok(instrument.get("contract_size"), positive=True)
            and isinstance(instrument.get("currency_base"), str)
            and len(instrument["currency_base"]) == 3
            and isinstance(instrument.get("currency_profit"), str)
            and len(instrument["currency_profit"]) == 3,
            "INSTRUMENT_FILE_FIELDS_INVALID",
            symbol,
        )
        checks.require(bool(instrument_sha), "INSTRUMENT_FILE_HASH_MISSING", symbol)
    checks.require(observed == expected and len(instruments) == 2, "INSTRUMENT_MANIFEST_SET_INVALID")
    return payload


def _validate_series_file_manifest(
    path: Path | None,
    *,
    expected_row: Mapping[str, Any],
    expected_file: Mapping[str, Any],
    checks: Checks,
) -> dict[str, Any] | None:
    label = (
        f"data_manifest.series_file.{expected_row.get('symbol')}:"
        f"{expected_row.get('timeframe')}"
    )
    payload = _structured_payload(
        path,
        artifact_type=DATA_SERIES_FILE_MANIFEST_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label=label,
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "SERIES_FILE_MANIFEST_PACKET_INVALID", label)
    checks.require(
        payload.get("symbol") == expected_row.get("symbol")
        and payload.get("timeframe") == expected_row.get("timeframe")
        and payload.get("role") == expected_row.get("role")
        and payload.get("literal_dwx") is True
        and payload.get("source") == "READ_ONLY_DARWINEXZERO_MT5_EXPORT",
        "SERIES_FILE_MANIFEST_IDENTITY_INVALID",
        label,
    )
    checks.require(
        _binding_equal(payload.get("data_file"), expected_file),
        "SERIES_FILE_MANIFEST_BINDING_INVALID",
        label,
    )
    first = _parse_broker_time(payload.get("first_mt5_server"))
    last = _parse_broker_time(payload.get("last_mt5_server"))
    checks.require(
        isinstance(payload.get("record_count"), int)
        and payload["record_count"] > 0
        and first is not None
        and last is not None
        and first <= last,
        "SERIES_FILE_MANIFEST_RANGE_INVALID",
        label,
    )
    return payload


def _validate_data_manifest(
    path: Path | None, *, base_dir: Path, checks: Checks
) -> tuple[dict[str, Any] | None, str, dict[str, Any] | None]:
    payload = _structured_payload(
        path,
        artifact_type=DATA_MANIFEST_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label="bundle.data_manifest",
        checks=checks,
    )
    if payload is None:
        return None, "", None
    checks.require(payload.get("packet_id") == PACKET_ID, "DATA_MANIFEST_PACKET_INVALID")
    checks.require(payload.get("literal_dwx_only") is True, "DATA_MANIFEST_NOT_LITERAL_DWX")
    expected = {
        ("GBPUSD.DWX", "H4", "HOST"),
        ("GBPUSD.DWX", "D1", "CONTEXT"),
        ("EURUSD.DWX", "CONVERSION", "EUR_ACCOUNT_CONVERSION"),
    }
    observed: set[tuple[str, str, str]] = set()
    series = payload.get("series") or []
    for index, row in enumerate(series):
        if not isinstance(row, Mapping):
            checks.errors.append(f"DATA_MANIFEST_SERIES_INVALID: {index}")
            continue
        observed.add(
            (
                str(row.get("symbol") or ""),
                str(row.get("timeframe") or ""),
                str(row.get("role") or ""),
            )
        )
        file_path, _ = checks.binding(
            row.get("file"),
            label=f"data_manifest.series.{index}",
            base_dir=base_dir,
        )
        checks.control_artifact(file_path, f"data_manifest.series.{index}")
        manifest_path, _ = checks.binding(
            row.get("file_manifest"),
            label=f"data_manifest.series.{index}.file_manifest",
            base_dir=base_dir,
        )
        checks.control_artifact(
            manifest_path, f"data_manifest.series.{index}.file_manifest"
        )
        _validate_series_file_manifest(
            manifest_path,
            expected_row=row,
            expected_file=row.get("file") or {},
            checks=checks,
        )
    checks.require(observed == expected, "DATA_MANIFEST_SERIES_SET_INVALID")
    calendar_path, calendar_sha = checks.binding(
        payload.get("session_calendar"),
        label="data_manifest.session_calendar",
        base_dir=base_dir,
    )
    checks.control_artifact(calendar_path, "data_manifest.session_calendar")
    calendar_payload = _validate_session_calendar(calendar_path, checks)
    checks.require(calendar_path is not None and bool(calendar_sha), "DATA_MANIFEST_CALENDAR_INVALID")
    instrument_path, instrument_sha = checks.binding(
        payload.get("instrument_manifest"),
        label="data_manifest.instrument_manifest",
        base_dir=base_dir,
    )
    checks.control_artifact(instrument_path, "data_manifest.instrument_manifest")
    _validate_instrument_manifest(instrument_path, base_dir=base_dir, checks=checks)
    checks.require(bool(instrument_sha), "DATA_MANIFEST_INSTRUMENT_INVALID")
    return payload, calendar_sha or "", calendar_payload


def _validate_segment_manifest(
    path: Path | None,
    *,
    data_manifest_sha256: str,
    calendar_sha256: str,
    checks: Checks,
) -> dict[str, Any] | None:
    payload = _structured_payload(
        path,
        artifact_type=SEGMENT_MANIFEST_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label="bundle.segment_boundary_manifest",
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "SEGMENT_MANIFEST_PACKET_INVALID")
    checks.require(
        payload.get("data_manifest_sha256") == data_manifest_sha256,
        "SEGMENT_MANIFEST_DATA_HASH_INVALID",
    )
    checks.require(
        payload.get("session_calendar_sha256") == calendar_sha256,
        "SEGMENT_MANIFEST_CALENDAR_HASH_INVALID",
    )
    checks.require(
        payload.get("session_aware") is True
        and payload.get("host_d1_conversion_intersection") is True,
        "SEGMENT_MANIFEST_METHOD_INVALID",
    )
    segments = payload.get("segments") or []
    checks.require(
        [row.get("segment_id") for row in segments if isinstance(row, Mapping)]
        == ["pre_B", "post_B_pre_C", "post_C_pre_D", "post_D_tail"],
        "SEGMENT_MANIFEST_SEGMENTS_INVALID",
    )
    return payload


def _validate_source_closure(
    path: Path | None, *, base_dir: Path, checks: Checks
) -> dict[str, Any] | None:
    payload = _structured_payload(
        path,
        artifact_type=SOURCE_CLOSURE_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label="build.source_closure_manifest",
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(payload.get("packet_id") == PACKET_ID, "SOURCE_CLOSURE_PACKET_INVALID")
    entries = payload.get("entries") or []
    checks.require(isinstance(entries, list) and bool(entries), "SOURCE_CLOSURE_EMPTY")
    on_tick_sources: list[tuple[str, str]] = []
    closure_source_texts: list[str] = []
    for index, row in enumerate(entries):
        entry_path, _ = checks.binding(
            row,
            label=f"source_closure.entries.{index}",
            base_dir=base_dir,
        )
        checks.control_artifact(entry_path, f"source_closure.entries.{index}")
        if entry_path is not None and entry_path.suffix.casefold() in {".mq5", ".mqh"}:
            try:
                source_text = entry_path.read_text(encoding="utf-8-sig", errors="strict")
            except (OSError, UnicodeError) as exc:
                checks.errors.append(f"SOURCE_CLOSURE_SOURCE_READ_ERROR: {entry_path}: {exc}")
            else:
                closure_source_texts.append(source_text)
                if re.search(r"\bvoid\s+OnTick\s*\(\s*\)", source_text):
                    on_tick_sources.append((str(entry_path), source_text))
    checks.require(len(on_tick_sources) == 1, "SOURCE_ONTICK_ROOT_COUNT_INVALID")
    if len(on_tick_sources) == 1:
        source_label, source_text = on_tick_sources[0]
        match = re.search(r"\bvoid\s+OnTick\s*\(\s*\)\s*\{", source_text)
        body = ""
        if match is not None:
            depth = 1
            cursor = match.end()
            start = cursor
            while cursor < len(source_text) and depth:
                if source_text[cursor] == "{":
                    depth += 1
                elif source_text[cursor] == "}":
                    depth -= 1
                cursor += 1
            if depth == 0:
                body = source_text[start : cursor - 1]
        scan_body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
        scan_body = re.sub(r"//[^\r\n]*", "", scan_body)
        close_match = re.search(r"\bQM_FrameworkHandleFridayClose\s*\(\s*\)", scan_body)
        close_pos = close_match.start() if close_match is not None else -1
        prefix = scan_body[:close_pos] if close_pos >= 0 else scan_body
        closure_text = "\n".join(closure_source_texts)
        kill_switch_semantics_bound = all(
            token in closure_text
            for token in (
                "bool QM_KillSwitchCheck",
                "g_qm_ks_halted",
                "QM_KillSwitchOwnedExposureExists",
                "QM_KillSwitchCloseOwnedPositions",
                "QM_KillSwitchDeleteOwnedPendings",
                "KILL_SWITCH_FLATTEN_RETRY",
            )
        )
        checks.require(
            kill_switch_semantics_bound,
            "SOURCE_KILL_SWITCH_FLATTEN_RETRY_UNBOUND",
        )
        if kill_switch_semantics_bound:
            prefix = re.sub(
                r"if\s*\(\s*!\s*QM_KillSwitchCheck\s*\(\s*\)\s*\)\s*"
                r"(?:\{\s*)?return\s*;\s*(?:\}\s*)?",
                "",
                prefix,
                flags=re.DOTALL,
            )
        blockers = (
            "Strategy_NewsFilterHook",
            "QM_NewsAllowsTrade2",
            "QM_NewsAllowsTrade",
            "Strategy_NoTradeFilter",
            "Strategy_ManageOpenPosition",
            "Strategy_ExitSignal",
        )
        checks.require(
            close_pos >= 0
            and re.search(r"\breturn\b", prefix) is None
            and all(prefix.find(token) < 0 for token in blockers),
            "SOURCE_FRIDAY_EXIT_PRECEDENCE_INVALID",
            source_label,
        )
    return payload


def _input_contract_payload(
    *,
    card_v2: Mapping[str, Any],
    owner_receipts: Mapping[str, Mapping[str, Any]],
    source_manifest: Mapping[str, Any],
    source_closure: Mapping[str, Any],
    compile_log: Mapping[str, Any],
    ex5: Mapping[str, Any],
    preset: Mapping[str, Any],
    data_manifest: Mapping[str, Any],
    segment_manifest: Mapping[str, Any],
    q08_extractor: Mapping[str, Any],
    native_extractor: Mapping[str, Any],
    cost_manifest: Mapping[str, Any],
    commission_resolution: Mapping[str, Any],
    effective_contract_sha256: str,
    owner_trust_anchor_sha256: str,
    owner_public_key_sha256: str,
) -> dict[str, Any]:
    def digest(binding: Mapping[str, Any]) -> str:
        return str(binding.get("sha256") or "").lower()

    return {
        "packet_id": PACKET_ID,
        "card_v2_sha256": digest(card_v2),
        "owner_receipt_sha256": {
            gate_id: digest(binding) for gate_id, binding in sorted(owner_receipts.items())
        },
        "owner_trust_anchor_sha256": owner_trust_anchor_sha256,
        "owner_public_key_sha256": owner_public_key_sha256,
        "source_manifest_sha256": digest(source_manifest),
        "source_closure_manifest_sha256": digest(source_closure),
        "compile_log_sha256": digest(compile_log),
        "ex5_sha256": digest(ex5),
        "preset_sha256": digest(preset),
        "data_manifest_sha256": digest(data_manifest),
        "segment_boundary_manifest_sha256": digest(segment_manifest),
        "q08_extractor_sha256": digest(q08_extractor),
        "native_extractor_sha256": digest(native_extractor),
        "execution_cost_manifest_sha256": digest(cost_manifest),
        "commission_resolution_sha256": digest(commission_resolution),
        "effective_contract_sha256": effective_contract_sha256,
    }


def _validate_sealed_input_manifest(
    path: Path | None,
    *,
    expected_bindings: Mapping[str, Any],
    owner_receipts: Mapping[str, Mapping[str, Any]],
    effective_contract_sha256: str,
    owner_trust_anchor_sha256: str,
    owner_public_key_sha256: str,
    checks: Checks,
) -> tuple[dict[str, Any] | None, str]:
    payload = _structured_payload(
        path,
        artifact_type=SEALED_INPUT_ARTIFACT,
        hash_field="manifest_payload_sha256",
        label="bundle.sealed_input_manifest",
        checks=checks,
    )
    if payload is None:
        return None, ""
    checks.require(payload.get("packet_id") == PACKET_ID, "SEALED_INPUT_PACKET_INVALID")
    bindings = payload.get("bindings") or {}
    expected_names = {
        "card_v2",
        "source_manifest",
        "source_closure_manifest",
        "compile_log",
        "ex5",
        "preset",
        "data_manifest",
        "segment_boundary_manifest",
        "q08_extractor",
        "native_extractor",
        "execution_cost_manifest",
        "commission_resolution",
    }
    checks.require(set(bindings) == expected_names, "SEALED_INPUT_BINDING_SET_INVALID")
    for name in expected_names:
        checks.require(
            _binding_equal(bindings.get(name), expected_bindings.get(name)),
            "SEALED_INPUT_BINDING_MISMATCH",
            name,
        )
    sealed_receipts = bindings.get("owner_receipts") or payload.get("owner_receipts") or {}
    checks.require(set(sealed_receipts) == set(owner_receipts), "SEALED_INPUT_OWNER_RECEIPT_SET_INVALID")
    for gate_id, binding in owner_receipts.items():
        checks.require(
            _binding_equal(sealed_receipts.get(gate_id), binding),
            "SEALED_INPUT_OWNER_RECEIPT_MISMATCH",
            gate_id,
        )
    contract_payload = _input_contract_payload(
        card_v2=expected_bindings["card_v2"],
        owner_receipts=owner_receipts,
        source_manifest=expected_bindings["source_manifest"],
        source_closure=expected_bindings["source_closure_manifest"],
        compile_log=expected_bindings["compile_log"],
        ex5=expected_bindings["ex5"],
        preset=expected_bindings["preset"],
        data_manifest=expected_bindings["data_manifest"],
        segment_manifest=expected_bindings["segment_boundary_manifest"],
        q08_extractor=expected_bindings["q08_extractor"],
        native_extractor=expected_bindings["native_extractor"],
        cost_manifest=expected_bindings["execution_cost_manifest"],
        commission_resolution=expected_bindings["commission_resolution"],
        effective_contract_sha256=effective_contract_sha256,
        owner_trust_anchor_sha256=owner_trust_anchor_sha256,
        owner_public_key_sha256=owner_public_key_sha256,
    )
    contract_sha = canonical_json_sha(contract_payload)
    checks.require(payload.get("input_contract") == contract_payload, "SEALED_INPUT_CONTRACT_PAYLOAD_INVALID")
    checks.require(payload.get("input_contract_sha256") == contract_sha, "SEALED_INPUT_CONTRACT_HASH_INVALID")
    return payload, contract_sha


def _validate_card_v2(path: Path | None, checks: Checks) -> None:
    if path is None or not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        checks.errors.append(f"CARD_V2_READ_ERROR: {exc}")
        return
    required = {
        "CARD_V2_SCHEMA_MISSING": r"(?m)^card_schema_version:\s*2\s*$",
        "CARD_V2_EA_ID_MISSING": r"(?m)^ea_id:\s*QM5_10939\s*$",
        "CARD_V2_G0_NOT_APPROVED": r"(?m)^g0_status:\s*APPROVED\s*$",
        "CARD_V2_EXECUTION_CONTRACT_NOT_APPROVED": (
            r"(?m)^execution_contract_status:\s*APPROVED\s*$"
        ),
    }
    for code, pattern in required.items():
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


def _decimal_ok(value: Any, *, positive: bool = False) -> bool:
    if not isinstance(value, str) or not DECIMAL_RE.fullmatch(value):
        return False
    try:
        number = float(value)
    except ValueError:
        return False
    return math.isfinite(number) and (number > 0.0 if positive else True)


def _crosses_weekend_cutoff(
    entry: dt.datetime,
    exit_: dt.datetime,
    *,
    calendar: Mapping[str, Any],
) -> bool:
    """Apply min(Friday 21, last tradable pre-weekend session) to a trade."""

    if entry.weekday() >= 5 or exit_.weekday() >= 5:
        return True
    try:
        coverage_from = dt.date.fromisoformat(str(calendar.get("coverage_from_date")))
        coverage_to = dt.date.fromisoformat(str(calendar.get("coverage_to_date")))
    except ValueError:
        return True
    if entry.date() < coverage_from or exit_.date() > coverage_to:
        return True
    for row in calendar.get("weekend_flat_cutoffs") or []:
        if not isinstance(row, Mapping):
            return True
        cutoff = _parse_broker_time(row.get("last_tradable_mt5_server"))
        next_open = _parse_broker_time(row.get("next_tradable_mt5_server"))
        try:
            friday = dt.date.fromisoformat(str(row.get("weekend_friday") or ""))
        except ValueError:
            return True
        if cutoff is None:
            return True
        weekend_end = next_open or dt.datetime.combine(
            friday + dt.timedelta(days=3), dt.time()
        )
        if entry < cutoff < exit_ or cutoff <= entry < weekend_end:
            return True
    return False


def _read_identity_rows(
    path: Path | None,
    *,
    expected_segment: str,
    score_start: dt.datetime | None,
    score_end: dt.datetime | None,
    session_calendar: Mapping[str, Any],
    label: str,
    checks: Checks,
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
            checks.errors.append(
                f"IDENTITY_JSON_INVALID: {label}:{line_number}: {exc.msg}"
            )
            continue
        if not isinstance(row, dict):
            checks.errors.append(f"IDENTITY_ROW_INVALID: {label}:{line_number}")
            continue
        missing = [field for field in IDENTITY_FIELDS if field not in row]
        if missing:
            checks.errors.append(
                f"IDENTITY_FIELDS_MISSING: {label}:{line_number}: {','.join(missing)}"
            )
            continue
        checks.require(
            set(row) == set(IDENTITY_FIELDS),
            "IDENTITY_UNDECLARED_FIELDS",
            f"{label}:{line_number}",
        )
        checks.require(
            row.get("segment_id") == expected_segment,
            "IDENTITY_SEGMENT_MISMATCH",
            f"{label}:{line_number}",
        )
        checks.require(
            row.get("symbol") == "GBPUSD.DWX",
            "IDENTITY_SYMBOL_MISMATCH",
            f"{label}:{line_number}",
        )
        checks.require(
            row.get("side") in {"BUY", "SELL"},
            "IDENTITY_SIDE_INVALID",
            f"{label}:{line_number}",
        )
        checks.require(
            isinstance(row.get("trade_index"), int) and row["trade_index"] > 0,
            "IDENTITY_INDEX_INVALID",
            f"{label}:{line_number}",
        )
        for field in ("entry_price", "initial_stop", "initial_target", "exit_price", "volume"):
            checks.require(
                _decimal_ok(row.get(field), positive=True),
                "IDENTITY_DECIMAL_INVALID",
                f"{label}:{line_number}:{field}",
            )
        checks.require(
            isinstance(row.get("entry_reason"), str) and bool(row["entry_reason"].strip()),
            "IDENTITY_ENTRY_REASON_INVALID",
            f"{label}:{line_number}",
        )
        checks.require(
            isinstance(row.get("exit_reason"), str) and bool(row["exit_reason"].strip()),
            "IDENTITY_EXIT_REASON_INVALID",
            f"{label}:{line_number}",
        )
        checks.require(
            row.get("gross_profit_sign") in {-1, 0, 1},
            "IDENTITY_OUTCOME_SIGN_INVALID",
            f"{label}:{line_number}",
        )
        entry_time = _parse_broker_time(row.get("entry_time_mt5_server"))
        exit_time = _parse_broker_time(row.get("exit_time_mt5_server"))
        checks.require(entry_time is not None, "IDENTITY_ENTRY_TIME_INVALID", f"{label}:{line_number}")
        checks.require(exit_time is not None, "IDENTITY_EXIT_TIME_INVALID", f"{label}:{line_number}")
        if entry_time is not None and exit_time is not None:
            checks.require(entry_time <= exit_time, "IDENTITY_TIME_ORDER_INVALID", f"{label}:{line_number}")
            checks.require(
                not _crosses_weekend_cutoff(
                    entry_time, exit_time, calendar=session_calendar
                ),
                "IDENTITY_WEEKEND_HOLDING_OR_FRIDAY_CUTOFF_BREACH",
                f"{label}:{line_number}",
            )
            if score_start is not None and score_end is not None:
                checks.require(
                    score_start <= entry_time <= exit_time <= score_end,
                    "IDENTITY_OUTSIDE_SCORE_WINDOW",
                    f"{label}:{line_number}",
                )
        rows.append(row)
    checks.require(
        [row.get("trade_index") for row in rows] == list(range(1, len(rows) + 1)),
        "IDENTITY_INDEX_SEQUENCE_INVALID",
        label,
    )
    return rows


def _canonical_decimal_text(raw: Any, *, label: str) -> str:
    text = str(raw or "").strip().replace("\xa0", " ").replace(" ", "")
    if "," in text and "." in text:
        text = text.replace(",", "")
    elif "," in text:
        text = text.replace(",", ".")
    try:
        value = Decimal(text)
    except (InvalidOperation, ValueError) as exc:
        raise ValueError(f"{label} is not a decimal: {raw!r}") from exc
    if not value.is_finite():
        raise ValueError(f"{label} is not finite")
    rendered = format(value, "f")
    if "." in rendered:
        rendered = rendered.rstrip("0").rstrip(".")
    return rendered or "0"


def _entry_identity_comment(raw: Any, *, side: str) -> dict[str, str]:
    text = str(raw or "").strip()
    parts = text.split("|")
    if len(parts) != 4 or parts[0] != "QM10939E":
        raise ValueError("entry comment must be QM10939E|TOKEN|SL|TP")
    identity = ENTRY_REASON_TOKENS.get(parts[1])
    if identity is None or identity[0] != side.upper():
        raise ValueError("entry comment token does not match the deal side")
    return {
        "entry_reason": identity[1],
        "initial_stop": parts[2],
        "initial_target": parts[3],
    }


def _exit_identity_comment(raw: Any) -> str:
    text = str(raw or "").strip()
    parts = text.split("|")
    if len(parts) != 2 or parts[0] != "QM10939X" or parts[1] not in EXIT_REASON_TOKENS:
        raise ValueError("exit comment must use a supported QM10939X|TOKEN")
    return EXIT_REASON_TOKENS[parts[1]]


def _derive_native_report_identity_rows(
    report_path: Path | None,
    *,
    segment_id: str,
    expected_history: Mapping[str, Any],
    label: str,
    checks: Checks,
) -> list[dict[str, Any]]:
    """Derive the full identity stream from MT5 deal rows, never from bundle text.

    The existing round-trip parser independently validates the MT5 table and
    report trade count.  The extra QMID comments carry the fields that native
    MT5 columns do not expose (entry/exit reason and initial SL/TP).
    """

    if report_path is None or not report_path.is_file():
        return []
    try:
        execution = hardened_requal.parse_native_report_execution_evidence(report_path)
        table_rows = _report_rows(report_path)
        stats = _extract_report_stats(table_rows)
    except (OSError, UnicodeError, ValueError) as exc:
        checks.errors.append(f"NATIVE_REPORT_SEMANTIC_PARSE_FAILED: {label}: {exc}")
        return []
    checks.require(
        execution.get("real_ticks_certified") is True,
        "NATIVE_REPORT_REAL_TICKS_NOT_CERTIFIED",
        label,
    )
    checks.require(stats.get("symbol") == "GBPUSD.DWX", "NATIVE_REPORT_SYMBOL_INVALID", label)
    checks.require(
        str(stats.get("expert") or "").startswith("QM5_10939"),
        "NATIVE_REPORT_EXPERT_INVALID",
        label,
    )
    period_match = re.search(
        r"\((\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\)",
        str(stats.get("period") or ""),
    )
    expected_period = None
    try:
        expected_period = (
            _parse_broker_time(expected_history.get("warmup_start")).date(),
            _parse_broker_time(expected_history.get("actual_last_session_bar")).date(),
        )
    except AttributeError:
        pass
    observed_period = None
    if period_match is not None:
        observed_period = (
            dt.datetime.strptime(period_match.group(1), "%Y.%m.%d").date(),
            dt.datetime.strptime(period_match.group(2), "%Y.%m.%d").date(),
        )
    checks.require(
        expected_period is not None and observed_period == expected_period,
        "NATIVE_REPORT_SEGMENT_PERIOD_INVALID",
        label,
    )
    total_trades = stats.get("total_trades")
    checks.require(isinstance(total_trades, int) and total_trades >= 0, "NATIVE_REPORT_TRADE_COUNT_INVALID", label)

    in_deals = False
    headers: list[str] = []
    open_entries: dict[tuple[str, str], list[dict[str, Any]]] = {}
    derived: list[dict[str, Any]] = []
    try:
        for raw_row in table_rows:
            if len(raw_row) == 1 and _normalize_cell(raw_row[0]) == "deals":
                in_deals = True
                headers = []
                continue
            if not in_deals:
                continue
            if raw_row and _normalize_cell(raw_row[0]) == "time":
                headers = list(raw_row)
                continue
            if not headers or len(raw_row) < len(headers):
                continue
            deal = dict(zip(headers, raw_row))
            direction = _normalize_cell(str(deal.get("Direction") or ""))
            if direction not in {"in", "out"}:
                continue
            symbol = str(deal.get("Symbol") or "").strip()
            if symbol != "GBPUSD.DWX":
                raise ValueError(f"non-literal or unexpected deal symbol {symbol!r}")
            deal_type = _normalize_cell(str(deal.get("Type") or ""))
            if deal_type not in {"buy", "sell"}:
                raise ValueError(f"unsupported deal type {deal_type!r}")
            when = _parse_broker_time(deal.get("Time"))
            if when is None:
                raise ValueError(f"invalid MT5 server time {deal.get('Time')!r}")
            volume = _canonical_decimal_text(deal.get("Volume"), label="deal volume")
            price = _canonical_decimal_text(deal.get("Price"), label="deal price")
            if Decimal(volume) <= 0 or Decimal(price) <= 0:
                raise ValueError("deal volume and price must be positive")
            profit = _canonical_decimal_text(deal.get("Profit") or "0", label="deal profit")
            if direction == "in":
                identity = _entry_identity_comment(deal.get("Comment"), side=deal_type)
                initial_stop = _canonical_decimal_text(identity["initial_stop"], label="initial stop")
                initial_target = _canonical_decimal_text(identity["initial_target"], label="initial target")
                if Decimal(initial_stop) <= 0 or Decimal(initial_target) <= 0:
                    raise ValueError("initial stop and target must be positive")
                entry_reason = str(identity["entry_reason"] or "").strip()
                if not entry_reason:
                    raise ValueError("entry reason must be non-empty")
                open_entries.setdefault((symbol, deal_type), []).append(
                    {
                        "time": when,
                        "volume": volume,
                        "price": price,
                        "profit": profit,
                        "entry_reason": entry_reason,
                        "initial_stop": initial_stop,
                        "initial_target": initial_target,
                    }
                )
                continue
            entry_side = "buy" if deal_type == "sell" else "sell"
            queue = open_entries.get((symbol, entry_side)) or []
            if not queue:
                raise ValueError("exit has no matching entry")
            entry = queue.pop(0)
            if entry["volume"] != volume:
                raise ValueError("partial/multi-entry fills are outside the 10939 identity contract")
            exit_reason = _exit_identity_comment(deal.get("Comment"))
            if not exit_reason:
                raise ValueError("exit reason must be non-empty")
            gross = Decimal(entry["profit"]) + Decimal(profit)
            derived.append(
                {
                    "segment_id": segment_id,
                    "trade_index": len(derived) + 1,
                    "symbol": symbol,
                    "side": entry_side.upper(),
                    "entry_time_mt5_server": entry["time"].strftime("%Y.%m.%d %H:%M:%S"),
                    "entry_price": entry["price"],
                    "entry_reason": entry["entry_reason"],
                    "initial_stop": entry["initial_stop"],
                    "initial_target": entry["initial_target"],
                    "exit_time_mt5_server": when.strftime("%Y.%m.%d %H:%M:%S"),
                    "exit_price": price,
                    "exit_reason": exit_reason,
                    "volume": volume,
                    "gross_profit_sign": 1 if gross > 0 else -1 if gross < 0 else 0,
                }
            )
        remaining = sum(len(queue) for queue in open_entries.values())
        if remaining:
            raise ValueError(f"{remaining} entry deal(s) remain open")
    except (InvalidOperation, KeyError, TypeError, ValueError) as exc:
        checks.errors.append(f"NATIVE_REPORT_IDENTITY_DERIVATION_FAILED: {label}: {exc}")
        return []

    checks.require(total_trades == len(derived), "NATIVE_REPORT_DERIVED_TRADE_COUNT_MISMATCH", label)
    if derived:
        try:
            round_trips, parsed_stats = extract_round_trips(report_path, "GBPUSD.DWX")
        except (OSError, UnicodeError, ValueError) as exc:
            checks.errors.append(f"NATIVE_REPORT_ROUND_TRIP_PARSER_FAILED: {label}: {exc}")
            return []
        checks.require(parsed_stats.get("total_trades") == len(derived), "NATIVE_REPORT_PARSER_COUNT_MISMATCH", label)
        checks.require(len(round_trips) == len(derived), "NATIVE_REPORT_ROUND_TRIP_COUNT_MISMATCH", label)
        for index, (parsed, row) in enumerate(zip(round_trips, derived), start=1):
            core_matches = (
                parsed.symbol == row["symbol"]
                and parsed.side.upper() == row["side"]
                and parsed.entry_time.strftime("%Y.%m.%d %H:%M:%S") == row["entry_time_mt5_server"]
                and parsed.exit_time.strftime("%Y.%m.%d %H:%M:%S") == row["exit_time_mt5_server"]
                and math.isclose(parsed.entry_price, float(row["entry_price"]), rel_tol=0.0, abs_tol=1e-10)
                and math.isclose(parsed.exit_price, float(row["exit_price"]), rel_tol=0.0, abs_tol=1e-10)
                and math.isclose(parsed.volume, float(row["volume"]), rel_tol=0.0, abs_tol=1e-10)
                and (1 if parsed.profit > 0 else -1 if parsed.profit < 0 else 0)
                == row["gross_profit_sign"]
            )
            checks.require(core_matches, "NATIVE_REPORT_EXISTING_PARSER_MISMATCH", f"{label}:{index}")
    return derived


def _identity_digests(rows: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    materialized = list(rows)
    entry = [
        [
            row["trade_index"],
            row["symbol"],
            row["side"],
            row["entry_time_mt5_server"],
            row["entry_price"],
            row["entry_reason"],
            row["initial_stop"],
            row["initial_target"],
        ]
        for row in materialized
    ]
    exit_rows = [
        [
            row["trade_index"],
            row["exit_time_mt5_server"],
            row["exit_price"],
            row["exit_reason"],
        ]
        for row in materialized
    ]
    outcome = [[row["trade_index"], row["gross_profit_sign"]] for row in materialized]
    close_sequence = [row["exit_time_mt5_server"] for row in materialized]
    full = [[row[field] for field in IDENTITY_FIELDS] for row in materialized]
    return {
        "trade_count": len(materialized),
        "entry_identity_sha256": canonical_json_sha(entry),
        "exit_identity_sha256": canonical_json_sha(exit_rows),
        "outcome_sign_sha256": canonical_json_sha(outcome),
        "close_sequence_sha256": canonical_json_sha(close_sequence),
        "full_round_trip_identity_sha256": canonical_json_sha(full),
    }


def _segment_contract(segment: Mapping[str, Any]) -> dict[str, Any]:
    history = segment.get("history") or {}
    return {
        "segment_id": segment.get("segment_id"),
        "role": segment.get("role"),
        "warmup_start": history.get("warmup_start"),
        "score_start": history.get("score_start"),
        "score_end": history.get("score_end"),
        "actual_first_session_bar": history.get("actual_first_session_bar"),
        "actual_last_session_bar": history.get("actual_last_session_bar"),
        "gap_boundary_manifest_sha256": history.get("gap_boundary_manifest_sha256"),
    }


def _validate_execution_receipt(
    path: Path | None,
    *,
    run_id: str,
    role: str,
    isolation_id: str,
    segment: Mapping[str, Any],
    history: Mapping[str, Any],
    expected_hashes: Mapping[str, str],
    bound: Mapping[str, tuple[Path | None, str | None]],
    owner_public_key: bytes | None,
    owner_public_key_sha256: str,
    label: str,
    checks: Checks,
) -> dt.datetime | None:
    payload = _structured_payload(
        path,
        artifact_type=EXECUTION_RECEIPT_ARTIFACT,
        hash_field="receipt_payload_sha256",
        label=label,
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "run_id",
            "role",
            "isolation_id",
            "segment_id",
            "execution_id",
            "sandbox_id",
            "output_root",
            "mt5_root",
            "started_utc",
            "finished_utc",
            "history_contract_sha256",
            "input_hashes",
            "artifacts",
            "signer_role",
            "signer_public_key_sha256",
            "signed_at_utc",
            "signature_base64",
            "receipt_payload_sha256",
        },
        "EXECUTION_RECEIPT_FIELDS_INVALID",
        label,
    )
    expected_artifact_names = set(RUN_BINDINGS) - {"receipt"}
    checks.require(payload.get("packet_id") == PACKET_ID, "EXECUTION_RECEIPT_PACKET_INVALID", label)
    checks.require(payload.get("run_id") == run_id, "EXECUTION_RECEIPT_RUN_ID_INVALID", label)
    checks.require(payload.get("role") == role, "EXECUTION_RECEIPT_ROLE_INVALID", label)
    checks.require(payload.get("isolation_id") == isolation_id, "EXECUTION_RECEIPT_ISOLATION_INVALID", label)
    for field in ("segment_id", "execution_id", "sandbox_id"):
        checks.require(
            payload.get(field) == segment.get(field),
            "EXECUTION_RECEIPT_SEGMENT_IDENTITY_INVALID",
            f"{label}.{field}",
        )
    for field in ("output_root", "mt5_root", "started_utc", "finished_utc"):
        left = payload.get(field)
        right = segment.get(field)
        if field in {"output_root", "mt5_root"}:
            try:
                equal = _path_key(Path(str(left or ""))) == _path_key(Path(str(right or "")))
            except (OSError, RuntimeError, ValueError):
                equal = False
        else:
            equal = left == right
        checks.require(equal, "EXECUTION_RECEIPT_SEGMENT_CONTRACT_INVALID", f"{label}.{field}")
    checks.require(
        payload.get("history_contract_sha256") == canonical_json_sha(dict(history)),
        "EXECUTION_RECEIPT_HISTORY_CONTRACT_INVALID",
        label,
    )
    checks.require(
        payload.get("input_hashes") == dict(expected_hashes),
        "EXECUTION_RECEIPT_INPUT_HASHES_INVALID",
        label,
    )
    artifacts = payload.get("artifacts") or {}
    checks.require(set(artifacts) == expected_artifact_names, "EXECUTION_RECEIPT_ARTIFACT_SET_INVALID", label)
    for name in expected_artifact_names:
        expected_path, expected_sha = bound.get(name, (None, None))
        checks.require(
            _binding_equal(
                artifacts.get(name),
                {
                    "path": str(expected_path) if expected_path is not None else "",
                    "sha256": expected_sha or "",
                },
            ),
            "EXECUTION_RECEIPT_ARTIFACT_MISMATCH",
            f"{label}.{name}",
        )
    signed_at = _parse_utc(payload.get("signed_at_utc"), label)
    segment_finished = _parse_utc(segment.get("finished_utc"), label)
    checks.require(
        payload.get("signer_role") == "OWNER_QUALIFICATION_AUTHORITY"
        and signed_at is not None
        and segment_finished is not None
        and segment_finished <= signed_at,
        "EXECUTION_RECEIPT_SIGNER_INVALID",
        label,
    )
    _verify_ed25519_payload(
        payload,
        public_key=owner_public_key,
        expected_public_key_sha256=owner_public_key_sha256,
        payload_hash_field="receipt_payload_sha256",
        label=label,
        checks=checks,
    )
    return signed_at


def _validate_run_group(
    group: Any,
    *,
    expected_role: str,
    label: str,
    spec: Mapping[str, Any],
    bundle_dir: Path,
    checks: Checks,
    expected_hashes: Mapping[str, str],
    segment_boundaries: Mapping[str, Mapping[str, Any]],
    session_calendar: Mapping[str, Any],
    owner_public_key: bytes | None,
    owner_public_key_sha256: str,
) -> dict[str, Any] | None:
    if not isinstance(group, Mapping):
        checks.errors.append(f"RUN_GROUP_INVALID: {label}")
        return None
    checks.require(group.get("role") == expected_role, "RUN_GROUP_ROLE_INVALID", label)
    run_id = str(group.get("run_id") or "")
    isolation_id = str(group.get("isolation_id") or "")
    checks.require(SAFE_ID_RE.fullmatch(run_id) is not None, "RUN_GROUP_ID_INVALID", label)
    checks.require(SAFE_ID_RE.fullmatch(isolation_id) is not None, "RUN_GROUP_ISOLATION_ID_INVALID", label)
    if run_id:
        checks.unique_global("run_id", run_id, label)
    if isolation_id:
        checks.unique_global("isolation_id", isolation_id, label)
    start = _parse_utc(group.get("started_utc"), f"{label}.started_utc")
    finish = _parse_utc(group.get("finished_utc"), f"{label}.finished_utc")
    checks.require(start is not None and finish is not None and start < finish, "RUN_GROUP_TIME_INVALID", label)
    for field, expected in expected_hashes.items():
        checks.require(group.get(field) == expected, "RUN_GROUP_INPUT_HASH_MISMATCH", f"{label}.{field}")
    checks.require(group.get("collision_free") is True, "RUN_GROUP_NOT_COLLISION_FREE", label)
    checks.require(group.get("source_inputs_unchanged") is True, "RUN_GROUP_INPUTS_CHANGED", label)
    if expected_role == "REFERENCE_PRODUCER":
        checks.require(group.get("frozen_before_verification") is True, "REFERENCE_NOT_FROZEN", label)
        seal_path, _ = checks.binding(
            group.get("seal"),
            label=f"{label}.seal",
            base_dir=bundle_dir,
        )
        checks.control_artifact(seal_path, "reference.structured_seal")

    spec_segments = (spec.get("history_contract") or {}).get("segments") or []
    raw_segments = group.get("segments") or []
    checks.require(len(raw_segments) == len(spec_segments), "RUN_GROUP_SEGMENT_COUNT_INVALID", label)
    results: dict[str, Any] = {}
    execution_windows: list[tuple[dt.datetime, dt.datetime, str]] = []
    output_roots: set[str] = set()
    for ordinal, expected_segment in enumerate(spec_segments):
        if ordinal >= len(raw_segments) or not isinstance(raw_segments[ordinal], Mapping):
            checks.errors.append(f"RUN_SEGMENT_INVALID: {label}:{ordinal}")
            continue
        segment = raw_segments[ordinal]
        segment_id = str(expected_segment.get("segment_id"))
        seg_label = f"{label}.{segment_id}"
        checks.require(segment.get("segment_id") == segment_id, "RUN_SEGMENT_ORDER_INVALID", seg_label)
        checks.require(segment.get("role") == expected_segment.get("role"), "RUN_SEGMENT_ROLE_INVALID", seg_label)
        execution_id = str(segment.get("execution_id") or "")
        checks.require(SAFE_ID_RE.fullmatch(execution_id) is not None, "RUN_SEGMENT_EXECUTION_ID_INVALID", seg_label)
        if execution_id:
            checks.unique_global("execution_id", execution_id, seg_label)
        sandbox = str(segment.get("sandbox_id") or "")
        checks.require(
            bool(re.fullmatch(r"DXZ_Truth_[A-Za-z0-9_-]+", sandbox, re.IGNORECASE)),
            "RUN_SEGMENT_SANDBOX_INVALID",
            seg_label,
        )
        if sandbox:
            checks.unique_global("sandbox_id", sandbox, seg_label)
        output_text = str(segment.get("output_root") or "")
        output_path = Path(output_text)
        if not output_path.is_absolute():
            output_path = bundle_dir / output_path
        output_path = output_path.resolve()
        checks.require(not _is_forbidden_execution_path(output_path), "RUN_OUTPUT_FORBIDDEN_ROOT", seg_label)
        checks.require(output_path.is_dir(), "RUN_OUTPUT_ROOT_MISSING", seg_label)
        output_key = _path_key(output_path)
        checks.require(output_key not in output_roots, "RUN_OUTPUT_ROOT_REUSED_WITHIN_GROUP", seg_label)
        output_roots.add(output_key)
        checks.unique_global("output_root", output_key, seg_label)
        mt5_text = str(segment.get("mt5_root") or "")
        mt5_path = Path(mt5_text)
        if not mt5_path.is_absolute():
            mt5_path = bundle_dir / mt5_path
        mt5_path = mt5_path.resolve()
        mt5_key = _path_key(mt5_path)
        checks.require(not _is_forbidden_execution_path(mt5_path), "RUN_MT5_FORBIDDEN_ROOT", seg_label)
        checks.require(mt5_path.is_dir(), "RUN_MT5_ROOT_MISSING", seg_label)
        checks.require(
            mt5_key.startswith(output_key.rstrip("\\") + "\\"),
            "RUN_MT5_ROOT_OUTSIDE_OUTPUT_ROOT",
            seg_label,
        )
        checks.unique_global("mt5_root", mt5_key, seg_label)

        seg_start = _parse_utc(segment.get("started_utc"), f"{seg_label}.started_utc")
        seg_finish = _parse_utc(segment.get("finished_utc"), f"{seg_label}.finished_utc")
        checks.require(
            seg_start is not None
            and seg_finish is not None
            and seg_start < seg_finish
            and (start is None or start <= seg_start)
            and (finish is None or seg_finish <= finish),
            "RUN_SEGMENT_TIME_INVALID",
            seg_label,
        )
        if seg_start is not None and seg_finish is not None:
            execution_windows.append((seg_start, seg_finish, seg_label))

        for field, expected in expected_hashes.items():
            checks.require(segment.get(field) == expected, "RUN_SEGMENT_INPUT_HASH_MISMATCH", f"{seg_label}.{field}")

        history = segment.get("history") or {}
        boundary = segment_boundaries.get(segment_id) or {}
        for boundary_field in (
            "warmup_start",
            "score_start",
            "score_end",
            "actual_first_session_bar",
            "actual_last_session_bar",
        ):
            checks.require(
                history.get(boundary_field) == boundary.get(boundary_field),
                "HISTORY_BOUNDARY_CONTRACT_MISMATCH",
                f"{seg_label}.{boundary_field}",
            )
        is_inference = expected_segment.get("role") == "INFERENCE"
        min_warmup = (spec.get("history_contract") or {}).get("minimum_warmup") or {}
        h4_bars = history.get("warmup_h4_bars")
        d1_bars = history.get("warmup_d1_bars")
        checks.require(history.get("session_aware_continuity_pass") is True, "HISTORY_CONTINUITY_FAIL", seg_label)
        checks.require(history.get("host_d1_conversion_intersection_pass") is True, "HISTORY_INTERSECTION_FAIL", seg_label)
        checks.require(history.get("segment_process_restarted") is True, "HISTORY_PROCESS_NOT_RESTARTED", seg_label)
        checks.require(history.get("history_staged_without_pre_gap") is True, "HISTORY_PRE_GAP_STATE_VISIBLE", seg_label)
        checks.require(history.get("indicator_state_reset") is True, "HISTORY_INDICATOR_NOT_RESET", seg_label)
        checks.require(history.get("rolling_state_reset") is True, "HISTORY_ROLLING_STATE_NOT_RESET", seg_label)
        checks.require(history.get("entries_during_warmup") == 0, "HISTORY_WARMUP_ENTRY", seg_label)
        checks.require(history.get("position_at_segment_start") == 0, "HISTORY_POSITION_AT_START", seg_label)
        checks.require(history.get("position_at_segment_end") == 0, "HISTORY_POSITION_AT_END", seg_label)
        checks.require(history.get("pending_orders_at_segment_start") == 0, "HISTORY_PENDING_AT_START", seg_label)
        checks.require(history.get("pending_orders_at_segment_end") == 0, "HISTORY_PENDING_AT_END", seg_label)
        checks.require(history.get("tester_forced_exit_count") == 0, "HISTORY_TESTER_FORCED_EXIT", seg_label)
        checks.require(history.get("economics_used") is is_inference, "HISTORY_ECONOMICS_ROLE_INVALID", seg_label)
        checks.require(history.get("score_enabled") is is_inference, "HISTORY_SCORE_ROLE_INVALID", seg_label)
        checks.require(
            history.get("gap_boundary_manifest_sha256")
            == expected_hashes.get("segment_boundary_manifest_sha256"),
            "HISTORY_SEGMENT_MANIFEST_HASH_MISMATCH",
            seg_label,
        )
        if is_inference:
            checks.require(
                isinstance(h4_bars, int) and h4_bars >= int(min_warmup.get("h4_bars", 60)),
                "HISTORY_H4_WARMUP_SHORT",
                seg_label,
            )
            checks.require(
                isinstance(d1_bars, int) and d1_bars >= int(min_warmup.get("d1_bars", 50)),
                "HISTORY_D1_WARMUP_SHORT",
                seg_label,
            )
            checks.require(history.get("warmup_complete") is True, "HISTORY_WARMUP_INCOMPLETE", seg_label)
            checks.require(
                history.get("score_started_after_warmup") is True,
                "HISTORY_SCORE_BEFORE_WARMUP",
                seg_label,
            )
        else:
            checks.require(history.get("warmup_complete") is False, "CONTINUITY_SEGMENT_MARKED_WARM", seg_label)

        score_start = _parse_broker_time(history.get("score_start"))
        score_end = _parse_broker_time(history.get("score_end"))
        if is_inference:
            checks.require(
                score_start is not None and score_end is not None and score_start < score_end,
                "HISTORY_SCORE_WINDOW_INVALID",
                seg_label,
            )

        bound: dict[str, tuple[Path | None, str | None]] = {}
        for binding_name in RUN_BINDINGS:
            bound[binding_name] = checks.binding(
                segment.get(binding_name),
                label=f"{seg_label}.{binding_name}",
                base_dir=bundle_dir,
                unique_run_artifact=True,
                run_root=output_path,
            )
        receipt_signed_at = _validate_execution_receipt(
            bound["receipt"][0],
            run_id=run_id,
            role=expected_role,
            isolation_id=isolation_id,
            segment=segment,
            history=history,
            expected_hashes=expected_hashes,
            bound=bound,
            owner_public_key=owner_public_key,
            owner_public_key_sha256=owner_public_key_sha256,
            label=f"{seg_label}.receipt",
            checks=checks,
        )
        checks.require(
            receipt_signed_at is not None
            and finish is not None
            and receipt_signed_at <= finish,
            "EXECUTION_RECEIPT_SIGNED_AFTER_RUN_GROUP_FINISH",
            seg_label,
        )
        native_report_path = bound["native_report"][0]
        checks.require(
            native_report_path is not None
            and _path_key(native_report_path).startswith(mt5_key.rstrip("\\") + "\\"),
            "NATIVE_REPORT_OUTSIDE_OWN_MT5_ROOT",
            seg_label,
        )
        q08_meta = segment.get("q08_identity_stream") or {}
        native_meta = segment.get("native_identity_stream") or {}
        checks.require(q08_meta.get("producer") == "Q08_EMITTER_PARSER", "Q08_PRODUCER_INVALID", seg_label)
        checks.require(
            q08_meta.get("source_sha256") == bound["q08_raw"][1],
            "Q08_SOURCE_BINDING_INVALID",
            seg_label,
        )
        checks.require(
            q08_meta.get("extractor_sha256") == expected_hashes.get("q08_extractor_sha256"),
            "Q08_EXTRACTOR_BINDING_INVALID",
            seg_label,
        )
        checks.require(
            native_meta.get("producer") == "VALIDATOR_BUILTIN_MT5_REPORT_DERIVATION_V1",
            "NATIVE_PRODUCER_INVALID",
            seg_label,
        )
        checks.require(
            native_meta.get("source_sha256") == bound["native_report"][1],
            "NATIVE_SOURCE_BINDING_INVALID",
            seg_label,
        )
        checks.require(
            native_meta.get("extractor_sha256")
            == expected_hashes.get("native_extractor_sha256"),
            "NATIVE_EXTRACTOR_BINDING_INVALID",
            seg_label,
        )
        checks.require(
            native_meta.get("derived_stream_sha256")
            == bound["native_identity_stream"][1],
            "NATIVE_DERIVED_STREAM_HASH_INVALID",
            seg_label,
        )
        checks.require(
            _path_key(bound["q08_identity_stream"][0]) != _path_key(bound["native_identity_stream"][0])
            if bound["q08_identity_stream"][0] and bound["native_identity_stream"][0]
            else False,
            "IDENTITY_SOURCE_PATHS_NOT_INDEPENDENT",
            seg_label,
        )

        q08_rows = _read_identity_rows(
            bound["q08_identity_stream"][0],
            expected_segment=segment_id,
            score_start=score_start,
            score_end=score_end,
            session_calendar=session_calendar,
            label=f"{seg_label}.q08",
            checks=checks,
        )
        native_rows = _read_identity_rows(
            bound["native_identity_stream"][0],
            expected_segment=segment_id,
            score_start=score_start,
            score_end=score_end,
            session_calendar=session_calendar,
            label=f"{seg_label}.native",
            checks=checks,
        )
        derived_native_rows = _derive_native_report_identity_rows(
            bound["native_report"][0],
            segment_id=segment_id,
            expected_history=history,
            label=seg_label,
            checks=checks,
        )
        checks.require(
            native_rows == derived_native_rows,
            "NATIVE_IDENTITY_NOT_DERIVED_FROM_REPORT",
            seg_label,
        )
        checks.require(
            native_meta.get("derived_identity_sha256")
            == canonical_json_sha(derived_native_rows),
            "NATIVE_DERIVED_IDENTITY_HASH_INVALID",
            seg_label,
        )
        q08_digest = _identity_digests(q08_rows)
        native_digest = _identity_digests(native_rows)
        checks.require(q08_digest == native_digest, "Q08_NATIVE_FULL_IDENTITY_MISMATCH", seg_label)
        if is_inference:
            checks.require(q08_digest["trade_count"] > 0, "INFERENCE_SEGMENT_IDENTITY_EMPTY", seg_label)
        else:
            checks.require(q08_digest["trade_count"] == 0, "CONTINUITY_SEGMENT_HAS_SCORED_TRADES", seg_label)
        results[segment_id] = {
            "identity": q08_digest,
            "contract": _segment_contract(segment),
            "output_root": output_key,
            "bindings": {
                name: {
                    "path": str(bound[name][0]) if bound[name][0] else "",
                    "sha256": bound[name][1] or "",
                }
                for name in RUN_BINDINGS
            },
        }

    execution_windows.sort()
    for left, right in zip(execution_windows, execution_windows[1:]):
        checks.require(left[1] <= right[0], "RUN_SEGMENTS_OVERLAP", f"{left[2]} -> {right[2]}")
    return {
        "run_id": run_id,
        "isolation_id": isolation_id,
        "start": start,
        "finish": finish,
        "segments": results,
        "seal_binding": group.get("seal"),
    }


def _validate_reference_seal(
    reference: Mapping[str, Any],
    *,
    bundle_dir: Path,
    input_contract_sha256: str,
    owner_public_key: bytes | None,
    owner_public_key_sha256: str,
    checks: Checks,
) -> dt.datetime | None:
    seal_path, _ = checks.binding(
        reference.get("seal_binding"),
        label="reference.structured_seal",
        base_dir=bundle_dir,
    )
    checks.control_artifact(seal_path, "reference.structured_seal")
    payload = _structured_payload(
        seal_path,
        artifact_type=REFERENCE_SEAL_ARTIFACT,
        hash_field="seal_payload_sha256",
        label="reference.structured_seal",
        checks=checks,
    )
    if payload is None:
        return None
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "run_id",
            "role",
            "reference_finished_utc",
            "sealed_at_utc",
            "input_contract_sha256",
            "segments",
            "signer_role",
            "signer_public_key_sha256",
            "signature_base64",
            "seal_payload_sha256",
        },
        "REFERENCE_SEAL_FIELDS_INVALID",
    )
    checks.require(payload.get("packet_id") == PACKET_ID, "REFERENCE_SEAL_PACKET_INVALID")
    checks.require(payload.get("run_id") == reference.get("run_id"), "REFERENCE_SEAL_RUN_ID_INVALID")
    checks.require(payload.get("role") == "REFERENCE_PRODUCER", "REFERENCE_SEAL_ROLE_INVALID")
    checks.require(
        payload.get("input_contract_sha256") == input_contract_sha256,
        "REFERENCE_SEAL_INPUT_CONTRACT_INVALID",
    )
    checks.require(
        payload.get("signer_role") == "OWNER_QUALIFICATION_AUTHORITY",
        "REFERENCE_SEAL_SIGNER_INVALID",
    )
    _verify_ed25519_payload(
        payload,
        public_key=owner_public_key,
        expected_public_key_sha256=owner_public_key_sha256,
        payload_hash_field="seal_payload_sha256",
        label="reference.structured_seal",
        checks=checks,
    )
    finish = reference.get("finish")
    declared_finish = _parse_utc(payload.get("reference_finished_utc"), "reference seal finish")
    checks.require(
        finish is not None and declared_finish == finish,
        "REFERENCE_SEAL_FINISH_MISMATCH",
    )
    sealed_at = _parse_utc(payload.get("sealed_at_utc"), "reference seal timestamp")
    checks.require(
        sealed_at is not None and finish is not None and finish <= sealed_at,
        "REFERENCE_SEAL_TIMESTAMP_INVALID",
    )
    sealed_segments = payload.get("segments") or []
    expected_ids = ["pre_B", "post_B_pre_C", "post_C_pre_D", "post_D_tail"]
    checks.require(
        [row.get("segment_id") for row in sealed_segments if isinstance(row, Mapping)]
        == expected_ids,
        "REFERENCE_SEAL_SEGMENT_SET_INVALID",
    )
    seal_key = _path_key(seal_path) if seal_path is not None else ""
    for row in sealed_segments:
        if not isinstance(row, Mapping):
            continue
        segment_id = str(row.get("segment_id") or "")
        expected = (reference.get("segments") or {}).get(segment_id)
        if not isinstance(expected, Mapping):
            checks.errors.append(f"REFERENCE_SEAL_UNKNOWN_SEGMENT: {segment_id}")
            continue
        checks.require(
            str(row.get("output_root") or "").replace("/", "\\").casefold()
            == str(expected.get("output_root") or "").replace("/", "\\").casefold(),
            "REFERENCE_SEAL_OUTPUT_ROOT_MISMATCH",
            segment_id,
        )
        artifacts = row.get("artifacts") or {}
        checks.require(set(artifacts) == set(RUN_BINDINGS), "REFERENCE_SEAL_ARTIFACT_SET_INVALID", segment_id)
        for name in RUN_BINDINGS:
            expected_binding = (expected.get("bindings") or {}).get(name)
            checks.require(
                _binding_equal(artifacts.get(name), expected_binding),
                "REFERENCE_SEAL_ARTIFACT_MISMATCH",
                f"{segment_id}.{name}",
            )
            if isinstance(artifacts.get(name), Mapping):
                artifact_path = Path(str(artifacts[name].get("path") or ""))
                checks.require(
                    not seal_key or _path_key(artifact_path) != seal_key,
                    "REFERENCE_SEAL_SELF_REFERENCE",
                    f"{segment_id}.{name}",
                )
        checks.require(
            row.get("identity") == expected.get("identity"),
            "REFERENCE_SEAL_IDENTITY_MISMATCH",
            segment_id,
        )
    return sealed_at


def _validate_owner_public_key(
    path: Path | None,
    expected_sha256: str | None,
    *,
    bundle_dir: Path,
    checks: Checks,
) -> tuple[bytes | None, str]:
    if path is None:
        checks.errors.append("OWNER_PUBLIC_KEY_OUT_OF_BAND_PATH_REQUIRED")
        return None, ""
    resolved = path.resolve()
    checks.control_artifact(resolved, "owner.public_key")
    checks.require(
        not _path_key(resolved).startswith(_path_key(bundle_dir).rstrip("\\") + "\\"),
        "OWNER_PUBLIC_KEY_INSIDE_BUNDLE_ROOT",
    )
    if not resolved.is_file():
        checks.errors.append(f"OWNER_PUBLIC_KEY_MISSING: {resolved}")
        return None, ""
    raw = resolved.read_bytes()
    actual_sha = sha256_file(resolved)
    expected = str(expected_sha256 or "").lower()
    checks.require(
        SHA_RE.fullmatch(expected) is not None and actual_sha == expected,
        "OWNER_PUBLIC_KEY_OUT_OF_BAND_HASH_MISMATCH",
    )
    checks.require(len(raw) == 32, "OWNER_PUBLIC_KEY_LENGTH_INVALID")
    if len(raw) != 32 or actual_sha != expected:
        return None, actual_sha
    return raw, actual_sha


def _validate_owner_trust_anchor(
    path: Path | None,
    expected_sha256: str | None,
    *,
    spec_sha256: str,
    bundle_dir: Path,
    owner_public_key: bytes | None,
    owner_public_key_sha256: str,
    checks: Checks,
) -> tuple[dict[str, Any], str]:
    if path is None:
        checks.errors.append("OWNER_TRUST_ANCHOR_OUT_OF_BAND_PATH_REQUIRED")
        return {}, ""
    resolved = path.resolve()
    checks.control_artifact(resolved, "owner.trust_anchor")
    checks.require(
        not _path_key(resolved).startswith(_path_key(bundle_dir).rstrip("\\") + "\\"),
        "OWNER_TRUST_ANCHOR_INSIDE_BUNDLE_ROOT",
    )
    if not resolved.is_file():
        checks.errors.append(f"OWNER_TRUST_ANCHOR_MISSING: {resolved}")
        return {}, ""
    actual_sha = sha256_file(resolved)
    expected = str(expected_sha256 or "").lower()
    checks.require(
        SHA_RE.fullmatch(expected) is not None and actual_sha == expected,
        "OWNER_TRUST_ANCHOR_OUT_OF_BAND_HASH_MISMATCH",
    )
    payload = _structured_payload(
        resolved,
        artifact_type=OWNER_TRUST_ANCHOR_ARTIFACT,
        hash_field="anchor_payload_sha256",
        label="owner.trust_anchor",
        checks=checks,
    )
    if payload is None:
        return {}, actual_sha
    checks.require(
        set(payload)
        == {
            "schema_version",
            "artifact_type",
            "packet_id",
            "spec_sha256",
            "owner_authority_id",
            "signer_public_key_sha256",
            "issued_at_utc",
            "receipts",
            "input_bindings",
            "signature_base64",
            "anchor_payload_sha256",
        },
        "OWNER_TRUST_ANCHOR_FIELDS_INVALID",
    )
    checks.require(payload.get("packet_id") == PACKET_ID, "OWNER_TRUST_ANCHOR_PACKET_INVALID")
    checks.require(payload.get("spec_sha256") == spec_sha256, "OWNER_TRUST_ANCHOR_SPEC_INVALID")
    checks.require(
        payload.get("owner_authority_id") == "OWNER"
        and _parse_utc(payload.get("issued_at_utc"), "owner trust anchor") is not None,
        "OWNER_TRUST_ANCHOR_AUTHORITY_INVALID",
    )
    receipts = payload.get("receipts")
    checks.require(isinstance(receipts, Mapping) and bool(receipts), "OWNER_TRUST_ANCHOR_RECEIPTS_INVALID")
    checks.require(
        isinstance(payload.get("input_bindings"), Mapping)
        and bool(payload.get("input_bindings")),
        "OWNER_TRUST_ANCHOR_INPUT_BINDINGS_INVALID",
    )
    _verify_ed25519_payload(
        payload,
        public_key=owner_public_key,
        expected_public_key_sha256=owner_public_key_sha256,
        payload_hash_field="anchor_payload_sha256",
        label="owner.trust_anchor",
        checks=checks,
    )
    return payload, actual_sha


def _validate_owner_gates(
    spec: Mapping[str, Any],
    bundle: Mapping[str, Any],
    bundle_dir: Path,
    checks: Checks,
    *,
    spec_sha256: str,
    trust_anchor: Mapping[str, Any],
) -> tuple[dict[str, str], dict[str, Mapping[str, Any]]]:
    raw = bundle.get("owner_gates") or []
    gates = {
        str(row.get("gate_id")): row for row in raw if isinstance(row, Mapping)
    }
    decisions: dict[str, str] = {}
    receipt_bindings: dict[str, Mapping[str, Any]] = {}
    anchored_receipts = trust_anchor.get("receipts") or {}
    anchor_issued_at = _parse_utc(trust_anchor.get("issued_at_utc"), "owner trust anchor")
    for expected in spec.get("owner_gates") or []:
        gate_id = str(expected.get("gate_id"))
        gate = gates.get(gate_id)
        if not isinstance(gate, Mapping):
            checks.errors.append(f"OWNER_GATE_MISSING: {gate_id}")
            continue
        checks.require(gate.get("status") == "APPROVED", "OWNER_GATE_NOT_APPROVED", gate_id)
        decision = str(gate.get("decision") or "")
        required = expected.get("required_decision")
        allowed = expected.get("allowed_decisions")
        if required is not None:
            checks.require(decision == required, "OWNER_GATE_DECISION_INVALID", gate_id)
        elif isinstance(allowed, list):
            checks.require(decision in allowed, "OWNER_GATE_DECISION_INVALID", gate_id)
        decisions[gate_id] = decision
        receipt_binding = gate.get("receipt")
        receipt_path, receipt_sha = checks.binding(
            receipt_binding,
            label=f"owner_gate.{gate_id}.receipt",
            base_dir=bundle_dir,
        )
        checks.control_artifact(receipt_path, f"owner_gate.{gate_id}.receipt")
        receipt = _structured_payload(
            receipt_path,
            artifact_type=OWNER_RECEIPT_ARTIFACT,
            hash_field="receipt_payload_sha256",
            label=f"owner_gate.{gate_id}.receipt",
            checks=checks,
        )
        if receipt is not None:
            checks.require(receipt.get("packet_id") == PACKET_ID, "OWNER_RECEIPT_PACKET_INVALID", gate_id)
            checks.require(receipt.get("gate_id") == gate_id, "OWNER_RECEIPT_GATE_INVALID", gate_id)
            checks.require(receipt.get("decision") == decision, "OWNER_RECEIPT_DECISION_INVALID", gate_id)
            checks.require(receipt.get("spec_sha256") == spec_sha256, "OWNER_RECEIPT_SPEC_HASH_INVALID", gate_id)
            checks.require(receipt.get("approved_by") == "OWNER", "OWNER_RECEIPT_APPROVER_INVALID", gate_id)
            approved_at = _parse_utc(receipt.get("approved_at_utc"), f"owner_gate.{gate_id}")
            checks.require(
                approved_at is not None
                and anchor_issued_at is not None
                and approved_at <= anchor_issued_at,
                "OWNER_RECEIPT_TIMESTAMP_INVALID",
                gate_id,
            )
        anchor_row = anchored_receipts.get(gate_id)
        checks.require(
            isinstance(anchor_row, Mapping)
            and set(anchor_row) == {"decision", "receipt_sha256"}
            and anchor_row.get("decision") == decision
            and anchor_row.get("receipt_sha256") == receipt_sha,
            "OWNER_RECEIPT_NOT_PINNED_BY_OUT_OF_BAND_ANCHOR",
            gate_id,
        )
        if isinstance(receipt_binding, Mapping):
            receipt_bindings[gate_id] = receipt_binding
    checks.require(len(gates) == len(spec.get("owner_gates") or []), "OWNER_GATE_SET_INVALID")
    checks.require(
        set(anchored_receipts) == {str(row.get("gate_id")) for row in spec.get("owner_gates") or []},
        "OWNER_TRUST_ANCHOR_GATE_SET_INVALID",
    )
    return decisions, receipt_bindings


def _validate_owner_anchor_input_bindings(
    trust_anchor: Mapping[str, Any],
    *,
    expected_bindings: Mapping[str, str],
    checks: Checks,
) -> None:
    """Require the authenticated OWNER anchor to pin every static input."""

    actual = trust_anchor.get("input_bindings") or {}
    checks.require(
        isinstance(actual, Mapping) and dict(actual) == dict(expected_bindings),
        "OWNER_TRUST_ANCHOR_INPUT_BINDING_MISMATCH",
    )


def _validate_effective_contract(
    bundle: Mapping[str, Any], decisions: Mapping[str, str], checks: Checks
) -> tuple[dict[str, Any], str]:
    contract = bundle.get("effective_contract")
    if not isinstance(contract, dict):
        checks.errors.append("EFFECTIVE_CONTRACT_INVALID")
        return {}, ""
    declared = str(bundle.get("effective_contract_sha256") or "").lower()
    actual = canonical_json_sha(contract)
    checks.require(SHA_RE.fullmatch(declared) is not None and declared == actual, "EFFECTIVE_CONTRACT_HASH_INVALID")
    friday = contract.get("friday") or {}
    friday_decision = decisions.get("FRIDAY_CLOSE_POLICY")
    if friday_decision == "FRAMEWORK_OVERRIDE_FRIDAY_21_BROKER":
        checks.require(
            friday.get("enabled") is True and friday.get("hour_broker") == 21,
            "EFFECTIVE_FRIDAY_OWNER_MISMATCH",
        )
    elif friday_decision == "NO_FRAMEWORK_FRIDAY_CLOSE":
        checks.require(friday.get("enabled") is False, "EFFECTIVE_FRIDAY_OWNER_MISMATCH")
    news = contract.get("news") or {}
    news_decision = decisions.get("NEWS_POLICY")
    if news_decision == "DXZ_PRE30_POST30":
        checks.require(
            news.get("temporal") == 3 and news.get("compliance") == 1,
            "EFFECTIVE_NEWS_OWNER_MISMATCH",
        )
    elif news_decision == "NO_NEWS_FILTER":
        checks.require(
            news.get("temporal") == 0 and news.get("compliance") == 0,
            "EFFECTIVE_NEWS_OWNER_MISMATCH",
        )
    risk = contract.get("risk") or {}
    checks.require(risk.get("mode") == "PERCENT", "EFFECTIVE_RISK_MODE_INVALID")
    checks.require(
        isinstance(risk.get("percent"), (int, float))
        and math.isfinite(float(risk["percent"]))
        and 0.0 < float(risk["percent"]) <= 1.0,
        "EFFECTIVE_RISK_PERCENT_INVALID",
    )
    fixed = risk.get("fixed")
    checks.require(
        isinstance(fixed, (int, float))
        and not isinstance(fixed, bool)
        and math.isfinite(float(fixed))
        and float(fixed) == 0.0,
        "EFFECTIVE_RISK_FIXED_NONZERO",
    )
    checks.require(risk.get("deposit") == 100000, "EFFECTIVE_DEPOSIT_INVALID")
    checks.require(risk.get("account_currency") == "EUR", "EFFECTIVE_CURRENCY_INVALID")
    portfolio_weight = risk.get("portfolio_weight")
    checks.require(
        isinstance(portfolio_weight, (int, float))
        and not isinstance(portfolio_weight, bool)
        and math.isfinite(float(portfolio_weight))
        and float(portfolio_weight) == 1.0,
        "EFFECTIVE_PORTFOLIO_WEIGHT_INVALID",
    )
    return contract, declared


def _validate_costs(
    spec: Mapping[str, Any],
    bundle: Mapping[str, Any],
    bundle_dir: Path,
    checks: Checks,
    *,
    source_manifest_sha256: str,
    as_of_utc: dt.datetime | None,
    evaluation_window: Mapping[str, Any],
) -> tuple[str, str]:
    costs = bundle.get("execution_costs")
    if not isinstance(costs, Mapping):
        checks.errors.append("EXECUTION_COSTS_INVALID")
        return "", ""
    checks.require(
        set(costs) == {"status", "manifest", "commission_resolution"},
        "EXECUTION_COSTS_SELF_ATTESTED_FIELDS_FORBIDDEN",
    )
    checks.require(costs.get("status") == "PASS", "EXECUTION_COSTS_NOT_PASS")
    manifest_path, manifest_sha = checks.binding(
        costs.get("manifest"), label="execution_costs.manifest", base_dir=bundle_dir
    )
    checks.control_artifact(manifest_path, "execution_costs.manifest")
    if manifest_path is not None and as_of_utc is not None and source_manifest_sha256:
        try:
            metadata, contracts = hardened_requal.load_execution_cost_evidence_manifest(
                manifest_path,
                source_manifest_sha256=source_manifest_sha256,
                as_of_utc=as_of_utc,
                required_sleeves=[
                    {"ea_id": 10939, "symbol": "GBPUSD.DWX", "timeframe": "H4"}
                ],
                window_contract=dict(evaluation_window),
            )
        except (hardened_requal.RequalError, OSError, ValueError) as exc:
            checks.errors.append(f"EXECUTION_COST_MANIFEST_REVALIDATION_FAILED: {exc}")
        else:
            contract = contracts.get("10939:GBPUSD.DWX")
            checks.require(contract is not None, "EXECUTION_COST_10939_CONTRACT_MISSING")
            if contract is not None:
                checks.require(contract.get("timeframe") == "H4", "EXECUTION_COST_TIMEFRAME_INVALID")
                checks.require(
                    set(contract.get("axes") or {}) == set(COST_AXES)
                    and all(
                        (contract.get("axes") or {}).get(axis, {}).get("status") == "PASS"
                        for axis in COST_AXES
                    ),
                    "EXECUTION_COST_AXIS_SEMANTICS_INVALID",
                )
            checks.require(
                metadata.get("sha256") == manifest_sha,
                "EXECUTION_COST_MANIFEST_METADATA_HASH_MISMATCH",
            )
            checks.control_artifact(
                Path(str(metadata.get("sidecar_path") or "")),
                "execution_costs.manifest.sidecar",
            )
            for index, artifact in enumerate(metadata.get("bound_artifacts") or []):
                if not isinstance(artifact, Mapping):
                    continue
                checks.control_artifact(
                    Path(str(artifact.get("path") or "")),
                    f"execution_costs.axis.{index}",
                )
                checks.control_artifact(
                    Path(str(artifact.get("sidecar_path") or "")),
                    f"execution_costs.axis.{index}.sidecar",
                )
    else:
        checks.errors.append("EXECUTION_COST_REVALIDATION_CONTEXT_INVALID")
    commission_path, commission_sha = checks.binding(
        costs.get("commission_resolution"),
        label="execution_costs.commission_resolution",
        base_dir=bundle_dir,
    )
    checks.control_artifact(
        commission_path, "execution_costs.commission_resolution"
    )
    commission = _structured_payload(
        commission_path,
        artifact_type=COMMISSION_RESOLUTION_ARTIFACT,
        hash_field="resolution_payload_sha256",
        label="execution_costs.commission_resolution",
        checks=checks,
    ) or {}
    checks.require(
        commission.get("packet_id") == PACKET_ID,
        "COMMISSION_RESOLUTION_PACKET_INVALID",
    )
    checks.require(commission.get("status") == "COMPLETE", "COMMISSION_RESOLUTION_INCOMPLETE")
    checks.require(commission.get("ambiguous_trade_count") == 0, "COMMISSION_AMBIGUITY_REMAINS")
    checks.require(commission.get("unbounded_trade_count") == 0, "COMMISSION_UNBOUNDED_REMAINS")
    expected_rows = {
        int(row["index"]): row for row in spec.get("commission_ambiguities") or []
    }
    actual_rows = commission.get("resolved_rows") or []
    checks.require(len(actual_rows) == len(expected_rows), "COMMISSION_RESOLUTION_ROW_COUNT_INVALID")
    seen: set[int] = set()
    allowed_methods = set(
        (spec.get("commission_resolution_contract") or {}).get("allowed_methods") or []
    )
    fingerprint_fields = (
        "entry_time_mt5_server",
        "exit_time_mt5_server",
        "side",
        "entry_price",
        "exit_price",
        "volume",
    )
    for row in actual_rows:
        if not isinstance(row, Mapping) or not isinstance(row.get("index"), int):
            checks.errors.append("COMMISSION_RESOLUTION_ROW_INVALID")
            continue
        index = int(row["index"])
        expected = expected_rows.get(index)
        checks.require(expected is not None and index not in seen, "COMMISSION_RESOLUTION_INDEX_INVALID", str(index))
        seen.add(index)
        if expected is not None:
            checks.require(
                all(str(row.get(field)) == str(expected.get(field)) for field in fingerprint_fields),
                "COMMISSION_FINGERPRINT_MISMATCH",
                str(index),
            )
        checks.require(row.get("method") in allowed_methods, "COMMISSION_METHOD_INVALID", str(index))
        checks.require(row.get("account_currency") == "EUR", "COMMISSION_CURRENCY_INVALID", str(index))
        checks.require(
            isinstance(row.get("commission_account_currency"), (int, float))
            and math.isfinite(float(row["commission_account_currency"]))
            and float(row["commission_account_currency"]) > 0.0,
            "COMMISSION_AMOUNT_INVALID",
            str(index),
        )
        evidence_path, _ = checks.binding(
            row.get("evidence"),
            label=f"commission_resolution.{index}.evidence",
            base_dir=bundle_dir,
        )
        checks.control_artifact(
            evidence_path, f"commission_resolution.{index}.evidence"
        )
    checks.require(seen == set(expected_rows), "COMMISSION_RESOLUTION_COVERAGE_INVALID")
    return manifest_sha or "", commission_sha or ""


def validate_bundle(
    spec_path: Path,
    bundle_path: Path,
    *,
    verify_baseline: bool = True,
    owner_trust_anchor_path: Path | None = None,
    owner_trust_anchor_sha256: str | None = None,
    owner_public_key_path: Path | None = None,
    owner_public_key_sha256: str | None = None,
) -> dict[str, Any]:
    checks = Checks()
    checks.control_artifact(spec_path.resolve(), "qualification.spec")
    checks.control_artifact(bundle_path.resolve(), "qualification.bundle")
    try:
        spec = _load_object(spec_path)
    except ValueError as exc:
        checks.errors.append(f"SPEC_READ_ERROR: {exc}")
        return checks.report()
    _validate_spec_payload(spec, spec_path, checks, verify_files=verify_baseline)
    try:
        bundle = _load_object(bundle_path)
    except ValueError as exc:
        checks.errors.append(f"BUNDLE_READ_ERROR: {exc}")
        return checks.report(spec_sha256=sha256_file(spec_path))
    bundle_dir = bundle_path.parent
    spec_sha = sha256_file(spec_path)
    owner_public_key, owner_key_sha = _validate_owner_public_key(
        owner_public_key_path,
        owner_public_key_sha256,
        bundle_dir=bundle_dir,
        checks=checks,
    )
    trust_anchor, trust_anchor_sha = _validate_owner_trust_anchor(
        owner_trust_anchor_path,
        owner_trust_anchor_sha256,
        spec_sha256=spec_sha,
        bundle_dir=bundle_dir,
        owner_public_key=owner_public_key,
        owner_public_key_sha256=owner_key_sha,
        checks=checks,
    )
    checks.require(bundle.get("schema_version") == 1, "BUNDLE_SCHEMA_INVALID")
    checks.require(bundle.get("artifact_type") == BUNDLE_ARTIFACT, "BUNDLE_TYPE_INVALID")
    checks.require(bundle.get("packet_id") == PACKET_ID, "BUNDLE_PACKET_ID_INVALID")
    checks.require(bundle.get("spec_sha256") == spec_sha, "BUNDLE_SPEC_HASH_MISMATCH")
    checks.require(bundle.get("status") == "READY_FOR_QUALIFICATION_VALIDATION", "BUNDLE_STATUS_INVALID")
    checks.require(bundle.get("deployment_eligible") is False, "BUNDLE_DEPLOYMENT_SCOPE_INVALID")

    card_binding = bundle.get("card_v2")
    card_path, _ = checks.binding(card_binding, label="bundle.card_v2", base_dir=bundle_dir)
    checks.control_artifact(card_path, "bundle.card_v2")
    _validate_card_v2(card_path, checks)
    decisions, owner_receipts = _validate_owner_gates(
        spec,
        bundle,
        bundle_dir,
        checks,
        spec_sha256=spec_sha,
        trust_anchor=trust_anchor,
    )
    effective_contract, effective_contract_sha = _validate_effective_contract(
        bundle, decisions, checks
    )
    as_of_utc = _parse_utc(bundle.get("validation_as_of_utc"), "validation_as_of_utc")
    checks.require(as_of_utc is not None, "BUNDLE_VALIDATION_AS_OF_INVALID")

    source_binding = bundle.get("source_manifest")
    source_path, source_manifest_sha = checks.binding(
        source_binding, label="bundle.source_manifest", base_dir=bundle_dir
    )
    checks.control_artifact(source_path, "bundle.source_manifest")
    source_manifest = _validate_source_manifest(
        source_path, label="bundle.source_manifest", checks=checks
    )
    evaluation_window = (
        source_manifest.get("evaluation_window")
        if isinstance(source_manifest, Mapping)
        else {}
    )

    data_binding = bundle.get("data_manifest")
    data_path, data_manifest_sha = checks.binding(
        data_binding, label="bundle.data_manifest", base_dir=bundle_dir
    )
    checks.control_artifact(data_path, "bundle.data_manifest")
    _, calendar_sha, session_calendar = _validate_data_manifest(
        data_path, base_dir=bundle_dir, checks=checks
    )
    segment_binding = bundle.get("segment_boundary_manifest")
    segment_path, segment_manifest_sha = checks.binding(
        segment_binding,
        label="bundle.segment_boundary_manifest",
        base_dir=bundle_dir,
    )
    checks.control_artifact(segment_path, "bundle.segment_boundary_manifest")
    segment_manifest_payload = _validate_segment_manifest(
        segment_path,
        data_manifest_sha256=data_manifest_sha or "",
        calendar_sha256=calendar_sha,
        checks=checks,
    )
    segment_boundaries = {
        str(row.get("segment_id")): row
        for row in (segment_manifest_payload or {}).get("segments", [])
        if isinstance(row, Mapping)
    }

    preset_binding = bundle.get("approved_preset")
    preset_path, preset_sha = checks.binding(
        preset_binding, label="bundle.approved_preset", base_dir=bundle_dir
    )
    checks.control_artifact(preset_path, "bundle.approved_preset")
    _validate_preset(preset_path, effective_contract, checks)
    build = bundle.get("build") or {}
    checks.require(build.get("clean_compile") is True, "BUILD_NOT_CLEAN")
    checks.require(build.get("compile_pass") is True, "BUILD_COMPILE_NOT_PASS")
    checks.require(
        build.get("recursive_include_closure_bound") is True,
        "BUILD_INCLUDE_CLOSURE_UNBOUND",
    )
    source_closure_binding = build.get("source_closure_manifest")
    source_closure_path, source_closure_sha = checks.binding(
        source_closure_binding,
        label="build.source_closure_manifest",
        base_dir=bundle_dir,
    )
    checks.control_artifact(source_closure_path, "build.source_closure_manifest")
    _validate_source_closure(
        source_closure_path, base_dir=bundle_dir, checks=checks
    )
    compile_log_binding = build.get("compile_log")
    compile_log_path, _ = checks.binding(
        compile_log_binding, label="build.compile_log", base_dir=bundle_dir
    )
    checks.control_artifact(compile_log_path, "build.compile_log")
    ex5_binding = build.get("ex5")
    ex5_path, ex5_sha = checks.binding(
        ex5_binding, label="build.ex5", base_dir=bundle_dir
    )
    checks.control_artifact(ex5_path, "build.ex5")
    checks.require(
        str(build.get("source_of_record_sha256") or "") == str(source_closure_sha or ""),
        "BUILD_SOURCE_OF_RECORD_HASH_INVALID",
    )
    q08_extractor_binding = bundle.get("q08_extractor")
    q08_extractor_path, q08_extractor_sha = checks.binding(
        q08_extractor_binding, label="bundle.q08_extractor", base_dir=bundle_dir
    )
    checks.control_artifact(q08_extractor_path, "bundle.q08_extractor")
    native_extractor_binding = bundle.get("native_extractor")
    native_extractor_path, native_extractor_sha = checks.binding(
        native_extractor_binding, label="bundle.native_extractor", base_dir=bundle_dir
    )
    checks.control_artifact(native_extractor_path, "bundle.native_extractor")
    checks.require(
        bool(q08_extractor_sha)
        and bool(native_extractor_sha)
        and q08_extractor_sha != native_extractor_sha
        and q08_extractor_path != native_extractor_path,
        "IDENTITY_EXTRACTORS_NOT_INDEPENDENT",
    )
    cost_manifest_binding = (bundle.get("execution_costs") or {}).get("manifest")
    cost_manifest_sha, commission_resolution_sha = _validate_costs(
        spec,
        bundle,
        bundle_dir,
        checks,
        source_manifest_sha256=source_manifest_sha or "",
        as_of_utc=as_of_utc,
        evaluation_window=evaluation_window,
    )

    sealed_binding = bundle.get("sealed_input_manifest")
    sealed_path, sealed_sha = checks.binding(
        sealed_binding,
        label="bundle.sealed_input_manifest",
        base_dir=bundle_dir,
    )
    checks.control_artifact(sealed_path, "bundle.sealed_input_manifest")
    sealed_expected = {
        "card_v2": card_binding,
        "source_manifest": source_binding,
        "source_closure_manifest": source_closure_binding,
        "compile_log": compile_log_binding,
        "ex5": ex5_binding,
        "preset": preset_binding,
        "data_manifest": data_binding,
        "segment_boundary_manifest": segment_binding,
        "q08_extractor": q08_extractor_binding,
        "native_extractor": native_extractor_binding,
        "execution_cost_manifest": cost_manifest_binding,
        "commission_resolution": (bundle.get("execution_costs") or {}).get(
            "commission_resolution"
        ),
    }
    _, input_contract_sha = _validate_sealed_input_manifest(
        sealed_path,
        expected_bindings=sealed_expected,
        owner_receipts=owner_receipts,
        effective_contract_sha256=effective_contract_sha,
        owner_trust_anchor_sha256=trust_anchor_sha,
        owner_public_key_sha256=owner_key_sha,
        checks=checks,
    )

    expected_hashes = {
        "sealed_input_manifest_sha256": sealed_sha or "",
        "input_contract_sha256": input_contract_sha,
        "source_manifest_sha256": source_manifest_sha or "",
        "binary_sha256": ex5_sha or "",
        "preset_sha256": preset_sha or "",
        "effective_contract_sha256": effective_contract_sha,
        "execution_cost_manifest_sha256": cost_manifest_sha,
        "commission_resolution_sha256": commission_resolution_sha,
        "data_manifest_sha256": data_manifest_sha or "",
        "segment_boundary_manifest_sha256": segment_manifest_sha or "",
        "q08_extractor_sha256": q08_extractor_sha or "",
        "native_extractor_sha256": native_extractor_sha or "",
        "owner_trust_anchor_sha256": trust_anchor_sha,
        "owner_public_key_sha256": owner_key_sha,
    }
    _validate_owner_anchor_input_bindings(
        trust_anchor,
        expected_bindings={
            "card_v2_sha256": str((card_binding or {}).get("sha256") or ""),
            "source_manifest_sha256": source_manifest_sha or "",
            "source_closure_manifest_sha256": source_closure_sha or "",
            "compile_log_sha256": str((compile_log_binding or {}).get("sha256") or ""),
            "ex5_sha256": ex5_sha or "",
            "preset_sha256": preset_sha or "",
            "data_manifest_sha256": data_manifest_sha or "",
            "segment_boundary_manifest_sha256": segment_manifest_sha or "",
            "q08_extractor_sha256": q08_extractor_sha or "",
            "native_extractor_sha256": native_extractor_sha or "",
            "execution_cost_manifest_sha256": cost_manifest_sha,
            "commission_resolution_sha256": commission_resolution_sha,
            "effective_contract_sha256": effective_contract_sha,
        },
        checks=checks,
    )
    checks.require(all(expected_hashes.values()), "BUNDLE_REQUIRED_HASH_EMPTY")
    reference = _validate_run_group(
        bundle.get("reference_run"),
        expected_role="REFERENCE_PRODUCER",
        label="reference",
        spec=spec,
        bundle_dir=bundle_dir,
        checks=checks,
        expected_hashes=expected_hashes,
        segment_boundaries=segment_boundaries,
        session_calendar=session_calendar or {},
        owner_public_key=owner_public_key,
        owner_public_key_sha256=owner_key_sha,
    )
    verification_raw = bundle.get("verification_runs") or []
    checks.require(len(verification_raw) == 2, "VERIFICATION_RUN_COUNT_INVALID")
    verification: list[dict[str, Any]] = []
    for index, raw in enumerate(verification_raw[:2], start=1):
        result = _validate_run_group(
            raw,
            expected_role="VERIFICATION",
            label=f"verification_{index}",
            spec=spec,
            bundle_dir=bundle_dir,
            checks=checks,
            expected_hashes=expected_hashes,
            segment_boundaries=segment_boundaries,
            session_calendar=session_calendar or {},
            owner_public_key=owner_public_key,
            owner_public_key_sha256=owner_key_sha,
        )
        if result is not None:
            verification.append(result)

    groups = ([reference] if reference is not None else []) + verification
    run_ids = [row["run_id"] for row in groups]
    isolation_ids = [row["isolation_id"] for row in groups]
    checks.require(len(run_ids) == 3 and len(set(run_ids)) == 3, "RUN_GROUP_IDS_NOT_INDEPENDENT")
    checks.require(
        len(isolation_ids) == 3 and len(set(isolation_ids)) == 3,
        "RUN_GROUP_ISOLATIONS_NOT_INDEPENDENT",
    )
    anchor_issued_at = _parse_utc(trust_anchor.get("issued_at_utc"), "owner trust anchor")
    if reference is not None:
        checks.require(
            anchor_issued_at is not None
            and reference.get("start") is not None
            and anchor_issued_at <= reference["start"],
            "OWNER_ANCHOR_NOT_ISSUED_BEFORE_REFERENCE",
        )
    checks.require(
        as_of_utc is not None
        and len(groups) == 3
        and all(row.get("finish") is not None and row["finish"] <= as_of_utc for row in groups),
        "BUNDLE_VALIDATION_AS_OF_PRECEDES_RUNS",
    )
    reference_sealed_at = (
        _validate_reference_seal(
            reference,
            bundle_dir=bundle_dir,
            input_contract_sha256=input_contract_sha,
            owner_public_key=owner_public_key,
            owner_public_key_sha256=owner_key_sha,
            checks=checks,
        )
        if reference is not None
        else None
    )
    if reference is not None and len(verification) == 2:
        checks.require(
            reference["finish"] is not None
            and verification[0]["start"] is not None
            and reference["finish"] <= verification[0]["start"],
            "REFERENCE_NOT_SEALED_BEFORE_VERIFICATION",
        )
        checks.require(
            reference_sealed_at is not None
            and verification[0]["start"] is not None
            and reference_sealed_at <= verification[0]["start"],
            "REFERENCE_SEAL_NOT_BEFORE_VERIFICATION",
        )
        checks.require(
            verification[0]["finish"] is not None
            and verification[1]["start"] is not None
            and verification[0]["finish"] <= verification[1]["start"],
            "VERIFICATION_RUNS_NOT_SERIAL",
        )
        for segment_id in ("pre_B", "post_B_pre_C", "post_C_pre_D", "post_D_tail"):
            segment_rows = [row["segments"].get(segment_id) for row in groups]
            if any(row is None for row in segment_rows):
                checks.errors.append(f"CROSS_RUN_SEGMENT_MISSING: {segment_id}")
                continue
            identities = [row["identity"] for row in segment_rows]
            contracts = [row["contract"] for row in segment_rows]
            checks.require(
                identities[0] == identities[1] == identities[2],
                "CROSS_RUN_FULL_IDENTITY_MISMATCH",
                segment_id,
            )
            checks.require(
                contracts[0] == contracts[1] == contracts[2],
                "CROSS_RUN_SEGMENT_CONTRACT_MISMATCH",
                segment_id,
            )
    checks.validate_path_topology()
    return checks.report(
        spec_path=str(spec_path.resolve()),
        spec_sha256=spec_sha,
        bundle_path=str(bundle_path.resolve()),
        bundle_sha256=sha256_file(bundle_path),
        run_groups_validated=len(groups),
        execution_performed=False,
        owner_trust_anchor_sha256=trust_anchor_sha,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument(
        "--owner-trust-anchor",
        type=Path,
        help="Out-of-band OWNER trust-anchor file (required with --bundle).",
    )
    parser.add_argument(
        "--owner-trust-anchor-sha256",
        help="Expected trust-anchor file SHA-256 supplied out of band (required with --bundle).",
    )
    parser.add_argument(
        "--owner-public-key",
        type=Path,
        help="Raw 32-byte Ed25519 OWNER public key supplied out of band (required with --bundle).",
    )
    parser.add_argument(
        "--owner-public-key-sha256",
        help="Expected OWNER public-key SHA-256 supplied out of band (required with --bundle).",
    )
    parser.add_argument(
        "--skip-baseline-files",
        action="store_true",
        help="Validate structure without re-hashing the baseline files (test/transport only).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.bundle is None:
        result = validate_spec(args.spec, verify_files=not args.skip_baseline_files)
    else:
        result = validate_bundle(
            args.spec,
            args.bundle,
            verify_baseline=not args.skip_baseline_files,
            owner_trust_anchor_path=args.owner_trust_anchor,
            owner_trust_anchor_sha256=args.owner_trust_anchor_sha256,
            owner_public_key_path=args.owner_public_key,
            owner_public_key_sha256=args.owner_public_key_sha256,
        )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
