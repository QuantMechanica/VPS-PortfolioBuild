import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from health import chk_q02_stranded_exhausted_pairs  # noqa: E402


def _db():
    con = sqlite3.connect(":memory:")
    con.execute(
        "CREATE TABLE work_items "
        "(ea_id TEXT, symbol TEXT, phase TEXT, status TEXT, verdict TEXT)"
    )
    return con


def _infra(con, ea, symbol, count, phase="Q02"):
    con.executemany(
        "INSERT INTO work_items VALUES (?,?,?,'failed','INFRA_FAIL')",
        [(ea, symbol, phase)] * count,
    )


def test_flags_exhausted_pair_without_successor_or_verdict():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    result = chk_q02_stranded_exhausted_pairs(con)
    assert result["status"] == "FAIL"
    assert result["value"] == 1


def test_pending_successor_prevents_false_alarm():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_1','EURUSD.DWX','Q02','pending',NULL)"
    )
    result = chk_q02_stranded_exhausted_pairs(con)
    assert result["status"] == "OK"
    assert result["value"] == 0


def test_real_verdict_prevents_false_alarm():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_1','EURUSD.DWX','Q02','done','FAIL')"
    )
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"


def test_zero_trade_is_frequency_floor_disposition_not_stranded_infra():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_1','EURUSD.DWX','Q02','done','ZERO_TRADES')"
    )
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"


def test_invalid_is_evidence_disposition_not_stranded_infra():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_1','EURUSD.DWX','Q02','failed','INVALID')"
    )
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"


def test_any_non_infra_terminal_disposition_is_future_proof():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 12)
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_1','EURUSD.DWX','Q02','done','DRAFT_DEFECT')"
    )
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"


def test_below_retry_cap_is_not_exhausted():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 11)
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"


def test_counts_pairs_not_raw_rows_and_ignores_other_phases():
    con = _db()
    _infra(con, "QM5_1", "EURUSD.DWX", 20)
    _infra(con, "QM5_2", "USDJPY.DWX", 12)
    con.executemany(
        "INSERT INTO work_items VALUES (?,?,'Q03','failed','INFRA_FAIL')",
        [("QM5_3", "GBPUSD.DWX")] * 30,
    )
    assert chk_q02_stranded_exhausted_pairs(con)["value"] == 2


def test_legacy_p2_is_included_in_same_invariant():
    con = _db()
    _infra(con, "QM5_legacy", "EURUSD.DWX", 12, phase="P2")
    result = chk_q02_stranded_exhausted_pairs(con)
    assert result["status"] == "FAIL"
    assert result["value"] == 1
    assert "Q02/P2" in result["detail"]


def test_q02_and_legacy_p2_rows_form_one_logical_pair():
    con = _db()
    _infra(con, "QM5_mixed", "EURUSD.DWX", 6, phase="Q02")
    _infra(con, "QM5_mixed", "EURUSD.DWX", 6, phase="P2")
    assert chk_q02_stranded_exhausted_pairs(con)["value"] == 1


def test_legacy_p2_zero_disposition_covers_q02_infra_history():
    con = _db()
    _infra(con, "QM5_mixed", "EURUSD.DWX", 12, phase="Q02")
    con.execute(
        "INSERT INTO work_items VALUES "
        "('QM5_mixed','EURUSD.DWX','P2','done','MIN_TRADES_NOT_MET')"
    )
    assert chk_q02_stranded_exhausted_pairs(con)["status"] == "OK"
