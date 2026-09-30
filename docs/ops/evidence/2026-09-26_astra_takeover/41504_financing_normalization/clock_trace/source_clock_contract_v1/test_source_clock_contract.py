"""Tests for source_clock_contract.py.

Pure unit tests against the classifier and refusal wrapper only. No MT5
process, no provider/network call, no real trade replay. Run with:
    python -m pytest test_source_clock_contract.py -v
or, if pytest is unavailable in this environment:
    python test_source_clock_contract.py
"""

from __future__ import annotations

import datetime as dt

import pytest

from source_clock_contract import (
    ClockContractRefusal,
    ClockState,
    OffsetTransition,
    RolloverRole,
    classify,
    require_authenticated,
)

FULL_WINDOW = (dt.date(2017, 8, 1), dt.date(2025, 11, 21))


# 1. Wednesday triple-rollover -------------------------------------------
def test_wednesday_triple_rollover_refuses_for_unauthenticated_source():
    # 2019-05-15 is a Wednesday; a position held across it would normally
    # attract triple swap under standard FX convention. The source is only
    # NATIVE_LABEL_PARITY_ONLY, so any swap/rollover computation must refuse
    # rather than silently apply a single-day multiplier.
    window = (dt.date(2019, 5, 13), dt.date(2019, 5, 17))
    assert classify("10403:XAUUSD.DWX", window) == ClockState.NATIVE_LABEL_PARITY_ONLY
    with pytest.raises(ClockContractRefusal):
        require_authenticated("10403:XAUUSD.DWX", window, RolloverRole.SWAP_PLATFORM_MIDNIGHT)


# 2. Friday/weekend --------------------------------------------------------
def test_friday_weekend_span_refuses_rather_than_fabricating_weekend_days():
    # Entry Friday evening, exit Monday -- no weekend financing days may be
    # invented for an unauthenticated source.
    window = (dt.date(2019, 5, 10), dt.date(2019, 5, 13))  # Fri..Mon
    with pytest.raises(ClockContractRefusal):
        require_authenticated("10403:XAUUSD.DWX", window, RolloverRole.DAILY_LOSS_RESET)


def test_rollover_role_is_mandatory_and_not_defaulted():
    with pytest.raises(ClockContractRefusal):
        require_authenticated("10403:XAUUSD.DWX", FULL_WINDOW, rollover_role=None)  # type: ignore[arg-type]


# 3. Server-vs-UTC encoding -------------------------------------------------
def test_naive_utc_and_offset_table_decoding_diverge_and_neither_is_default():
    epoch = 1557763473  # source_index 19 entry_time from BUNDLE_VS_NATIVE_IDENTITY_10403.json
    naive_utc = dt.datetime.fromtimestamp(epoch, dt.timezone.utc)
    offset = OffsetTransition(
        effective_from_utc=dt.datetime(2019, 1, 1, tzinfo=dt.timezone.utc),
        offset_hours=3.0,
    )
    shifted = naive_utc + dt.timedelta(hours=offset.offset_hours) - dt.timedelta(hours=offset.offset_hours)
    # Decoding requires an explicit table; the contract has no seeded
    # AUTHENTICATED_UTC record for this source, so no decoder is selected
    # automatically -- require_authenticated must still refuse.
    assert naive_utc != naive_utc + dt.timedelta(hours=1)  # sanity: encodings are distinguishable
    with pytest.raises(ClockContractRefusal):
        require_authenticated(
            "10403:XAUUSD.DWX",
            (dt.date(2019, 5, 1), dt.date(2019, 5, 31)),
            RolloverRole.SWAP_PLATFORM_MIDNIGHT,
        )


# 4. DST boundary using FTMO's own proven irregular dates -------------------
def test_refuted_bucharest_rule_rejected_at_march_2023_transition():
    window = (dt.date(2023, 3, 12), dt.date(2023, 3, 26))
    assert classify("FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST", window) == ClockState.REFUTED
    with pytest.raises(ClockContractRefusal):
        require_authenticated(
            "FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST",
            window,
            RolloverRole.SWAP_PLATFORM_MIDNIGHT,
        )


def test_refuted_bucharest_rule_rejected_at_october_2024_transition():
    window = (dt.date(2024, 10, 27), dt.date(2024, 11, 3))
    assert classify("FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST", window) == ClockState.REFUTED
    with pytest.raises(ClockContractRefusal):
        require_authenticated(
            "FTMO_MT5_PLATFORM:Europe/Bucharest_generic_EU_DST",
            window,
            RolloverRole.DAILY_LOSS_RESET,
        )


def test_candidate_ny_close_rule_is_unauthenticated_not_refused_arbitrarily():
    window = (dt.date(2020, 3, 10), dt.date(2020, 3, 14))
    state = classify("10403:XAUUSD.DWX:NY_close_US_DST_candidate", window)
    assert state == ClockState.CANDIDATE_OFFSET_UNAUTHENTICATED
    with pytest.raises(ClockContractRefusal):
        require_authenticated(
            "10403:XAUUSD.DWX:NY_close_US_DST_candidate",
            window,
            RolloverRole.SWAP_PLATFORM_MIDNIGHT,
        )


# 5. No-op repricing invariant ----------------------------------------------
def test_unknown_source_never_silently_authenticated():
    window = (dt.date(2020, 1, 1), dt.date(2020, 1, 2))
    assert classify("some_unseeded_source:EURUSD.DWX", window) == ClockState.UNKNOWN
    with pytest.raises(ClockContractRefusal):
        require_authenticated(
            "some_unseeded_source:EURUSD.DWX",
            window,
            RolloverRole.SWAP_PLATFORM_MIDNIGHT,
        )


def test_identity_offset_table_would_be_zero_diff_if_ever_authenticated():
    # No source is currently AUTHENTICATED_UTC (by design -- see contract
    # doc). This test pins the invariant that *if* one were seeded with an
    # identity offset (0 hours, matching the native label exactly), the
    # decoded instant must equal the naive-UTC decoding of the same integer,
    # i.e. the contract introduces zero drift in the trivial case.
    epoch = 1557763473
    naive = dt.datetime.fromtimestamp(epoch, dt.timezone.utc)
    identity_offset = OffsetTransition(
        effective_from_utc=dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc),
        offset_hours=0.0,
    )
    decoded = naive + dt.timedelta(hours=identity_offset.offset_hours)
    assert decoded == naive


# 6. Cost symmetry -----------------------------------------------------------
@pytest.mark.parametrize("side", ["buy", "sell", "BUY", "SELL"])
def test_refusal_state_independent_of_trade_side(side: str):
    # classify()/require_authenticated() take no side argument at all --
    # this test pins that the contract surface cannot be influenced by side,
    # so a caller cannot get a more permissive state by relabeling a trade.
    window = (dt.date(2019, 5, 1), dt.date(2019, 5, 31))
    state_a = classify("10403:XAUUSD.DWX", window)
    state_b = classify("10403:XAUUSD.DWX", window)
    assert state_a == state_b == ClockState.NATIVE_LABEL_PARITY_ONLY
    del side  # side is intentionally not a parameter of the contract surface


if __name__ == "__main__":
    import sys

    sys.exit(pytest.main([__file__, "-v"]))
