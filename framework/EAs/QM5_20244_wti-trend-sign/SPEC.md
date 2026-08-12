# QM5_20244_wti-trend-sign - Strategy Spec

**EA ID:** QM5_20244

**Slug:** `wti-trend-sign`

**Source:** `MOP-PAPAILIAS-WTI-TRENDSIGN-2026`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, reconstruct
thirteen consecutive completed broker-month closes. Calculate the cumulative
twelve-month log return and the twelve constituent monthly log returns.
Independently map the cumulative return to a long/short direction and map the
fraction of non-negative monthly returns to the published return-sign state:
long at probability at least 0.40, short otherwise.

Open a package only when both directions agree. Disagreement, exact-zero
cumulative return, or invalid history consumes the month flat. Close the prior
package before every monthly decision. Persist each month before fallible
gates so a blocked, stopped, failed, or flat attempt cannot retry after a
restart. Use a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a forty-day
stale guard. Friday close is disabled because the monthly hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 12 | Common cumulative-return and binary-sign window |
| `strategy_positive_threshold` | 0.40 | Fixed return-sign long threshold |
| `strategy_history_bars` | 500 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every strategy value is locked for Q02. No baseline parameter sweep is
authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202440000`).
- No companion symbol, futures curve, conversion history, or external input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Formation: thirteen consecutive completed broker-month endpoints.
- Signal: `ln(M0/M12)` plus the non-negative count of
  `ln(M_i/M_i+1)`, `i=0..11`.

## 5. Expected Behaviour

Maximum cadence is twelve consumed decisions per full post-warm-up year. The
predeclared expectation is eight to eleven completed packages/year; Q02
retires below five per full post-warm-up year. Exposure normally spans one
broker month. Principal risks are WTI gaps and rolls, futures-to-CFD basis,
financing, sign-state concentration, false trend confirmation, stop-outs, and
realized book correlation.

This is not pure 12-month WTI momentum, binary return-sign momentum, two
cumulative-horizon agreement, a seasonal filter, or pre-pullback trend. Its
load-bearing object is agreement between cumulative magnitude direction and
the breadth of twelve separate monthly signs over one common interval.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Papailias, F., Liu, J., and Thomakos, D. D. (2021), "Return Signal Momentum,"
*Journal of Banking & Finance* 124, 106063, DOI
`10.1016/j.jbankfin.2021.106063`.

The governed composite record is
`strategy-seeds/sources/MOP-PAPAILIAS-WTI-TRENDSIGN-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20244_wti-trend-sign_card.md`. Both papers
include WTI futures and supply the parent states, not this conjunction's CFD
performance, drawdown, costs, density, or portfolio correlation.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no manual backtest, live/demo/shadow
setfile, live authorization, deploy manifest, portfolio admission, or
portfolio-gate change.

## 8. Framework Alignment

- **No trade:** exact host/timeframe/ID/slot, locked inputs, news/Friday
  contract, month boundary, attempt state, history, agreement, spread, quote,
  ATR, and stop guards.
- **Trade entry:** thirteen endpoint reconstruction, cumulative trend,
  twelve-return sign probability, concordance, registered magic, V5
  fixed-risk sizing, and frozen hard stop.
- **Trade management:** next-month and forty-day stale closes before
  entry-only gates.
- **Trade close:** framework close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile/build PASS; zero errors, warnings, failures, or build warnings |
| v1.1 | 2026-08-06 | Paced Q02 handoff | Not enqueued at binding 7/7 factory-terminal CPU ceiling; no tester run |
