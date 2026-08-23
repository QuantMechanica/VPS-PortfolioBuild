# QM5_41132_wti-mweekday-med-mom - Strategy Spec

**EA ID:** QM5_41132

**Slug:** `wti-mweekday-med-mom`

**Strategy ID:** `MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01`

**Source:** `MOP-MEEK-WTI-MWEEKDAY-MED-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-23

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
collect every close in the immediately completed calendar month. Require 17
through 23 unique month-session closes and one older adjacent-month boundary
close. One uniform label offset—raw or `+1` calendar day—is applied to the
current bar and the complete history package.

Starting at the older boundary, compute one chronological log return ending on
every completed-month session and verify the sum against the direct endpoint
return within `1e-10`. Assign each return by its normalized ending weekday,
require all five Monday-through-Friday buckets, and require three through five
observations in each bucket. Compute each bucket's arithmetic mean, sort the
five means ascending, and select exact index two. A strictly positive median
buys WTI, a strictly negative median sells, and exact zero stays flat. The raw
month endpoint is logged but never gates or sizes the trade.

The decision month is persisted before any fallible gate. A valid direction
owns one fixed-risk position until the first later normalized broker month,
protected by a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded completed-month buffer |
| `strategy_min_month_sessions` | 17 | minimum returns ending in month |
| `strategy_max_month_sessions` | 23 | maximum returns ending in month |
| `strategy_weekday_buckets` | 5 | exact Monday-through-Friday buckets |
| `strategy_min_bucket_observations` | 3 | per-weekday minimum |
| `strategy_max_bucket_observations` | 5 | per-weekday maximum |
| `strategy_numerical_tolerance` | 1e-10 | endpoint identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for the single Q02 baseline; there is no optimization
surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411320000`.
- No signal, hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: immediately completed normalized broker-calendar month.
- Path statistic: median of five equally weighted ending-weekday mean daily
  log returns.
- Direction: strict sign of that median, independent of the raw endpoint sign.
- Hold: first tick in a later normalized broker month, with a forty-day stale
  repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-WTI structural continuation after weekday-balanced monthly
  path aggregation.
- One fixed-risk position and one consumed attempt per broker month.
- WTI supplies physical-energy exposure distinct from the current carriers;
  only Q09 may establish realized portfolio decorrelation.

## 6. Source Citations

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Meek, H., and Hoelscher, S. A. (2023), "Day-of-the-week effect: Petroleum and
petroleum products," *Cogent Economics & Finance* 11(1), DOI
`10.1080/23322039.2023.2213876`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026/source.md`.

The first paper supplies WTI membership and own-return monthly-continuation
lineage. The second supplies ending-weekday WTI heterogeneity and label
lineage. The within-month median of weekday means is an explicitly disclosed
QM hypothesis. No source result transfers to this continuous-CFD carrier.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, raw-endpoint gate, fitted center or scale, retry, scale-in, grid,
martingale, pyramid, target, trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot and locked risk/news/Friday/strategy
  inputs.
- trade_entry: normalized month clock, consumed attempt, exact calendar
  package, chronological log returns, endpoint identity, ending weekdays,
  bucket counts and means, exact median, spread/quote/ATR/stop checks, and one
  fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-23 | approved source build | G0-approved card and governed magic `411320000` |
