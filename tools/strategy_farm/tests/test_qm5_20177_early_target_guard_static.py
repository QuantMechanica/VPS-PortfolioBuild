from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
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


def simulate_strategy_entry_signal(
    *,
    bullish: bool,
    atr14: float,
    spread: float,
    spread_atr_mult_cap: float = 0.35,
    d1_rsi: float = 50.0,
    d1_rsi_lo: float = 30.0,
    d1_rsi_hi: float = 70.0,
    A: float,
    B: float,
    C: float,
    ab_bars: int,
    c_shift: int,
    time_symmetry_tolerance: float = 0.30,
    bc_ab_ratio_min: float = 0.382,
    bc_ab_ratio_max: float = 0.886,
    projection_touch_atr_mult: float = 0.5,
    t1_fib: float = 0.382,
    c2: Bar,
    c1: Bar,
    ask: float,
    bid: float,
    bars_since_last_entry: int = 999,
    cooldown_bars: int = 18,
) -> tuple[bool, dict[str, any]]:
    """Complete mathematical & geometric simulation of Strategy_EntrySignal."""
    if atr14 <= 0.0:
        return False, {"reason": "atr_non_positive"}

    if spread > 0.0 and spread > spread_atr_mult_cap * atr14:
        return False, {"reason": "spread_filter_exceeded"}

    d1_regime_ok = (d1_rsi >= d1_rsi_lo and d1_rsi <= d1_rsi_hi)
    if not d1_regime_ok:
        return False, {"reason": "d1_regime_filter_failed"}

    tol = projection_touch_atr_mult * atr14

    if bullish:
        # Long geometry: C=low, B=high, A=low, C>A, B>A
        if not (C > A and B > A):
            return False, {"reason": "bullish_fractal_geometry_invalid"}

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
            "d_proj": d_proj,
            "t1": t1,
            "touch_ok": touch_ok,
            "confirm_ok": confirm_ok,
            "t1_ok": t1_ok,
            "cooldown_ok": cooldown_ok,
            "ask": ask,
        }

    else:
        # Short geometry: C=high, B=low, A=high, C<A, A>B
        if not (C < A and A > B):
            return False, {"reason": "bearish_fractal_geometry_invalid"}

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
            "d_proj": d_proj,
            "t1": t1,
            "touch_ok": touch_ok,
            "confirm_ok": confirm_ok,
            "t1_ok": t1_ok,
            "cooldown_ok": cooldown_ok,
            "bid": bid,
        }


def test_qm5_20177_full_geometry_positive_acceptance_and_rejection() -> None:
    """Pins full entry geometry simulation for both positive (accepted) and defective (rejected) cases."""
    atr14 = 10.0
    spread = 1.0

    # 1. Bullish Positive Entry: AB is tight enough that Ask < T1
    # AB range = 10.0 (= 1.0 * ATR14 < 1.3089 * ATR14)
    # A=100.0, B=110.0, C=104.0, D_proj = 114.0, tol = 5.0 -> [109.0, 119.0]
    # T1 = 114.0 + 0.382 * (104.0 - 114.0) = 110.18
    # c2: low=109.5, high=109.8, close=109.6 (within [109.0, 119.0])
    # c1: close=109.9 (> c2.high 109.8)
    # Ask: 110.00 (< T1 110.18) -> t1_ok is TRUE
    c2_bull_pos = Bar(time=2, open=111.0, high=109.8, low=109.5, close=109.6)
    c1_bull_pos = Bar(time=1, open=109.6, high=110.0, low=109.5, close=109.9)

    accepted, trace = simulate_strategy_entry_signal(
        bullish=True,
        atr14=atr14,
        spread=spread,
        A=100.0,
        B=110.0,
        C=104.0,
        ab_bars=10,
        c_shift=12,
        c2=c2_bull_pos,
        c1=c1_bull_pos,
        ask=110.00,
        bid=109.90,
    )
    assert accepted is True, f"Full geometry with room to T1 MUST be accepted, got trace: {trace}"
    assert trace["touch_ok"] is True
    assert trace["confirm_ok"] is True
    assert trace["t1_ok"] is True
    assert trace["cooldown_ok"] is True

    # 2. Bullish Defective Entry: Standard macro swing where Ask >= T1
    # AB range = 50.0 (= 5.0 * ATR14)
    # A=100.0, B=150.0, C=120.0, D_proj = 170.0, tol = 5.0 -> [165.0, 175.0]
    # T1 = 170.0 + 0.382 * (120.0 - 170.0) = 150.90
    # c2: low=166.0, high=169.0, close=167.0
    # c1: close=169.5 (> c2.high 169.0)
    # Ask: 169.60 (> T1 150.90) -> t1_ok is FALSE
    c2_bull_neg = Bar(time=2, open=168.0, high=169.0, low=166.0, close=167.0)
    c1_bull_neg = Bar(time=1, open=167.0, high=170.0, low=166.5, close=169.5)

    rejected, trace_neg = simulate_strategy_entry_signal(
        bullish=True,
        atr14=atr14,
        spread=spread,
        A=100.0,
        B=150.0,
        C=120.0,
        ab_bars=10,
        c_shift=12,
        c2=c2_bull_neg,
        c1=c1_bull_neg,
        ask=169.60,
        bid=169.50,
    )
    assert rejected is False, "Entry where T1 is behind fill MUST be rejected"
    assert trace_neg["touch_ok"] is True
    assert trace_neg["confirm_ok"] is True
    assert trace_neg["t1_ok"] is False

    # 3. Bearish Positive Entry: AB is tight enough that Bid > T1
    # AB range = 10.0 (= 1.0 * ATR14)
    # A=120.0, B=110.0, C=116.0, D_proj = 106.0, tol = 5.0 -> [101.0, 111.0]
    # T1 = 106.0 + 0.382 * (116.0 - 106.0) = 109.82
    # c2: low=110.2, high=110.5, close=110.4 (within [101.0, 111.0])
    # c1: close=110.0 (< c2.low 110.2)
    # Bid: 110.00 (> T1 109.82) -> t1_ok is TRUE
    c2_bear_pos = Bar(time=2, open=109.0, high=110.5, low=110.2, close=110.4)
    c1_bear_pos = Bar(time=1, open=110.4, high=110.4, low=109.9, close=110.0)

    accepted_bear, trace_bear = simulate_strategy_entry_signal(
        bullish=False,
        atr14=atr14,
        spread=spread,
        A=120.0,
        B=110.0,
        C=116.0,
        ab_bars=10,
        c_shift=12,
        c2=c2_bear_pos,
        c1=c1_bear_pos,
        ask=110.10,
        bid=110.00,
    )
    assert accepted_bear is True, f"Bearish full geometry with room to T1 MUST be accepted, got trace: {trace_bear}"
    assert trace_bear["touch_ok"] is True
    assert trace_bear["confirm_ok"] is True
    assert trace_bear["t1_ok"] is True


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
