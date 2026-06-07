# QM5_11032_atc-horiz-chan - Strategy Spec

**EA ID:** QM5_11032
**Slug:** atc-horiz-chan
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed M5 bars and measures the highest high and lowest low over the channel lookback. It arms a breakout only when the latest closed price is back inside the middle of that channel, then places one buy stop above the channel high and one sell stop below the channel low. The stop distance is the larger of 0.75 times channel width and 1.5 times ATR(14), with a 3R take-profit by default. Once one pending order fills, the management hook cancels the opposite pending order and trails the stop after the trade moves far enough in profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_channel_period_m5 | 48 | 24-144 | Completed M5 bars used to build the horizontal channel. |
| strategy_inside_depth_pct | 0.20 | 0.10-0.30 | Fraction of channel width that price must be away from either border before arming. |
| strategy_atr_period | 14 | 14 | ATR period used for buffer, stop, and width filter. |
| strategy_entry_buffer_atr | 0.10 | 0.05-0.20 | Entry stop buffer as a multiple of ATR(14). |
| strategy_channel_sl_mult | 0.75 | 0.50-1.00 | Channel-width multiplier used in the max stop formula. |
| strategy_atr_sl_mult | 1.50 | 1.00-2.00 | ATR multiplier used in the max stop formula. |
| strategy_tp_r_multiple | 3.00 | 0.00-4.00 | Take-profit distance in units of initial risk. |
| strategy_tp_enabled | true | true/false | Enable or disable fixed TP. |
| strategy_trail_start_r | 1.50 | 1.00-2.00 | Profit in R before classical trailing begins. |
| strategy_pending_expiry_bars | 3 | 1+ | Number of M5 bars before pending orders expire. |
| strategy_width_min_atr_factor | 0.50 | 0.50 | Lower bound for channel width versus ATR scaled by lookback. |
| strategy_width_max_atr_factor | 2.50 | 2.50 | Upper bound for channel width versus ATR scaled by lookback. |
| strategy_median_spread_points | 25.0 | symbol-specific | Median spread estimate in broker points for the spread filter. |
| strategy_spread_mult | 2.0 | 2.0 | Current spread must be no more than this multiple of the median spread estimate. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex symbol for M5 channel breakout testing.
- GBPUSD.DWX - card-listed DWX forex symbol with the same OHLC and pending-stop mechanics.
- USDJPY.DWX - card-listed DWX forex symbol with the same OHLC and pending-stop mechanics.
- XAUUSD.DWX - card-listed DWX metals symbol for the same low-volatility to breakout transition.

**Explicitly NOT for:**
- Non-DWX symbols - the build and backtest workflow requires canonical `.DWX` symbols.
- Equity index symbols - not listed in this card's R3 P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Minutes to hours after an M5 pending-stop breakout, until SL, TP, trailing stop, expiry, or Friday close |
| Expected drawdown profile | Breakout churn is possible around channel borders; loss is bounded by fixed SL, spread gating, pending expiry, and one active position |
| Regime preference | Volatility expansion after a horizontal channel |
| Win rate target (qualitative) | medium |

Card expected frequency: M5 horizontal-channel breakout places paired pending orders when price returns inside the channel; conservative estimate 80-180 trades/year/symbol after filters.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/538
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11032_atc-horiz-chan.md`

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
| v1 | 2026-06-07 | Initial build from card | 21a85c2f-7c79-4b16-b914-a32f1bd34cae |
