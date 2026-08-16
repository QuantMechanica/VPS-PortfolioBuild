from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import custom_history_contract as contract
from tools.strategy_farm import farmctl


def _approved_xti_manifest(tmp_path: Path) -> dict:
    source = tmp_path / "source" / "Custom"
    for relative, body in {
        "history/XTIUSD.DWX/2025.hcc": b"xti-archive-bars",
        "ticks/XTIUSD.DWX/202501.tkc": b"xti-archive-ticks",
    }.items():
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
    return contract.attach_owner_approval(draft, approval)


def _active_metadata(manifest: dict) -> dict:
    return {
        "required": True,
        "status": "ACTIVE",
        "activation_sha256": "c" * 64,
        "manifest_path": "D:/fixture/archive_manifest_owner_approved.json",
        "manifest_sha256": manifest["manifest_sha256"],
    }


def test_admission_refuses_uncovered_member_of_logical_basket(
    tmp_path: Path,
) -> None:
    manifest = _approved_xti_manifest(tmp_path)
    admission = farmctl.custom_history_archive_admission(
        tmp_path / "farm",
        ea_id="QM5_99001",
        symbols=["QM5_99001_XTI_XCU_BASKET_D1"],
        basket_manifest={
            "host_symbol": "XTIUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["XTIUSD.DWX", "XCUUSD.DWX"],
        },
        archive_manifest=manifest,
        activation_metadata=_active_metadata(manifest),
    )

    assert admission["ok"] is False
    assert admission["status"] == "FAIL"
    assert admission["reason"] == (
        farmctl.CUSTOM_HISTORY_ARCHIVE_COVERAGE_MISSING
    )
    assert admission["missing_symbols"] == ["XCUUSD.DWX"]
    assert admission["requested_symbols"] == [
        "QM5_99001_XTI_XCU_BASKET_D1",
        "XTIUSD.DWX",
        "XCUUSD.DWX",
    ]
    assert admission["manifest_sha256"] == manifest["manifest_sha256"]


def test_auto_q02_enqueue_writes_no_row_when_basket_archive_is_uncovered(
    tmp_path: Path,
    monkeypatch,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    ea_id = "QM5_99001"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_xti-xcu"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    logical_symbol = "QM5_99001_XTI_XCU_BASKET_D1"
    basket_manifest = {
        "logical_symbol": logical_symbol,
        "host_symbol": "XTIUSD.DWX",
        "host_timeframe": "D1",
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "basket_symbols": ["XTIUSD.DWX", "XCUUSD.DWX"],
    }
    (ea_dir / "basket_manifest.json").write_text(
        json.dumps(basket_manifest), encoding="utf-8"
    )
    setfile = sets_dir / f"{ea_dir.name}_{logical_symbol}_D1_backtest.set"
    setfile.write_text("; fabricated uncovered basket\n", encoding="utf-8")

    manifest = _approved_xti_manifest(tmp_path)
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo_root)
    monkeypatch.setattr(
        farmctl,
        "_load_active_custom_history_archive_manifest",
        lambda _root: (manifest, _active_metadata(manifest)),
    )
    farmctl.init_db(farm_root)

    result = farmctl._auto_enqueue_q02_for_build(
        farm_root,
        {
            "task_id": "build-test",
            "ea_id": ea_id,
            "setfiles_generated": [str(setfile)],
        },
    )

    assert result["enqueued"] == []
    assert result["custom_history_archive_admission"]["reason"] == (
        farmctl.CUSTOM_HISTORY_ARCHIVE_COVERAGE_MISSING
    )
    assert result["custom_history_archive_admission"]["missing_symbols"] == [
        "XCUUSD.DWX"
    ]
    assert result["skipped"][0]["reason"] == (
        farmctl.CUSTOM_HISTORY_ARCHIVE_COVERAGE_MISSING
    )
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0


def test_card_approval_refuses_uncovered_declared_symbol(
    tmp_path: Path,
    monkeypatch,
) -> None:
    farm_root = tmp_path / "farm"
    card = tmp_path / "QM5_99001_xti-xcu_card.md"
    original = "Target symbols: XTIUSD.DWX, XCUUSD.DWX\n"
    card.write_text(original, encoding="utf-8")
    manifest = _approved_xti_manifest(tmp_path)
    monkeypatch.setattr(
        farmctl,
        "_load_active_custom_history_archive_manifest",
        lambda _root: (manifest, _active_metadata(manifest)),
    )
    monkeypatch.setattr(
        farmctl,
        "parse_card_frontmatter",
        lambda _path: {"ea_id": "QM5_99001"},
    )
    monkeypatch.setattr(
        farmctl,
        "strategy_card_r_gate_consistency",
        lambda _path, _fm: {"ok": True, "errors": []},
    )
    monkeypatch.setattr(
        farmctl,
        "_approval_card_contract_issues",
        lambda _path, _fm: [],
    )
    monkeypatch.setattr(
        farmctl,
        "_verify_card_body_coverage",
        lambda _path: {"ok": True, "missing": []},
    )
    monkeypatch.setattr(
        farmctl,
        "_infer_expected_trades_per_year_per_symbol",
        lambda _text: 12,
    )

    result = farmctl.approve_card(farm_root, str(card), "fixture approval")

    assert result["approved"] is False
    assert result["reason"] == farmctl.CUSTOM_HISTORY_ARCHIVE_COVERAGE_MISSING
    assert result["missing_symbols"] == ["XCUUSD.DWX"]
    assert card.read_text(encoding="utf-8") == original


def test_prebuild_validation_reports_uncovered_declared_symbol(
    tmp_path: Path,
    monkeypatch,
) -> None:
    farm_root = tmp_path / "farm"
    approved = farm_root / "artifacts" / "cards_approved"
    approved.mkdir(parents=True)
    card = approved / "QM5_99001_xti-xcu_card.md"
    card.write_text(
        "Target symbols: XTIUSD.DWX, XCUUSD.DWX\n",
        encoding="utf-8",
    )
    manifest = _approved_xti_manifest(tmp_path)
    monkeypatch.setattr(farmctl, "REPO_ROOT", tmp_path / "repo")
    monkeypatch.setattr(
        farmctl,
        "_load_active_custom_history_archive_manifest",
        lambda _root: (manifest, _active_metadata(manifest)),
    )
    monkeypatch.setattr(
        farmctl,
        "strategy_card_r_gate_consistency",
        lambda _path, _fm: {"ok": True, "errors": [], "warnings": []},
    )

    result = farmctl.prebuild_validate_card(
        farm_root,
        card,
        {
            "ea_id": "QM5_99001",
            "slug": "xti-xcu",
            "g0_status": "APPROVED",
            "source_id": "fixture-source",
            "r2_mechanical": "PASS",
            "r3_data_available": "PASS",
            "r4_ml_forbidden": "PASS",
            "expected_trades_per_year_per_symbol": "12",
        },
    )

    assert result["ok"] is False
    assert result["custom_history_archive_admission"]["missing_symbols"] == [
        "XCUUSD.DWX"
    ]
    assert (
        "custom_history_manifest_archive_coverage_missing:XCUUSD.DWX"
        in result["errors"]
    )
