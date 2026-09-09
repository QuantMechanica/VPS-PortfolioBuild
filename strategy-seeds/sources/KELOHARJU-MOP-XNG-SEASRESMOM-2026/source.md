---
source_id: KELOHARJU-MOP-XNG-SEASRESMOM-2026
title: XNG same-calendar standardized monthly-residual momentum
publisher: Journal of Finance / Journal of Financial Economics
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xng_seasonal_residual_momentum_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
created: 2026-09-09
created_by: Research+Development
strategy_ids:
  - KELOHARJU-MOP-XNG-SEASRESMOM-2026_S01
cards_extracted:
  - xng-seas-resid-mom
---

# XNG Seasonal-Residual Momentum Source Packet

## Approval And Complete-Read Scope

The durable approval is
`decisions/2026-09-09_xng_seasonal_residual_momentum_source_approval.md`.
It carries the OWNER commodity/energy sleeve mission and authorizes one
structural, low-frequency, non-live XNG card whose logic differs from
`QM5_12567`.

The following governed records were read completely before extraction:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` records the
   complete 57-page review of Keloharju, Linnainmaa, and Nyberg (2016),
   "Return Seasonalities," *Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. The commodity panel explicitly includes natural gas.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records the complete
   23-page published-paper review and durable retrieval hash for Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Natural
   gas is explicit in the commodity universe and the pooled commodity tests
   include one-month formation and one-month holding.
3. `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`
   was read only as an already-governed arithmetic, endpoint, and sample-
   exclusion precedent. Its contrarian evidence, strategy direction, and
   pipeline results do not transfer.

No blocked page, inaccessible table, inferred coefficient, secondary
summary, sibling backtest result, or unrecorded source is used.

## Findings Used And Claim Boundary

Keloharju, Linnainmaa, and Nyberg test recurring same-calendar-month returns
across a broad futures cross-section that includes natural gas and requires at
least five years of history. Their result is cross-sectional and does not
establish a standalone XNG forecast or continuation of a seasonal residual.

Moskowitz, Ooi, and Pedersen test the sign of an instrument's own past return
as a continuation signal across liquid futures. Their commodity universe
includes natural gas, and a pooled commodity test covers one-month formation
and holding. They do not report an XNG-only result and do not remove a
same-calendar expected return.

QM intersects the two information objects before seeing Q02 results: estimate
the recurring return of the just-completed calendar month from earlier years,
subtract it from the realized XNG monthly return, scale by historical sample
dispersion, and follow only a residual outside a fixed half-standard-deviation
band in the next broker month. This exact conjunction, XNG continuous-CFD
carrier, threshold, risk, stop, spread, and lifecycle are QM hypotheses, not
source claims.

No source or sibling profit factor, return, alpha, significance, drawdown,
trade count, transaction cost, CFD equivalence, or portfolio-correlation
statistic transfers.

## Bounded Mechanization

At the first executable `XNGUSD.DWX` D1 tick of broker month `M`, define the
just-completed month `J=M-1` with exact year rollover. Under one uniform raw or
`+1` calendar-day D1 label convention, reconstruct completed month-end closes
and calculate:

```text
realized_J = ln(XNG_end_J / XNG_end_(J-1))
```

For the same calendar month as `J`, scan the preceding ten years. Exclude
`realized_J`; accept at most one return per exact earlier year; skip missing
years without substituting a neighboring year; and require at least five
observations. For accepted returns `r_y`:

```text
seasonal_mean = sum(r_y) / n
seasonal_sd   = sqrt(sum((r_y-seasonal_mean)^2) / (n-1))
residual_z    = (realized_J-seasonal_mean) / seasonal_sd
```

Require finite positive `seasonal_sd`. At a strict
`residual_z > +0.50 + 1e-10`, buy `XNGUSD.DWX`. At a strict
`residual_z < -0.50 - 1e-10`, sell it. Equality and the interior band are
flat. Signal magnitude never changes risk.

Persist the current decision month before history, arithmetic, news, spread,
quote, ATR, sizing, or order gates. A blocked, invalid, rejected, stopped, or
failed month never retries. Use one `RISK_FIXED=1000` position with a frozen
`3.5*ATR(20,D1)` server stop and no target. Close at the next genuine broker-
month transition; repair malformed exposure immediately and enforce a
40-calendar-day stale guard.

Backtest `.DWX` history may model `Ask==Bid`. Entry therefore requires finite
positive Bid/Ask, rejects crossed quotes, admits exact zero modeled spread,
and caps nonnegative spread at 3,000 points. Both news axes, legacy news, and
Friday close are OFF. Runtime reads no external source data.

## Non-Duplicate Boundary

The canonical receipt found no exact registry or card collision and two
expected fuzzy siblings; the configured Strategy Wiki root was unavailable
and that limitation remains explicit.

- `QM5_41209_wti-seas-resid-mom` uses the same standardized estimator and
  continuation direction on WTI. The XNG carrier is fixed before results and
  no WTI evidence or performance transfers.
- `QM5_41208_xng-seas-surprise-rv` computes the same XNG standardized residual
  but fades it. This candidate follows it under the separate peer-reviewed
  own-return-continuation lineage. Direction is load-bearing.
- `QM5_20204_xng-tsmom1m` follows every nonzero completed-month XNG return.
  This candidate subtracts a historical same-calendar expectation, divides by
  sample dispersion, and stays flat inside a strict band.
- `QM5_20100_xng-samecal`, `QM5_41205_xng-samecal-huber10`, and
  `QM5_41225_xng-medcal` forecast the upcoming month from earlier same-calendar
  observations. They do not observe a standardized just-completed residual.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon oscillator
  pullback aligned to a slow moving average. This rule is symmetric, monthly,
  oscillator-free, and seasonally adjusted.

The just-completed XNG month, same-calendar expectation, realized-sample
exclusion, n-1 scaling, strict continuation band, and next-month lifecycle are
jointly load-bearing. Verdict:
`DISTINCT_XNG_STANDARDIZED_SEASONAL_RESIDUAL_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: two peer-reviewed
  lineages with complete-read records and explicit natural-gas membership;
  standalone XNG and exact-conjunction evidence are absent and disclosed.
- R2 `PASS`: month clock, labels, endpoints, exclusion, sample, arithmetic
  mean, n-1 scale, strict band, side, attempt, fixed risk, stop, spread,
  renewal, and repair are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XNGUSD.DWX` D1 history, broker time, quotes, metadata, positions, deals,
  and terminal-global state supply every runtime input.
- R4 `PASS`: native dates, completed prices, logarithms, sums, square root,
  comparisons, ATR risk plumbing, and execution state only; no banned signal,
  ML, external runtime feed, adaptive PnL fit, grid, martingale, scale-in, or
  pyramid.

## Falsification And Safety Boundary

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
wrong month mapping, current-month leakage, realized-sample leakage, wrong
denominator, wrong direction, duplicate attempt, missing hard stop, late
close, invalid fixed-risk mode, or nondeterminism. Changing the sample,
estimator, band, direction, carrier, risk, stop, spread, hold, or retry policy
requires a new identity.

This packet authorizes research, deterministic allocation, one branch-only V5
build, strict Q01, one fixed-risk D1 backtest setfile, and one paced non-live
Q02 handoff only while CPU remains below the hard ceiling. It authorizes no
manual backtest, live/demo/shadow/stress/optimization preset, terminal
control, AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
portfolio-gate change, or correlation waiver. Q09 alone may establish realized
book correlation.
