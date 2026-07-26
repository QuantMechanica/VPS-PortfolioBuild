"""Source-structure guard for the WS-G' target-before-day-4 fail-safe.

The governor EA is money-control MQL that this workstream cannot compile
offline (compile happens in the OWNER Factory-OFF window). These structural
assertions lock the exact fail-safe wiring so a later edit or a bad merge can
not silently drop it:

  * the distinct reason code TARGET_MIN_DAYS_PENDING exists in the policy include;
  * the EA remaps the before-four-days case to that code BEFORE the generic
    TARGET_CAPTURE branch, guarded by `trading_days < minimum_trading_days`;
  * the pending state remains latched (`g_target_lock`) so `must_lock` keeps the
    account entry-locked and flat — gains are protected, completion withheld;
  * a transition-throttled LiveOps log line is emitted.

Parallel to the existing structural checks in test_ftmo_governor_wiring.py.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA = ROOT / "framework" / "EAs" / "QM5_13206_ftmo-account-governor"
SOURCE = EA / "QM5_13206_ftmo-account-governor.mq5"
POLICY = ROOT / "framework" / "include" / "QM" / "QM_FTMOGovernorPolicy.mqh"


def test_policy_include_defines_distinct_min_days_pending_reason():
    policy = POLICY.read_text(encoding="utf-8")
    assert "QM_FTMO_GOVERNOR_TARGET_MIN_DAYS_PENDING = 11" in policy
    # Appended, not renumbered: existing published reason codes are unchanged.
    assert "QM_FTMO_GOVERNOR_INVALID_INPUT = 10," in policy
    assert "QM_FTMO_GOVERNOR_STATE_INVALID = 9," in policy


def test_ea_remaps_before_day4_to_min_days_pending_before_capture():
    source = SOURCE.read_text(encoding="utf-8")
    pending = source.index("publish_reason=QM_FTMO_GOVERNOR_TARGET_MIN_DAYS_PENDING")
    capture = source.index("publish_reason=QM_FTMO_GOVERNOR_TARGET_CAPTURE")
    complete = source.index("publish_reason=QM_FTMO_GOVERNOR_TARGET_COMPLETE")
    # complete (days met) -> pending (days short) -> capture (fallback) order.
    assert complete < pending < capture
    # The pending branch (its guard + assignment) sits between the COMPLETE and
    # CAPTURE branches and is gated by the minimum-opening-days shortfall while
    # completion has not yet been declared.
    branch = source[complete:capture]
    assert "g_trading_days < g_policy.minimum_trading_days" in branch
    assert "!g_target_complete" in branch


def test_pending_state_stays_latched_and_locked():
    source = SOURCE.read_text(encoding="utf-8")
    # must_lock includes g_target_lock, so a target-latched pending state is
    # entry-locked and flattened just like a normal capture.
    assert "const bool must_lock=(g_day_lock || g_total_lock || g_target_lock ||" in source
    assert "g_flatten_pending=((g_day_lock || g_total_lock || g_target_lock) &&" in source


def test_transition_throttled_liveops_log_present():
    source = SOURCE.read_text(encoding="utf-8")
    assert "int g_last_logged_reason=-1;" in source
    assert "FTMO_GOVERNOR_TARGET_REACHED_MIN_DAYS_PENDING" in source
    assert "publish_reason != g_last_logged_reason" in source
    assert "g_last_logged_reason=publish_reason;" in source
