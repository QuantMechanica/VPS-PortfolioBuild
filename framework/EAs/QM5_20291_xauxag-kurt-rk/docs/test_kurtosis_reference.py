"""Deterministic reference checks for QM5_20291 historical kurtosis."""

from __future__ import annotations

import math


LOOKBACK = 252


def source_kurtosis(returns: list[float]) -> float:
    assert len(returns) == LOOKBACK
    mean_return = sum(returns) / LOOKBACK
    deviations = [value - mean_return for value in returns]
    sample_variance = sum(value * value for value in deviations) / (LOOKBACK - 1)
    fourth_moment = sum(value**4 for value in deviations) / LOOKBACK
    return fourth_moment / (sample_variance * sample_variance)


def ea_emulation(closes: list[float]) -> float:
    assert len(closes) == LOOKBACK + 1
    returns = [closes[index + 1] / closes[index] - 1.0 for index in range(LOOKBACK)]
    return source_kurtosis(returns)


def closes_from_returns(returns: list[float], start: float = 100.0) -> list[float]:
    closes = [start]
    for value in returns:
        closes.append(closes[-1] * (1.0 + value))
    return closes


def main() -> None:
    xau_returns = [0.0015 * math.sin(index * 0.31) for index in range(LOOKBACK)]
    xag_returns = [0.0012 * math.sin(index * 0.31) for index in range(LOOKBACK)]
    # Four deterministic shocks make the XAU sample more heavy-tailed.
    for index, shock in ((17, 0.06), (83, -0.055), (149, 0.05), (221, -0.045)):
        xau_returns[index] += shock

    xau_reference = source_kurtosis(xau_returns)
    xag_reference = source_kurtosis(xag_returns)
    xau_emulated = ea_emulation(closes_from_returns(xau_returns))
    xag_emulated = ea_emulation(closes_from_returns(xag_returns))

    assert math.isclose(xau_emulated, xau_reference, rel_tol=2e-12, abs_tol=2e-12)
    assert math.isclose(xag_emulated, xag_reference, rel_tol=2e-12, abs_tol=2e-12)
    assert xau_reference > xag_reference
    assert xau_reference - xag_reference > 1e-12  # long XAU, short XAG
    print(
        "PASS",
        f"xau_kurtosis={xau_reference:.12f}",
        f"xag_kurtosis={xag_reference:.12f}",
    )


if __name__ == "__main__":
    main()

