"""Regression tests for the CAMP-2026-0001 successor (QM-RESEARCH-2026-0002, G1 review).

Covers (directive sec37-54, sec70):
* the H-CW card passes the mechanization gate; H1/H2/H3 findings do NOT (honest),
* the successor mint flow remints from the parent, writes numeric-provenance outputs,
  attaches an honest cross-vendor critique, seals, and passes ``research_source.verify``,
* the parent artifact is never edited (lineage-only supersession),
* the multi-agent author is authorized.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import research_source  # noqa: E402
from research import campaign_ftmo_gap_cards_v2 as cards  # noqa: E402
from research import mechanization_check as mc  # noqa: E402
from research import finalize_ftmo_gap_campaign_v2 as drv  # noqa: E402


def test_hcw_card_passes_and_findings_do_not(tmp_path: Path) -> None:
    verdicts = {}
    for name, text in (("hcw", cards.H_CW_CARD), ("h1", cards.H1_CARD),
                       ("h2", cards.H2_CARD), ("h3", cards.H3_CARD)):
        p = tmp_path / f"{name}.md"
        p.write_text(text, encoding="utf-8")
        verdicts[name] = mc.check_spec(p)["verdict"]
    assert verdicts["hcw"] == "PASS"
    # The findings are honest non-candidates -> they must NOT masquerade as mechanized.
    assert verdicts["h1"] == "RETURN_TO_RESEARCH"
    assert verdicts["h2"] == "RETURN_TO_RESEARCH"
    assert verdicts["h3"] == "RETURN_TO_RESEARCH"


def test_multi_agent_author_is_authorized() -> None:
    assert research_source.is_authorized_author("multi-agent:Kimi+Fable") is True


def _seed_parent(store: Path, ledger: Path) -> str:
    minted = research_source.mint(
        author="Kimi", model="kimi-code/kimi-for-coding", task_id="CAMP-2026-0001-ftmo-gap",
        title="parent", research_id="QM-RESEARCH-2026-0001",
        store_root=store, ledger_path=ledger,
    )
    research_source.seal("QM-RESEARCH-2026-0001", status="reviewed",
                         store_root=store, ledger_path=ledger)
    return minted["id"]


def _fake_campaign(camp: Path, observe_dir: Path) -> None:
    observe_dir.mkdir(parents=True, exist_ok=True)
    (observe_dir / "manifest.json").write_text(
        json.dumps({"dataset_id": "deadbeef", "schema": "qm.observe-dataset/v1"}),
        encoding="utf-8")
    (camp / "observe_summary.json").write_text(json.dumps({
        "schema": "qm.observe-summary/v1", "strategy_row_count": 53722,
        "h1_outcome_by_holding_class": {
            "intraday": {"pass_rate": 0.5164, "total": 19516},
            "swing": {"pass_rate": 0.5079, "total": 9160},
            "position": {"pass_rate": 0.5567, "total": 20533},
            "scalp": {"pass_rate": 0.3991, "total": 3478},
        },
        "h2_activity": {"low_activity_below_floor": 424, "strategy_metric_rows": 4455,
                        "trades_mean": 373.17, "trades_min": 0.0, "trades_max": 8302.0},
        "h3_failure_clusters_top": [
            {"symbol_class": "fx_major", "session": "unspecified",
             "holding_class": "intraday", "fail_pairs": 4539}],
    }), encoding="utf-8")
    (camp / "campaign_run.json").write_text(json.dumps({
        "steps": {"observe": {"dataset_dir": str(observe_dir)},
                  "kimi": {"cli_version": "0.43.1", "latency_s": 932.9}}}), encoding="utf-8")


def test_successor_mint_seals_and_verifies(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    store = tmp_path / "store"
    ledger = tmp_path / "source_ledger.jsonl"
    search = tmp_path / "search_ledger.jsonl"
    _seed_parent(store, ledger)
    camp = tmp_path / "camp"; camp.mkdir()
    _fake_campaign(camp, tmp_path / "observe" / "run1")

    # research_source resolves ledgers via env when not passed explicitly.
    monkeypatch.setenv("QM_RESEARCH_STORE_ROOT", str(store))
    monkeypatch.setenv("QM_RESEARCH_SOURCE_LEDGER", str(ledger))
    monkeypatch.setenv("QM_RESEARCH_SEARCH_LEDGER", str(search))
    monkeypatch.setattr(drv, "STORE_ROOT", store)
    monkeypatch.setattr(drv, "CAMP_ROOT", camp)
    monkeypatch.setattr(drv, "SEARCH_LEDGER", search)
    monkeypatch.setattr(drv, "EXPERIMENT_LEDGER", tmp_path / "exp.jsonl")
    monkeypatch.setattr(drv, "RESEARCH_STATE_OUT", tmp_path / "research_state.json")
    monkeypatch.setattr(drv, "RECEIPT", tmp_path / "receipt.md")

    parent_source_before = (store / "QM-RESEARCH-2026-0001" / "source.md").read_bytes()

    out = drv.finalize(force_fallback=True)

    assert out["research_id"] == "QM-RESEARCH-2026-0002"
    assert out["mechanization"]["H-CW"]["verdict"] == "PASS"
    assert out["mechanization"]["H1"]["verdict"] == "RETURN_TO_RESEARCH"
    assert out["critic_verdict"] == "REVISE"  # not REJECT -> sealed
    assert out["cross_vendor"] is True
    assert out["sealed"] is True
    assert out["verify"]["ok"] is True
    assert not out["blockers"]
    # Parent is immutable: supersession is lineage-only, never an in-place edit.
    assert (store / "QM-RESEARCH-2026-0001" / "source.md").read_bytes() == parent_source_before
    lineage = json.loads((store / "QM-RESEARCH-2026-0002" / "lineage.json").read_text(encoding="utf-8"))
    assert lineage["parent_version_id"] == "QM-RESEARCH-2026-0001"
    assert lineage["version"] == 2
    # H-CW card exists in the artifact.
    assert (store / "QM-RESEARCH-2026-0002" / "H_CW_card.md").is_file()


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-q"]))
