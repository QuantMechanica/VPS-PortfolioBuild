#!/usr/bin/env python3
"""Independent reference vectors for QM5_20293's exact nine-month return."""

from __future__ import annotations

import math


RETURN_MONTHS = 9
REQUIRED_CLOSES = RETURN_MONTHS + 1


def exact_nine_month_return(closes: list[float]) -> float:
    """Return ln(newest/oldest) for ten chronological month-end closes."""
    if len(closes) != REQUIRED_CLOSES:
        raise ValueError("exactly ten chronological month-end closes are required")
    if not all(math.isfinite(value) and value > 0.0 for value in closes):
        raise ValueError("all closes must be finite and positive")

    endpoint_return = math.log(closes[9] / closes[0])
    chained_return = sum(
        math.log(closes[index + 1] / closes[index])
        for index in range(RETURN_MONTHS)
    )
    if not math.isclose(endpoint_return, chained_return, rel_tol=0.0, abs_tol=1.0e-12):
        raise AssertionError("endpoint and chained log returns must telescope")
    return endpoint_return


def signal(value: float) -> int:
    if value > 0.0:
        return 1
    if value < 0.0:
        return -1
    return 0


def horizon_return(closes: list[float], months: int) -> float:
    return math.log(closes[-1] / closes[-1 - months])


def assert_close(actual: float, expected: float, tolerance: float = 1.0e-14) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance):
        raise AssertionError(f"actual={actual!r} expected={expected!r}")


def main() -> None:
    rising = [100.0, 104.0, 102.0, 111.0, 108.0, 115.0, 117.0, 113.0, 119.0, 120.0]
    falling = list(reversed(rising))
    flat_endpoint = [100.0, 120.0, 80.0, 105.0, 95.0, 130.0, 90.0, 110.0, 125.0, 100.0]

    assert_close(exact_nine_month_return(rising), math.log(1.2))
    assert_close(exact_nine_month_return(falling), math.log(1.0 / 1.2))
    assert signal(exact_nine_month_return(rising)) == 1
    assert signal(exact_nine_month_return(falling)) == -1
    assert signal(exact_nine_month_return(flat_endpoint)) == 0

    assert_close(
        exact_nine_month_return(rising),
        -exact_nine_month_return(falling),
    )

    alternate_path = [100.0, 60.0, 180.0, 75.0, 130.0, 90.0, 145.0, 85.0, 110.0, 120.0]
    assert_close(
        exact_nine_month_return(alternate_path),
        exact_nine_month_return(rising),
    )

    # Exact nine completed months diverge from neighboring registered horizons.
    horizon_vector = [200.0, 180.0, 160.0, 100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 150.0, 140.0, 130.0]
    assert signal(horizon_return(horizon_vector, 9)) == 1
    assert signal(horizon_return(horizon_vector, 4)) == -1
    assert signal(horizon_return(horizon_vector, 12)) == -1
    assert_close(
        exact_nine_month_return(horizon_vector[-REQUIRED_CLOSES:]),
        horizon_return(horizon_vector, 9),
    )

    invalid_vectors = (
        [100.0] * 9,
        [100.0, 101.0, 102.0, 103.0, 0.0, 105.0, 106.0, 107.0, 108.0, 109.0],
        [100.0, 101.0, 102.0, 103.0, math.inf, 105.0, 106.0, 107.0, 108.0, 109.0],
        [100.0, 101.0, 102.0, 103.0, math.nan, 105.0, 106.0, 107.0, 108.0, 109.0],
    )
    for vector in invalid_vectors:
        try:
            exact_nine_month_return(vector)
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid vector accepted: {vector!r}")

    print("PASS QM5_20293 exact nine-month return reference vectors")


if __name__ == "__main__":
    main()
