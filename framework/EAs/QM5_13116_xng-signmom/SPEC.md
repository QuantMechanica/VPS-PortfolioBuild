# QM5_13116_xng-signmom — Strategy Spec

**EA ID:** QM5_13116  
**Slug:** `xng-signmom`  
**Source:** `PAPAILIAS-RSM-2021`  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA trades `XNGUSD.DWX` D1 once per broker month. It reconstructs the prior
13 completed month-end closes, converts the intervening 12 monthly returns to
binary signs, and estimates the probability of a non-negative monthly return by
their equal-weight mean. It buys when the probability is at least 0.40 and sells
otherwise, closes at the next monthly renewal, and protects the position with a
frozen ATR hard stop plus a 35-day stale guard.

The signal uses the distribution of monthly return signs. It is not the
`QM5_12567` long-only cumulative-RSI pullback, conventional cumulative-return
momentum (`QM5_12804`), magnitude reversal, seasonality, event/fundamental data,
breakout, carry, ratio, or return-spread logic.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | 12 | completed monthly signs |
| `strategy_positive_threshold` | 0.40 | 0.30-0.50 | fixed positive-sign threshold |
| `strategy_history_bars` | 500 | 400-650 | bounded D1 reconstruction history |
| `strategy_atr_period` | 20 | 14-30 | frozen hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | hard-stop multiplier |
| `strategy_max_hold_days` | 35 | 35 | stale monthly-position guard |
| `strategy_max_spread_points` | 3000 | 2000-4500 | entry spread cap |

The default Q02 baseline is locked to 12 months and 0.40. The source's adaptive
cross-validated threshold is not implemented.

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.
- No XAU, XAG, XTI, index, FX, basket, or external signal symbol.

## 4. Timeframe

- Host and signal timeframe: D1.
- Signal/renewal: first D1 bar of each broker-calendar month.
- Expected completed trades: approximately 12/year after warm-up.

## 5. Expected Behaviour

The EA should alternate between long and short monthly natural-gas positions
based on sign persistence, not return magnitude. A stopped position is not
re-entered in the same month. Q02 retires the carrier below five trades/year.
Friday close is disabled to preserve the source's one-month holding period;
month reset, stale exit, kill switch, and broker stop remain active.

## 6. Source Citation

Papailias, F., Liu, J., and Thomakos, D. D. (2021), "Return Signal Momentum,"
*Journal of Banking & Finance* 124, Article 106063,
https://doi.org/10.1016/j.jbankfin.2021.106063. The peer-reviewed accepted
manuscript explicitly includes natural gas in its commodity panel and defines
the 12-month binary-sign mean in Equation 7 and monthly fixed-threshold position
rule in Equation 10.

## 7. Risk Model

| Environment | Mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Live | not configured | n/a |

The source uses futures and portfolio volatility scaling; this DWX CFD carrier
uses fixed dollar risk sized to a frozen ATR stop. Q02 independently judges the
translation. No live setfile, deploy/T_Live manifest, portfolio gate, `T_Live`
path, or AutoTrading setting is part of the build.

## 8. Framework Alignment

- No-Trade: exact XNG/D1/slot, parameter, history, arithmetic, spread, ATR, and
  position guards.
- Entry: 12 completed binary monthly signs with fixed 0.40 threshold.
- Management: month reset and 35-day stale close before entry-news gating.
- Close: `QM_TM_ClosePosition` plus the broker ATR hard stop.

## Revision History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-10 | initial XNG return-sign momentum build | Q02 |
| v1.1 | 2026-07-10 | Codex review rework: replace hand-rolled monthly keys with `QM_CalendarPeriodKey(PERIOD_MN1)` and reuse the pooled ATR value for the stop | Q02 |
