"""Independent repair regressions, not expectations copied from native output."""
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import dl089_prescreen as screen, opt_census as census
from tools.strategy_farm import opt_census_select as selector
from tools.strategy_farm.research import pattern_fire_count as counter
from tools.strategy_farm.tests.test_opt_census import _db, _plan


@pytest.mark.parametrize("pid,sign", [(33, 1), (34, -1)])
def test_three_outside_requires_oldest_candle_and_close_confirmation(pid, sign):
    def bars(values):
        if sign < 0:
            values = [(210-o, 210-l, 210-h, 210-c, v) for o,h,l,c,v in values]
        return [counter.Bar(1700000000-i*86400, *v) for i,v in enumerate(values)]
    # Confirmation below the middle wick is sufficient. Positive is false in v1.
    sample = [(106,110,105,109,1000), (99,112,98,106,1000), (105,106,99,100,1000)]
    assert counter.evaluate(pid, bars(sample))
    assert not counter.evaluate(pid, bars([*sample[:2], (100,106,99,105,1000)]))
    assert not counter.evaluate(pid, bars([(106,110,105,106,1000), *sample[1:]]))
    # A formerly positive two-candle engulfing must no longer qualify.
    old = [(99,106.5,98.5,106,5000), (105,105.2,99.8,100,3000), (104,106,103,105,2000)]
    assert not counter.evaluate(pid, bars(old))


def test_prescreen_cannot_be_reenabled_by_stale_host_environment(monkeypatch, tmp_path):
    monkeypatch.setenv("QM_DL089_PRESCREEN", "1")
    assert screen.RETIRED and not screen.enabled()
    with pytest.raises(ValueError, match="retired"):
        screen.create_contract("USDJPY.DWX", manifest_root=tmp_path)
    from tools.strategy_farm import dl089_prescreen_retro as retro
    with pytest.raises(ValueError, match="retired"):
        retro.apply_program(None, {}, "", tmp_path, None, {})


@pytest.mark.parametrize("negative_first", [False, True])
def test_sealed_selector_can_accept_arms_rejected_by_b2(negative_first):
    years = list(range(2019, 2025))
    baseline = {y: selector.YearCell(y, 40, 1.0) for y in years}
    arm = {y: selector.YearCell(y, 40, 1.9) for y in years}
    # Less net profit (95 instead of 100), half the drawdown: R2DD 1.9 vs 1.0.
    assert not screen.qualifies({"net_profit":"95"}, {"net_profit":"100"})
    if negative_first:
        baseline[2019] = selector.YearCell(2019, 40, -1.0)
        assert not screen.qualifies({"net_profit":"100"}, {"net_profit":"-100"})
    result = selector.evaluate_arm(arm, baseline, years, activity_floor=10, min_rel=.05)
    assert result.admissible and result.qualifies
    assert result.consistency == (5 if negative_first else 6)


def test_new_program_admits_complete_matrix_despite_stale_optin(tmp_path, monkeypatch):
    monkeypatch.setenv("QM_DL089_PRESCREEN", "1")
    plan = _plan(tmp_path)
    db = _db(tmp_path / "farm.sqlite")
    ledger = tmp_path / "ledger.json"
    result = census.enqueue(plan, db_path=db, ledger_path=ledger,
                            parent_work_item_id="repair-owner")
    assert result["inserted"] == 1085
    assert "prescreen_contract" not in json.loads(ledger.read_text())
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT count(*) FROM work_items WHERE verdict=?", (screen.VERDICT,)).fetchone()[0] == 0


def test_retirement_preserves_legacy_rows_and_admits_only_unmaterialized_cells(tmp_path, monkeypatch):
    from tools.strategy_farm.tests.test_dl089_prescreen import setup, measure
    plan, db, ledger = setup(tmp_path, monkeypatch)
    census.enqueue(plan, db_path=db, ledger_path=ledger)
    for year in screen.YEARS:
        measure(db, plan, year, "baseline", 100, tmp_path)
    census.enqueue(plan, db_path=db, ledger_path=ledger)
    with sqlite3.connect(db) as conn:
        before = {r[0]:r for r in conn.execute("SELECT * FROM work_items")}
        old_skips = conn.execute("SELECT count(*) FROM work_items WHERE verdict=?", (screen.VERDICT,)).fetchone()[0]
    monkeypatch.setattr(screen, "RETIRED", True)
    (tmp_path / "USDJPY.DWX_D1.csv").unlink()
    result = census.enqueue(plan, db_path=db, ledger_path=ledger)
    assert result["skipped"] == 0 and result["deferred"] == 0
    with sqlite3.connect(db) as conn:
        after = {r[0]:r for r in conn.execute("SELECT * FROM work_items")}
        assert all(after[key] == row for key,row in before.items())
        assert conn.execute("SELECT count(*) FROM work_items WHERE verdict=?", (screen.VERDICT,)).fetchone()[0] == old_skips
