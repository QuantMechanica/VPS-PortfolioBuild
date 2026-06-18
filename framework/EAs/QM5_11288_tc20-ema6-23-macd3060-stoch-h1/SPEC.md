# QM5_11288_tc20-ema6-23-macd3060-stoch-h1 — Strategy Spec

**EA ID:** QM5_11288
**Slug:** `tc20-ema6-23-macd3060-stoch-h1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A multi-indicator H1 trend-confluence system from Thomas Carter's "20 Forex
Trading Strategies", Strategy #3. The EMA(6/23) crossover is the single trigger
EVENT; the other indicators act as same-bar directional STATES so two fresh
crosses are never required on one bar. LONG fires when EMA(6) crosses above
EMA(23) on the close of an H1 bar AND MACD(30,60,30) main line is non-negative
(zero-line filter, may be negative for shorts) AND Stochastic(5,3,3) %K is above
%D. SHORT is the mirror: EMA(6) crosses below EMA(23), MACD main non-positive,
and %K below %D. Stop is a fixed 25 pips, take-profit a fixed 55 pips. A reverse
EMA(6/23) cross closes the open position early.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 6 | 3-15 | Fast EMA of the crossover trigger |
| `strategy_ema_slow_period` | 23 | 15-50 | Slow EMA of the crossover trigger |
| `strategy_macd_fast` | 30 | 8-40 | MACD fast EMA period (non-standard) |
| `strategy_macd_slow` | 60 | 20-80 | MACD slow EMA period (non-standard) |
| `strategy_macd_signal` | 30 | 5-40 | MACD signal EMA period |
| `strategy_stoch_k` | 5 | 3-14 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-5 | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | 1-5 | Stochastic slowing |
| `strategy_sl_pips` | 25.0 | 20-30 | Fixed stop-loss distance in pips |
| `strategy_tp_pips` | 55.0 | 50-60 | Fixed take-profit distance in pips |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Block only a genuinely wide spread (fail-open on zero) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary; deepest liquidity, tightest spread on H1 forex.
- `GBPUSD.DWX` — card P2 basket; liquid major, trends well on H1.
- `USDJPY.DWX` — card P2 basket; liquid major, JPY pip-scaling handled by `QM_StopRules*`.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — card is a forex H1 strategy; pip thresholds
  (25/55) are forex-calibrated and would mis-scale on indices/metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` |
| Typical hold time | `hours (intraday-to-multi-bar H1)` |
| Expected drawdown profile | `moderate; fixed 25-pip stop caps per-trade loss` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #3 (local PDF archive per card frontmatter).
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11288_tc20-ema6-23-macd3060-stoch-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA(6/23) trigger + MACD/Stoch states |
