# QM5_41137_wti-mmedian-shift-mom - Strategy Spec

**EA ID:** QM5_41137

**Slug:** wti-mmedian-shift-mom

**Strategy ID:** MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01

**Source:** MOP-WTI-MMEDIAN-SHIFT-MOM-2026

**Author of this spec:** Codex

**Last revised:** 2026-08-24

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month,
load at least 70 completed bars and select every valid close in each of the two
immediately completed consecutive calendar months. Each month must contain
17-23 unique, strictly descending normalized weekday labels. One uniform
energy-label offset, raw or plus one calendar day, applies to the current bar
and every historical observation.

Transform each accepted close independently to its natural logarithm. Sort
the two monthly samples independently and calculate the ordinary sample
median: the middle value for odd counts and the arithmetic mean of the two
middle values for even counts. A newest median strictly above the parent
median buys WTI; a newest median strictly below sells; exact equality stays
flat. No daily return, endpoint, range, threshold, fitted coefficient, or
cross-sample centering participates.

The decision month is persisted before any fallible gate. One fixed-risk
position is held until the first tick in a later normalized broker month,
with a frozen ATR hard stop and a forty-day stale repair.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | raw first-bar execution window |
| `strategy_history_bars_d1` | 70 | bounded two-month history buffer |
| `strategy_min_month_sessions` | 17 | minimum closes in each month |
| `strategy_max_month_sessions` | 23 | maximum closes in each month |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | market-request deviation |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All inputs are locked for the single Q02 baseline. There is no optimization
surface.

## 3. Symbol Universe

- Exact host and traded symbol: `XTIUSD.DWX`, D1.
- Symbol slot: 0; registered magic: `411370000`.
- Signal clock: first raw D1 bar whose uniformly normalized date is in a new
  broker month and is no more than 180 elapsed minutes old.
- Formation: newest completed normalized month and its consecutive parent.
- Direction: strict sign of newest ordinary log-price median versus parent.
- State: one terminal global-variable month-attempt key derived from magic,
  reconciled with owned positions and same-magic entry deals on initialization.
- Hold: later normalized month, with a forty-calendar-day repair ceiling.

The implementation rejects non-midnight, future, colliding, weekend-ending,
mixed/non-uniform, current-month, non-adjacent, invalid-close, invalid-count,
and nonfinite-median packages. Seeing an older adjacent-month boundary proves
the parent sample was not truncated.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two immediately completed normalized broker-calendar months.
- Statistic: independent ordinary medians of all accepted daily log-price
  levels in each month.
- Decision: first executable D1 bar of the new normalized month.
- Hold: until the first tick in a later normalized month, with forty-day stale
  repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed WTI positions per full post-warm-up
  year; Q02 retires below five in any scored full year.
- Symmetric long/short direct-WTI structural continuation using robust price
  location rather than a month-end print.
- One fixed-risk position and one consumed attempt per broker month.
- The WTI carrier and signal are distinct from the certified XAU, SP500, NDX,
  and XNG sleeves; only Q09 may establish realized portfolio decorrelation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
10.1016/j.jfineco.2011.11.003.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MMEDIAN-SHIFT-MOM-2026/source.md`.

The peer-reviewed source supplies WTI membership, own-price monthly
continuation, symmetric side, and monthly holding lineage. The two within-
month daily log-price distributions, independent ordinary medians, and strict
location-shift translation are a disclosed QM hypothesis. No source return,
WTI-only efficacy, CFD equivalence, cost, density, or correlation result
transfers.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Sizing uses the V5 helper with a frozen completed-bar `3.5 * ATR(20,D1)` hard
stop. There is no take-profit, trail, break-even move, partial close, scale-in,
grid, martingale, or pyramid. Both news axes and Friday close are OFF.

Only one D1 backtest setfile exists. This build authorizes no manual backtest,
live/demo/shadow/stress/optimization setfile, AutoTrading, `T_Live`, deploy,
live manifest, portfolio-gate edit, portfolio admission, correlation waiver,
or decorrelation claim.

## Framework Alignment

- no_trade: exact symbol, period, ID, slot, fixed-risk mode, news, Friday,
  stress, seed, and every locked parameter.
- trade_entry: uniform label, durable attempt, exact adjacent-month samples,
  positive log prices, independent full sorts and ordinary medians, strict
  continuation side, spread, quote, ATR stop, and one fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-24 | approved source build | G0-approved card and governed magic 411370000 |
