---
source_id: KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026
title: XNG same-calendar standardized monthly-surprise reversion
publisher: Journal of Finance / Economic Modelling
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_xng_seasonal_surprise_reversion_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MISHRA-SMYTH-XNG-PRED-2016
created: 2026-08-30
created_by: Research+Development
strategy_ids:
  - KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01
cards_extracted:
  - xng-seas-surprise-rv
---

# XNG Seasonal-Surprise Reversion Source Packet

## Approval And Complete-Read Scope

The durable source approval was committed before this extraction at
`c69176b43`:
`decisions/2026-08-30_xng_seasonal_surprise_reversion_source_approval.md`.
It carries the current explicit OWNER commodity/energy portfolio mission and
authorizes one structural, low-frequency, non-live XNG card only when its
mechanic differs from `QM5_12567`.

The following governed records were read completely before mechanization.
Their exact paths, byte counts, line counts, and SHA-256 hashes are preserved
in `artifacts/qm5_xng_seassurprise_rv_source_provenance_20260830.json`.

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` records the
   complete 57-page NBER review of Keloharju, Linnainmaa, and Nyberg (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. The commodity panel explicitly includes natural gas.
2. `strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md` records the
   complete 36-page author-manuscript review of Mishra and Smyth (2016), "Are
   Natural Gas Spot and Futures Prices Predictable?", *Economic Modelling*
   54, 178-186, DOI `10.1016/j.econmod.2015.12.034`.
3. `strategy-seeds/sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026/source.md`
   was read as a previously governed arithmetic precedent. Its gold/silver
   evidence, paired carrier, and any pipeline result are not source evidence
   for natural gas and do not transfer.

No blocked web page, inaccessible table, inferred coefficient, secondary
summary, sibling backtest result, or unrecorded source is used.

## Findings Used

Keloharju, Linnainmaa, and Nyberg test whether an asset's returns recur in the
same calendar month across years. Their commodity strategy ranks 24 futures,
including natural gas, from historical returns in that same calendar month,
requires at least five years of history, and holds the cross-sectional
portfolio for a month. The result is broad and cross-sectional. It does not
establish a standalone XNG forecast or a reversal of seasonal residuals.

Mishra and Smyth test fixed-frequency contrarian rules directly on Henry Hub
spot and one- through four-month natural-gas futures. At a chosen frequency,
their simulation buys after a price decline and sells after a price rise. They
report unusually strong two-month results but explicitly caution that those
may be sample- or strategy-specific. Their paper does not subtract a recurring
same-calendar expectation or test Darwinex continuous CFDs.

The bounded QM hypothesis intersects the two information objects without
claiming a replication: estimate the recurring return for the just-completed
calendar month from earlier years, subtract it from the realized XNG monthly
return, scale the residual by its historical sample dispersion, and fade only
an unusually large residual during the following broker month.

Neither paper specifies this conjunction, the ten-year cap, sample standard
deviation, half-standard-deviation band, energy-D1 label convention,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap, attempt
ledger, or lifecycle. Every such item is a transparent, pre-result QM
mechanization subject to Q02 falsification.

## Bounded Mechanization

At the first executable `XNGUSD.DWX` D1 tick of broker month `M`, define the
just-completed month `J=M-1` with exact year rollover. Under one uniform raw
or `+1` calendar-day label convention, reconstruct completed month-end closes
and calculate:

```text
realized_J = ln(XNG_end_J / XNG_end_(J-1))
```

For the same calendar month as `J`, scan the preceding ten years. Exclude
`realized_J`; accept at most one return per exact earlier year; skip missing
older years without substituting a neighboring year; and require at least
five observations. For accepted returns `r_y`:

```text
seasonal_mean = sum(r_y) / n
seasonal_sd   = sqrt(sum((r_y-seasonal_mean)^2) / (n-1))
surprise_z    = (realized_J-seasonal_mean) / seasonal_sd
```

Require finite positive `seasonal_sd`. At a strict
`surprise_z > +0.50 + 1e-10`, sell `XNGUSD.DWX`. At a strict
`surprise_z < -0.50 - 1e-10`, buy it. Equality and the interior band are flat.
The magnitude never changes risk.

Persist the current decision month before history, scale, news, spread,
quote, ATR, sizing, or order checks. A blocked, invalid, rejected, stopped, or
failed month never retries. Use one `RISK_FIXED=1000` position with a frozen
`3.5*ATR(20,D1)` server stop and no target. Close on the next genuine broker-
month transition; repair malformed exposure immediately and enforce a
40-calendar-day stale guard.

Backtest `.DWX` history may model `Ask==Bid`. Entry therefore requires finite
positive Bid/Ask, rejects crossed quotes, admits exact zero modeled spread,
and caps nonnegative spread at 3,000 points. This is execution reachability,
not alpha. Both news axes, legacy news, and Friday close are OFF.

## Non-Duplicate Boundary

The corrected-root canonical checker scanned 4,707 EA-registry identities,
1,353 card files, and 45 Strategy Wiki nodes. It returned `CLEAN` with no exact
or fuzzy match. Receipt:
`artifacts/qm5_xng_seassurprise_rv_preallocation_dedup_20260830.json`.

Manual signal/input/carrier/clock/lifecycle review fixes these boundaries:

- `QM5_12567_cum-rsi2-commodity` uses a two-day cumulative-RSI2 pullback,
  SMA200 alignment, long-only entry, and a maximum five-bar hold. This
  candidate is symmetric, monthly, oscillator-free, and seasonally adjusted.
- `QM5_20054_xng-1m-contr` fades every nonzero completed-month sign. This
  candidate first removes a same-calendar expectation, divides by historical
  scale, and consumes the month flat inside the strict band.
- `QM5_20100_xng-samecal` follows the raw historical mean for the *upcoming*
  calendar month. It never observes, standardizes, or fades the just-completed
  realized-minus-expected surprise.
- `QM5_41205_xng-samecal-huber10` follows a fixed-scale Huber location of ten
  historical returns for the *upcoming* calendar month. This candidate uses
  an arithmetic `n-1` surprise score around the just-completed month and
  trades in the opposite direction only outside a fixed band.
- `QM5_21517_xauxag-seas-rv` owns an atomic opposite-leg XAU/XAG basket and
  computes a relative metals surprise. This candidate owns only XNG and uses
  direct peer-reviewed natural-gas contrarian evidence; no metals position or
  relative return exists.

The just-completed XNG month, same-calendar historical expectation, realized-
sample exclusion, sample scaling, strict contrarian band, direct energy
carrier, and next-month lifecycle are jointly load-bearing. Replacing the
surprise with either parent state recreates an existing family. Verdict:
`CLEAN_XNG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: peer-reviewed
  *Journal of Finance* same-calendar evidence with explicit natural-gas
  membership plus peer-reviewed *Economic Modelling* natural-gas contrarian
  evidence; the conjunction is untested and adverse caveats remain binding.
- R2 `PASS`: exact clock, label rule, endpoints, exclusion, sample, mean,
  `n-1` scale, band, direction, attempt, risk, stop, spread, renewal, stale
  repair, and malformed-state repair are fixed mechanically.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XNGUSD.DWX` D1 history, broker time, quotes, contract metadata, positions,
  deals, and terminal-global state provide every runtime field; history,
  roll/basis, financing, fills, spread, and density remain Q02 risks.
- R4 `PASS`: native dates, completed OHLC, logarithms, arithmetic, square
  root, comparisons, ATR risk plumbing, and trade state only; no banned
  signal, trained output, adaptive fit, external feed, grid, martingale,
  scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

No source or sibling profit factor, return, significance, drawdown, cost,
trade count, threshold, continuous-CFD equivalence, correlation, or portfolio
result is imported. Ten-year same-calendar sampling, unstable dispersion,
XNG gaps and season changes, continuous-CFD rolls/financing, broker-label
mapping, sparse threshold crossings, and stop slippage are first-order risks.

Q02 must retire the unchanged identity on zero trades, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, wrong month mapping, realized-sample leakage, wrong denominator,
wrong side, repeated attempt, missing hard stop, late close, invalid fixed-risk
mode, or nondeterminism. It may not be rescued by changing the history,
sample floor, scale, threshold, side, carrier, stop, hold, spread, or retry
rule after results.

This packet authorizes research, deterministic allocation, one branch-only V5
build, strict compile/Q01, one `RISK_FIXED` D1 backtest setfile, and one paced
non-live Q02 handoff while CPU remains below the hard ceiling. It authorizes
no manual backtest, live/demo/shadow/stress/optimization preset, terminal
control, AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
portfolio-gate change, or correlation waiver. Q09 alone may establish realized
book correlation.
