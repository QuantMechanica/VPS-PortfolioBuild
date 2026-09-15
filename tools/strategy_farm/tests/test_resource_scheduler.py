"""Tests for the pure resource-aware admission scheduler (directive 3 §12).

Fixture scenarios enumerated by the slice:
  * headroom 30 GB + head row 44 GB + smaller rows -> smaller rows claimed, no pre-drain;
  * quiet window -> heavy allowed;
  * starvation guard;
  * kill switch reproduces today's behaviour (is_enabled False).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import resource_scheduler as rs  # noqa: E402

CFG = dict(rs.DEFAULT_CONFIG)


def _c(item_id, gb, priority=0.0, ea_id=""):
    return rs.Candidate(item_id=item_id, reservation_gb=gb, priority=priority, ea_id=ea_id or item_id)


# --- kill switch --------------------------------------------------------------
def test_kill_switch_default_off():
    assert rs.is_enabled({}) is False
    assert rs.is_enabled({"QM_RESOURCE_SCHEDULER": "0"}) is False
    assert rs.is_enabled({"QM_RESOURCE_SCHEDULER": "off"}) is False


def test_kill_switch_on():
    assert rs.is_enabled({"QM_RESOURCE_SCHEDULER": "1"}) is True
    assert rs.is_enabled({"QM_RESOURCE_SCHEDULER": "calibrated"}) is True


# --- config loader fail-open --------------------------------------------------
def test_load_config_fail_open(tmp_path):
    assert rs.load_config(tmp_path / "does_not_exist.json") == rs.DEFAULT_CONFIG
    bad = tmp_path / "bad.json"
    bad.write_text("{not json", encoding="utf-8")
    assert rs.load_config(bad) == rs.DEFAULT_CONFIG


def test_load_config_override(tmp_path):
    p = tmp_path / "cfg.json"
    p.write_text('{"heavy_reservation_gb": 30.0, "quiet_window_max_active_cells": 5}', encoding="utf-8")
    cfg = rs.load_config(p)
    assert cfg["heavy_reservation_gb"] == 30.0
    assert cfg["quiet_window_max_active_cells"] == 5
    # untouched keys keep defaults
    assert cfg["fit_post_reservation_floor_gb"] == rs.DEFAULT_CONFIG["fit_post_reservation_floor_gb"]


# --- fit / heavy predicates ---------------------------------------------------
def test_fits_and_heavy():
    # 30 GB free, floor 14: a 44 GB row does not fit (30-44 < 14); an 8 GB row fits.
    assert _c("heavy", 44.0).fits(30.0, CFG) is False
    assert _c("small", 8.0).fits(30.0, CFG) is True
    assert _c("heavy", 44.0).is_heavy(CFG) is True
    assert _c("small", 8.0).is_heavy(CFG) is False
    assert _c("mid", 24.0).is_heavy(CFG) is True


# --- bin-packing selection ----------------------------------------------------
def test_plan_head_window_picks_highest_value_fitting():
    cands = [_c("h", 44.0, priority=99), _c("a", 8.0, priority=10), _c("b", 6.0, priority=20)]
    plan = rs.plan_head_window(cands, free_ram_gb=30.0, cfg=CFG)
    # heavy does not fit; highest-value fitting is b (priority 20)
    assert plan.chosen.item_id == "b"
    assert {c.item_id for c in plan.skipped_no_fit} == {"h"}
    assert {c.item_id for c in plan.fitting_smaller} == {"a"}


def test_plan_head_window_none_fit():
    cands = [_c("h", 44.0), _c("h2", 46.0)]
    plan = rs.plan_head_window(cands, free_ram_gb=30.0, cfg=CFG)
    assert plan.chosen is None
    assert plan.reason == "no_fitting_candidate"


# --- pre-drain decision: the head-of-line scenario ----------------------------
def test_heavy_suppressed_when_fitting_smaller_and_busy():
    # headroom 30 GB, head row 44 GB, smaller rows present, fleet busy (>=2 cells)
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    window = [heavy, _c("a", 8.0), _c("b", 6.0)]
    d = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=6,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert d.arm_allowed is False
    assert d.reason.startswith("suppressed_fitting_smaller_exists")
    assert "QM5_SP" in d.tracking_out


def test_heavy_allowed_in_quiet_window_no_fitting_smaller():
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    # only heavy rows in window, fleet quiet (0 active cells)
    window = [heavy, _c("h2", 44.0)]
    d = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=0,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert d.arm_allowed is True
    assert d.reason == "quiet_window_no_fitting_smaller"
    assert "QM5_SP" not in d.tracking_out  # tracking cleared on allow


def test_heavy_suppressed_quiet_but_fitting_smaller_exists():
    # even in a quiet window, a fitting smaller row keeps the heavy waiting
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    window = [heavy, _c("a", 8.0)]
    d = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=0,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert d.arm_allowed is False
    assert d.reason.startswith("suppressed_fitting_smaller_exists")


def test_heavy_suppressed_when_busy_even_without_fitting_smaller():
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    window = [heavy]  # no smaller rows
    d = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=6,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert d.arm_allowed is False
    assert d.reason.startswith("suppressed_fleet_busy")


# --- starvation guard ---------------------------------------------------------
def test_starvation_guard_allows_after_max_wait():
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    window = [heavy, _c("a", 8.0)]
    # first pass: suppressed, tracking records first_suppressed_epoch
    d1 = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=6,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert d1.arm_allowed is False
    first = d1.tracking_out["QM5_SP"]["first_suppressed_epoch"]
    assert first == 1000.0
    # still within max wait -> still suppressed
    d2 = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=6,
        tracking=d1.tracking_out, now_epoch=1000.0 + 10 * 60, cfg=CFG,
    )
    assert d2.arm_allowed is False
    assert d2.tracking_out["QM5_SP"]["first_suppressed_epoch"] == 1000.0
    # past max wait (45 min) -> allowed by starvation guard
    d3 = rs.predrain_decision(
        heavy, window_candidates=window, free_ram_gb=30.0, active_cells=6,
        tracking=d2.tracking_out, now_epoch=1000.0 + 46 * 60, cfg=CFG,
    )
    assert d3.arm_allowed is True
    assert d3.reason.startswith("starvation_guard_override")
    assert "QM5_SP" not in d3.tracking_out


def test_tracking_cleared_when_conditions_clear():
    heavy = _c("h", 44.0, ea_id="QM5_SP")
    window_busy = [heavy, _c("a", 8.0)]
    d1 = rs.predrain_decision(
        heavy, window_candidates=window_busy, free_ram_gb=30.0, active_cells=6,
        tracking={}, now_epoch=1000.0, cfg=CFG,
    )
    assert "QM5_SP" in d1.tracking_out
    # next pass: quiet + no fitting smaller -> allowed, tracking cleared
    d2 = rs.predrain_decision(
        heavy, window_candidates=[heavy], free_ram_gb=30.0, active_cells=0,
        tracking=d1.tracking_out, now_epoch=1100.0, cfg=CFG,
    )
    assert d2.arm_allowed is True
    assert "QM5_SP" not in d2.tracking_out


def test_prune_tracking_drops_absent_rows():
    track = {"QM5_A": {"first_suppressed_epoch": 1.0}, "QM5_B": {"first_suppressed_epoch": 2.0}}
    out = rs.prune_tracking(track, live_heavy_ea_keys={"QM5_A"})
    assert out == {"QM5_A": {"first_suppressed_epoch": 1.0}}
