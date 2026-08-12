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
        DEFAULT_RUNNER_TERMINALS,
        canonical_bytes,
        load_json_strict,
        load_manifest,
        sha256_file,
        utc_now,
        validate_owner_approval,
        write_json_atomic,
    )
    import mt5_history_isolation
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import (
        ACTIVATION_SCHEMA,
        DEFAULT_RUNNER_TERMINALS,
        canonical_bytes,
        load_json_strict,
        load_manifest,
        sha256_file,
        utc_now,
        validate_owner_approval,
        write_json_atomic,
    )
    from tools.strategy_farm import mt5_history_isolation


ACTIVATION_RELATIVE_PATH = Path("state/custom_history_isolation_activation.json")
RAMP_RELATIVE_PATH = Path("state/custom_history_ramp.json")
RAMP_SCHEMA = "qm.custom-history-ramp/v1"
RAMP_LIMITS = frozenset({1, 2, 5, 10})
ROLLBACK_MODE_RELATIVE_PATH = Path("state/custom_history_isolation_rollback_mode.json")
ROLLBACK_MODE_SCHEMA = "qm.custom-history-isolation-rollback-mode/v1"


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
    if int(limit) not in RAMP_LIMITS:
        raise CustomHistoryGateError("ramp limit must be one of 1,2,5,10")
    payload: dict[str, Any] = {
        "schema_version": RAMP_SCHEMA,
        "recorded_at_utc": utc_now(),
        "activation_sha256": validated_activation["activation_sha256"],
        "limit": int(limit),
        "terminal_order": list(DEFAULT_RUNNER_TERMINALS),
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
    if payload.get("activation_sha256") != activation.get("activation_sha256"):
        raise CustomHistoryGateError("ramp activation binding mismatch")
    if int(payload.get("limit", 0)) not in RAMP_LIMITS:
        raise CustomHistoryGateError("ramp limit is invalid")
    if tuple(payload.get("terminal_order", ())) != DEFAULT_RUNNER_TERMINALS:
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


def validate_activation(payload: Mapping[str, Any]) -> dict[str, Any]:
    required = {
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
    if set(payload) != required or payload.get("schema_version") != ACTIVATION_SCHEMA:
        raise CustomHistoryGateError("activation receipt schema/key mismatch")
    if payload.get("enabled") is not True:
        raise CustomHistoryGateError("activation receipt is not enabled")
    if payload.get("auto_reengage_containment") is not True:
        raise CustomHistoryGateError("automatic containment re-engagement is required")
    expected = activation_sha256(payload)
    if str(payload.get("activation_sha256") or "").casefold() != expected:
        raise CustomHistoryGateError("activation receipt hash mismatch")
    terminals = tuple(sorted({str(value).upper() for value in payload["runner_terminals"]}))
    if terminals != tuple(sorted(DEFAULT_RUNNER_TERMINALS)):
        raise CustomHistoryGateError("activation runner set must be exactly T1-T10")
    roots = tuple(str(value).strip() for value in payload["protected_roots"])
    normalized_roots = tuple(
        str(Path(value).resolve(strict=False)).casefold().rstrip("\\/") for value in roots
    )
    expected_roots = tuple(
        str(Path(value).resolve(strict=False)).casefold().rstrip("\\/")
        for value in mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
    )
    if (
        any(not value for value in roots)
        or len(set(normalized_roots)) != len(expected_roots)
        or set(normalized_roots) != set(expected_roots)
    ):
        raise CustomHistoryGateError(
            "protected-root set must exactly match the governed T_Live/FTMO/DEV/T_Export roots"
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
            sorted({str(value).upper() for value in audit["runner_terminals"]})
        )
        if audit_terminals != tuple(sorted(DEFAULT_RUNNER_TERMINALS)):
            raise CustomHistoryGateError(f"dual audit runner set mismatch: {audit_path}")
        if not isinstance(audit.get("protected_roots"), list):
            raise CustomHistoryGateError(
                f"dual audit protected-root set missing: {audit_path}"
            )
        audit_roots = tuple(
            str(value).casefold().rstrip("\\/") for value in audit["protected_roots"]
        )
        if (
            len(set(audit_roots)) != len(expected_roots)
            or set(audit_roots) != set(expected_roots)
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


def write_activation(root: Path, payload: Mapping[str, Any]) -> dict[str, Any]:
    validated = validate_activation(payload)
    write_json_atomic(activation_path(root), validated)
    return validated


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
            protected_roots=tuple(Path(value) for value in activation["protected_roots"]),
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
    return result
