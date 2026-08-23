# QM5_41124 WTI Completed-Month Mean-to-RMS Coherence Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41124_wti-mrms-coherence-mom_card.md`

Source approval:
`decisions/2026-08-23_wti_monthly_mean_rms_coherence_momentum_source_approval.md`

Source packet:
`strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41124`
- slug: `wti-mrms-coherence-mom`
- strategy ID: `MOP-WTI-MRMS-COHERENCE-MOM-2026_S01`
- source ID: `MOP-WTI-MRMS-COHERENCE-MOM-2026`
- symbol: `XTIUSD.DWX`, D1, slot 0
- magic: `411240000`

The governed allocator reserved `41124` in
`framework/registry/ea_id_registry.csv` before this decision. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK`.

The bounded source preserves a named peer-reviewed *Journal of Financial
Economics* paper, DOI, author-hosted complete-paper evidence, durable hashes,
explicit NYMEX WTI membership, and a source-declared one-month formation and
hold inside the commodity-futures portfolio. The paper supports testing WTI
own-return continuation but does not establish a WTI-specific one-month effect
and does not test mean-to-RMS daily-path coherence. That gate is an explicit
pre-result QM translation. No performance, density, cost, CFD-equivalence, or
correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbol and D1 period; first-new-month timing; an exact
17-to-23-session immediately completed broker month; one adjacent older
boundary close; chronological log returns ending on every completed-month
session; signed sum `N`; squared-path sum `Q`; endpoint identity; bounded
`C=abs(N)/sqrt(n*Q)`; fixed inclusive `C>=0.16`; same-sign direction; consumed
monthly attempt; fixed risk; frozen ATR stop; spread cap; first-later-month
exit; and forty-day stale closure. There is no optimization surface or
fallback signal.

### R3 - Runtime data availability

`PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.

Registered native `XTIUSD.DWX` D1 history, MT5 symbol metadata, quote, spread,
ATR, position/deal state, broker time, and terminal-global attempt state
supply every input. No futures chain or external dataset is required. Q02 owns
history sufficiency, costs, fills, financing, density, gaps, and continuous-
CFD basis risk.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, addition,
multiplication, square root, division, comparisons, ATR risk distance, quotes,
positions, deals, and persistent terminal state. It contains no trained or
adaptive output, banned signal, external runtime feed, grid, martingale,
pyramid, scale-in, or result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,623 registry identities,
1,292 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_wti_mrms_coherence_mom_preallocation_dedup_20260823.json`.

After reservation, the same checker scanned 4,624 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41124`:
`artifacts/qm5_41124_wti_mrms_coherence_mom_postallocation_dedup_20260823.json`.

Manual review separates unconditional one-month WTI endpoint momentum
(`QM5_20187`), twelve-month/equal-month L2 normalization (`QM5_20288`),
twelve-month L1 path efficiency (`QM5_20274`), unordered sign breadth
(`QM5_41111`), fixed-block aggregation (`QM5_41114`, `QM5_41115`,
`QM5_41117`), and ordered extreme sequences (`QM5_41122`). This card uses one
immediately completed month, every daily squared magnitude, one bounded
mean-to-RMS quotient, and a fixed 0.16 gate before following its net sign.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_MEAN_RMS_COHERENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XTIUSD.DWX`, D1, EA `41124`, slot 0, magic `411240000`.
2. One decision attempt on the first executable bar of each new broker month,
   within 180 minutes of the raw host D1 bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique D1
   closes, plus one adjacent older close proving the left boundary.
4. Chronological log returns from the older close into every month-session
   close; `N=sum(r)`, `Q=sum(r^2)`, endpoint identity, and
   `C=abs(N)/sqrt(n*Q)`; finite arithmetic, `Q>0`, and `C` bounded to `[0,1]`
   within `1e-10`.
5. Accept only `C>=0.16` and `N!=0`. Positive `N`: BUY WTI. Negative `N`:
   SELL WTI. Zero path, zero net, below threshold, endpoint mismatch, and
   malformed states consume the month flat.
6. One position, aggregate `RISK_FIXED=1000`, frozen
   `3.5*ATR(20,D1)` hard stop, no target, no signal-strength sizing, and a
   1,500-point spread ceiling.
7. Malformed-position repair; first-later-month close; forty-day stale guard;
   no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

The pre-result Gaussian design reference qualifies about 45.6% to 52.6% of
months across the allowed observation counts, or about 5.5 to 6.3 decisions
per year. This is not market evidence. Q02 retires at zero positions, below
five completed positions in any full scored post-warm-up year, nonpositive
governed economics, or any calendar, boundary, orientation, arithmetic,
normalization, threshold, direction, attempt, risk, lifecycle, or determinism
defect.

A weak result may not be rescued by changing the threshold, direction, return
inclusion, session bounds, hold, risk, or carrier, or by adding a fitted mean,
volatility forecast, sign count, block vote, sequence, range location,
seasonality, event, external, or prior-result state. Any such change requires
a new OWNER-approved identity.

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
