---
source_id: KELOHARJU-MOP-WTI-SEASRESMOM-2026
title: WTI same-calendar standardized monthly-residual momentum
publisher: Journal of Finance / Journal of Financial Economics
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-30_wti_seasonal_residual_momentum_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - MOP-TSMOM-2012
created: 2026-08-30
created_by: Research+Development
strategy_ids:
  - KELOHARJU-MOP-WTI-SEASRESMOM-2026_S01
cards_extracted:
  - wti-seas-resid-mom
---

# WTI Seasonal-Residual Momentum Source Packet

## Approval And Complete-Read Scope

The durable source approval was committed before this extraction at
`a19955cc0`:
`decisions/2026-08-30_wti_seasonal_residual_momentum_source_approval.md`.
It carries the current explicit OWNER commodity/energy portfolio mission and
authorizes one structural, low-frequency, non-live WTI trend/seasonality card.

The following governed records were read completely before mechanization.
Their exact paths, byte counts, line counts, and SHA-256 hashes are preserved
in `artifacts/qm5_wti_seas_resid_mom_source_provenance_20260830.json`.

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` records the
   complete 57-page NBER review of Keloharju, Linnainmaa, and Nyberg (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. The commodity panel explicitly includes crude oil.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records the complete
   23-page published-paper review of Moskowitz, Ooi, and Pedersen (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. WTI is explicit, and the source tests
   one-month formation / one-month holding in its pooled commodity panel.
3. `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`
   was read only as a governed arithmetic and realized-sample-exclusion
   precedent. Its natural-gas evidence, contrarian direction, carrier, and
   pipeline results are not WTI evidence and do not transfer.

No blocked web page, inaccessible table, inferred coefficient, secondary
summary, sibling backtest result, or unrecorded source is used.

## Findings Used

Keloharju, Linnainmaa, and Nyberg test whether returns recur in the same
calendar month across years. Their commodity strategy ranks 24 futures,
including crude oil, from historical returns in that same calendar month,
requires at least five years of history, and holds the cross-sectional
portfolio for a month. The result is broad and cross-sectional. It does not
establish a standalone WTI forecast or the continuation of a seasonally
adjusted residual.

Moskowitz, Ooi, and Pedersen test own-return continuation across liquid
futures. Their pooled commodity results explicitly include a one-month
formation / one-month hold rule, and Appendix A includes NYMEX WTI. The paper
does not report a WTI-only one-month result and does not remove a recurring
same-calendar expectation.

The bounded QM hypothesis intersects the two information objects without
claiming a replication: estimate the recurring return for the just-completed
calendar month from earlier years, subtract it from the realized WTI monthly
return, scale the residual by its historical sample dispersion, and follow
only an unusually large residual during the following broker month.

Neither paper specifies this conjunction, the ten-year cap, sample standard
deviation, half-standard-deviation band, energy-D1 label convention,
continuous-CFD carrier, fixed-risk budget, ATR stop, spread cap, attempt
ledger, or lifecycle. Every such item is a transparent, pre-result QM
mechanization subject to Q02 falsification.

## Bounded Mechanization

At the first executable `XTIUSD.DWX` D1 tick of broker month `M`, define the
just-completed month `J=M-1` with exact year rollover. Under one uniform raw
or `+1` calendar-day label convention, reconstruct completed month-end closes
and calculate:

```text
realized_J = ln(WTI_end_J / WTI_end_(J-1))
```

For the same calendar month as `J`, scan the preceding ten years. Exclude
`realized_J`; accept at most one return per exact earlier year; skip missing
older years without substituting a neighboring year; and require at least
five observations. For accepted returns `r_y`:

```text
seasonal_mean = sum(r_y) / n
seasonal_sd   = sqrt(sum((r_y-seasonal_mean)^2) / (n-1))
residual_z    = (realized_J-seasonal_mean) / seasonal_sd
```

Require finite positive `seasonal_sd`. At a strict
`residual_z > +0.50 + 1e-10`, buy `XTIUSD.DWX`. At a strict
`residual_z < -0.50 - 1e-10`, sell it. Equality and the interior band are
flat. The magnitude never changes risk.

Persist the current decision month before history, scale, news, spread,
quote, ATR, sizing, or order checks. A blocked, invalid, rejected, stopped, or
failed month never retries. Use one `RISK_FIXED=1000` position with a frozen
`3.5*ATR(20,D1)` server stop and no target. Close on the next genuine broker-
month transition; repair malformed exposure immediately and enforce a
40-calendar-day stale guard.

Backtest `.DWX` history may model `Ask==Bid`. Entry therefore requires finite
positive Bid/Ask, rejects crossed quotes, admits exact zero modeled spread,
and caps nonnegative spread at 1,500 points. This is execution reachability,
not alpha. Both news axes, legacy news, and Friday close are OFF.

## Non-Duplicate Boundary

The corrected-root canonical checker scanned 4,708 EA-registry identities,
1,354 card files, and 45 Strategy Wiki nodes. It returned `CLEAN` with no
exact or fuzzy match. Receipt:
`artifacts/qm5_wti_seas_resid_mom_preallocation_dedup_20260830.json`.

Manual signal/input/carrier/clock/lifecycle review fixes these boundaries:

- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month WTI return.
  This candidate removes that month's historical expectation, scales the
  residual, and remains flat inside a strict band.
- `QM5_20099_wti-samecal` follows the historical mean for the upcoming
  calendar month. This candidate never predicts the upcoming seasonal sign;
  it observes and follows only the just-completed month's unexpected part.
- `QM5_20205_wti-calmom1` requires the upcoming-month same-calendar sign and
  raw immediately completed return sign to agree. This candidate instead
  forms one standardized realized-minus-expected prior-month residual.
- `QM5_20229_wti-seas-rev1` uses a fixed winter/summer direction after an
  opposing raw prior month. This candidate has no fixed seasonal partition
  and follows rather than reverses its residual.
- `QM5_41208_xng-seas-surprise-rv` computes analogous arithmetic on natural
  gas and trades the opposite direction. This candidate owns WTI and tests
  continuation under WTI-specific peer-reviewed momentum evidence.
- `QM5_21517_xauxag-seas-rv` owns an atomic opposite-leg metals basket and
  fades its relative surprise. This candidate owns one directional WTI leg.

The just-completed WTI month, same-calendar historical expectation, realized-
sample exclusion, sample scaling, strict continuation band, direct crude-oil
carrier, and next-month lifecycle are jointly load-bearing. Replacing the
residual with either parent state recreates an existing family. Verdict:
`CLEAN_WTI_STANDARDIZED_SEASONAL_RESIDUAL_MOMENTUM_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: peer-reviewed
  *Journal of Finance* same-calendar evidence with explicit crude-oil
  membership plus peer-reviewed *Journal of Financial Economics* own-return
  continuation evidence with explicit WTI membership; the conjunction is
  untested and pooled-result limits remain binding.
- R2 `PASS`: exact clock, label rule, endpoints, exclusion, sample, mean,
  `n-1` scale, band, direction, attempt, risk, stop, spread, renewal, stale
  repair, and malformed-state repair are fixed mechanically.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XTIUSD.DWX` D1 history, broker time, quotes, contract metadata, positions,
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
WTI gaps and regime changes, continuous-CFD rolls/financing, broker-label
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
