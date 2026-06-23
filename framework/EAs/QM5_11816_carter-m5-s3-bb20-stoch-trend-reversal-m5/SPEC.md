# QM5_11816_carter-m5-s3-bb20-stoch-trend-reversal-m5 - Strategy Spec

**EA ID:** QM5_11816
**Slug:** carter-m5-s3-bb20-stoch-trend-reversal-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades M5 Bollinger Band reversal setups only when the reversal is aligned with the Bollinger midline trend proxy. A long setup requires the last closed bar to touch or close below the lower BB(20,2), Stochastic(5,3,3) %K below 20, and a rising BB midline from two bars earlier. A short setup mirrors this at the upper band with %K above 80 and a falling BB midline. Entries use market orders with a 2x ATR(14) stop and a 4x ATR(14) target; discretionary exits close open trades when price reaches the BB midline or opposite band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 5-100 | Bollinger Band period from the card. |
| strategy_bb_deviation | 2.0 | 0.5-5.0 | Bollinger Band standard-deviation multiplier. |
| strategy_stoch_k | 5 | 2-50 | Stochastic %K period. |
| strategy_stoch_d | 3 | 1-20 | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1-20 | Stochastic slowing period. |
| strategy_stoch_oversold | 20.0 | 0-50 | Long entry requires %K below this level. |
| strategy_stoch_overbought | 80.0 | 50-100 | Short entry requires %K above this level. |
| strategy_trend_slope_bars | 2 | 1-10 | BB midline slope lookback; default implements midline[1] vs midline[3]. |
| strategy_atr_period | 14 | 2-100 | ATR period for stop and target distance. |
| strategy_sl_atr_mult | 2.0 | 0.25-10.0 | Stop-loss distance in ATR multiples. |
| strategy_tp_atr_mult | 4.0 | 0.25-20.0 | Take-profit distance in ATR multiples. |
| strategy_max_spread_points | 35 | 0-500 | Entry block for genuinely wide positive spread; zero modeled spread remains tradeable. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target FX pair with M5 DWX data available.
- GBPUSD.DWX - Card target FX pair with M5 DWX data available.
- USDJPY.DWX - Card target FX pair with M5 DWX data available.
- USDCHF.DWX - Card target FX pair with M5 DWX data available.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The approved card names four FX pairs only and does not authorize index, metal, energy, or crypto ports.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Card frontmatter does not specify; expected intraday M5 holds until BB midline/opposite band, 4x ATR target, or 2x ATR stop. |
| Expected drawdown profile | Card frontmatter does not specify; ATR-bounded single-position mean-reversion losses. |
| Regime preference | Mean-reversion entries aligned with a local BB-midline trend. |
| Win rate target (qualitative) | Card frontmatter does not specify; medium expected from frequent M5 reversal profile. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** book/PDF
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 2014, Strategy 3; local PDF `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11816_carter-m5-s3-bb20-stoch-trend-reversal-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | e0eae4a1-e4b4-4cde-bf3e-693b4764e626 |
