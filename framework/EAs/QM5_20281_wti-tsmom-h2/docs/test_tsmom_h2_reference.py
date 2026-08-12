#!/usr/bin/env python3
"""Independent reference vectors for QM5_20281's locked statistic and clock."""

from __future__ import annotations

import json
import math


def next_month(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if year < 1900 or not 1 <= month <= 12:
        raise ValueError("invalid month key")
    month += 1
    if month == 13:
        year += 1
        month = 1
    return year * 100 + month


def consecutive(month_keys: list[int]) -> bool:
    return len(month_keys) == 13 and all(
        next_month(month_keys[i]) == month_keys[i + 1]
        for i in range(12)
    )


def eligible_odd_month(month_key: int) -> bool:
    month = month_key % 100
    return month_key >= 190001 and 1 <= month <= 12 and month % 2 == 1


def signal(closes: list[float]) -> tuple[int | None, float | None]:
    if len(closes) != 13:
        return None, None
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        return None, None
    endpoint_return = math.log(closes[12] / closes[0])
    chained_return = sum(
        math.log(closes[i + 1] / closes[i]) for i in range(12)
    )
    if not math.isfinite(endpoint_return) or not math.isfinite(chained_return):
        return None, None
    if abs(endpoint_return - chained_return) > 1.0e-10:
        return None, None
    if endpoint_return == 0.0:
        return 0, endpoint_return
    return (1 if endpoint_return > 0.0 else -1), endpoint_return


def should_roll(entry_month: int, current_month: int) -> bool:
    return eligible_odd_month(current_month) and entry_month != current_month


def main() -> None:
    keys = [202312]
    for _ in range(12):
        keys.append(next_month(keys[-1]))
    assert consecutive(keys)
    assert not consecutive(keys[:-1] + [202501])

    rising = [100.0 * (1.01**i) for i in range(13)]
    falling = [100.0 * (0.99**i) for i in range(13)]
    flat = [100.0] * 13
    assert signal(rising)[0] == 1
    assert signal(falling)[0] == -1
    assert signal(flat)[0] == 0
    assert signal(rising[:-1])[0] is None
    assert signal(rising[:6] + [0.0] + rising[7:])[0] is None

    # The same endpoint statistic must equal the sum of all 12 adjacent logs.
    irregular = [100, 104, 98, 105, 101, 109, 106, 112, 108, 117, 121, 118, 125]
    irregular_signal, irregular_return = signal(irregular)
    assert irregular_signal == 1
    assert irregular_return is not None
    assert abs(
        irregular_return
        - sum(math.log(irregular[i + 1] / irregular[i]) for i in range(12))
    ) <= 1.0e-12

    # A negative newest month does not turn this into the existing pullback rule.
    counter_move = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 120, 115]
    assert signal(counter_move)[0] == 1
    assert math.log(counter_move[-1] / counter_move[-2]) < 0.0

    eligible = [month for month in range(1, 13) if eligible_odd_month(202600 + month)]
    assert eligible == [1, 3, 5, 7, 9, 11]
    assert not should_roll(202601, 202602)
    assert should_roll(202601, 202603)
    assert not should_roll(202603, 202603)
    assert should_roll(202611, 202701)

    print(
        json.dumps(
            {
                "status": "PASS",
                "vectors": [
                    "month_key_continuity_cross_year",
                    "positive_negative_exact_zero",
                    "invalid_count_and_close",
                    "endpoint_chained_log_identity",
                    "newest_month_countermove_nonconjunction",
                    "six_odd_month_decisions",
                    "even_month_hold_and_odd_month_rollover",
                ],
                "decision_months": eligible,
                "expected_packages_per_full_year": len(eligible),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
