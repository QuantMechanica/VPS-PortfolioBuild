#!/usr/bin/env python3
"""Independent vectors for QM5_41379's locked statistic and clock."""

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
    return len(month_keys) == 4 and all(
        next_month(month_keys[i]) == month_keys[i + 1] for i in range(3)
    )


def eligible_odd_month(month_key: int) -> bool:
    month = month_key % 100
    return month_key >= 190001 and 1 <= month <= 12 and month % 2 == 1


def signal(closes: list[float]) -> tuple[int | None, float | None]:
    if len(closes) != 4:
        return None, None
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        return None, None
    endpoint_return = math.log(closes[3] / closes[0])
    chained_return = sum(math.log(closes[i + 1] / closes[i]) for i in range(3))
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
    assert consecutive([202611, 202612, 202701, 202702])
    assert not consecutive([202611, 202612, 202702, 202703])

    rising = [100.0, 103.0, 105.0, 110.0]
    falling = [100.0, 98.0, 95.0, 90.0]
    flat = [100.0, 105.0, 95.0, 100.0]
    assert signal(rising)[0] == 1
    assert signal(falling)[0] == -1
    assert signal(flat)[0] == 0
    assert signal(rising[:-1])[0] is None
    assert signal([100.0, math.nan, 105.0, 110.0])[0] is None
    assert signal([100.0, 0.0, 105.0, 110.0])[0] is None

    irregular = [100.0, 92.0, 108.0, 104.0]
    direction, endpoint = signal(irregular)
    assert direction == 1 and endpoint is not None
    assert abs(endpoint - sum(math.log(irregular[i + 1] / irregular[i]) for i in range(3))) <= 1.0e-12

    eligible = [m for m in range(1, 13) if eligible_odd_month(202600 + m)]
    assert eligible == [1, 3, 5, 7, 9, 11]
    assert not should_roll(202601, 202602)
    assert should_roll(202601, 202603)
    assert not should_roll(202603, 202603)
    assert should_roll(202611, 202701)

    print(json.dumps({
        "status": "PASS",
        "vectors": 13,
        "decision_months": eligible,
        "expected_packages_per_full_year": len(eligible),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
