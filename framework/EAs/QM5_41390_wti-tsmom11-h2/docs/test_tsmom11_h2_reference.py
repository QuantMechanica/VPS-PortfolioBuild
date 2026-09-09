#!/usr/bin/env python3
"""Independent vectors for QM5_41390's locked statistic and clock."""

from __future__ import annotations

import math


def next_month(month_key: int) -> int:
    year, month = divmod(month_key, 100)
    if month == 12:
        return (year + 1) * 100 + 1
    return year * 100 + month + 1


def consecutive(month_keys: list[int]) -> bool:
    return len(month_keys) == 12 and all(
        next_month(month_keys[i]) == month_keys[i + 1] for i in range(11)
    )


def eligible_odd_month(month_key: int) -> bool:
    return month_key % 100 in {1, 3, 5, 7, 9, 11}


def signal(closes: list[float]) -> tuple[int | None, float | None]:
    if len(closes) != 12:
        return None, None
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        return None, None
    endpoint_return = math.log(closes[11] / closes[0])
    chained_return = sum(math.log(closes[i + 1] / closes[i]) for i in range(11))
    if not math.isfinite(endpoint_return) or not math.isfinite(chained_return):
        return None, None
    if abs(endpoint_return - chained_return) > 1.0e-10:
        return None, None
    if endpoint_return == 0.0:
        return 0, endpoint_return
    return (1 if endpoint_return > 0.0 else -1), endpoint_return


def should_roll(entry_month: int, current_month: int) -> bool:
    return current_month != entry_month and eligible_odd_month(current_month)


def main() -> None:
    months = [202603, 202604, 202605, 202606, 202607, 202608, 202609, 202610, 202611, 202612, 202701, 202702]
    assert consecutive(months)
    assert not consecutive([202603, 202604, 202605, 202606, 202607, 202608, 202609, 202610, 202612, 202701, 202702, 202703])

    rising = [100.0, 101.0, 99.0, 103.0, 102.0, 105.0, 104.0, 107.0, 106.0, 108.0, 109.0, 110.0]
    falling = [100.0, 99.0, 101.0, 96.0, 98.0, 94.0, 93.0, 92.0, 94.0, 91.0, 92.0, 90.0]
    flat = [100.0, 105.0, 95.0, 106.0, 94.0, 107.0, 93.0, 108.0, 92.0, 109.0, 91.0, 100.0]
    assert signal(rising)[0] == 1
    assert signal(falling)[0] == -1
    assert signal(flat)[0] == 0
    assert signal(rising[:-1])[0] is None
    invalid_nan = rising.copy()
    invalid_nan[11] = math.nan
    invalid_zero = rising.copy()
    invalid_zero[11] = 0.0
    assert signal(invalid_nan)[0] is None
    assert signal(invalid_zero)[0] is None

    irregular = [100.0, 92.0, 108.0, 91.0, 96.0, 89.0, 110.0, 97.0, 111.0, 98.0, 112.0, 104.0]
    direction, endpoint = signal(irregular)
    assert direction == 1 and endpoint is not None
    assert abs(endpoint - sum(math.log(irregular[i + 1] / irregular[i]) for i in range(11))) <= 1.0e-12

    eligible = [m for m in range(1, 13) if eligible_odd_month(202600 + m)]
    assert eligible == [1, 3, 5, 7, 9, 11]
    assert should_roll(202601, 202603)
    assert not should_roll(202601, 202602)
    assert not should_roll(202601, 202601)

    risk_fixed = 1000.0
    risk_percent = 0.0
    stress_probability = 0.0
    assert risk_fixed > 0.0 and risk_percent == 0.0
    assert math.isfinite(stress_probability) and 0.0 <= stress_probability <= 1.0

    print("PASS: QM5_41390 eleven-month bimonthly reference vectors")


if __name__ == "__main__":
    main()


