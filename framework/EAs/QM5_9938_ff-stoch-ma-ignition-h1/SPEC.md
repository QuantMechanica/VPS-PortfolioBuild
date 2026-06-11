# QM5_9938_ff-stoch-ma-ignition-h1 - Strategy Spec

**EA ID:** QM5_9938
**Slug:** ff-stoch-ma-ignition-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 trend ignition on ForexFactory's stochastic MA system. A long entry is allowed when EMA(3) and EMA(5) have each crossed from below EMA(13) to above EMA(13) within the last five completed H1 candles, both fast EMAs are rising over three bars, and Stochastic %K(14,3,3) crossed above 50 within two bars of the completed EMA ignition. Shorts mirror the same rules below EMA(13) with falling EMA slopes and a Stochastic %K cross below 50.

Entries are market orders at the next H1 open after the completed signal while the last closed candle remains on the correct side of EMA(13). Exits use a fixed 20-pip SL, fixed 40-pip TP, an early close when EMA(3) and EMA(5) move back across EMA(13) against the trade, and a 12-H1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 3 | 1+ | Fast EMA used in the ignition cross. |
| `strategy_ema_confirm_period` | 5 | 1+ | Second fast EMA that must also cross EMA(13). |
| `strategy_ema_slow_period` | 13 | 1+ | Trend EMA used as the ignition threshold. |
| `strategy_stoch_k_period` | 14 | 1+ | Stochastic %K period. |
| `strategy_stoch_d_period` | 3 | 1+ | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing value. |
| `strategy_stoch_midline` | 50.0 | 0-100 | Midline crossed by Stochastic %K for confirmation. |
| `strategy_ignition_fresh_bars` | 5 | 1+ | Maximum completed H1 bars since both EMA ignition crosses. |
| `strategy_slope_lookback_bars` | 3 | 1+ | Bars used to confirm EMA(3) and EMA(5) slope direction. |
| `strategy_stoch_sync_bars` | 2 | 0+ | Maximum bar distance between stochastic cross and EMA ignition. |
| `strategy_fixed_sl_pips` | 20 | 1+ | Fixed FX stop loss in pips. |
| `strategy_fixed_tp_pips` | 40 | 1+ | Fixed FX take profit in pips. |
| `strategy_max_spread_sl_frac` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of fixed SL distance. |
| `strategy_time_stop_bars` | 12 | 1+ | Maximum holding time in H1 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX major with direct DWX availability.
- `GBPUSD.DWX` - Card-listed FX major with direct DWX availability.
- `USDJPY.DWX` - Card-listed FX major with direct DWX availability.
- `AUDUSD.DWX` - Card-listed FX major with direct DWX availability.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The card specifies FX-major 20-pip SL and 40-pip TP behavior; non-FX ports would need ATR/2R handling from a separate card decision.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Trade frequency | H1 MA/stochastic ignition; estimate 70-120 trades/year/symbol after five-candle freshness rule. |
| Typical hold time | Up to 12 H1 bars by card time stop; earlier SL/TP or opposite EMA exit allowed. |
| Regime preference | Short-term trend ignition / momentum continuation. |
| Win rate target (qualitative) | Medium; fixed 20-pip SL and 40-pip TP gives 2R reward-to-risk. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** jamesagnew, "1 hour system trade with stochastics", ForexFactory, 2025, https://www.forexfactory.com/thread/1346623-1-hour-system-trade-with-stochastics
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9938_ff-stoch-ma-ignition-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 65e66139-9669-40af-bf5e-8234f232403d |
