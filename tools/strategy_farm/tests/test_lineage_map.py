"""Contract tests for tools/strategy_farm/lineage_map.py (directive §9 / master §56).

Covers: mechanism-signature stability under cosmetic edits, relationship-class
decisions from fixture pairs, JSON read-model schema validity, and idempotency.
Read-only; no farm DB / terminal / network.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import lineage_map as lm  # noqa: E402


# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #

_BASE_MQ5 = """
#property strict
#include <QM/QM_Common.mqh>

// Framework banner comment that must be ignored.
input group "Risk"
input double RISK_FIXED = 1000.0;
input int    strategy_range_start_hour = 3;

// Non-strategy framework function -- ignored by the signature.
int OnInit()
{
   return INIT_SUCCEEDED;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   double atr = QM_ATR(14);
   if(atr <= 0.0)
      return false;
   req.price = QM_NormalizePrice(range_high);
   Strategy_PopulateEntry(req, QM_BUY_STOP, range_high, range_low, "BUY_TAG");
   return true;
}

bool Strategy_ExitSignal()
{
   if(Strategy_Gmt3Hour(TimeCurrent()) >= strategy_exit_hour)
      return true;
   return false;
}
"""


def _sig(text: str) -> str | None:
    return lm.compute_rule_signature(text)[0]


# --------------------------------------------------------------------------- #
# (a) Signature stability
# --------------------------------------------------------------------------- #

def test_signature_stable_under_comment_changes():
    edited = _BASE_MQ5.replace(
        "// Framework banner comment that must be ignored.",
        "// A completely different comment here",
    ).replace("// Non-strategy framework function -- ignored by the signature.", "")
    assert _sig(_BASE_MQ5) == _sig(edited)


def test_signature_stable_under_whitespace_changes():
    edited = _BASE_MQ5.replace("   ", "\t").replace("\n\n", "\n\n\n")
    assert _sig(_BASE_MQ5) == _sig(edited)


def test_signature_stable_under_input_default_changes():
    # Changing an input default (outside the Strategy_ hooks) must not move the hash.
    edited = _BASE_MQ5.replace("RISK_FIXED = 1000.0", "RISK_FIXED = 2500.0").replace(
        "strategy_range_start_hour = 3", "strategy_range_start_hour = 5"
    )
    assert _sig(_BASE_MQ5) == _sig(edited)


def test_signature_stable_under_hook_rename_and_string_tag():
    # Renaming a Strategy_ helper and changing a string reason tag are name-only.
    edited = _BASE_MQ5.replace("Strategy_PopulateEntry", "Strategy_PlaceOrder").replace(
        '"BUY_TAG"', '"A_DIFFERENT_TAG"'
    )
    assert _sig(_BASE_MQ5) == _sig(edited)


def test_signature_changes_when_logic_changes():
    # A genuine control-flow change MUST move the hash.
    edited = _BASE_MQ5.replace("if(atr <= 0.0)", "if(atr <= 5.0 && QM_RSI(14) > 70.0)")
    assert _sig(_BASE_MQ5) != _sig(edited)


def test_signature_none_without_strategy_hooks():
    boilerplate = "#property strict\nint OnInit(){return 0;}\nvoid OnTick(){}\n"
    assert lm.compute_rule_signature(boilerplate)[0] is None


# --------------------------------------------------------------------------- #
# (b) parameter distance
# --------------------------------------------------------------------------- #

def test_param_distance_zero_when_identical():
    a = {"strategy_hour": 3.0, "strategy_mult": 2.5}
    assert lm.param_distance(a, dict(a)) == 0.0


def test_param_distance_none_without_shared_keys():
    assert lm.param_distance({"strategy_a": 1.0}, {"strategy_b": 2.0}) is None


def test_param_distance_positive_when_differs():
    d = lm.param_distance({"strategy_hour": 3.0}, {"strategy_hour": 6.0})
    assert d is not None and 0 < d <= 1.0


def test_parse_setfile_only_strategy_keys(tmp_path):
    p = tmp_path / "x.set"
    p.write_text(
        "; header\nqm_ea_id=13213\nRISK_FIXED=1000\n"
        "strategy_range_start_hour=3\nstrategy_min_range_atr_mult=0.4||0||0.1||1\n",
        encoding="utf-8",
    )
    params = lm.parse_setfile(p)
    assert params == {"strategy_range_start_hour": 3.0, "strategy_min_range_atr_mult": 0.4}


# --------------------------------------------------------------------------- #
# (c) behaviour primitives
# --------------------------------------------------------------------------- #

def test_jaccard_and_pearson():
    assert lm.jaccard({"a", "b"}, {"a", "b"}) == 1.0
    assert lm.jaccard({"a", "b"}, {"b", "c"}) == round(1 / 3, 6)
    rho, n = lm.pearson({"d1": 1.0, "d2": 2.0, "d3": 3.0}, {"d1": 2.0, "d2": 4.0, "d3": 6.0})
    assert n == 3 and rho == 1.0


def test_load_trade_stream(tmp_path):
    p = tmp_path / "13213_USDJPY_DWX.jsonl"
    # entry 2020-01-01, exit same day net +10; second trade entry 2020-01-02 exit +5
    p.write_text(
        json.dumps({"entry_time": 1577836800, "time": 1577880000, "net": 10.0}) + "\n"
        + json.dumps({"entry_time": 1577923200, "time": 1577966400, "net": 5.0}) + "\n",
        encoding="utf-8",
    )
    loaded = lm.load_trade_stream(p)
    assert loaded["entry_days"] == {"2020-01-01", "2020-01-02"}
    assert set(loaded["daily_pnl"]) == {"2020-01-01", "2020-01-02"}


# --------------------------------------------------------------------------- #
# (relationship classes from fixture pairs)
# --------------------------------------------------------------------------- #

def _cfg():
    return lm.load_config()


def _node(sig, params=None, tokens=None):
    counter = lm.token_counter(tokens or [])
    return {
        "mechanism_signature": sig,
        "params": params or {},
        "token_counter": counter,
    }


def test_class_exact_clone_on_equal_signature():
    thr = _cfg()["thresholds"]
    a = _node("SIG1")
    b = _node("SIG1")
    rel, basis = lm.classify_pair(a, b, thr, rule_sim=None, d_param=0.0, jac=None,
                                  rho=None, declared=False, parent_retired=False)
    assert rel == "exact_clone" and basis == "SOURCE_SIGNATURE"


def test_class_close_implementation_clone_on_high_rule_sim():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, _ = lm.classify_pair(a, b, thr, rule_sim=0.93, d_param=None, jac=None,
                              rho=None, declared=False, parent_retired=False)
    assert rel == "close_implementation_clone"


def test_class_parameter_variant_on_near_same_code_diff_params():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, _ = lm.classify_pair(a, b, thr, rule_sim=0.99, d_param=0.1, jac=0.6,
                              rho=None, declared=False, parent_retired=False)
    assert rel == "parameter_variant"


def test_class_same_edge_different_implementation_on_behaviour():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, basis = lm.classify_pair(a, b, thr, rule_sim=0.4, d_param=None, jac=0.55,
                                  rho=0.8, declared=False, parent_retired=False)
    assert rel == "same_edge_different_implementation" and basis == "BEHAVIOUR"


def test_class_child_challenger_when_declared_and_distinct():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, _ = lm.classify_pair(a, b, thr, rule_sim=0.5, d_param=None, jac=None,
                              rho=None, declared=True, parent_retired=False)
    assert rel == "child_challenger"


def test_class_superseded_when_parent_retired():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, _ = lm.classify_pair(a, b, thr, rule_sim=0.5, d_param=None, jac=None,
                              rho=None, declared=True, parent_retired=True)
    assert rel == "superseded"


def test_class_materially_different_default():
    thr = _cfg()["thresholds"]
    a = _node("SIGA")
    b = _node("SIGB")
    rel, _ = lm.classify_pair(a, b, thr, rule_sim=0.2, d_param=None, jac=0.1,
                              rho=0.1, declared=False, parent_retired=False)
    assert rel == "materially_different"


# --------------------------------------------------------------------------- #
# families
# --------------------------------------------------------------------------- #

def test_family_classifier_first_match():
    cfg = _cfg()
    assert lm.classify_family("balke-gmt3-range-breakout", cfg) == "breakout"
    assert lm.classify_family("tv-dual-supertrend-adx", cfg) == "pairs"  # 'dual' -> pairs
    assert lm.classify_family("", cfg) == "unclassified"
    assert lm.classify_family("zzz-unknowable-thing", cfg) == "other"


def test_named_families_tags():
    cfg = _cfg()
    tags = lm.named_families_for("balke-gmt3-range-breakout", ["USDJPY.DWX"], cfg)
    assert "balke" in tags and "breakout" in tags
    xau = lm.named_families_for("some-system", ["XAUUSD.DWX"], cfg)
    assert "xau_systems" in xau


# --------------------------------------------------------------------------- #
# JSON schema validity + idempotency
# --------------------------------------------------------------------------- #

_RELATIONS = {
    "exact_clone", "close_implementation_clone", "parameter_variant",
    "same_edge_different_implementation", "materially_different",
    "child_challenger", "superseded",
}


def test_readmodel_schema_and_idempotency(tmp_path):
    json_path = tmp_path / "lineage_map.json"
    md_path = tmp_path / "STRATEGY_LINEAGE_MAP.md"
    r1 = lm.build(write_json=True, write_md=True, write_vault=False,
                  json_path=json_path, md_path=md_path)
    lineage = r1["lineage"]

    # Contract shape.
    assert lineage["schema"] == "qm.lineage-map/v1"
    for key in ("generated_at_utc", "inputs_sha256", "nodes", "edges", "families"):
        assert key in lineage
    # nodes keyed by ea_id, carry family + mechanism_signature + card_lineage.
    any_node = next(iter(lineage["nodes"].values()))
    for key in ("family", "mechanism_signature", "card_lineage"):
        assert key in any_node
    for key in ("parent_id", "variant_of", "rerun_of"):
        assert key in any_node["card_lineage"]
    # edges carry the contract fields and a valid relation.
    for e in lineage["edges"]:
        assert set(("from", "to", "relation", "evidence", "confidence")) <= set(e)
        assert e["relation"] in _RELATIONS
        ev = e["evidence"]
        for key in ("rule_signature_equal", "param_distance",
                    "trade_overlap_jaccard", "return_correlation"):
            assert key in ev
    # families maps to lists of ea_ids that exist as nodes.
    for fam, members in lineage["families"].items():
        assert isinstance(members, list)
        for m in members:
            assert m in lineage["nodes"]

    # Idempotency: same inputs -> byte-identical JSON (generated_at reused).
    first_bytes = json_path.read_bytes()
    lm.build(write_json=True, write_md=False, write_vault=False,
             json_path=json_path, md_path=md_path)
    assert json_path.read_bytes() == first_bytes


def test_edges_are_deterministically_ordered(tmp_path):
    json_path = tmp_path / "lm.json"
    r = lm.build(write_json=True, write_md=False, write_vault=False,
                 json_path=json_path)
    edges = r["lineage"]["edges"]
    keys = [(e["from"], e["to"], e["evidence"].get("symbol") or "", e["relation"]) for e in edges]
    assert keys == sorted(keys)
