"""Unit tests for rebaseline_census with a tiny in-memory fixture."""
import json
import os
import sqlite3
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import rebaseline_census as rc  # noqa: E402


def _mk_con():
    con = sqlite3.connect(":memory:")
    con.execute(
        "CREATE TABLE work_items ("
        " id TEXT, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,"
        " setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,"
        " parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,"
        " payload_json TEXT, created_at TEXT, updated_at TEXT)"
    )
    con.row_factory = sqlite3.Row
    return con


def _ins(con, rid, phase, ea, sym, status, verdict, payload=None):
    con.execute(
        "INSERT INTO work_items (id, phase, ea_id, symbol, status, verdict, payload_json)"
        " VALUES (?,?,?,?,?,?,?)",
        (rid, phase, ea, sym, status, verdict,
         json.dumps(payload) if payload else None),
    )


def test_canonical_gate_mapping():
    assert rc.canonical_gate("Q02") == "Q02"
    assert rc.canonical_gate("P2") == "Q02"          # legacy alias
    assert rc.canonical_gate("Q09_NEWS") == "Q09"    # Q09 prefix merge
    assert rc.canonical_gate("Q09_PORTFOLIO") is None
    assert rc.canonical_gate("COMPILE_EA") is None    # off-chain
    assert rc.canonical_gate("OPT_CENSUS") is None
    assert rc.canonical_gate("Q11") is None


def test_vclass():
    assert rc.vclass("PASS") == "PASS"
    assert rc.vclass("PASS_PORTFOLIO") == "OTHER"
    assert rc.vclass("PROMOTE_CHALLENGER") == "PASS"
    assert rc.vclass("CHALLENGER_PROMOTED") == "PASS"
    assert rc.vclass("KEEP_INCUMBENT") == "PASS"
    assert rc.vclass("ADMIT_BOTH") == "PASS"
    assert rc.vclass("FAIL") == "ECON_FAIL"
    assert rc.vclass("ZERO_TRADES") == "ECON_FAIL"
    assert rc.vclass("INFRA_FAIL") == "INFRA"
    assert rc.vclass("INVALID") == "INVALID"
    assert rc.vclass("SUPERSEDED") == "STALE"
    assert rc.vclass("OBSOLETE_NON_DWX_SYMBOL") == "NA"
    assert rc.vclass(None) == "OTHER"


def test_reusable_pair_with_frontier_infra():
    """Q02-Q05 valid, Q06 INFRA_FAIL -> REUSABLE, frontier Q06 infra."""
    con = _mk_con()
    for g in ("Q02", "Q03", "Q04", "Q05"):
        _ins(con, f"r{g}", g, "QM5_1", "EURUSD.DWX", "done", "PASS")
    _ins(con, "r6", "Q06", "QM5_1", "EURUSD.DWX", "failed", "INFRA_FAIL")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_contiguous_valid_gate"] == "Q05"
    assert row["earliest_missing_prerequisite"] == "Q06"
    assert row["frontier_class"] == "INFRA"
    assert row["frontier_infra"] is True
    assert row["disposition"] == "REUSABLE"
    assert row["macro_phase"] == "1_STRATEGIEBEWEIS"


def test_economic_fail_pair():
    """Q02 valid, Q03 FAIL on merit -> ECONOMIC_FAIL (dead), separate from infra."""
    con = _mk_con()
    _ins(con, "a", "Q02", "QM5_2", "GBPUSD.DWX", "done", "PASS")
    _ins(con, "b", "Q03", "QM5_2", "GBPUSD.DWX", "done", "FAIL")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_contiguous_valid_gate"] == "Q02"
    assert row["earliest_missing_prerequisite"] == "Q03"
    assert row["disposition"] == "ECONOMIC_FAIL"
    assert row["frontier_infra"] is False


def test_informational_portfolio_lane_cannot_mask_or_kill_news_frontier():
    con = _mk_con()
    for gate in rc.GATE_CHAIN[:7]:
        _ins(con, f"r{gate}", gate, "QM5_NEWS", "XAUUSD.DWX", "done", "PASS")
    _ins(
        con, "portfolio", "Q09_PORTFOLIO", "QM5_NEWS", "XAUUSD.DWX",
        "done", "FAIL_PORTFOLIO",
    )
    _ins(
        con, "news", "Q09_NEWS", "QM5_NEWS", "XAUUSD.DWX",
        "done", "REVIEW_REQUIRED",
    )

    row = rc.compute(con, None)["pair_rows"][0]

    assert row["highest_contiguous_valid_gate"] == "Q08"
    assert row["earliest_missing_prerequisite"] == "Q09"
    assert row["frontier_class"] == "INVALID"
    assert row["disposition"] == "REUSABLE"


def test_invalid_pair_no_valid_gate():
    """Q02 only, INFRA_FAIL, no valid gate -> INVALID disposition."""
    con = _mk_con()
    _ins(con, "a", "Q02", "QM5_3", "USDJPY.DWX", "failed", "INFRA_FAIL")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_contiguous_valid_gate"] == ""
    assert row["earliest_missing_prerequisite"] == "Q02"
    assert row["disposition"] == "INVALID"


def test_not_applicable_pair():
    con = _mk_con()
    _ins(con, "a", "Q02", "QM5_4", "XBRUSD.DWX", "done", "OBSOLETE_NON_DWX_SYMBOL")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["disposition"] == "NOT_APPLICABLE"
    assert row["frontier_class"] == "NA"


def test_renumber_only_legacy_pass():
    """Valid via legacy P2 only -> RENUMBER_ONLY, frontier Q03 missing."""
    con = _mk_con()
    _ins(con, "a", "P2", "QM5_5", "AUDUSD.DWX", "done", "PASS")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_contiguous_valid_gate"] == "Q02"
    assert row["disposition"] == "RENUMBER_ONLY"


def test_missing_pair_no_chain_rows():
    """Only off-chain rows -> MISSING, no observed gate."""
    con = _mk_con()
    _ins(con, "a", "COMPILE_EA", "QM5_6", "NZDUSD.DWX", "done", "COMPILE_OK")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_observed_gate"] == ""
    assert row["earliest_missing_prerequisite"] == "Q02"
    assert row["disposition"] == "MISSING"
    assert row["macro_phase"] == "0_NONE"


def test_full_chain_reusable_and_valid_at_gates():
    """Contiguous PASS through Q16 -> REUSABLE, counts at Q08/Q10/Q16."""
    con = _mk_con()
    for g in rc.GATE_CHAIN:
        _ins(con, f"r{g}", g, "QM5_7", "EURJPY.DWX", "done", "PASS")
    res = rc.compute(con, None)
    row = res["pair_rows"][0]
    assert row["highest_contiguous_valid_gate"] == "Q16"
    assert row["earliest_missing_prerequisite"] == ""
    assert row["disposition"] == "REUSABLE"
    assert row["macro_phase"] == "2_OPTIMIERUNG"
    s = res["summary"]
    assert s["pairs_valid_at_least_Q08"] == 1
    assert s["pairs_valid_at_least_Q10"] == 1
    assert s["pairs_valid_at_least_Q16"] == 1


@pytest.mark.parametrize(
    "terminal_verdict",
    ("PROMOTE_CHALLENGER", "CHALLENGER_PROMOTED", "KEEP_INCUMBENT", "ADMIT_BOTH"),
)
def test_terminal_requalification_outcomes_complete_contiguous_chain(terminal_verdict):
    con = _mk_con()
    for gate in rc.GATE_CHAIN[:-1]:
        _ins(con, f"r{gate}", gate, "QM5_9", "EURUSD.DWX", "done", "PASS")
    _ins(con, "rQ16", "Q16", "QM5_9", "EURUSD.DWX", "done", terminal_verdict)

    row = rc.compute(con, None)["pair_rows"][0]

    assert row["highest_contiguous_valid_gate"] == "Q16"


def test_finer_key_hash_extraction_and_validity():
    con = _mk_con()
    payload = {"expected_ex5_sha256": "AB" * 32, "expected_setfile_sha256": "CD" * 32}
    _ins(con, "a", "Q02", "QM5_8", "EURUSD.DWX", "done", "PASS", payload)
    res = rc.compute(con, None)
    finer = res["finer_rows"]
    assert len(finer) == 1
    fr = finer[0]
    assert fr["build_hash"] == ("ab" * 32)
    assert fr["setfile_hash"] == ("cd" * 32)
    assert fr["gate"] == "Q02"
    assert fr["valid"] == 1
    assert res["summary"]["total_finer_keys"] == 1


def test_limit_smoke():
    con = _mk_con()
    for i in range(5):
        _ins(con, f"r{i}", "Q02", f"QM5_{i:02d}", "EURUSD.DWX", "done", "PASS")
    res = rc.compute(con, 2)
    assert len(res["pair_rows"]) == 2
