# QM5_10250_tv-bb-scalp - Strategy Spec

**EA ID:** QM5_10250
**Slug:** tv-bb-scalp
**Source:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades mean reversion after a closed M5 candle is fully outside Bollinger Bands. A long setup requires the closed candle open and close to be below the lower BB(20, 2.0), tick volume above its 20-bar average, current spread no more than 1.5 times the 50-bar average spread, and, by default, close above EMA(200). A short setup mirrors the rule above the upper band and below EMA(200). Positions exit when price reaches EMA(8), or after 24 bars if no EMA target or stop is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >=2 | Bollinger Band SMA period. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard deviation multiplier. |
| strategy_exit_ema_period | 8 | >=1 | EMA target for the full-position strategy exit. |
| strategy_ema12_period | 12 | >=1 | Card-declared P3 target candidate retained as visible input. |
| strategy_ema26_period | 26 | >=1 | Card-declared P3 target candidate retained as visible input. |
| strategy_use_ema200_filter | true | true/false | Enables the baseline EMA(200) trend-side filter. |
| strategy_ema200_period | 200 | >=1 | EMA period used by the optional trend filter. |
| strategy_volume_sma_period | 20 | >=1 | Tick-volume SMA period for entry confirmation. |
| strategy_spread_avg_bars | 50 | >=1 | Closed-bar spread lookback for the average-spread filter. |
| strategy_spread_avg_mult | 1.5 | >0 | Maximum current spread as a multiple of average spread. |
| strategy_atr_period | 14 | >=1 | ATR period for FX and non-index stop distance. |
| strategy_fx_atr_sl_mult | 1.2 | >0 | ATR stop multiple for FX and XAUUSD.DWX. |
| strategy_index_sl_percent | 0.35 | >0 | Percent-of-entry stop distance for index CFDs. |
| strategy_max_hold_bars | 24 | >=1 | Time stop in bars from position open. |
| strategy_london_start_hour | 7 | 0-23 | Broker-hour start for the London entry window. |
| strategy_london_end_hour | 12 | 0-23 | Broker-hour end for the London entry window. |
| strategy_ny_start_hour | 13 | 0-23 | Broker-hour start for the New York entry window. |
| strategy_ny_end_hour | 21 | 0-23 | Broker-hour end for the New York entry window. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - primary FX symbol from the card frontmatter.
- GBPUSD.DWX - liquid FX pair from the card's default P2 basket.
- XAUUSD.DWX - liquid DWX commodity from the card's default P2 basket; uses the ATR stop branch.
- NDX.DWX - liquid index CFD from the card's default P2 basket; uses the percent stop branch.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data availability is not guaranteed.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Minutes to 24 M5 bars, maximum about 2 hours |
| Expected drawdown profile | Scalping mean-reversion with fixed ATR or percent stop exposure |
| Regime preference | Mean-revert during liquid London and New York hours |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Source type:** TradingView public Pine script
**Pointer:** https://www.tradingview.com/script/CmHXgNGT-Bollinger-Band-Scalping/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10250_tv-bb-scalp.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | bfa7742b-c1d8-422f-bb9e-085144e62a0c |
