# QM5_1612_aa-dsp-hplwma10 - Strategy Spec

**EA ID:** QM5_1612
**Slug:** a-dsp-hplwma10
**Source:** de348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This EA implements the Alpha Architect Digital Signal Processing High-Pass Linear Weighted Moving Average (HPLWMA10) trend-following system on D1 bars.
Stern defines LWMA as a low-pass filter and HPLWMA as current price minus that LWMA. The fixed N=10 coefficients yield a zero-DC gain high-pass filter:

HPLWMA10 = 0.8182*C0 - 0.1636*C1 - 0.1455*C2 - 0.1273*C3 - 0.1091*C4 - 0.0909*C5 - 0.0727*C6 - 0.0545*C7 - 0.0364*C8 - 0.0182*C9

On each closed D1 bar:
- Long Entry: HPLWMA10(1) > 0.0 and HPLWMA10(2) <= 0.0 (zero-cross up).
- Short Entry: HPLWMA10(1) < 0.0 and HPLWMA10(2) >= 0.0 (zero-cross down).
- Exit: Long positions exit when HPLWMA10(1) <= 0.0; Short positions exit when HPLWMA10(1) >= 0.0.
- Protective Stop: Initial SL placed at 2.5 * ATR(20, D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_min_daily_bars | 20 | 20-50 | Warmup bar count requirement |
| strategy_atr_period | 20 | 10-30 | ATR period for protective stop |
| strategy_atr_sl_mult | 2.5 | 1.5-3.5 | ATR multiplier for protective stop |
| strategy_max_spread_points | 0 | 0-5000 | Max spread guard (0 = disabled) |

---

## 3. Symbol Universe

**Baseline DWX symbols:**
- SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX
- XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, UK100.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar() |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~100 |
| Typical hold time | 2-10 D1 bars |
| Regime preference | Trending / directional momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** de348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Henry Stern, 'An Introduction to Digital Signal Processing for Trend Following', Alpha Architect (2020-08-13, updated 2025-03), https://alphaarchitect.com/an-introduction-to-digital-signal-processing-for-trend-following/
**R1-R4 verdict (Q00):** all PASS; see docs/strategy_card.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | 0.5% |
