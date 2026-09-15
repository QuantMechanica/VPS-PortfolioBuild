"""Tests: campaign library, mechanization ML policy, provider separation, research-state.

Covers directive §41/§42 (ML in research allowed, ML runtime rejected), §51
(mechanization gate), §52 (Creator/Critic provider separation), §54/§69 (research
state read-model), and follow-up §16 (first-campaign receipt data).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

from research import campaign_lib, mechanization_check, research_state_readmodel  # noqa: E402


# --------------------------------------------------------------------------- mechanization
def _write_card(tmp_path, text) -> Path:
    p = Path(tmp_path) / "card.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p


def test_ml_provenance_card_passes_but_runtime_ml_card_fails(tmp_path):
    """directive §41/§42/§51: ML in research provenance PASSes; ML in the runtime rules FAILs."""
    hyp = campaign_lib.FTMO_GAP_HYPOTHESES[0]
    good = campaign_lib.build_hypothesis_card(hyp)
    good_res = mechanization_check.check_spec(_write_card(tmp_path, good))
    assert good_res["verdict"] == "PASS", good_res["findings"]
    assert good_res["codex_implementable"] is True

    # Inject a runtime-ML marker into a *mechanics* section (the Long entry rules).
    bad = good.replace(
        "Enter long when the intraday z-score of price versus its lookback mean falls below the\n"
        "negative entry threshold within the trading session.",
        "A trained neural network model outputs the BUY signal via its inference API at runtime.",
    )
    bad_res = mechanization_check.check_spec(_write_card(tmp_path / "b", bad) if False else _write_card(tmp_path, bad))
    assert bad_res["verdict"] == "RETURN_TO_RESEARCH"
    assert any(f.startswith(("MECH_ML_IN_RULES", "MECH_RUNTIME_FEED", "MECH_MODEL_DEPENDENCY"))
               for f in bad_res["findings"]), bad_res["findings"]


def test_all_mechanizable_hypotheses_render_passing_cards(tmp_path):
    for hyp in campaign_lib.FTMO_GAP_HYPOTHESES:
        if not hyp.mechanizable:
            continue
        card = campaign_lib.build_hypothesis_card(hyp)
        res = mechanization_check.check_spec(_write_card(tmp_path / hyp.hid, card))
        assert res["verdict"] == "PASS", (hyp.hid, res["findings"])


# --------------------------------------------------------------------------- provider separation
def test_provider_separation_directive_52():
    ok, reason = campaign_lib.validate_provider_separation("kimi", "codex")
    assert ok and reason == "cross_provider_ok"
    ok, reason = campaign_lib.validate_provider_separation("kimi", "claude")
    assert ok
    # Kimi critiquing Kimi is never a valid separation.
    ok, reason = campaign_lib.validate_provider_separation("kimi", "kimi")
    assert not ok and reason == "kimi_critiqued_by_kimi"
    # Same provider both seats.
    ok, reason = campaign_lib.validate_provider_separation("claude", "claude")
    assert not ok and reason == "same_provider_creator_and_critic"
    # Absent critic is not a separation.
    ok, reason = campaign_lib.validate_provider_separation("kimi", "NOT_EVALUATED")
    assert not ok and reason == "critic_provider_absent"


def test_campaign_manifest_carries_creator_critic_separation():
    manifest = campaign_lib.assemble_campaign_manifest(
        campaign_id="CAMP-2026-0001-ftmo-gap",
        question="What mechanical edge is our FTMO book missing?",
        creator_provider="kimi",
        critic_provider="codex",
        critic_verdict="REVISE",
        cross_vendor=True,
        artifact="QM-RESEARCH-2026-0001",
        sealed=True,
        hypotheses_status={"H1": "preregistered", "H2": "new", "H3": "mechanized"},
        lessons=["Swing sleeves carry an overnight tail the FTMO daily-loss box punishes."],
    )
    # Creator/Critic separation is provable from the receipt data (directive §52).
    ok, reason = campaign_lib.validate_provider_separation(
        manifest["creator_provider"], manifest["critic_provider"]
    )
    assert ok, reason
    assert manifest["creator_provider"] != manifest["critic_provider"]
    assert manifest["schema"] == "qm.research-campaign/v1"
    assert {h["id"] for h in manifest["hypotheses"]} == {"H1", "H2", "H3"}


# --------------------------------------------------------------------------- research state read-model
def _write_jsonl(path: Path, rows) -> None:
    path.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")


def test_research_state_readmodel_from_fixtures(tmp_path):
    # A campaign manifest on disk.
    camp_root = tmp_path / "campaigns" / "CAMP-2026-0001-ftmo-gap"
    camp_root.mkdir(parents=True)
    manifest = campaign_lib.assemble_campaign_manifest(
        campaign_id="CAMP-2026-0001-ftmo-gap",
        question="What mechanical edge is our FTMO book missing?",
        creator_provider="kimi",
        critic_provider="codex",
        critic_verdict="REVISE",
        cross_vendor=True,
        artifact="QM-RESEARCH-2026-0001",
        sealed=False,
        hypotheses_status={"H1": "preregistered", "H2": "falsified", "H3": "mechanized"},
        lessons=["Density, not per-trade edge, binds FTMO completion."],
    )
    (camp_root / "campaign.json").write_text(json.dumps(manifest), encoding="utf-8")

    # Experiment-memory ledger with a falsified lesson.
    exp = tmp_path / "experiment_memory_ledger.jsonl"
    _write_jsonl(exp, [
        {"schema": "qm.experiment_memory/v1", "ts_utc": "2026-09-15T10:00:00+00:00",
         "strategy_id": "H2", "ea_id": "", "symbol": "", "phase": "research",
         "verdict": "FALSIFIED", "verdict_taxonomy": "research",
         "lesson": "H2 density claim did not add explanatory power out of sample."},
    ])

    # Real Kimi quota + governor state.
    quota = tmp_path / "kimi_quota_state.json"
    quota.write_text(json.dumps({
        "schema": "qm.kimi-quota/v1", "fetch_status": "ok",
        "source": "api.kimi.com/coding/v1/usages", "source_timestamp": "2026-09-15T12:00:00Z",
        "plan": "Allegro", "monthly": None,
        "rolling_5h": {"used_ratio": 0.12}, "rolling_7d": {"used_ratio": 0.05},
        "extra_quota_active": False,
    }), encoding="utf-8")
    gov = tmp_path / "kimi_governor_state.json"
    gov.write_text(json.dumps({"state": "NORMAL", "usage_source": "managed_usage_endpoint"}), encoding="utf-8")

    model = research_state_readmodel.build_research_state(
        campaigns_root=tmp_path / "campaigns",
        research_source_ledger=tmp_path / "missing_source_ledger.jsonl",  # absent -> tolerated
        experiment_memory_ledger=exp,
        kimi_quota_state=quota,
        kimi_governor_state=gov,
    )

    assert model["schema"] == "qm.research-state/v1"
    # Campaign surfaced with its cross-provider critic.
    assert len(model["kimi_campaigns"]) == 1
    camp = model["kimi_campaigns"][0]
    assert camp["campaign_id"] == "CAMP-2026-0001-ftmo-gap"
    assert camp["critic_provider"] == "codex"
    assert camp["sealed"] is False
    # Hypotheses bucketed by lifecycle stage.
    assert "CAMP-2026-0001-ftmo-gap/H1" in model["hypotheses"]["preregistered"]
    assert "CAMP-2026-0001-ftmo-gap/H2" in model["hypotheses"]["falsified"]
    assert "CAMP-2026-0001-ftmo-gap/H3" in model["hypotheses"]["mechanized"]
    # Most important failed lesson from experiment memory.
    assert "density" in model["most_important_failed_lesson"].lower()
    # Real quota folded (honest, from the fetch).
    assert model["quota"]["kimi"]["usage_source"] == "managed_usage_endpoint"
    assert model["quota"]["kimi"]["real"]["rolling_5h_used_ratio"] == 0.12
    # Programme roster present with owner providers.
    names = {p["name"] for p in model["programmes"]}
    assert "ftmo_gap_research" in names and "failure_mining" in names


def test_research_state_tolerates_all_inputs_absent(tmp_path):
    model = research_state_readmodel.build_research_state(
        campaigns_root=tmp_path / "nope",
        research_source_ledger=tmp_path / "a.jsonl",
        experiment_memory_ledger=tmp_path / "b.jsonl",
        kimi_quota_state=tmp_path / "c.json",
        kimi_governor_state=tmp_path / "d.json",
        universe_map_state=tmp_path / "no_universe_map.json",
        research_roi_state=tmp_path / "no_roi.json",
    )
    assert model["kimi_campaigns"] == []
    assert model["most_important_failed_lesson"] == "EVIDENCE_MISSING"
    assert model["quota"]["kimi"]["real"] is None
    assert model["quota"]["kimi"]["usage_source"] == "UNKNOWN"
    # New §19/§20 blocks degrade gracefully when the read-models are absent.
    assert model["universe_map"]["status"] == "EVIDENCE_MISSING"
    assert model["roi"]["status"] == "EVIDENCE_MISSING"


def test_research_state_folds_universe_map_and_roi(tmp_path):
    """§19/§20: research_state folds compact universe_map + roi summaries when present."""
    umap = tmp_path / "strategy_universe_map.json"
    umap.write_text(json.dumps({
        "schema": "qm.strategy-universe-map/v1",
        "generated_at_utc": "2026-09-15T12:00:00+00:00",
        "inputs_sha256": "abc",
        "totals": {"pairs": 100, "qualified": 5, "dxz_incumbent": 3, "ftmo_incumbent": 2},
        "directive_answers": {
            "breakout_derivative_share": {"count": 30, "share_pct": 30.0},
            "mean_reversion": {"count": 10, "share_pct": 10.0},
            "short_duration_fx_systems": {"count": 8, "share_pct": 8.0},
            "gold_share": {"count": 12, "share_pct": 12.0},
            "session_diversification": {"count": 5, "share_pct": 5.0, "by_session": {}},
            "high_density_ftmo_systems": {"count": 1, "share_pct": 1.0},
        },
        "whitespace_ranked": [{"style": "breakout", "expected_value": 20}] * 8,
    }), encoding="utf-8")
    roi = tmp_path / "research_roi.json"
    roi.write_text(json.dumps({
        "schema": "qm.research-roi/v1",
        "generated_at_utc": "2026-09-15T12:00:00+00:00",
        "inputs_sha256": "def",
        "origin_derivation": {"origin_distribution": {"external_source": 90, "internal_discovery": 10}},
        "sources_considered": {"external_seed_dirs": 5},
        "programmes": [
            {"origin_programme": "external_source", "is_directive_roi_programme": True,
             "funnel": {"registry_eas": 90, "reached_q02": 80, "reached_q08": 10, "reached_q14": 3},
             "book_admission": {"total": 3}, "yield_admit_per_q02_pct": 3.75},
            {"origin_programme": "failure_mining", "is_directive_roi_programme": True,
             "funnel": {"registry_eas": 0, "reached_q02": 0, "reached_q08": 0, "reached_q14": 0},
             "book_admission": {"total": 0}, "yield_admit_per_q02_pct": None},
        ],
    }), encoding="utf-8")

    model = research_state_readmodel.build_research_state(
        campaigns_root=tmp_path / "nope",
        research_source_ledger=tmp_path / "a.jsonl",
        experiment_memory_ledger=tmp_path / "b.jsonl",
        kimi_quota_state=tmp_path / "c.json",
        kimi_governor_state=tmp_path / "d.json",
        universe_map_state=umap,
        research_roi_state=roi,
    )
    um = model["universe_map"]
    assert um["status"] == "PRESENT"
    assert um["totals"]["pairs"] == 100
    assert um["breakout_share_pct"] == 30.0
    assert um["gold_share_pct"] == 12.0
    assert len(um["top_whitespace"]) == 5  # capped at 5
    r = model["roi"]
    assert r["status"] == "PRESENT"
    assert r["origin_distribution"]["external_source"] == 90
    assert r["economic_contribution_pnl"] == "EVIDENCE_MISSING"
    assert r["programmes"]["external_source"]["reached_q14"] == 3
    # failure_mining is a directive programme so it is kept even at zero.
    assert "failure_mining" in r["programmes"]


def test_observe_summary_deterministic_and_infra_free(tmp_path):
    from _research_fixtures import build_fixture_db, build_registry_csv  # noqa: WPS433
    from research import observe_projector

    db = build_fixture_db(tmp_path / "farm_state.sqlite")
    registry = build_registry_csv(tmp_path / "ea_id_registry.csv")
    manifest = observe_projector.project(db, tmp_path / "ds", registry_path=registry)
    dataset_dir = Path(manifest["dataset_dir"])

    summary = campaign_lib.compute_observe_summary(dataset_dir)
    # w3 (INFRA) never contributes to any economic figure.
    assert summary["strategy_row_count"] == 4  # w1,w2,w4,w6 (w3 infra, w5 measurement)
    # H1: intraday holding class present (H1/M15 fixture rows).
    assert "intraday" in summary["h1_outcome_by_holding_class"]
    # H2: low-activity count computed (w4=3, w6=8 trades over 5y are below floor).
    assert summary["h2_activity"]["low_activity_below_floor"] >= 2
    # Determinism: recompute equals.
    assert campaign_lib.compute_observe_summary(dataset_dir) == summary
