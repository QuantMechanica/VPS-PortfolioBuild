from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import custom_history_contract as contract
from tools.strategy_farm import custom_history_lease as lease
from tools.strategy_farm import custom_history_migration as migration
from tools.strategy_farm import custom_history_gate as gate


def _source_tree(root: Path) -> Path:
    source = root / "mt5" / "T1" / "Bases" / "Custom"
    files = {
        "history/EURUSD.DWX/2025.hcc": b"archive-bars",
        "ticks/EURUSD.DWX/202501.tkc": b"archive-ticks",
        "history/EURUSD.DWX/2026.hcc": b"mutable-bars",
        "ticks/EURUSD.DWX/202601.tkc": b"mutable-ticks",
        "history/EURUSD.DWX/M1.hc": b"mutable-cache",
        "custom.dat": b"mutable-metadata",
    }
    for relative, body in files.items():
        path = source.joinpath(*relative.split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    return source


def _approval(manifest: dict) -> dict:
    return {
        "schema_version": contract.OWNER_APPROVAL_SCHEMA,
        "authority": "OWNER",
        "signed_by": "test-owner",
        "signed_at_utc": "2020-01-02T00:00:00+00:00",
        "signature": "TEST-SIGNATURE-NOT-FOR-PRODUCTION",
        "manifest_sha256": manifest["manifest_sha256"],
        "decision_sha256": "a" * 64,
        "window_id": "20260809T060000Z",
        "window_start_utc": "2020-01-01T00:00:00+00:00",
        "window_end_utc": "2099-01-01T00:00:00+00:00",
        "variant": "A",
        "terminals": list(contract.DEFAULT_RUNNER_TERMINALS),
        "rollback_authorized": True,
        "implementation_git_commit": "b" * 40,
        "claude_review_task_id": "review-task-test",
        "claude_review_verdict": "APPROVED",
        "claude_reviewed_at_utc": "2020-01-01T12:00:00+00:00",
    }


def _approved_files(tmp_path: Path) -> tuple[Path, dict, Path, Path]:
    source = _source_tree(tmp_path)
    draft = contract.build_archive_manifest(
        source,
        runner_identity="TEST\\Runner",
        created_at_utc="2026-08-07T00:00:00+00:00",
    )
    approval = _approval(draft)
    approved = contract.attach_owner_approval(draft, approval)
    manifest_path = tmp_path / "approved-manifest.json"
    owner_path = tmp_path / "owner-window.json"
    contract.write_json_atomic(manifest_path, approved)
    contract.write_json_atomic(owner_path, approval)
    return source, approved, manifest_path, owner_path


def test_manifest_classifies_archive_and_mutable_files(tmp_path: Path) -> None:
    source = _source_tree(tmp_path)
    manifest = contract.build_archive_manifest(
        source,
        runner_identity="TEST\\Runner",
        created_at_utc="2026-08-07T00:00:00+00:00",
    )

    assert [row["relative_path"] for row in manifest["files"]] == [
        "history/EURUSD.DWX/2025.hcc",
        "ticks/EURUSD.DWX/202501.tkc",
    ]
    assert manifest["hash_mode"] == "SHA256_FULL"
    assert manifest["owner_approval"] is None
    assert contract.validate_manifest(manifest) == manifest
    assert contract.classify_relative_path("history/X/2026.hcc")["file_class"] == "CURRENT_YEAR_MUTABLE"
    assert contract.classify_relative_path("ticks/X/202601.tkc")["file_class"] == "CURRENT_YEAR_MUTABLE"
    assert contract.classify_relative_path("history/X/M1.hc")["file_class"] == "UNCLASSIFIED_MUTABLE"


def test_manifest_tamper_and_unsigned_execution_fail_closed(tmp_path: Path) -> None:
    source = _source_tree(tmp_path)
    manifest = contract.build_archive_manifest(source, runner_identity="TEST\\Runner")
    tampered = json.loads(json.dumps(manifest))
    tampered["files"][0]["size"] += 1
    with pytest.raises(contract.CustomHistoryContractError, match="content hash mismatch"):
        contract.validate_manifest(tampered)
    with pytest.raises(contract.CustomHistoryContractError, match="OWNER approval"):
        contract.validate_manifest(manifest, require_owner_approval=True)
    closed_window = _approval(manifest)
    closed_window["window_end_utc"] = "2021-01-01T00:00:00+00:00"
    with pytest.raises(contract.CustomHistoryContractError, match="window is not open"):
        contract.require_owner_window_open(closed_window)


def test_acl_tool_removes_and_rejects_runner_archive_deny() -> None:
    script = (Path(migration.__file__).with_name("custom_history_acl.ps1")).read_text(
        encoding="utf-8-sig"
    )
    assert "RemoveAccessRuleSpecific" in script
    assert "RUNNER_WRITE_DELETE_DENY_PRESENT" in script
    assert "ACL_DENY_REMOVED" in script
    assert ".SetAccessRule($denyRule)" not in script
    assert "WRITE_DELETE_DENY_MISSING" not in script


def test_stage_is_dry_by_default_and_execute_builds_private_mutable_files(
    tmp_path: Path,
) -> None:
    source, manifest, manifest_path, owner_path = _approved_files(tmp_path)
    mt5_root = tmp_path / "mt5"
    farm_root = tmp_path / "farm"
    receipt_path = tmp_path / "stage-receipt.json"
    acl_evidence = tmp_path / "acl-evidence.json"

    plan = migration.stage_variant_a(
        manifest_path=manifest_path,
        owner_receipt_path=owner_path,
        mt5_root=mt5_root,
        farm_root=farm_root,
        receipt_path=receipt_path,
        acl_evidence_path=acl_evidence,
        execute=False,
    )
    assert plan["runtime_action"] == "NONE"
    assert not migration.staging_path(mt5_root, "T2", _approval(manifest)["window_id"]).exists()

    def fake_acl(**kwargs):
        kwargs["evidence_path"].write_text('{"status":"PASS"}\n', encoding="utf-8")
        return {"status": "PASS"}

    mode = lease.build_mode_receipt(
        enabled=True,
        reason="staging-test",
        source="unit-test",
        authorization_sha256="a" * 64,
    )
    lease.write_mode(farm_root, mode)
    (farm_root / "state" / "FACTORY_OFF.flag").write_text("test\n", encoding="utf-8")
    quiescent = lambda **kwargs: {
        "quiescent": True,
        "active_work_items": [],
        "runner_processes": [],
    }

    receipt = migration.stage_variant_a(
        manifest_path=manifest_path,
        owner_receipt_path=owner_path,
        mt5_root=mt5_root,
        farm_root=farm_root,
        receipt_path=receipt_path,
        acl_evidence_path=acl_evidence,
        execute=True,
        acl_runner=fake_acl,
        quiescence_probe=quiescent,
    )
    assert receipt["schema_version"] == migration.STAGE_RECEIPT_SCHEMA
    archive_rel = "history/EURUSD.DWX/2025.hcc"
    mutable_rel = "history/EURUSD.DWX/2026.hcc"
    archive_ids = set()
    mutable_ids = set()
    for terminal in contract.DEFAULT_RUNNER_TERMINALS:
        stage = migration.staging_path(mt5_root, terminal, _approval(manifest)["window_id"])
        archive_ids.add(contract.file_identity(stage.joinpath(*archive_rel.split("/")))["file_id"])
        mutable_ids.add(contract.file_identity(stage.joinpath(*mutable_rel.split("/")))["file_id"])
    assert archive_ids == {manifest["files"][0]["file_id"]}
    assert len(mutable_ids) == len(contract.DEFAULT_RUNNER_TERMINALS)
    verification = migration.verify_staging(
        manifest=manifest,
        mt5_root=mt5_root,
        window_id=_approval(manifest)["window_id"],
        acl_probe=lambda path, identity: {"write_denied": True},
    )
    assert verification["status"] == "PASS_ISOLATED", verification["findings"]
    assert source.is_dir()


def test_containment_lease_requires_reconcile_before_stale_release(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    mode = lease.build_mode_receipt(
        enabled=True,
        reason="test",
        source="unit-test",
        authorization_sha256="b" * 64,
    )
    lease.write_mode(root, mode)
    identity = {"creation_key": "proc-a", "image_path": "python"}
    first = lease.acquire_lease(
        root,
        terminal="T1",
        reconcile_stale=lambda record: {"terminal_inactive": True, "claim_reconciled": True},
        owner_identity=identity,
    )
    assert first.acquired and first.handle is not None
    second = lease.acquire_lease(
        root,
        terminal="T2",
        reconcile_stale=lambda record: {"terminal_inactive": True, "claim_reconciled": True},
        owner_identity={"creation_key": "proc-b", "image_path": "python"},
    )
    assert not second.acquired
    first.handle.abandon_for_test()

    refused = lease.acquire_lease(
        root,
        terminal="T2",
        reconcile_stale=lambda record: {"terminal_inactive": True, "claim_reconciled": False},
        owner_identity={"creation_key": "proc-b", "image_path": "python"},
        owner_state=lambda record: "absent",
    )
    assert refused.reason == "stale_lease_not_reconciled"
    recovered = lease.acquire_lease(
        root,
        terminal="T2",
        reconcile_stale=lambda record: {"terminal_inactive": True, "claim_reconciled": True},
        owner_identity={"creation_key": "proc-b", "image_path": "python"},
        owner_state=lambda record: "absent",
    )
    assert recovered.acquired and recovered.handle is not None
    assert recovered.handle.release() == "released"


def test_ramp_contract_allows_only_governed_steps(monkeypatch) -> None:
    activation = {"activation_sha256": "e" * 64}
    monkeypatch.setattr(gate, "validate_activation", lambda payload: dict(payload))
    receipt = gate.build_ramp(
        activation=activation,
        limit=5,
        reason="step_5_after_step_2_receipt_pass",
    )
    assert gate.validate_ramp(receipt, activation=activation)["limit"] == 5
    with pytest.raises(gate.CustomHistoryGateError, match="1,2,5,10"):
        gate.build_ramp(activation=activation, limit=3, reason="invalid")


def test_activation_binds_two_full_audits_acl_receipts_ramp_and_rollback(
    tmp_path: Path,
) -> None:
    _, manifest, manifest_path, owner_path = _approved_files(tmp_path)
    audit_paths = []
    for number in (1, 2):
        acl_path = tmp_path / f"acl-{number}.json"
        acl_path.write_text(
            json.dumps(
                {
                    "schema_version": "qm.custom-history-archive-acl/v1",
                    "mode": "VERIFY",
                    "status": "PASS",
                    "manifest_sha256": manifest["manifest_sha256"],
                    "runner_identity": manifest["runner_identity"],
                    "runner_sid": "S-1-5-21-test",
                    "archive_file_count": manifest["file_count"],
                    "verified": manifest["file_count"],
                    "failures": [],
                }
            ),
            encoding="utf-8",
        )
        audit = {
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
                "manifest_sha256": manifest["manifest_sha256"],
                "archive_hash_verification": "FULL",
            },
            "archive_acl_evidence": {
                "path": str(acl_path),
                "file_sha256": contract.sha256_file(acl_path),
            },
        }
        audit["audit_sha256"] = hashlib.sha256(
            contract.canonical_bytes(audit)
        ).hexdigest()
        path = tmp_path / f"audit-{number}.json"
        path.write_text(json.dumps(audit), encoding="utf-8")
        audit_paths.append(path)
    activation = gate.build_activation(
        manifest_path=manifest_path,
        owner_window_receipt_path=owner_path,
        protected_roots=gate.mt5_history_isolation.DEFAULT_PROTECTED_ROOTS,
        dual_audit_paths=audit_paths,
    )
    farm_root = tmp_path / "farm"
    gate.write_activation(farm_root, activation)
    assert gate.load_activation(farm_root)["activation_sha256"] == activation["activation_sha256"]
    initial_hold = gate.run_worker_gate(farm_root, terminal="T1", mt5_root=tmp_path / "mt5")
    assert initial_hold["admission_allowed"] is False
    assert initial_hold["reason"] == "custom_history_ramp_not_initialized"

    ramp = gate.build_ramp(activation=activation, limit=1, reason="start")
    gate.write_ramp(farm_root, ramp, activation=activation)
    assert gate.load_ramp(farm_root, activation=activation)["limit"] == 1

    rollback_receipt = tmp_path / "rollback.json"
    rollback_receipt.write_text('{"status":"ROLLED_BACK"}\n', encoding="utf-8")
    rollback_mode = gate.build_rollback_mode(
        activation=activation,
        rollback_receipt_path=rollback_receipt,
        owner_receipt_path=owner_path,
    )
    gate.write_rollback_mode(farm_root, rollback_mode, activation=activation)
    assert gate.load_rollback_mode(
        farm_root, activation=activation
    )["dispatch_contract"] == "GLOBAL_CONTAINMENT_LEASE_REQUIRED"


def test_cutover_and_rollback_are_rename_only_and_retain_both_trees(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _, manifest, manifest_path, owner_path = _approved_files(tmp_path)
    mt5_root = tmp_path / "mt5"
    farm_root = tmp_path / "farm"
    (farm_root / "state").mkdir(parents=True)
    with sqlite3.connect(farm_root / "state" / "farm_state.sqlite") as conn:
        conn.execute("CREATE TABLE work_items(id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, claimed_by TEXT, status TEXT)")
    mode = lease.build_mode_receipt(
        enabled=True,
        reason="migration",
        source="unit-test",
        authorization_sha256="c" * 64,
    )
    lease.write_mode(farm_root, mode)
    (farm_root / "state" / "FACTORY_OFF.flag").write_text("test\n", encoding="utf-8")
    for terminal in contract.DEFAULT_RUNNER_TERMINALS[1:]:
        (migration.custom_path(mt5_root, terminal)).mkdir(parents=True)

    def fake_acl(**kwargs):
        kwargs["evidence_path"].write_text('{"status":"PASS"}\n', encoding="utf-8")
        return {"status": "PASS"}

    migration.stage_variant_a(
        manifest_path=manifest_path,
        owner_receipt_path=owner_path,
        mt5_root=mt5_root,
        farm_root=farm_root,
        receipt_path=tmp_path / "stage.json",
        acl_evidence_path=tmp_path / "acl.json",
        execute=True,
        acl_runner=fake_acl,
        quiescence_probe=lambda **kwargs: {
            "quiescent": True,
            "active_work_items": [],
            "runner_processes": [],
        },
    )
    monkeypatch.setattr(
        migration,
        "verify_staging",
        lambda **kwargs: {"status": "PASS_ISOLATED", "verification_sha256": "d" * 64},
    )
    quiescent = lambda **kwargs: {"quiescent": True, "active_work_items": [], "runner_processes": []}
    real_rename = Path.rename
    rename_calls = 0

    def interrupt_second_rename(path: Path, target: Path) -> Path:
        nonlocal rename_calls
        rename_calls += 1
        if rename_calls == 2:
            raise OSError("simulated cutover interruption")
        return real_rename(path, target)

    monkeypatch.setattr(Path, "rename", interrupt_second_rename)
    with pytest.raises(OSError, match="simulated cutover interruption"):
        migration.cutover_variant_a(
            manifest_path=manifest_path,
            owner_receipt_path=owner_path,
            mt5_root=mt5_root,
            farm_root=farm_root,
            db_backup_path=tmp_path / "farm-backup.sqlite",
            receipt_path=tmp_path / "cutover.json",
            execute=True,
            quiescence_probe=quiescent,
        )
    monkeypatch.setattr(Path, "rename", real_rename)
    cutover = migration.cutover_variant_a(
        manifest_path=manifest_path,
        owner_receipt_path=owner_path,
        mt5_root=mt5_root,
        farm_root=farm_root,
        db_backup_path=tmp_path / "farm-backup.sqlite",
        receipt_path=tmp_path / "cutover.json",
        execute=True,
        quiescence_probe=quiescent,
    )
    assert cutover["rollback_retained"] is True
    window_id = _approval(manifest)["window_id"]
    for terminal in contract.DEFAULT_RUNNER_TERMINALS:
        assert migration.custom_path(mt5_root, terminal).is_dir()
        assert migration.rollback_path(mt5_root, terminal, window_id).exists()

    rename_calls = 0

    def interrupt_second_rollback_rename(path: Path, target: Path) -> Path:
        nonlocal rename_calls
        rename_calls += 1
        if rename_calls == 2:
            raise OSError("simulated rollback interruption")
        return real_rename(path, target)

    monkeypatch.setattr(Path, "rename", interrupt_second_rollback_rename)
    with pytest.raises(OSError, match="simulated rollback interruption"):
        migration.rollback_variant_a(
            manifest_path=manifest_path,
            owner_receipt_path=owner_path,
            mt5_root=mt5_root,
            farm_root=farm_root,
            receipt_path=tmp_path / "rollback.json",
            execute=True,
            quiescence_probe=quiescent,
        )
    monkeypatch.setattr(Path, "rename", real_rename)
    rollback = migration.rollback_variant_a(
        manifest_path=manifest_path,
        owner_receipt_path=owner_path,
        mt5_root=mt5_root,
        farm_root=farm_root,
        receipt_path=tmp_path / "rollback.json",
        execute=True,
        quiescence_probe=quiescent,
    )
    assert rollback["failure_analysis_retained"] is True
    for terminal in contract.DEFAULT_RUNNER_TERMINALS:
        assert migration.custom_path(mt5_root, terminal).is_dir()
        assert migration.failed_path(mt5_root, terminal, window_id).exists()


def test_worker_gate_reaudits_pure_link_count_races(monkeypatch, tmp_path: Path) -> None:
    activation = {
        "runner_terminals": ["T1", "T2"],
        "protected_roots": [],
        "manifest_path": str(tmp_path / "manifest.json"),
        "activation_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
    }
    monkeypatch.setattr(gate, "load_activation", lambda root: activation)
    monkeypatch.setattr(gate, "load_rollback_mode", lambda root, activation: None)
    monkeypatch.setattr(
        gate,
        "load_ramp",
        lambda root, activation: {
            "terminal_order": ["T1", "T2"],
            "limit": 2,
            "ramp_sha256": "c" * 64,
        },
    )
    monkeypatch.setattr(gate.time, "sleep", lambda seconds: None)

    torn = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "ARCHIVE_LINK_COUNT_TOO_LOW",
                    "terminal": "T2",
                    "relative_path": "history/XAUUSD.DWX/2017.hcc",
                    "actual": 6,
                    "minimum": 7,
                }
            ]
        },
    }
    clean = {
        "status": "PASS_ISOLATED",
        "audit_sha256": "e" * 64,
        "findings": [],
        "variant_a_file_audit": {"findings": []},
    }
    results = [dict(torn), dict(clean)]
    calls = []
    monkeypatch.setattr(
        gate.mt5_history_isolation,
        "audit_history_isolation",
        lambda **kwargs: (calls.append(kwargs), results.pop(0))[1],
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "PASS_ISOLATED"
    assert len(calls) == 2


def test_worker_gate_persistent_link_deficit_stays_fail_closed(
    monkeypatch, tmp_path: Path
) -> None:
    activation = {
        "runner_terminals": ["T1"],
        "protected_roots": [],
        "manifest_path": str(tmp_path / "manifest.json"),
        "activation_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
    }
    monkeypatch.setattr(gate, "load_activation", lambda root: activation)
    monkeypatch.setattr(gate, "load_rollback_mode", lambda root, activation: None)
    monkeypatch.setattr(
        gate,
        "load_ramp",
        lambda root, activation: {
            "terminal_order": ["T1"],
            "limit": 1,
            "ramp_sha256": "c" * 64,
        },
    )
    monkeypatch.setattr(gate.time, "sleep", lambda seconds: None)

    torn = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "ARCHIVE_LINK_COUNT_TOO_LOW",
                    "terminal": "T1",
                    "relative_path": "history/XAUUSD.DWX/2017.hcc",
                    "actual": 5,
                    "minimum": 7,
                }
            ]
        },
    }
    calls = []
    monkeypatch.setattr(
        gate.mt5_history_isolation,
        "audit_history_isolation",
        lambda **kwargs: (calls.append(kwargs), dict(torn))[1],
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "FAIL_CLOSED"
    assert len(calls) == 3


def test_worker_gate_mixed_findings_do_not_retry(monkeypatch, tmp_path: Path) -> None:
    activation = {
        "runner_terminals": ["T1"],
        "protected_roots": [],
        "manifest_path": str(tmp_path / "manifest.json"),
        "activation_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
    }
    monkeypatch.setattr(gate, "load_activation", lambda root: activation)
    monkeypatch.setattr(gate, "load_rollback_mode", lambda root, activation: None)
    monkeypatch.setattr(
        gate,
        "load_ramp",
        lambda root, activation: {
            "terminal_order": ["T1"],
            "limit": 1,
            "ramp_sha256": "c" * 64,
        },
    )

    deleted = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": "T1",
                    "relative_path": "history/XAUUSD.DWX/2017.hcc",
                },
                {
                    "code": "ARCHIVE_LINK_COUNT_TOO_LOW",
                    "terminal": "T1",
                    "relative_path": "history/XAUUSD.DWX/2018.hcc",
                    "actual": 6,
                    "minimum": 7,
                },
            ]
        },
    }
    calls = []
    monkeypatch.setattr(
        gate.mt5_history_isolation,
        "audit_history_isolation",
        lambda **kwargs: (calls.append(kwargs), dict(deleted))[1],
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "FAIL_CLOSED"
    assert len(calls) == 1
