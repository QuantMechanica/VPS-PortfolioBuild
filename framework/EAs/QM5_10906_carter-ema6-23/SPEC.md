# QM5_10906_carter-ema6-23 — Strategy Spec

**EA ID:** QM5_10906
**Slug:** `carter-ema6-23`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (Thomas Carter, *20 Forex Trading Strategies (1H)*, Strategy #3, p.9)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

A trend-following moving-average crossover on EURUSD H1. Go long when the EMA(6)
crosses above the EMA(23) on the close of the last bar, confirmed by MACD(30,60,30)
being above zero (or crossing its signal line upward) and a Stochastic(5,3,3) %K
crossing above %D. The source preference to enter "as close to the 6 EMA as
possible" is implemented as a filter: the entry reference price must lie within
0.5 × ATR(14) of the EMA(6). The short side mirrors all conditions. Each trade
takes a fixed 25-pip stop and 55-pip take profit; an open trade is also closed
early if the EMA(6)/EMA(23) pair crosses back in the reverse direction. One
position per magic at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 6 | 3-20 | Fast EMA period (cross trigger) |
| `strategy_ema_slow` | 23 | 10-60 | Slow EMA period (trend filter) |
| `strategy_macd_fast` | 30 | 8-40 | MACD fast EMA |
| `strategy_macd_slow` | 60 | 20-120 | MACD slow EMA |
| `strategy_macd_signal` | 30 | 5-40 | MACD signal smoothing |
| `strategy_stoch_k` | 5 | 3-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-9 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-9 | Stochastic slowing |
| `strategy_atr_period` | 14 | 7-30 | ATR period for entry-proximity band |
| `strategy_atr_prox_mult` | 0.5 | 0.1-2.0 | Entry must be within this × ATR of EMA(6) |
| `strategy_sl_pips` | 25 | 20-30 | Fixed stop loss (pips), source range midpoint |
| `strategy_tp_pips` | 55 | 50-60 | Fixed take profit (pips), source range midpoint |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source symbol/timeframe is EURUSD H1; card R3 PASS lists EURUSD
  as the only portable target, and the matrix confirms EURUSD.DWX tick data.

**Explicitly NOT for:**
- Index `.DWX` symbols (NDX/WS30/SP500) — the strategy and its pip-based fixed
  SL/TP are calibrated to a 5-digit FX pair; index point scales differ entirely.

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
| Trades / year / symbol | `~35` |
| Typical hold time | `hours (intraday-to-multi-day H1 swing)` |
| Expected drawdown profile | `moderate; fixed 25-pip stop caps per-trade loss` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** `book`
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf` (Strategy #3, p.9)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10906_carter-ema6-23.md`

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
| v1 | 2026-06-06 | Initial build from card | 16beaf30-ed42-45f5-aa20-915f9a94dba7 |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
