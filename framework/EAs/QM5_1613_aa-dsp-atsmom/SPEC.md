# QM5_1613_aa-dsp-atsmom - Strategy Spec

**EA ID:** QM5_1613
**Slug:** a-dsp-atsmom
**Source:** de348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This EA implements the Alpha Architect Digital Signal Processing Averaged Time Series Momentum (ATSMOM 3-6-9-12) strategy on D1 bars.
Stern describes averaged TSMOM as an average of multiple fixed lookbacks with a gain multiplier:

ATSMOM = 0.7043 * (Close(1) - 0.25*Close(4) - 0.25*Close(7) - 0.25*Close(10) - 0.25*Close(13))

On each closed D1 bar:
- Long Entry: ATSMOM(1) > 0.0 and ATSMOM(2) <= 0.0 (zero-cross up).
- Short Entry: ATSMOM(1) < 0.0 and ATSMOM(2) >= 0.0 (zero-cross down).
- Exit: Long positions exit when ATSMOM(1) <= 0.0; Short positions exit when ATSMOM(1) >= 0.0.
- Protective Stop: Initial SL placed at 2.5 * ATR(20, D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_min_daily_bars | 30 | 20-50 | Warmup bar count requirement |
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
| Typical hold time | 2-15 D1 bars |
| Regime preference | Trending / momentum |
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
