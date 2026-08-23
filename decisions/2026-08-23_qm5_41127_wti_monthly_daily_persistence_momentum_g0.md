# QM5_41127 WTI Completed-Month Daily-Persistence Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41127_wti-mdaily-persist-mom_card.md`

Source approval:
`decisions/2026-08-23_wti_monthly_daily_persistence_momentum_source_approval.md`

Source packet:
`strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41127`
- slug: `wti-mdaily-persist-mom`
- strategy ID: `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026_S01`
- source ID: `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026`
- symbol: `XTIUSD.DWX`, D1, slot 0
- magic: `411270000`

The deterministic registry reserved `41127` in
`framework/registry/ea_id_registry.csv` before this decision. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_WITHIN_MONTH_PERSISTENCE_TRANSLATION_RISK`.

The bounded source preserves two peer-reviewed papers with named authors,
DOIs, complete-read evidence, durable hashes, explicit WTI membership, own-
return continuation, a monthly formation/hold clock, and return-
autocorrelation lineage. Neither paper tests a one-month daily-return sample,
the fixed `1/(n-1)` short-sample neutralization, or persistence-only endpoint
continuation. Those elements are explicit pre-result QM translations. No
performance, density, cost, CFD-equivalence, or correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbol and D1 period; first-new-month timing; an exact
17-to-23-session immediately completed month; one adjacent older boundary;
chronological returns ending on every completed-month session; endpoint sum
`N`; mean `mu`; squared-deviation sum `S`; adjacent-product sum `A`; lag-one
`rho=A/S`; fixed `J=rho+1/(n-1)`; strict `J>0`; same-sign endpoint direction;
consumed monthly attempt; fixed risk; frozen ATR stop; spread cap; first-later-
month exit; and forty-day stale closure. There is no optimization surface or
fallback signal.

### R3 - Runtime data availability

`PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.

Registered native `XTIUSD.DWX` D1 history, MT5 symbol metadata, quote, spread,
ATR, position/deal state, broker time, and terminal-global attempt state supply
every input. No futures chain or external dataset is required. Q02 owns history
sufficiency, costs, fills, financing, density, gaps, and continuous-CFD basis.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, addition,
multiplication, division, comparisons, ATR risk distance, quotes, positions,
deals, and persistent terminal state. It contains no trained or adaptive
output, banned signal, external runtime feed, grid, martingale, pyramid,
scale-in, or result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,626 registry identities,
1,295 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_wti_mdaily_persist_mom_preallocation_dedup_20260823.json`.

After reservation, the checker found only the two exact expected self-hits for
reserved `QM5_41127` in
`artifacts/qm5_41127_wti_mdaily_persist_mom_postallocation_dedup_20260823.json`.

Manual review separates unconditional one-month endpoint momentum
(`QM5_20187`), 32-month robust q2 memory (`QM5_13134`), other multi-month
variance-ratio horizons (`QM5_20245`, `QM5_20253`, `QM5_20256`, `QM5_20257`),
daily sign breadth (`QM5_41111`), fixed-block votes (`QM5_41114`, `QM5_41115`,
`QM5_41117`), ordered extremes (`QM5_41122`), mean/RMS coherence (`QM5_41124`),
L1 path efficiency (`QM5_41126`), and XAU/XAG relative baskets (`QM5_41123`,
`QM5_41125`). This card alone centers one completed month of WTI daily returns,
multiplies every adjacent pair, applies the fixed short-sample shift, and
follows the endpoint only when the corrected score is strictly positive.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_PERSISTENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XTIUSD.DWX`, D1, EA `41127`, slot 0, magic `411270000`.
2. One decision attempt on the first executable bar of each new broker month,
   within 180 minutes of the raw host D1 bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique D1
   closes, plus one adjacent older close proving the left boundary.
4. Chronological log returns from the older close into every month-session
   close; compute `N`, `mu`, `S`, `A`, `rho`, `J`; require endpoint identity,
   finite arithmetic, `S>0`, bounded `rho`, and strict `J>0`.
5. Positive `N`: BUY WTI. Negative `N`: SELL WTI. Zero variance, zero net,
   `J<=0`, endpoint mismatch, and malformed states consume the month flat.
6. One position, aggregate `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` hard
   stop, no target or score-strength sizing, and a 1,500-point spread ceiling.
7. Malformed-position repair; first-later-month close; forty-day stale guard;
   no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

The seeded zero-drift Gaussian design reference qualifies 49.595% to 50.385%
of months across the fixed 17, 20, and 23 observation counts, or about six
decisions/year. This is not market evidence. Q02 retires at zero positions,
below five completed positions in any full scored post-warm-up year,
nonpositive governed economics, or any calendar, boundary, orientation,
centering, arithmetic, correction, threshold, direction, attempt, risk,
lifecycle, or determinism defect.

A weak result may not be rescued by changing the correction, threshold,
direction, return inclusion, session bounds, hold, risk, or carrier, or by
adding a significance test, reversal state, sign count, block vote, sequence,
range location, seasonality, event, external, or prior-result state.

WTI is a different economic carrier from the certified XAU/SP500/NDX/XNG book
but is not presumed decorrelated. Unchanged Q09 alone owns the realized
portfolio decision.

## Approval Scope And Safety

`g0_status: APPROVED` and `execution_contract_status: APPROVED` authorize the
card-aligned branch-only EA source, governed magic row, strict compile/Q01,
one `RISK_FIXED` backtest setfile, deterministic reference tests, and one paced
Q02 enqueue if the fresh resource ceiling permits.

This decision does not authorize a manual tester run, demo/shadow/live/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, or live use. Q09 alone may establish realized portfolio
correlation.
