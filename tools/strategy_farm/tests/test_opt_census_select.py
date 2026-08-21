"""DL-089 WF-selection + advance-driver tests (F2 R2 #4/#5).

Every expected outcome is derived by hand arithmetic in a comment so a reviewer can
recompute it without running the code.  The sealed rule (plan v3 §2) is:
  * return_to_maxdd, each year vs the SAME-YEAR baseline;
  * activity floor >= 10 distinct ENTRY days in EVERY selection year, checked FIRST;
  * qualification = >= +5% RELATIVE in >= 2/3 of the selection years;
  * rank by consistency, then mean relative improvement, then predicate id (asc);
  * <= 3 per direction; plateau MEDIAN for numeric picks, never the best.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import opt_census as census
from tools.strategy_farm import opt_census_select as sel
from tools.strategy_farm.opt_census_select import YearCell


def _cells(years, entry_days, r2dd) -> dict[int, YearCell]:
    """Build {year: YearCell}; scalars broadcast across years."""
    ed = entry_days if isinstance(entry_days, (list, tuple)) else [entry_days] * len(years)
    rr = r2dd if isinstance(r2dd, (list, tuple)) else [r2dd] * len(years)
    return {y: YearCell(y, ed[i], rr[i]) for i, y in enumerate(years)}


# ===========================================================================
# 1 · Exact +5%-relative threshold edge.
# ===========================================================================
def test_relative_threshold_exact_edge() -> None:
    # baseline r2dd = 1.0 every year.  arm r2dd = 1.05 -> (1.05-1.0)/1.0 = 0.05 -> qualifies (>=).
    # arm r2dd = 1.04 -> 0.04 < 0.05 -> does NOT qualify.
    assert sel.year_improves(1.05, 1.0, 0.05) is True   # exactly +5% relative -> True
    assert sel.year_improves(1.04, 1.0, 0.05) is False  # +4% relative -> False

    years = [2019, 2020, 2021]  # quorum(3) = ceil(2*3/3) = 2
    base = _cells(years, 20, 1.0)
    # arm improves in 2019 and 2020 (1.05) but not 2021 (1.0): consistency 2 >= 2 -> qualifies.
    arm_pass = _cells(years, 20, [1.05, 1.05, 1.0])
    ev = sel.evaluate_arm(arm_pass, base, years, activity_floor=10, min_rel=0.05)
    assert ev.consistency == 2 and ev.qualifies is True
    # arm improves in only 2019: consistency 1 < 2 -> fails.
    arm_fail = _cells(years, 20, [1.05, 1.0, 1.0])
    ev2 = sel.evaluate_arm(arm_fail, base, years, activity_floor=10, min_rel=0.05)
    assert ev2.consistency == 1 and ev2.qualifies is False


# ===========================================================================
# 2 · Activity-floor kill — evaluated BEFORE any return consideration.
# ===========================================================================
def test_activity_floor_kills_before_returns() -> None:
    years = [2019, 2020, 2021]
    base = _cells(years, 20, 1.0)
    # 2020 has only 5 entry days (< floor 10) though returns are stellar (r2dd 9.0).
    arm = _cells(years, [20, 5, 20], [9.0, 9.0, 9.0])
    ev = sel.evaluate_arm(arm, base, years, activity_floor=10, min_rel=0.05)
    assert ev.admissible is False
    assert ev.breach_year == 2020
    assert ev.qualifies is False
    assert ev.consistency == 0  # returns never scored — floor is the gate


# ===========================================================================
# 3 · Ranking tie — broken by predicate id ascending (deterministic).
# ===========================================================================
def test_ranking_tie_breaks_on_predicate_id() -> None:
    years = [2019, 2020, 2021]
    base = _cells(years, 20, 1.0)
    strong = _cells(years, 20, [1.2, 1.2, 1.2])  # 3/3, mean rel +20%
    tie_a = _cells(years, 20, [1.1, 1.1, 1.0])   # 2/3, mean rel = (0.1+0.1+0.0)/3 = 0.0667
    tie_b = _cells(years, 20, [1.1, 1.1, 1.0])   # identical stats to tie_a
    evals = {
        60: sel.evaluate_arm(strong, base, years, activity_floor=10, min_rel=0.05),
        50: sel.evaluate_arm(tie_a, base, years, activity_floor=10, min_rel=0.05),
        20: sel.evaluate_arm(tie_b, base, years, activity_floor=10, min_rel=0.05),
    }
    # 60 first (consistency 3). 20 before 50 (equal consistency+mean, lower pid wins).
    assert sel.select_direction(evals, cap=3) == [60, 20, 50]


# ===========================================================================
# 4 · <= 3 cap per direction.
# ===========================================================================
def test_direction_cap_is_three() -> None:
    years = [2019, 2020, 2021]
    base = _cells(years, 20, 1.0)
    # Five qualifying arms, all 3/3, distinct mean improvement by their constant r2dd.
    # pid -> constant r2dd: higher r2dd => higher mean rel improvement => ranks earlier.
    r = {10: 1.10, 20: 1.20, 30: 1.30, 40: 1.40, 50: 1.50}
    evals = {pid: sel.evaluate_arm(_cells(years, 20, val), base, years,
                                   activity_floor=10, min_rel=0.05)
             for pid, val in r.items()}
    # Descending mean improvement: 50,40,30 are the top three.
    assert sel.select_direction(evals, cap=3) == [50, 40, 30]
    assert len(sel.select_direction(evals, cap=3)) == 3


# ===========================================================================
# 5 · Stability — pass AND fail (plan §2; subset = Teilmenge per sealed text).
# ===========================================================================
def _step(buy, sell) -> dict:
    return {"BUY": list(buy), "SELL": list(sell)}


def test_stability_pass() -> None:
    # final (step4) = {(BUY,50)}.  earlier steps all contain (BUY,50) -> subset in 3/3 (>=2).
    steps = {
        1: _step([50], [20]),   # final subset? {(BUY,50)} <= {(BUY,50),(SELL,20)} : yes
        2: _step([50], []),     # equal -> subset : yes
        3: _step([50, 60], []), # {(BUY,50)} <= {(BUY,50),(BUY,60)} : yes
        4: _step([50], []),
    }
    # combo >= baseline in 2022,2023,2024 (3 of 4); worse in 2025 -> not_worse = 3 (>=3).
    combo = {2022: 1.2, 2023: 1.2, 2024: 1.2, 2025: 0.5}
    baseln = {2022: 1.0, 2023: 1.0, 2024: 1.0, 2025: 1.0}
    v = sel.stability_check(steps, combo, baseln)
    assert v["not_worse_count"] == 3 and v["subset_count"] == 3
    assert v["stable"] is True


def test_stability_fail_on_subset() -> None:
    # final (step4) = {(BUY,50),(BUY,99)} — 99 was never selected earlier -> subset in 0/3 (<2).
    steps = {
        1: _step([50], []),
        2: _step([50], []),
        3: _step([50], []),
        4: _step([50, 99], []),
    }
    # Returns are great everywhere (not_worse = 4) — irrelevant, the subset rule fails it.
    combo = {2022: 2.0, 2023: 2.0, 2024: 2.0, 2025: 2.0}
    baseln = {2022: 1.0, 2023: 1.0, 2024: 1.0, 2025: 1.0}
    v = sel.stability_check(steps, combo, baseln)
    assert v["not_worse_count"] == 4 and v["subset_count"] == 0
    assert v["stable"] is False


def test_stability_fail_on_return() -> None:
    # subset is fine (3/3) but combo beats baseline in only 2 of 4 test years (<3).
    steps = {1: _step([50], []), 2: _step([50], []), 3: _step([50], []), 4: _step([50], [])}
    combo = {2022: 1.2, 2023: 1.2, 2024: 0.5, 2025: 0.5}
    baseln = {2022: 1.0, 2023: 1.0, 2024: 1.0, 2025: 1.0}
    v = sel.stability_check(steps, combo, baseln)
    assert v["not_worse_count"] == 2 and v["subset_count"] == 3
    assert v["stable"] is False


# ===========================================================================
# 6 · Plateau median — never the best value.
# ===========================================================================
def test_plateau_median_picks_center_not_best() -> None:
    years = list(range(2019, 2026))  # 7 years; quorum(7) = ceil(14/3) = 5
    base = _cells(years, 20, 1.0)
    # For each candidate value, K years at r2dd 1.10 (+10%), the rest at 1.0.
    #   0.5  -> K=4  (< 5) -> NOT qualifying
    #   0.75 -> K=5  (>=5) -> qualifying
    #   1.25 -> K=6         -> qualifying
    #   1.5  -> K=7 (best)  -> qualifying
    # qualifying = {0.75, 1.25, 1.5}; sorted median = 1.25 (NOT the best 1.5).
    def val_cells(k):
        return _cells(years, 20, [1.10] * k + [1.0] * (7 - k))
    per_value = {0.5: val_cells(4), 0.75: val_cells(5), 1.25: val_cells(6), 1.5: val_cells(7)}
    result = sel.select_numeric_parameter(
        1.0, [0.5, 0.75, 1.25, 1.5], per_value, base, years,
        activity_floor=10, min_rel=0.05,
    )
    assert result["qualifying_values"] == [0.75, 1.25, 1.5]
    assert result["chosen_value"] == 1.25          # plateau median, not best (1.5)
    assert result["chosen_is_parent"] is False


def test_plateau_none_qualifying_keeps_parent() -> None:
    years = list(range(2019, 2026))
    base = _cells(years, 20, 1.0)
    per_value = {0.5: _cells(years, 20, 1.0), 1.5: _cells(years, 20, 1.0)}  # nobody improves
    result = sel.select_numeric_parameter(
        1.0, [0.5, 1.5], per_value, base, years, activity_floor=10, min_rel=0.05,
    )
    assert result["qualifying_values"] == []
    assert result["chosen_value"] == 1.0 and result["chosen_is_parent"] is True


# ===========================================================================
# 7 · Param grid + trial-count increment BEFORE enqueue.
# ===========================================================================
def _grid_file(tmp_path: Path) -> Path:
    # DL-088-correct shape: real wired parent levers, parent_value AMONG the
    # <=5 candidate_values as the mandatory control cell (matches F1's sealed
    # framework/EAs/QM5_41097_*/opt_param_grid.json).
    grid = {
        "schema": "qm.opt-param-grid.v1",
        "ea_id": "QM5_41097",
        "parameters": [
            {"name": "strategy_max_range_atr_mult", "parent_value": 2.5,
             "candidate_values": [1.5, 2.0, 2.5, 3.0, 3.5]},  # 5 incl. parent -> 4 trials
            {"name": "strategy_trail_trigger_r", "parent_value": 1.0,
             "candidate_values": [0.5, 0.75, 1.0, 1.25, 1.5]},  # 5 incl. parent -> 4 trials
            {"name": "strategy_range_end_hour", "parent_value": 6,
             "candidate_values": [5, 6, 7, 8]},                 # 4 incl. parent -> 3 trials
        ],
    }
    path = tmp_path / "opt_param_grid.json"
    path.write_text(json.dumps(grid), encoding="utf-8")
    return path


def test_load_param_grid_validates_and_hashes(tmp_path: Path) -> None:
    path = _grid_file(tmp_path)
    grid = sel.load_param_grid(path, expected_sha256=None)
    # (5-1) + (5-1) + (4-1) = 11 non-parent candidates = the trial increment;
    # the parent control cells are the incumbent, never new hypotheses.
    assert sel.numeric_trial_increment(grid) == 11
    # sha mismatch fails closed.
    with pytest.raises(census.CensusError, match="sha256 does not match"):
        sel.load_param_grid(path, expected_sha256="0" * 64)
    # a grid WITHOUT the parent among the candidates is rejected (DL-088:
    # the unmodified parent value is the mandatory control cell of the ladder).
    bad = json.loads(path.read_text())
    bad["parameters"][0]["candidate_values"] = [1.5, 2.0, 3.0, 3.5]  # parent 2.5 missing
    p2 = tmp_path / "bad.json"
    p2.write_text(json.dumps(bad), encoding="utf-8")
    with pytest.raises(census.CensusError, match="AMONG the candidate_values"):
        sel.load_param_grid(p2, expected_sha256=None)


def test_trial_count_increments_before_any_numeric_cell(tmp_path: Path) -> None:
    grid = sel.load_param_grid(_grid_file(tmp_path), expected_sha256=None)
    ledger = {"schema": census.SCHEMA, "declared_trial_count": 154, "driver": sel.init_driver()}
    # DB is empty: no numeric work item has been created yet.
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE work_items (id TEXT PRIMARY KEY, phase TEXT)")
    assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0
    sel.register_numeric_stage(ledger, grid)
    # 154 + 11 = 165, registered strictly before any cell exists.
    assert ledger["declared_trial_count_effective"] == 165
    assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0
    # Idempotent: a second registration does not double-count.
    sel.register_numeric_stage(ledger, grid)
    assert ledger["declared_trial_count_effective"] == 165
    assert ledger["driver"]["s5"]["numeric_trial_increment"] == 11


# ===========================================================================
# 8 · Advance is deterministic + idempotent over the farm DB.
# ===========================================================================
WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
    setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
    parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT, payload_json TEXT,
    created_at TEXT, updated_at TEXT
)
"""


def _base_setfile(path: Path) -> Path:
    path.write_text(
        "; environment: backtest\nqm_ea_id=41097\nRISK_FIXED=1000\nRISK_PERCENT=0\n"
        "opt_pp_buy1=0\nopt_pp_buy2=0\nopt_pp_buy3=0\n"
        "opt_pp_sell1=0\nopt_pp_sell2=0\nopt_pp_sell3=0\n"
        "strategy_max_range_atr_mult=2.5\nstrategy_trail_trigger_r=1.0\n"
        "strategy_range_end_hour=6\n",
        encoding="utf-8",
    )
    return path


def _mini_ledger(tmp_path: Path) -> tuple[Path, list[str]]:
    """A tiny census ledger: 7 baselines + 1 buy arm, all measurable."""
    out_dir = tmp_path / "sets"
    base = _base_setfile(tmp_path / "base.set")
    cells = []
    ids = []
    for year in census.YEARS:
        for arm, direction, pid in (("baseline", "NONE", 0), ("buy_005", "BUY", 5)):
            cell_key = f"PROG:{year}:{arm}"
            wid = f"wi-{year}-{arm}"
            ids.append(wid)
            cells.append({"cell_key": cell_key, "work_item_id": wid, "year": year,
                          "arm": arm, "direction": direction, "predicate_id": pid,
                          "setfile_path": str(out_dir / f"{cell_key}.set"),
                          "from_date": f"{year}.01.01", "to_date": f"{year}.12.31"})
    ledger = {
        "schema": census.SCHEMA, "program_id": "PROG", "ea_id": "QM5_41097",
        "ea_label": "QM5_41097_opt", "symbol": "USDJPY.DWX", "timeframe": "H1",
        "base_setfile_path": str(base), "output_dir": str(out_dir),
        "declared_trial_count": 154, "activity_floor": 10, "relative_improve_min": 0.05,
        "param_grid_sha256": None, "cells": cells, "driver": sel.init_driver(),
    }
    path = tmp_path / "ledger.json"
    path.write_text(json.dumps(ledger), encoding="utf-8")
    return path, ids


def _reader_for(measured_ids: set[str]):
    def read(work_item_id: str):
        if work_item_id in measured_ids:
            return ("OK", {"entry_days": 20, "return_to_maxdd": 1.0, "trades": 50})
        return ("PENDING", None)
    return read


def test_advance_waits_when_census_incomplete_and_is_idempotent(tmp_path: Path) -> None:
    ledger_path, _ids = _mini_ledger(tmp_path)
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    reader = _reader_for(set())  # nothing measured yet
    r1 = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                     metric_reader=reader, conn=conn)
    r2 = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                     metric_reader=reader, conn=conn)
    assert r1["state"] == sel.STATE_ENQUEUED and r1["waiting"] is True
    assert r2 == r1  # deterministic, no drift
    led = json.loads(ledger_path.read_text())
    assert led["driver"]["transitions"] == []  # no transition recorded while waiting


def test_advance_transitions_once_then_holds(tmp_path: Path) -> None:
    ledger_path, ids = _mini_ledger(tmp_path)
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    reader = _reader_for(set(ids))  # all census cells measured

    first = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                        metric_reader=reader, conn=conn)
    assert first["state"] == sel.STATE_WF_COMBO and first["combo_runs"] == 4
    combo_rows = conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS'").fetchone()[0]
    assert combo_rows == 4  # exactly the 4 walk-forward combo runs
    led_after_first = ledger_path.read_text()
    assert len(json.loads(led_after_first)["driver"]["transitions"]) == 1

    # Second advance: now in WF_COMBO with the 4 combo runs still PENDING -> no change.
    second = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                         metric_reader=reader, conn=conn)
    assert second["state"] == sel.STATE_WF_COMBO and second["waiting"] is True
    assert conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS'").fetchone()[0] == 4
    assert ledger_path.read_text() == led_after_first  # ledger byte-identical -> idempotent


def test_advance_dry_run_writes_nothing(tmp_path: Path) -> None:
    ledger_path, ids = _mini_ledger(tmp_path)
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    before = ledger_path.read_text()
    out = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                      metric_reader=_reader_for(set(ids)), conn=conn, dry_run=True)
    assert out["dry_run"] is True and out["state"] == sel.STATE_WF_COMBO
    assert conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0] == 0
    assert ledger_path.read_text() == before  # dry-run never persists


def test_advance_full_chain_to_ready_for_q15(tmp_path: Path) -> None:
    """Drive census -> combo -> full-window -> S5 -> confirm -> READY_FOR_Q15.

    A run is 'measured' as soon as its row exists (uniform r2dd 1.0): the point of
    this test is the *sequencing* and the terminal stop, not the numeric verdict.
    With every arm tied to baseline, no filter/parameter qualifies, so the chain
    freezes the six-zero baseline + parent numerics — still a complete, stable pass.
    """
    ledger_path, census_ids = _mini_ledger(tmp_path)
    grid = _grid_file(tmp_path)
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    census_id_set = set(census_ids)

    def reader(work_item_id: str):
        if work_item_id in census_id_set:
            return ("OK", {"entry_days": 20, "return_to_maxdd": 1.0, "trades": 50})
        row = conn.execute("SELECT 1 FROM work_items WHERE id=?", (work_item_id,)).fetchone()
        if row is not None:  # any derived run already enqueued counts as measured
            return ("OK", {"entry_days": 20, "return_to_maxdd": 1.0, "trades": 50})
        return ("PENDING", None)

    states = []
    for _ in range(8):
        out = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                          param_grid=grid, metric_reader=reader, conn=conn)
        states.append(out["state"])
        if out["state"] in sel.TERMINAL_STATES:
            break

    assert states[-1] == sel.STATE_READY
    assert sel.STATE_WF_COMBO in states and sel.STATE_S5 in states
    led = json.loads(ledger_path.read_text())
    # 5 transitions: ->WF_COMBO ->FULLWINDOW ->S5 ->CONFIRM ->READY_FOR_Q15.
    assert len(led["driver"]["transitions"]) == 5
    # Trial count grew by the grid increment (11 non-parent candidates) strictly during the S5 registration.
    assert led["declared_trial_count_effective"] == 154 + 11
    # Numeric pool = 7 per-year baselines + 12 candidates * 7 years = 91 S5 rows.
    s5_rows = conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE payload_json LIKE '%\"opt_census_stage\": \"S5%'"
    ).fetchone()[0]
    assert s5_rows == 7 + 14 * 7

    # A final advance in the terminal state is a no-op (idempotent stop).
    frozen = ledger_path.read_text()
    tail = sel.advance(ledger_path=ledger_path, db_path=Path(":memory:"),
                       param_grid=grid, metric_reader=reader, conn=conn)
    assert tail["terminal"] is True and ledger_path.read_text() == frozen
