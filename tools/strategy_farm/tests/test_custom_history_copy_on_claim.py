from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm import custom_history_contract as contract
from tools.strategy_farm import custom_history_copy_on_claim as copy_on_claim


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


def test_copy_on_claim_is_scoped_atomic_and_idempotent(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    receipt_path = tmp_path / "receipt.json"

    first = copy_on_claim.privatize_terminal_archives(
        manifest=manifest,
        mt5_root=mt5_root,
        terminal="T3",
        symbols=["EURUSD.DWX", "SYNTHETIC_BASKET"],
        receipt_path=receipt_path,
    )

    assert first["status"] == "PASS_PRIVATIZED"
    assert first["symbols"] == ["EURUSD.DWX"]
    assert first["ignored_non_custom_symbols"] == ["SYNTHETIC_BASKET"]
    assert first["selected_file_count"] == 2
    assert first["copied_file_count"] == 2
    assert first["already_private_file_count"] == 0
    assert json.loads(receipt_path.read_text(encoding="utf-8"))["receipt_sha256"] == first["receipt_sha256"]

    for row in manifest["files"]:
        target = mt5_root / "T3" / "Bases" / "Custom" / Path(row["relative_path"])
        identity = contract.file_identity(target)
        if "EURUSD.DWX" in row["relative_path"]:
            assert identity["file_id"] != row["file_id"]
            assert identity["link_count"] == 1
            assert contract.sha256_file(target) == row["sha256"]
        else:
            assert identity["file_id"] == row["file_id"]
    assert not list((mt5_root / "T3").rglob("*.copy-on-claim.*.tmp"))

    second = copy_on_claim.privatize_terminal_archives(
        manifest=manifest,
        mt5_root=mt5_root,
        terminal="T3",
        symbols=["EURUSD.DWX"],
    )
    assert second["copied_file_count"] == 0
    assert second["already_private_file_count"] == 2


def test_copy_on_claim_refuses_private_sha_mismatch(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)
    row = next(row for row in manifest["files"] if "EURUSD.DWX" in row["relative_path"])
    target = mt5_root / "T4" / "Bases" / "Custom" / Path(row["relative_path"])
    target.unlink()
    target.write_bytes(b"x" * int(row["size"]))

    with pytest.raises(
        copy_on_claim.CustomHistoryCopyOnClaimError,
        match="SHA-256 mismatch after privatization",
    ):
        copy_on_claim.privatize_terminal_archives(
            manifest=manifest,
            mt5_root=mt5_root,
            terminal="T4",
            symbols=["EURUSD.DWX"],
        )


def test_copy_on_claim_refuses_undeclared_custom_symbol(tmp_path: Path) -> None:
    source, manifest = _approved_manifest(tmp_path)
    mt5_root = tmp_path / "mt5"
    _fan_out(mt5_root, source, manifest)

    with pytest.raises(
        copy_on_claim.CustomHistoryCopyOnClaimError,
        match="manifest has no archive rows",
    ):
        copy_on_claim.privatize_terminal_archives(
            manifest=manifest,
            mt5_root=mt5_root,
            terminal="T2",
            symbols=["XAUUSD.DWX"],
        )

