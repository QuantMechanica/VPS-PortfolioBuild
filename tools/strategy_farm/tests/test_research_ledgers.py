"""Tests: search-history + experiment-memory ledgers, projector, preregistration."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import (  # noqa: E402
    experiment_memory,
    observe_projector,
    preregister,
    search_history_ledger,
)
from _research_fixtures import build_fixture_db, build_registry_csv  # noqa: E402


def _search_record(family="trend", holdout="H1", touched=False, campaign="C1"):
    return {
        "campaign_id": campaign,
        "hypothesis_family": family,
        "dataset_id": "sha256:deadbeef",
        "period": "2015-2019",
        "instruments": ["EURUSD.DWX"],
        "feature_families": ["atr", "channel"],
        "parameter_space_size": 42,
        "holdout_id": holdout,
        "holdout_touched": touched,
        "outcome": "no_edge",
    }


# --- search-history ledger ---------------------------------------------------


def test_search_history_append_only_and_family_counts(tmp_path):
    ledger = tmp_path / "search_history_ledger.jsonl"
    search_history_ledger.append_search(ledger, _search_record("trend"))
    search_history_ledger.append_search(ledger, _search_record("trend"))
    search_history_ledger.append_search(ledger, _search_record("breakout"))

    # append-only: three physical lines, none rewritten.
    assert len([ln for ln in ledger.read_text(encoding="utf-8").splitlines() if ln.strip()]) == 3

    counts = search_history_ledger.trials_per_family(ledger)
    assert counts == {"trend": 2, "breakout": 1}
    # The card-intake evidence helper.
    assert search_history_ledger.declared_trial_count_for(ledger, "trend") == 2
    assert search_history_ledger.declared_trial_count_for(ledger, "carry") == 0


def test_search_history_holdout_reuse(tmp_path):
    ledger = tmp_path / "sh.jsonl"
    search_history_ledger.append_search(ledger, _search_record(holdout="H1", touched=True))
    search_history_ledger.append_search(ledger, _search_record(holdout="H1", touched=True))
    search_history_ledger.append_search(ledger, _search_record(holdout="H2", touched=False))
    reuse = search_history_ledger.holdout_reuse_count(ledger)
    assert reuse == {"H1": 2}
    assert search_history_ledger.summarize(ledger)["reused_holdouts"] == ["H1"]


def test_search_history_requires_id_and_fields(tmp_path):
    ledger = tmp_path / "sh.jsonl"
    bad = _search_record()
    bad.pop("campaign_id")  # neither research_id nor campaign_id
    with pytest.raises(ValueError):
        search_history_ledger.append_search(ledger, bad)


# --- preregistration immutability -------------------------------------------


def _prereg_kwargs(spec_path):
    return dict(
        research_id="QM-RESEARCH-2026-0001",
        hypothesis="Robust engines are under-triggered by a too-tight entry filter.",
        mechanical_spec=spec_path,
        parameter_ranges={"channel_len": [10, 80], "atr_len": [5, 30]},
        discovery_sample="2015-2018",
        validation_sample="2019",
        holdout_logic="2020 held out, untouched",
        expected_behaviour="More trades, similar per-trade edge",
        success_criteria="trades/yr >= 5 with PF > 1.1 on holdout",
        failure_criteria="PF < 1.0 or dd > 10% on holdout",
        known_risks=["survivorship", "symbol concentration"],
    )


def test_preregistration_immutable_and_versioned(tmp_path):
    spec = tmp_path / "spec.md"
    spec.write_text("# spec v1\nchannel_len: 10 .. 80\n", encoding="utf-8")
    artifact_dir = tmp_path / "QM-RESEARCH-2026-0001"
    ledger = tmp_path / "research_source_ledger.jsonl"

    record = preregister.build_preregistration(**_prereg_kwargs(spec))
    assert record["version"] == 1
    assert record["parameter_count"] == 2
    written = preregister.write_preregistration(artifact_dir, record, ledger_path=ledger)
    assert Path(written["preregistration_path"]).name == "preregistration.json"

    # check_unchanged holds while the spec is untouched ...
    assert preregister.check_unchanged(record, spec)
    # ... and breaks the moment the spec changes.
    spec.write_text("# spec v2 changed\nchannel_len: 10 .. 120\n", encoding="utf-8")
    assert not preregister.check_unchanged(record, spec)

    # Re-writing version 1 with a different hash is refused (immutability).
    record_v1_mutated = dict(record)
    record_v1_mutated["record_sha256"] = "0" * 64
    with pytest.raises(FileExistsError):
        preregister.write_preregistration(artifact_dir, record_v1_mutated, ledger_path=ledger)

    # A modification mints a NEW version with a parent link.
    v2 = preregister.build_preregistration(parent_version=1, **_prereg_kwargs(spec))
    assert v2["version"] == 2 and v2["parent_version"] == 1
    out2 = preregister.write_preregistration(artifact_dir, v2, ledger_path=ledger)
    assert Path(out2["preregistration_path"]).name == "preregistration.v2.json"

    lineage = json.loads((artifact_dir / "lineage.json").read_text(encoding="utf-8"))
    versions = [v["version"] for v in lineage["versions"]]
    assert versions == [1, 2]
    parents = [v["parent_version"] for v in lineage["versions"]]
    assert parents == [None, 1]

    # The ledger recorded a preregistered status row per version.
    rows = [json.loads(ln) for ln in ledger.read_text(encoding="utf-8").splitlines() if ln.strip()]
    assert [r["status"] for r in rows] == ["preregistered", "preregistered"]
    assert [r["version"] for r in rows] == [1, 2]


# --- experiment-memory ledger + projector -----------------------------------


def test_experiment_memory_append_only(tmp_path):
    ledger = tmp_path / "experiment_memory_ledger.jsonl"
    row = {
        "strategy_id": "uuid-1001",
        "ea_id": "QM5_1001",
        "symbol": "EURUSD.DWX",
        "timeframe": "D1",
        "phase": "Q02",
        "hypothesis": "trend continuation",
        "verdict": "FAIL",
        "verdict_taxonomy": "strategy",
        "reason": "below frequency floor",
        "evidence_path": "D:/QM/reports/work_items/w6/summary.json.gz",
        "work_item_id": "w6",
        "search_history_ref": "C1",
    }
    experiment_memory.append_experiment(ledger, row)
    experiment_memory.append_experiment(ledger, dict(row, work_item_id="w2"))
    read = experiment_memory.read_ledger(ledger)
    assert len(read) == 2
    assert read[0]["schema"] == "qm.experiment_memory/v1"
    assert all("ts_utc" in r for r in read)

    with pytest.raises(ValueError):
        experiment_memory.append_experiment(ledger, {"ea_id": "QM5_1"})


def test_experiment_memory_projector_answers_section19(tmp_path):
    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    manifest = observe_projector.project(db, tmp_path / "ds", registry_path=registry)
    dataset_dir = Path(manifest["dataset_dir"])

    projection = experiment_memory.project(dataset_dir)

    # Q: which ideas repeatedly failed and why (by family + reason class).
    # QM5_1001 (family trend) FAILed on w2 and w6 -> a (trend, FAIL) group, count >= 2.
    repeat = {(r["family"], r["reason_class"]): r for r in projection["repeatedly_failed_ideas"]}
    assert ("trend", "FAIL") in repeat
    assert repeat[("trend", "FAIL")]["count"] == 2
    assert set(repeat[("trend", "FAIL")]["work_item_ids"]) == {"w2", "w6"}

    # Q: redundant families -> trend has two distinct EAs (1001, 1004).
    fams = {r["family"]: r["distinct_ea_count"] for r in projection["redundant_families"]}
    assert fams.get("trend") == 2

    # Q: robust but too inactive -> healthy metrics, trades/yr below the floor.
    inactive_wids = {r["work_item_id"] for r in projection["robust_but_inactive"]}
    assert "w4" in inactive_wids  # 3 trades over 5y = 0.6/yr < 5
    assert "w6" in inactive_wids  # 8 trades over 5y = 1.6/yr < 5
    assert "w1" not in inactive_wids  # 100 trades = active

    # Q: economic-only failures -> healthy risk but a strategy FAIL/ZERO verdict.
    econ_wids = {r["work_item_id"] for r in projection["economic_only_failures"]}
    assert {"w2", "w4", "w6"} <= econ_wids

    # INFRA rows never leak into an economic answer.
    all_econ = inactive_wids | econ_wids
    assert "w3" not in all_econ

    # Every conclusion resolves to a work_item_id (directive sec 19).
    for r in projection["economic_only_failures"]:
        assert r["work_item_id"]
