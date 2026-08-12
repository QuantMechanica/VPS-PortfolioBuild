#!/usr/bin/env python3
"""Independent vectors for QM5_20288's locked monthly L2 statistic."""

from __future__ import annotations

import math

MONTHS = 12
MIN_RETURNS = 15
MAX_RETURNS = 25
IDENTITY_TOLERANCE = 1.0e-10


def sequential_sum(values: list[float]) -> float:
    total = 0.0
    for value in values:
        total += value
    return total


def endpoint_from_prices(start_price: float, returns: list[float]) -> float:
    price = start_price
    for daily_return in returns:
        price *= math.exp(daily_return)
    return math.log(price / start_price)


def volnorm_score(
    paths: list[list[float]], endpoint_returns: list[float]
) -> float:
    if len(paths) != MONTHS or len(endpoint_returns) != MONTHS:
        raise ValueError("exactly twelve monthly paths are required")

    normalized_sum = 0.0
    for path, endpoint_return in zip(paths, endpoint_returns, strict=True):
        if not MIN_RETURNS <= len(path) <= MAX_RETURNS:
            raise ValueError("daily return count is outside [15, 25]")
        daily_sum = sequential_sum(path)
        square_sum = sequential_sum([value * value for value in path])
        l2_norm = math.sqrt(square_sum)
        if not all(
            math.isfinite(value)
            for value in (daily_sum, square_sum, l2_norm, endpoint_return)
        ):
            raise ValueError("nonfinite arithmetic")
        if l2_norm <= 0.0:
            raise ValueError("nonpositive L2 norm")
        if abs(daily_sum - endpoint_return) > IDENTITY_TOLERANCE:
            raise ValueError("endpoint identity failed")
        normalized_sum += daily_sum / l2_norm

    score = normalized_sum / MONTHS
    if not math.isfinite(score):
        raise ValueError("nonfinite final score")
    return score


def endpoints(paths: list[list[float]]) -> list[float]:
    return [endpoint_from_prices(80.0 + index, path) for index, path in enumerate(paths)]


def expect_rejected(paths: list[list[float]], direct: list[float]) -> None:
    try:
        volnorm_score(paths, direct)
    except ValueError:
        return
    raise AssertionError("invalid vector was accepted")


def main() -> None:
    smooth_up = [[0.001] * 20 for _ in range(MONTHS)]
    smooth_down = [[-0.001] * 20 for _ in range(MONTHS)]
    assert volnorm_score(smooth_up, endpoints(smooth_up)) > 0.0
    assert volnorm_score(smooth_down, endpoints(smooth_down)) < 0.0

    balanced = smooth_up[:6] + smooth_down[:6]
    assert abs(volnorm_score(balanced, endpoints(balanced))) < 1.0e-12

    # A single large positive shock cannot dominate eleven smooth negative months.
    shock_up = [[0.20] + [0.0] * 19]
    shock_against_eleven = shock_up + smooth_down[:11]
    assert volnorm_score(shock_against_eleven, endpoints(shock_against_eleven)) < 0.0

    mixed = [
        [0.002, -0.001, 0.0015, -0.0005] * 5
        for _ in range(MONTHS)
    ]
    scaled = [[value * 7.0 for value in path] for path in mixed]
    assert math.isclose(
        volnorm_score(mixed, endpoints(mixed)),
        volnorm_score(scaled, endpoints(scaled)),
        rel_tol=0.0,
        abs_tol=1.0e-12,
    )

    bad_identity = endpoints(smooth_up)
    bad_identity[5] += 2.0e-10
    expect_rejected(smooth_up, bad_identity)

    too_short = [path[:] for path in smooth_up]
    too_short[0] = [0.001] * 14
    expect_rejected(too_short, endpoints(too_short))

    too_long = [path[:] for path in smooth_up]
    too_long[0] = [0.001] * 26
    expect_rejected(too_long, endpoints(too_long))

    zero_norm = [path[:] for path in smooth_up]
    zero_norm[0] = [0.0] * 20
    expect_rejected(zero_norm, endpoints(zero_norm))

    print("QM5_20288 volnorm reference vectors: PASS")


if __name__ == "__main__":
    main()
