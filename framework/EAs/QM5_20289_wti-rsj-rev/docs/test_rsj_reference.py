"""Independent reference vectors for QM5_20289's locked WTI RSJ contract."""

from __future__ import annotations

import math
from datetime import datetime, timedelta


MIN_RETURNS = 15
MAX_RETURNS = 25
TOLERANCE = 1.0e-12


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def rsj_from_returns(returns: list[float]) -> tuple[float, str]:
    if not MIN_RETURNS <= len(returns) <= MAX_RETURNS:
        raise ValueError("return_count_out_of_bounds")

    rv_plus = 0.0
    rv_minus = 0.0
    for value in returns:
        if not math.isfinite(value):
            raise ValueError("invalid_daily_return")
        squared = value * value
        if value > 0.0:
            rv_plus += squared
        elif value < 0.0:
            rv_minus += squared

    total = rv_plus + rv_minus
    if not math.isfinite(total) or total <= 0.0:
        raise ValueError("invalid_total_variance")

    rsj = (rv_plus - rv_minus) / total
    if not math.isfinite(rsj) or not -1.0 - TOLERANCE <= rsj <= 1.0 + TOLERANCE:
        raise ValueError("rsj_out_of_bounds")

    if rsj < 0.0:
        signal = "BUY"
    elif rsj > 0.0:
        signal = "SELL"
    else:
        signal = "FLAT"
    return rsj, signal


def select_prior_month_returns(
    rows: list[tuple[datetime, float]], expected_month: int
) -> list[float]:
    if not rows:
        raise ValueError("history_unavailable")

    first = -1
    last = -1
    left_prior_month = False
    previous_time: datetime | None = None

    for index, (timestamp, close) in enumerate(rows):
        if previous_time is not None and timestamp <= previous_time:
            raise ValueError("non_increasing_daily_time")
        previous_time = timestamp

        if month_key(timestamp) == expected_month:
            if left_prior_month:
                raise ValueError("disjoint_prior_month")
            if not math.isfinite(close) or close <= 0.0:
                raise ValueError("invalid_prior_month_close")
            if first < 0:
                first = index
            last = index
        elif first >= 0:
            left_prior_month = True

    if first < 0 or last <= first:
        raise ValueError("prior_month_not_reconstructed")

    count = last - first
    if not MIN_RETURNS <= count <= MAX_RETURNS:
        raise ValueError("return_count_out_of_bounds")

    output: list[float] = []
    for index in range(first + 1, last + 1):
        previous_timestamp, previous_close = rows[index - 1]
        timestamp, close = rows[index]
        if (
            month_key(previous_timestamp) != expected_month
            or month_key(timestamp) != expected_month
        ):
            raise ValueError("return_crosses_month_boundary")
        value = math.log(close / previous_close)
        if not math.isfinite(value):
            raise ValueError("invalid_daily_return")
        output.append(value)
    return output


def closes_from_returns(start: float, returns: list[float]) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return closes


def genuine_month_transition(
    current_bar: datetime,
    previous_bar: datetime,
    calendar_current: int,
    calendar_previous: int,
) -> bool:
    current_key = month_key(current_bar)
    previous_key = month_key(previous_bar)
    return (
        current_key != previous_key
        and current_key == calendar_current
        and previous_key == calendar_previous
    )


def expect_error(name: str, action) -> None:
    try:
        action()
    except ValueError as exc:
        assert str(exc) == name, (str(exc), name)
    else:
        raise AssertionError(f"expected {name}")


def run() -> None:
    downside = [-0.02] * 10 + [0.005] * 5
    upside = [0.02] * 10 + [-0.005] * 5

    downside_rsj, downside_signal = rsj_from_returns(downside)
    upside_rsj, upside_signal = rsj_from_returns(upside)
    assert downside_rsj < 0.0 and downside_signal == "BUY"
    assert upside_rsj > 0.0 and upside_signal == "SELL"

    balanced = [0.01, -0.01] + [0.0] * 13
    balanced_rsj, balanced_signal = rsj_from_returns(balanced)
    assert balanced_rsj == 0.0 and balanced_signal == "FLAT"

    scaled_rsj, scaled_signal = rsj_from_returns([7.0 * value for value in downside])
    assert math.isclose(scaled_rsj, downside_rsj, rel_tol=0.0, abs_tol=1.0e-15)
    assert scaled_signal == downside_signal

    zeros_counted = [-0.02] * 8 + [0.01] * 2 + [0.0] * 5
    zero_rsj, zero_signal = rsj_from_returns(zeros_counted)
    assert zero_rsj < 0.0 and zero_signal == "BUY"

    expected_month = 202606
    june_returns = [-0.015] * 9 + [0.004] * 6
    june_closes = closes_from_returns(125.0, june_returns)
    rows = [(datetime(2026, 5, 31), 1.0)]
    rows.extend(
        (datetime(2026, 6, 1) + timedelta(days=index), close)
        for index, close in enumerate(june_closes)
    )
    rows.append((datetime(2026, 7, 1), 5000.0))
    selected = select_prior_month_returns(rows, expected_month)
    assert len(selected) == 15
    assert all(
        math.isclose(actual, expected, rel_tol=0.0, abs_tol=2.0e-16)
        for actual, expected in zip(selected, june_returns)
    )
    selected_rsj, selected_signal = rsj_from_returns(selected)
    direct_rsj, direct_signal = rsj_from_returns(june_returns)
    assert math.isclose(selected_rsj, direct_rsj, rel_tol=0.0, abs_tol=1.0e-14)
    assert selected_signal == direct_signal == "BUY"

    expect_error("return_count_out_of_bounds", lambda: rsj_from_returns([0.01] * 14))
    expect_error("return_count_out_of_bounds", lambda: rsj_from_returns([0.01] * 26))
    expect_error("invalid_total_variance", lambda: rsj_from_returns([0.0] * 15))
    expect_error(
        "non_increasing_daily_time",
        lambda: select_prior_month_returns(list(reversed(rows)), expected_month),
    )

    assert genuine_month_transition(
        datetime(2026, 7, 1), datetime(2026, 6, 30), 202607, 202606
    )
    assert not genuine_month_transition(
        datetime(2026, 7, 15), datetime(2026, 7, 14), 202607, 202606
    )
    assert not genuine_month_transition(
        datetime(2026, 8, 1), datetime(2026, 6, 30), 202608, 202607
    )


if __name__ == "__main__":
    run()
    print("PASS: QM5_20289 independent RSJ reference vectors")


