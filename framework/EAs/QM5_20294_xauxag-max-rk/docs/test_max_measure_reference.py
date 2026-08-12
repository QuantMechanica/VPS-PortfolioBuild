#!/usr/bin/env python3
"""Independent reference vectors for QM5_20294's locked low-MAX statistic."""
from __future__ import annotations

import math


LOOKBACK = 252
TOP_COUNT = 5
TOLERANCE = 1.0e-12


def prices_from_returns(returns: list[float], start: float = 100.0) -> list[float]:
    prices = [start]
    for value in returns:
        prices.append(prices[-1] * (1.0 + value))
    return prices


def max_measure(closes: list[float]) -> float:
    if len(closes) != LOOKBACK + 1:
        raise ValueError("exactly 253 closes required")
    if any(not math.isfinite(value) or value <= 0.0 for value in closes):
        raise ValueError("closes must be positive and finite")
    returns = [
        closes[index] / closes[index - 1] - 1.0
        for index in range(1, len(closes))
    ]
    if len(returns) != LOOKBACK or any(not math.isfinite(value) for value in returns):
        raise ValueError("exactly 252 finite simple returns required")
    return sum(sorted(returns)[-TOP_COUNT:]) / TOP_COUNT


def pair_direction(xau_max: float, xag_max: float) -> int:
    difference = xau_max - xag_max
    if not math.isfinite(difference):
        raise ValueError("finite rank difference required")
    if difference < -TOLERANCE:
        return 1
    if difference > TOLERANCE:
        return -1
    return 0


def main() -> None:
    background = [((index % 17) - 8) / 10_000.0 for index in range(LOOKBACK)]
    xau_returns = background.copy()
    xag_returns = background.copy()
    xau_returns[-5:] = [0.020, 0.021, 0.022, 0.023, 0.024]
    xag_returns[-5:] = [0.040, 0.041, 0.042, 0.043, 0.044]

    xau = max_measure(prices_from_returns(xau_returns))
    xag = max_measure(prices_from_returns(xag_returns))
    assert math.isclose(xau, 0.022, rel_tol=0.0, abs_tol=1.0e-14)
    assert math.isclose(xag, 0.042, rel_tol=0.0, abs_tol=1.0e-14)
    assert pair_direction(xau, xag) == 1
    assert pair_direction(xag, xau) == -1
    assert pair_direction(xau, xau + 0.5e-12) == 0

    single_max = max(xau_returns)
    assert not math.isclose(single_max, xau, rel_tol=0.0, abs_tol=1.0e-14)
    # MAX is an order statistic over the completed return set, so a pure
    # permutation must not change the measure; timestamp ordering is a
    # separate EA fail-closed guard.
    assert math.isclose(
        max_measure(prices_from_returns(list(reversed(xau_returns)))),
        xau,
        rel_tol=0.0,
        abs_tol=1.0e-14,
    )

    for bad in (
        prices_from_returns(xau_returns)[:-1],
        [0.0] + prices_from_returns(xau_returns)[1:],
        [math.nan] + prices_from_returns(xau_returns)[1:],
    ):
        try:
            max_measure(bad)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid input was accepted")

    print(
        "PASS "
        f"xau_max={xau:.12f} "
        f"xag_max={xag:.12f} "
        "direction=LONG_XAU_SHORT_XAG"
    )


if __name__ == "__main__":
    main()
