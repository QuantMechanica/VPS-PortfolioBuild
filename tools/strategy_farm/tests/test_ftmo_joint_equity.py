import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.strategy_farm.portfolio import ftmo_joint_equity as joint  # noqa: E402


def row(ts, balance=100_000.0, equity=None, open_positions=0, opened=0, anchor=False):
    return {
        "ts_utc": ts,
        "balance": balance,
        "equity": balance if equity is None else equity,
        "open_positions": open_positions,
        "opened_positions": opened,
        "day_anchor": anchor,
    }


def test_floating_and_closed_losses_share_daily_floor() -> None:
    trace = [
        row("2026-01-04T23:00:00Z", anchor=True),
        row("2026-01-05T10:00:00Z", balance=97_000.0, equity=94_999.0, open_positions=1),
    ]
    result = joint.evaluate_path(trace)
    assert result["status"] == "DAILY_BREACH"
    assert result["floor"] == 95_000.0


def test_exact_daily_loss_floor_is_a_breach() -> None:
    trace = [
        row("2026-01-04T23:00:00Z", anchor=True),
        row("2026-01-05T10:00:00Z", balance=97_000.0, equity=95_000.0, open_positions=1),
    ]

    result = joint.evaluate_path(trace)

    assert result["status"] == "DAILY_BREACH"
    assert result["floor"] == 95_000.0


def test_exact_static_max_loss_floor_is_a_breach() -> None:
    trace = [row("2026-01-04T23:00:00Z", equity=90_000.0, anchor=True)]

    result = joint.evaluate_path(trace)

    assert result["status"] == "MAX_BREACH"
    assert result["floor"] == 90_000.0


def test_static_max_loss_can_bind_without_daily_breach() -> None:
    trace = [
        row("2026-01-04T23:00:00Z", anchor=True),
        row("2026-01-05T20:00:00Z", balance=97_000.0, equity=97_000.0),
        row("2026-01-05T23:00:00Z", balance=97_000.0, equity=97_000.0, anchor=True),
        row("2026-01-06T20:00:00Z", balance=94_000.0, equity=94_000.0),
        row("2026-01-06T23:00:00Z", balance=94_000.0, equity=94_000.0, anchor=True),
        row("2026-01-07T10:00:00Z", balance=94_000.0, equity=89_999.0),
    ]
    result = joint.evaluate_path(trace)
    assert result["status"] == "MAX_BREACH"
    assert result["floor"] == 90_000.0


def test_target_requires_four_trading_days_and_flat_book() -> None:
    trace = []
    anchors = [
        "2026-01-04T23:00:00Z",
        "2026-01-05T23:00:00Z",
        "2026-01-06T23:00:00Z",
        "2026-01-07T23:00:00Z",
    ]
    balance = 100_000.0
    for index, anchor in enumerate(anchors):
        trace.append(row(anchor, balance=balance, anchor=True))
        balance += 2_500.0
        trace.append(row(
            anchor.replace("23:00:00Z", "23:30:00Z"),
            balance=balance,
            open_positions=1 if index == 3 else 0,
            opened=1,
        ))
    trace.append(row("2026-01-08T00:00:00Z", balance=110_000.0, open_positions=0))

    result = joint.evaluate_path(trace)
    assert result["status"] == "PASS"
    assert result["trading_days"] == 4


def test_missing_midnight_anchor_fails_closed() -> None:
    result = joint.evaluate_path([row("2026-01-05T10:00:00Z")])
    assert result == {
        "status": "INVALID",
        "reason": "day_anchor_missing:2026-01-05",
        "sample_index": 0,
    }


def test_missing_prague_calendar_day_fails_closed() -> None:
    trace = [
        row("2026-01-04T23:00:00Z", anchor=True),  # 2026-01-05 00:00 CET
        row("2026-01-06T23:00:00Z", anchor=True),  # 2026-01-07 00:00 CET
    ]

    result = joint.evaluate_path(trace)

    assert result == {
        "status": "INVALID",
        "reason": "day_anchor_gap:2026-01-05->2026-01-07",
        "sample_index": 1,
    }


def test_prague_dst_midnight_anchors_are_recognized() -> None:
    trace = [
        row("2026-03-28T23:00:00Z", anchor=True),  # 00:00 CET
        row("2026-03-29T22:00:00Z", anchor=True),  # 00:00 CEST after transition
    ]
    result = joint.evaluate_path(trace)
    assert result["status"] == "NOT_REACHED"


def test_two_phase_uses_fresh_starting_balance() -> None:
    def passing_trace(target):
        trace = []
        for index in range(4):
            anchor = f"2026-02-0{index + 1}T23:00:00Z"
            trace.append(row(anchor, balance=100_000.0 if index == 0 else target - 1, anchor=True))
            trace.append(row(
                anchor.replace("23:00:00Z", "23:30:00Z"),
                balance=target if index == 3 else target - 1,
                opened=1,
            ))
        return trace

    result = joint.evaluate_two_phase(passing_trace(110_000.0), passing_trace(105_000.0))
    assert result["status"] == "PASS"
    assert result["phase1"]["balance"] == 110_000.0
    assert result["phase2"]["balance"] == 105_000.0


def sleeve_row(
    ts,
    balance_delta,
    equity_delta,
    opened=0,
    anchor=False,
    open_positions=0,
):
    return {
        "ts_utc": ts,
        "balance_delta": balance_delta,
        "equity_delta": equity_delta,
        "open_positions": open_positions,
        "opened_positions": opened,
        "day_anchor": anchor,
    }


def test_joint_combination_preserves_common_grid_and_scales() -> None:
    timestamps = ["2026-01-04T23:00:00Z", "2026-01-05T10:00:00Z"]
    traces = {
        "a": [sleeve_row(timestamps[0], 0, 0, anchor=True), sleeve_row(timestamps[1], 100, 80, opened=1)],
        "b": [sleeve_row(timestamps[0], 0, 0, anchor=True), sleeve_row(timestamps[1], -20, -50)],
    }
    combined = joint.combine_sleeve_traces(traces, scales={"a": 2.0, "b": 1.0})
    assert combined[-1]["balance"] == 100_180.0
    assert combined[-1]["equity"] == 100_110.0
    assert combined[-1]["opened_positions"] == 1


def test_joint_combination_rejects_different_timestamp_grids() -> None:
    traces = {
        "a": [sleeve_row("2026-01-04T23:00:00Z", 0, 0, anchor=True)],
        "b": [sleeve_row("2026-01-04T23:01:00Z", 0, 0, anchor=True)],
    }
    with pytest.raises(joint.TraceValidationError, match="sleeve_grid_mismatch:b"):
        joint.combine_sleeve_traces(traces)


def test_zero_scale_sleeve_contributes_no_position_or_opening_counts() -> None:
    timestamp = "2026-01-04T23:00:00Z"
    traces = {
        "active": [sleeve_row(timestamp, 0, 0, anchor=True)],
        "disabled": [
            sleeve_row(
                timestamp,
                1_000,
                -5_000,
                opened=3,
                anchor=True,
                open_positions=2,
            )
        ],
    }

    combined = joint.combine_sleeve_traces(
        traces,
        scales={"active": 1.0, "disabled": 0.0},
    )

    assert combined[0]["balance"] == 100_000.0
    assert combined[0]["equity"] == 100_000.0
    assert combined[0]["open_positions"] == 0
    assert combined[0]["opened_positions"] == 0
    result = joint.evaluate_path(combined)
    assert result["status"] == "NOT_REACHED"
    assert result["trading_days"] == 0
