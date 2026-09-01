from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from tools.strategy_farm import apply_dl082_ext_option_d_regrade as regrade


def _eligible_source() -> dict:
    return {
        "evidence_schema": "q08_aggregate/v2",
        "ea_id": 12345,
        "symbol": "EURUSD.DWX",
        "phase": "Q08",
        "verdict": "FAIL_HARD",
        "verdict_classification": {
            "8.2_dsr_mc_fdr": "PASS",
            "8.5_neighborhood": "EDGE_HARD",
            "8.7_pbo": "EDGE_SOFT",
            "8.8_edge_decay": "PASS",
            "8.9_runs_test": "PASS",
            "cost_cushion": "PASS",
        },
        "cost_cushion_tier": "PASS",
        "sub_gates": [{"name": "8.5_neighborhood", "status": "FAIL"}],
        "baseline_run": {"period": "H4"},
        "generated_at_utc": "2026-07-01T00:00:00+00:00",
        "verdict_calibration": {"UNCHANGED_THRESHOLD": 7},
    }


def _target() -> dict:
    return {
        "source_work_item_id": "source-id",
        "source_work_item_row_sha256": "1" * 64,
        "source_snapshot": {
            "path": "source.json.gz",
            "storage": "gzip",
            "storage_sha256": "2" * 64,
            "json_bytes_sha256": "3" * 64,
            "verdict": "FAIL_HARD",
            "verdict_classification_sha256": "4" * 64,
        },
        "new_work_item_id": "new-id",
        "runnable_binding": {
            "setfile_path": "x.set",
            "setfile_sha256": "5" * 64,
            "mq5_path": "x.mq5",
            "mq5_sha256": "6" * 64,
            "ex5_path": "x.ex5",
            "ex5_sha256": "7" * 64,
            "expert": "QM\\x",
            "risk_fixed": 1000.0,
            "risk_percent": 0.0,
            "qm_news_stale_max_hours": 336.0,
            "period": "H4",
        },
    }


def _authority() -> dict:
    return {
        "decision_record_sha256": "8" * 64,
        "decision_doc_sha256": "9" * 64,
    }


def test_static_manifest_is_exactly_thirteen_unique_pairs() -> None:
    scope = [(source, ea, symbol) for source, ea, symbol, _path in regrade.TARGETS]
    pairs = {(ea, symbol) for _source, ea, symbol in scope}
    assert len(scope) == 13
    assert len(pairs) == 13
    assert pairs == {
        ("QM5_11421", "AUDUSD.DWX"),
        ("QM5_1567", "GBPJPY.DWX"),
        ("QM5_1567", "GBPNZD.DWX"),
        ("QM5_1567", "XAGUSD.DWX"),
        ("QM5_12552", "USDCAD.DWX"),
        ("QM5_1551", "USDJPY.DWX"),
        ("QM5_10569", "XAUUSD.DWX"),
        ("QM5_11403", "EURUSD.DWX"),
        ("QM5_1355", "NDX.DWX"),
        ("QM5_11294", "NDX.DWX"),
        ("QM5_12474", "GBPUSD.DWX"),
        ("QM5_10715", "USDJPY.DWX"),
        ("QM5_10476", "USDCAD.DWX"),
    }
    ids = {regrade.new_work_item_id(ea, symbol) for ea, symbol in pairs}
    assert len(ids) == 13


def test_regrade_clones_measurement_and_changes_only_calibration_verdict_fields() -> None:
    source = _eligible_source()
    before = copy.deepcopy(source)
    result = regrade.build_regrade_aggregate(
        source,
        target=_target(),
        authority=_authority(),
        generated_at_utc="2026-09-01T18:00:00+00:00",
    )
    assert source == before
    assert result["verdict"] == "FAIL_SOFT"
    assert result["verdict_classification"] == source["verdict_classification"]
    assert result["sub_gates"] == source["sub_gates"]
    assert result["baseline_run"] == source["baseline_run"]
    assert result["dl082_ext_option_d"] is True
    assert "DL082_EXT_OPTION_D_APPLIED" in result["dl082_ext_option_d_reason_codes"]
    assert result["dl082_ext_regrade"]["mt5_rerun_performed"] is False
    assert result["dl082_ext_regrade"]["historical_verdict_preserved"] is True
    assert result["dl082_ext_regrade"]["q09_eligibility"] == {
        "gate_contract_version": "v4",
        "source_phase": "Q08",
        "source_status": "done",
        "source_verdict": "FAIL_SOFT",
        "existing_admission_verdict": "FAIL_SOFT",
        "next_phase": "Q09",
        "enqueued": False,
    }
    assert result["verdict_calibration"]["UNCHANGED_THRESHOLD"] == 7


def test_regrade_fails_closed_for_invalid_pbo() -> None:
    source = _eligible_source()
    source["verdict_classification"]["8.7_pbo"] = "INVALID"
    with pytest.raises(regrade.RegradeError, match="selected_snapshot_not_option_d"):
        regrade.build_regrade_aggregate(
            source,
            target=_target(),
            authority=_authority(),
            generated_at_utc="2026-09-01T18:00:00+00:00",
        )


def test_row_payload_binds_v4_fail_soft_admission_without_enqueue() -> None:
    target = _target()
    target.update({
        "source_work_item_id": "source-id",
        "source_work_item_row_sha256": "1" * 64,
        "source_snapshot": _target()["source_snapshot"],
        "symbol": "EURUSD.DWX",
    })
    payload = regrade._row_payload(target, plan_sha256="a" * 64)
    assert payload["phase"] == "Q08"
    assert payload["gate_contract_version"] == "v4"
    assert payload["q09_eligibility"]["existing_q08_admission_verdict"] == "FAIL_SOFT"
    assert payload["q09_eligibility"]["next_phase"] == "Q09"
    assert payload["q09_eligibility"]["eligible"] is True
    assert payload["q09_eligibility"]["enqueued"] is False


def _make_runnable(tmp_path: Path, set_body: str) -> Path:
    ea_dir = tmp_path / "QM5_12345_test"
    sets = ea_dir / "sets"
    sets.mkdir(parents=True)
    (ea_dir / "QM5_12345_test.mq5").write_text("source", encoding="utf-8")
    (ea_dir / "QM5_12345_test.ex5").write_bytes(b"binary")
    setfile = sets / "QM5_12345_test_EURUSD.DWX_H4_backtest.set"
    setfile.write_text(set_body, encoding="utf-8")
    return setfile


def test_runnable_binding_enforces_risk_and_news_ceiling(tmp_path: Path) -> None:
    setfile = _make_runnable(
        tmp_path,
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=336\n",
    )
    binding = regrade.runnable_binding(setfile)
    assert binding["risk_fixed"] == 1000
    assert binding["risk_percent"] == 0
    assert binding["qm_news_stale_max_hours"] == 336

    setfile.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=1\nqm_news_stale_max_hours=336\n",
        encoding="utf-8",
    )
    with pytest.raises(regrade.RegradeError, match="fixed_risk_contract_violation"):
        regrade.runnable_binding(setfile)

    setfile.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=337\n",
        encoding="utf-8",
    )
    with pytest.raises(regrade.RegradeError, match="news_stale_ceiling_above_336"):
        regrade.runnable_binding(setfile)


def test_receipt_manifest_has_exactly_eight_multicause_snapshots() -> None:
    assert len(regrade.MULTICAUSE_SNAPSHOTS) == 8
    assert len({str(path) for path in regrade.MULTICAUSE_SNAPSHOTS}) == 8
    assert regrade.EURGBP_EXCLUSION[1:3] == ("QM5_1567", "EURGBP.DWX")
