# QM5_41121 XAU/XAG Completed-Month Sequence-Dominance Reversion - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card: `strategy-seeds/cards/approved/QM5_41121_xauxag-mseqdom-rv_card.md`

Source approval:
`decisions/2026-08-23_xauxag_monthly_sequence_dominance_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural
low-frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02
enqueue, no live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41121`
- slug: `xauxag-mseqdom-rv`
- strategy ID: `SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026_S01`
- source ID: `SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0
- companion: `XAGUSD.DWX`, D1, slot 1
- logical symbol: `QM5_41121_XAU_XAG_MSEQDOM_RV_D1`

The governed allocator reserved `41121` in
`framework/registry/ea_id_registry.csv` at commit `9b19a5024`. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_CROSS_ASSET_SEQUENCE_AND_DIRECTION_TRANSLATION_RISK`.

The approved bounded source preserves named peer-reviewed gold/silver DOI
lineage, official CME Group carrier research, and the fully read primary
Cowles-Jones *Econometrica* sequence/reversal paper with durable hashes.

The gold/silver sources support a potentially state-dependent intermetal
relation and ratio-spread carrier. Cowles-Jones supply the same-sign sequence
and opposite-sign reversal definitions, but study equity prices and interpret
sequence excess as persistence. They do not test a completed XAU/XAG month's
sequence majority as an exhaustion fade, continuous CFDs, equal-notional
fixed-dollar risk, or the QM book. Those are explicit pre-result QM
translations. No source performance, probability, neutrality, threshold,
hedge ratio, cost, or correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; a
17-to-23-session synchronized completed-month package; strict chronological
log-ratio close ordering; finite nonzero adjacent relative returns; exhaustive
same-sign sequence and opposite-sign reversal transitions; inclusive
`sequences>=reversals`; first-to-last net direction; contrarian sides;
consumed monthly attempt; equal-notional aggregate fixed risk; per-leg frozen
ATR stops; spread and notional guards; atomic repair; first-later-month exit;
and forty-day stale closure. There is no optimization surface or fallback
signal.

### R3 - Runtime data availability

`PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.

Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history, MT5 symbol
metadata, quotes, ATR, positions, deals, broker time, and persistent terminal
state supply every runtime input. No futures chain or external dataset is
required. Q02 owns synchronized-history sufficiency, holiday attrition,
density, costs, fills, financing, and continuous-CFD basis risk.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, signs, integer
counts, comparisons, ATR risk distance, quotes, positions, deals, and terminal
global state. It contains no trained or adaptive output, prohibited signal
indicator, external runtime feed, grid, martingale, pyramid, scale-in, or
result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,620 registry identities,
1,289 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mseqdom_rv_preallocation_dedup_20260823.json`.

After reservation, the same checker scanned 4,621 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41121`:
`artifacts/qm5_41121_xauxag_mseqdom_rv_postallocation_dedup_20260823.json`.

Manual review separates terminal daily runs (`QM5_20275`), three completed
weekly signs (`QM5_41078`), unordered daily sign breadth (`QM5_41112`), fixed
block return votes (`QM5_41113`, `QM5_41116`), fixed-anchor level residence
(`QM5_41120`), and rolling fitted ratio families. This card uses every
chronological within-month adjacent return-sign transition, an exhaustive
sequence/reversal partition, an inclusive majority, and net-month
contrarian direction. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_SEQUENCE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. One logical basket hosted on exact `XAUUSD.DWX`, D1, with exact
   `XAGUSD.DWX` companion and governed slots 0/1.
2. One decision attempt on the first synchronized tradable bar of each new
   broker month, within 180 minutes of the raw host bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized close pairs, strict completed-history and label checks.
4. Chronological log-ratio closes and adjacent returns; every return finite
   and nonzero; every adjacent sign transition classified once as a same-sign
   sequence or opposite-sign reversal; exhaustive count `n-2`.
5. Accept only `sequences>=reversals`. Positive completed-month net ratio:
   SELL XAU / BUY XAG. Negative net ratio: BUY XAU / SELL XAG. Zero return,
   zero net, reversal dominance, and malformed states consume the month flat.
6. One equal-absolute-notional package, aggregate `RISK_FIXED=1000`, frozen
   `3.5*ATR(20,D1)` per-leg stops, 20-percent maximum notional mismatch, no
   target, and no signal-strength sizing.
7. Atomic broken-package repair; first-later-month close; forty-day stale
   guard; no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

Expected cadence is approximately six to eight packages per full post-warm-up
year based on a symmetric-sign prior, not test evidence. Q02 retires at zero
packages, below five completed packages in any full year, nonpositive governed
economics, or any synchronization, label, ordering, zero-return, sign,
transition-count, majority, net-direction, attempt, aggregate-risk, atomicity,
lifecycle, or determinism defect.

A weak result may not be rescued by changing the inclusive majority, assigning
zero returns a sign, reversing the side, altering the hold or session bounds,
or adding a fitted center, scale, magnitude, volatility, volume, calendar,
event, external, or prior-result state. Any such change requires a new
OWNER-approved identity.

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
