# QM5_41136_xng-mdaily-iqrmean-mom - Strategy Spec

**EA ID:** QM5_41136

**Slug:** xng-mdaily-iqrmean-mom

**Strategy ID:** MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01

**Source:** MOP-MEEK-XNG-MDAILY-IQRMEAN-2026

**Author of this spec:** Codex

**Last revised:** 2026-08-24

## 1. Strategy Logic

On the first executable XNGUSD.DWX D1 bar of a new normalized broker month,
collect every close in the immediately completed calendar month. Require 17
through 23 unique month-session closes and one older adjacent-month boundary
close. One uniform label offset, raw or plus one calendar day, applies to the
current bar and the entire history package.

Starting at the older boundary, compute one chronological log return ending on
every completed-month session and verify their sum against the direct endpoint
return within 1e-10. Sort all individual returns ascending without rounding.
For n returns, remove floor(n/4) observations from each tail and average every
remaining observation at indexes floor(n/4) through n-floor(n/4)-1. This
retains exactly 9 through 13 central observations.

A strictly positive central mean buys XNG, a strictly negative central mean
sells, and exact zero stays flat. The raw month endpoint is logged only; it
never gates direction, sizing, or entry.

The decision month is persisted before any fallible gate. A valid direction
owns one fixed-risk position until the first later normalized broker month,
protected by a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| strategy_entry_grace_minutes | 180 | raw current-bar execution window |
| strategy_history_bars_d1 | 45 | bounded completed-month buffer |
| strategy_min_month_sessions | 17 | minimum returns ending in month |
| strategy_max_month_sessions | 23 | maximum returns ending in month |
| strategy_trim_divisor | 4 | integer tail-trim divisor |
| strategy_min_retained_returns | 9 | fail-closed retained-band floor |
| strategy_numerical_tolerance | 1e-10 | endpoint identity tolerance |
| strategy_atr_period_d1 | 20 | completed-bar risk range |
| strategy_atr_sl_mult | 3.5 | frozen hard-stop distance |
| strategy_max_hold_days | 40 | stale-position repair |
| strategy_max_spread_points | 3000 | XNG entry-cost guard |
| qm_friday_close_enabled | false | preserve full-month ownership |

All inputs are locked for the single Q02 baseline. There is no optimization
surface.

## 3. Symbol Universe

- Host and traded symbol: exact XNGUSD.DWX, D1.
- Symbol slot: 0.
- Magic: 411360000.
- No hedge, conversion, ratio, external, or companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: immediately completed normalized broker-calendar month.
- Path statistic: arithmetic mean of the central band after symmetric integer
  quartile trimming of all 17-23 daily log returns ending in that month.
- Direction: strict sign of that central mean, independent of raw endpoint.
- Hold: first tick in a later normalized broker month, with a forty-day stale
  repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed XNG positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric direct-XNG structural continuation after robust within-month path
  aggregation.
- One fixed-risk position and one consumed attempt per broker month.
- XNG supplies monthly symmetric structural-trend exposure distinct from the
  certified short-horizon oscillator carrier; only Q09 may establish realized
  portfolio decorrelation.

## 6. Source Citations

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," Journal of Financial Economics 104(2), 228-250, DOI
10.1016/j.jfineco.2011.11.003.

Meek, H., and Hoelscher, S. A. (2023), "Day-of-the-week effect: Petroleum and
petroleum products," Cogent Economics & Finance 11(1), DOI
10.1080/23322039.2023.2213876.

Canonical bounded source packet:
strategy-seeds/sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026/source.md.

The first paper supplies XNG membership and own-return monthly-continuation
lineage. The second supplies close-to-close daily XNG log-return lineage. The
within-month symmetric interquartile-mean translation is an explicitly
disclosed QM hypothesis. No source result transfers to this continuous-CFD
carrier.

## 7. Risk Model And Scope

Q02 uses RISK_FIXED=1000, RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1. Position
sizing uses a frozen completed-bar 3.5*ATR(20,D1) stop through the V5 risk
helper. Both news axes and Friday close are OFF.

There is no live, demo, shadow, stress, or optimization setfile; no manual
backtest; no AutoTrading, T_Live, deploy, or live manifest; no portfolio
admission or decorrelation claim; and no correlation waiver or portfolio-gate
change. The EA has no current-month signal price, raw-endpoint gate, fitted
center or scale, retry, scale-in, grid, martingale, pyramid, target, trail,
break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbol, period, ID, slot, risk mode, and locked strategy,
  news, Friday, and stress inputs.
- trade_entry: normalized month clock, consumed attempt, exact calendar
  package, chronological log returns, endpoint identity, full sort, integer
  symmetric trim, retained arithmetic mean, spread, quote, ATR, stop, and one
  fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-24 | approved source build | G0-approved card and governed magic 411360000 |
