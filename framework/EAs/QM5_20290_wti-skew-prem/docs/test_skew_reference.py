"""Independent reference vectors for QM5_20290's locked WTI skew contract."""

from __future__ import annotations

import math
from datetime import datetime, timedelta


LOOKBACK_MONTHS = 12
MIN_RETURNS = 180
MAX_RETURNS = 280
VARIANCE_FLOOR = 1.0e-12
SKEW_TOLERANCE = 1.0e-12


def month_key(value: datetime) -> int:
    return value.year * 100 + value.month


def shift_month_key(value: int, delta: int) -> int:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        raise ValueError("invalid_month_key")
    serial = year * 12 + month - 1 + delta
    if serial < 1900 * 12:
        raise ValueError("invalid_month_key")
    return (serial // 12) * 100 + serial % 12 + 1


def month_start(value: int) -> datetime:
    year, month = divmod(value, 100)
    if year < 1900 or not 1 <= month <= 12:
        raise ValueError("invalid_month_key")
    return datetime(year, month, 1)


def pearson_skew(returns: list[float]) -> tuple[float, str]:
    if not MIN_RETURNS <= len(returns) <= MAX_RETURNS:
        raise ValueError("return_count_out_of_bounds")
    if any(not math.isfinite(value) for value in returns):
        raise ValueError("invalid_daily_return")

    mean = sum(returns) / len(returns)
    centered = [value - mean for value in returns]
    variance = sum(value * value for value in centered) / len(centered)
    third_moment = sum(value * value * value for value in centered) / len(centered)
    if (
        not math.isfinite(mean)
        or not math.isfinite(variance)
        or not math.isfinite(third_moment)
        or variance <= VARIANCE_FLOOR
    ):
        raise ValueError("invalid_population_moments")

    skew = third_moment / math.pow(variance, 1.5)
    if not math.isfinite(skew):
        raise ValueError("invalid_pearson_skewness")
    if abs(skew) <= SKEW_TOLERANCE:
        return skew, "FLAT"
    return skew, "BUY" if skew < 0.0 else "SELL"


def select_formation_returns(
    rows: list[tuple[datetime, float]], current_month: int
) -> list[float]:
    first_month = shift_month_key(current_month, -LOOKBACK_MONTHS)
    formation_start = month_start(first_month)
    formation_end = month_start(current_month)
    expected_months = {
        shift_month_key(first_month, offset) for offset in range(LOOKBACK_MONTHS)
    }
    covered_months: set[int] = set()

    if not rows:
        raise ValueError("history_unavailable")
    for index, (timestamp, _) in enumerate(rows):
        if index and timestamp <= rows[index - 1][0]:
            raise ValueError("non_increasing_daily_time")

    output: list[float] = []
    for (prior_time, prior_close), (current_time, current_close) in zip(rows, rows[1:]):
        prior_in_window = formation_start <= prior_time < formation_end
        current_in_window = formation_start <= current_time < formation_end
        if not prior_in_window or not current_in_window:
            continue
        current_key = month_key(current_time)
        if current_key not in expected_months:
            raise ValueError("return_month_outside_formation")
        if (
            prior_close <= 0.0
            or current_close <= 0.0
            or not math.isfinite(prior_close)
            or not math.isfinite(current_close)
        ):
            raise ValueError("invalid_return_close")
        value = math.log(current_close / prior_close)
        if not math.isfinite(value):
            raise ValueError("invalid_daily_return")
        output.append(value)
        covered_months.add(current_key)

    if not MIN_RETURNS <= len(output) <= MAX_RETURNS:
        raise ValueError("return_count_out_of_bounds")
    if covered_months != expected_months:
        raise ValueError("missing_formation_month")
    return output


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


def weekday_dates(start: datetime, end: datetime) -> list[datetime]:
    output: list[datetime] = []
    cursor = start
    while cursor < end:
        if cursor.weekday() < 5:
            output.append(cursor)
        cursor += timedelta(days=1)
    return output


def rows_from_returns(
    dates: list[datetime], returns: list[float], first_close: float = 100.0
) -> list[tuple[datetime, float]]:
    assert len(returns) == len(dates) - 1
    closes = [first_close]
    for value in returns:
        closes.append(closes[-1] * math.exp(value))
    return list(zip(dates, closes))


def run() -> None:
    negative = [0.001] * 199 + [-0.04]
    positive = [-value for value in negative]
    negative_skew, negative_signal = pearson_skew(negative)
    positive_skew, positive_signal = pearson_skew(positive)
    assert negative_skew < 0.0 and negative_signal == "BUY"
    assert positive_skew > 0.0 and positive_signal == "SELL"
    assert math.isclose(positive_skew, -negative_skew, rel_tol=0.0, abs_tol=1.0e-14)

    symmetric = [0.01, -0.01] * 100
    symmetric_skew, symmetric_signal = pearson_skew(symmetric)
    assert abs(symmetric_skew) <= SKEW_TOLERANCE
    assert symmetric_signal == "FLAT"

    scaled_skew, scaled_signal = pearson_skew([7.0 * value for value in negative])
    assert math.isclose(scaled_skew, negative_skew, rel_tol=0.0, abs_tol=1.0e-13)
    assert scaled_signal == negative_signal

    current_month = 202607
    formation_dates = weekday_dates(datetime(2025, 7, 1), datetime(2026, 7, 1))
    formation_returns = [
        -0.012 if index % 53 == 0 else 0.0008
        for index in range(len(formation_dates) - 1)
    ]
    rows = [(datetime(2025, 6, 30), 5.0)]
    rows.extend(rows_from_returns(formation_dates, formation_returns))
    rows.append((datetime(2026, 7, 1), 5000.0))
    selected = select_formation_returns(rows, current_month)
    assert MIN_RETURNS <= len(selected) <= MAX_RETURNS
    assert len(selected) == len(formation_returns)
    assert all(
        math.isclose(actual, expected, rel_tol=0.0, abs_tol=2.0e-16)
        for actual, expected in zip(selected, formation_returns)
    )

    missing_august = [row for row in rows if month_key(row[0]) != 202508]
    expect_error(
        "missing_formation_month",
        lambda: select_formation_returns(missing_august, current_month),
    )
    expect_error("return_count_out_of_bounds", lambda: pearson_skew([0.01] * 179))
    expect_error("return_count_out_of_bounds", lambda: pearson_skew([0.01] * 281))
    expect_error("invalid_population_moments", lambda: pearson_skew([0.0] * 200))
    expect_error(
        "non_increasing_daily_time",
        lambda: select_formation_returns(list(reversed(rows)), current_month),
    )

    assert shift_month_key(202601, -1) == 202512
    assert shift_month_key(202512, 1) == 202601
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
    print("PASS: QM5_20290 independent WTI skew reference vectors")
