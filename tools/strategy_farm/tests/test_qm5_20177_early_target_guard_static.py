from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_20177_carney-ab-cd-pattern-h4-r1-recovery"
SOURCE = EA_DIR / "QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5"


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def test_qm5_20177_entry_signal_rejects_early_target_at_fill() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    entry_body = _function_body(source, "bool Strategy_EntrySignal(QM_EntryRequest &req)")

    # Ensure long branch computes T1 target and requires ask < t1 before accepting entry
    assert "const double t1 = d_proj + t1_fib * (C - d_proj);" in entry_body
    assert "const bool t1_ok = (ask < t1);" in entry_body
    assert "long_ok = touch_ok && confirm_ok && t1_ok" in entry_body

    # Ensure short branch computes T1 target and requires bid > t1 before accepting entry
    assert "const double t1 = d_proj + t1_fib * (C2p - d_proj);" in entry_body
    assert "const bool t1_ok = (bid > t1);" in entry_body
    assert "short_ok = touch_ok && confirm_ok && t1_ok" in entry_body


@dataclass
class Bar:
    time: int
    open: float
    high: float
    low: float
    close: float


def _assert_valid_bar(bar: Bar) -> None:
    assert bar.low <= min(bar.open, bar.close) <= max(bar.open, bar.close) <= bar.high


def _fractal_flags(bars: dict[int, Bar], shift: int) -> tuple[bool, bool]:
    """Equivalent five-bar extrema used by MT5's Williams Fractals."""
    required = (shift - 2, shift - 1, shift, shift + 1, shift + 2)
    if any(index not in bars for index in required):
        return False, False

    center = bars[shift]
    neighbours = [bars[index] for index in required if index != shift]
    upper = all(center.high > bar.high for bar in neighbours)
    lower = all(center.low < bar.low for bar in neighbours)
    return upper, lower


def find_abc_from_bars(
    bars: dict[int, Bar],
    *,
    bullish: bool,
    pivot_scan_start: int = 4,
    pivot_scan_max: int = 80,
) -> tuple[float, float, float, int, int, int] | None:
    """Python equivalent of the EA's bounded, alternating ``FindABC`` search."""
    prices: list[float] = []
    shifts: list[int] = []
    is_upper: list[bool] = []

    for shift in range(pivot_scan_start, pivot_scan_max + 1):
        upper, lower = _fractal_flags(bars, shift)
        if not upper and not lower:
            continue
        if upper and lower:
            continue
        this_is_upper = upper
        if is_upper and is_upper[-1] == this_is_upper:
            continue
        prices.append(bars[shift].high if upper else bars[shift].low)
        shifts.append(shift)
        is_upper.append(this_is_upper)
        if len(prices) == 3:
            break

    if len(prices) < 3:
        return None

    C, B, A = prices
    ab_bars = shifts[2] - shifts[1]
    c_bars_from_b = shifts[1] - shifts[0]
    c_shift = shifts[0]
    polarity_ok = (
        (not is_upper[0] and is_upper[1] and not is_upper[2] and C > A)
        if bullish
        else (is_upper[0] and not is_upper[1] and is_upper[2] and C < A)
    )
    if not polarity_ok:
        return None
    return A, B, C, c_bars_from_b, ab_bars, c_shift


def simulate_strategy_entry_signal(
    *,
    bullish: bool,
    bars: dict[int, Bar],
    atr14: float,
    spread: float,
    spread_atr_mult_cap: float = 0.35,
    d1_rsi: float = 50.0,
    d1_rsi_lo: float = 30.0,
    d1_rsi_hi: float = 70.0,
    time_symmetry_tolerance: float = 0.20,
    bc_ab_ratio_min: float = 0.382,
    bc_ab_ratio_max: float = 0.886,
    projection_touch_atr_mult: float = 0.5,
    t1_fib: float = 0.382,
    ask: float,
    bid: float,
    bars_since_last_entry: int = 999,
    cooldown_bars: int = 18,
) -> tuple[bool, dict[str, Any]]:
    """EA-equivalent search plus the mathematical entry gates."""
    for bar in bars.values():
        _assert_valid_bar(bar)
    if 1 not in bars or 2 not in bars:
        return False, {"reason": "touch_or_confirmation_bar_missing"}
    if ask < bid:
        return False, {"reason": "crossed_market"}

    if atr14 <= 0.0:
        return False, {"reason": "atr_non_positive"}

    if spread > 0.0 and spread > spread_atr_mult_cap * atr14:
        return False, {"reason": "spread_filter_exceeded"}

    d1_regime_ok = (d1_rsi >= d1_rsi_lo and d1_rsi <= d1_rsi_hi)
    if not d1_regime_ok:
        return False, {"reason": "d1_regime_filter_failed"}

    tol = projection_touch_atr_mult * atr14
    pivots = find_abc_from_bars(bars, bullish=bullish)
    if pivots is None:
        return False, {"reason": "find_abc_failed"}
    A, B, C, c_bars_from_b, ab_bars, c_shift = pivots
    c2 = bars[2]
    c1 = bars[1]

    if bullish:
        ab_range = B - A
        if ab_range <= 0.0:
            return False, {"reason": "ab_range_non_positive"}

        bc_ratio = (B - C) / ab_range
        cd_bars = c_shift - 2
        time_symmetry_ok = (
            cd_bars > 0 and abs(float(cd_bars) / float(ab_bars) - 1.0) <= time_symmetry_tolerance
        )

        ratio_ok = (bc_ratio >= bc_ab_ratio_min and bc_ratio <= bc_ab_ratio_max)
        bars_ok = (ab_bars >= 3 and ab_bars <= 60)

        if not (ratio_ok and bars_ok and time_symmetry_ok):
            return False, {"reason": "swing_metrics_failed", "bc_ratio": bc_ratio, "time_sym": time_symmetry_ok}

        d_proj = C + (B - A)
        t1 = d_proj + t1_fib * (C - d_proj)

        touch_ok = (
            (c2.low <= d_proj + tol) and (c2.low >= d_proj - tol) and
            (c2.close >= d_proj - tol) and (c2.close <= d_proj + tol)
        )
        confirm_ok = (c1.close > c2.high)
        t1_ok = (ask < t1)
        cooldown_ok = (bars_since_last_entry > cooldown_bars)

        long_ok = touch_ok and confirm_ok and t1_ok and cooldown_ok
        return long_ok, {
            "A": A,
            "B": B,
            "C": C,
            "c_bars_from_b": c_bars_from_b,
            "ab_bars": ab_bars,
            "c_shift": c_shift,
            "d_proj": d_proj,
            "t1": t1,
            "touch_ok": touch_ok,
            "confirm_ok": confirm_ok,
            "t1_ok": t1_ok,
            "cooldown_ok": cooldown_ok,
            "ask": ask,
        }

    else:
        ab_range = A - B
        if ab_range <= 0.0:
            return False, {"reason": "ab_range_non_positive"}

        bc_ratio = (C - B) / ab_range
        cd_bars = c_shift - 2
        time_symmetry_ok = (
            cd_bars > 0 and abs(float(cd_bars) / float(ab_bars) - 1.0) <= time_symmetry_tolerance
        )

        ratio_ok = (bc_ratio >= bc_ab_ratio_min and bc_ratio <= bc_ab_ratio_max)
        bars_ok = (ab_bars >= 3 and ab_bars <= 60)

        if not (ratio_ok and bars_ok and time_symmetry_ok):
            return False, {"reason": "swing_metrics_failed", "bc_ratio": bc_ratio, "time_sym": time_symmetry_ok}

        d_proj = C - (A - B)
        t1 = d_proj + t1_fib * (C - d_proj)

        touch_ok = (
            (c2.high <= d_proj + tol) and (c2.high >= d_proj - tol) and
            (c2.close >= d_proj - tol) and (c2.close <= d_proj + tol)
        )
        confirm_ok = (c1.close < c2.low)
        t1_ok = (bid > t1)
        cooldown_ok = (bars_since_last_entry > cooldown_bars)

        short_ok = touch_ok and confirm_ok and t1_ok and cooldown_ok
        return short_ok, {
            "A": A,
            "B": B,
            "C": C,
            "c_bars_from_b": c_bars_from_b,
            "ab_bars": ab_bars,
            "c_shift": c_shift,
            "d_proj": d_proj,
            "t1": t1,
            "touch_ok": touch_ok,
            "confirm_ok": confirm_ok,
            "t1_ok": t1_ok,
            "cooldown_ok": cooldown_ok,
            "bid": bid,
        }


def _bullish_reachable_window() -> dict[int, Bar]:
    """Valid OHLC window whose most-recent alternating pivots are 100/110/104."""
    return {
        0: Bar(0, 109.90, 110.10, 109.80, 110.00),
        1: Bar(1, 109.60, 110.05, 109.50, 109.90),
        2: Bar(2, 109.70, 109.80, 109.50, 109.60),
        3: Bar(3, 106.50, 109.60, 106.40, 109.40),
        4: Bar(4, 104.50, 107.00, 104.20, 106.50),
        5: Bar(5, 105.50, 106.00, 104.00, 104.50),  # C: lower fractal
        6: Bar(6, 106.50, 107.50, 105.00, 105.50),
        7: Bar(7, 108.50, 109.00, 106.00, 106.50),
        8: Bar(8, 108.00, 110.00, 107.00, 108.50),  # B: upper fractal
        9: Bar(9, 105.00, 108.50, 104.50, 108.00),
        10: Bar(10, 102.00, 106.00, 101.80, 105.00),
        11: Bar(11, 104.00, 104.50, 100.00, 102.00),  # A: lower fractal
        12: Bar(12, 102.00, 105.00, 101.00, 104.00),
        13: Bar(13, 103.00, 104.00, 101.50, 102.00),
    }


def _bullish_macro_window() -> dict[int, Bar]:
    """Valid OHLC window with a 5x-ATR AB leg and T1 already behind fill."""
    return {
        0: Bar(0, 169.50, 170.10, 169.30, 169.60),
        1: Bar(1, 167.00, 170.00, 166.50, 169.50),
        2: Bar(2, 168.00, 169.00, 166.00, 167.00),
        3: Bar(3, 140.00, 165.00, 139.00, 164.00),
        4: Bar(4, 122.00, 145.00, 121.00, 140.00),
        5: Bar(5, 125.00, 130.00, 120.00, 122.00),  # C: lower fractal
        6: Bar(6, 132.00, 135.00, 125.00, 126.00),
        7: Bar(7, 145.00, 147.00, 132.00, 133.00),
        8: Bar(8, 140.00, 150.00, 139.00, 145.00),  # B: upper fractal
        9: Bar(9, 130.00, 145.00, 129.00, 140.00),
        10: Bar(10, 110.00, 135.00, 109.00, 130.00),
        11: Bar(11, 120.00, 125.00, 100.00, 110.00),  # A: lower fractal
        12: Bar(12, 110.00, 120.00, 104.00, 119.00),
        13: Bar(13, 112.00, 115.00, 105.00, 110.00),
    }


def _bearish_reachable_window() -> dict[int, Bar]:
    """Valid OHLC window whose most-recent alternating pivots are 120/110/116."""
    return {
        0: Bar(0, 110.00, 110.10, 109.80, 109.90),
        1: Bar(1, 110.40, 110.45, 109.90, 110.00),
        2: Bar(2, 110.50, 110.50, 110.20, 110.40),
        3: Bar(3, 112.50, 112.80, 110.40, 110.50),
        4: Bar(4, 115.00, 115.50, 112.00, 112.50),
        5: Bar(5, 114.50, 116.00, 113.00, 115.00),  # C: upper fractal
        6: Bar(6, 113.50, 115.00, 112.00, 114.50),
        7: Bar(7, 111.00, 114.00, 110.80, 113.50),
        8: Bar(8, 112.50, 113.00, 110.00, 111.00),  # B: lower fractal
        9: Bar(9, 115.00, 115.50, 112.00, 112.50),
        10: Bar(10, 118.00, 118.50, 114.00, 115.00),
        11: Bar(11, 116.00, 120.00, 115.50, 118.00),  # A: upper fractal
        12: Bar(12, 118.00, 119.00, 115.00, 116.00),
        13: Bar(13, 117.00, 118.50, 116.00, 118.00),
    }


def test_qm5_20177_full_geometry_positive_acceptance_and_rejection() -> None:
    """Derive pivots from valid bars; accept reachable cases and reject the macro swing."""
    atr14 = 10.0
    spread = 1.0

    accepted, trace = simulate_strategy_entry_signal(
        bullish=True,
        bars=_bullish_reachable_window(),
        atr14=atr14,
        spread=spread,
        ask=110.00,
        bid=109.90,
    )
    assert accepted is True, f"Full geometry with room to T1 MUST be accepted, got trace: {trace}"
    assert trace["touch_ok"] is True
    assert trace["confirm_ok"] is True
    assert trace["t1_ok"] is True
    assert trace["cooldown_ok"] is True
    assert (trace["A"], trace["B"], trace["C"]) == (100.0, 110.0, 104.0)
    assert (trace["ab_bars"], trace["c_shift"]) == (3, 5)

    rejected, trace_neg = simulate_strategy_entry_signal(
        bullish=True,
        bars=_bullish_macro_window(),
        atr14=atr14,
        spread=spread,
        ask=169.60,
        bid=169.50,
    )
    assert rejected is False, "Entry where T1 is behind fill MUST be rejected"
    assert trace_neg["touch_ok"] is True
    assert trace_neg["confirm_ok"] is True
    assert trace_neg["t1_ok"] is False
    assert (trace_neg["A"], trace_neg["B"], trace_neg["C"]) == (100.0, 150.0, 120.0)

    accepted_bear, trace_bear = simulate_strategy_entry_signal(
        bullish=False,
        bars=_bearish_reachable_window(),
        atr14=atr14,
        spread=spread,
        ask=110.10,
        bid=110.00,
    )
    assert accepted_bear is True, f"Bearish full geometry with room to T1 MUST be accepted, got trace: {trace_bear}"
    assert trace_bear["touch_ok"] is True
    assert trace_bear["confirm_ok"] is True
    assert trace_bear["t1_ok"] is True
    assert (trace_bear["A"], trace_bear["B"], trace_bear["C"]) == (120.0, 110.0, 116.0)


def test_qm5_20177_build_guardrails_compliance() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    assert "qm_news_stale_max_hours" in source
    assert "qm_news_stale_max_hours      = 336;" in source

    setfiles = list(EA_DIR.glob("sets/*.set"))
    assert len(setfiles) >= 1, "At least one setfile must exist"

    for setfile in setfiles:
        values: dict[str, str] = {}
        for raw_line in setfile.read_text(encoding="utf-8-sig").splitlines():
            line = raw_line.strip()
            if not line or line.startswith(";") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()

        assert float(values.get("RISK_FIXED", "0")) > 0.0, f"RISK_FIXED must be > 0 in {setfile.name}"
        assert float(values.get("RISK_PERCENT", "1")) == 0.0, f"RISK_PERCENT must be 0 in {setfile.name}"
        if "qm_news_stale_max_hours" in values:
            assert int(values["qm_news_stale_max_hours"]) <= 336, f"News stale max hours > 336 in {setfile.name}"
