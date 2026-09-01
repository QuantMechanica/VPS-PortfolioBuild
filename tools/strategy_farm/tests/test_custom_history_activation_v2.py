from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import custom_history_contract as contract
from tools.strategy_farm import custom_history_gate as gate


def _write_json(path: Path, payload: dict) -> None:
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _audit(tmp_path: Path, number: int, manifest_sha256: str) -> Path:
    acl_path = tmp_path / f"acl-{number}.json"
    _write_json(acl_path, {"status": "PASS"})
    payload = {
        "schema_version": gate.mt5_history_isolation.SCHEMA_VERSION,
        "audit_mode": "READ_ONLY",
        "runtime_action": "NONE",
        "status": "PASS_ISOLATED",
        "runner_terminals": list(contract.DEFAULT_RUNNER_TERMINALS),
        "protected_roots": [
            str(Path(value).resolve(strict=False)).casefold().rstrip("\\/")
            for value in gate.mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
        ],
        "variant_a_file_audit": {
            "status": "PASS_ISOLATED",
            "manifest_sha256": manifest_sha256,
            "archive_hash_verification": "FULL",
        },
        "archive_acl_evidence": {
            "path": str(acl_path),
            "file_sha256": contract.sha256_file(acl_path),
        },
    }
    payload["audit_sha256"] = hashlib.sha256(
        contract.canonical_bytes(payload)
    ).hexdigest()
    path = tmp_path / f"audit-{number}.json"
    _write_json(path, payload)
    return path


def _provision_receipt(tmp_path: Path, terminal: str, manifest_sha256: str) -> Path:
    payload = {
        "schema_version": "qm.inert-factory-canary-provision/v1",
        "status": "PASS_INERT_PROVISIONED",
        "terminal": terminal,
        "activation_performed": False,
        "terminal_started": False,
        "t_live_touched": False,
        "disabled_verified": True,
        "custom_history": {
            "manifest_content_sha256": manifest_sha256,
            "verification": "PASS_FULL_SHA256",
            "admission_state": "FAIL_CLOSED_NOT_IN_ACTIVE_T1_T10_ACTIVATION",
            "signed_runner_set_preserved": list(contract.DEFAULT_RUNNER_TERMINALS),
        },
        "containment": {"enabled": False},
    }
    payload["receipt_sha256"] = hashlib.sha256(
        contract.canonical_bytes(payload)
    ).hexdigest()
    path = tmp_path / f"{terminal.lower()}-provision.json"
    _write_json(path, payload)
    return path


def _activation_pair(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> tuple[dict, dict]:
    manifest_sha256 = "a" * 64
    owner = {"authority": "OWNER", "manifest_sha256": manifest_sha256}
    manifest = {
        "manifest_sha256": manifest_sha256,
        "owner_approval": owner,
        "runner_terminals": list(contract.DEFAULT_RUNNER_TERMINALS),
    }
    monkeypatch.setattr(gate, "load_manifest", lambda *args, **kwargs: manifest)
    monkeypatch.setattr(gate, "validate_owner_approval", lambda *args, **kwargs: None)
    monkeypatch.setattr(
        gate.mt5_history_isolation,
        "load_acl_evidence",
        lambda path, manifest: {"file_sha256": contract.sha256_file(path)},
    )

    owner_path = tmp_path / "owner-v1.json"
    _write_json(owner_path, owner)
    audits = [_audit(tmp_path, number, manifest_sha256) for number in (1, 2)]
    base = {
        "schema_version": contract.ACTIVATION_SCHEMA,
        "enabled": True,
        "activated_at_utc": "2026-08-09T16:47:31+00:00",
        "manifest_path": str(tmp_path / "manifest.json"),
        "manifest_sha256": manifest_sha256,
        "owner_window_receipt_path": str(owner_path),
        "owner_window_receipt_sha256": contract.sha256_file(owner_path),
        "runner_terminals": list(contract.DEFAULT_RUNNER_TERMINALS),
        "protected_roots": [
            str(value) for value in gate.mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
        ],
        "dual_audits": [
            {
                "path": str(path),
                "file_sha256": contract.sha256_file(path),
                "audit_sha256": json.loads(path.read_text(encoding="utf-8"))[
                    "audit_sha256"
                ],
            }
            for path in audits
        ],
        "auto_reengage_containment": True,
    }
    base["activation_sha256"] = gate.activation_sha256(base)
    assert gate.validate_activation(base) == base
    base_path = tmp_path / "activation-v1.json"
    _write_json(base_path, base)

    authority = {
        "schema_version": gate.OWNER_WINDOW_EXTENSION_SCHEMA,
        "authority": "OWNER",
        "authority_task_id": gate.OWNER_T11_T12_AUTHORITY_TASK_ID,
        "authority_date": "2026-09-01",
        "owner_directive": gate.OWNER_T11_T12_DIRECTIVE,
        "decision_register": gate.OWNER_T11_T12_DECISION_REGISTER,
        "measured_condition": {
            "metric": "census_throughput_gain_pct",
            "status": "MEASURED",
            "value": 7,
        },
        "manifest_sha256": manifest_sha256,
        "base_activation_sha256": base["activation_sha256"],
        "runner_terminals": list(contract.PROVISIONED_FACTORY_TERMINALS),
        "orchestrator_countersign_required": True,
        "live_trading_authorized": False,
    }
    authority["owner_window_sha256"] = gate.owner_window_extension_sha256(
        authority
    )
    authority_path = tmp_path / "owner-extension.json"
    _write_json(authority_path, authority)

    extension_paths = [
        _provision_receipt(tmp_path, terminal, manifest_sha256)
        for terminal in gate.ACTIVATION_V2_EXTENSION_TERMINALS
    ]
    v2 = gate.build_activation_v2(
        base_activation_path=base_path,
        owner_window_authority_path=authority_path,
        runner_extension_audit_paths=extension_paths,
    )
    return base, v2


def test_v2_accepts_exact_provisioned_set_and_v1_remains_valid(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    base, v2 = _activation_pair(tmp_path, monkeypatch)

    assert gate.validate_activation(base)["schema_version"] == contract.ACTIVATION_SCHEMA
    assert gate.validate_activation(v2)["schema_version"] == contract.ACTIVATION_SCHEMA_V2
    assert tuple(v2["runner_terminals"]) == contract.PROVISIONED_FACTORY_TERMINALS
    assert gate._runtime_protected_roots(v2) == tuple(
        Path(value) for value in gate.mt5_history_isolation.DEFAULT_PROTECTED_ROOTS
    )


@pytest.mark.parametrize(
    "runner_terminals",
    [
        list(contract.PROVISIONED_FACTORY_TERMINALS[:-1]),
        [*contract.PROVISIONED_FACTORY_TERMINALS, "T13"],
    ],
)
def test_v2_refuses_any_11_or_13_terminal_set(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    runner_terminals: list[str],
) -> None:
    _, v2 = _activation_pair(tmp_path, monkeypatch)
    v2["runner_terminals"] = runner_terminals
    v2["activation_sha256"] = gate.activation_sha256(v2)

    with pytest.raises(gate.CustomHistoryGateError, match="must be exactly"):
        gate.validate_activation(v2)


def test_v2_refuses_activation_hash_tamper(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _, v2 = _activation_pair(tmp_path, monkeypatch)
    v2["activated_at_utc"] = "2026-09-01T23:59:59+00:00"

    with pytest.raises(gate.CustomHistoryGateError, match="activation receipt hash"):
        gate.validate_activation(v2)


def test_v2_inherits_valid_v1_ramp_as_ten_terminal_hold(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    base, v2 = _activation_pair(tmp_path, monkeypatch)
    legacy_ramp = gate.build_ramp(
        activation=base,
        limit=10,
        reason="sequenced_full_fleet_soak",
    )

    validated = gate.validate_ramp(legacy_ramp, activation=v2)

    assert validated["activation_sha256"] == base["activation_sha256"]
    assert tuple(validated["terminal_order"]) == contract.DEFAULT_RUNNER_TERMINALS
    assert validated["limit"] == 10


@pytest.mark.parametrize("limit", [11, 12])
def test_v2_builds_exact_staged_extension_ramp(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    limit: int,
) -> None:
    _, v2 = _activation_pair(tmp_path, monkeypatch)

    receipt = gate.build_ramp(
        activation=v2,
        limit=limit,
        reason=f"staged_t11_t12_limit_{limit}",
    )

    assert gate.validate_ramp(receipt, activation=v2) == receipt
    assert receipt["activation_sha256"] == v2["activation_sha256"]
    assert tuple(receipt["terminal_order"]) == contract.PROVISIONED_FACTORY_TERMINALS


def test_v2_refuses_legacy_ramp_with_non_v1_terminal_order(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    base, v2 = _activation_pair(tmp_path, monkeypatch)
    legacy_ramp = gate.build_ramp(activation=base, limit=10, reason="legacy")
    legacy_ramp["terminal_order"] = list(contract.PROVISIONED_FACTORY_TERMINALS)
    legacy_ramp["ramp_sha256"] = gate._ramp_sha256(legacy_ramp)

    with pytest.raises(gate.CustomHistoryGateError, match="terminal order"):
        gate.validate_ramp(legacy_ramp, activation=v2)
