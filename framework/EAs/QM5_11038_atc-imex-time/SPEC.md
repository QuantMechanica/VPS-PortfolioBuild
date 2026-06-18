# QM5_11038_atc-imex-time - Strategy Spec

**EA ID:** QM5_11038
**Slug:** atc-imex-time
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates a Bulls/Bears Power approximation of the source IMEX index at fixed intraday time points inside the current D1 bar. Bulls Power is the closed-bar high minus EMA(close), Bears Power is the closed-bar low minus EMA(close), and the signal is the z-score of Bulls Power minus the z-score of absolute Bears Power over the configured lookback. A positive signal above threshold opens long, a negative signal below threshold opens short, with ATR-based stop and target. Optional reversal closes an existing trade when a later permitted time point produces the opposite forecast.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_tp1_broker_minutes | 360 | -1-1439 | First permitted time point, minutes from broker midnight; -1 disables it. |
| strategy_tp2_broker_minutes | 720 | -1-1439 | Second permitted time point, minutes from broker midnight; -1 disables it. |
| strategy_tp3_broker_minutes | 1080 | -1-1439 | Third permitted time point, minutes from broker midnight; -1 disables it. |
| strategy_tp_window_min | 60 | 1-240 | Width of each permitted time-point window in minutes. |
| strategy_latest_entry_broker_minutes | 1080 | 1-1439 | Latest broker minute for a new entry or reversal decision. |
| strategy_imex_ma_period | 13 | 2-100 | EMA period used in Bulls/Bears Power. |
| strategy_imex_lookback | 34 | 2-252 | Lookback for the Bulls/Bears z-score calculation. |
| strategy_imex_threshold | 0.50 | 0.01-5.00 | Absolute IMEX z-score threshold required to trade. |
| strategy_atr_tf | PERIOD_D1 | M1-W1 | Timeframe for ATR stop and target distance. |
| strategy_atr_period | 14 | 2-100 | ATR period for SL and TP. |
| strategy_sl_atr_mult | 0.70 | 0.01-10.00 | Stop distance as ATR multiple. |
| strategy_tp_atr_mult | 0.45 | 0.01-10.00 | Target distance as ATR multiple. |
| strategy_reversal_enabled | false | true/false | Enables close-on-opposite-forecast at a later time point. |
| strategy_spread_pct_of_stop | 25.0 | 0.0-100.0 | Blocks only genuinely wide positive spread relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - Card R3 target; liquid major FX pair with DWX history.
- EURUSD.DWX - Card R3 target; liquid major FX pair with DWX history.
- GBPUSD.DWX - Card R3 target; liquid major FX pair with DWX history.
- XAUUSD.DWX - Card R3 target; liquid metal CFD with DWX history.

**Explicitly NOT for:**
- Non-DWX symbols - build and P2 registration use only symbols present in `framework/registry/dwx_symbol_matrix.csv`.
- External macro-only symbols - the card uses only native OHLC and standard indicators.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 P2 baseline; H4 and D1 generated as card-listed signal-timeframe variants |
| Multi-timeframe refs | ATR on PERIOD_D1 by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Not explicit in frontmatter; expected intraday-to-multi-day until ATR SL/TP or later time-point reversal |
| Expected drawdown profile | Fixed-risk, ATR-bounded directional forecast trades |
| Regime preference | Momentum-reversal / daily bar-color forecast from Bulls/Bears balance |
| Win rate target (qualitative) | Medium |

Expected trade frequency from card: one time-point forecast per D1 bar with intrabar reversal/expiry; conservative estimate 40-90 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article / Automated Trading Championship interview
**Pointer:** Vladimir Tsyrulnik, "The Essense of my program is improvisation! (ATC 2010)", MQL5 Articles, 2010-10-27
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11038_atc-imex-time.md`

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
| v1 | 2026-06-18 | Initial build from card | 709017be-1247-4946-ac34-86a386563e63 |
