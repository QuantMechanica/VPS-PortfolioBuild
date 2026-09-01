#!/usr/bin/env python3
"""Activation receipt and governed-worker gate for Custom-history isolation."""

from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from custom_history_contract import (
        ACTIVATION_SCHEMA,
        ACTIVATION_SCHEMA_V2,
        DEFAULT_RUNNER_TERMINALS,
        PROVISIONED_FACTORY_TERMINALS,
        canonical_bytes,
        load_json_strict,
        load_manifest,
        sha256_file,
        utc_now,
        validate_owner_approval,
        write_json_atomic,
    )
    import mt5_history_isolation
    import custom_history_master
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import (
        ACTIVATION_SCHEMA,
        ACTIVATION_SCHEMA_V2,
        DEFAULT_RUNNER_TERMINALS,
        PROVISIONED_FACTORY_TERMINALS,
        canonical_bytes,
        load_json_strict,
        load_manifest,
        sha256_file,
        utc_now,
        validate_owner_approval,
        write_json_atomic,
    )
    from tools.strategy_farm import mt5_history_isolation
    from tools.strategy_farm import custom_history_master


ACTIVATION_RELATIVE_PATH = Path("state/custom_history_isolation_activation.json")
RAMP_RELATIVE_PATH = Path("state/custom_history_ramp.json")
RAMP_SCHEMA = "qm.custom-history-ramp/v1"
RAMP_LIMITS = frozenset({1, 2, 5, 10})
RAMP_LIMITS_V2 = frozenset({*RAMP_LIMITS, 11, 12})
ROLLBACK_MODE_RELATIVE_PATH = Path("state/custom_history_isolation_rollback_mode.json")
ROLLBACK_MODE_SCHEMA = "qm.custom-history-isolation-rollback-mode/v1"
OWNER_WINDOW_EXTENSION_SCHEMA = "qm.custom-history-owner-window-extension/v1"
OWNER_T11_T12_AUTHORITY_TASK_ID = "d7919623-bae4-445f-888c-00f2a3e058ca"
OWNER_T11_T12_DIRECTIVE = (
    "T11/T12 Canary starten, sobald High-Performance-Effekt gemessen"
)
OWNER_T11_T12_DECISION_REGISTER = "Vault OWNER-Entscheidungsregister 2026-09"
ACTIVATION_V2_EXTENSION_TERMINALS = ("T11", "T12")
ACTIVATION_V2_PROTECTED_ROOTS = (
    *mt5_history_isolation.DEFAULT_PROTECTED_ROOTS,
    Path(r"D:\QM\mt5\T11\Bases"),
    Path(r"D:\QM\mt5\T12\Bases"),
)

_ACTIVATION_V1_KEYS = frozenset(
    {
        "schema_version",
        "enabled",
        "activated_at_utc",
        "manifest_path",
        "manifest_sha256",
        "owner_window_receipt_path",
        "owner_window_receipt_sha256",
        "runner_terminals",
        "protected_roots",
        "dual_audits",
        "auto_reengage_containment",
        "activation_sha256",
    }
)
_ACTIVATION_V2_KEYS = _ACTIVATION_V1_KEYS | frozenset(
    {
        "base_activation",
        "owner_window_authority",
        "runner_extension_audits",
    }
)


class CustomHistoryGateError(RuntimeError):
    pass


def activation_path(root: Path) -> Path:
    return Path(root) / ACTIVATION_RELATIVE_PATH


def ramp_path(root: Path) -> Path:
    return Path(root) / RAMP_RELATIVE_PATH


def rollback_mode_path(root: Path) -> Path:
    return Path(root) / ROLLBACK_MODE_RELATIVE_PATH


def _rollback_mode_sha256(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_bytes(
            {key: value for key, value in payload.items() if key != "rollback_mode_sha256"}
        )
    ).hexdigest()


def build_rollback_mode(
    *,
    activation: Mapping[str, Any],
    rollback_receipt_path: Path,
    owner_receipt_path: Path,
) -> dict[str, Any]:
    validated_activation = validate_activation(activation)
    rollback_path = Path(rollback_receipt_path)
    owner_path = Path(owner_receipt_path)
    if sha256_file(owner_path) != validated_activation["owner_window_receipt_sha256"]:
        raise CustomHistoryGateError(
            "rollback mode must bind the activation's OWNER window receipt"
        )
    payload: dict[str, Any] = {
        "schema_version": ROLLBACK_MODE_SCHEMA,
        "recorded_at_utc": utc_now(),
        "activation_sha256": validated_activation["activation_sha256"],
        "rollback_receipt_path": str(rollback_path.absolute()),
        "rollback_receipt_sha256": sha256_file(rollback_path),
        "owner_receipt_path": str(owner_path.absolute()),
        "owner_receipt_sha256": sha256_file(owner_path),
        "dispatch_contract": "GLOBAL_CONTAINMENT_LEASE_REQUIRED",
    }
    payload["rollback_mode_sha256"] = _rollback_mode_sha256(payload)
    return payload


def validate_rollback_mode(
    payload: Mapping[str, Any], *, activation: Mapping[str, Any]
) -> dict[str, Any]:
    required = {
        "schema_version",
        "recorded_at_utc",
        "activation_sha256",
        "rollback_receipt_path",
        "rollback_receipt_sha256",
        "owner_receipt_path",
        "owner_receipt_sha256",
        "dispatch_contract",
        "rollback_mode_sha256",
    }
    if set(payload) != required or payload.get("schema_version") != ROLLBACK_MODE_SCHEMA:
        raise CustomHistoryGateError("rollback-mode receipt schema/key mismatch")
    if payload.get("activation_sha256") != activation.get("activation_sha256"):
        raise CustomHistoryGateError("rollback-mode activation binding mismatch")
    if payload.get("dispatch_contract") != "GLOBAL_CONTAINMENT_LEASE_REQUIRED":
        raise CustomHistoryGateError("rollback mode must require global containment")
    if payload.get("rollback_mode_sha256") != _rollback_mode_sha256(payload):
        raise CustomHistoryGateError("rollback-mode receipt hash mismatch")
    for label in ("rollback", "owner"):
        path = Path(payload[f"{label}_receipt_path"])
        if sha256_file(path) != payload[f"{label}_receipt_sha256"]:
            raise CustomHistoryGateError(f"rollback-mode {label} receipt hash mismatch")
    if payload["owner_receipt_sha256"] != activation["owner_window_receipt_sha256"]:
        raise CustomHistoryGateError("rollback-mode OWNER receipt binding mismatch")
    return dict(payload)


def load_rollback_mode(
    root: Path, *, activation: Mapping[str, Any]
) -> dict[str, Any] | None:
    path = rollback_mode_path(root)
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return None
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryGateError(f"rollback-mode receipt unreadable: {exc}") from exc
    if not isinstance(payload, dict):
        raise CustomHistoryGateError("rollback-mode receipt root must be an object")
    return validate_rollback_mode(payload, activation=activation)


def write_rollback_mode(
    root: Path, payload: Mapping[str, Any], *, activation: Mapping[str, Any]
) -> dict[str, Any]:
    validated = validate_rollback_mode(payload, activation=activation)
    write_json_atomic(rollback_mode_path(root), validated)
    return validated


def _ramp_sha256(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_bytes({key: value for key, value in payload.items() if key != "ramp_sha256"})
    ).hexdigest()


def build_ramp(*, activation: Mapping[str, Any], limit: int, reason: str) -> dict[str, Any]:
    validated_activation = validate_activation(activation)
    is_v2 = validated_activation.get("schema_version") == ACTIVATION_SCHEMA_V2
    allowed_limits = RAMP_LIMITS_V2 if is_v2 else RAMP_LIMITS
    terminal_order = (
        PROVISIONED_FACTORY_TERMINALS if is_v2 else DEFAULT_RUNNER_TERMINALS
    )
    if int(limit) not in allowed_limits:
        allowed = ",".join(str(value) for value in sorted(allowed_limits))
        raise CustomHistoryGateError(f"ramp limit must be one of {allowed}")
    payload: dict[str, Any] = {
        "schema_version": RAMP_SCHEMA,
        "recorded_at_utc": utc_now(),
        "activation_sha256": validated_activation["activation_sha256"],
        "limit": int(limit),
        "terminal_order": list(terminal_order),
        "reason": str(reason).strip(),
    }
    if not payload["reason"]:
        raise CustomHistoryGateError("ramp reason is required")
    payload["ramp_sha256"] = _ramp_sha256(payload)
    return payload


def validate_ramp(payload: Mapping[str, Any], *, activation: Mapping[str, Any]) -> dict[str, Any]:
    required = {
        "schema_version",
        "recorded_at_utc",
        "activation_sha256",
        "limit",
        "terminal_order",
        "reason",
        "ramp_sha256",
    }
    if set(payload) != required or payload.get("schema_version") != RAMP_SCHEMA:
        raise CustomHistoryGateError("ramp receipt schema/key mismatch")
    validated_activation = validate_activation(activation)
    direct_binding = payload.get("activation_sha256") == validated_activation.get(
        "activation_sha256"
    )
    inherited_v1_binding = (
        validated_activation.get("schema_version") == ACTIVATION_SCHEMA_V2
        and payload.get("activation_sha256")
        == validated_activation.get("base_activation", {}).get("activation_sha256")
    )
    if not (direct_binding or inherited_v1_binding):
        raise CustomHistoryGateError("ramp activation binding mismatch")
    if inherited_v1_binding:
        allowed_limits = RAMP_LIMITS
        expected_terminals = DEFAULT_RUNNER_TERMINALS
    else:
        allowed_limits = (
            RAMP_LIMITS_V2
            if validated_activation.get("schema_version") == ACTIVATION_SCHEMA_V2
            else RAMP_LIMITS
        )
        expected_terminals = (
            PROVISIONED_FACTORY_TERMINALS
            if validated_activation.get("schema_version") == ACTIVATION_SCHEMA_V2
            else DEFAULT_RUNNER_TERMINALS
        )
    if int(payload.get("limit", 0)) not in allowed_limits:
        raise CustomHistoryGateError("ramp limit is invalid")
    if tuple(payload.get("terminal_order", ())) != expected_terminals:
        raise CustomHistoryGateError("ramp terminal order mismatch")
    if not str(payload.get("reason") or "").strip():
        raise CustomHistoryGateError("ramp reason is required")
    if payload.get("ramp_sha256") != _ramp_sha256(payload):
        raise CustomHistoryGateError("ramp receipt hash mismatch")
    return dict(payload)


def load_ramp(root: Path, *, activation: Mapping[str, Any]) -> dict[str, Any] | None:
    path = ramp_path(root)
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return None
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryGateError(f"ramp receipt unreadable: {exc}") from exc
    if not isinstance(payload, dict):
        raise CustomHistoryGateError("ramp receipt root must be an object")
    return validate_ramp(payload, activation=activation)


def write_ramp(root: Path, payload: Mapping[str, Any], *, activation: Mapping[str, Any]) -> dict[str, Any]:
    validated = validate_ramp(payload, activation=activation)
    write_json_atomic(ramp_path(root), validated)
    return validated


def activation_sha256(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_bytes(
            {key: value for key, value in payload.items() if key != "activation_sha256"}
        )
    ).hexdigest()


def owner_window_extension_sha256(payload: Mapping[str, Any]) -> str:
    return hashlib.sha256(
        canonical_bytes(
            {
                key: value
                for key, value in payload.items()
                if key != "owner_window_sha256"
            }
        )
    ).hexdigest()


def _exact_terminal_set(
    value: Any,
    *,
    expected: Sequence[str],
    field: str,
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise CustomHistoryGateError(f"{field} must be a list")
    normalized = tuple(str(item).strip().upper() for item in value)
    expected_normalized = tuple(str(item).strip().upper() for item in expected)
    if (
        any(not item for item in normalized)
        or len(normalized) != len(expected_normalized)
        or len(set(normalized)) != len(normalized)
        or set(normalized) != set(expected_normalized)
    ):
        raise CustomHistoryGateError(
            f"{field} must be exactly {','.join(expected_normalized)}"
        )
    return normalized


def _normalized_root(value: Any) -> str:
    return str(Path(str(value)).resolve(strict=False)).casefold().rstrip("\\/")


def _validate_exact_protected_roots(
    value: Any,
    *,
    expected: Sequence[Path | str],
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise CustomHistoryGateError("protected_roots must be a list")
    roots = tuple(str(item).strip() for item in value)
    normalized = tuple(_normalized_root(item) for item in roots)
    expected_normalized = tuple(_normalized_root(item) for item in expected)
    if (
        any(not item for item in roots)
        or len(normalized) != len(expected_normalized)
        or len(set(normalized)) != len(normalized)
        or set(normalized) != set(expected_normalized)
    ):
        raise CustomHistoryGateError(
            "protected-root set must exactly match the governed schema set"
        )
    return normalized


def validate_owner_window_extension(
    payload: Mapping[str, Any],
    *,
    manifest_sha256: str,
    base_activation_sha256: str,
) -> dict[str, Any]:
    required = {
        "schema_version",
        "authority",
        "authority_task_id",
        "authority_date",
        "owner_directive",
        "decision_register",
        "measured_condition",
        "manifest_sha256",
        "base_activation_sha256",
        "runner_terminals",
        "orchestrator_countersign_required",
        "live_trading_authorized",
        "owner_window_sha256",
    }
    if (
        set(payload) != required
        or payload.get("schema_version") != OWNER_WINDOW_EXTENSION_SCHEMA
    ):
        raise CustomHistoryGateError("OWNER window extension schema/key mismatch")
    if payload.get("authority") != "OWNER":
        raise CustomHistoryGateError("OWNER window extension authority mismatch")
    if payload.get("authority_task_id") != OWNER_T11_T12_AUTHORITY_TASK_ID:
        raise CustomHistoryGateError("OWNER window extension task binding mismatch")
    if payload.get("authority_date") != "2026-09-01":
        raise CustomHistoryGateError("OWNER window extension date mismatch")
    if payload.get("owner_directive") != OWNER_T11_T12_DIRECTIVE:
        raise CustomHistoryGateError("OWNER window extension directive mismatch")
    if payload.get("decision_register") != OWNER_T11_T12_DECISION_REGISTER:
        raise CustomHistoryGateError("OWNER decision-register binding mismatch")
    if payload.get("measured_condition") != {
        "metric": "census_throughput_gain_pct",
        "status": "MEASURED",
        "value": 7,
    }:
        raise CustomHistoryGateError("OWNER activation condition mismatch")
    if str(payload.get("manifest_sha256") or "").casefold() != str(
        manifest_sha256
    ).casefold():
        raise CustomHistoryGateError("OWNER window extension manifest mismatch")
    if str(payload.get("base_activation_sha256") or "").casefold() != str(
        base_activation_sha256
    ).casefold():
        raise CustomHistoryGateError("OWNER window extension base activation mismatch")
    _exact_terminal_set(
        payload.get("runner_terminals"),
        expected=PROVISIONED_FACTORY_TERMINALS,
        field="OWNER window extension runner_terminals",
    )
    if payload.get("orchestrator_countersign_required") is not True:
        raise CustomHistoryGateError("Orchestrator countersign is required")
    if payload.get("live_trading_authorized") is not False:
        raise CustomHistoryGateError("OWNER window extension cannot authorize live trading")
    if str(payload.get("owner_window_sha256") or "").casefold() != (
        owner_window_extension_sha256(payload)
    ):
        raise CustomHistoryGateError("OWNER window extension hash mismatch")
    return dict(payload)


def _load_bound_json(path: Path, *, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryGateError(f"{label} unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise CustomHistoryGateError(f"{label} root must be an object: {path}")
    return payload


def _validate_runner_extension_receipt(
    row: Mapping[str, Any],
    *,
    manifest_sha256: str,
) -> str:
    if set(row) != {"terminal", "path", "file_sha256", "receipt_sha256"}:
        raise CustomHistoryGateError("runner extension audit key mismatch")
    terminal = str(row.get("terminal") or "").strip().upper()
    path = Path(str(row.get("path") or ""))
    if sha256_file(path) != str(row.get("file_sha256") or "").casefold():
        raise CustomHistoryGateError(
            f"runner extension audit file hash mismatch: {path}"
        )
    receipt = _load_bound_json(path, label="runner extension audit")
    required_receipt_values = {
        "schema_version": "qm.inert-factory-canary-provision/v1",
        "status": "PASS_INERT_PROVISIONED",
        "terminal": terminal,
        "activation_performed": False,
        "terminal_started": False,
        "t_live_touched": False,
        "disabled_verified": True,
    }
    for key, expected in required_receipt_values.items():
        if receipt.get(key) != expected:
            raise CustomHistoryGateError(
                f"runner extension audit {terminal} {key} mismatch"
            )
    if terminal not in ACTIVATION_V2_EXTENSION_TERMINALS:
        raise CustomHistoryGateError("runner extension audit terminal mismatch")
    custom_history = receipt.get("custom_history")
    if not isinstance(custom_history, dict) or (
        custom_history.get("manifest_content_sha256") != manifest_sha256
        or custom_history.get("verification") != "PASS_FULL_SHA256"
        or custom_history.get("admission_state")
        != "FAIL_CLOSED_NOT_IN_ACTIVE_T1_T10_ACTIVATION"
    ):
        raise CustomHistoryGateError(
            f"runner extension audit {terminal} Custom-history binding mismatch"
        )
    _exact_terminal_set(
        custom_history.get("signed_runner_set_preserved"),
        expected=DEFAULT_RUNNER_TERMINALS,
        field=f"runner extension audit {terminal} signed_runner_set_preserved",
    )
    containment = receipt.get("containment")
    if not isinstance(containment, dict) or containment.get("enabled") is not False:
        raise CustomHistoryGateError(
            f"runner extension audit {terminal} containment state mismatch"
        )
    receipt_hash = hashlib.sha256(
        canonical_bytes(
            {key: value for key, value in receipt.items() if key != "receipt_sha256"}
        )
    ).hexdigest()
    if (
        receipt_hash != str(receipt.get("receipt_sha256") or "").casefold()
        or receipt_hash != str(row.get("receipt_sha256") or "").casefold()
    ):
        raise CustomHistoryGateError(
            f"runner extension audit {terminal} receipt hash mismatch"
        )
    return terminal


def _validate_activation_v2_extension(
    payload: Mapping[str, Any],
    *,
    manifest_sha256: str,
) -> None:
    base_binding = payload.get("base_activation")
    if not isinstance(base_binding, dict) or set(base_binding) != {
        "path",
        "file_sha256",
        "activation_sha256",
    }:
        raise CustomHistoryGateError("v2 base_activation binding mismatch")
    base_path = Path(str(base_binding.get("path") or ""))
    if sha256_file(base_path) != str(base_binding.get("file_sha256") or "").casefold():
        raise CustomHistoryGateError("v2 base activation file hash mismatch")
    base = _load_bound_json(base_path, label="v2 base activation")
    if base.get("schema_version") != ACTIVATION_SCHEMA:
        raise CustomHistoryGateError("v2 base activation must be a v1 receipt")
    validated_base = validate_activation(base)
    base_sha256 = str(validated_base["activation_sha256"]).casefold()
    if base_sha256 != str(base_binding.get("activation_sha256") or "").casefold():
        raise CustomHistoryGateError("v2 base activation identity mismatch")
    if validated_base.get("manifest_sha256") != manifest_sha256:
        raise CustomHistoryGateError("v2 base activation manifest mismatch")

    owner_binding = payload.get("owner_window_authority")
    if not isinstance(owner_binding, dict) or set(owner_binding) != {
        "path",
        "file_sha256",
        "owner_window_sha256",
    }:
        raise CustomHistoryGateError("v2 OWNER window authority binding mismatch")
    owner_path = Path(str(owner_binding.get("path") or ""))
    if sha256_file(owner_path) != str(owner_binding.get("file_sha256") or "").casefold():
        raise CustomHistoryGateError("v2 OWNER window authority file hash mismatch")
    owner_extension = _load_bound_json(
        owner_path, label="v2 OWNER window authority"
    )
    validated_owner = validate_owner_window_extension(
        owner_extension,
        manifest_sha256=manifest_sha256,
        base_activation_sha256=base_sha256,
    )
    if validated_owner["owner_window_sha256"] != str(
        owner_binding.get("owner_window_sha256") or ""
    ).casefold():
        raise CustomHistoryGateError("v2 OWNER window authority identity mismatch")

    extension_rows = payload.get("runner_extension_audits")
    if not isinstance(extension_rows, list) or len(extension_rows) != 2:
        raise CustomHistoryGateError("exactly two runner extension audits are required")
    terminals = tuple(
        _validate_runner_extension_receipt(row, manifest_sha256=manifest_sha256)
        if isinstance(row, dict)
        else ""
        for row in extension_rows
    )
    _exact_terminal_set(
        list(terminals),
        expected=ACTIVATION_V2_EXTENSION_TERMINALS,
        field="runner_extension_audits terminals",
    )


def validate_activation(payload: Mapping[str, Any]) -> dict[str, Any]:
    schema = payload.get("schema_version")
    required = (
        _ACTIVATION_V1_KEYS
        if schema == ACTIVATION_SCHEMA
        else _ACTIVATION_V2_KEYS
        if schema == ACTIVATION_SCHEMA_V2
        else None
    )
    if required is None or set(payload) != required:
        raise CustomHistoryGateError("activation receipt schema/key mismatch")
    if payload.get("enabled") is not True:
        raise CustomHistoryGateError("activation receipt is not enabled")
    if payload.get("auto_reengage_containment") is not True:
        raise CustomHistoryGateError("automatic containment re-engagement is required")
    expected = activation_sha256(payload)
    if str(payload.get("activation_sha256") or "").casefold() != expected:
        raise CustomHistoryGateError("activation receipt hash mismatch")
    expected_terminals = (
        DEFAULT_RUNNER_TERMINALS
        if schema == ACTIVATION_SCHEMA
        else PROVISIONED_FACTORY_TERMINALS
    )
    _exact_terminal_set(
        payload.get("runner_terminals"),
        expected=expected_terminals,
        field="activation runner_terminals",
    )
    expected_protected_roots = (
        mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
        if schema == ACTIVATION_SCHEMA
        else ACTIVATION_V2_PROTECTED_ROOTS
    )
    _validate_exact_protected_roots(
        payload.get("protected_roots"), expected=expected_protected_roots
    )
    base_expected_roots = tuple(
        _normalized_root(value)
        for value in mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
    )
    manifest = load_manifest(Path(payload["manifest_path"]), require_owner_approval=True)
    if str(payload["manifest_sha256"]).casefold() != manifest["manifest_sha256"]:
        raise CustomHistoryGateError("activation manifest hash mismatch")
    owner_path = Path(payload["owner_window_receipt_path"])
    if not owner_path.is_file():
        raise CustomHistoryGateError("OWNER window receipt missing")
    if sha256_file(owner_path) != str(payload["owner_window_receipt_sha256"]).casefold():
        raise CustomHistoryGateError("OWNER window receipt file hash mismatch")
    owner = load_json_strict(owner_path)
    validate_owner_approval(
        owner,
        expected_manifest_sha256=manifest["manifest_sha256"],
        expected_terminals=manifest["runner_terminals"],
    )
    if canonical_bytes(owner) != canonical_bytes(manifest["owner_approval"]):
        raise CustomHistoryGateError(
            "OWNER window receipt does not exactly match the manifest approval"
        )
    audits = payload["dual_audits"]
    if not isinstance(audits, list) or len(audits) != 2:
        raise CustomHistoryGateError("exactly two independent cutover audits are required")
    paths: set[str] = set()
    for index, row in enumerate(audits):
        if not isinstance(row, dict) or set(row) != {"path", "file_sha256", "audit_sha256"}:
            raise CustomHistoryGateError(f"dual_audits[{index}] key mismatch")
        audit_path = Path(row["path"])
        normalized = str(audit_path.absolute()).casefold()
        if normalized in paths:
            raise CustomHistoryGateError("dual audit paths must be distinct")
        paths.add(normalized)
        if sha256_file(audit_path) != str(row["file_sha256"]).casefold():
            raise CustomHistoryGateError(f"dual audit file hash mismatch: {audit_path}")
        try:
            audit = json.loads(audit_path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise CustomHistoryGateError(f"dual audit unreadable: {audit_path}: {exc}") from exc
        if audit.get("status") != "PASS_ISOLATED":
            raise CustomHistoryGateError(f"dual audit is not PASS_ISOLATED: {audit_path}")
        if (
            audit.get("schema_version") != mt5_history_isolation.SCHEMA_VERSION
            or audit.get("audit_mode") != "READ_ONLY"
            or audit.get("runtime_action") != "NONE"
        ):
            raise CustomHistoryGateError(f"dual audit contract mismatch: {audit_path}")
        if not isinstance(audit.get("runner_terminals"), list):
            raise CustomHistoryGateError(f"dual audit runner set missing: {audit_path}")
        audit_terminals = tuple(
            str(value).strip().upper() for value in audit["runner_terminals"]
        )
        if (
            len(audit_terminals) != len(DEFAULT_RUNNER_TERMINALS)
            or len(set(audit_terminals)) != len(audit_terminals)
            or set(audit_terminals) != set(DEFAULT_RUNNER_TERMINALS)
        ):
            raise CustomHistoryGateError(f"dual audit runner set mismatch: {audit_path}")
        if not isinstance(audit.get("protected_roots"), list):
            raise CustomHistoryGateError(
                f"dual audit protected-root set missing: {audit_path}"
            )
        audit_roots = tuple(
            str(value).casefold().rstrip("\\/") for value in audit["protected_roots"]
        )
        if (
            len(audit_roots) != len(base_expected_roots)
            or len(set(audit_roots)) != len(audit_roots)
            or set(audit_roots) != set(base_expected_roots)
        ):
            raise CustomHistoryGateError(f"dual audit protected-root set mismatch: {audit_path}")
        if audit.get("audit_sha256") != row["audit_sha256"]:
            raise CustomHistoryGateError(f"dual audit identity mismatch: {audit_path}")
        computed_audit_sha256 = hashlib.sha256(
            canonical_bytes(
                {key: value for key, value in audit.items() if key != "audit_sha256"}
            )
        ).hexdigest()
        if audit.get("audit_sha256") != computed_audit_sha256:
            raise CustomHistoryGateError(f"dual audit content hash mismatch: {audit_path}")
        file_audit = audit.get("variant_a_file_audit") or {}
        if file_audit.get("status") != "PASS_ISOLATED":
            raise CustomHistoryGateError(f"dual file audit is not PASS_ISOLATED: {audit_path}")
        if file_audit.get("manifest_sha256") != manifest["manifest_sha256"]:
            raise CustomHistoryGateError(f"dual audit manifest mismatch: {audit_path}")
        if file_audit.get("archive_hash_verification") != "FULL":
            raise CustomHistoryGateError(f"dual audit was not a full hash audit: {audit_path}")
        acl_evidence = audit.get("archive_acl_evidence")
        if (
            not isinstance(acl_evidence, dict)
            or not acl_evidence.get("path")
            or not acl_evidence.get("file_sha256")
        ):
            raise CustomHistoryGateError(
                f"dual audit lacks bound full ACL verification evidence: {audit_path}"
            )
        verified_acl = mt5_history_isolation.load_acl_evidence(
            Path(acl_evidence["path"]), manifest=manifest
        )
        if verified_acl["file_sha256"] != acl_evidence["file_sha256"]:
            raise CustomHistoryGateError(f"dual audit ACL evidence mismatch: {audit_path}")
    if schema == ACTIVATION_SCHEMA_V2:
        _validate_activation_v2_extension(
            payload,
            manifest_sha256=manifest["manifest_sha256"],
        )
    return dict(payload)


def load_activation(root: Path) -> dict[str, Any] | None:
    path = activation_path(root)
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return None
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CustomHistoryGateError(f"activation receipt unreadable: {exc}") from exc
    if not isinstance(payload, dict):
        raise CustomHistoryGateError("activation receipt root must be an object")
    return validate_activation(payload)


def build_activation(
    *,
    manifest_path: Path,
    owner_window_receipt_path: Path,
    protected_roots: Sequence[Path | str],
    dual_audit_paths: Sequence[Path],
) -> dict[str, Any]:
    if len(dual_audit_paths) != 2:
        raise CustomHistoryGateError("two dual-audit paths are required")
    manifest = load_manifest(Path(manifest_path), require_owner_approval=True)
    owner_path = Path(owner_window_receipt_path)
    audits = []
    for path in dual_audit_paths:
        audit_path = Path(path)
        try:
            audit = json.loads(audit_path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise CustomHistoryGateError(
                f"dual audit unreadable: {audit_path}: {exc}"
            ) from exc
        if not isinstance(audit, dict):
            raise CustomHistoryGateError(
                f"dual audit root must be an object: {audit_path}"
            )
        audits.append(
            {
                "path": str(audit_path.absolute()),
                "file_sha256": sha256_file(audit_path),
                "audit_sha256": audit.get("audit_sha256"),
            }
        )
    payload: dict[str, Any] = {
        "schema_version": ACTIVATION_SCHEMA,
        "enabled": True,
        "activated_at_utc": utc_now(),
        "manifest_path": str(Path(manifest_path).absolute()),
        "manifest_sha256": manifest["manifest_sha256"],
        "owner_window_receipt_path": str(owner_path.absolute()),
        "owner_window_receipt_sha256": sha256_file(owner_path),
        "runner_terminals": list(DEFAULT_RUNNER_TERMINALS),
        "protected_roots": [str(Path(value).absolute()) for value in protected_roots],
        "dual_audits": audits,
        "auto_reengage_containment": True,
    }
    payload["activation_sha256"] = activation_sha256(payload)
    validate_activation(payload)
    return payload


def build_activation_v2(
    *,
    base_activation_path: Path,
    owner_window_authority_path: Path,
    runner_extension_audit_paths: Sequence[Path],
) -> dict[str, Any]:
    if len(runner_extension_audit_paths) != 2:
        raise CustomHistoryGateError("two runner extension audit paths are required")
    base_path = Path(base_activation_path)
    base = _load_bound_json(base_path, label="v2 base activation")
    validated_base = validate_activation(base)
    if validated_base.get("schema_version") != ACTIVATION_SCHEMA:
        raise CustomHistoryGateError("v2 base activation must use the v1 schema")

    authority_path = Path(owner_window_authority_path)
    authority = _load_bound_json(authority_path, label="v2 OWNER window authority")
    validated_authority = validate_owner_window_extension(
        authority,
        manifest_sha256=validated_base["manifest_sha256"],
        base_activation_sha256=validated_base["activation_sha256"],
    )

    extension_rows: list[dict[str, Any]] = []
    for raw_path in runner_extension_audit_paths:
        path = Path(raw_path)
        receipt = _load_bound_json(path, label="runner extension audit")
        extension_rows.append(
            {
                "terminal": str(receipt.get("terminal") or "").strip().upper(),
                "path": str(path.absolute()),
                "file_sha256": sha256_file(path),
                "receipt_sha256": str(receipt.get("receipt_sha256") or "").casefold(),
            }
        )

    payload: dict[str, Any] = {
        "schema_version": ACTIVATION_SCHEMA_V2,
        "enabled": True,
        "activated_at_utc": utc_now(),
        "manifest_path": validated_base["manifest_path"],
        "manifest_sha256": validated_base["manifest_sha256"],
        "owner_window_receipt_path": validated_base["owner_window_receipt_path"],
        "owner_window_receipt_sha256": validated_base[
            "owner_window_receipt_sha256"
        ],
        "runner_terminals": list(PROVISIONED_FACTORY_TERMINALS),
        "protected_roots": [
            str(Path(value).absolute()) for value in ACTIVATION_V2_PROTECTED_ROOTS
        ],
        "dual_audits": list(validated_base["dual_audits"]),
        "auto_reengage_containment": True,
        "base_activation": {
            "path": str(base_path.absolute()),
            "file_sha256": sha256_file(base_path),
            "activation_sha256": validated_base["activation_sha256"],
        },
        "owner_window_authority": {
            "path": str(authority_path.absolute()),
            "file_sha256": sha256_file(authority_path),
            "owner_window_sha256": validated_authority["owner_window_sha256"],
        },
        "runner_extension_audits": extension_rows,
    }
    payload["activation_sha256"] = activation_sha256(payload)
    validate_activation(payload)
    return payload


def write_activation(root: Path, payload: Mapping[str, Any]) -> dict[str, Any]:
    validated = validate_activation(payload)
    write_json_atomic(activation_path(root), validated)
    return validated


def _runtime_protected_roots(activation: Mapping[str, Any]) -> tuple[Path, ...]:
    """Return foreign roots for overlap checks without self-colliding runners.

    The v2 receipt additionally binds T11/T12 ``Bases`` as protected runner
    roots.  Those same paths are already inspected as mutable runner components
    by the pairwise topology evaluator; passing them again as *foreign* roots
    would compare each path with itself and fail every valid v2 gate.  The
    long-standing non-runner roots remain the foreign protected set, while the
    T11/T12 roots retain their receipt binding and pairwise isolation checks.
    """

    if activation.get("schema_version") == ACTIVATION_SCHEMA_V2:
        return tuple(Path(value) for value in mt5_history_isolation.DEFAULT_PROTECTED_ROOTS)
    return tuple(Path(value) for value in activation["protected_roots"])


def run_worker_gate(
    root: Path,
    *,
    terminal: str,
    mt5_root: Path | str = mt5_history_isolation.DEFAULT_MT5_ROOT,
) -> dict[str, Any]:
    """Run the immediate metadata/file-ID gate; full hashes bind via dual receipts."""

    activation = load_activation(root)
    if activation is None:
        return {
            "required": False,
            "status": "NOT_ACTIVE",
            "terminal": str(terminal).upper(),
        }
    target = str(terminal).upper()
    if target not in activation["runner_terminals"]:
        return {
            "required": True,
            "status": "FAIL_CLOSED",
            "terminal": target,
            "reason": "terminal_not_in_activation",
            "activation_sha256": activation["activation_sha256"],
        }
    rollback_mode = load_rollback_mode(root, activation=activation)
    if rollback_mode is not None:
        try:
            try:
                import custom_history_lease
            except ImportError:  # pragma: no cover - package import path
                from tools.strategy_farm import custom_history_lease
            containment = custom_history_lease.load_mode(root)
        except Exception as exc:
            raise CustomHistoryGateError(
                f"rollback containment mode cannot be established: {exc}"
            ) from exc
        if not containment.get("enabled"):
            raise CustomHistoryGateError(
                "rollback topology requires engaged global Custom-history containment"
            )
        return {
            "required": True,
            "status": "PASS_SERIALIZED_ROLLBACK",
            "admission_allowed": True,
            "terminal": target,
            "activation_sha256": activation["activation_sha256"],
            "rollback_mode_sha256": rollback_mode["rollback_mode_sha256"],
            "containment_mode_sha256": containment["mode_sha256"],
            "reason": "owner_authorized_shared_topology_rollback_under_global_lease",
        }
    ramp = load_ramp(root, activation=activation)
    if ramp is None:
        return {
            "required": True,
            "status": "PASS_ISOLATED",
            "admission_allowed": False,
            "terminal": target,
            "reason": "custom_history_ramp_not_initialized",
            "ramp_limit": 0,
            "allowed_terminals": [],
            "activation_sha256": activation["activation_sha256"],
        }
    allowed = tuple(ramp["terminal_order"][: int(ramp["limit"])])
    if target not in allowed:
        return {
            "required": True,
            "status": "PASS_ISOLATED",
            "admission_allowed": False,
            "terminal": target,
            "reason": "custom_history_ramp_hold",
            "ramp_limit": ramp["limit"],
            "allowed_terminals": list(allowed),
            "ramp_sha256": ramp["ramp_sha256"],
            "activation_sha256": activation["activation_sha256"],
        }

    # The dual fresh-process receipts bind full family content hashes.  The
    # immediate gate re-enumerates file IDs, sizes, dynamic family link counts,
    # and topology. Only the claiming terminal's private inodes are content
    # re-hashed here: other terminals' MT5 processes hold their privatized
    # archives write-open, so a concurrent read open would raise a sharing
    # violation. Foreign private inodes remain bound by their claim-time
    # copy-on-claim proof and the quiescent full audits.
    #
    # A concurrent copy-on-claim privatization on another terminal shrinks a
    # hardlink family while this gate's sequential scan is mid-snapshot, so a
    # pure ARCHIVE_LINK_COUNT_TOO_LOW result (typically actual==minimum-1) can
    # be a benign torn read. Re-audit for a consistent snapshot before
    # treating it as real; genuine deletions either raise MISSING findings
    # (different code, no retry) or persist across every re-audit and stay
    # fail-closed.
    audit: dict[str, Any] = {}
    for attempt in range(3):
        audit = mt5_history_isolation.audit_history_isolation(
            mt5_root=mt5_root,
            terminals=tuple(activation["runner_terminals"]),
            protected_roots=_runtime_protected_roots(activation),
            manifest_path=Path(activation["manifest_path"]),
            require_owner_approval=True,
            verify_archive_hashes=False,
            hash_private_terminals=(target,),
        )
        if audit["status"] == "PASS_ISOLATED":
            break
        codes = {
            str(finding.get("code"))
            for finding in (
                list(audit.get("findings", []))
                + list(audit.get("variant_a_file_audit", {}).get("findings", []))
            )
        }
        if codes != {"ARCHIVE_LINK_COUNT_TOO_LOW"}:
            break
        time.sleep(1.5)

    # A large copy-on-claim privatization replaces archives for minutes while
    # one inventory pass itself spans many seconds, so every whole-audit retry
    # above can tear again (2026-08-10: 43 AUDJPY archives privatizing on one
    # terminal produced 288 persistent link-count findings across the fleet).
    # Reconcile the flagged families with per-path instantaneous recounts; a
    # recount is microsecond-scale and converges even mid-privatization.
    # Reconciliation errors and unexplained deficits stay fail-closed.
    status = str(audit["status"])
    findings = audit.get("findings", []) + (
        audit.get("variant_a_file_audit", {}).get("findings", [])
    )
    reconciliation_summary: dict[str, Any] | None = None
    if status != "PASS_ISOLATED" and findings and {
        str(finding.get("code")) for finding in findings
    } == {"ARCHIVE_LINK_COUNT_TOO_LOW"}:
        try:
            manifest = load_manifest(
                Path(activation["manifest_path"]), require_owner_approval=True
            )
            reconciliation = mt5_history_isolation.reconcile_archive_link_count_findings(
                mt5_root=mt5_root,
                terminals=tuple(activation["runner_terminals"]),
                manifest=manifest,
                findings=findings,
            )
        except Exception as exc:
            reconciliation_summary = {"status": "ERROR", "error": repr(exc)}
        else:
            reconciliation_summary = {
                "status": "CLEARED" if not reconciliation["remaining"] else "REMAINING",
                "cleared_count": len(reconciliation["cleared"]),
                "remaining_count": len(reconciliation["remaining"]),
                "paths_recounted": len(reconciliation["recounts"]),
            }
            if not reconciliation["remaining"]:
                status = "PASS_ISOLATED"
                findings = []
            else:
                findings = reconciliation["remaining"]

    # DL-085 repair-first: a manifest archive gap is repaired from the
    # standalone verified master tree (sha-verified copy + receipt) instead of
    # fail-closing the fleet. Containment remains for master loss/mismatch —
    # any repair failure keeps the original FAIL status untouched.
    repair_summary: dict[str, Any] | None = None
    if status != "PASS_ISOLATED" and findings and {
        str(finding.get("code")) for finding in findings
    } <= set(custom_history_master.REPAIRABLE_FINDING_CODES):
        try:
            manifest = load_manifest(
                Path(activation["manifest_path"]), require_owner_approval=True
            )
            repair = custom_history_master.repair_missing_archives(
                farm_root=root,
                mt5_root=mt5_root,
                manifest=manifest,
                findings=findings,
                repaired_by=f"worker_gate:{target}",
            )
        except Exception as exc:
            # A repair pass that dies on a transient copy-environment error
            # (sharing violation, resource exhaustion) defers this claim only;
            # ERROR remains the master-cannot-vouch emergency class.
            repair_summary = {
                "status": (
                    "ERROR_TRANSIENT_IO"
                    if custom_history_master.is_transient_repair_io_error(exc)
                    else "ERROR"
                ),
                "error": repr(exc),
            }
        else:
            failed_transient = [
                record for record in repair["failed"] if record.get("transient_io")
            ]
            if not repair["failed"]:
                repair_status = "REPAIRED"
            elif len(failed_transient) == len(repair["failed"]):
                # Every failure is a copy race / resource artifact while the
                # master still vouches -> defer, never fleet-stop (2026-08-14
                # 21:49Z: 1-of-4 transient failure reported PARTIAL and
                # engaged containment although a concurrent sibling repair of
                # the same file succeeded in the same second).
                repair_status = "PARTIAL_TRANSIENT_IO"
            else:
                repair_status = "PARTIAL"
            repair_summary = {
                "status": repair_status,
                "repaired_count": len(repair["repaired"]),
                "already_present_count": len(repair["already_present"]),
                "failed_count": len(repair["failed"]),
                "failed_transient_io_count": len(failed_transient),
                "receipts_path": repair["receipts_path"],
            }
            if not repair["failed"]:
                verification = mt5_history_isolation.audit_history_isolation(
                    mt5_root=mt5_root,
                    terminals=tuple(activation["runner_terminals"]),
                    protected_roots=_runtime_protected_roots(activation),
                    manifest_path=Path(activation["manifest_path"]),
                    require_owner_approval=True,
                    verify_archive_hashes=False,
                    hash_private_terminals=(target,),
                )
                repair_summary["post_repair_status"] = str(verification["status"])
                if verification["status"] == "PASS_ISOLATED":
                    audit = verification
                    status = "PASS_ISOLATED"
                    findings = []
    result = {
        "required": True,
        "status": status,
        "terminal": target,
        "activation_sha256": activation["activation_sha256"],
        "audit_sha256": audit["audit_sha256"],
        "manifest_sha256": activation["manifest_sha256"],
        "admission_allowed": True,
        "ramp_limit": ramp["limit"],
        "ramp_sha256": ramp["ramp_sha256"],
        "findings": findings,
    }
    if reconciliation_summary is not None:
        result["link_count_reconciliation"] = reconciliation_summary
    if repair_summary is not None:
        result["master_repair"] = repair_summary
    return result
