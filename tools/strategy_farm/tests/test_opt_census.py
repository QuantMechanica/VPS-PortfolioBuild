from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import opt_census as subject


def _base_setfile(path: Path, ea_id: int = 29999) -> Path:
    path.write_text(
        "; environment:  backtest\n"
        f"qm_ea_id={ea_id}\n"
        "RISK_FIXED=1000\n"
        "RISK_PERCENT=0\n"
        "qm_news_stale_max_hours=336\n"
        "opt_pp_buy1=0\nopt_pp_buy2=0\nopt_pp_buy3=0\n"
        "opt_pp_sell1=0\nopt_pp_sell2=0\nopt_pp_sell3=0\n",
        encoding="utf-8",
    )
    return path


def _plan(tmp_path: Path) -> dict:
    return subject.build_plan(
        ea_id="QM5_29999", ea_label="QM5_29999_test_opt",
        symbol="USDJPY.DWX", timeframe="H1",
        base_setfile=_base_setfile(tmp_path / "base.set"),
        output_dir=tmp_path / "sets",
    )


def _db(path: Path, *, harness_pass: bool = True) -> Path:
    conn = sqlite3.connect(path)
    conn.execute("""CREATE TABLE work_items (
        id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
        ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
        status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL,
        parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
        payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )""")
    conn.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (subject.HARNESS_WORK_ITEM_ID, "harness", "HARNESS_PP_FIXTURE",
         "QM_PP_FIXTURE_HARNESS", "EURUSD.DWX", "",
         "done" if harness_pass else "failed", "PASS" if harness_pass else "INFRA_FAIL",
         0, None, "harness.json", None, "{}", "now", "now"),
    )
    conn.commit()
    conn.close()
    return path


def test_plan_is_exact_unique_1085_matrix(tmp_path: Path) -> None:
    plan = _plan(tmp_path)
    assert plan["planned_trials"] == 1085
    assert plan["declared_trial_count"] == 154
    assert plan["arm_count_per_year"] == 155
    assert len({cell["cell_key"] for cell in plan["cells"]}) == 1085
    assert {cell["year"] for cell in plan["cells"]} == set(range(2019, 2026))


def test_arm_inputs_are_single_pattern_or_zero_baseline(tmp_path: Path) -> None:
    plan = _plan(tmp_path)
    for cell in plan["cells"]:
        values = [int(cell["inputs"][key]) for key in subject.SET_KEYS]
        if cell["arm"] == "baseline":
            assert values == [0] * 6
        else:
            assert sum(value != 0 for value in values) == 1
            assert max(values) == cell["predicate_id"]


def test_enqueue_is_idempotent_and_keeps_opt_phase(tmp_path: Path) -> None:
    plan = _plan(tmp_path)
    db = _db(tmp_path / "farm.sqlite")
    ledger = tmp_path / "ledger.json"
    first = subject.enqueue(plan, db_path=db, ledger_path=ledger)
    second = subject.enqueue(plan, db_path=db, ledger_path=ledger)
    assert first == {"inserted": 1085, "existing": 0, "planned": 1085,
                     "ledger_path": str(ledger.resolve())}
    assert second["inserted"] == 0
    assert second["existing"] == 1085
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS'").fetchone()[0] == 1085
    assert conn.execute("SELECT COUNT(*) FROM work_items WHERE phase='Q02'").fetchone()[0] == 0
    payload = json.loads(conn.execute(
        "SELECT payload_json FROM work_items WHERE phase='OPT_CENSUS' LIMIT 1"
    ).fetchone()[0])
    assert payload["schema"] == subject.SCHEMA
    assert payload["declared_trial_count"] == 154
    assert payload["planned_trials"] == 1085
    conn.close()


def test_enqueue_refuses_until_fixture_harness_passes(tmp_path: Path) -> None:
    plan = _plan(tmp_path)
    db = _db(tmp_path / "farm.sqlite", harness_pass=False)
    with pytest.raises(subject.CensusError, match="not green"):
        subject.enqueue(plan, db_path=db, ledger_path=tmp_path / "ledger.json")
    assert not (tmp_path / "sets").exists()


@pytest.mark.parametrize(
    ("fixed", "percent", "stale", "message"),
    [("0", "0", "336", "RISK_FIXED"),
     ("1000", "1", "336", "RISK_FIXED"),
     ("1000", "0", "337", "must not exceed 336")],
)
def test_base_setfile_guardrails(tmp_path: Path, fixed: str, percent: str,
                                 stale: str, message: str) -> None:
    path = _base_setfile(tmp_path / "base.set")
    text = path.read_text(encoding="utf-8")
    text = text.replace("RISK_FIXED=1000", f"RISK_FIXED={fixed}")
    text = text.replace("RISK_PERCENT=0", f"RISK_PERCENT={percent}")
    text = text.replace("qm_news_stale_max_hours=336", f"qm_news_stale_max_hours={stale}")
    path.write_text(text, encoding="utf-8")
    with pytest.raises(subject.CensusError, match=message):
        subject.validate_base_setfile(path, "QM5_29999")
