# QM5_11017_the5ers-outbar-rev - Strategy Spec

**EA ID:** QM5_11017
**Slug:** the5ers-outbar-rev
**Source:** 1d445184-7c47-57da-9856-a123682a932d
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades D1 outside-bar reversals. A setup requires the just-closed bar to engulf the prior bar, to have a range of at least 1.2 ATR(14), and to close on the reversal side of its midpoint after at least 10 of the prior 15 closes were on the exhausted side of EMA(50). A bullish setup places a buy stop one tick above the outside-bar high; a bearish setup places a sell stop one tick below the outside-bar low, with pending orders expiring after 3 D1 bars or being replaced by a new outside-bar setup. Management closes 50% at 2 ATR, moves to breakeven at 80% of that first target, trails the remainder by 2 ATR after new favorable closed-bar extremes, closes at 7R, and time-stops after 30 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 50 | >= 2 | EMA period used for prior-trend exhaustion. |
| strategy_atr_period | 14 | >= 2 | ATR period used for range, stop, target, and trail distances. |
| strategy_trend_window | 15 | >= 1 | Number of prior closed bars checked for trend exhaustion. |
| strategy_trend_min | 10 | 1 to strategy_trend_window | Minimum bars that must close on the exhausted side of EMA(50). |
| strategy_range_atr_mult | 1.2 | > 0 | Minimum outside-bar range as a multiple of ATR(14). |
| strategy_expiry_bars | 3 | >= 1 | Pending stop-order lifetime in D1 bars. |
| strategy_sl_atr_mult | 2.0 | > 0 | Initial ATR stop distance from entry. |
| strategy_max_stop_pct | 4.0 | > 0 | Skip setup if the 2 ATR stop exceeds this percent of entry price. |
| strategy_tp1_atr_mult | 2.0 | > 0 | First target distance as a multiple of ATR(14). |
| strategy_tp1_fraction | 0.5 | 0.0 to 1.0 | Position fraction to close at the first target. |
| strategy_be_trigger_frac | 0.8 | > 0 | Fraction of first target reached before moving SL to breakeven. |
| strategy_trail_atr_mult | 2.0 | > 0 | ATR multiple used to trail the remainder after favorable swings. |
| strategy_final_rr | 7.0 | > 0 | Final target in original-risk multiples. |
| strategy_max_hold_bars | 30 | >= 1 | D1 bars after which any remaining position is closed. |
| strategy_spread_pct_of_stop | 15.0 | >= 0 | Blocks only genuinely wide spread above this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with D1 OHLC and ATR available in DWX.
- GBPUSD.DWX - card-listed major FX pair with D1 OHLC and ATR available in DWX.
- USDJPY.DWX - card-listed major FX pair with D1 OHLC and ATR available in DWX.
- AUDUSD.DWX - card-listed major FX pair with D1 OHLC and ATR available in DWX.
- XAUUSD.DWX - card-listed liquid metal CFD with D1 OHLC and ATR available in DWX.
- GDAXI.DWX - DWX DAX equivalent used because card-listed GER40.DWX is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | 1 to 30 D1 bars |
| Expected drawdown profile | ATR-defined reversal trades with fixed $1,000 backtest risk and partial exits. |
| Regime preference | volatility-expansion reversal after prior trend exhaustion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1d445184-7c47-57da-9856-a123682a932d
**Source type:** blog
**Pointer:** https://the5ers.com/outside-bar-candlestick/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11017_the5ers-outbar-rev.md`

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
| v1 | 2026-06-18 | Initial build from card | 755f9f2c-3db1-478e-b15c-c2640bf37d5c |
