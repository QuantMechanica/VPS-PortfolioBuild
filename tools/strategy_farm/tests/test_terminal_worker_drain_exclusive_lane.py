"""Exclusive lane for >= 40 GB rows in the drain window (2026-09-14).

OWNER 2026-09-14: "Es wird keinen RAM Zukauf geben, bei SP500 und Multisymbol koennen halt keine
anderen Backtests nebenbei laufen".  A 44 GB row (SP500 single_index_tick, heavy multisymbol)
needs 44 + 4 + 3 = 51 GB under the ordinary arithmetic against a ceiling of 63.1 - 14 = 49.1 GB, so
it could never arm.  The exclusive lane: any pending exclusive row may be the candidate; need =
reservation + armed floor (no margin) against the empty-fleet baseline; while long runs are active a
PRE-DRAIN refuses NEW long-run claims (short rows keep flowing) until they finish; then the ordinary
drain parks the fleet and the row runs alone.  Duty cycle: exclusive cooldown + a daily cap.
Kill switch QM_DRAIN_EXCLUSIVE=0 restores the prior behaviour byte-for-byte.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import farmctl  # noqa: E402
import terminal_worker as tw  # noqa: E402

NOW = 20_000_000.0


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.delenv(tw.QM_DRAIN_EXCLUSIVE_ENV, raising=False)
    monkeypatch.delenv(tw.INDEX_TICK_RESERVATION_TABLE_ENV, raising=False)


def _sp500(item_id="SPX1", phase="Q04", priority=False):
    item = {"id": item_id, "ea_id": "QM5_10145", "phase": phase, "symbol": "SP500.DWX"}
    payload = {"priority_track": True} if priority else {}
    return item, payload


def test_sp500_row_without_priority_track_is_an_exclusive_candidate():
    item, payload = _sp500()
    cand = tw._drain_candidate_from_row(item, payload, free_ram_gb=30.0, host_total_gb=63.1, multisym_ids=frozenset())
    assert cand is not None and cand["exclusive"] is True
    assert cand["reservation_gb"] == 44.0 and cand["ram_class"] == tw.COMMIT_CLASS_SINGLE_INDEX_TICK


def test_kill_switch_restores_priority_only_candidates(monkeypatch):
    monkeypatch.setenv(tw.QM_DRAIN_EXCLUSIVE_ENV, "0")
    item, payload = _sp500()
    assert tw._drain_candidate_from_row(item, payload, free_ram_gb=30.0, host_total_gb=63.1, multisym_ids=frozenset()) is None


def test_lighter_index_rows_are_not_exclusive():
    # NDX at 12 GB is below the drain's own minimum (24 GB): never a drain candidate at all
    ndx = {"id": "NDX1", "ea_id": "QM5_10363", "phase": "Q04", "symbol": "NDX.DWX"}
    assert tw._drain_candidate_from_row(ndx, {"priority_track": True}, free_ram_gb=20.0, host_total_gb=63.1, multisym_ids=frozenset()) is None
    # GDAXI at the provisional 24 GB: an ordinary (non-exclusive) drain candidate only when priority-tracked
    dax = {"id": "DAX1", "ea_id": "QM5_10377", "phase": "Q04", "symbol": "GDAXI.DWX"}
    assert tw._drain_candidate_from_row(dax, {}, free_ram_gb=20.0, host_total_gb=63.1, multisym_ids=frozenset()) is None
    cand = tw._drain_candidate_from_row(dax, {"priority_track": True}, free_ram_gb=20.0, host_total_gb=63.1, multisym_ids=frozenset())
    assert cand is not None and cand["exclusive"] is False and cand["reservation_gb"] == 24.0


def test_exclusive_winnable_arithmetic_alone_on_the_fleet():
    cand = {"item_id": "SPX1", "reservation_gb": 44.0, "floor_gb": 14.0, "exclusive": True}
    # need = 44 + 4 = 48 (no margin); ceiling = 63.1 - 9 = 54.1 -> winnable once the parked fleet frees 48
    assert tw._drain_candidate_is_winnable(cand, free_ram_gb=40.0, releasable_short_ram_gb=10.0, long_run_ram_gb=0.0, host_total_gb=63.1) == (True, "")
    assert tw._drain_candidate_is_winnable(cand, free_ram_gb=40.0, releasable_short_ram_gb=6.0, long_run_ram_gb=0.0, host_total_gb=63.1) == (False, "insufficient_releasable_ram")
    # any active long run -> not now (the evaluator opens a pre-drain instead)
    assert tw._drain_candidate_is_winnable(cand, free_ram_gb=50.0, releasable_short_ram_gb=10.0, long_run_ram_gb=8.0, host_total_gb=63.1) == (False, "exclusive_waits_for_long_runs")
    # a row that does not fit even on the empty fleet is refused
    big = {**cand, "reservation_gb": 52.0}
    assert tw._drain_candidate_is_winnable(big, free_ram_gb=60.0, releasable_short_ram_gb=0.0, long_run_ram_gb=0.0, host_total_gb=63.1) == (False, "exclusive_exceeds_empty_fleet_ceiling")


def test_ordinary_44gb_arithmetic_is_unchanged_without_the_flag():
    cand = {"item_id": "SPX1", "reservation_gb": 44.0, "floor_gb": 14.0, "exclusive": False}
    # 44 + 4 + 3 = 51 > 63.1 - 14 = 49.1 -> long_run_ceiling even with zero long runs (the historical dead end)
    assert tw._drain_candidate_is_winnable(cand, free_ram_gb=54.0, releasable_short_ram_gb=0.0, long_run_ram_gb=0.0, host_total_gb=63.1) == (False, "long_run_ceiling")


def _tracked_state(cid="SPX1", waited_min=25.0):
    return {"version": 1, "active": None, "cooldown_until_epoch": 0.0,
            "tracker": {cid: {"first_skipped_epoch": NOW - waited_min * 60.0, "reservation_gb": 44.0, "floor_gb": 14.0, "ea_id": "QM5_10145"}}}


def _cand(exclusive=True):
    return {"item_id": "SPX1", "ea_id": "QM5_10145", "phase": "Q04", "ram_class": "single_index_tick",
            "reservation_gb": 44.0, "floor_gb": 14.0, "exclusive": exclusive}


def test_predrain_opens_while_long_runs_block_and_refuses_new_long_runs():
    state, events = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                       winnable=False, winnable_reason="exclusive_waits_for_long_runs", long_run_ids_active=["LR1"])
    assert [e["event"] for e in events] == ["drain_predrain_open"]
    assert state["pre_drain"]["item_id"] == "SPX1" and state["active"] is None
    active, item_id = tw._drain_predrain_now(state, NOW + 60.0)
    assert (active, item_id) == (True, "SPX1")
    # claim path: a NEW long-run row is refused, a short row and COMPILE_EA are not
    assert tw._drain_blocks_new_long_run({"id": "NEW", "phase": "Q07"}, item_id) is True
    assert tw._drain_blocks_new_long_run({"id": "NEW", "phase": "Q02"}, item_id) is False
    assert tw._drain_blocks_new_long_run({"id": "NEW", "phase": "COMPILE_EA"}, item_id) is False
    # the pre-drain is bounded
    assert tw._drain_predrain_now(state, NOW + tw.DRAIN_EXCLUSIVE_PREDRAIN_MAX_MIN * 60.0 + 1.0) == (False, None)


def test_predrain_is_consumed_by_the_open_and_the_claim_starts_the_exclusive_cooldown():
    state, _ = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs", long_run_ids_active=["LR1"])
    later = NOW + 30 * 60.0
    state, events = tw._drain_evaluate(state, now_epoch=later, qualifying_candidate=_cand(), winnable=True, long_run_ids_active=[])
    assert [e["event"] for e in events] == ["drain_window_open"]
    assert "pre_drain" not in state and state["active"]["exclusive"] is True
    state, events = tw._drain_note_claim(state, now_epoch=later + 120.0, claimed_item_id="SPX1")
    assert events[0]["event"] == "drain_window_claim" and events[0]["exclusive"] is True
    assert state["exclusive_claims"]["count"] == 1
    assert state["exclusive_cooldown_until_epoch"] == later + 120.0 + tw.DRAIN_EXCLUSIVE_COOLDOWN_MIN * 60.0
    # inside the exclusive cooldown no new pre-drain/open for an exclusive candidate
    st2 = {**state, "tracker": _tracked_state()["tracker"]}
    st2, events = tw._drain_evaluate(st2, now_epoch=later + 300.0, qualifying_candidate=_cand(),
                                     winnable=False, winnable_reason="exclusive_waits_for_long_runs", long_run_ids_active=["LR2"])
    assert "pre_drain" not in st2 and not any(e["event"] == "drain_predrain_open" for e in events)


def test_daily_cap_blocks_further_exclusive_arming():
    state = _tracked_state()
    state["exclusive_claims"] = {"day": tw._drain_utc_day(NOW), "count": tw.DRAIN_EXCLUSIVE_DAILY_MAX}
    state, events = tw._drain_evaluate(state, now_epoch=NOW, qualifying_candidate=_cand(), winnable=True, long_run_ids_active=[])
    assert state["active"] is None and not any(e["event"] == "drain_window_open" for e in events)
    # a new UTC day resets the counter
    state["exclusive_claims"] = {"day": "2000-01-01", "count": tw.DRAIN_EXCLUSIVE_DAILY_MAX}
    state, events = tw._drain_evaluate(state, now_epoch=NOW, qualifying_candidate=_cand(), winnable=True, long_run_ids_active=[])
    assert state["active"] is not None


def test_predrain_survives_a_differing_scan_candidate_and_still_expires():
    # 2026-09-14 fix (was test_predrain_expires_and_abandons_when_the_candidate_changes,
    # which asserted the DEFECT behaviour): a differing scan candidate no longer
    # abandons the pre-drain (that oscillation reset opened_epoch every pass so the
    # 240-min bound never expired and refused new long runs for ~4 h).  Only the
    # kill switch, the max-window bound, or the row leaving the pending set closes it.
    state, _ = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs", long_run_ids_active=["LR1"])
    opened0 = state["pre_drain"]["opened_epoch"]
    other = {**_cand(), "item_id": "SPX2"}
    st, events = tw._drain_evaluate(state, now_epoch=NOW + 60.0, qualifying_candidate=other,
                                    winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                    long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert not any(e["event"] == "drain_predrain_abandoned" for e in events)
    assert st["pre_drain"]["item_id"] == "SPX1" and st["pre_drain"]["opened_epoch"] == opened0
    # the max-window bound still fires, measured from the ORIGINAL open, with cooldown
    st, events = tw._drain_evaluate(st, now_epoch=opened0 + tw.DRAIN_EXCLUSIVE_PREDRAIN_MAX_MIN * 60.0 + 1.0,
                                    qualifying_candidate=_cand(), winnable=False,
                                    winnable_reason="exclusive_waits_for_long_runs",
                                    long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert any(e["event"] == "drain_predrain_expired" for e in events)
    assert st.get("exclusive_cooldown_until_epoch", 0.0) > NOW


def test_ordinary_drain_bookkeeping_survives_abandon():
    state = {"version": 1, "active": {"item_id": "X", "opened_epoch": NOW - 60.0}, "cooldown_until_epoch": 0.0, "tracker": {},
             "exclusive_claims": {"day": tw._drain_utc_day(NOW), "count": 2}, "exclusive_cooldown_until_epoch": NOW + 100.0}
    st, _ = tw._drain_abandon(state, now_epoch=NOW, reason="test")
    assert st["exclusive_claims"]["count"] == 2 and st["exclusive_cooldown_until_epoch"] == NOW + 100.0


# --- 2026-09-14 sticky pre-drain fix (BOOK_SPRINT_2026-09-20 defect) ------------
#
# The 44 GB row f15ac955 re-opened its pre-drain on EVERY claim pass: another
# worker's pass picked a different first candidate, the old code abandoned the
# pre-drain, and the next pass re-opened it -- resetting opened_epoch so the
# 240-min bound never expired (waited 77,608 s) while NEW long runs were refused
# for ~4 h.  The fix makes the pre-drain STICKY and row-bound.


def _insert_wi(conn, item_id, symbol="SP500.DWX", phase="Q04", *, status="pending",
               kind="backtest", payload=None):
    now = "2026-09-14T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,
                               verdict,evidence_path,payload_json,created_at,
                               updated_at)
        VALUES(?,?,?,?,?, 'x.set', ?, NULL, NULL, ?, ?, ?)
        """,
        (item_id, kind, phase, "QM5_10145", symbol, status,
         json.dumps(payload or {}), now, now),
    )


def test_predrain_is_sticky_across_two_passes_and_does_not_reopen():
    # (a) two consecutive passes with the SAME exclusive row keep opened_epoch and
    # do not re-emit drain_predrain_open.
    state, events = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                       winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                       long_run_ids_active=["LR1"])
    assert [e["event"] for e in events] == ["drain_predrain_open"]
    opened0 = state["pre_drain"]["opened_epoch"]
    later = NOW + 45 * 60.0
    state2, events2 = tw._drain_evaluate(state, now_epoch=later, qualifying_candidate=_cand(),
                                         winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                         long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert state2["pre_drain"]["item_id"] == "SPX1"
    assert state2["pre_drain"]["opened_epoch"] == opened0            # not reset
    assert not any(e["event"] == "drain_predrain_open" for e in events2)  # no churn
    # the bound is still measured from the ORIGINAL open
    assert tw._drain_predrain_now(
        state2, opened0 + tw.DRAIN_EXCLUSIVE_PREDRAIN_MAX_MIN * 60.0 + 1.0
    ) == (False, None)


def test_scan_prefers_the_predrain_row_over_other_exclusive_rows(tmp_path):
    # (b) a pass whose first candidate would be a DIFFERENT exclusive row returns
    # the pre-drain row R instead, so the fleet converges on R.
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_wi(conn, "SPX_R", symbol="SP500.DWX")
        _insert_wi(conn, "SPX_R2", symbol="SP500.DWX")
        conn.commit()
    kw = dict(free_ram_gb=30.0, host_total_gb=63.1, multisym_ids=frozenset(),
              releasable_short_ram_gb=10.0, long_run_ram_gb=8.0, now_epoch=NOW)
    # both rows are exclusive candidates; a long run is active so neither is winnable
    base, base_winnable, base_reason = tw._drain_scan_candidate(root, **kw)
    assert base is not None and base["exclusive"] is True
    assert (base_winnable, base_reason) == (False, "exclusive_waits_for_long_runs")
    # with a pre-drain on SPX_R2 the scan converges on SPX_R2 regardless of order
    pref, pref_winnable, pref_reason = tw._drain_scan_candidate(
        root, predrain_item_id="SPX_R2", **kw
    )
    assert pref is not None and pref["item_id"] == "SPX_R2"
    assert (pref_winnable, pref_reason) == (False, "exclusive_waits_for_long_runs")


def test_evaluate_keeps_predrain_when_scan_candidate_differs():
    # (b, pure): _drain_evaluate must NOT abandon R's pre-drain merely because the
    # candidate it is handed is a different exclusive row (row R still pending).
    state, _ = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                  long_run_ids_active=["LR1"])
    other = {**_cand(), "item_id": "SPX2"}
    st, events = tw._drain_evaluate(state, now_epoch=NOW + 90.0, qualifying_candidate=other,
                                    winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                    long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert not any(e["event"] == "drain_predrain_abandoned" for e in events)
    assert st["pre_drain"]["item_id"] == "SPX1"


def test_predrain_bound_expires_from_original_open_with_cooldown():
    # (c) the 240-min bound expires from the ORIGINAL opened_epoch even after
    # intervening passes, and closes with reason predrain_max_minutes + cooldown.
    state, _ = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                  long_run_ids_active=["LR1"])
    opened0 = state["pre_drain"]["opened_epoch"]
    # a mid-window pass keeps it sticky, original open unchanged
    state, _ = tw._drain_evaluate(state, now_epoch=NOW + 100 * 60.0, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                  long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert state["pre_drain"]["opened_epoch"] == opened0
    expire_at = opened0 + tw.DRAIN_EXCLUSIVE_PREDRAIN_MAX_MIN * 60.0 + 1.0
    state, events = tw._drain_evaluate(state, now_epoch=expire_at, qualifying_candidate=_cand(),
                                       winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                       long_run_ids_active=["LR1"], predrain_row_pending=True)
    assert any(e["event"] == "drain_predrain_expired" and e["reason"] == "predrain_max_minutes"
               for e in events)
    assert "pre_drain" not in state
    assert state["exclusive_cooldown_until_epoch"] == expire_at + tw.DRAIN_EXCLUSIVE_COOLDOWN_MIN * 60.0
    assert not any(e["event"] == "drain_predrain_open" for e in events)


def test_predrain_abandoned_when_row_leaves_pending():
    # (d) the pre-drain is abandoned once its row is no longer pending (claimed /
    # done / held / deleted): the scan cannot return R, so predrain_row_pending=False.
    state, _ = tw._drain_evaluate(_tracked_state(), now_epoch=NOW, qualifying_candidate=_cand(),
                                  winnable=False, winnable_reason="exclusive_waits_for_long_runs",
                                  long_run_ids_active=["LR1"])
    assert state["pre_drain"]["item_id"] == "SPX1"
    state, events = tw._drain_evaluate(state, now_epoch=NOW + 120.0, qualifying_candidate=None,
                                       predrain_row_pending=False)
    assert any(e["event"] == "drain_predrain_abandoned" and e["reason"] == "row_not_pending"
               for e in events)
    assert "pre_drain" not in state


def test_kill_switch_drops_stale_predrain_and_leaves_legacy_behaviour(monkeypatch):
    # (e) QM_DRAIN_EXCLUSIVE=0: the exclusive lane is off, a stale pre-drain from
    # before the switch is closed (not carried), and no exclusive pre-drain opens.
    monkeypatch.setenv(tw.QM_DRAIN_EXCLUSIVE_ENV, "0")
    state = _tracked_state()
    state["pre_drain"] = {"item_id": "SPX1", "ea_id": "QM5_10145", "reservation_gb": 44.0,
                          "opened_epoch": NOW - 60.0, "long_run_ids_at_open": []}
    state, events = tw._drain_evaluate(state, now_epoch=NOW, qualifying_candidate=None)
    assert "pre_drain" not in state
    assert any(e["event"] == "drain_predrain_abandoned" and e["reason"] == "exclusive_lane_disabled"
               for e in events)
