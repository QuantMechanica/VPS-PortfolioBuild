"""Tests for the Second-Chance Strategy Register generator.

Covers the classifier precedence rules, clone suppression, eligibility logic,
the section-27 counterfactual, ranking determinism and the CSV/vault outputs.
All inputs are synthesised under tmp_path — no VPS state is touched.
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.research import second_chance_register as scr

FIXED = dt.datetime(2026, 9, 15, 12, 0, 0, tzinfo=dt.UTC)


# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------
def _node(gen: Path, cls: str, ea: str, slug: str, **fm: str) -> Path:
    d = gen / cls
    d.mkdir(parents=True, exist_ok=True)
    base = {
        "ea_id": ea,
        "slug": slug,
        "name": slug.replace("-", " ").title(),
        "projection_class": cls,
        "lifecycle_status": cls.lower(),
        "strategy_family": fm.get("strategy_family", "UNKNOWN"),
        "timeframes": fm.get("timeframes", "UNKNOWN"),
        "intended_symbols": fm.get("intended_symbols", "UNKNOWN"),
        "terminal_verdict": fm.get("terminal_verdict", "NOT_APPLICABLE"),
        "current_blocker": fm.get("current_blocker", "NOT_EVALUATED"),
        "canonical_repo_path": fm.get("canonical_repo_path", "EVIDENCE_MISSING"),
        "dxz_status": "NOT_APPLICABLE",
        "ftmo_status": "NOT_APPLICABLE",
    }
    lines = ["---"] + [f"{k}: {v}" for k, v in base.items()] + ["---", "", f"# {slug}", ""]
    p = d / f"{ea}_{slug}.md"
    p.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return p


def _card(root: Path, store: str, ea: str, slug: str, reason: str, *, bom: bool = False) -> Path:
    d = root / store
    d.mkdir(parents=True, exist_ok=True)
    fm = ["---", f"ea_id: {ea.split('_')[-1]}", f"slug: {slug}",
          "g0_status: REJECTED", f'g0_rejection_reason: "{reason}"', "---", "", "# card", ""]
    text = ("\r\n".join(fm)) if bom else ("\n".join(fm))
    p = d / f"{ea}_{slug}.md"
    data = text.encode("utf-8")
    if bom:
        data = b"\xef\xbb\xbf" + data
    p.write_bytes(data)
    return p


@pytest.fixture
def config_path() -> Path:
    return scr.DEFAULT_CONFIG


def _base_inputs(tmp_path: Path):
    gen = tmp_path / "generated"
    artifacts = tmp_path / "artifacts"
    registry = tmp_path / "ea_id_registry.csv"
    registry.write_text("ea_id,slug,status,retired_reason\n", encoding="utf-8")
    lineage = tmp_path / "lineage.json"
    lineage.write_text(json.dumps({"nodes": {}, "edges": [], "families": {}}), encoding="utf-8")
    universe = tmp_path / "universe.json"
    universe.write_text(json.dumps({"cells": [], "whitespace_ranked": []}), encoding="utf-8")
    return gen, artifacts, registry, lineage, universe


def _run(tmp_path, gen, artifacts, registry, lineage, universe, **kw):
    return scr.build_register(
        generated_dir=gen,
        config_path=scr.DEFAULT_CONFIG,
        registry_path=registry,
        lineage_path=lineage,
        universe_path=universe,
        db_path=kw.get("db", tmp_path / "no.sqlite"),
        artifacts_root=artifacts,
        book_dxz_path=kw.get("book_dxz", tmp_path / "no_dxz.json"),
        book_ftmo_path=kw.get("book_ftmo", tmp_path / "no_ftmo.json"),
        stream_dir=kw.get("stream_dir", tmp_path / "no_streams"),
        now=FIXED,
    )


# ---------------------------------------------------------------------------
# Classifier precedence
# ---------------------------------------------------------------------------
def test_style_reason_multi_position_is_eligible(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_1001", "split-tp-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_1001", "split-tp-ea",
                                        "R4 FAIL: split position as two separate MT5 orders per signal, conflicting with HR14 1-position-per-magic.")))
    reg_out = _run(tmp_path, gen, art, reg, lin, uni)
    rec = {r["ea_id"]: r for r in reg_out["records"]}["QM5_1001"]
    assert rec["primary_reason"] == "MULTI_POSITION"
    assert rec["eligibility"] == scr.ELIGIBLE
    assert rec["second_chance_status"] == scr.ELIGIBLE


def test_ml_runtime_stays_invalid_and_beats_multi_position(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_1002", "ml-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_1002", "ml-ea",
                                        "R4 FAIL: uses online learning ml inference and also multiple positions.")))
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1002"]
    assert rec["primary_reason"] == "ML_RUNTIME"
    assert rec["eligibility"] == scr.STILL_INVALID


def test_no_external_source_superseded_beats_insufficient(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_1003", "src-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_1003", "src-ea",
                                        "SUPERSEDED: source-only rejection recovered under OWNER R1 policy; original spec unspecified.")))
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1003"]
    assert rec["primary_reason"] == "NO_EXTERNAL_SOURCE"
    assert rec["eligibility"] == scr.ELIGIBLE


def test_insufficient_evidence_still_invalid(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_1004", "inc-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_1004", "inc-ea",
                                        "R2/R3 card_body_incomplete: missing target_symbols and period.", bom=True)))
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1004"]
    assert rec["primary_reason"] == "INSUFFICIENT_EVIDENCE"
    assert rec["eligibility"] == scr.STILL_INVALID


def test_bom_and_crlf_card_is_parsed(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_1005", "bom-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_1005", "bom-ea",
                                        "R2 FAIL: scalping M1 crypto-style threshold.", bom=True)))
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1005"]
    assert rec["primary_reason"] == "SCALPING"


def test_unknown_reason_is_other_never_guessed(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "RETIRED", "QM5_1006", "mystery")  # no card, no registry row, no db
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1006"]
    assert rec["primary_reason"] == "OTHER"
    assert rec["eligibility"] == scr.STILL_INVALID


def test_registry_unmaterialized_reservation_still_invalid(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    reg.write_text(
        "ea_id,slug,status,retired_reason\n"
        "1007,empty-res,retired,OWNER Option B: retire unmaterialized legacy reservations; fresh intake only\n",
        encoding="utf-8",
    )
    _node(gen, "RETIRED", "QM5_1007", "empty-res")
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1007"]
    assert rec["primary_reason"] == "HISTORICAL_POLICY"
    assert rec["eligibility"] == scr.STILL_INVALID  # override: nothing to reconsider


def test_id_repurpose_debris_not_attached(tmp_path):
    # A rejected debris card under an id whose node now has a DIFFERENT slug must
    # NOT inherit the debris reason (id re-purposing trap).
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _card(art, "cards_rejected", "QM5_1008", "old-debris-slug", "DUPLICATE: already approved twin.")
    _node(gen, "REJECTED", "QM5_1008", "new-repurposed-slug")  # different slug, no own reason
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_1008"]
    assert rec["primary_reason"] == "OTHER"  # debris reason not borrowed


# ---------------------------------------------------------------------------
# Clone suppression
# ---------------------------------------------------------------------------
def test_exact_clone_suppressed_against_active(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    lin.write_text(json.dumps({
        "nodes": {"QM5_2001": {"family": "trend"}, "QM5_9001": {"family": "trend"}},
        "edges": [{"from": "QM5_2001", "to": "QM5_9001", "relation": "exact_clone"}],
        "families": {"trend": ["QM5_2001", "QM5_9001"]},
    }), encoding="utf-8")
    _node(gen, "REJECTED", "QM5_2001", "clone-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_2001", "clone-ea",
                                        "R4 FAIL: multiple positions HR14.")))
    # QM5_9001 is not in the population, so it defaults to ACTIVE_CANONICAL keeper.
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_2001"]
    assert rec["second_chance_status"] == "SUPPRESSED_CLONE_OF:QM5_9001"
    assert rec["suppressed_clone_of"] == "QM5_9001"


def test_materially_different_duplicate_is_eligible(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    lin.write_text(json.dumps({
        "nodes": {"QM5_2002": {"family": "trend"}, "QM5_2003": {"family": "trend"}},
        "edges": [{"from": "QM5_2002", "to": "QM5_2003", "relation": "materially_different"}],
        "families": {"trend": ["QM5_2002", "QM5_2003"]},
    }), encoding="utf-8")
    _node(gen, "REJECTED", "QM5_2002", "dup-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_2002", "dup-ea",
                                        "DUPLICATE: functional duplicate of QM5_2003.")))
    rec = {r["ea_id"]: r for r in _run(tmp_path, gen, art, reg, lin, uni)["records"]}["QM5_2002"]
    assert rec["primary_reason"] == "DUPLICATE"
    assert rec["eligibility"] == scr.ELIGIBLE  # material edge upgrades it
    assert rec["suppressed_clone_of"] == ""  # material edge is not a clone edge


# ---------------------------------------------------------------------------
# Ranking + determinism
# ---------------------------------------------------------------------------
def test_ranking_is_deterministic_and_excludes_invalid(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    for i, (sym, tf) in enumerate([("EURUSD.DWX", "M15"), ("SP500.DWX", "D1"), ("XAUUSD.DWX", "H1")]):
        _node(gen, "REJECTED", f"QM5_30{i}", f"style-{i}", intended_symbols=sym, timeframes=tf,
              strategy_family="mean-reversion",
              canonical_repo_path=str(_card(art, "cards_rejected", f"QM5_30{i}", f"style-{i}",
                                            "R4 FAIL: multiple positions HR14 slot allocation.")))
    _node(gen, "REJECTED", "QM5_309", "invalid-ea",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_309", "invalid-ea",
                                        "R2 card_body_incomplete missing period.")))
    a = _run(tmp_path, gen, art, reg, lin, uni)
    b = _run(tmp_path, gen, art, reg, lin, uni)
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)
    ranked_ids = [r["ea_id"] for r in a["ranked_top200"]]
    assert "QM5_309" not in ranked_ids  # STILL_INVALID excluded
    assert set(ranked_ids) == {"QM5_300", "QM5_301", "QM5_302"}
    # FTMO-relevant EURUSD M15 (intraday, low swap) outranks SP500 D1.
    assert ranked_ids.index("QM5_300") < ranked_ids.index("QM5_301")


# ---------------------------------------------------------------------------
# Counterfactual (section 27/28)
# ---------------------------------------------------------------------------
def _write_stream(stream_dir: Path, numid: str, symbol: str, daily: dict[str, float]) -> None:
    stream_dir.mkdir(parents=True, exist_ok=True)
    lines = []
    for day, net in daily.items():
        epoch = int(dt.datetime.fromisoformat(day + "T00:00:00+00:00").timestamp())
        lines.append(json.dumps({"entry_time": epoch, "time": epoch, "net": net}))
    (stream_dir / f"{numid}_{symbol}.jsonl").write_text("\n".join(lines), encoding="utf-8")


def test_counterfactual_flags_improving_challenger(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    streams = tmp_path / "streams"
    # Roster with a small drawdown in 2025.
    _write_stream(streams, "9100", "EURUSD_DWX",
                  {"2025-03-01": 100.0, "2025-06-01": -50.0, "2025-09-01": 80.0})
    # Candidate adds pure positive PnL on non-overlapping days -> raises objective,
    # does not add drawdown.
    _write_stream(streams, "4001", "GBPUSD_DWX",
                  {"2025-04-01": 60.0, "2025-07-01": 40.0})
    book_dxz = tmp_path / "dxz.json"
    book_dxz.write_text(json.dumps({"incumbent": {"sleeves": [{"ea_id": 9100}]}}), encoding="utf-8")
    book_ftmo = tmp_path / "ftmo.json"
    book_ftmo.write_text(json.dumps({"incumbent": {"sleeves": []}}), encoding="utf-8")
    _node(gen, "REJECTED", "QM5_4001", "econ-ea", current_blocker="Q10:FAIL_PORTFOLIO",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_4001", "econ-ea", "portfolio")))
    out = _run(tmp_path, gen, art, reg, lin, uni,
               book_dxz=book_dxz, book_ftmo=book_ftmo, stream_dir=streams)
    cf = out["counterfactual"]
    assert cf["economic_fail_with_stream"] == 1
    assert any(c["ea_id"] == "QM5_4001" and c["venue"] == "DXZ" for c in cf["challengers"])
    rec = {r["ea_id"]: r for r in out["records"]}["QM5_4001"]
    assert rec["portfolio_utility_challenger"] is True
    assert rec["eligibility"] == scr.ELIGIBLE


def test_counterfactual_evidence_missing_without_streams(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_4002", "econ-nostream", current_blocker="Q10:FAIL_PORTFOLIO",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_4002", "econ-nostream", "fail_portfolio")))
    out = _run(tmp_path, gen, art, reg, lin, uni)
    cf = out["counterfactual"]
    assert cf["economic_fail_with_stream"] == 0
    assert cf["evidence_missing"] is True
    assert "QM5_4002" in cf["economic_fail_without_stream"]


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------
def test_write_all_emits_json_csv_and_vault(tmp_path):
    gen, art, reg, lin, uni = _base_inputs(tmp_path)
    _node(gen, "REJECTED", "QM5_5001", "ea-a",
          canonical_repo_path=str(_card(art, "cards_rejected", "QM5_5001", "ea-a",
                                        "R4 FAIL multiple positions HR14.")))
    register = _run(tmp_path, gen, art, reg, lin, uni)
    out_json = tmp_path / "reg.json"
    out_csv = tmp_path / "reg.csv"
    vault = tmp_path / "vault"
    written = scr.write_all(register, out_json=out_json, out_csv=out_csv, vault_override=vault)
    assert out_json.is_file() and out_csv.is_file()
    assert Path(written["vault_page"]).is_file()
    assert register["schema"] == "qm.second-chance-register/v1"
    header = out_csv.read_text(encoding="utf-8").splitlines()[0]
    assert "primary_reason" in header and "second_chance_status" in header
