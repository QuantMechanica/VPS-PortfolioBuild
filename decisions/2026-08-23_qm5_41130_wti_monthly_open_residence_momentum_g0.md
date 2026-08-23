# QM5_41130 WTI Completed-Month Fixed-Open Residence Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41130_wti-mopen-residence-mom_card.md`

Source approval:
`decisions/2026-08-23_wti_monthly_open_residence_momentum_source_approval.md`

Source packet:
`strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41130`
- slug: `wti-mopen-residence-mom`
- strategy ID: `MOP-WTI-MOPEN-RESIDENCE-MOM-2026_S01`
- source ID: `MOP-WTI-MOPEN-RESIDENCE-MOM-2026`
- symbol: `XTIUSD.DWX`, D1, slot 0
- intended magic: `411300000`

The deterministic registry reserved `41130` in
`framework/registry/ea_id_registry.csv` before this decision. Magic allocation
must follow the governed directory-first sequence before implementation and
compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable track-record basis

`PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK`.

The bounded source preserves a peer-reviewed *Journal of Financial Economics*
paper with named authors, DOI, complete-read evidence, durable hashes,
explicit WTI membership, own-return continuation, and a monthly formation and
hold clock. A separately governed bounded packet supplies deterministic
residence-count conventions only. Neither record tests this one-month WTI D1
residence gate or its continuation mapping. Those elements are explicit pre-
result QM translations. No performance, density, cost, CFD-equivalence, or
correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbol and D1 period; first-new-month timing; an exact
17-to-23-session immediately completed month; one adjacent older boundary;
every chronological close comparison with that immutable boundary; strict
tie handling; integer `ceil(3*n/4)` arithmetic; endpoint identity and same-side
continuation; consumed monthly attempt; fixed risk; frozen ATR stop; spread
cap; first-later-month exit; and forty-day stale closure. There is no
optimization surface or fallback signal.

### R3 - Runtime data availability

`PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.

Registered native `XTIUSD.DWX` D1 history, MT5 symbol metadata, quote, spread,
ATR, position/deal state, broker time, and terminal-global attempt state supply
every input. No futures chain or external dataset is required. Q02 owns
history sufficiency, costs, fills, financing, density, gaps, and continuous-
CFD basis.

### R4 - ML and prohibited-mechanic ban

`PASS`.

The rule uses completed timestamps and closes, logarithms, integer counts,
comparisons, native ATR for the hard stop, and framework execution state.
There is no trained output, banned signal indicator, external runtime feed,
grid, martingale, scale-in, or pyramid.

## Source And Claim Review

The canonical packet
`strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md`, SHA-256
`4618B8365486FE18DA1C878F7920F6ED284115A37A87D26B59CE9C5A24DED991`,
binds the named paper, complete-read evidence, parent hashes, exact mechanic,
non-duplicate boundary, reputable-source criteria, and kill rule. The source
approval was committed first at `751e7cc4d`.

The paper supports testing WTI own-return continuation at a monthly clock. It
does not establish the three-quarter D1 residence gate, continuous-CFD
equivalence, fixed-dollar sizing, ATR stop, or portfolio behavior. Those are
falsification choices rather than source claims.

## Non-Duplicate Review

Pre-allocation evidence
`artifacts/qm5_wti_mopen_residence_mom_preallocation_dedup_20260823.json`
returned `CLEAN` across 4,629 registry rows, 1,297 cards, and 45 Strategy-Wiki
nodes. Post-allocation evidence
`artifacts/qm5_41130_wti_mopen_residence_mom_postallocation_dedup_20260823.json`
contains only the expected exact slug and strategy-ID self-hits for the
reserved row.

Manual review separates the card from endpoint-only WTI momentum, adjacent-
return sign breadth, half/third votes, extreme sequencing, L1/L2 path
statistics, centered adjacent-return persistence, and the existing XAU/XAG
contrarian residence basket. The fixed older WTI boundary, exhaustive month-
close count, integer three-quarter gate, final endpoint confirmation, and
outright continuation map are jointly load-bearing.

Verdict:
`CLEAN_WTI_COMPLETED_MONTH_FIXED_OPEN_RESIDENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Locked Execution Contract

1. Exact `XTIUSD.DWX`, D1, EA `41130`, slot 0, magic `411300000`.
2. First-new-month decision within 180 minutes; one durable attempt before
   every fallible gate.
3. Immediately completed 17-to-23-session month plus one adjacent older close.
4. Compare every month close strictly with the older boundary, retain ties in
   `n`, and require `required=(3*n+3)//4` on the endpoint side.
5. Verify the chronological return sum equals the boundary-to-final log return
   within `1e-10`; long above, short below, otherwise flat.
6. One position, aggregate `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` hard
   stop, no target or score-strength sizing, and a 1,500-point spread ceiling.
7. Malformed-position repair; first-later-month close; forty-day stale guard;
   no retry, add, trail, partial close, grid, martingale, or pyramid.
8. Both news axes and Friday close OFF. Framework kill switch and lifecycle
   repair remain authoritative.

## Falsification Boundary

The seeded zero-drift Gaussian design reference qualifies 60.825% to 65.170%
of months across the fixed 17, 20, and 23 observation counts, or roughly seven
to eight decisions/year. This is not market evidence. Q02 retires at zero
positions, below five completed positions in any full scored post-warm-up
year, nonpositive governed economics, or any calendar, anchor, count,
threshold, endpoint, direction, attempt, risk, lifecycle, or determinism
defect.

A weak result may not be rescued by changing the threshold, tie rule, anchor,
direction, close inclusion, hold, risk, or carrier, or by adding a fitted
mean, scale, return threshold, volatility state, sign count, block vote,
sequence, range, seasonality, event, external, or prior-result state.

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
