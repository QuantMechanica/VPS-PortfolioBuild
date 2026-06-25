# QM5_9585_ff-ch-stoch-m15 - Strategy Spec

**EA ID:** QM5_9585
**Slug:** `ff-ch-stoch-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the Craig Harris stochastic angle method on closed M15 bars. A long entry requires Stochastic(8,3,3) and Stochastic(14,3,3) %K lines to rise for two closed bars, each %K to be above its %D, each %K two-bar angle proxy to be at least 12 points, M15 price to be above EMA(20), and H1 price to be above EMA(50). Shorts mirror the same stochastic angle and EMA conditions. Exits occur on an opposite stochastic cross in either stochastic series, at a 12-bar time stop, at the framework Friday close, or at the initial SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_stoch_k` | 8 | 2-50 | Fast stochastic %K period. |
| `strategy_slow_stoch_k` | 14 | 2-80 | Slow stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic %D period for both series. |
| `strategy_stoch_slowing` | 3 | 1-20 | Stochastic slowing value for both series. |
| `strategy_stoch_angle_points` | 12.0 | 1.0-50.0 | Minimum %K[1] minus %K[3] angle proxy for entry. |
| `strategy_m15_ema_period` | 20 | 2-200 | M15 EMA trend gate. |
| `strategy_h1_ema_period` | 50 | 2-300 | H1 EMA trend gate. |
| `strategy_swing_lookback_bars` | 5 | 2-20 | Structure lookback for initial stop placement. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the stop buffer. |
| `strategy_structure_atr_buffer` | 0.20 | 0.0-2.0 | ATR fraction added beyond the 5-bar swing stop. |
| `strategy_take_profit_rr` | 1.50 | 0.5-5.0 | Reward:risk multiple for baseline take-profit. |
| `strategy_time_stop_bars` | 12 | 1-96 | Maximum hold time in M15 bars. |
| `strategy_session_start_hour` | 9 | 0-23 | Broker-time hour where London/early New York entry window starts. |
| `strategy_session_end_hour` | 18 | 0-23 | Broker-time hour where London/early New York entry window ends. |
| `strategy_max_spread_pips` | 3.0 | 0.0-20.0 | Entry spread cap; zero modeled spread is allowed. |
| `strategy_adr_filter_enabled` | true | true/false | Enables the ADR exhaustion counter-trend filter. |
| `strategy_adr_period` | 13 | 2-60 | ADR lookback days. |
| `strategy_adr_exhaustion_fraction` | 1.0 | 0.25-2.0 | Current D1 range fraction of ADR that marks exhaustion. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX FX major with direct M15 stochastic and EMA data.
- `GBPUSD.DWX` - Card-listed DWX FX major with direct M15 stochastic and EMA data.
- `USDJPY.DWX` - Card-listed DWX FX major with direct M15 stochastic and EMA data.
- `EURJPY.DWX` - Card-listed DWX FX cross with direct M15 stochastic and EMA data.

**Explicitly NOT for:**
- Non-DWX symbols - The build and pipeline use `.DWX` research/backtest symbols only.
- Equity index symbols - The card R3 basket is FX-specific, not an index basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H1` EMA(50) trend gate; `PERIOD_D1` ADR exhaustion filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `110` |
| Typical hold time | Up to 12 M15 bars, roughly 3 hours maximum unless SL/TP or opposite cross exits first. |
| Expected drawdown profile | Fixed-risk intraday FX momentum drawdowns constrained by structure stop plus 0.2 ATR buffer. |
| Regime preference | Trend-following stochastic momentum during active London and early New York sessions. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/post/3772616`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9585_ff-ch-stoch-m15.md`

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
| v1 | 2026-06-25 | Initial build from card | 9bb96dfd-28d2-4c6e-954b-a8fec81fa21a |
