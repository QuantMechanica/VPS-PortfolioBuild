"""DL-085: verified master tree, repair-first gate, master-sourced privatization."""
from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm import custom_history_contract as contract
from tools.strategy_farm import custom_history_copy_on_claim as copy_on_claim
from tools.strategy_farm import custom_history_gate as gate
from tools.strategy_farm import custom_history_master as master


def _approved_manifest(tmp_path: Path) -> tuple[Path, dict]:
    source = tmp_path / "source" / "Custom"
    files = {
        "history/EURUSD.DWX/2025.hcc": b"eur-archive-bars",
        "ticks/EURUSD.DWX/202501.tkc": b"eur-archive-ticks",
        "history/GBPUSD.DWX/2025.hcc": b"gbp-archive-bars",
        "ticks/GBPUSD.DWX/202501.tkc": b"gbp-archive-ticks",
    }
    for relative, body in files.items():
        path = source.joinpath(*relative.split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    draft = contract.build_archive_manifest(
        source,
        runner_identity="TEST\\Runner",
        created_at_utc="2026-08-09T00:00:00+00:00",
    )
    approval = {
        "schema_version": contract.OWNER_APPROVAL_SCHEMA,
        "authority": "OWNER",
        "signed_by": "test-owner",
        "signed_at_utc": "2026-08-09T01:00:00+00:00",
        "signature": "TEST-SIGNATURE",
        "manifest_sha256": draft["manifest_sha256"],
        "decision_sha256": "a" * 64,
        "window_id": "custom_history_variant_a_20260809",
        "window_start_utc": "2026-08-09T00:00:00+00:00",
        "window_end_utc": "2099-08-09T22:00:00+00:00",
        "variant": "A",
        "terminals": list(contract.DEFAULT_RUNNER_TERMINALS),
        "rollback_authorized": True,
        "implementation_git_commit": "b" * 40,
        "claude_review_task_id": "review-test",
        "claude_review_verdict": "APPROVED",
        "claude_reviewed_at_utc": "2026-08-09T00:30:00+00:00",
    }
    return source, contract.attach_owner_approval(draft, approval)


def _fan_out(mt5_root: Path, source: Path, manifest: dict) -> None:
    for terminal in contract.DEFAULT_RUNNER_TERMINALS:
        custom = mt5_root / terminal / "Bases" / "Custom"
        for row in manifest["files"]:
            relative = str(row["relative_path"])
            target = custom.joinpath(*relative.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            os.link(source.joinpath(*relative.split("/")), target)


def _build_master(tmp_path: Path, source: Path, manifest: dict) -> tuple[Path, Path]:
    """Copy the source tree into a standalone master and bind the state file."""
    farm_root = tmp_path / "farm"
    master_root = tmp_path / "archive" / "Custom_master"
    for row in manifest["files"]:
        relative = str(row["relative_path"])
        dst = master_root.joinpath(*relative.split("/"))
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(source.joinpath(*relative.split("/")).read_bytes())
    state = master.master_state_path(farm_root)
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(
        json.dumps(
            {
                "schema": master.MASTER_STATE_SCHEMA,
                "master_root": str(master_root),
                "manifest_sha256": manifest["manifest_sha256"],
            }
        ),
        encoding="utf-8",
    )
    return farm_root, master_root


def _finding(terminal: str, relative: str, code: str = "MANIFEST_ARCHIVE_FILE_MISSING") -> dict:
    return {"code": code, "terminal": terminal, "relative_path": relative}


# ---------------------------------------------------------------- master unit


def test_load_master_state_binds_manifest(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    farm_root, master_root = _build_master(tmp_path, source, manifest)
    loaded = master.load_master_state(farm_root, manifest=manifest)
    assert loaded["master_root"] == master_root

    with pytest.raises(master.CustomHistoryMasterError):
        master.load_master_state(farm_root, manifest={"manifest_sha256": "f" * 64})


def test_repair_restores_missing_file_with_receipt(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    farm_root, _ = _build_master(tmp_path, source, manifest)
    row = next(r for r in manifest["files"] if "EURUSD" in r["relative_path"] and r["relative_path"].startswith("history/"))
    victim = mt5_root / "T5" / "Bases" / "Custom" / Path(row["relative_path"])
    victim.unlink()

    result = master.repair_missing_archives(
        farm_root=farm_root,
        mt5_root=mt5_root,
        manifest=manifest,
        findings=[_finding("T5", str(row["relative_path"]))],
        repaired_by="test",
    )

    assert [r["result"] for r in result["repaired"]] == ["REPAIRED_VERIFIED"]
    assert not result["failed"]
    assert contract.sha256_file(victim) == row["sha256"]
    receipts = [
        json.loads(line)
        for line in Path(result["receipts_path"]).read_text(encoding="utf-8").splitlines()
    ]
    assert receipts[-1]["terminal"] == "T5"
    assert receipts[-1]["result"] == "REPAIRED_VERIFIED"
    assert master.count_recent_repairs(farm_root, hours=1.0) == 1

    # concurrent-repair idempotence: a second call finds the file verified
    again = master.repair_missing_archives(
        farm_root=farm_root,
        mt5_root=mt5_root,
        manifest=manifest,
        findings=[_finding("T5", str(row["relative_path"]))],
        repaired_by="test",
    )
    assert [r["result"] for r in again["already_present"]] == ["ALREADY_PRESENT_VERIFIED"]
    assert not again["repaired"] and not again["failed"]


def test_repair_fails_closed_on_master_corruption(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    farm_root, master_root = _build_master(tmp_path, source, manifest)
    row = manifest["files"][0]
    victim = mt5_root / "T2" / "Bases" / "Custom" / Path(row["relative_path"])
    victim.unlink()
    corrupted = master_root.joinpath(*str(row["relative_path"]).split("/"))
    corrupted.write_bytes(b"x" * int(row["size"]))  # size ok, sha wrong

    result = master.repair_missing_archives(
        farm_root=farm_root,
        mt5_root=mt5_root,
        manifest=manifest,
        findings=[_finding("T2", str(row["relative_path"]))],
        repaired_by="test",
    )
    assert len(result["failed"]) == 1
    assert result["failed"][0]["transient_io"] is False
    assert result["failed"][0]["exception_type"] == "CustomHistoryMasterError"
    assert not victim.exists()
    # no stray temp files
    assert not list((mt5_root / "T2").rglob("*.master-repair.*.tmp"))


def test_repair_refuses_non_repairable_codes(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    farm_root, _ = _build_master(tmp_path, source, manifest)
    with pytest.raises(master.CustomHistoryMasterError):
        master.repair_missing_archives(
            farm_root=farm_root,
            mt5_root=tmp_path / "mt5",
            manifest=manifest,
            findings=[_finding("T1", "history/EURUSD.DWX/2025.hcc", code="MUTABLE_FILE_CONFLICT")],
            repaired_by="test",
        )


# ----------------------------------------------------- privatization sourcing


def test_privatize_reads_from_master_when_farm_root_given(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    farm_root, master_root = _build_master(tmp_path, source, manifest)

    receipt = copy_on_claim.privatize_terminal_archives(
        manifest=manifest,
        mt5_root=mt5_root,
        terminal="T3",
        symbols=["EURUSD.DWX"],
        farm_root=farm_root,
    )
    assert receipt["status"] == "PASS_PRIVATIZED"
    assert receipt["privatization_source"] == "master"

    # corrupt master -> privatization of the other symbol must fail closed,
    # proving the data read comes from the master, not the family inode
    row = next(r for r in manifest["files"] if "GBPUSD" in r["relative_path"] and r["relative_path"].startswith("history/"))
    corrupted = master_root.joinpath(*str(row["relative_path"]).split("/"))
    corrupted.write_bytes(b"y" * int(row["size"]))
    with pytest.raises(copy_on_claim.CustomHistoryCopyOnClaimError):
        copy_on_claim.privatize_terminal_archives(
            manifest=manifest,
            mt5_root=mt5_root,
            terminal="T4",
            symbols=["GBPUSD.DWX"],
            farm_root=farm_root,
        )
    # legacy family-inode path (no farm_root) still succeeds for the same claim
    legacy = copy_on_claim.privatize_terminal_archives(
        manifest=manifest,
        mt5_root=mt5_root,
        terminal="T4",
        symbols=["GBPUSD.DWX"],
    )
    assert legacy["privatization_source"] == "family_inode"


def test_privatize_fails_closed_without_master_state(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    with pytest.raises(master.CustomHistoryMasterError):
        copy_on_claim.privatize_terminal_archives(
            manifest=manifest,
            mt5_root=mt5_root,
            terminal="T3",
            symbols=["EURUSD.DWX"],
            farm_root=tmp_path / "farm_without_master",
        )


# ------------------------------------------------------- gate repair-first


def _gate_fixture(monkeypatch, tmp_path: Path, audits: list[dict]) -> list:
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
    monkeypatch.setattr(gate, "load_manifest", lambda path, require_owner_approval: {"files": []})
    calls: list = []
    results = [dict(a) for a in audits]
    monkeypatch.setattr(
        gate.mt5_history_isolation,
        "audit_history_isolation",
        lambda **kwargs: (calls.append(kwargs), results.pop(0))[1],
    )
    return calls


def test_worker_gate_repairs_archive_gap_and_passes(monkeypatch, tmp_path: Path) -> None:
    missing = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": "T2",
                    "relative_path": "history/EURUSD.DWX/2025.hcc",
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
    calls = _gate_fixture(monkeypatch, tmp_path, [missing, clean])
    repair_calls: list = []

    def fake_repair(**kwargs):
        repair_calls.append(kwargs)
        return {
            "repaired": [{"result": "REPAIRED_VERIFIED"}],
            "already_present": [],
            "failed": [],
            "receipts_path": str(tmp_path / "repairs.jsonl"),
        }

    monkeypatch.setattr(gate.custom_history_master, "repair_missing_archives", fake_repair)

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "PASS_ISOLATED"
    assert verdict["master_repair"]["status"] == "REPAIRED"
    assert verdict["master_repair"]["post_repair_status"] == "PASS_ISOLATED"
    assert len(repair_calls) == 1
    assert repair_calls[0]["repaired_by"] == "worker_gate:T1"
    assert len(calls) == 2  # initial audit + post-repair verification


def test_worker_gate_stays_fail_closed_when_repair_fails(monkeypatch, tmp_path: Path) -> None:
    missing = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "TERMINAL_MANIFEST_INCOMPLETE",
                    "terminal": "T2",
                    "relative_path": "history/EURUSD.DWX/2025.hcc",
                }
            ]
        },
    }
    calls = _gate_fixture(monkeypatch, tmp_path, [missing])
    monkeypatch.setattr(
        gate.custom_history_master,
        "repair_missing_archives",
        lambda **kwargs: {
            "repaired": [],
            "already_present": [],
            "failed": [{"result": "FAILED", "error": "master missing"}],
            "receipts_path": str(tmp_path / "repairs.jsonl"),
        },
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "FAIL_CLOSED"
    assert verdict["master_repair"]["status"] == "PARTIAL"
    assert verdict["master_repair"]["failed_count"] == 1
    assert verdict["master_repair"]["failed_transient_io_count"] == 0
    assert len(calls) == 1  # no post-repair audit after a failed repair


def test_worker_gate_reports_partial_transient_io_when_all_failures_transient(
    monkeypatch, tmp_path: Path
) -> None:
    missing = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": "T2",
                    "relative_path": "history/EURUSD.DWX/2025.hcc",
                }
            ]
        },
    }
    calls = _gate_fixture(monkeypatch, tmp_path, [missing])
    monkeypatch.setattr(
        gate.custom_history_master,
        "repair_missing_archives",
        lambda **kwargs: {
            "repaired": [],
            "already_present": [],
            "failed": [
                {
                    "result": "FAILED",
                    "error": "PermissionError(13, 'Permission denied')",
                    "transient_io": True,
                }
            ],
            "receipts_path": str(tmp_path / "repairs.jsonl"),
        },
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")

    assert verdict["status"] == "FAIL_CLOSED"
    assert verdict["master_repair"]["status"] == "PARTIAL_TRANSIENT_IO"
    assert verdict["master_repair"]["failed_transient_io_count"] == 1
    assert len(calls) == 1  # still no post-repair audit; the claim just defers


def test_transient_repair_io_classifier() -> None:
    resource = OSError(22, "Insufficient system resources")
    resource.winerror = 1450
    crc = OSError(23, "Data error (cyclic redundancy check)")
    crc.winerror = 23
    wrapped_vouch = master.CustomHistoryMasterError("sha mismatch")
    wrapped_vouch.__cause__ = PermissionError(13, "Permission denied")

    assert master.is_transient_repair_io_error(PermissionError(13, "denied"))
    assert master.is_transient_repair_io_error(FileNotFoundError(2, "gone"))
    assert master.is_transient_repair_io_error(MemoryError())
    assert master.is_transient_repair_io_error(resource)
    assert not master.is_transient_repair_io_error(crc)
    assert not master.is_transient_repair_io_error(
        master.CustomHistoryMasterError("master file missing")
    )
    # A vouching failure anywhere in the chain always wins over transient IO.
    assert not master.is_transient_repair_io_error(wrapped_vouch)


def test_worker_gate_does_not_repair_foreign_codes(monkeypatch, tmp_path: Path) -> None:
    mixed = {
        "status": "FAIL_CLOSED",
        "audit_sha256": "d" * 64,
        "findings": [],
        "variant_a_file_audit": {
            "findings": [
                {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": "T2",
                    "relative_path": "history/EURUSD.DWX/2025.hcc",
                },
                {
                    "code": "MUTABLE_FILE_CONFLICT",
                    "terminal": "T2",
                    "relative_path": "ticks/EURUSD.DWX/202501.tkc",
                },
            ]
        },
    }
    _gate_fixture(monkeypatch, tmp_path, [mixed])
    monkeypatch.setattr(
        gate.custom_history_master,
        "repair_missing_archives",
        lambda **kwargs: pytest.fail("repair must not run for non-repairable codes"),
    )

    verdict = gate.run_worker_gate(tmp_path, terminal="T1")
    assert verdict["status"] == "FAIL_CLOSED"
    assert "master_repair" not in verdict
