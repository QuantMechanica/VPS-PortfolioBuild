---
source_id: KELOHARJU-YANG-WTI-SEASSURPRISE-2026
title: WTI same-calendar standardized monthly-surprise reversion
publisher: Journal of Finance / SSRN
source_type: peer_reviewed_and_academic_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_wti_seasonal_surprise_reversion_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
  - YANG-COMM-REVERSAL-2017
created: 2026-09-09
created_by: Research+Development
strategy_ids:
  - KELOHARJU-YANG-WTI-SEASSURPRISE-2026_S01
cards_extracted:
  - wti-seas-surprise-rv
---

# WTI Seasonal-Surprise Reversion Source Packet

## Approval And Complete-Read Scope

The durable source approval is
`decisions/2026-09-09_wti_seasonal_surprise_reversion_source_approval.md`,
committed before this extraction as `28e093d625`. It carries the explicit
OWNER commodity/energy sleeve mission and authorizes one structural,
low-frequency, non-live WTI card and build.

The following governed records were read completely before mechanization:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` records the
   complete 57-page open NBER version of Keloharju, Linnainmaa, and Nyberg
   (2016), "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. Crude oil is explicit in its commodity panel.
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` is the governed
   academic commodity-reversal lineage for Yang, Goncu, and Pantelous,
   "Momentum and Reversal in Commodity Futures," SSRN 3069253. Its status and
   non-peer-reviewed publication boundary are preserved.
3. `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`
   was read only as the governed estimator/lifecycle precedent. Its natural-
   gas evidence and any sibling pipeline result do not transfer to WTI.

No inaccessible page, secondary summary, sibling result, or inferred
coefficient is used.

## Findings Used And Translation Boundary

Keloharju, Linnainmaa, and Nyberg test recurring same-calendar-month returns
across 24 commodity futures, explicitly including crude oil, with at least
five years of history. Their result is broad and cross-sectional; it does not
establish a standalone WTI forecast or residual-reversal rule.

Yang, Goncu, and Pantelous provide a named-author academic lineage for fixed-
horizon commodity winner/loser reversal. The governed packet includes direct
WTI reversal extractions, but does not establish this residual estimator or a
standalone result at the chosen one-month horizon.

The bounded QM hypothesis intersects the two information objects: remove the
historical expectation for the just-completed calendar month from WTI's
realized monthly return, standardize by that historical sample dispersion,
and fade only a large residual during the following broker month.

Neither source specifies the ten-year cap, `n-1` scale, half-standard-
deviation band, energy-D1 label convention, Darwinex continuous CFD, fixed-
risk budget, ATR stop, spread cap, attempt ledger, or lifecycle. These are
transparent pre-result choices. No source or sibling performance, density,
cost, CFD-equivalence, decorrelation, or portfolio result transfers.

## Bounded Mechanization

At the first executable `XTIUSD.DWX` D1 tick of broker month `M`, define the
just-completed month `J=M-1`. Under one uniform raw or `+1` day label
convention, reconstruct completed month-end closes and calculate:

```text
realized_J = ln(WTI_end_J / WTI_end_(J-1))
```

For the same calendar month as `J`, scan the preceding ten years. Exclude the
realized year; accept at most one return per exact earlier year; skip a
missing year without substitution; and require at least five observations.
For accepted returns `r_y`:

```text
seasonal_mean = sum(r_y) / n
seasonal_sd   = sqrt(sum((r_y-seasonal_mean)^2) / (n-1))
surprise_z    = (realized_J-seasonal_mean) / seasonal_sd
```

Require finite positive scale. At `surprise_z > +0.50+1e-10`, sell WTI. At
`surprise_z < -0.50-1e-10`, buy WTI. Equality and the interior band are flat;
score magnitude never changes risk.

Persist the decision month before history, signal, news, spread, quote, ATR,
sizing, margin, or order checks. A blocked, invalid, rejected, stopped, or
failed month never retries. Use one `RISK_FIXED=1000` position with a frozen
`3.5*ATR(20,D1)` server stop and no target. Close at the next genuine broker-
month transition; repair malformed exposure immediately and use 40 calendar
days only as stale repair.

Entry requires finite positive Bid/Ask, rejects crossed quotes, admits exact
zero modeled spread, and caps nonnegative spread at 1,500 points. Both news
axes, legacy news, and Friday close are OFF in the backtest preset but are not
equality-pinned by the EA.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_wti_seas_surprise_rv_preallocation_dedup_20260909.json`
scanned 4,877 registry identities and 1,489 cards. The configured Strategy
Wiki root was unavailable. It found no exact collision and raised the
expected fuzzy family members:

- `QM5_41208_xng-seas-surprise-rv` uses the same estimator and contrarian
  side on XNG; it never reads or trades WTI.
- `QM5_41209_wti-seas-resid-mom` uses the same WTI estimator but follows the
  residual; direction is the load-bearing opposite.
- `QM5_41393_xng-seas-resid-mom` uses both the other carrier and the opposite
  direction.
- `QM5_20137_wti-seas-pb` follows the upcoming-month historical seasonal
  sign only after an opposite raw prior-month return. It does not subtract
  the just-completed month's own same-calendar expectation or standardize the
  residual.
- `QM5_20054_wti-1m-contr` fades every nonzero completed-month return with no
  seasonal subtraction, historical scale, or flat band.
- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI pullback above a
  slow trend with a five-bar maximum hold.

The direct WTI carrier, standardized just-completed-minus-same-calendar
residual, realized-sample exclusion, strict half-sigma band, contrarian side,
and next-month lifecycle are jointly load-bearing. Verdict:
`DISTINCT_WTI_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_ACADEMIC_SUPPLEMENT_CONJUNCTION_AND_CFD_RISK`: the complete-
  read peer-reviewed Journal of Finance source supplies the same-calendar
  information object and explicit crude-oil membership; the named-author
  academic reversal source supplies only broad reversal lineage. The exact
  conjunction remains untested.
- R2 `PASS`: exact month clock, label rule, endpoints, exclusion, bounded
  sample, mean, `n-1` scale, band, direction, attempt, fixed risk, stop,
  spread, renewal, stale repair, and malformed-state repair are locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XTIUSD.DWX` D1 history, broker time, quotes, metadata, positions, deals,
  and terminal-global state provide every runtime field.
- R4 `PASS`: deterministic dates, completed OHLC, logarithms, arithmetic,
  square root, comparisons, ATR risk plumbing, and trade state only; no
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Claim, Kill, And Safety Boundary

Ten-year same-calendar sampling, unstable dispersion, WTI gaps, continuous-
CFD rolls/financing, broker-label mapping, sparse threshold crossings, and
stop slippage are first-order risks. Q02 must retire the unchanged identity
on zero trades, fewer than five completed positions in any full post-warm-up
year, nonpositive governed economics, or any clock, endpoint, sample, scale,
side, attempt, risk, stop, spread, lifecycle, or determinism defect.

No failure may be rescued by changing history, sample floor, scale,
threshold, side, carrier, stop, hold, spread, or retry rules. This packet
authorizes research, deterministic allocation, one branch-only V5 build,
strict Q01, one `RISK_FIXED` D1 backtest setfile, and one paced non-live Q02
enqueue below the CPU ceiling. It authorizes no manual backtest, live/demo/
shadow/stress/optimization preset, terminal control, AutoTrading, `T_Live`,
deploy or live manifest, portfolio admission, portfolio-gate change, or
correlation waiver. Q09 alone may establish realized book correlation.
