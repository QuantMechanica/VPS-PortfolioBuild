# WTI completed-month median-location shift momentum - Source Approval

Date: 2026-08-24

Decision: `APPROVED_SOURCE`

## Authority and bounded scope

The current explicit OWNER instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency
commodity/energy edge outside the certified XAU/SP500/NDX/XNG book. It
explicitly permits a WTI trend or seasonality carrier, requires a
reputable-source QM card, a branch-only V5 build, `RISK_FIXED` backtest
configuration, committed non-duplicate work, and one paced Q02 enqueue. It
forbids `T_Live`, AutoTrading, portfolio-gate, and T_Live-manifest changes.

This decision approves bounded source intake for:

- proposed source ID: `MOP-WTI-MMEDIAN-SHIFT-MOM-2026`
- proposed strategy ID: `MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01`
- proposed EA identity: `QM5_41137`
- proposed slug: `wti-mmedian-shift-mom`
- instrument: exact `XTIUSD.DWX`
- decision period: D1, evaluated once on the first executable bar of a new
  normalized broker-calendar month

This is source approval only. It permits one bounded source packet and one
Strategy Card for G0 consideration. It does not itself approve a build,
backtest result, portfolio admission, or live use.

## Complete governed source read

The bounded parent record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read completely before
this decision. Its SHA-256 is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
The record covers Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen
(2012), "Time Series Momentum," *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The parent preserves an end-to-end read of the 23-page published paper, the
author-faculty-site retrieval receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json`, and
published-PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The paper tests each instrument's own return at monthly lags, maps past-return
sign to a symmetric next-period direction, reports a pooled commodity
`k=1,h=1` implementation, and explicitly includes NYMEX WTI crude.

The source supports testing a direct-WTI monthly continuation carrier. It
does not test two non-overlapping samples of daily log-price levels, ordinary
sample medians, strict migration of those medians, a Darwinex continuous CFD,
fixed-dollar ATR risk, a spread ceiling, restart persistence, or the QM
portfolio. Those are disclosed QM translations. No source alpha, return,
probability, density, profit factor, Sharpe ratio, drawdown, trade count,
transaction cost, WTI-only efficacy, CFD equivalence, neutrality, or
portfolio-correlation result transfers.

## Approved deterministic extraction

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month:

1. Exclude every current-month observation. Reconstruct the immediately
   completed calendar month and its consecutive parent month from completed
   D1 closes under one uniform raw or `+1` calendar-day energy-label rule.
2. Require exact month adjacency, 17 through 23 unique strictly ordered
   sessions in each month, and positive finite closes. Any missing, duplicate,
   mixed-label, out-of-order, nonpositive, or nonfinite state consumes the
   decision month flat.
3. Transform each accepted close independently to its natural logarithm.
   Sort each month's log-price sample ascending without rounding. For an odd
   count select index `n/2`; for an even count average only indexes `n/2-1`
   and `n/2`. Reject invalid indexes or nonfinite arithmetic.
4. If the newest completed-month median is strictly above the parent-month
   median, BUY WTI. If it is strictly below, SELL WTI. Equality stays flat.
   The displacement magnitude never changes risk.
5. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. No failure, stop,
   rejection, or restart may retry that month.
6. Permit at most one owned WTI position. Use `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry-spread
   ceiling.
7. Close on the first tick carrying a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF so the position owns the complete
monthly package. No current-month confirmation, endpoint-return gate, range
gate, moving average, oscillator, seasonal condition, event input, external
feed, trained output, fitted parameter, scale-in, grid, martingale, pyramid,
target, trail, break-even move, partial close, or opposite-signal exit is
permitted.

## Reputable-source criteria

- R1: `PASS_WITH_MONTHLY_MEDIAN_LOCATION_TRANSLATION_RISK`. Named authors, a
  peer-reviewed JFE paper with DOI, complete-paper evidence, a durable PDF
  hash, and explicit WTI membership support the structural direct-WTI monthly
  trend carrier. The exact two-sample median-location proxy is explicitly
  untested.
- R2: `PASS`. Clock, label normalization, exact adjacent months, session
  limits, log-price transform, independent sort, odd/even median formula,
  strict comparison, direction, equality handling, consumed attempt, risk,
  stop, spread, and lifecycle are fixed before any candidate result.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history plus native MT5 calendar and execution state supply
  every runtime input. Q02 owns label, history, density, fill, cost, and CFD-
  basis sufficiency.
- R4: `PASS`. Deterministic timestamps, logarithms, sorting, arithmetic,
  comparison, ATR, and execution state only; no trained output, prohibited
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-duplicate boundary

The fail-closed canonical checker evidence is
`artifacts/qm5_wti_mmedian_shift_mom_preallocation_dedup_20260824.json`. It
returned `CLEAN` after binding 4,636 registry identities, 1,304 repository
cards, and 45 Strategy Wiki nodes from the current Company Reference root.
No exact or fuzzy identity was found.

Manual mechanic review fixes the nearest-family boundaries:

- `QM5_20187_wti-tsmom1m` follows one unpartitioned close-to-close completed-
  month endpoint. This extraction uses every valid daily close in two months,
  discards endpoints as signal objects, and compares robust locations.
- `QM5_41102_wti-mrange-migrate-mom` requires strict same-direction migration
  of both aggregate monthly highs and lows. This extraction ignores every
  high/low and compares only independently sorted close medians.
- `QM5_41133_wti-mdaily-median-mom` takes the ordinary median of 17-23 daily
  *returns inside one month*. This extraction takes one median of daily
  *log-price levels in each of two months* and follows their cross-month
  location shift; no daily return is a signal input.
- `QM5_20269_wti-medret-mom` takes a median across twelve disjoint monthly
  returns. This extraction compares two non-overlapping within-month daily
  price-level distributions.
- `QM5_41055_wti-med-calendar` uses same-calendar historical seasonality.
  This extraction has no year-of-history or calendar-season comparison.
- `QM5_41104_xauxag-mmedian-shift-rv` trades two metals, measures a unit-log
  ratio, and fades its shift with an equal-notional package. This extraction
  owns one outright WTI position and follows the shift.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, two-day XNG
  oscillator pullback above a slow trend filter.

The exact WTI carrier, two consecutive completed broker months, 17-23 daily
closes in each, independent log-price ordinary medians, strict newest-minus-
parent comparison, continuation side, durable monthly attempt, fixed risk,
and next-month lifecycle are jointly load bearing. Manual verdict:
`CLEAN_WTI_TWO_COMPLETED_MONTH_DAILY_LOG_PRICE_MEDIAN_LOCATION_SHIFT_MOMENTUM`.

## Claim, kill, and safety boundary

Every valid strict median displacement can qualify, so the pre-result density
prior is near twelve decisions per year. This is not market evidence. Q02
must retire the candidate below five completed positions in any full post-
warm-up year, at zero trades, with nonpositive governed economics, or on any
label, month, sort, median, side, attempt, risk, lifecycle, or determinism
defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG carriers, but that does not prove low realized
correlation. Q09 alone owns the portfolio result. No failure may be rescued by
changing either sample, median formula, direction, carrier, risk, hold, or by
adding endpoint agreement, range, weekday, seasonal, event, volatility,
external, or prior-result state.

This approval authorizes one bounded source packet and one Strategy Card for
G0 consideration. It does not authorize a manual backtest, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
start/stop, or a second queue row.
