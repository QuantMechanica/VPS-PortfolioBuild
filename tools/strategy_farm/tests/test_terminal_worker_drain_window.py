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
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

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
    # 58 > 63 - 10 = 53: even a fully drained 63 GB host cannot satisfy it.
    assert not tw._drain_row_is_qualifying(
        reservation_gb=44.0, floor_gb=14.0, free_ram_gb=18.0, host_total_gb=63.0
    )


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
    assert tw._drain_candidate_from_row(
        _index_item(), {"priority_track": True}, 18.0, 63.0, _FZ
    ) is None


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
