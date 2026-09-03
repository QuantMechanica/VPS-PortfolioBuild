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
    # OPT_CENSUS tracks Q04's tier under the active manifest and is never
    # priority_track (v4 inserts another upstream gate, shifting the tier to 7).
    expected_q04_rank = farmctl.phase_rank(farmctl._INCUMBENT_PHASE) - farmctl.phase_rank("Q04")
    assert by_id["opt1"]["_phase_rank"] == by_id["plain_q04"]["_phase_rank"] == expected_q04_rank
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


def test_dl089_q02_prerequisite_outranks_opt_census_under_topdown(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """OQ-SIBLING-SEED-RANK-20260902 (OWNER Option A, 2026-09-02).

    A DL-089 measurement-sibling Q02 PREREQUISITE row -- identified purely by
    the seed-path schema ``DL089_Q02_PREREQUISITE_SCHEMA`` -- is lifted out of
    the ordinary Q02 tier and sorts strictly ahead of an OPT_CENSUS row of
    equal priority_track and age under the top-down selector, while an ordinary
    Q02 row of equal priority_track/age still sorts after OPT_CENSUS.
    """
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    assert farmctl.topdown_gate_priority_enabled()
    # Pin the constant to the exact literal the matrix-service seed path
    # (dl089_matrix_service._seed_q02) stamps on the prerequisite payload.
    assert (
        farmctl.DL089_Q02_PREREQUISITE_SCHEMA
        == "qm.dl089-measurement-q02-prerequisite/v1"
    )
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    # Equal priority_track and equal created_at (age) across all three rows so
    # the only distinguishing factor is the top-down gate rank the schema earns.
    prereq_payload = {
        "schema": farmctl.DL089_Q02_PREREQUISITE_SCHEMA,
        "priority_track": True,
        "priority_reason": "OWNER_P0_DL089_MATRIX_PREREQUISITE",
    }
    opt_census_payload = {"priority_track": True}
    ordinary_q02_payload = {"priority_track": True}
    with farmctl.connect(root) as conn:
        for rid, phase, payload in (
            ("dl089-prereq", "Q02", prereq_payload),
            ("opt-census", "OPT_CENSUS", opt_census_payload),
            ("ordinary-q02", "Q02", ordinary_q02_payload),
        ):
            _insert(
                conn, id=rid, kind="backtest", phase=phase, ea_id=f"QM5_{rid}",
                symbol="EURUSD.DWX", setfile_path=f"{rid}.set", status="pending",
                attempt_count=0, payload_json=json.dumps(payload),
                created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    order = [r["id"] for r in ordered]
    # First arm ranks the prerequisite ahead of the tier-0 optimization rows,
    # so it precedes OPT_CENSUS; the ordinary Q02 keeps its ordinary (large)
    # top-down rank and stays behind OPT_CENSUS.
    assert order.index("dl089-prereq") < order.index("opt-census")
    assert order.index("opt-census") < order.index("ordinary-q02")


def test_dl089_q02_prerequisite_schema_only_matches_that_exact_schema(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The new first arm must not lift ordinary Q02 rows: only the exact
    seed-path schema is matched; a bare/other-schema Q02 stays in its tier."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        for rid, payload in (
            ("no-schema", {"priority_track": True}),
            ("other-schema", {"schema": "qm.something-else/v1", "priority_track": True}),
            ("opt-census", None),
        ):
            phase = "OPT_CENSUS" if rid == "opt-census" else "Q02"
            body = {"priority_track": True} if payload is None else payload
            _insert(
                conn, id=rid, kind="backtest", phase=phase, ea_id=f"QM5_{rid}",
                symbol="EURUSD.DWX", setfile_path=f"{rid}.set", status="pending",
                attempt_count=0, payload_json=json.dumps(body),
                created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    order = [r["id"] for r in ordered]
    # Neither ordinary Q02 row is lifted; OPT_CENSUS still precedes both.
    assert order.index("opt-census") < order.index("no-schema")
    assert order.index("opt-census") < order.index("other-schema")


def test_released_source_repair_compile_beats_priority_measurement(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    authenticated_repair = {
        "compile_contract_version": farmctl.COMPILE_WORK_ITEM_CONTRACT,
        "append_only_source_repair": True,
        "compile_source_repair_contract_version": (
            farmctl.COMPILE_SOURCE_REPAIR_CONTRACT
        ),
        "compile_source_repair_authority": "router_ops_issue:test-task",
    }
    malformed_repair = {
        **authenticated_repair,
        "compile_source_repair_authority": "",
    }
    with farmctl.connect(root) as conn:
        for item_id, kind, phase, payload in (
            (
                "priority-measurement",
                "backtest",
                "OPT_CENSUS",
                {"priority_track": True},
            ),
            ("authenticated-repair", "compile", "COMPILE_EA", authenticated_repair),
            ("malformed-repair", "compile", "COMPILE_EA", malformed_repair),
        ):
            _insert(
                conn,
                id=item_id,
                kind=kind,
                phase=phase,
                ea_id=f"QM5_{item_id}",
                symbol="",
                setfile_path="",
                status="pending",
                attempt_count=0,
                payload_json=json.dumps(payload),
                created_at=now,
                updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    order = [row["id"] for row in ordered]
    assert by_id["authenticated-repair"]["_priority_track_rank"] == -1
    assert by_id["malformed-repair"]["_priority_track_rank"] == 1
    assert order.index("authenticated-repair") < order.index("priority-measurement")
    assert order.index("priority-measurement") < order.index("malformed-repair")


def test_frontier_marker_breaks_broad_owner_priority_tie(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-08-31T00:00:00+00:00"
    external = {
        "priority_track": True,
        "priority_track_reason": "OWNER fixture priority",
    }
    frontier = {
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    with farmctl.connect(root) as conn:
        for item_id, payload in (
            ("external-nonfrontier", external),
            ("authenticated-frontier", frontier),
        ):
            _insert(
                conn,
                id=item_id,
                kind="backtest",
                phase="OPT_CENSUS",
                ea_id="QM5_REPLAY",
                symbol="EURUSD.DWX",
                setfile_path=f"{item_id}.set",
                status="pending",
                attempt_count=0,
                payload_json=json.dumps(payload),
                created_at=now,
                updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
        external_after = json.loads(conn.execute(
            "SELECT payload_json FROM work_items WHERE id='external-nonfrontier'"
        ).fetchone()[0])

    assert [row["id"] for row in ordered[:2]] == [
        "authenticated-frontier",
        "external-nonfrontier",
    ]
    assert external_after == external


def test_idle_program_frontier_precedes_second_lane_when_capacity_is_free(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-08-31T00:00:00+00:00"
    active = {
        "schema": census.SCHEMA,
        "program_id": "program-running",
        "arm": "buy_001",
        "year": 2019,
    }
    running_second_lane = {
        **active,
        "arm": "buy_002",
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    idle_head = {
        **active,
        "program_id": "program-idle",
        "arm": "baseline",
        "year": 2021,
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    with farmctl.connect(root) as conn:
        for item_id, status, claimed_by, symbol, payload, updated_at in (
            (
                "running-active",
                "active",
                "T1",
                "XAUUSD.DWX",
                active,
                "2026-08-31T00:00:00+00:00",
            ),
            (
                "running-second-lane",
                "pending",
                None,
                "XAUUSD.DWX",
                running_second_lane,
                "2026-08-31T00:01:00+00:00",
            ),
            (
                "idle-program-head",
                "pending",
                None,
                "EURUSD.DWX",
                idle_head,
                "2026-08-31T01:00:00+00:00",
            ),
        ):
            _insert(
                conn,
                id=item_id,
                kind="backtest",
                phase="OPT_CENSUS",
                ea_id=f"QM5_{item_id}",
                symbol=symbol,
                setfile_path=f"{item_id}.set",
                status=status,
                attempt_count=0,
                claimed_by=claimed_by,
                payload_json=json.dumps(payload),
                created_at=now,
                updated_at=updated_at,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert by_id["idle-program-head"]["_opt_census_idle_program_rank"] == 0
    assert by_id["running-second-lane"]["_opt_census_idle_program_rank"] == 1
    assert [row["id"] for row in ordered[:2]] == [
        "idle-program-head",
        "running-second-lane",
    ]


def test_post_census_critical_path_precedes_annual_frontier_without_reordering_annuals(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    annual = {
        "schema": census.SCHEMA,
        "program_id": "program-annual",
        "arm": "buy_001",
        "year": 2019,
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    combo = {
        "schema": census.SCHEMA,
        "program_id": "program-complete",
        "cell_key": "program-complete:wf1:combo:2022",
        "arm": "wf1_combo",
        "year": 2022,
        "opt_census_stage": "WF_COMBO",
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    numeric = {
        "schema": census.SCHEMA,
        "program_id": "program-complete",
        "cell_key": "program-complete:numeric:baseline:2019",
        "arm": "baseline",
        "year": 2019,
        "opt_census_stage": "NUMERIC_BASELINE",
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    final_fullwindow = {
        "schema": census.SCHEMA,
        "program_id": "program-complete",
        "cell_key": "program-complete:final_fullwindow:final",
        "arm": "final:selected",
        "year": 2019,
        "opt_census_stage": "FINAL_FULLWINDOW",
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    with farmctl.connect(root) as conn:
        for item_id, payload, updated_at in (
            ("annual-first", annual, "2026-08-31T00:00:00+00:00"),
            (
                "annual-second",
                {**annual, "arm": "buy_002"},
                "2026-08-31T00:01:00+00:00",
            ),
            ("wf-combo", combo, now),
            ("numeric", numeric, "2026-09-01T00:01:00+00:00"),
            ("final-fullwindow", final_fullwindow, "2026-09-01T00:02:00+00:00"),
        ):
            _insert(
                conn,
                id=item_id,
                kind="backtest",
                phase="OPT_CENSUS",
                ea_id=f"QM5_{item_id}",
                symbol="EURUSD.DWX",
                setfile_path=f"{item_id}.set",
                status="pending",
                attempt_count=0,
                payload_json=json.dumps(payload),
                created_at=updated_at,
                updated_at=updated_at,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert by_id["wf-combo"]["_opt_census_post_census_rank"] == 0
    assert by_id["numeric"]["_opt_census_post_census_rank"] == 0
    assert by_id["final-fullwindow"]["_opt_census_post_census_rank"] == 0
    assert by_id["annual-first"]["_opt_census_post_census_rank"] == 1
    assert [row["id"] for row in ordered[:5]] == [
        "wf-combo",
        "numeric",
        "final-fullwindow",
        "annual-first",
        "annual-second",
    ]


def test_numeric_baseline_true_head_precedes_later_year_and_cross_program_annual(
    tmp_path: Path,
) -> None:
    """A later baseline year with an older timestamp cannot hide the lane head."""

    root = tmp_path / "farm"
    farmctl.init_db(root)
    annual = {
        "schema": census.SCHEMA,
        "program_id": "program-annual-refill",
        "cell_key": "program-annual-refill:2019:buy_001",
        "arm": "buy_001",
        "year": 2019,
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    baseline_head = {
        "schema": census.SCHEMA,
        "program_id": "program-numeric",
        "cell_key": "program-numeric:numeric:baseline:2020",
        "arm": "baseline",
        "year": 2020,
        "opt_census_stage": "NUMERIC_BASELINE",
        "priority_track": True,
        census.FRONTIER_PRIORITY_MARKER: True,
    }
    baseline_later = {
        **baseline_head,
        "cell_key": "program-numeric:numeric:baseline:2021",
        "year": 2021,
    }
    with farmctl.connect(root) as conn:
        for item_id, payload, updated_at in (
            # Reproduce the live defect: year 2021 is older by updated_at, while
            # year 2020 was restamped after its predecessor completed.
            ("baseline-2021", baseline_later, "2026-09-01T05:47:24+00:00"),
            ("annual-refill", annual, "2026-09-01T06:00:00+00:00"),
            ("baseline-2020", baseline_head, "2026-09-01T07:50:26+00:00"),
        ):
            _insert(
                conn,
                id=item_id,
                kind="backtest",
                phase="OPT_CENSUS",
                ea_id=f"QM5_{item_id}",
                symbol="EURUSD.DWX",
                setfile_path=f"{item_id}.set",
                status="pending",
                attempt_count=0,
                payload_json=json.dumps(payload),
                created_at=updated_at,
                updated_at=updated_at,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert by_id["baseline-2020"]["_opt_census_post_census_rank"] == 0
    assert by_id["baseline-2021"]["_opt_census_post_census_rank"] == 1
    assert by_id["annual-refill"]["_opt_census_post_census_rank"] == 1
    assert ordered[0]["id"] == "baseline-2020"
    assert [row["id"] for row in ordered].index("baseline-2020") < [
        row["id"] for row in ordered
    ].index("annual-refill")


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
    # A real Q06 gate PASS plus an OPT_CENSUS measurement completion.
    _insert(conn, id="q06", kind="backtest", phase="Q06", ea_id="QM5_1", symbol="EURUSD",
            setfile_path="a.set", status="done", verdict="PASS", attempt_count=0,
            payload_json="{}", created_at=now, updated_at=now)
    _insert(conn, id="opt", kind="backtest", phase="OPT_CENSUS", ea_id="QM5_2_opt",
            symbol="USDJPY.DWX", setfile_path="b.set", status="done", verdict="MEASURED",
            attempt_count=0, payload_json="{}", created_at=now, updated_at=now)
    conn.row_factory = sqlite3.Row
    clean.install_clean_view(conn)
    progress = mc.build_progress(conn)
    # Completed-work counts both rows; gate_pass counts only the Q06 PASS
    # because the MEASURED row has measurement taxonomy.
    assert progress["total"]["gate_pass"] == 1
    assert progress["total"]["completed"] == 2


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
    for bad in (0, 65):
        try:
            census.boost(ledger_path=ledger, db_path=db, window=bad)
        except census.CensusError:
            continue
        raise AssertionError(f"window {bad} accepted")


def test_dl089_q02_prerequisite_arm_tolerates_malformed_payload(monkeypatch):
    """OQ-SIBLING-SEED-RANK-20260902 guard: a pending Q02 row whose payload_json
    is empty or not JSON must neither abort the claim-order query nor be lifted;
    it keeps the ordinary Q02 rank while a valid prerequisite still leads."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    rank_sql = farmctl._topdown_gate_rank_sql()
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE work_items(id TEXT, phase TEXT, payload_json TEXT)")
    conn.executemany(
        "INSERT INTO work_items VALUES (?, ?, ?)",
        [
            ("prereq", "Q02", json.dumps({"schema": farmctl.DL089_Q02_PREREQUISITE_SCHEMA})),
            ("empty", "Q02", ""),
            ("garbage", "Q02", "not json"),
            ("census", "OPT_CENSUS", "{}"),
        ],
    )
    rows = conn.execute(
        f"SELECT id, {rank_sql} AS r FROM work_items w ORDER BY r, id"
    ).fetchall()
    ranks = dict(rows)
    assert ranks["prereq"] < ranks["census"]
    assert ranks["empty"] == ranks["garbage"] > ranks["census"]


# ---------------------------------------------------------------------------
# 8 · AMENDMENT B — exact append-only lineage reruns lead the priority lane
#     (OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 §3, recorded in
#     docs/ops/evidence/
#     2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md)
# ---------------------------------------------------------------------------

def _lineage_rerun_payload(**extra: object) -> dict:
    """The payload an exact append-only rerun carries once it is marked.

    ``append_only_rerun`` is written by ``farmctl.append_only_exact_row_rerun``
    (the ``enqueue-backtest --append-only-rerun-of`` path); ``priority_track``
    is added afterwards by ``farmctl mark-priority-track``.
    """
    payload = {
        "append_only_rerun": True,
        "append_only_rerun_of_work_item": "source-row-id",
        "priority_track": True,
    }
    payload.update(extra)
    return payload


def test_lineage_rerun_precedes_sibling_seed_and_priority_census(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Amendment B, including the documented consequence of the key position.

    The new ``_lineage_rerun_rank`` sits between ``_recovery_rank`` and
    ``_priority_track_rank``, i.e. BEFORE the top-down gate key that carries
    Option A's sibling-seed arm (-1).  A lineage rerun therefore outranks the
    DL-089 measurement-sibling Q02 prerequisite seed as well as the
    priority-tracked census cell.  Option A's ordering is preserved *within*
    the gate key (seed still ahead of the census cell) — the OWNER note's
    "sibling seeds are unaffected" holds for their gate rank, not for their
    position relative to a lineage rerun.  Documented order:
    lineage rerun > sibling seed > census cell.
    """
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    assert farmctl.topdown_gate_priority_enabled()
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    rows = (
        ("census-cell", "OPT_CENSUS", {
            "schema": census.SCHEMA,
            "priority_track": True,
            census.FRONTIER_PRIORITY_MARKER: True,
        }),
        ("sibling-seed", "Q02", {
            "schema": farmctl.DL089_Q02_PREREQUISITE_SCHEMA,
            "priority_track": True,
            "priority_reason": "OWNER_P0_DL089_MATRIX_PREREQUISITE",
        }),
        ("lineage-q07-rerun", "Q07", _lineage_rerun_payload()),
    )
    with farmctl.connect(root) as conn:
        for rid, phase, payload in rows:
            _insert(
                conn, id=rid, kind="backtest", phase=phase, ea_id=f"QM5_{rid}",
                symbol="NZDUSD.DWX", setfile_path=f"{rid}.set", status="pending",
                attempt_count=0, payload_json=json.dumps(payload),
                created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert by_id["lineage-q07-rerun"]["_lineage_rerun_rank"] == 0
    assert by_id["sibling-seed"]["_lineage_rerun_rank"] == 1
    assert by_id["census-cell"]["_lineage_rerun_rank"] == 1
    assert [row["id"] for row in ordered] == [
        "lineage-q07-rerun",   # Amendment B key (0) wins before anything else
        "sibling-seed",        # Option A gate arm (-1) still beats the census
        "census-cell",
    ]


@pytest.mark.parametrize(
    ("rid", "phase", "payload"),
    [
        # priority_track without the append-only marker
        ("no-rerun-marker", "Q07", {"priority_track": True}),
        # the rerun marker without the priority mark
        ("not-priority", "Q07", {"append_only_rerun": True}),
        # priority_track present but not the JSON literal true
        ("priority-track-not-true", "Q07",
         {"append_only_rerun": True, "priority_track": 1}),
        # marker present but as text, neither true nor 1
        ("rerun-marker-is-text", "Q07",
         {"append_only_rerun": "true", "priority_track": True}),
        # outside the OWNER-enumerated Q02..Q09 span (Q02 joined 2026-09-03
        # 03:45Z for governed-recompile new-identity chains)
        # (a NEWS-phase row cannot be used here: the selector's WHERE clause
        # excludes it until bind-q09-plan has written the dispatch binding)
        # Q11 joined the admitted set on 2026-09-03 12:10Z (priority-tracked
        # Q11 rows are the minutes-long gate to the Q12 program row); Q13 is
        # the nearest phase that stays outside.
        ("q13-rerun", "Q13",
         {"append_only_rerun": True, "priority_track": True}),
        ("census-rerun", "OPT_CENSUS",
         {"append_only_rerun": True, "priority_track": True}),
        # quarantined lineage: the poison-pill override is honoured exactly as
        # _priority_track_rank honours it
        ("poison-pill", "Q07",
         {"append_only_rerun": True, "priority_track": True,
          "poison_pill_priority_override": 1}),
    ],
)
def test_lineage_rerun_rank_requires_all_four_exact_conditions(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
    rid: str, phase: str, payload: dict,
) -> None:
    """Only the exact marker set earns rank 0; every near-miss stays at 1."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        for item_id, item_phase, body in (
            (rid, phase, payload),
            ("exact-lineage", "Q07", _lineage_rerun_payload()),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=item_phase,
                ea_id=f"QM5_{item_id}", symbol="XAUUSD.DWX",
                setfile_path=f"{item_id}.set", status="pending", attempt_count=0,
                payload_json=json.dumps(body), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert by_id["exact-lineage"]["_lineage_rerun_rank"] == 0
    assert by_id[rid]["_lineage_rerun_rank"] == 1
    order = [row["id"] for row in ordered]
    assert order.index("exact-lineage") < order.index(rid)


def test_lineage_rerun_rank_tolerates_malformed_payload(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A pending row with an empty / non-JSON payload must neither abort the
    canonical claim-order query nor be lifted (the defect Option A shipped and
    then fixed: an unguarded json_extract raises 'malformed JSON' and kills the
    query for EVERY claimant).  ``payload_json`` is NOT NULL in the real
    schema, so the NULL case is covered by the SQL-only test below."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        for item_id, phase, raw_payload in (
            ("empty-payload", "Q07", ""),
            ("garbage-payload", "Q07", "not json"),
            ("exact-lineage", "Q07", json.dumps(_lineage_rerun_payload())),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="XTIUSD.DWX",
                setfile_path=f"{item_id}.set", status="pending", attempt_count=0,
                payload_json=raw_payload, created_at=now, updated_at=now,
            )
        conn.commit()
        # The query itself must execute; a malformed-JSON abort would raise here.
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    assert len(by_id) == 3
    assert by_id["exact-lineage"]["_lineage_rerun_rank"] == 0
    for item_id in ("empty-payload", "garbage-payload"):
        assert by_id[item_id]["_lineage_rerun_rank"] == 1
    assert ordered[0]["id"] == "exact-lineage"


def test_lineage_rerun_rank_sql_is_total_over_malformed_rows() -> None:
    """The CASE alone (as the claim path evaluates it) is total over garbage."""
    rank_sql = farmctl._lineage_rerun_rank_sql()
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE work_items(id TEXT, phase TEXT, payload_json TEXT)")
    conn.executemany(
        "INSERT INTO work_items VALUES (?, ?, ?)",
        [
            ("lineage", "Q07", json.dumps({
                "append_only_rerun": True, "priority_track": True,
            })),
            ("lineage-int-marker", "Q09", json.dumps({
                "append_only_rerun": 1, "priority_track": True,
            })),
            ("empty", "Q07", ""),
            ("garbage", "Q07", "not json"),
            ("null", "Q07", None),
            ("census", "OPT_CENSUS", "{}"),
        ],
    )
    ranks = dict(conn.execute(
        f"SELECT id, {rank_sql} AS r FROM work_items w"
    ).fetchall())
    conn.close()
    assert ranks["lineage"] == ranks["lineage-int-marker"] == 0
    assert ranks["empty"] == ranks["garbage"] == ranks["null"] == 1
    assert ranks["census"] == 1


def test_amendment_b_is_inert_when_topdown_flag_is_off(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Cold path unchanged: the alias is projected but never ordered on.

    The fixture is deliberately discriminating — under the cold age-weighted
    term a priority OPT_CENSUS cell (Q04 tier) sorts ahead of a priority Q03
    lineage rerun (one tier further upstream), and Amendment B inverts exactly
    that pair.
    """
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        for item_id, phase, payload in (
            ("census-cell", "OPT_CENSUS", {
                "schema": census.SCHEMA, "priority_track": True,
            }),
            ("lineage-q03-rerun", "Q03", _lineage_rerun_payload()),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="GDAXI.DWX",
                setfile_path=f"{item_id}.set", status="pending", attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()

        monkeypatch.delenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, raising=False)
        assert not farmctl.topdown_gate_priority_enabled()
        cold_sql = farmctl.pending_claim_order_sql()
        cold_order = [r["id"] for r in conn.execute(cold_sql).fetchall()]

        monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "0")
        assert farmctl.pending_claim_order_sql() == cold_sql  # only "1" arms it

        monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
        hot_sql = farmctl.pending_claim_order_sql()
        hot_order = [r["id"] for r in conn.execute(hot_sql).fetchall()]

    # The cold ORDER BY never mentions the new key (the alias stays in the
    # projection for diagnostics), so the pre-amendment order is preserved.
    assert "_lineage_rerun_rank" not in cold_sql.rsplit("ORDER BY", 1)[1]
    assert "_lineage_rerun_rank" in hot_sql.rsplit("ORDER BY", 1)[1]
    assert cold_order == ["census-cell", "lineage-q03-rerun"]
    assert hot_order == ["lineage-q03-rerun", "census-cell"]


def test_amendment_b_keeps_cheap_prerequisites_ahead_of_lineage_rerun(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """CEO merge decision 2026-09-03 on the key POSITION.

    ``_priority_track_rank`` ranks two seconds-cheap prerequisites at -1: an
    authorized append-only source-repair COMPILE_EA row and an exact Q01 smoke
    row.  The lineage-rerun key is ordered AFTER that column, so those
    prerequisites keep their precedence over an hours-long lineage rerun,
    while inside the priority tier the OWNER-documented order (lineage rerun
    > sibling seed > census cell) is unchanged (see the sibling-seed test).
    """
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    source_repair = {
        "compile_contract_version": farmctl.COMPILE_WORK_ITEM_CONTRACT,
        "append_only_source_repair": True,
        "compile_source_repair_contract_version": (
            farmctl.COMPILE_SOURCE_REPAIR_CONTRACT
        ),
        "compile_source_repair_authority": "router_ops_issue:test-task",
    }
    q01_smoke = {
        "priority_track": True,
        "q01_smoke_contract": farmctl.Q01_SMOKE_WORK_ITEM_CONTRACT,
    }
    with farmctl.connect(root) as conn:
        for item_id, kind, phase, payload in (
            ("compile-repair", farmctl.COMPILE_WORK_ITEM_KIND,
             farmctl.COMPILE_EA_PHASE, source_repair),
            ("q01-smoke", farmctl.Q01_SMOKE_WORK_ITEM_KIND, "Q01", q01_smoke),
            ("lineage-q08-rerun", "backtest", "Q08", _lineage_rerun_payload()),
        ):
            _insert(
                conn, id=item_id, kind=kind, phase=phase,
                ea_id=f"QM5_{item_id}", symbol="", setfile_path="",
                status="pending", attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()

    by_id = {row["id"]: row for row in ordered}
    # The prerequisites keep their -1 priority rank; only the key ORDER changed.
    assert by_id["compile-repair"]["_priority_track_rank"] == -1
    assert by_id["q01-smoke"]["_priority_track_rank"] == -1
    assert by_id["lineage-q08-rerun"]["_priority_track_rank"] == 0
    head = [row["id"] for row in ordered]
    assert set(head[:2]) == {"compile-repair", "q01-smoke"}
    assert head[2] == "lineage-q08-rerun"


def test_amendment_b_admits_governed_fresh_q02_seed_restart(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """CEO 2026-09-03: a ``seed-fresh-q02`` restart of a pre-binding source
    (QM5_10700/XAUUSD after the pre-0803 recompile) ranks with the lineage
    reruns; an unmarked fresh seed, a seed without its old-row binding and a
    fresh seed on any other phase do not."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    governed = {
        "fresh_q02_seed": True,
        "priority_track": True,
        "requalification_old_work_item_id": "6205ba82-old",
    }
    unmarked = {"fresh_q02_seed": True, "requalification_old_work_item_id": "x"}
    unbound = {"fresh_q02_seed": True, "priority_track": True}
    wrong_phase = dict(governed)
    census_cell = {"priority_track": True, "cell_key": "P:2021:buy_001"}
    with farmctl.connect(root) as conn:
        for item_id, phase, payload in (
            ("census-cell", "OPT_CENSUS", census_cell),
            ("seed-governed", "Q02", governed),
            ("seed-unmarked", "Q02", unmarked),
            ("seed-unbound", "Q02", unbound),
            ("seed-wrong-phase", "Q03", wrong_phase),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="", setfile_path="",
                status="pending", attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    by_id = {row["id"]: row for row in ordered}
    assert by_id["seed-governed"]["_lineage_rerun_rank"] == 0
    for item_id in ("seed-unmarked", "seed-unbound", "seed-wrong-phase", "census-cell"):
        assert by_id[item_id]["_lineage_rerun_rank"] == 1, item_id
    assert [row["id"] for row in ordered][0] == "seed-governed"


def test_amendment_b_admits_news_gate_parents_of_a_lineage(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """CEO 2026-09-03 11:30Z: the Q10_NEWS parent of a recompile lineage (an
    append-only rerun, or the service-minted replacement parent carrying
    ``supersedes_held_q09_work_item``) ranks with the lineage reruns instead of
    behind every frontier census cell; an ordinary news parent and an unmarked
    replacement do not."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    news = farmctl._NEWS_PHASE
    bound = {  # the claim order admits a news row only once bind-q09-plan sealed it
        "q09_binding_version": "q09-news-dispatch-binding/v1",
        "q09_run_plan_path": "D:/plan.json",
        "q09_run_plan_file_sha256": "0" * 64,
        "q09_dispatch_binding_sha256": "1" * 64,
    }
    rerun_parent = {**bound, "append_only_rerun": True, "priority_track": True}
    replacement = {**bound, "supersedes_held_q09_work_item": "77bd97c2-old", "priority_track": True}
    ordinary = {**bound, "priority_track": True}
    unmarked = {**bound, "supersedes_held_q09_work_item": "77bd97c2-old"}
    census_cell = {"priority_track": True, "cell_key": "P:2021:buy_001",
                   "opt_census_frontier_priority": True}
    with farmctl.connect(root) as conn:
        for item_id, phase, payload in (
            ("census-cell", "OPT_CENSUS", census_cell),
            ("news-rerun", news, rerun_parent),
            ("news-replacement", news, replacement),
            ("news-ordinary", news, ordinary),
            ("news-unmarked", news, unmarked),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="", setfile_path="",
                status="pending", attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    by_id = {row["id"]: row for row in ordered}
    assert by_id["news-rerun"]["_lineage_rerun_rank"] == 0
    assert by_id["news-replacement"]["_lineage_rerun_rank"] == 0
    for item_id in ("news-ordinary", "news-unmarked", "census-cell"):
        assert by_id[item_id]["_lineage_rerun_rank"] == 1, item_id
    head = [row["id"] for row in ordered]
    assert set(head[:2]) == {"news-rerun", "news-replacement"}
    assert head.index("census-cell") < head.index("news-ordinary")


def test_amendment_b_admits_priority_tracked_q11_rows(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """CEO 2026-09-03 12:10Z: a priority-tracked Q11 row ranks with the lineage
    reruns; an unmarked Q11 row and a priority-tracked Q05 row do not."""
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        for item_id, phase, payload in (
            ("census-cell", "OPT_CENSUS", {"priority_track": True, "cell_key": "P:2021:buy_001",
                                            "opt_census_frontier_priority": True}),
            ("q11-priority", "Q11", {"priority_track": True}),
            ("q11-unmarked", "Q11", {}),
            ("q05-priority", "Q05", {"priority_track": True}),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="", setfile_path="",
                status="pending", attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    by_id = {row["id"]: row for row in ordered}
    assert by_id["q11-priority"]["_lineage_rerun_rank"] == 0
    for item_id in ("q11-unmarked", "q05-priority", "census-cell"):
        assert by_id[item_id]["_lineage_rerun_rank"] == 1, item_id
    assert [row["id"] for row in ordered][0] == "q11-priority"


def test_amendment_b_admits_news_expansion_child_of_a_lineage_parent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Proposal C (docs/ops/evidence/
    2026-09-03_newsgate_expansion_forensics.md section 4): a Q10_NEWS expansion
    child (``news_expansion_of_work_item`` set) whose PARENT row is itself a
    lineage row ranks with the lineage reruns; a child of an ordinary parent
    does not, and a frontier census cell still sorts before that ordinary child.

    Children inherit ``priority_track`` from their source via
    PROMOTION_QUEUE_CONTEXT_PAYLOAD_KEYS, so the child's own flag is what the arm
    reads (verified on the live DB: QM5_10700/XAUUSD child c0faeb48 carries
    priority_track=true; parent fe33550e carries supersedes_held_q09_work_item).
    The children here carry NO ``append_only_rerun`` marker so that rank 0 can
    only come from the new parent-is-lineage arm, not the existing rerun arm.
    """
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, "1")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-03T00:00:00+00:00"
    news = farmctl._NEWS_PHASE
    bound = {  # a Q10_NEWS row is only claimable once bind-q09-plan sealed it
        "q09_binding_version": "q09-news-dispatch-binding/v1",
        "q09_run_plan_path": "D:/plan.json",
        "q09_run_plan_file_sha256": "0" * 64,
        "q09_dispatch_binding_sha256": "1" * 64,
    }
    # Parents are done REVIEW_REQUIRED sources (mirrors the live farm): not
    # pending, so they never enter the ordering, only the child EXISTS-by-id.
    lineage_parent = {
        "supersedes_held_q09_work_item": "77bd97c2-old",
        "priority_track": True,
    }
    ordinary_parent = {"priority_track": True}  # priority, but no lineage marker
    child_of_lineage = {
        **bound,
        "news_expansion_of_work_item": "parent-lineage",
        "priority_track": True,
    }
    child_of_ordinary = {
        **bound,
        "news_expansion_of_work_item": "parent-ordinary",
        "priority_track": True,
    }
    census_cell = {
        "priority_track": True,
        "cell_key": "P:2021:buy_001",
        "opt_census_frontier_priority": True,
    }
    with farmctl.connect(root) as conn:
        for item_id, phase, status, verdict, payload in (
            ("parent-lineage", news, "done", "REVIEW_REQUIRED", lineage_parent),
            ("parent-ordinary", news, "done", "REVIEW_REQUIRED", ordinary_parent),
            ("child-of-lineage", news, "pending", None, child_of_lineage),
            ("child-of-ordinary", news, "pending", None, child_of_ordinary),
            ("census-cell", "OPT_CENSUS", "pending", None, census_cell),
        ):
            _insert(
                conn, id=item_id, kind="backtest", phase=phase,
                ea_id=f"QM5_{item_id}", symbol="", setfile_path="",
                status=status, verdict=verdict, attempt_count=0,
                payload_json=json.dumps(payload), created_at=now, updated_at=now,
            )
        conn.commit()
        ordered = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
    by_id = {row["id"]: row for row in ordered}
    # the done parents are excluded from the pending ordering
    assert set(by_id) == {"child-of-lineage", "child-of-ordinary", "census-cell"}
    # a child of a lineage parent ranks 0
    assert by_id["child-of-lineage"]["_lineage_rerun_rank"] == 0
    # a child of an ordinary (non-lineage) parent ranks 1
    assert by_id["child-of-ordinary"]["_lineage_rerun_rank"] == 1
    assert by_id["census-cell"]["_lineage_rerun_rank"] == 1
    head = [row["id"] for row in ordered]
    # the lineage child leads; the frontier census cell still sorts before the
    # ordinary child (both rank 1 on the lineage key; the census wins the
    # top-down gate key: OPT_CENSUS=0 vs Q10_NEWS=2).
    assert head[0] == "child-of-lineage"
    assert head.index("census-cell") < head.index("child-of-ordinary")
