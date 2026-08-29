# QM5_41206_xauxag-samecal-huber10 - Strategy Spec

**EA ID:** QM5_41206

Slug: `xauxag-samecal-huber10`

Strategy ID: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01`

Source: `KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026`

Author: Development

Last revised: 2026-08-29

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar after each genuine broker-month
transition, reconstruct synchronized completed XAU and XAG returns for the
same target calendar month in exact years `Y-1` through `Y-10`. Require all
ten paired observations and form `d=r_xau-r_xag`.

Compute the even median and raw even MAD, freeze scale at `1.4826*MAD` and
Huber delta at `1.5*scale`, then run exactly 32 weighted-location updates.
A location above `1e-12` buys XAU and sells XAG; below `-1e-12` reverses both
legs. Invalid or inclusive-band state consumes the month flat. The package
closes and recomputes at the next month boundary.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | XAGUSD.DWX | exact companion leg |
| `strategy_history_years` | 10 | exact prior same-calendar years inspected |
| `strategy_required_observations` | 10 | synchronized paired sample, no substitution |
| `strategy_mad_normalizer` | 1.4826 | frozen raw-MAD scale multiplier |
| `strategy_huber_tuning` | 1.5 | frozen-scale clipping multiplier |
| `strategy_huber_steps` | 32 | exact reweight updates, no early stop |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded D1 reconstruction buffer per leg |
| `strategy_atr_period_d1` | 20 | completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | stale survivor guard |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_points` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | basket market-order deviation |

All values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, magic `412060000`.
- Companion/traded slot 1: `XAGUSD.DWX`, magic `412060001`.
- No third traded symbol or external runtime dependency.

## 4. Timeframe

- Host and both signal inputs: D1.
- Decision/reset: first genuine D1 bar after each broker-month transition.
- History work runs only after new-bar, month-boundary, and consumed-attempt
  gates.

## 5. Expected Behaviour

- Approximately ten to twelve two-leg packages/year after the ten-year
  warm-up; Q02 retires below five completed packages in a full post-warm-up
  year.
- Direction: exactly one long metal and one short metal.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Hold: next broker month, capped by 40 days, malformed repair, or per-leg
  broker stop.
- Friday close and both news axes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *Journal of
Finance* 71(4), 1557-1590, supplies recurring same-calendar commodity-return
information and the history floor. Fuertes, Miffre, and Rallis (2010),
"Tactical Allocation in Commodity Futures Markets," *Journal of Banking &
Finance* 34(10), 2530-2548, supplies the governed XAU/XAG carrier and monthly
hold. Huber (1964), "Robust Estimation of a Location Parameter," *Annals of
Mathematical Statistics* 35(1), 73-101, supplies bounded-influence location
lineage; the governed packet fixes the exact arithmetic.

The complete evidence boundary is
`strategy-seeds/sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026/source.md`;
the approved card is
`strategy-seeds/cards/approved/QM5_41206_xauxag-samecal-huber10_card.md`.
No source tests this exact paired CFD basket or establishes decorrelation.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the package stop-risk budget and
a frozen `3.5*ATR(20,D1)` hard stop. If either leg cannot be prepared or the
second leg fails, the package stands down or is flattened immediately.

No live setfile, live authorization, deploy manifest, `T_Live` change,
portfolio admission, correlation waiver, or portfolio-gate change exists.

## 8. Framework Alignment

- No-Trade: exact host/slot/input, synchronized endpoint, all-ten sample,
  finite location arithmetic, spread, quote, stop, lot, package, and
  consumed-month guards.
- Entry: paired same-calendar Huber side, opposite legs, shared fixed risk,
  and frozen stops.
- Management: later-month, 40-day stale, orphan, direction, magic, duplicate,
  and stop repair before any new entry.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-29 | Initial build from approved G0 card | Q01 pending |
