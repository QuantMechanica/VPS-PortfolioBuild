"""The pump must never publish an .ex5 whose own .mq5 is still dirty.

Regression cover for 2026-08-17: the artifact auto-commit swept QM5_20176's freshly
compiled binary while an ops lane still held the matching source edit in the working
tree, so HEAD recorded an .ex5 that its own recorded .mq5 cannot produce.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import farmctl  # noqa: E402


def plan(entries, active=frozenset()):
    return farmctl._plan_artifact_auto_commit(list(entries), set(active))


EA = "framework/EAs/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery"


def test_ex5_held_back_when_its_own_source_is_dirty():
    result = plan([
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.mq5",
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5",
    ])
    assert result["valid"]
    assert result["commit_paths"] == []
    assert result["skipped_source_dirty_paths"] == [
        f"{EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5"
    ]


def test_ex5_committed_when_source_is_clean():
    result = plan([
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5",
    ])
    assert result["commit_paths"] == [
        f"{EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5"
    ]
    assert result["skipped_source_dirty_paths"] == []


def test_guard_is_per_ea_not_global():
    other = "framework/EAs/QM5_11301_tc-m5-macd1-stoch-ema5-open-close"
    result = plan([
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.mq5",
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5",
        f" M {other}/QM5_11301_tc-m5-macd1-stoch-ema5-open-close.ex5",
    ])
    # a dirty source on one EA must not hold back another EA's binary
    assert result["commit_paths"] == [
        f"{other}/QM5_11301_tc-m5-macd1-stoch-ema5-open-close.ex5"
    ]


def test_setfiles_are_not_held_back_by_a_dirty_source():
    # a .set is not produced by compiling the .mq5, so the pairing argument
    # does not apply to it and the dirty-guard unblock must keep working
    result = plan([
        f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.mq5",
        f" M {EA}/sets/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery_NDX.DWX_H4_backtest.set",
    ])
    assert result["commit_paths"] == [
        f"{EA}/sets/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery_NDX.DWX_H4_backtest.set"
    ]


def test_active_build_skip_still_wins():
    result = plan(
        [f" M {EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5"],
        active={"QM5_20176"},
    )
    assert result["commit_paths"] == []
    assert result["skipped_active_paths"] == [
        f"{EA}/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5"
    ]
    assert result["skipped_source_dirty_paths"] == []
