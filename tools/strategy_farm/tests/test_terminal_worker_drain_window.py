"""Bounded drain window for headroom-starved priority rows (2026-09-03, CEO).

Claim-selection-only reorder: a qualifying heavy priority-tracked row that has
been headroom-skipped past the trigger age parks the fleet's NEW short-row
claims (running rows finish, COMPILE_EA keeps flowing) until free RAM organically
reaches the row's reservation + floor, then releases.  Evidence:
docs/ops/evidence/2026-09-03_index_tick_admission_audit.md.

No reservation constant, RAM latch, census floor or tester ledger is touched;
these tests assert the pure predicates, the JSON state machine, and the
postprocess wrapper only.
"""
import json
import sqlite3
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402

tw = terminal_worker
_FZ = frozenset()


@pytest.fixture(autouse=True)
def _isolate_env(monkeypatch):
    # Keep the measured-RAM admission override out of the reservation resolver so
    # the index/basket flat classes are deterministic, and clear the drain env.
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    monkeypatch.delenv("QM_DRAIN_WINDOW", raising=False)
    monkeypatch.setenv("QM_TEST_TOTAL_RAM_GB", "80.0")


def _index_item(item_id="IDX1", ea_id="QM5_10815", phase="Q02"):
    return {"id": item_id, "ea_id": ea_id, "phase": phase, "symbol": "GDAXI.DWX"}


def _cand(item_id="IDX1", reservation=44.0, floor=14.0, ea_id="E"):
    return {
        "item_id": item_id,
        "ea_id": ea_id,
        "reservation_gb": reservation,
        "floor_gb": floor,
    }


# --- pure qualification predicate ----------------------------------------

def test_predicate_winnable_heavy_priority_qualifies():
    # reservation+floor = 58 > free 18, and 58 <= 80 - 10 baseline = 70
    assert tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=18.0, host_total_gb=80.0
    )


def test_predicate_unwinnable_row_never_qualifies():
    # Even at the reduced armed-row floor (4 GB), 44 + 4 = 48 > 50 - 10 = 40, so
    # a fully drained 50 GB host cannot satisfy it -> reservation-tuning matter.
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=18.0, host_total_gb=50.0
    )


def test_predicate_index_row_now_qualifies_on_drained_63gb_host():
    # DRAINED-FLEET floor (audit 2026-09-03): the 44 GB single_index_tick row was
    # unwinnable under the 14 GB floor (44 + 14 = 58 > 63.1 - 10 = 53.1) but the
    # reduced armed-row floor makes it winnable (44 + 4 = 48 <= 53.1).
    assert tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=12.0, host_total_gb=63.1
    )
    # The boundary tracks the reduced floor, not the 14 GB one: 44 + 4 = 48
    # exactly equals 58 - 10, still winnable; one GB smaller host is not.
    assert tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=12.0, host_total_gb=58.0
    )
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=12.0, host_total_gb=57.0
    )


def test_drain_armed_row_floor_constant():
    assert tw.DRAIN_ARMED_ROW_FLOOR_GB == 4.0


def test_predicate_already_claimable_not_qualifying():
    # free RAM already covers reservation+floor -> the normal gate admits it.
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=60.0, host_total_gb=80.0
    )


def test_predicate_light_row_below_heaviness_floor_not_qualifying():
    # An 8 GB ordinary reservation is below DRAIN_WINDOW_MIN_RESERVATION_GB even
    # when free RAM is scarce; only genuinely heavy classes may drain the fleet.
    assert not tw._drain_row_is_qualifying(
        reservation_gb=8.0, floor_gb=14.0, free_ram_gb=5.0, host_total_gb=80.0
    )


def test_predicate_unknown_host_total_fails_closed():
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=18.0,
        host_total_gb=float("inf"),
    )


# --- candidate derivation from a work-item row ----------------------------

def test_candidate_index_priority_row_qualifies():
    cand = tw._drain_candidate_from_row(
        _index_item(), {"priority_track": True}, 18.0, 80.0, _FZ
    )
    assert cand is not None
    assert cand["item_id"] == "IDX1"
    assert cand["ram_class"] == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert cand["reservation_gb"] == 44.0
    assert cand["floor_gb"] == 14.0


def test_candidate_non_priority_heavy_row_never_qualifies():
    # Behavior: a non-priority heavy row never opens a drain -> yields no candidate.
    assert tw._drain_candidate_from_row(
        _index_item(), {}, 18.0, 80.0, _FZ
    ) is None
    assert tw._drain_candidate_from_row(
        _index_item(), {"priority_track": False}, 18.0, 80.0, _FZ
    ) is None


def test_candidate_index_row_unwinnable_on_small_host_is_none():
    # 44 + 4 (reduced armed-row floor) = 48 > 50 - 10 = 40: unwinnable even on a
    # fully drained 50 GB host, so no drain candidate is derived.
    assert tw._drain_candidate_from_row(
        _index_item(), {"priority_track": True}, 18.0, 50.0, _FZ
    ) is None


def test_candidate_index_row_qualifies_on_drained_63gb_host():
    # The real audit host: a 44 GB index row on a 63 GB host, now winnable
    # because the armed row is admitted at the reduced 4 GB floor.  The row's own
    # class floor (14 GB) is still reported unchanged -- only admission changes.
    cand = tw._drain_candidate_from_row(
        _index_item(), {"priority_track": True}, 12.0, 63.1, _FZ
    )
    assert cand is not None
    assert cand["ram_class"] == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert cand["reservation_gb"] == 44.0
    assert cand["floor_gb"] == 14.0


# --- short-row blocking ---------------------------------------------------

def test_short_rows_blocked_while_open():
    for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "OPT_CENSUS"):
        assert tw._drain_blocks_candidate({"id": "X", "phase": phase}, "IDX1")


def test_armed_heavy_row_is_never_blocked():
    assert not tw._drain_blocks_candidate({"id": "IDX1", "phase": "Q02"}, "IDX1")


def test_compiles_unaffected_by_drain():
    assert not tw._drain_blocks_candidate(
        {"id": "C1", "phase": tw.farmctl.COMPILE_EA_PHASE}, "IDX1"
    )


def test_longrun_phases_not_treated_as_short_rows():
    for phase in ("Q07", "Q08", "Q09_NEWS", "Q10_NEWS"):
        assert not tw._drain_blocks_candidate({"id": "L", "phase": phase}, "IDX1")


# --- state machine: open only after the trigger age ----------------------

def test_drain_opens_only_after_trigger_age():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    t0 = 1_000_000.0
    cand = _cand()
    state = tw._empty_drain_state()

    # First observation: tracker recorded, no drain yet.
    state, events = tw._drain_evaluate(state, now_epoch=t0, qualifying_candidate=cand)
    assert state["active"] is None
    assert events == []
    assert "IDX1" in state["tracker"]

    # Still below the trigger age: no open.
    state2, events2 = tw._drain_evaluate(
        state, now_epoch=t0 + trig - 1.0, qualifying_candidate=cand
    )
    assert state2["active"] is None
    assert not events2

    # At/after the trigger age: the drain opens with a structured event.
    state3, events3 = tw._drain_evaluate(
        state2, now_epoch=t0 + trig, qualifying_candidate=cand
    )
    assert state3["active"] is not None
    assert state3["active"]["item_id"] == "IDX1"
    assert [e["event"] for e in events3] == ["drain_window_open"]
    assert events3[0]["reservation_gb"] == 44.0


def test_drain_active_now_honours_max_window():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    maxw = tw.DRAIN_WINDOW_MAX_MIN * 60.0
    t0 = 2_000_000.0
    seeded = {"IDX1": {"first_skipped_epoch": t0}}
    state = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": seeded,
    }
    state, _ = tw._drain_evaluate(
        state, now_epoch=t0 + trig, qualifying_candidate=_cand()
    )
    assert state["active"] is not None
    # Inside the window the fleet blocks; past DRAIN_WINDOW_MAX_MIN it does not,
    # so ordinary short rows are admitted again after expiry.
    active_open, item_open = tw._drain_active_now(state, t0 + trig)
    assert (active_open, item_open) == (True, "IDX1")
    active_late, item_late = tw._drain_active_now(state, t0 + trig + maxw)
    assert (active_late, item_late) == (False, None)


def test_expiry_emits_event_and_sets_cooldown():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    maxw = tw.DRAIN_WINDOW_MAX_MIN * 60.0
    cool = tw.DRAIN_COOLDOWN_MIN * 60.0
    t0 = 3_000_000.0
    state = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"IDX1": {"first_skipped_epoch": t0}},
    }
    state, _ = tw._drain_evaluate(
        state, now_epoch=t0 + trig, qualifying_candidate=_cand()
    )
    opened_at = state["active"]["opened_epoch"]
    expired, events = tw._drain_evaluate(
        state, now_epoch=opened_at + maxw + 1.0, qualifying_candidate=_cand()
    )
    assert expired["active"] is None
    assert [e["event"] for e in events] == ["drain_window_expired"]
    assert expired["cooldown_until_epoch"] == pytest.approx(
        opened_at + maxw + 1.0 + cool
    )


# --- heavy row claims when free RAM suffices ------------------------------

def test_heavy_row_claim_closes_drain_and_sets_cooldown():
    cool = tw.DRAIN_COOLDOWN_MIN * 60.0
    now = 4_000_000.0
    active_state = {
        "version": 1,
        "active": {
            "item_id": "IDX1",
            "ea_id": "E",
            "reservation_gb": 44.0,
            "floor_gb": 14.0,
            "opened_epoch": now - 500.0,
            "opened_iso": tw._drain_iso(now - 500.0),
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    }
    closed, events = tw._drain_note_claim(
        active_state, now_epoch=now, claimed_item_id="IDX1"
    )
    assert closed["active"] is None
    assert [e["event"] for e in events] == ["drain_window_claim"]
    assert closed["cooldown_until_epoch"] == pytest.approx(now + cool)


def test_note_claim_ignores_unrelated_claim():
    now = 4_100_000.0
    active_state = {
        "version": 1,
        "active": {"item_id": "IDX1", "opened_epoch": now - 10.0},
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    }
    same, events = tw._drain_note_claim(
        active_state, now_epoch=now, claimed_item_id="OTHER"
    )
    assert events == []
    assert same is active_state  # unchanged


def test_free_ram_suffices_makes_row_claimable_not_qualifying():
    # Once free RAM >= reservation+floor the heavy row is no longer a drain
    # candidate: the normal RAM gate admits it (that is how it "claims").
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=58.0, host_total_gb=80.0
    )


# --- cooldown blocks a second drain --------------------------------------

def test_cooldown_blocks_second_drain_then_allows_after():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    now = 5_000_000.0
    cooldown_until = now + tw.DRAIN_COOLDOWN_MIN * 60.0
    # A fully aged tracker, but still inside the cooldown window.
    within = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": cooldown_until,
        "tracker": {"IDX1": {"first_skipped_epoch": now - trig - 10.0}},
    }
    state_within, events_within = tw._drain_evaluate(
        within, now_epoch=now, qualifying_candidate=_cand()
    )
    assert state_within["active"] is None
    assert not events_within

    after = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": cooldown_until,
        "tracker": {"IDX1": {"first_skipped_epoch": now - trig - 10.0}},
    }
    state_after, events_after = tw._drain_evaluate(
        after, now_epoch=cooldown_until + 1.0, qualifying_candidate=_cand()
    )
    assert state_after["active"] is not None
    assert [e["event"] for e in events_after] == ["drain_window_open"]


# --- only one heavy row holds a drain ------------------------------------

def test_only_one_heavy_row_holds_a_drain():
    now = 6_000_000.0
    active_state = {
        "version": 1,
        "active": {"item_id": "IDX1", "opened_epoch": now - 10.0},
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    }
    # A different qualifying heavy row is present, but a drain is already held.
    state, events = tw._drain_evaluate(
        active_state, now_epoch=now, qualifying_candidate=_cand(item_id="IDX2")
    )
    assert state["active"]["item_id"] == "IDX1"
    assert not events


# --- kill switch ----------------------------------------------------------

def test_kill_switch_restores_old_behaviour(monkeypatch):
    monkeypatch.setenv("QM_DRAIN_WINDOW", "0")
    assert tw._drain_window_enabled() is False
    monkeypatch.setenv("QM_DRAIN_WINDOW", "1")
    assert tw._drain_window_enabled() is True
    monkeypatch.delenv("QM_DRAIN_WINDOW", raising=False)
    assert tw._drain_window_enabled() is True  # default on


# --- state file: round trip, atomicity, fail-open ------------------------

def test_state_file_round_trip(tmp_path):
    state = {
        "version": 1,
        "active": {"item_id": "IDX1", "ea_id": "E", "opened_epoch": 123.0},
        "cooldown_until_epoch": 456.0,
        "tracker": {"IDX1": {"first_skipped_epoch": 100.0}},
    }
    assert tw._write_drain_state_atomic(tmp_path, state) is True
    assert tw._drain_state_path(tmp_path).is_file()
    back = tw._load_drain_state(tmp_path)
    assert back["active"]["item_id"] == "IDX1"
    assert back["cooldown_until_epoch"] == 456.0
    assert back["tracker"]["IDX1"]["first_skipped_epoch"] == 100.0


def test_write_leaves_no_temp_file(tmp_path):
    tw._write_drain_state_atomic(tmp_path, tw._empty_drain_state())
    leftovers = list((tmp_path / "state").glob("drain_window.json.*"))
    assert leftovers == []


def test_load_missing_and_corrupt_fail_open(tmp_path):
    assert tw._load_drain_state(tmp_path) == tw._empty_drain_state()
    path = tw._drain_state_path(tmp_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("not json{", encoding="utf-8")
    assert tw._load_drain_state(tmp_path) == tw._empty_drain_state()


# --- postprocess wrapper (no DB needed for the claim-close branch) --------

def test_postprocess_closes_drain_on_armed_claim(tmp_path, capsys):
    now = 7_000_000.0
    seeded = {
        "version": 1,
        "active": {
            "item_id": "IDX1",
            "ea_id": "E",
            "opened_epoch": now - 300.0,
            "opened_iso": tw._drain_iso(now - 300.0),
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    }
    tw._write_drain_state_atomic(tmp_path, seeded)
    claim_result = {"claimed": True, "item": {"id": "IDX1"}}
    tw._drain_run_postprocess(
        tmp_path,
        "T1",
        claim_result,
        now_epoch=now,
        free_ram_gb=55.0,
        host_total_gb=80.0,
        multisym_ids=_FZ,
    )
    after = tw._load_drain_state(tmp_path)
    assert after["active"] is None
    assert after["cooldown_until_epoch"] == pytest.approx(
        now + tw.DRAIN_COOLDOWN_MIN * 60.0
    )
    emitted = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.strip().startswith("{")
    ]
    assert any(e.get("event") == "drain_window_claim" for e in emitted)


def test_scan_candidate_fails_open_without_db(tmp_path):
    assert tw._drain_scan_candidate(
        tmp_path, free_ram_gb=18.0, host_total_gb=80.0, multisym_ids=_FZ
    ) is None


# --- fleet-drained probe (real DB) ---------------------------------------
# The DRAINED-FLEET floor (audit 2026-09-03) drops the armed row's post-
# reservation floor to DRAIN_ARMED_ROW_FLOOR_GB only when no OTHER backtest
# tester is running; COMPILE_EA rows use <1 GB and never count.

def _insert_row(conn, item_id, phase, *, status="pending", kind="backtest"):
    now = "2026-09-03T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,
                               verdict,evidence_path,payload_json,created_at,
                               updated_at)
        VALUES(?,?,?,?,?, 'x.set', ?, NULL, NULL, '{}', ?, ?)
        """,
        (item_id, kind, phase, f"QM5_{item_id}", "GDAXI.DWX", status, now, now),
    )


def test_no_other_tester_active_on_empty_and_pending_fleet(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        assert tw._no_other_backtest_tester_active(conn) is True
        # A pending row is not a running tester.
        _insert_row(conn, "p1", "Q02", status="pending")
        assert tw._no_other_backtest_tester_active(conn) is True
        conn.commit()


def test_no_other_tester_active_false_when_backtest_running(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_row(conn, "a1", "Q02", status="active")
        assert tw._no_other_backtest_tester_active(conn) is False
        conn.commit()


def test_no_other_tester_active_ignores_active_compile(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        # An active COMPILE_EA row never counts as a running tester.
        _insert_row(conn, "c1", tw.farmctl.COMPILE_EA_PHASE, status="active")
        assert tw._no_other_backtest_tester_active(conn) is True
        # By compile KIND too (phase-agnostic).
        _insert_row(
            conn, "c2", "SOMEPHASE", status="active",
            kind=tw.farmctl.COMPILE_WORK_ITEM_KIND,
        )
        assert tw._no_other_backtest_tester_active(conn) is True
        # A real active backtest alongside the compiles flips it to False.
        _insert_row(conn, "b1", "Q04", status="active")
        assert tw._no_other_backtest_tester_active(conn) is False
        conn.commit()


# --- DRAINED-FLEET armed-row admission at the real claim path -------------
# The armed heavy row is made 44 GB (single_index_tick) by overriding only its
# reservation; commit/calendar gates are neutralized and no census cells exist,
# so admission turns solely on the post-reservation RAM floor.  Selection-only:
# a skipped row stays pending, never verdicted.

def _insert_backtest(root, item_id, *, phase="P3", status="pending",
                     claimed_by=None, payload=None, ea="QM5_9999"):
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.execute(
            """
            INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,
                                   status,verdict,attempt_count,parent_task_id,
                                   evidence_path,claimed_by,payload_json,
                                   created_at,updated_at)
            VALUES(?,?,?,?,?,?, ?, NULL, 0, NULL, NULL, ?, ?, ?, ?)
            """,
            (item_id, "backtest", phase, ea, "EURUSD.DWX", "dummy.set",
             status, claimed_by, json.dumps(payload or {}), now, now),
        )
        conn.commit()


def _seed_drain_active(root, armed_item_id):
    now = time.time()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": {
            "item_id": armed_item_id,
            "ea_id": "QM5_9999",
            "reservation_gb": 44.0,
            "floor_gb": 14.0,
            "opened_epoch": now,
            "opened_iso": tw._drain_iso(now),
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    })


def _status(root, item_id):
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        return conn.execute(
            "SELECT status,claimed_by FROM work_items WHERE id=?", (item_id,)
        ).fetchone()


@pytest.fixture
def armed_claim(monkeypatch):
    """'idx-row' reserves 44 GB (single_index_tick); commit/calendar gates are
    neutralized and no census cells are claimable so nothing but the RAM floor
    gates admission.  Returns monkeypatch so each test injects free RAM."""
    real_reservation = tw._ram_reservation_for_candidate

    def fake_reservation(item, payload, multisym):
        if tw._work_item_value(item, "id") == "idx-row":
            return (tw.COMMIT_CLASS_SINGLE_INDEX_TICK, 44.0)
        return real_reservation(item, payload, multisym)

    monkeypatch.setattr(tw, "_ram_reservation_for_candidate", fake_reservation)
    monkeypatch.setattr(tw, "_commit_headroom_gb", lambda: 10_000.0)
    monkeypatch.setattr(
        tw, "_opt_census_cells_claimable_in_txn", lambda conn: False
    )
    monkeypatch.setattr(
        tw.farmctl,
        "_news_calendar_preflight",
        lambda *a, **k: {"ok": True, "status": "VALID"},
    )
    return monkeypatch


def test_claim_armed_row_admitted_at_48_on_drained_fleet(tmp_path, armed_claim):
    monkeypatch = armed_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "idx-row")
    _seed_drain_active(root, "idx-row")
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: 48.0)

    result = tw.claim_atomic(root, "T1")

    # 48 - 44 = 4 >= DRAIN_ARMED_ROW_FLOOR_GB (4): the armed row clears.
    assert result.get("claimed") is True, result
    assert result["item"]["id"] == "idx-row"
    assert result["ram_class_skipped"] == []
    assert _status(root, "idx-row") == ("active", "T1")


def test_claim_armed_row_skipped_at_47_on_drained_fleet(tmp_path, armed_claim):
    monkeypatch = armed_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "idx-row")
    _seed_drain_active(root, "idx-row")
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: 47.0)

    result = tw.claim_atomic(root, "T1")

    # 47 - 44 = 3 < 4: even the reduced floor is not met -> deferred, not verdicted.
    assert result.get("claimed") is False, result
    assert result["reason"] == "no_pending_claimable"
    skipped = result["ram_class_skipped"]
    assert len(skipped) == 1
    assert skipped[0]["item_id"] == "idx-row"
    # The reduced floor WAS applied (4, not 14) -- it just was not cleared at 47.
    assert skipped[0]["threshold_gb"] == tw.DRAIN_ARMED_ROW_FLOOR_GB
    assert _status(root, "idx-row") == ("pending", None)


def test_claim_armed_row_keeps_full_floor_with_another_tester_active(
    tmp_path, armed_claim
):
    monkeypatch = armed_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "idx-row")
    # A real backtest tester (a different EA) is still running -> the 14 GB floor
    # still protects it, so the reduced floor must NOT apply even to the armed row.
    _insert_backtest(
        root, "busy", phase="Q04", status="active", claimed_by="T9", ea="QM5_8888"
    )
    _seed_drain_active(root, "idx-row")
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: 48.0)

    result = tw.claim_atomic(root, "T1")

    assert result.get("claimed") is False, result
    skipped = result["ram_class_skipped"]
    assert len(skipped) == 1
    assert skipped[0]["item_id"] == "idx-row"
    assert skipped[0]["threshold_gb"] == tw.RAM_MIN_FREE_GB  # 14, not reduced
    assert _status(root, "idx-row") == ("pending", None)


def test_claim_non_armed_heavy_row_never_gets_reduced_floor(tmp_path, armed_claim):
    monkeypatch = armed_claim
    root = tmp_path / "farm"
    # idx-row is NOT the armed row; the drain is armed for a different id and the
    # fleet is otherwise drained.  The reduced floor is armed-row-only, so idx-row
    # keeps the full 14 GB floor and is deferred at 48 GB free.
    _insert_backtest(root, "idx-row")
    _seed_drain_active(root, "some-other-armed-row")
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: 48.0)

    result = tw.claim_atomic(root, "T1")

    assert result.get("claimed") is False, result
    skipped = result["ram_class_skipped"]
    assert len(skipped) == 1
    assert skipped[0]["item_id"] == "idx-row"
    assert skipped[0]["threshold_gb"] == tw.RAM_MIN_FREE_GB  # 14, no reduction
    assert _status(root, "idx-row") == ("pending", None)


def test_claim_armed_row_reduced_floor_off_under_kill_switch(
    tmp_path, armed_claim
):
    monkeypatch = armed_claim
    root = tmp_path / "farm"
    _insert_backtest(root, "idx-row")
    _seed_drain_active(root, "idx-row")
    # QM_DRAIN_WINDOW=0 clears drain_active upstream, so the reduced floor never
    # applies: the armed row keeps the 14 GB floor and is deferred at 48 GB free.
    monkeypatch.setenv("QM_DRAIN_WINDOW", "0")
    monkeypatch.setattr(tw, "_free_ram_gb", lambda: 48.0)

    result = tw.claim_atomic(root, "T1")

    assert result.get("claimed") is False, result
    skipped = result["ram_class_skipped"]
    assert len(skipped) == 1
    assert skipped[0]["item_id"] == "idx-row"
    assert skipped[0]["threshold_gb"] == tw.RAM_MIN_FREE_GB
    assert _status(root, "idx-row") == ("pending", None)


# --- WINNABILITY: long-run phase classification (manifest-resolved) -------
# Arming a drain is pointless while any row that holds RAM for hours is running,
# because such a row will not release inside DRAIN_WINDOW_MAX_MIN.  The long-run
# set (Q07, Q08, the news phase, Q09 and later) is read from the active gate
# manifest through the same phase_rank helper farmctl uses -- never a bare Qxx
# literal -- and the short gates/census/compile release RAM inside the window.

def test_long_run_phases_classified_from_manifest():
    for phase in ("Q07", "Q08", "Q09", tw._Q09_NEWS_PHASE, "Q10_NEWS", "Q11", "Q13"):
        assert tw._drain_phase_is_long_run(phase), phase


def test_short_phases_not_long_run():
    for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "OPT_CENSUS",
                  tw.farmctl.COMPILE_EA_PHASE, "", "GARBAGE"):
        assert not tw._drain_phase_is_long_run(phase), phase


# --- WINNABILITY: pure predicate -----------------------------------------
# need = reservation + DRAIN_ARMED_ROW_FLOOR_GB (44 + 4 = 48 for the index row);
# it is winnable when free RAM plus the RAM the active SHORT rows release covers
# that need.  Long-run rows are not an input to the predicate any more -- they
# hold RAM for hours and are already excluded from free RAM, so they add no
# releasable headroom; a heavy row can arm beside a long run when the arithmetic
# clears (a NEW long run appearing after the open still abandons the drain).

def test_winnable_true_when_short_rows_release_enough():
    ok, reason = tw._drain_candidate_is_winnable(
        _cand(), free_ram_gb=12.0, releasable_short_ram_gb=40.0,
    )
    assert (ok, reason) == (True, "")


def test_winnable_beside_long_run_ignores_it_and_uses_arithmetic():
    # A long run holds RAM for hours and adds no releasable headroom, but it no
    # longer refuses the arm outright: free 12 + short 40 = 52 >= need 48 -> the
    # heavy row is winnable (the old model returned long_run_row_active here).
    ok, reason = tw._drain_candidate_is_winnable(
        _cand(), free_ram_gb=12.0, releasable_short_ram_gb=40.0,
    )
    assert (ok, reason) == (True, "")


def test_not_winnable_when_releasable_ram_insufficient():
    # free 12 + releasable 30 = 42 < need 48.
    ok, reason = tw._drain_candidate_is_winnable(
        _cand(), free_ram_gb=12.0, releasable_short_ram_gb=30.0,
    )
    assert (ok, reason) == (False, "insufficient_releasable_ram")


def test_winnable_boundary_exact_need_is_winnable():
    # free 12 + releasable 36 = 48 == need -> winnable (>=).
    ok, reason = tw._drain_candidate_is_winnable(
        _cand(), free_ram_gb=12.0, releasable_short_ram_gb=36.0,
    )
    assert (ok, reason) == (True, "")


# --- WINNABILITY: evaluate does not arm when not winnable, keeps tracking -

def test_evaluate_not_winnable_does_not_arm_but_keeps_tracking():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    t0 = 8_000_000.0
    seeded = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"IDX1": {"first_skipped_epoch": t0}},
    }
    state, events = tw._drain_evaluate(
        seeded, now_epoch=t0 + trig, qualifying_candidate=_cand(),
        winnable=False, winnable_reason="insufficient_releasable_ram",
    )
    assert state["active"] is None
    assert "IDX1" in state["tracker"]  # still tracked for the next round
    assert [e["event"] for e in events] == ["drain_window_not_winnable"]
    assert events[0]["reason"] == "insufficient_releasable_ram"


def test_evaluate_not_winnable_event_throttled_per_cooldown():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    cool = tw.DRAIN_COOLDOWN_MIN * 60.0
    t0 = 8_100_000.0
    state = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"IDX1": {"first_skipped_epoch": t0}},
    }
    # First refusal logs and records the timestamp.
    state, ev1 = tw._drain_evaluate(
        state, now_epoch=t0 + trig, qualifying_candidate=_cand(),
        winnable=False, winnable_reason="insufficient_releasable_ram",
    )
    assert [e["event"] for e in ev1] == ["drain_window_not_winnable"]
    # A second refusal inside the cooldown window is silent (no log spam).
    state, ev2 = tw._drain_evaluate(
        state, now_epoch=t0 + trig + 60.0, qualifying_candidate=_cand(),
        winnable=False, winnable_reason="insufficient_releasable_ram",
    )
    assert ev2 == []
    assert state["active"] is None
    assert "IDX1" in state["tracker"]
    # Past the cooldown the refusal is logged again.
    state, ev3 = tw._drain_evaluate(
        state, now_epoch=t0 + trig + cool + 1.0, qualifying_candidate=_cand(),
        winnable=False, winnable_reason="insufficient_releasable_ram",
    )
    assert [e["event"] for e in ev3] == ["drain_window_not_winnable"]


def test_evaluate_arms_once_row_becomes_winnable():
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    t0 = 8_200_000.0
    state = {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"IDX1": {"first_skipped_epoch": t0}},
    }
    state, _ = tw._drain_evaluate(
        state, now_epoch=t0 + trig, qualifying_candidate=_cand(),
        winnable=False, winnable_reason="insufficient_releasable_ram",
    )
    assert state["active"] is None
    # The releasable RAM now covers the need; the same tracked row arms
    # immediately, recording the (here empty) long-run id set at open.
    state, events = tw._drain_evaluate(
        state, now_epoch=t0 + trig + 30.0, qualifying_candidate=_cand(),
        winnable=True,
    )
    assert state["active"] is not None
    assert state["active"]["long_run_ids_at_open"] == []
    assert [e["event"] for e in events] == ["drain_window_open"]


# --- WINNABILITY: abandon closes an open drain early ----------------------

def test_abandon_closes_active_and_sets_cooldown():
    cool = tw.DRAIN_COOLDOWN_MIN * 60.0
    now = 9_000_000.0
    active_state = {
        "version": 1,
        "active": {"item_id": "IDX1", "ea_id": "E", "opened_epoch": now - 120.0},
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    }
    closed, events = tw._drain_abandon(
        active_state, now_epoch=now, reason="new_long_run_row_active"
    )
    assert closed["active"] is None
    assert closed["cooldown_until_epoch"] == pytest.approx(now + cool)
    assert [e["event"] for e in events] == ["drain_window_abandoned"]
    assert events[0]["reason"] == "new_long_run_row_active"


def test_abandon_noop_when_no_active_drain():
    state = tw._empty_drain_state()
    same, events = tw._drain_abandon(state, now_epoch=1.0, reason="x")
    assert events == []
    assert same is state


# --- WINNABILITY: fleet-occupancy facts (real DB) ------------------------

def _insert_wi(conn, item_id, phase, *, symbol="EURUSD.DWX", status="active",
               kind="backtest", payload=None):
    now = "2026-09-03T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,
                               verdict,evidence_path,payload_json,created_at,
                               updated_at)
        VALUES(?,?,?,?,?, 'x.set', ?, NULL, NULL, ?, ?, ?)
        """,
        (item_id, kind, phase, f"QM5_{item_id}", symbol, status,
         json.dumps(payload or {}), now, now),
    )


def test_active_ram_facts_detects_long_run_and_sums_short(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_wi(conn, "s1", "Q02", symbol="EURUSD.DWX")      # ordinary FX = 8
        _insert_wi(conn, "s2", "OPT_CENSUS", symbol="EURUSD.DWX")  # census = 4
        _insert_wi(conn, "c1", tw.farmctl.COMPILE_EA_PHASE)     # keeps flowing
        _insert_wi(conn, "l1", "Q07", symbol="EURUSD.DWX")      # long-run
        conn.commit()
    facts = tw._drain_active_ram_facts(root, multisym_ids=_FZ, armed_item_id=None)
    assert facts["long_run_active_ids"] == ["l1"]
    # 8 (ordinary FX) + 4 (census); compile and long-run are excluded.
    assert facts["releasable_short_ram_gb"] == pytest.approx(12.0)
    assert facts["armed_row_pending"] is True


def test_active_ram_facts_excludes_armed_row_from_long_run(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        # The armed heavy row itself is now active (a Q07 row); it must not count
        # as an *other* long-run row, but it is no longer pending.
        _insert_wi(conn, "armed", "Q07", symbol="GDAXI.DWX")
        conn.commit()
    facts = tw._drain_active_ram_facts(
        root, multisym_ids=_FZ, armed_item_id="armed"
    )
    assert facts["long_run_active_ids"] == []
    assert facts["armed_row_pending"] is False


def test_active_ram_facts_armed_row_pending_true_when_pending(tmp_path):
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_wi(conn, "armed", "Q02", symbol="GDAXI.DWX", status="pending")
        conn.commit()
    facts = tw._drain_active_ram_facts(
        root, multisym_ids=_FZ, armed_item_id="armed"
    )
    assert facts["armed_row_pending"] is True


def test_active_ram_facts_fail_open_without_db(tmp_path):
    facts = tw._drain_active_ram_facts(
        tmp_path, multisym_ids=_FZ, armed_item_id="x"
    )
    assert facts == {
        "long_run_active_ids": [],
        "releasable_short_ram_gb": 0.0,
        "armed_row_pending": True,
    }


# --- WINNABILITY: postprocess integration (real DB) ----------------------
# The armed candidate is a pending priority-tracked 44 GB index row; free RAM
# (12) leaves need = 44 + 4 = 48 to be reached by draining short rows.

def _insert_pending_priority_index(conn, item_id="idx"):
    _insert_wi(
        conn, item_id, "Q07", symbol="GDAXI.DWX", status="pending",
        payload={"priority_track": True},
    )


def _emitted_events(capsys):
    return [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.strip().startswith("{")
    ]


def test_postprocess_arms_beside_long_runs_when_arithmetic_ok(tmp_path, capsys):
    # Two long-run rows are active (the fleet almost always has some), but the
    # heavy row is arithmetically winnable beside them: long runs add no
    # releasable headroom, yet free 12 + five short FX (5 * 8 = 40) = 52 >= need
    # 48, so the drain arms and records the two long-run ids at open time.
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    now = 10_000_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")
        _insert_wi(conn, "l1", "Q07", symbol="EURUSD.DWX", status="active")
        _insert_wi(conn, "l2", "Q10_NEWS", symbol="GBPUSD.DWX", status="active")
        for i in range(5):
            _insert_wi(conn, f"q{i}", "Q02", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"idx": {"first_skipped_epoch": now - trig - 10.0}},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is not None
    assert after["active"]["item_id"] == "idx"
    assert set(after["active"]["long_run_ids_at_open"]) == {"l1", "l2"}
    assert any(
        e.get("event") == "drain_window_open" for e in _emitted_events(capsys)
    )


def test_postprocess_not_armed_beside_long_runs_when_arithmetic_short(
    tmp_path, capsys
):
    # Two long-run rows active and only three short FX (3 * 8 = 24) releasable:
    # free 12 + 24 = 36 < need 48, so the heavy row is not winnable even beside
    # the long runs -> not armed, structured refusal insufficient_releasable_ram.
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    now = 10_300_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")
        _insert_wi(conn, "l1", "Q07", symbol="EURUSD.DWX", status="active")
        _insert_wi(conn, "l2", "Q10_NEWS", symbol="GBPUSD.DWX", status="active")
        for i in range(3):
            _insert_wi(conn, f"q{i}", "Q02", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"idx": {"first_skipped_epoch": now - trig - 10.0}},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is None
    assert "idx" in after["tracker"]
    assert any(
        e.get("event") == "drain_window_not_winnable"
        and e.get("reason") == "insufficient_releasable_ram"
        for e in _emitted_events(capsys)
    )


def test_postprocess_arms_when_short_rows_release_enough(tmp_path, capsys):
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    now = 10_100_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")
        # five ordinary FX testers = 5 * 8 = 40 GB releasable; free 12 + 40 = 52
        # >= need 48 -> winnable once the fleet parks; only short rows are active.
        for i in range(5):
            _insert_wi(conn, f"q{i}", "Q02", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"idx": {"first_skipped_epoch": now - trig - 10.0}},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is not None
    assert after["active"]["item_id"] == "idx"
    assert any(
        e.get("event") == "drain_window_open" for e in _emitted_events(capsys)
    )


def test_postprocess_not_armed_when_releasable_ram_insufficient(tmp_path, capsys):
    trig = tw.DRAIN_WINDOW_TRIGGER_MIN * 60.0
    now = 10_200_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")
        # three ordinary FX testers = 24 GB releasable; free 12 + 24 = 36 < 48.
        for i in range(3):
            _insert_wi(conn, f"q{i}", "Q02", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": None,
        "cooldown_until_epoch": 0.0,
        "tracker": {"idx": {"first_skipped_epoch": now - trig - 10.0}},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is None
    assert "idx" in after["tracker"]
    assert any(
        e.get("event") == "drain_window_not_winnable"
        and e.get("reason") == "insufficient_releasable_ram"
        for e in _emitted_events(capsys)
    )


def test_postprocess_abandons_active_drain_on_new_long_run(tmp_path, capsys):
    # The drain opened with NO long-run row running (long_run_ids_at_open empty).
    # A long-run row (l1) then goes active -- a NEW id the open set did not have
    # -> the open drain is abandoned so the fleet resumes short rows at once.
    now = 11_000_000.0
    cool = tw.DRAIN_COOLDOWN_MIN * 60.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")  # armed row still pending
        _insert_wi(conn, "l1", "Q10_NEWS", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": {
            "item_id": "idx", "ea_id": "QM5_idx",
            "reservation_gb": 44.0, "floor_gb": 14.0,
            "opened_epoch": now - 300.0, "opened_iso": tw._drain_iso(now - 300.0),
            "long_run_ids_at_open": [],
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is None
    assert after["cooldown_until_epoch"] == pytest.approx(now + cool)
    assert any(
        e.get("event") == "drain_window_abandoned"
        and e.get("reason") == "new_long_run_row_active"
        for e in _emitted_events(capsys)
    )


def test_postprocess_does_not_abandon_on_preexisting_long_run(tmp_path, capsys):
    # The drain opened WHILE l1 was already running (recorded in
    # long_run_ids_at_open).  l1 is still the only long-run row and the armed row
    # is still pending, so nothing NEW appeared -> the drain stays open, not
    # abandoned.
    now = 11_050_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_pending_priority_index(conn, "idx")  # armed row still pending
        _insert_wi(conn, "l1", "Q10_NEWS", symbol="EURUSD.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": {
            "item_id": "idx", "ea_id": "QM5_idx",
            "reservation_gb": 44.0, "floor_gb": 14.0,
            "opened_epoch": now - 300.0, "opened_iso": tw._drain_iso(now - 300.0),
            "long_run_ids_at_open": ["l1"],
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is not None
    assert after["active"]["item_id"] == "idx"
    assert not any(
        e.get("event") == "drain_window_abandoned"
        for e in _emitted_events(capsys)
    )


def test_postprocess_abandons_when_armed_row_claimed_elsewhere(tmp_path, capsys):
    now = 11_100_000.0
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        # Another terminal took the armed row: it is now active, not pending, and
        # this worker did not claim it (claimed=False).
        _insert_wi(conn, "idx", "Q02", symbol="GDAXI.DWX", status="active")
        conn.commit()
    tw._write_drain_state_atomic(root, {
        "version": 1,
        "active": {
            "item_id": "idx", "ea_id": "QM5_idx",
            "opened_epoch": now - 100.0, "opened_iso": tw._drain_iso(now - 100.0),
        },
        "cooldown_until_epoch": 0.0,
        "tracker": {},
    })
    tw._drain_run_postprocess(
        root, "T1", {"claimed": False},
        now_epoch=now, free_ram_gb=12.0, host_total_gb=80.0, multisym_ids=_FZ,
    )
    after = tw._load_drain_state(root)
    assert after["active"] is None
    assert any(
        e.get("event") == "drain_window_abandoned"
        and e.get("reason") == "armed_row_claimed_elsewhere"
        for e in _emitted_events(capsys)
    )
