# QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd — Strategy Spec

**EA ID:** QM5_11319
**Slug:** `tc-m5-11-mtf-ema-rsi-stoch-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 5 Min System #11)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multi-timeframe trend-following scalp on the same symbol (no basket). The higher
timeframe H4 sets directional bias: H4 EMA(5) > H4 EMA(10) permits longs only,
H4 EMA(5) < H4 EMA(10) permits shorts only. On the M5 entry timeframe the single
fresh trigger EVENT is the M5 EMA(5)/EMA(10) crossover; every other condition is a
STATE read on the same closed M5 bar, so two cross events are never required on one
bar. A long fires when, on the just-closed M5 bar: H4 bias is up, M5 EMA(5) crosses
above M5 EMA(10), RSI(14) > 50, Stochastic(5,3,3) %K is rising (%K@1 > %K@2) and
below the cap, and the MACD(12,26,9) histogram is rising (hist@1 > hist@2 — this
single condition captures the card's "cross from negative to positive OR negative
but increasing" disjunction; MACD may be negative). Shorts are the exact mirror.
Exit is by fixed stop-loss / take-profit only (source defines no indicator exit);
baseline 25 pips each. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bias_tf` | PERIOD_H4 | H1-D1 | Higher-TF EMA bias timeframe |
| `strategy_ema_fast_period` | 5 | 3-20 | Fast EMA (bias TF and M5 entry TF) |
| `strategy_ema_slow_period` | 10 | 5-50 | Slow EMA (bias TF and M5 entry TF) |
| `strategy_rsi_period` | 14 | 5-30 | RSI period on entry TF |
| `strategy_rsi_mid` | 50.0 | 40-60 | RSI midline filter (long >mid / short <mid) |
| `strategy_stoch_k` | 5 | 3-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 1-10 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-10 | Stochastic slowing |
| `strategy_stoch_cap` | 80.0 | 60-90 | Long: %K must be below this |
| `strategy_stoch_floor` | 20.0 | 10-40 | Short: %K must be above this |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA |
| `strategy_macd_slow` | 26 | 15-50 | MACD slow EMA |
| `strategy_macd_signal` | 9 | 3-15 | MACD signal EMA |
| `strategy_sl_pips` | 25.0 | 20-30 | Stop loss in pips |
| `strategy_tp_pips` | 25.0 | 20-30 | Take profit in pips |
| `strategy_spread_pct_of_stop` | 50.0 | 10-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid FX pair; tight spreads suit a 25-pip M5 scalp
- `GBPUSD.DWX` — liquid major with intraday trend persistence on M5
- `USDJPY.DWX` — liquid major; pip-scaling handled via QM_StopRules (3-digit JPY)

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — source is a forex 5-minute system; pip-based
  25-pip stops are calibrated for FX majors, not index points or metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H4 EMA(5/10) bias read on the same symbol (no basket)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~90` |
| Typical hold time | `minutes to a few hours (M5 scalp, 25-pip targets)` |
| Expected drawdown profile | `frequent small losers; clustered around choppy bias-flip periods` |
| Regime preference | `trend / momentum-continuation` |
| Win rate target (qualitative) | `medium (1:1 RR baseline)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)" (2014), 5 Min Trading System #11, pp. 28-29 — local PDF cited in card frontmatter.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
