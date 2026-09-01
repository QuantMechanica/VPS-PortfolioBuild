"""Pure reference fixtures for QM5_41276 card arithmetic."""

from __future__ import annotations

from math import fsum, isclose, sqrt


Z_LOOKBACK = 40
RANGE_LOOKBACK = 250
Z_ENTRY = -2.0
Z_EXIT = -0.5
LOWER_DECILE = 0.10


def population_z(signal_close: float, prior_closes: list[float]) -> float:
    """Use C1..C40 only; the signal close C0 is ex-current."""
    reference = prior_closes[:Z_LOOKBACK]
    assert len(reference) == Z_LOOKBACK
    mean = fsum(reference) / Z_LOOKBACK
    variance = fsum((value - mean) ** 2 for value in reference) / Z_LOOKBACK
    assert variance > 0.0
    return (signal_close - mean) / sqrt(variance)


def prior_close_lower_decile(prior_closes: list[float]) -> float:
    reference = prior_closes[:RANGE_LOOKBACK]
    assert len(reference) == RANGE_LOOKBACK
    low = min(reference)
    high = max(reference)
    assert high > low
    return low + LOWER_DECILE * (high - low)


def entry_predicate(
    *,
    z_score: float,
    signal_open: float,
    signal_close: float,
    prior_close: float,
    lower_decile: float,
) -> bool:
    return (
        z_score < Z_ENTRY
        and signal_close <= lower_decile
        and signal_close > signal_open
        and signal_close > prior_close
    )


def stop_distance(
    *, entry: float, signal_low: float, atr: float
) -> float | None:
    structural_stop = signal_low - 0.25 * atr
    distance = max(entry - structural_stop, 1.25 * atr)
    if distance > 2.50 * atr:
        return None
    return distance


def test_population_z_excludes_signal_and_uses_divisor_forty() -> None:
    prior = [1.05 + index * 0.001 for index in range(Z_LOOKBACK)]
    signal = 0.95
    mean = fsum(prior) / Z_LOOKBACK
    expected_sd = sqrt(fsum((value - mean) ** 2 for value in prior) / 40)

    observed = population_z(signal, prior)

    assert isclose(observed, (signal - mean) / expected_sd, rel_tol=0, abs_tol=1e-12)
    # Adding C0 to the reference would produce a different statistic.
    contaminated = [signal, *prior[:-1]]
    assert not isclose(observed, population_z(signal, contaminated), abs_tol=1e-6)


def test_entry_boundary_at_minus_two_is_strict() -> None:
    kwargs = {
        "signal_open": 0.89,
        "signal_close": 0.90,
        "prior_close": 0.88,
        "lower_decile": 0.91,
    }
    assert not entry_predicate(z_score=-2.0, **kwargs)
    assert entry_predicate(z_score=-2.0000001, **kwargs)


def test_range_is_prior_250_closes_and_equality_is_admitted() -> None:
    prior = [0.88, 1.20, *([1.10] * 248)]
    threshold = prior_close_lower_decile(prior)
    assert isclose(threshold, 0.912, rel_tol=0, abs_tol=1e-12)
    assert entry_predicate(
        z_score=-2.1,
        signal_open=0.90,
        signal_close=threshold,
        prior_close=0.88,
        lower_decile=threshold,
    )


def test_bullish_reversal_requires_both_comparisons() -> None:
    base = {
        "z_score": -2.1,
        "signal_close": 0.90,
        "lower_decile": 0.91,
    }
    assert not entry_predicate(signal_open=0.90, prior_close=0.88, **base)
    assert not entry_predicate(signal_open=0.89, prior_close=0.90, **base)
    assert entry_predicate(signal_open=0.89, prior_close=0.88, **base)


def test_full_fixture_qualifies_only_with_excurrent_samples() -> None:
    prior = [0.88, *([1.20] * 39), *([1.10] * 210)]
    z_score = population_z(0.90, prior)
    threshold = prior_close_lower_decile(prior)
    assert z_score < Z_ENTRY
    assert entry_predicate(
        z_score=z_score,
        signal_open=0.89,
        signal_close=0.90,
        prior_close=prior[0],
        lower_decile=threshold,
    )


def test_z_exit_boundary_is_strict() -> None:
    assert not (-0.5 > Z_EXIT)
    assert -0.4999999 > Z_EXIT


def test_stop_uses_minimum_structural_distance_and_maximum_rejection() -> None:
    assert isclose(
        stop_distance(entry=1.0, signal_low=0.999, atr=0.01) or 0.0,
        0.0125,
        rel_tol=0,
        abs_tol=1e-12,
    )
    assert isclose(
        stop_distance(entry=1.0, signal_low=0.985, atr=0.01) or 0.0,
        0.0175,
        rel_tol=0,
        abs_tol=1e-12,
    )
    assert stop_distance(entry=1.0, signal_low=0.97, atr=0.01) is None
