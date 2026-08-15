# QM5_41017_wti-dom-ctrreg - Strategy Spec

**EA ID:** QM5_41017  
**Slug:** `wti-dom-ctrreg`  
**Strategy ID:** `BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01`  
**Source:** `BOROWSKI-MOP-WTI-DOMCOUNTER-2026`  
**Author:** Research+Development  
**Last revised:** 2026-08-16

## 1. Strategy Logic

On an actual `XTIUSD.DWX` D1 bar dated exactly broker-calendar day 8, buy
only when the completed 252-D1 log return is strictly negative. On an exact
day-26 D1 bar, sell only when that return is strictly positive. Read
`Close[1]` and `Close[253]`, never current-bar prices, and never shift a
missing date.

Consume each exact-date decision before fallible gates. Close on the first
following D1 bar, with a one-calendar-day stale guard. Freeze a
`2.75 * ATR(20,D1)` hard stop, use no profit target, and retain framework
Friday close at broker hour 21.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_long_day` | 8 | exact negative-state long date |
| `strategy_short_day` | 26 | exact positive-state short date |
| `strategy_momentum_lookback_d1` | 252 | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | strict sign with no deadband |
| `strategy_entry_grace_minutes` | 5 | exact D1-open attachment window |
| `strategy_atr_period` | 20 | completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 2.75 | frozen hard-stop distance |
| `strategy_max_hold_days` | 1 | one-calendar-day stale guard |
| `strategy_max_spread_points` | 2500 | maximum WTI entry spread |

Every value is locked for Q02. No baseline sweep, neighboring-date
substitution, state flip, or unconditional fallback is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot 0, magic `410170000`.
- No companion symbol, logical basket, conversion-only history, or external
  runtime input.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision: first observed tick within five minutes of an exact day-8 or
  day-26 D1 bar.
- State: completed D1 `Close[1]` versus `Close[253]`.
- Lifecycle: first following D1 bar.

## 5. Expected Behaviour

The completed trend sign normally authorizes one of the two calendar arms per
month, while weekends and holidays remove exact dates. Expected cadence is
approximately six to ten completed positions per full post-warm-up year; Q02
retires below five/year.

The return driver is a sparse physical-crude calendar/counter-regime
interaction outside the certified XAU, SP500, NDX, and XNG book. Realized
decorrelation is not assumed and remains a downstream Q09 gate.

## 6. Source Citation

Borowski, K. (2016), "Analysis of Selected Seasonality Effects in Markets of
Future Contracts," *Journal of Management and Financial Sciences* 26, 27-44.
Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed composite is
`strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMCOUNTER-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_41017_wti-dom-ctrreg_card.md`. The papers
supply numbered-day directions and an own-return state lineage, not the
opposing-state conjunction or any CFD/portfolio performance claim.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The frozen hard stop is the sole sizing distance and
signal magnitude never scales risk. Both news axes are OFF. Friday close
remains enabled at broker hour 21.

No manual backtest, live/demo/shadow setfile, AutoTrading, `T_Live`, deploy
manifest, portfolio admission, correlation waiver, portfolio-gate change, or
live-manifest change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-15 | initial approved build scaffold | magic 410170000 registered; strict Q01 PASS |
| v2 | 2026-08-16 | paced Q02 admission | work item `7eb89f24-8be4-49a0-8b94-5501e124f059` pending; no dispatch |
| v3 | 2026-08-16 | Q02 zero-trades classification | valid bound run returned zero trades; the frozen five-minute nominal D1-open gate requires a new approved variant before repair |
