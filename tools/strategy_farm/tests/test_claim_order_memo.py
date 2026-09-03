"""Pending-claim-order per-process memo (farmctl.execute_pending_claim_order).

The memo is a pure cost optimization over ``pending_claim_order_sql()``: it must
return the byte-identical ordered rows the raw query returns, reuse a result
only while a fingerprint proves the inputs are unchanged and no ``_age_weeks``
boundary can have been crossed, and fall back to the plain query on any doubt.

Covered:
  * equivalence (miss AND hit) on a synthetic queue exercising every rank branch
    (universe_expansion, recovery, lineage_rerun, priority_track, census
    sub-ranks, phase rank, compile/q01/dl089 prerequisites, basket/diagnostic/
    winner/asset tie-breaks) under BOTH the cold and top-down selectors;
  * cross-connection reuse keyed on the db file;
  * invalidation on every fingerprinted change (insert, in-place edit, hold,
    supersede, quarantine, PASS verdict);
  * the age-week-boundary cap on the memo lifetime;
  * the TTL<=0 kill switch and the in-memory bypass;
  * the v4 readiness rule (no bare v3 phase literals in the memo SQL).
"""
from __future__ import annotations

import datetime as dt
import inspect
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import farmctl


def _insert(conn: sqlite3.Connection, **cols: object) -> None:
    keys = list(cols)
    conn.execute(
        f"INSERT INTO work_items({','.join(keys)}) "
        f"VALUES ({','.join('?' for _ in keys)})",
        tuple(cols[k] for k in keys),
    )


def _row(
    conn: sqlite3.Connection,
    rid: str,
    phase: str,
    ea: str,
    sym: str,
    payload: object,
    now: str,
    *,
    kind: str = "backtest",
    status: str = "pending",
    verdict: object = None,
) -> None:
    _insert(
        conn,
        id=rid,
        kind=kind,
        phase=phase,
        ea_id=ea,
        symbol=sym,
        setfile_path=f"{rid}.set",
        status=status,
        verdict=verdict,
        attempt_count=0,
        payload_json=json.dumps(payload) if isinstance(payload, dict) else payload,
        created_at=now,
        updated_at=now,
    )


def _seed_all_branches(conn: sqlite3.Connection, now: str) -> None:
    """One row per rank branch the ordering can take."""
    _row(conn, "universe", "Q02", "QM5_U", "EURUSD.DWX",
         {"universe_expansion": True}, now)
    _row(conn, "recovery", "Q02", "QM5_R", "EURUSD.DWX",
         {"recovery_class": "stranded_infra_fail"}, now)
    _row(conn, "lineage", "Q05", "QM5_L", "EURUSD.DWX",
         {"append_only_rerun": True, "priority_track": True}, now)
    _row(conn, "prio_q04", "Q04", "QM5_P", "EURUSD.DWX",
         {"priority_track": True}, now)
    _row(conn, "census_frontier", "OPT_CENSUS", "QM5_CF_opt", "USDJPY.DWX",
         {"priority_track": True, "opt_census_frontier_priority": True,
          "opt_census_stage": "WF_COMBO", "program_id": "PROG1", "arm": "ARM1",
          "year": 2021, "opt_from_date": "2021.01.01", "opt_to_date": "2021.12.31"},
         now)
    _row(conn, "census_plain", "OPT_CENSUS", "QM5_CP_opt", "USDJPY.DWX",
         {"opt_from_date": "2021.01.01", "opt_to_date": "2021.12.31"}, now)
    _row(conn, "dl089_prereq", "Q02", "QM5_D", "EURUSD.DWX",
         {"schema": farmctl.DL089_Q02_PREREQUISITE_SCHEMA, "priority_track": True},
         now)
    _row(conn, "compile_prereq", "COMPILE_EA", "QM5_C", "EURUSD.DWX",
         {"compile_contract_version": farmctl.COMPILE_WORK_ITEM_CONTRACT,
          "bound_build_task_id": "build-1"},
         now, kind=farmctl.COMPILE_WORK_ITEM_KIND)
    _row(conn, "q01_smoke", "Q01", "QM5_S", "EURUSD.DWX",
         {"q01_smoke_contract": farmctl.Q01_SMOKE_WORK_ITEM_CONTRACT},
         now, kind=farmctl.Q01_SMOKE_WORK_ITEM_KIND)
    _row(conn, "harness", "HARNESS_PP_FIXTURE", "QM5_H", "EURUSD.DWX", {}, now)
    _row(conn, "basket_q02", "Q02", "QM5_B", "EURUSD.DWX",
         {"portfolio_scope": "basket"}, now)
    _row(conn, "diagnostic", "Q08", "QM5_DG", "EURUSD.DWX",
         {"diagnostic_non_admission": 1, "diagnostic_queue_rank": 5}, now)
    # winner: a done PASS for QM5_WIN plus a pending row for the same ea
    _row(conn, "winner_done", "Q10", "QM5_WIN", "XAUUSD.DWX", {}, now,
         status="done", verdict="PASS")
    _row(conn, "winner_pending", "Q02", "QM5_WIN", "XAUUSD.DWX", {}, now)
    # asset-class variety
    _row(conn, "asset_metal", "Q02", "QM5_M", "XAUUSD.DWX", {}, now)
    _row(conn, "asset_index", "Q02", "QM5_I", "SP500.DWX", {}, now)
    _row(conn, "asset_energy", "Q02", "QM5_E", "XTIUSD.DWX", {}, now)
    _row(conn, "asset_fx", "Q02", "QM5_F", "GBPUSD.DWX", {}, now)
    _row(conn, "plain_q03", "Q03", "QM5_3", "EURUSD.DWX", {}, now)
    # active row (referenced by the OPT_CENSUS sub-rank subqueries; never claimed)
    _row(conn, "active_census", "OPT_CENSUS", "QM5_AC_opt", "USDJPY.DWX",
         {"program_id": "PROG1"}, now, status="active")
    # excluded rows: hold / supersede / quarantine
    _row(conn, "held", "Q02", "QM5_HELD", "EURUSD.DWX", {}, now)
    _row(conn, "superseded", "Q02", "QM5_SUP", "EURUSD.DWX", {}, now)
    _row(conn, "quarantined", "Q02", "QM5_QU", "EURUSD.DWX", {}, now)
    conn.execute(
        "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
        "release_on_restart,created_at,updated_at) VALUES(?,?,?,?,?,?,?)",
        ("held", "TEST_HOLD", "test", 1, 0, now, now),
    )
    conn.execute(
        "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,"
        "reason,source_encoding,recorded_by,recorded_at) VALUES(?,?,?,?,?,?)",
        ("superseded", "winner_pending", "test", "test/v1", "tester", now),
    )
    conn.execute(
        "INSERT INTO poison_pill_quarantine(ea_id,symbol,phase,active,verdict_reason,"
        "consecutive_failures,successes_ever,quarantined_at,updated_at) "
        "VALUES(?,?,?,?,?,?,?,?,?)",
        ("QM5_QU", "EURUSD.DWX", "Q02", 1, "test", 3, 0, now, now),
    )
    conn.commit()


def _raw_ids(conn: sqlite3.Connection) -> list[str]:
    return [r["id"] for r in conn.execute(farmctl.pending_claim_order_sql()).fetchall()]


@pytest.fixture(autouse=True)
def _clear_cache():
    farmctl._CLAIM_ORDER_CACHE.clear()
    farmctl._reset_claim_order_pollers()
    yield
    farmctl._CLAIM_ORDER_CACHE.clear()
    farmctl._reset_claim_order_pollers()


@pytest.mark.parametrize("topdown", ["0", "1"])
def test_memo_equivalence_all_rank_branches(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, topdown: str
) -> None:
    monkeypatch.setenv(farmctl.TOPDOWN_GATE_PRIORITY_ENV, topdown)
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "5000")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        _seed_all_branches(conn, now)
        raw = conn.execute(farmctl.pending_claim_order_sql()).fetchall()
        raw_ids = [r["id"] for r in raw]

        farmctl._CLAIM_ORDER_CACHE.clear()
        miss = farmctl.execute_pending_claim_order(conn)   # MISS -> builds
        hit = farmctl.execute_pending_claim_order(conn)    # HIT (no mutation)

        assert [r["id"] for r in miss] == raw_ids
        assert [r["id"] for r in hit] == raw_ids
        # full-row equivalence, not only ids
        assert [tuple(r) for r in miss] == [tuple(r) for r in raw]
        # the excluded rows never appear in either
        for excluded in ("held", "superseded", "quarantined", "active_census"):
            assert excluded not in raw_ids
        # the hit is a genuine reuse of the built object
        entry = next(iter(farmctl._CLAIM_ORDER_CACHE.values()))
        assert hit is entry.rows


def test_cross_connection_reuse_same_db(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "5000")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    with farmctl.connect(root) as seed:
        _seed_all_branches(seed, now)
    farmctl._CLAIM_ORDER_CACHE.clear()
    with farmctl.connect(root) as c1, farmctl.connect(root) as c2:
        built = farmctl.execute_pending_claim_order(c1)   # MISS on c1
        reused = farmctl.execute_pending_claim_order(c2)  # HIT on c2 (same file)
        assert reused is built


def test_memo_invalidated_by_every_fingerprinted_change(
    tmp_path: Path, monkeypatch
) -> None:
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "5000")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    later = "2026-09-01T00:00:05+00:00"
    with farmctl.connect(root) as conn:
        _seed_all_branches(conn, now)

        def warm() -> object:
            farmctl._CLAIM_ORDER_CACHE.clear()
            first = farmctl.execute_pending_claim_order(conn)
            assert farmctl.execute_pending_claim_order(conn) is first  # HIT
            return first

        # (1) insert a new pending row
        prev = warm()
        _row(conn, "new_pending", "Q02", "QM5_N", "EURUSD.DWX", {}, later)
        conn.commit()
        after = farmctl.execute_pending_claim_order(conn)
        assert after is not prev
        assert "new_pending" in [r["id"] for r in after]

        # (2) in-place payload edit bumps updated_at
        prev = warm()
        conn.execute(
            "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=?",
            (json.dumps({"priority_track": True}), later, "plain_q03"),
        )
        conn.commit()
        assert farmctl.execute_pending_claim_order(conn) is not prev

        # (3) add a hold -> row disappears and cache busts
        prev = warm()
        conn.execute(
            "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
            "release_on_restart,created_at,updated_at) VALUES(?,?,?,?,?,?,?)",
            ("prio_q04", "H", "r", 1, 0, later, later),
        )
        conn.commit()
        after = farmctl.execute_pending_claim_order(conn)
        assert after is not prev
        assert "prio_q04" not in [r["id"] for r in after]

        # (4) add a supersede
        prev = warm()
        conn.execute(
            "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id,"
            "reason,source_encoding,recorded_by,recorded_at) VALUES(?,?,?,?,?,?)",
            ("basket_q02", None, "r", "enc/v1", "t", later),
        )
        conn.commit()
        assert farmctl.execute_pending_claim_order(conn) is not prev

        # (5) add a quarantine
        prev = warm()
        conn.execute(
            "INSERT INTO poison_pill_quarantine(ea_id,symbol,phase,active,"
            "verdict_reason,consecutive_failures,successes_ever,quarantined_at,"
            "updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
            ("QM5_M", "XAUUSD.DWX", "Q02", 1, "r", 3, 0, later, later),
        )
        conn.commit()
        assert farmctl.execute_pending_claim_order(conn) is not prev

        # (6) a fresh PASS verdict changes _winner_rank
        prev = warm()
        _row(conn, "pass_new", "Q10", "QM5_NEWWIN", "XAUUSD.DWX", {}, later,
             status="done", verdict="PASS")
        conn.commit()
        assert farmctl.execute_pending_claim_order(conn) is not prev


def test_age_week_boundary_caps_memo_lifetime(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "5000")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    week = farmctl._WEEK_SECONDS
    wall = 1_000_000.0
    # one pending row two seconds short of its next _age_weeks boundary
    created = dt.datetime.fromtimestamp(wall - (week - 2.0), tz=dt.UTC).isoformat()
    with farmctl.connect(root) as conn:
        _row(conn, "near_flip", "Q02", "QM5_A", "EURUSD.DWX", {}, created)
        conn.commit()

        built = farmctl.execute_pending_claim_order(
            conn, monotonic=lambda: 100.0, wall_clock=lambda: wall
        )
        entry = next(iter(farmctl._CLAIM_ORDER_CACHE.values()))
        # TTL would allow +5.0s; the flip in 2.0s caps expiry to +2.0s.
        assert entry.expiry_monotonic == pytest.approx(102.0, abs=1e-6)

        # before the cap -> HIT (same object)
        assert farmctl.execute_pending_claim_order(
            conn, monotonic=lambda: 101.5, wall_clock=lambda: wall
        ) is built
        # after the cap -> MISS (recompute, fresh object)
        assert farmctl.execute_pending_claim_order(
            conn, monotonic=lambda: 103.0, wall_clock=lambda: wall
        ) is not built


def test_far_from_boundary_uses_full_ttl(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "5000")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    week = farmctl._WEEK_SECONDS
    wall = 1_000_000.0
    created = dt.datetime.fromtimestamp(wall - week / 2.0, tz=dt.UTC).isoformat()
    with farmctl.connect(root) as conn:
        _row(conn, "mid_week", "Q02", "QM5_A", "EURUSD.DWX", {}, created)
        conn.commit()
        farmctl.execute_pending_claim_order(
            conn, monotonic=lambda: 100.0, wall_clock=lambda: wall
        )
        entry = next(iter(farmctl._CLAIM_ORDER_CACHE.values()))
        assert entry.expiry_monotonic == pytest.approx(105.0, abs=1e-6)


def test_ttl_zero_disables_memo(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv(farmctl.CLAIM_ORDER_CACHE_TTL_MS_ENV, "0")
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-09-01T00:00:00+00:00"
    with farmctl.connect(root) as conn:
        _seed_all_branches(conn, now)
        raw_ids = _raw_ids(conn)
        farmctl._CLAIM_ORDER_CACHE.clear()
        r1 = farmctl.execute_pending_claim_order(conn)
        r2 = farmctl.execute_pending_claim_order(conn)
        assert not farmctl._CLAIM_ORDER_CACHE      # nothing cached
        assert r1 is not r2                          # fresh every call
        assert [r["id"] for r in r1] == raw_ids


def test_conn_key_none_for_in_memory() -> None:
    mem = sqlite3.connect(":memory:")
    try:
        assert farmctl._claim_order_conn_key(mem) is None
    finally:
        mem.close()


def test_memo_source_has_no_bare_v3_phase_literal() -> None:
    # v4 readiness rule: the memo introduces no *_sql helper and no bare v3
    # phase literal; pending_claim_order_sql (unchanged) remains the only
    # phase-aware SQL and is guarded by its own tests.
    src = "".join(
        inspect.getsource(fn)
        for fn in (
            farmctl.execute_pending_claim_order,
            farmctl._claim_order_data_version,
            farmctl._claim_order_conn_key,
            farmctl._seconds_to_earliest_age_flip,
        )
    )
    for banned in ("Q10A", "Q10B", "'Q09'", "'Q10'", "'P2'", "'P3'", "'P4'"):
        assert banned not in src
