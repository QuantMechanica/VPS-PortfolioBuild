"""chk_p2_pass_no_p3 must subtract DL-089 measurement siblings.

Q02-PASS OPT_CENSUS measurement instruments are never promoted to Q03 by the
pump (its promoter drops them via ``_measurement_sibling_exclusion_clause``), so
the health check must not count that by-design non-promotion as a stranded pump
backlog. A genuine orphan Q02-PASS-without-Q03 must still trip the check.

The sibling resolution normally consults on-disk DL-089 roots
(``_measurement_sibling_ea_ids``); to keep the test hermetic it is monkeypatched
to a controlled population so the test exercises only the check's own
exclusion bookkeeping.
"""

import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import health  # noqa: E402


def _db():
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute(
        "CREATE TABLE work_items "
        "(ea_id TEXT, symbol TEXT, phase TEXT, status TEXT, verdict TEXT, "
        " setfile_path TEXT, payload_json TEXT, evidence_path TEXT)"
    )
    return con


def _profitable_q02_pass(con, ea, symbol, net_profit=100.0):
    """A done/PASS Q02 row with positive net profit and no Q03 successor."""
    setfile = f"C:/QM/repo/framework/EAs/{ea}_x/sets/{ea}_x_{symbol}_D1_backtest.set"
    payload = json.dumps({"recovered_stats": {"net_profit": net_profit}})
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?)",
        (ea, symbol, "Q02", "done", "PASS", setfile, payload, None),
    )


def _set_siblings(monkeypatch, ea_ids, *, degraded=False):
    failures = [{"recognizer": "x", "reason": "blind"}] if degraded else []
    sib = farmctl.MeasurementSiblingSet(ea_ids, failures, {})
    monkeypatch.setattr(farmctl, "_measurement_sibling_ea_ids", lambda con: sib)


def test_measurement_siblings_are_excluded(monkeypatch):
    con = _db()
    for ea in ("QM5_41331", "QM5_41332", "QM5_41333"):
        _profitable_q02_pass(con, ea, "EURUSD.DWX")
    _set_siblings(monkeypatch, {"QM5_41331", "QM5_41332", "QM5_41333"})
    result = health.chk_p2_pass_no_p3(con)
    assert result["value"] == 0, result
    assert result["status"] == "OK"


def test_genuine_orphan_still_trips(monkeypatch):
    con = _db()
    # 9 measurement siblings (excluded) + 1 real orphan (kept).
    for i in range(9):
        _profitable_q02_pass(con, f"QM5_4133{i}", "EURUSD.DWX")
    _profitable_q02_pass(con, "QM5_9999", "GBPUSD.DWX")
    _set_siblings(monkeypatch, {f"QM5_4133{i}" for i in range(9)})
    result = health.chk_p2_pass_no_p3(con)
    # exactly the one real orphan survives the sibling exclusion
    assert result["value"] == 1, result


def test_mixed_population_counts_only_orphans(monkeypatch):
    con = _db()
    siblings = {f"QM5_413{i:02d}" for i in range(20)}
    for ea in siblings:
        _profitable_q02_pass(con, ea, "EURUSD.DWX")
    # three genuine orphans across distinct pairs
    for ea in ("QM5_1000", "QM5_1001", "QM5_1002"):
        _profitable_q02_pass(con, ea, "USDJPY.DWX")
    _set_siblings(monkeypatch, siblings)
    result = health.chk_p2_pass_no_p3(con)
    assert result["value"] == 3, result


def test_nonpositive_profit_siblings_never_counted(monkeypatch):
    con = _db()
    # loss-making Q02 PASS is already excluded by the profit filter regardless
    _profitable_q02_pass(con, "QM5_2000", "EURUSD.DWX", net_profit=-5.0)
    _set_siblings(monkeypatch, set())
    result = health.chk_p2_pass_no_p3(con)
    assert result["value"] == 0, result


def test_degraded_recognizer_stays_loud(monkeypatch):
    con = _db()
    # A recognizer blind-spot means the sibling set may be short: count all
    # rather than silently hide a possible orphan.
    for ea in ("QM5_41331", "QM5_41332", "QM5_41333"):
        _profitable_q02_pass(con, ea, "EURUSD.DWX")
    _set_siblings(monkeypatch, {"QM5_41331", "QM5_41332", "QM5_41333"}, degraded=True)
    result = health.chk_p2_pass_no_p3(con)
    assert result["value"] == 3, result
    assert "DEGRADED" in result["detail"]
