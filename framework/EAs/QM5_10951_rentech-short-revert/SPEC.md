# QM5_10951_rentech-short-revert — Strategy Spec

**EA ID:** QM5_10951
**Slug:** rentech-short-revert
**Source:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 exhaustion reversals after an unusually large completed bar. It buys when the last closed H1 return is at least 1.25 ATR-equivalent down, RSI(2) is below 10, and the close has not fallen more than 2 ATR below EMA(100). It sells the mirror condition after a large up bar with RSI(2) above 90 and close no more than 2 ATR above EMA(100). Exits occur when price returns to EMA(20), RSI(2) mean-reverts past the card threshold, the position has been open for 8 H1 bars, or the broker hits the fixed 1.2R target or 1.2 ATR stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 2 | 2-4 | RSI lookback for exhaustion and exit tests. |
| strategy_atr_period | 14 | fixed | ATR lookback for move size, stop distance, and volatility filter. |
| strategy_ema_filter_period | 100 | fixed | EMA used to reject runaway trend entries. |
| strategy_ema_exit_period | 20 | fixed | EMA used as the mean-reversion exit level. |
| strategy_exhaustion_atr_mult | 1.25 | 1.00-1.50 | Required one-bar return in ATR-equivalent units. |
| strategy_ema_distance_atr_mult | 2.0 | fixed | Maximum distance from EMA(100) before entry is rejected. |
| strategy_stop_atr_mult | 1.2 | 1.0-1.5 | Hard stop distance in ATR units. |
| strategy_take_profit_r | 1.2 | fixed | Profit target in R-multiple of stop distance. |
| strategy_time_exit_bars | 8 | 4-12 | Maximum H1 bars to hold a position. |
| strategy_atr_percentile_lookback | 252 | fixed | Lookback for ATR/close percentile filter. |
| strategy_atr_percentile | 90.0 | fixed | Blocks entries when current ATR/close is above this percentile. |
| strategy_weekend_skip_hours | 4 | fixed | Blocks entries in the final hours before the framework Friday close. |
| strategy_spread_stop_fraction | 0.10 | fixed | Maximum spread as a fraction of stop distance. |
| strategy_warmup_bars | 300 | fixed | Minimum closed H1 history required before signals are evaluated. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — liquid FX pair from the card's P2 basket.
- GBPUSD.DWX — liquid FX pair from the card's P2 basket.
- XAUUSD.DWX — liquid metals CFD from the card's P2 basket.
- XAGUSD.DWX — liquid metals CFD from the card's P2 basket.
- GDAXI.DWX — available DAX custom symbol used as the DWX matrix equivalent for card-stated GER40.DWX.
- NDX.DWX — liquid index CFD from the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX — card-stated symbol is not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Up to 8 H1 bars |
| Expected drawdown profile | Countertrend losses during runaway trends and volatility clusters. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
**Source type:** book
**Pointer:** Gregory Zuckerman, *The Man Who Solved the Market: How Jim Simons Launched the Quant Revolution*, plus public notes listed in the approved card.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10951_rentech-short-revert.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | d0acd781-d809-47c9-b5e7-79dbaa63d091 |
