# QM5_41125 XAU/XAG Completed-Month Mean-to-RMS Coherence Reversion - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41125_xauxag-mrms-coherence-rv_card.md`

Source approval:
`decisions/2026-08-23_xauxag_monthly_mean_rms_coherence_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MRMS-COHERENCE-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41125`
- slug: `xauxag-mrms-coherence-rv`
- strategy ID: `SCHWEIKERT-MOP-CME-XAUXAG-MRMS-COHERENCE-RV-2026_S01`
- source ID: `SCHWEIKERT-MOP-CME-XAUXAG-MRMS-COHERENCE-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0, magic `411250000`
- companion: `XAGUSD.DWX`, D1, slot 1, magic `411250001`
- logical symbol: `QM5_41125_XAU_XAG_MRMS_COHERENCE_RV_D1`

The governed allocator reserved `41125` in
`framework/registry/ea_id_registry.csv` before this decision. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`.

The bounded source preserves a peer-reviewed gold/silver relation paper with
DOI, official CME intermarket-spread research, and peer-reviewed monthly
price-path lineage with complete-read evidence and durable hashes. The sources
support testing a state-dependent gold/silver relative carrier and a mechanical
monthly clock. They do not establish within-month relative-path coherence, the
`0.16` gate, contrarian direction, a CFD package, or book decorrelation. Those
are explicit pre-result QM translations, and no efficacy transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; 17 through
23 synchronized sessions in the immediately completed broker month; one
adjacent older boundary pair; one chronological gold-minus-silver log-ratio
return ending on every month session; signed sum `N`; squared-path sum `Q`;
endpoint identity; bounded `C=abs(N)/sqrt(n*Q)`; inclusive `C>=0.16`;
contrarian sides; consumed monthly attempt; equal-notional aggregate fixed
risk; atomic two-leg lifecycle; frozen stops; spread caps; later-month exit;
and forty-day stale closure. There is no optimization surface or fallback
signal.

### R3 - Runtime data availability

`PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.

Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories, MT5 symbol
metadata, quotes, spreads, ATR, position/deal state, broker time, and terminal-
global attempt state supply every input. No futures chain or external dataset
is required. Q02 owns synchronization attrition, history, costs, fills,
financing, density, gaps, and continuous-CFD basis risk.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, addition,
multiplication, square root, division, comparisons, ATR risk distance, quotes,
positions, deals, and persistent terminal state. It contains no trained or
adaptive output, banned signal, external runtime feed, grid, martingale,
pyramid, scale-in, or result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,624 registry identities,
1,293 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mrms_coherence_rv_preallocation_dedup_20260823.json`.

After reservation, the same checker scanned 4,625 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41125`:
`artifacts/qm5_41125_xauxag_mrms_coherence_rv_postallocation_dedup_20260823.json`.

Manual review separates rolling center/scale and regression systems,
32-month variance-ratio memory, daily sign breadth, fixed-block aggregation,
ordered extreme sequences, the L1 path-efficiency basket, and outright-WTI
mean-to-RMS momentum. This card uses one immediately completed synchronized
gold/silver month, every daily squared relative-return magnitude, one bounded
L2/RMS quotient, a fixed `0.16` gate, contrarian sides, and an atomic equal-
notional package. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_MEAN_RMS_COHERENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XAUUSD.DWX`/`XAGUSD.DWX`, D1, EA `41125`, slots 0/1, magics
   `411250000`/`411250001`.
2. One decision attempt on the first synchronized executable bar of each new
   broker month, within 180 minutes of the raw host D1 bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized pairs, plus one adjacent older pair proving the left boundary.
4. One chronological relative return ending on every completed-month session;
   `N=sum(r)`, `Q=sum(r^2)`, endpoint identity, and
   `C=abs(N)/sqrt(n*Q)`; finite arithmetic, `Q>0`, and `C` bounded to `[0,1]`
   within `1e-10`.
5. Accept only `C>=0.16` and `N!=0`. Positive `N`: SELL XAU / BUY XAG.
   Negative `N`: BUY XAU / SELL XAG. Zero path, zero net, below threshold,
   endpoint mismatch, and malformed states consume the month flat.
6. One atomic package, equal target absolute USD notionals, no more than 20%
   realized mismatch, aggregate `RISK_FIXED=1000`, frozen
   `3.5*ATR(20,D1)` hard stops, no target, and fixed spread ceilings.
7. Malformed-package repair; first-later-month close; forty-day stale guard;
   no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

The pre-result Gaussian design reference qualifies about 45.6% to 52.6% of
months across the allowed observation counts, or about 5.5 to 6.3 packages per
year. This is not market evidence. Q02 retires at zero packages, below five
completed packages in any full scored post-warm-up year, nonpositive governed
economics, or any synchronization, boundary, orientation, arithmetic,
normalization, threshold, side, attempt, risk, atomicity, lifecycle, or
determinism defect.

A weak result may not be rescued by changing the threshold, direction, return
inclusion, session bounds, hold, risk, or carrier, or by adding a fitted center,
scale, volatility forecast, sign count, block vote, sequence, range location,
seasonality, event, external, or prior-result state. Any such change requires
a new OWNER-approved identity.

Opposite equal-notional legs are intended to reduce common outright-metal
direction but are not presumed neutral or decorrelated. Unchanged Q09 alone
owns the realized portfolio decision.

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
