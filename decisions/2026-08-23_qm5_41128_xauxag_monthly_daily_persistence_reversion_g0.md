# QM5_41128 XAU/XAG Completed-Month Daily-Persistence Reversion - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41128_xauxag-mdaily-persist-rv_card.md`

Source approval:
`decisions/2026-08-23_xauxag_monthly_daily_persistence_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41128`
- slug: `xauxag-mdaily-persist-rv`
- strategy ID:
  `SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026_S01`
- source ID: `SCHWEIKERT-MEHLITZ-CME-XAUXAG-MDAILY-PERSIST-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0, magic `411280000`
- companion: `XAGUSD.DWX`, D1, slot 1, magic `411280001`
- logical symbol: `QM5_41128_XAU_XAG_MDAILY_PERSIST_RV_D1`

The deterministic registry reserved `41128` before this decision. Magic
allocation must follow the governed directory-first sequence before
implementation and compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable Track-Record Basis

`PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`.

The bounded source preserves a peer-reviewed gold/silver relation paper with
DOI, official CME intermarket-spread research, and a peer-reviewed commodity-
memory paper with complete-read evidence and durable hashes. The within-month
daily relative-return score, fixed correction on that relative path, and
contrarian direction are explicit pre-result QM translations. No performance,
density, cost, CFD-equivalence, hedge-ratio, neutrality, or correlation result
transfers.

### R2 - Mechanical Completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; an exact
17-to-23-session immediately completed synchronized month; one adjacent older
boundary pair; chronological relative returns ending on every completed-month
session; endpoint sum `N`; mean `mu`; squared-deviation sum `S`; adjacent-
product sum `A`; lag-one `rho=A/S`; fixed `J=rho+1/(n-1)`; strict `J>0`;
contrarian sides; consumed monthly attempt; aggregate fixed risk; equal
notionals; frozen ATR stops; spread caps; atomic repair; first-later-month
exit; and forty-day stale closure. There is no optimization surface or
fallback signal.

### R3 - Runtime Data Availability

`PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.

Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history, MT5 symbol
metadata, quotes, spreads, ATR, position/deal state, broker time, and terminal-
global attempt state supply every input. No futures chain or external dataset
is required. Q02 owns history sufficiency, costs, fills, financing, density,
calendar overlap, gaps, and continuous-CFD basis.

### R4 - ML And Prohibited-Mechanic Ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, addition,
multiplication, division, comparisons, ATR risk distance, quotes, positions,
deals, and persistent terminal state. It contains no trained or adaptive
output, banned signal, external runtime feed, grid, martingale, pyramid,
scale-in, or result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,627 registry identities,
1,296 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mdaily_persist_rv_preallocation_dedup_20260823.json`.

After reservation, the checker found only the two exact expected self-hits for
reserved `QM5_41128` in
`artifacts/qm5_41128_xauxag_mdaily_persist_rv_postallocation_dedup_20260823.json`.

Manual review separates rolling ratio/OLS/MAD center and crossing systems;
the 32-month relative variance-ratio state in `QM5_20249`; sign breadth and
fixed-block cards; ordered-state `QM5_41121`; L1 path efficiency in
`QM5_41123`; L2 mean-to-RMS coherence in `QM5_41125`; and the outright WTI
continuation carrier in `QM5_41127`. This card alone centers one completed
month of synchronized daily gold-minus-silver returns, multiplies every
adjacent pair, applies the fixed short-sample shift, and fades the endpoint
only when the corrected score is strictly positive. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_PERSISTENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, EA `41128`, slots
   0/1, magics `411280000`/`411280001`.
2. One decision attempt on the first synchronized executable bar of each new
   broker month, within 180 minutes of the raw host D1 bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized close pairs, plus one adjacent older pair proving the left
   boundary.
4. Chronological relative log returns from the older pair into every month-
   session pair; compute `N`, `mu`, `S`, `A`, `rho`, and `J`; require endpoint
   identity, finite arithmetic, `S>0`, bounded `rho`, and strict `J>0`.
5. Positive `N`: SELL XAU and BUY XAG. Negative `N`: BUY XAU and SELL XAG.
   Zero variance, zero net, `J<=0`, endpoint mismatch, and malformed states
   consume the month flat.
6. One equal-target-notional opposite-leg package, aggregate
   `RISK_FIXED=1000`, no more than 20% realized notional mismatch, frozen
   `3.5*ATR(20,D1)` hard stops on both legs, no target or score-strength
   sizing, and spread ceilings of 1,500 XAU / 500 XAG points.
7. Submit atomically with immediate cleanup after a second-leg failure;
   flatten orphaned, duplicated, same-side, stopless, wrong-magic, or
   notional-invalid exposure.
8. Close both legs at the first later broker-month tick, with a forty-day stale
   guard; no retry, add, rebalance, trail, partial close, grid, martingale, or
   pyramid.
9. Both news axes and Friday close OFF. Framework kill switch and ownership
   repair remain authoritative.

## Falsification Boundary

The fixed positive-score gate has a design prior of roughly six decisions per
year. This is not market evidence. Q02 retires at zero packages, below five
completed packages in any full scored post-warm-up year, nonpositive governed
economics, or any synchronization, boundary, orientation, centering,
arithmetic, correction, threshold, side, attempt, risk, atomicity, lifecycle,
or determinism defect.

A weak result may not be rescued by changing the correction, threshold,
direction, return inclusion, session bounds, hold, risk, or carrier, or by
adding a center, scale, sign count, block vote, sequence, range location,
seasonality, event, external, or prior-result state.

Opposite equal-notional legs are a market-neutral design, not a neutrality or
decorrelation finding. Unchanged Q09 alone owns the realized portfolio
decision.

## Approval Scope And Safety

`g0_status: APPROVED` and `execution_contract_status: APPROVED` authorize the
card-aligned branch-only EA source, governed magic rows, strict compile/Q01,
one logical `RISK_FIXED` backtest setfile, deterministic reference tests, and
one paced Q02 enqueue if the fresh resource ceiling permits.

This decision does not authorize a manual tester run, demo/shadow/live/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, or live use. Q09 alone may establish realized portfolio
correlation.
