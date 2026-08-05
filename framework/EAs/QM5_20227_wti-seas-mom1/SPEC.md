# QM5_20227 wti-seas-mom1 - Strategy Spec

**EA ID:** QM5_20227

**Slug:** `wti-seas-mom1`

**Source:** `BURAKOV-MOP-WTI-SEASMOM1-2026`

**Author:** Research+Development

**Last revised:** 2026-08-05

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, reconstruct
the exact immediately completed broker-calendar-month log return. Classify
November-May as seasonal BUY and June-October as seasonal SELL. Open a package
only when the completed-month return sign agrees: BUY after a positive winter
month or SELL after a negative summer month. Disagreement and exact zero stay
flat after consuming the month.

Close the prior package before the next month decision. Use a frozen
`3.5 * ATR(20,D1)` server-side hard stop, no target, a forty-day stale guard,
and no intramonth re-entry. Friday close is disabled for the source-aligned
month-to-month hold.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_winter_first_month` | 11 | Seasonal BUY interval start |
| `strategy_winter_last_month` | 5 | Seasonal BUY interval end |
| `strategy_history_bars` | 80 | Bounded completed-month reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | WTI entry spread ceiling |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202270000`).
- No companion symbol, conversion history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Formation: two consecutive completed broker-month-end closes.
- Ordinary exposure: one broker month.

## 5. Expected Behaviour

Maximum cadence is twelve decisions per full post-warm-up year. The
predeclared expectation is five to seven concordant packages/year; Q02 retires
below five completed packages/year. Principal risks are filter-induced
under-frequency, one-month reversal, WTI gaps and rolls, futures-to-CFD basis,
financing, source decay, and realized book correlation. This build makes no
profitability, decorrelation, certification, or portfolio-admission claim.

## 6. Source Citation

Burakov, Freidin, and Solovyev (2018), "The Halloween Effect on Energy
Markets: An Empirical Study," *International Journal of Energy Economics and
Policy* 8(2), 121-126. Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed composite is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM1-2026/source.md`; the card is
`strategy-seeds/cards/wti-seas-mom1_card.md`. The papers supply the two parent
states, not this conjunction's WTI CFD or portfolio performance.

## 7. Risk Model

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and legacy news mode are OFF; framework
Friday close is disabled. There is no live/demo/shadow setfile, live
authorization, deploy manifest, portfolio admission, or portfolio-gate
change.

## Framework Alignment

- no_trade: exact carrier/D1/ID/slot, frozen inputs, Friday/news contract,
  completed-month validation, agreement, spread, and attempt gates.
- trade_entry: exact one-month sign, fixed seasonal direction, concordance,
  restart-safe consumed attempt, fixed-risk sizing, and frozen ATR stop.
- trade_management: close-before-renew, wrong-side close, and stale guard.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-05 | Initial build from approved G0 card | Q01 strict compile/build PASS; zero errors, warnings, failures, or build warnings |
