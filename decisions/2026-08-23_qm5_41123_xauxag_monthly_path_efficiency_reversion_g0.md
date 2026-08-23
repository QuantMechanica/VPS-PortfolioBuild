# QM5_41123 XAU/XAG Completed-Month Path-Efficiency Reversion - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card: `strategy-seeds/cards/approved/QM5_41123_xauxag-mpath-eff-rv_card.md`

Source approval:
`decisions/2026-08-23_xauxag_monthly_path_efficiency_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural
low-frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02
enqueue, no live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41123`
- slug: `xauxag-mpath-eff-rv`
- strategy ID: `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01`
- source ID: `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0
- companion: `XAGUSD.DWX`, D1, slot 1
- logical symbol: `QM5_41123_XAU_XAG_MPATH_EFF_RV_D1`

The governed allocator reserved `41123` in
`framework/registry/ea_id_registry.csv` before this decision. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_PATH_HORIZON_AND_DIRECTION_TRANSLATION_RISK`.

The approved bounded source preserves named peer-reviewed gold/silver DOI
lineage, official CME Group ratio-spread research, and a completely read
peer-reviewed path-efficiency lineage with durable hashes. The gold/silver
sources support a state-dependent intermetal relationship and tradeable
relative carrier. The path source supplies exact net-to-absolute-path
arithmetic, but not its use on one month of daily ratio returns or its reversal
direction. Those are explicit pre-result QM translations. No source
performance, probability, neutrality, threshold, hedge ratio, cost, or
correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; a
17-to-23-session synchronized completed-month package; strict chronological
log-ratio close ordering; every adjacent relative return; signed net and full
absolute-path sums; fixed inclusive `E>=0.20`; numerical and zero handling;
contrarian sides; consumed monthly attempt; equal-notional aggregate fixed
risk; per-leg frozen ATR stops; spread and notional guards; atomic repair;
first-later-month exit; and forty-day stale closure. There is no optimization
surface or fallback signal.

### R3 - Runtime data availability

`PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.

Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history, MT5 symbol
metadata, quotes, ATR, positions, deals, broker time, and persistent terminal
state supply every runtime input. No futures chain or external dataset is
required. Q02 owns synchronized-history sufficiency, holiday attrition,
density, costs, fills, financing, and continuous-CFD basis risk.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, absolute values,
sums, division, comparisons, ATR risk distance, quotes, positions, deals, and
terminal global state. It contains no trained or adaptive output, prohibited
signal, external runtime feed, grid, martingale, pyramid, scale-in, or
result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,622 registry identities,
1,291 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mpath_eff_rv_preallocation_dedup_20260823.json`.

After reservation, the same checker scanned 4,623 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41123`:
`artifacts/qm5_41123_xauxag_mpath_eff_rv_postallocation_dedup_20260823.json`.

Manual review separates rolling ratio/OLS/robust-score families, outright
twelve-month WTI path efficiency (`QM5_20274`), unordered sign breadth
(`QM5_41112`), fixed-block votes (`QM5_41113`, `QM5_41116`, `QM5_41118`),
range/anchor locations (`QM5_41119`, `QM5_41120`), and sequence/reversal counts
(`QM5_41121`). This card uses every within-month relative-return magnitude
only through exact net displacement and total absolute path, then fades one
month with opposite equal-notional legs. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_PATH_EFFICIENCY_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. One logical basket hosted on exact `XAUUSD.DWX`, D1, with exact
   `XAGUSD.DWX` companion and governed slots 0/1.
2. One decision attempt on the first synchronized tradable bar of each new
   broker month, within 180 minutes of the raw host bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized close pairs, strict completed-history and label checks.
4. Chronological log-ratio closes and adjacent returns; `N=sum(r)`,
   `P=sum(abs(r))`, and `E=abs(N)/P`; finite arithmetic, `P>0`, and
   `E` bounded to `[0,1]` within `1e-10`.
5. Accept only `E>=0.20` and `N!=0`. Positive `N`: SELL XAU / BUY XAG.
   Negative `N`: BUY XAU / SELL XAG. Zero path, zero net, below threshold,
   and malformed states consume the month flat.
6. One equal-target-absolute-notional package, aggregate `RISK_FIXED=1000`,
   frozen `3.5*ATR(20,D1)` per-leg stops, 20-percent maximum realized
   notional mismatch, no target, and no signal-strength sizing.
7. Atomic broken-package repair; first-later-month close; forty-day stale
   guard; no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

A deterministic twenty-return Gaussian design reference qualifies about
48.3% of months, or 5.8 decisions/year. This is not test evidence. Q02 retires
at zero packages, below five completed packages in any full year, nonpositive
governed economics, or any synchronization, label, orientation, arithmetic,
threshold, side, attempt, aggregate-risk, atomicity, lifecycle, or determinism
defect.

A weak result may not be rescued by changing the threshold, reversing the
side, altering the hold or session bounds, or adding a fitted center, scale,
location, sign count, block vote, sequence state, volatility, volume,
calendar, event, external, or prior-result state. Any such change requires a
new OWNER-approved identity.

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
