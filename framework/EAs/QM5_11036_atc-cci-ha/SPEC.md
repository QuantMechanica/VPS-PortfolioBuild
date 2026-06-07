# QM5_11036_atc-cci-ha - Strategy Spec

**EA ID:** QM5_11036
**Slug:** `atc-cci-ha`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It opens long when CCI crosses back above the configured oversold level after being below it on the prior completed bar, and opens short when CCI crosses back below the configured overbought level after being above it on the prior completed bar. Stop loss and take profit are placed at ATR multiples. Open longs close when the completed Heiken Ashi candle turns bearish, and open shorts close when it turns bullish.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 1+ | CCI lookback period. |
| `strategy_oversold_level` | -100.0 | negative threshold | Long recross threshold. |
| `strategy_overbought_level` | 100.0 | positive threshold | Short recross threshold. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for SL and TP distance. |
| `strategy_atr_sl_mult` | 2.0 | greater than 0 | ATR multiplier for stop loss. |
| `strategy_atr_tp_mult` | 2.0 | 0 disables, otherwise greater than 0 | ATR multiplier for take profit. |
| `strategy_adx_filter_enabled` | false | true/false | Enables optional mean-reversion regime filter. |
| `strategy_adx_period` | 14 | 1+ | ADX lookback when the ADX filter is enabled. |
| `strategy_adx_max` | 25.0 | greater than 0 | Maximum ADX allowed when the ADX filter is enabled. |
| `strategy_ema200_filter_enabled` | false | true/false | Enables optional EMA trend-alignment variant. |
| `strategy_ema_period` | 200 | 1+ | EMA period for optional trend alignment. |
| `strategy_median_spread_points` | 0 | 0 disables, otherwise greater than 0 | Median spread input used by the card spread filter. |
| `strategy_spread_multiplier` | 2.0 | greater than 0 | Multiplier applied to the median spread threshold. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card primary basket includes gold and the CCI/ATR/Heiken Ashi rules use standard OHLC indicators.
- `EURUSD.DWX` - card primary basket includes major FX and all required data is available in DWX.
- `GBPUSD.DWX` - card primary basket includes major FX and all required data is available in DWX.
- `USDJPY.DWX` - card primary basket includes major FX and all required data is available in DWX.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick source is registered for build or backtest.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | hours to a few days |
| Expected drawdown profile | Bounded ATR risk with vulnerability to persistent trends. |
| Regime preference | mean-reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** MQL5 article / interview
**Pointer:** https://www.mql5.com/en/articles/583
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11036_atc-cci-ha.md`

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
| v1 | 2026-06-07 | Initial build from card | b1c3684a-c6c8-436c-9f71-77a94ec01a7c |
