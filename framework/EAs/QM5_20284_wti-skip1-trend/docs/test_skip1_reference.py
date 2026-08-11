#!/usr/bin/env python3
"""Independent reference vectors for QM5_20284's skipped-month trend rule."""

from __future__ import annotations

import json
import math


def delayed_trend(closes: list[float]) -> tuple[int, float, float]:
    """Return signal, older 12-month return, and excluded newest return."""
    assert len(closes) == 14
    assert all(math.isfinite(value) and value > 0.0 for value in closes)
    trend_return = math.log(closes[12] / closes[0])
    skipped_return = math.log(closes[13] / closes[12])
    signal = 0 if trend_return == 0.0 else 1 if trend_return > 0.0 else -1
    return signal, trend_return, skipped_return


def pullback_gate(signal: int, skipped_return: float) -> bool:
    return (signal > 0 and skipped_return < 0.0) or (
        signal < 0 and skipped_return > 0.0
    )


def trailing_twelve_month_signal(closes: list[float]) -> int:
    """Nearest ordinary rule: twelve months ending at the newest endpoint."""
    value = math.log(closes[13] / closes[1])
    return 0 if value == 0.0 else 1 if value > 0.0 else -1


def consecutive_month_keys(start_year: int, start_month: int, count: int) -> list[int]:
    keys: list[int] = []
    year, month = start_year, start_month
    for _ in range(count):
        keys.append(year * 100 + month)
        month += 1
        if month > 12:
            year += 1
            month = 1
    return keys


def main() -> int:
    # Oldest through newest completed month. The first thirteen endpoints form
    # the signal interval; the final endpoint changes only the excluded return.
    base = [100.0 + index for index in range(13)]

    agreeing = [*base, 120.0]
    agree_signal, agree_trend, agree_skipped = delayed_trend(agreeing)
    assert agree_signal == 1
    assert agree_skipped > 0.0
    assert not pullback_gate(agree_signal, agree_skipped)

    opposing = [*base, 80.0]
    oppose_signal, oppose_trend, oppose_skipped = delayed_trend(opposing)
    assert oppose_signal == 1
    assert oppose_skipped < 0.0
    assert pullback_gate(oppose_signal, oppose_skipped)
    assert math.isclose(agree_trend, oppose_trend, abs_tol=1.0e-15)

    # A large excluded-month shock can reverse the ordinary trailing 12-month
    # rule but cannot change this card's delayed signal.
    assert trailing_twelve_month_signal(opposing) == -1

    falling = [140.0 - 2.0 * index for index in range(13)] + [130.0]
    short_signal, short_trend, short_skipped = delayed_trend(falling)
    assert short_signal == -1 and short_trend < 0.0 and short_skipped > 0.0

    exact_zero = [100.0 + index for index in range(12)] + [100.0, 250.0]
    zero_signal, zero_trend, zero_skipped = delayed_trend(exact_zero)
    assert zero_signal == 0 and zero_trend == 0.0 and zero_skipped > 0.0

    keys = consecutive_month_keys(2025, 6, 14)
    assert keys == [
        202506, 202507, 202508, 202509, 202510, 202511, 202512,
        202601, 202602, 202603, 202604, 202605, 202606, 202607,
    ]

    result = {
        "status": "PASS",
        "agreeing_newest_month_still_trades": {
            "signal": agree_signal,
            "trend_return": agree_trend,
            "skipped_return": agree_skipped,
            "pullback_neighbor_would_enter": False,
        },
        "opposing_newest_month_same_signal": {
            "signal": oppose_signal,
            "trend_return": oppose_trend,
            "skipped_return": oppose_skipped,
            "ordinary_trailing_signal": trailing_twelve_month_signal(opposing),
        },
        "short_case": {
            "signal": short_signal,
            "trend_return": short_trend,
            "skipped_return": short_skipped,
        },
        "exact_zero": {
            "signal": zero_signal,
            "trend_return": zero_trend,
            "skipped_return": zero_skipped,
        },
        "month_keys": keys,
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
