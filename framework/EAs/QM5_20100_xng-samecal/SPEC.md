# QM5_20100_xng-samecal

**EA ID:** QM5_20100

**Source strategy:** `KELOHARJU-RETSEAS-2016_XNG_S03`

## 1. Strategy Logic

On the first genuine `XNGUSD.DWX` D1 bar of each broker month, reconstruct
natural gas's completed return for that same calendar month in up to ten prior
years. Require at least five observations. Buy for one month when the
arithmetic average is positive and sell for one month when it is negative.

The previous package closes before renewal. A month is consumed before news,
history, spread, ATR, price, or order gates, so restart or rejection cannot
create a same-month retry. The source documents a broad cross-sectional
commodity effect; the single-XNG absolute-sign translation is a locked Q02
falsification candidate.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_history_years` | 10 | Maximum prior same-month observations |
| `strategy_min_history_years` | 5 | Minimum valid observations |
| `strategy_history_bars` | 3000 | Bounded D1 reconstruction buffer |
| `strategy_atr_period` | 20 | Completed-bar hard-stop estimator |
| `strategy_atr_sl_mult` | 4.0 | Frozen stop distance |
| `strategy_max_hold_days` | 35 | Stale monthly-package guard |
| `strategy_max_spread_points` | 2500 | Entry spread ceiling |

All strategy parameters are locked for Q02. No baseline sweep is authorized.

## 3. Symbol Universe

- `XNGUSD.DWX`, D1, magic slot 0, magic `201000000`.
- No WTI leg, implicit symbol port, futures chain, or external runtime series
  is permitted.

## 4. Timeframe

The EA runs only on D1. It copies completed D1 history only at a detected
broker-month boundary and reconstructs exact month-end closes from that
bounded array. The current month never enters its signal.

## 5. Expected Behaviour

- One consumed decision per broker month.
- About 10-12 completed packages/year after the five-year warm-up.
- Typical hold: one broker month; hard-capped at 35 calendar days.
- Positive historical same-month average: long XNG.
- Negative historical same-month average: short XNG.
- Exact tie, insufficient history, invalid arithmetic, blocked entry or stop:
  flat for the rest of that month.

Q02 must retire the carrier for zero trades, fewer than five completed
packages/year after warm-up, wrong-month or duplicate entries, look-ahead,
nondeterminism, risk-mode mismatch, or governed performance failure.

## 6. Source Citation

Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016), "Return
Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
`10.1111/jofi.12398`. The complete reviewed NBER version is Working Paper
20815. The approved card is
`strategy-seeds/cards/approved/QM5_20100_xng-samecal_card.md`.

## 7. Risk Model

The only preset is backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Entry receives one normalized `4.0 * ATR(20)` hard stop;
there is no take-profit, trailing, scaling, grid, martingale, or same-month
re-entry. Friday close is disabled only to preserve the source-aligned monthly
hold. This build does not authorize a live preset, T_Live, AutoTrading,
deployment, portfolio admission, or a portfolio-gate change.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-24 | Initial approved-card build |
