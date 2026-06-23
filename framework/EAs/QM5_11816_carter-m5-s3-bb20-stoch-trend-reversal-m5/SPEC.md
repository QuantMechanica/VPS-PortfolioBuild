# QM5_11816_carter-m5-s3-bb20-stoch-trend-reversal-m5 - Strategy Spec

**EA ID:** QM5_11816
**Slug:** `carter-m5-s3-bb20-stoch-trend-reversal-m5`
**Source:** `f4430cee-7efb-592e-bf0f-e469ef156b2d` (see `sources/20-forex-trading-strategies-5min-carter-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades M5 reversals at Bollinger Band extremes when the reversal is aligned with the local Bollinger midline slope. A long signal requires the prior closed bar to touch or break the lower BB(20,2), Stochastic(5,3,3) %K to be below 20, and the BB midline to be rising versus the configured lookback. A short signal requires the prior closed bar to touch or break the upper band, %K to be above 80, and the BB midline to be falling. Stops are 2x ATR(14), take-profit is 4x ATR(14), and the trade-close hook exits if price reaches the BB midline or opposite band first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 5-100 | Bollinger Band period. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger Band deviation multiplier. |
| `strategy_stoch_k` | 5 | 2-50 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-20 | Stochastic slowing period. |
| `strategy_stoch_oversold` | 20.0 | 1-50 | Long-side oversold threshold. |
| `strategy_stoch_overbought` | 80.0 | 50-99 | Short-side overbought threshold. |
| `strategy_trend_lookback` | 2 | 1-20 | Closed-bar lookback for BB midline slope. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop and target distance. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-10.0 | Stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 4.0 | 0.5-20.0 | Take-profit distance in ATR multiples. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Blocks only genuinely wide modeled spread versus stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target FX pair with M5 DWX data available.
- `GBPUSD.DWX` - Card target FX pair with M5 DWX data available.
- `USDJPY.DWX` - Card target FX pair with M5 DWX data available.
- `USDCHF.DWX` - Card target FX pair with M5 DWX data available.

**Explicitly NOT for:**
- Non-card symbols - The approved card names only the four FX pairs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | mean-reversion with trend filter |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4430cee-7efb-592e-bf0f-e469ef156b2d`
**Source type:** book / local PDF
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy 3
**R1-R4 verdict (Q00):** all R1-R4 PASS per frontmatter in `artifacts/cards_approved/QM5_11816_carter-m5-s3-bb20-stoch-trend-reversal-m5.md`; the body table contains an R1 conflict noted in the build result.

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
