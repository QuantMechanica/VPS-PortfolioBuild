"""Regression tests for the hourly-watch census-stall-in-drain tripwire.

OWNER-DEC-CBE-20260915 factory audit (pipeline_factory_state.md): the
``q08_head_of_line_claim_starvation`` health check read false-OK while >=3
factory terminals sat idle in ``drain_predrain`` behind an un-winnable RAM
reservation and census throughput was zero.  ``census_stall_alert`` surfaces
that case explicitly and names the blocking item.
"""
from __future__ import annotations

from session_tools import hourly_watch_0909 as watch


def _drain_window(now_epoch: float, *, waited_s: float = 10_600.0) -> dict:
    return {
        "pre_drain": {
            "ea_id": "QM5_10025",
            "item_id": "d16ec281-aaaa-bbbb-cccc-000000000000",
            "opened_epoch": now_epoch - waited_s,
            "reservation_gb": 44.0,
        },
        "tracker": {},
    }


def test_idle_factory_terminals_counts_only_numbered_slots() -> None:
    # Only T<digits> leaves are factory slots; MT5_Base / FTMO / T_Live are not.
    assert watch.idle_factory_terminals("T1,T2,MT5_Base,FTMO") == 8
    assert watch.idle_factory_terminals("T1,T2,T3,T4,T5,T6,T7,T8,T9,T10") == 0
    assert watch.idle_factory_terminals("") == 10
    assert watch.idle_factory_terminals("MT5_Base,FTMO,T_Live") == 10


def test_census_stall_alert_fires_and_names_blocking_item() -> None:
    now = 1_789_492_000.0
    alert = watch.census_stall_alert(0, 6, _drain_window(now), now)
    assert alert is not None
    assert "CENSUS STALL in drain" in alert
    assert "QM5_10025" in alert
    assert "d16ec281-aaaa-bbbb-cccc-000000000000" in alert
    assert "reservation_gb=44.0" in alert


def test_census_stall_alert_reads_from_tracker_when_no_pre_drain() -> None:
    now = 1_789_492_000.0
    dw = {
        "pre_drain": {},
        "tracker": {
            "7d0e2ae9-item": {
                "ea_id": "QM5_1069",
                "first_skipped_epoch": now - 4000.0,
                "reservation_gb": 44.0,
            }
        },
    }
    alert = watch.census_stall_alert(0, 4, dw, now)
    assert alert is not None
    assert "QM5_1069" in alert
    assert "7d0e2ae9-item" in alert


def test_census_stall_alert_silent_when_healthy() -> None:
    now = 1_789_492_000.0
    dw = _drain_window(now)
    # census throughput present -> not a stall
    assert watch.census_stall_alert(5, 6, dw, now) is None
    # too few idle terminals -> not a stall
    assert watch.census_stall_alert(0, 2, dw, now) is None
    # drain only just opened (< 10 min) -> not a stall
    assert watch.census_stall_alert(0, 6, _drain_window(now, waited_s=60.0), now) is None
    # no drain window entry at all -> not a stall
    assert watch.census_stall_alert(0, 6, {}, now) is None
    assert watch.census_stall_alert(0, 6, {"pre_drain": {}, "tracker": {}}, now) is None


def _active_unwinnable_window(now_epoch: float, *, unwinnable_for_s: float = 900.0) -> dict:
    return {
        "active": {
            "ea_id": "QM5_20260",
            "item_id": "e2622f78-aaaa-bbbb-cccc-000000000000",
            "reservation_gb": 24.0,
            "opened_epoch": now_epoch - 1800.0,
            "not_winnable_since_epoch": now_epoch - unwinnable_for_s,
            "not_winnable_reason": "no_releasable_ram",
        },
        "tracker": {},
    }


def test_drain_unwinnable_alert_fires_and_names_the_active_row() -> None:
    """2026-09-18 ticket c9cff1f2: census_stall_alert cannot see an ACTIVE
    drain (tracker is consumed at open) -- drain_unwinnable_alert must."""
    now = 1_789_792_358.0
    alert = watch.drain_unwinnable_alert(6, _active_unwinnable_window(now), now)
    assert alert is not None
    assert "DRAIN_UNWINNABLE" in alert
    assert "QM5_20260" in alert
    assert "e2622f78-aaaa-bbbb-cccc-000000000000" in alert
    assert "reservation_gb=24.0" in alert
    assert "reason=no_releasable_ram" in alert


def test_census_stall_alert_is_silent_for_the_same_active_window() -> None:
    """The gap this closes: an armed (active) drain leaves pre_drain/tracker
    empty, so the older check reads healthy while the fleet is fully blocked."""
    now = 1_789_792_358.0
    assert watch.census_stall_alert(0, 6, _active_unwinnable_window(now), now) is None


def test_drain_unwinnable_alert_silent_when_not_marked_or_understaffed() -> None:
    now = 1_789_792_358.0
    # no not_winnable marker yet (still within grace, or still winnable)
    dw = _active_unwinnable_window(now)
    dw["active"].pop("not_winnable_reason")
    dw["active"].pop("not_winnable_since_epoch")
    assert watch.drain_unwinnable_alert(6, dw, now) is None
    # too few idle terminals
    assert watch.drain_unwinnable_alert(2, _active_unwinnable_window(now), now) is None
    # no active drain at all
    assert watch.drain_unwinnable_alert(6, {"tracker": {}}, now) is None
    assert watch.drain_unwinnable_alert(6, {}, now) is None
