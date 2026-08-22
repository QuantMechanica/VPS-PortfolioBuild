# QM5_41119 XAU/XAG Completed-Month Close-Quartile Reversion - G0 Decision

Date: 2026-08-22

Decision: `APPROVED`

Card: `strategy-seeds/cards/approved/QM5_41119_xauxag-mclose-quartile-rv_card.md`

Source approval:
`decisions/2026-08-22_xauxag_monthly_close_quartile_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural
low-frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02
enqueue, no live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41119`
- slug: `xauxag-mclose-quartile-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01`
- source ID: `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0
- companion: `XAGUSD.DWX`, D1, slot 1
- logical symbol: `QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1`

The governed allocator reserved `41119` in
`framework/registry/ea_id_registry.csv` at commit `ad4f24de1`. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_CLOSE_QUARTILE_TRANSLATION_RISK`.

The approved bounded source preserves a named peer-reviewed *Journal of
Banking & Finance* DOI, supporting peer-reviewed *Resources Policy* DOI
lineage, and official CME Group carrier research. Parent packets were read
completely and their SHA-256 hashes are fixed in the source approval and child
packet.

The sources support a potentially state-dependent gold/silver relation and an
intermarket-spread carrier. They do not test an immediately completed month's
final-close quartile rank, the contrarian direction, continuous CFDs,
equal-notional fixed-dollar risk, or the QM book. Those elements are explicit
pre-result QM translations. No source performance, neutrality, hedge ratio,
cost, or correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; a
17-to-23-session synchronized completed-month package; strict chronological
log-ratio close ordering; newest-close uniqueness; zero-based strict lower
count; `tail=ceil(n/4)`; lower/upper fixed rank sets; contrarian sides;
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

The mechanic uses completed timestamps, prices, logarithms, integer counts,
comparisons, ATR risk distance, quotes, positions, deals, and terminal global
state. It contains no trained or adaptive output, prohibited signal indicator,
external runtime feed, grid, martingale, pyramid, scale-in, or result-driven
parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,618 registry identities,
1,287 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mclose_quartile_rv_preallocation_dedup_20260822.json`.

After reservation, the same checker scanned 4,619 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41119`; no foreign fuzzy match was reported:
`artifacts/qm5_41119_xauxag_mclose_quartile_rv_postallocation_dedup_20260822.json`.

Manual semantic review separates the candidate from:

- weekly unique-minimum/maximum `QM5_41079`, because this card uses monthly
  fixed outer-quartile rank sets and a one-month hold;
- rolling 126-observation empirical-tail `QM5_20268`, because this card uses
  only one completed month's close levels and no rolling distribution or
  median exit;
- monthly half-dominance `QM5_41118`, outside-residence `QM5_41110`, and
  range-migration `QM5_41103`, because this card has no return-block
  magnitude, parent range, residence, or cross-month range comparison;
- rolling z-score, regression, robust-score, and conditional-tail ratio
  systems, because it estimates no center, scale, beta, or fitted threshold;
- certified `QM5_12567`, because that is a long-only two-day XNG oscillator
  pullback rather than a paired monthly intermetal rank fade.

Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_CLOSE_QUARTILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. One logical basket hosted on exact `XAUUSD.DWX`, D1, with exact
   `XAGUSD.DWX` companion and governed slots 0/1.
2. One decision attempt on the first synchronized tradable bar of each new
   broker month, within 180 minutes of the raw host bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized close pairs, strict completed-history and label checks.
4. Chronological log-ratio closes; final close unique; `rank` equals the count
   strictly below the final close; `tail=(n+3)//4`.
5. Bottom-tail rank: BUY XAU / SELL XAG. Top-tail rank: SELL XAU / BUY XAG.
   Ties and interior ranks consume the attempt flat.
6. One equal-absolute-notional package, aggregate `RISK_FIXED=1000`, frozen
   `3.5*ATR(20,D1)` per-leg stops, 20-percent maximum notional mismatch, no
   target, and no signal-strength sizing.
7. Atomic broken-package repair; first-later-month close; forty-day stale
   guard; no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

Expected cadence is approximately five to seven packages per full post-warm-
up year based on fixed rank-set cardinality, not test evidence. Q02 retires at
zero packages, below five completed packages per full year, nonpositive
governed economics, or any synchronization, label, ordering, tie, rank,
quartile, side, attempt, aggregate-risk, atomicity, lifecycle, or determinism
defect.

A weak result may not be rescued by changing the quartile definition,
accepting ties, reversing the side, altering the hold or session bounds, or
adding a fitted center, scale, return threshold, volatility, volume, calendar,
event, external, or prior-result state. Any such change requires a new OWNER-
approved identity.

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
