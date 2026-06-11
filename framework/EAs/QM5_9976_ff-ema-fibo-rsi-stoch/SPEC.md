# QM5_9976_ff-ema-fibo-rsi-stoch - Strategy Spec

**EA ID:** QM5_9976
**Slug:** ff-ema-fibo-rsi-stoch
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 EMA20 breakout or bounce signals confirmed by RSI(10) and Stochastic(10,3,3). A long setup requires the last closed bar to cross above EMA20 or bounce from EMA20 while still closing above it, RSI(10) to cross above 50, and Stochastic %K to cross above %D while crossing upward through 20, 40, 60, or 80. Shorts mirror the same logic below EMA20, with RSI crossing below 50 and Stochastic crossing downward. Entries are market orders on the next bar, with TP at 0.618 ATR(20) and early close on the opposite EMA20 close plus RSI midline cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 20 | 1+ | EMA period used for breakout and bounce tests. |
| strategy_atr_period | 20 | 1+ | ATR period used to normalize Fibonacci levels. |
| strategy_fibo_stop_atr_mult | 0.382 | 0.0+ | ATR multiplier for the EMA Fibonacci stop offset. |
| strategy_fibo_tp_atr_mult | 0.618 | 0.0+ | ATR multiplier for the take-profit distance. |
| strategy_rsi_period | 10 | 1+ | RSI period for midline confirmation. |
| strategy_rsi_midline | 50.0 | 0-100 | RSI threshold crossed for momentum confirmation. |
| strategy_stoch_k | 10 | 1+ | Stochastic %K period. |
| strategy_stoch_d | 3 | 1+ | Stochastic %D period. |
| strategy_stoch_slowing | 3 | 1+ | Stochastic slowing value. |
| strategy_fixed_stop_pips | 10 | 1+ | Fixed stop fallback distance in pips. |
| strategy_min_fx_stop_pips | 5 | 1+ | Minimum FX stop distance when EMA-level stop is too tight. |
| strategy_max_spread_stop_fraction | 0.10 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |
| strategy_no_entry_last_minutes | 15 | 0-59 | Blocks new entries in the final minutes before bar close. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - R3 basket FX major with full DWX availability.
- GBPUSD.DWX - R3 basket FX major with full DWX availability.
- USDJPY.DWX - R3 basket FX major with full DWX availability.
- XAUUSD.DWX - R3 basket liquid metal symbol with DWX availability.

**Explicitly NOT for:**
- SP500.DWX - not part of this ForexFactory FX/metals R3 basket.
- NDX.DWX - not part of this ForexFactory FX/metals R3 basket.
- WS30.DWX - not part of this ForexFactory FX/metals R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | H1 swing hold, usually hours to a few days until 0.618 ATR TP, SL, Friday close, or opposite EMA/RSI exit. |
| Expected drawdown profile | Momentum-confirmed EMA breakout/bounce systems should take clustered losses in choppy low-follow-through periods. |
| Regime preference | EMA breakout/bounce with momentum confirmation; best in directional intraday FX/metals regimes. |
| Win rate target (qualitative) | medium |

Card frontmatter frequency: "EMA20 close/bounce plus RSI/Stochastic confirmation on H1; estimate 35-80 trades/year/symbol."

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** MIH Bobby, "EMA Fibonacci Level Trading Strategy", ForexFactory, 2013, https://www.forexfactory.com/thread/416962-ema-fibonacci-level-trading-strategy
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9976_ff-ema-fibo-rsi-stoch.md`

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
| v1 | 2026-06-11 | Initial build from card | a648436d-d984-4070-bb58-793b4a138e15 |
