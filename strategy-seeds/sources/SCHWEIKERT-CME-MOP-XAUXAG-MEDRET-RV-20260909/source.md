---
source_id: SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909
title: XAU/XAG ordinary monthly return-median reversion
publisher: Journal of Banking & Finance / CME Group / Journal of Financial Economics
source_type: peer_reviewed_exchange_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xauxag_monthly_median_return_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-TSMOM-2012
created: 2026-09-09
created_by: Research+Development
strategy_ids:
  - SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909_S01
cards_extracted:
  - xauxag-medret-rv
---

# XAU/XAG Ordinary Monthly Return-Median Reversion Source Packet

## Approval And Complete-Read Scope

The durable source approval is
`decisions/2026-09-09_xauxag_monthly_median_return_reversion_source_approval.md`.
It carries the explicit OWNER commodity/energy sleeve mission and authorizes
one structural, low-frequency, non-live market-neutral-style XAU/XAG card and
build.

The following governed records were read completely before mechanization:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md` preserves
   the peer-reviewed gold/silver cointegration evidence and its important
   state-dependence warning.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md` preserves CME's
   ratio definition, opposed-leg spread construction, and differentiated
   monetary versus industrial drivers.
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md` preserves the complete-
   paper read, author-hosted retrieval hash, monthly lag tests, and commodity
   universe of Moskowitz, Ooi, and Pedersen (2012).
4. `strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md` was read only as
   a governed arithmetic and lifecycle precedent. Its WTI carrier, block
   aggregation, continuation direction, and any pipeline result do not
   transfer.

No inaccessible page, secondary summary, sibling result, or inferred
coefficient is used.

## Findings Used And Translation Boundary

Schweikert supplies peer-reviewed evidence of a long-run but state-dependent
gold/silver relation. CME defines the gold/silver ratio and documents how an
opposed-leg spread expresses relative rather than outright-metal movement.
Moskowitz, Ooi, and Pedersen establish that completed monthly commodity
returns can contain directional information, but their source strategy is
continuation and does not use the ordinary sample median.

The QM hypothesis changes the information object to the central sign across
twelve individual monthly changes in the gold/silver log ratio, then takes a
contrarian opposed-leg package. The ordinary median, contrarian side, equal-
notional implementation, Darwinex continuous CFDs, aggregate fixed risk, ATR
stops, spread caps, attempt ledger, and lifecycle are transparent pre-result
choices. No source return, alpha, Sharpe ratio, trade count, cost, neutrality,
CFD equivalence, or portfolio correlation transfers.

## Bounded Mechanization

At the first executable `XAUUSD.DWX` D1 tick of broker month `M`, reconstruct
exactly thirteen immediately prior consecutive broker-month endpoints shared
by XAU and XAG. For positive finite closes `G[0..12]` and `S[0..12]`, oldest
first:

```text
q[i] = ln(G[i]/S[i]), i=0..12
r[i] = q[i+1]-q[i], i=0..11
s = ascending sort of all twelve individual r values
m = (s[5]+s[6])/2
```

If `m>+1e-12`, sell XAU and buy XAG. If `m<-1e-12`, buy XAU and sell XAG.
The epsilon interior consumes the month flat. Signal magnitude never scales
risk.

Persist `M` before history, signal, news, spread, quotes, ATR, sizing, margin,
or order checks. Use equal target absolute USD notionals within 20%, one
aggregate `RISK_FIXED=1000` budget divided across frozen
`3.5*ATR(20,D1)` hard stops, and no target. The package is atomic: if the
second leg fails, flatten the first. Close both at the next genuine broker-
month transition; 40 days is stale repair only. Cap modeled spread at 1,500
XAU points and 500 XAG points while admitting exact zero.

## Non-Duplicate Boundary

The canonical receipt
`artifacts/qm5_xauxag_medret_rv_preallocation_dedup_20260909.json` scanned
4,879 registry identities and 1,490 cards. Its unavailable configured Wiki
root is explicit. It found no exact collision and raised three expected fuzzy
neighbors:

- `QM5_41389_xauxag-blockmed-rv` compresses twelve changes into four fixed
  chronological three-change means, sorts only the four means, and averages
  their center two. This candidate sorts all twelve individual changes and
  averages indexes five and six; fixed fixtures must show disagreement.
- `QM5_41356_xauxag-mwinsor2-rv` clips the two smallest and two largest
  changes to inner boundary values, then averages all twelve. This candidate
  retains only the two central order statistics.
- `QM5_41357_xtixng-mwinsor2-rv` also differs in both functional and carrier.

Manual family review separates `QM5_20263` (current ratio level relative to a
rolling median/MAD), `QM5_41104` (old-six versus recent-six median shift), and
`QM5_20269` (ordinary median of WTI monthly returns, continuation, one leg).
The raw twelve-return order statistic, XAU/XAG ratio-change carrier,
contrarian direction, equal-notional opposed legs, aggregate risk, and atomic
monthly lifecycle are jointly load-bearing. Verdict:
`DISTINCT_XAUXAG_ORDINARY_MONTHLY_RETURN_MEDIAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MEDIAN_DIRECTION_AND_CFD_TRANSLATION_RISK`: named peer-
  reviewed relationship and monthly-return sources plus official exchange
  construction support a bounded test; no exact-conjunction result exists.
- R2 `PASS`: endpoint count/order, synchronization, ratio orientation,
  adjacent changes, full sort, even-median indexes, epsilon, side, attempt,
  equal notional, aggregate risk, hard stops, atomicity, rollover, and stale
  repair are exact.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_RISK`: registered native
  XAU/XAG D1 history plus broker time, quotes, metadata, positions, deals, and
  persistent state supply every runtime input.
- R4 `PASS`: logarithm, sorting, arithmetic, ATR risk controls, and execution
  state only; no trained output, prohibited signal, external feed, grid,
  martingale, scale-in, or pyramid.

## Claim, Kill, And Safety Boundary

Q02 must retire the unchanged identity on zero trades, fewer than five
completed packages in any full post-warm-up year, nonpositive governed
economics, or any clock, synchronization, endpoint, sort, median, side,
attempt, notional, risk, stop, spread, atomicity, lifecycle, or determinism
defect. No failure may be rescued by changing horizon, statistic, epsilon,
direction, carrier, stop, hold, spread, mismatch, or retry rules.

This packet authorizes research, deterministic allocation, one branch-only V5
build, strict Q01, one `RISK_FIXED` logical-basket backtest preset, and one
paced non-live Q02 enqueue below the CPU ceiling. It authorizes no manual
backtest, live/demo/shadow/stress/optimization preset, terminal control,
AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
portfolio-gate change, correlation waiver, or claim of decorrelation.
