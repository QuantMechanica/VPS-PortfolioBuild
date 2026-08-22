"""TASK B — OPT_CENSUS dispatchable end-to-end (DL-089 §3, S1/S2 infra half).

Covers the five infrastructure guarantees:
  1. DISPATCH — an OPT_CENSUS row ranks at Q04's tier (phase_rank 6), is NOT
     priority_track, interleaves with ordinary Q04, sits below priority rows and
     above ordinary Q02.
  2. RUN PATH — the payload single-year window resolves through
     ``_opt_census_window`` (opt_from_date/opt_to_date preferred, from_date/to_date
     fallback), fails closed on missing/malformed/reversed bounds.
  3. VERDICT — a healthy completion is scored MEASURED (taxonomy 'measurement',
     status 'done'); INFRA_FAIL keeps the infra path. The MNT-016 clean-view
     invariant admits the new (done, MEASURED, measurement) combination.
  4. METRICS ISOLATION — OPT_CENSUS is outside MT5_TESTER_PHASES, and a MEASURED
     row contributes nothing to the throughput gate_pass / completed counts; the
     per-phase age SLO does not false-alarm on a fresh census batch.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import farmctl
from tools.strategy_farm import health
from tools.strategy_farm import opt_census as census
from tools.strategy_farm import work_item_clean_view as clean
from tools.strategy_farm import mission_control_v2_data as mc


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
    setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
    parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT, payload_json TEXT,
    created_at TEXT, updated_at TEXT
)
"""


def _insert(conn: sqlite3.Connection, **cols: object) -> None:
    keys = list(cols)
    conn.execute(
        f"INSERT INTO work_items({','.join(keys)}) VALUES ({','.join('?' for _ in keys)})",
        tuple(cols[k] for k in keys),
    )


# ---------------------------------------------------------------------------
# 1 · DISPATCH — claim ordering
# ---------------------------------------------------------------------------
def test_opt_census_ranks_tier6_not_priority(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-08-21T00:00:00+00:00"
    rows = [
        ("prio_q04", "Q04", "QM5_1", "EURUSD.DWX", '{"priority_track": true}'),
        ("opt1", "OPT_CENSUS", "QM5_2_opt", "USDJPY.DWX",
         '{"opt_from_date":"2021.01.01","opt_to_date":"2021.12.31"}'),
        ("plain_q04", "Q04", "QM5_3", "EURUSD.DWX", "{}"),
        ("plain_q02", "Q02", "QM5_4", "EURUSD.DWX", "{}"),
    ]
    with farmctl.connect(root) as conn:
        for rid, phase, ea, sym, payload in rows:
            _insert(
                conn, id=rid, kind="backtest", phase=phase, ea_id=ea, symbol=sym,
                setfile_path=f"{rid}.set", status="pending", attempt_count=0,
                payload_json=payload, created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {r["id"]: r for r in ordered}
    # OPT_CENSUS is Q04's tier and is never priority_track.
    assert by_id["opt1"]["_phase_rank"] == by_id["plain_q04"]["_phase_rank"] == 6
    assert by_id["opt1"]["_priority_track_rank"] == 1
    order = [r["id"] for r in ordered]
    # Priority funnel rows drain first; OPT_CENSUS interleaves with ordinary Q04
    # and beats ordinary Q02 (never starves, never leads the funnel).
    assert order.index("prio_q04") < order.index("opt1")
    assert order.index("opt1") < order.index("plain_q02")

    opt_term = (by_id["opt1"]["_priority_track_rank"] * 10
                + by_id["opt1"]["_phase_rank"] - by_id["opt1"]["_age_weeks"])
    q04_term = (by_id["plain_q04"]["_priority_track_rank"] * 10
                + by_id["plain_q04"]["_phase_rank"] - by_id["plain_q04"]["_age_weeks"])
    assert opt_term == q04_term  # true interleave, not ahead


# ---------------------------------------------------------------------------
# 2 · RUN PATH — window pass-through
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ({"opt_from_date": "2021.01.01", "opt_to_date": "2021.12.31"},
         ("2021.01.01", "2021.12.31")),
        # committed OPT-S1 generator writes the plain keys — accepted as fallback
        ({"from_date": "2020.01.01", "to_date": "2020.12.31"},
         ("2020.01.01", "2020.12.31")),
        # opt_* wins when both present
        ({"opt_from_date": "2022.01.01", "opt_to_date": "2022.12.31",
          "from_date": "2020.01.01", "to_date": "2020.12.31"},
         ("2022.01.01", "2022.12.31")),
    ],
)
def test_opt_census_window_resolves(payload: dict, expected: tuple) -> None:
    assert farmctl._opt_census_window(payload) == expected


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"opt_from_date": "2021.01.01"},              # half-open
        {"opt_from_date": "2021-01-01", "opt_to_date": "2021.12.31"},  # malformed
        {"opt_from_date": "2021.12.31", "opt_to_date": "2021.01.01"},  # reversed
    ],
)
def test_opt_census_window_fails_closed(payload: dict) -> None:
    assert farmctl._opt_census_window(payload) is None


def test_opt_census_timeout_honours_payload_override() -> None:
    base = farmctl._opt_census_timeout_seconds({})
    assert base == farmctl.P2_FULL_TIMEOUT_MIN_SECONDS
    extended = farmctl._opt_census_timeout_seconds({"timeout_min": 300})
    assert extended >= base  # override can only extend


# ---------------------------------------------------------------------------
# 3 · VERDICT — MEASURED semantics
# ---------------------------------------------------------------------------
def test_measurement_verdict_remap() -> None:
    # Healthy completion (any gate token) -> MEASURED / measurement, underlying kept.
    payload: dict = {}
    verdict, reason, tax = farmctl._apply_measurement_phase_verdict(
        "OPT_CENSUS", "FAIL", "MIN_TRADES_NOT_MET", payload
    )
    assert (verdict, reason, tax) == ("MEASURED", "opt_census_measured", "measurement")
    assert payload["opt_census_underlying_verdict"] == "FAIL"
    assert payload["opt_census_underlying_reason"] == "MIN_TRADES_NOT_MET"
    # Reason carries no gate token (cockpit zero-trade scan must not pick it up).
    assert "MIN_TRADES_NOT_MET" not in reason

    # PASS also collapses to MEASURED (a measurement is never a gate pass).
    assert farmctl._apply_measurement_phase_verdict("OPT_CENSUS", "PASS", "", {})[:1] == ("MEASURED",)

    # INFRA_FAIL keeps the standard infra path.
    assert farmctl._apply_measurement_phase_verdict(
        "OPT_CENSUS", "INFRA_FAIL", "NO_HISTORY", {}
    ) == ("INFRA_FAIL", "NO_HISTORY", "infra")

    # Non-measurement phases pass through unchanged.
    assert farmctl._apply_measurement_phase_verdict("Q02", "PASS", "", {}) == ("PASS", "", "strategy")
    assert farmctl._apply_measurement_phase_verdict("Q06", "INFRA_FAIL", "TIMEOUT", {}) == (
        "INFRA_FAIL", "TIMEOUT", "infra",
    )


def test_measured_is_a_canonical_terminal_verdict() -> None:
    assert farmctl.MEASURED_VERDICT == "MEASURED"
    assert "MEASURED" in farmctl.CANONICAL_PARENT_CHILD_VERDICTS


def test_clean_view_admits_measured_combination() -> None:
    derived = clean.derive_work_item(
        {"id": "m", "status": "done", "verdict": "MEASURED", "payload_json": "{}"}
    )
    assert derived["status"] == "done"
    assert derived["verdict_taxonomy"] == "measurement"
    assert derived["clean_view_valid"] is True
    assert clean.allowed_combination("done", "MEASURED", "measurement")


def test_clean_view_sql_projects_measured(tmp_path: Path) -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    _insert(
        conn, id="m", kind="backtest", phase="OPT_CENSUS", ea_id="QM5_13213_opt",
        symbol="USDJPY.DWX", setfile_path="s.set", status="done", verdict="MEASURED",
        attempt_count=0, evidence_path="/e/summary.json", payload_json="{}",
        created_at="2026-08-21", updated_at="2026-08-21",
    )
    clean.install_clean_view(conn)
    conn.execute("PRAGMA query_only=ON")
    conn.row_factory = sqlite3.Row
    row = dict(conn.execute("SELECT * FROM work_items_clean").fetchone())
    assert (row["status"], row["verdict"], row["verdict_taxonomy"]) == (
        "done", "MEASURED", "measurement",
    )
    assert int(row["clean_view_valid"]) == 1


# ---------------------------------------------------------------------------
# 4 · METRICS ISOLATION
# ---------------------------------------------------------------------------
def test_opt_census_outside_mt5_tester_phases() -> None:
    assert "OPT_CENSUS" not in mc.MT5_TESTER_PHASES


def test_measured_row_does_not_count_in_throughput_gate_pass() -> None:
    conn = sqlite3.connect(":memory:")
    conn.execute(WORK_ITEMS_DDL)
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    # A real Q06 gate PASS (should count) + an OPT_CENSUS MEASURED (must not).
    _insert(conn, id="q06", kind="backtest", phase="Q06", ea_id="QM5_1", symbol="EURUSD",
            setfile_path="a.set", status="done", verdict="PASS", attempt_count=0,
            payload_json="{}", created_at=now, updated_at=now)
    _insert(conn, id="opt", kind="backtest", phase="OPT_CENSUS", ea_id="QM5_2_opt",
            symbol="USDJPY.DWX", setfile_path="b.set", status="done", verdict="MEASURED",
            attempt_count=0, payload_json="{}", created_at=now, updated_at=now)
    conn.row_factory = sqlite3.Row
    clean.install_clean_view(conn)
    progress = mc.build_progress(conn)
    # gate_pass counts the Q06 PASS only; the MEASURED row is excluded both by
    # phase (not an MT5 tester phase) and by its 'measurement' taxonomy.
    assert progress["total"]["gate_pass"] == 1
    assert progress["total"]["completed"] == 1  # OPT_CENSUS not in the MT5 window


def test_phase_age_slo_ignores_fresh_census_batch() -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(WORK_ITEMS_DDL)
    old = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=40)).isoformat()
    for i in range(200):
        _insert(conn, id=f"opt{i}", kind="backtest", phase="OPT_CENSUS",
                ea_id="QM5_x_opt", symbol="USDJPY.DWX", setfile_path=f"o{i}.set",
                status="pending", attempt_count=0, payload_json="{}",
                created_at=old, updated_at=old)
    conn.commit()
    snap = health.phase_age_slo_snapshot(conn)
    assert "OPT_CENSUS" not in snap["phases"]
    result = health.chk_work_item_phase_age_slo(conn)
    assert result["status"] == "OK"


# ---------------------------------------------------------------------------
# 7 · BOOST — rolling priority window (queue-priority-only)
# ---------------------------------------------------------------------------

def _boost_fixture(tmp_path: Path, statuses: list[tuple[str, bool]]) -> tuple[Path, Path]:
    """statuses: list of (status, already_flagged) per cell, ledger order."""
    db = tmp_path / "farm.sqlite"
    conn = sqlite3.connect(db)
    conn.execute(WORK_ITEMS_DDL)
    cells = []
    for i, (status, flagged) in enumerate(statuses):
        wid = f"cell-{i:03d}"
        payload = {"schema": census.SCHEMA, "cell_key": f"k{i}", "year": 2019 + i % 7}
        if flagged:
            payload["priority_track"] = True
        _insert(conn, id=wid, kind="backtest", phase="OPT_CENSUS", ea_id="QM5_41097",
                status=status, payload_json=json.dumps(payload),
                created_at="2026-08-22T07:00:00+00:00", updated_at="2026-08-22T07:00:00+00:00")
        cells.append({"work_item_id": wid, "cell_key": f"k{i}", "year": 2019 + i % 7,
                      "arm": "baseline", "direction": "NONE", "predicate_id": 0,
                      "setfile_path": "x.set", "from_date": "2019.01.01", "to_date": "2019.12.31"})
    conn.commit(); conn.close()
    ledger = tmp_path / "ledger.json"
    ledger.write_text(json.dumps({"cells": cells}), encoding="utf-8")
    return ledger, db


def test_boost_tops_up_to_window_counting_active_and_flagged(tmp_path: Path) -> None:
    ledger, db = _boost_fixture(tmp_path, [("active", False), ("pending", True)] + [("pending", False)] * 10)
    result = census.boost(ledger_path=ledger, db_path=db, window=4)
    assert result["active"] == 1 and result["flagged_before"] == 1
    assert result["boosted_now"] == 2  # 4 - 1 active - 1 flagged
    conn = sqlite3.connect(db)
    flagged = [r[0] for r in conn.execute(
        "SELECT id FROM work_items WHERE status='pending' "
        "AND json_extract(payload_json,'$.priority_track')=1 ORDER BY id")]
    assert flagged == ["cell-001", "cell-002", "cell-003"]
    payload = json.loads(conn.execute(
        "SELECT payload_json FROM work_items WHERE id='cell-002'").fetchone()[0])
    assert payload["boost_authority"].startswith("opt_census.boost")
    conn.close()


def test_boost_never_touches_done_or_active_and_is_idempotent_at_window(tmp_path: Path) -> None:
    ledger, db = _boost_fixture(tmp_path, [("done", False), ("active", False)] + [("pending", False)] * 6)
    first = census.boost(ledger_path=ledger, db_path=db, window=3)
    assert first["boosted_now"] == 2 and first["done"] == 1
    second = census.boost(ledger_path=ledger, db_path=db, window=3)
    assert second["boosted_now"] == 0 and second["flagged_before"] == 2
    conn = sqlite3.connect(db)
    for wid in ("cell-000", "cell-001"):
        payload = json.loads(conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (wid,)).fetchone()[0])
        assert "priority_track" not in payload
    conn.close()


def test_boost_window_bounds_rejected(tmp_path: Path) -> None:
    ledger, db = _boost_fixture(tmp_path, [("pending", False)])
    for bad in (0, 17):
        try:
            census.boost(ledger_path=ledger, db_path=db, window=bad)
        except census.CensusError:
            continue
        raise AssertionError(f"window {bad} accepted")
