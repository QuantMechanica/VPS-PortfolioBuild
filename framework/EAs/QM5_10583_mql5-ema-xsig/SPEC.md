# QM5_10583_mql5-ema-xsig - Strategy Spec

**EA ID:** QM5_10583
**Slug:** `mql5-ema-xsig`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see MQL5 CodeBase citation below)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades the closed-bar crossover signal from the MQL5 EMA-Crossover semaphore family. It opens long when the fast EMA crosses above the slow EMA on the latest closed H6 bar, and opens short when the fast EMA crosses below the slow EMA. It exits an open long on the opposite bearish crossover and exits an open short on the opposite bullish crossover. Each entry uses an ATR(14) stop at 2.0 times ATR and a take-profit target at 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 5 | 1 to `strategy_slow_ema_period - 1` | Fast EMA period used for the crossover signal. |
| `strategy_slow_ema_period` | 6 | `strategy_fast_ema_period + 1` and above | Slow EMA period used for the crossover signal. |
| `strategy_atr_period` | 14 | 1 and above | ATR lookback for hard stop distance. |
| `strategy_atr_sl_mult` | 2.0 | greater than 0 | ATR multiplier for the stop loss. |
| `strategy_take_profit_rr` | 1.5 | greater than 0 | Reward-to-risk multiple for the take-profit target. |
| `strategy_max_spread_points` | 80 | 0 disables; otherwise points | Blocks new entries when current spread is above this threshold. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - primary source-test style FX major from the approved card basket.
- `EURUSD.DWX` - liquid FX major suitable for portable EMA crossover testing.
- `GBPJPY.DWX` - liquid FX cross from the approved card basket.
- `XAUUSD.DWX` - liquid metal from the approved card basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's approved R3 FX/metals P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | H6 closed-bar signals; typically hours to days depending on the next opposite crossover or SL/TP. |
| Expected drawdown profile | Trend-following crossover drawdowns during choppy ranges. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/13588`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10583_mql5-ema-xsig.md`

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
| v1 | 2026-05-31 | Initial build from card | 00629e77-fcf8-426c-abcf-55e89ee1f445 |
