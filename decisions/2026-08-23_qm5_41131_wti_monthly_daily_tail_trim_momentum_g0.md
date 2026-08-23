# QM5_41131 WTI Completed-Month Daily Tail-Trim Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41131_wti-mdaily-tailtrim-mom_card.md`

Source approval:
`decisions/2026-08-23_wti_monthly_daily_tail_trim_momentum_source_approval.md`

Source packet:
`strategy-seeds/sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural
low-frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02
enqueue, no live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41131`
- slug: `wti-mdaily-tailtrim-mom`
- strategy ID: `MOP-WTI-MDAILY-TAILTRIM-MOM-2026_S01`
- source ID: `MOP-WTI-MDAILY-TAILTRIM-MOM-2026`
- host: `XTIUSD.DWX`, D1, slot 0, magic `411310000`

The atomic registry procedure reserved `41131` at commit `b241a2557`. Magic
allocation must follow the governed directory-first sequence before
implementation and compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable Track-Record Basis

`PASS_WITH_WITHIN_MONTH_ROBUST_AGGREGATION_TRANSLATION_RISK`.

The bounded source preserves a peer-reviewed *Journal of Financial Economics*
paper with DOI, complete-read evidence, durable hashes, own-return momentum,
monthly renewal, and explicit WTI membership. Governed child packets fix the
robust-order-statistic convention and exact completed-month boundary. The
within-month daily horizon and exact one-observation-per-tail deletion are
explicit pre-result QM translations. No performance, density, cost,
CFD-equivalence, or portfolio result transfers.

### R2 - Mechanical Completeness

`PASS`.

The card locks exact symbol and D1 period; uniform energy-label convention;
first-new-month timing; an exact 17-to-23-session immediately completed month;
one older boundary close; one chronological log return ending on every month
session; endpoint identity; ascending sort; omission of exactly indexes zero
and `n-1`; sum of exactly indexes `1..n-2`; strict sign direction; consumed
monthly attempt; fixed risk; frozen ATR hard stop; spread cap; later-month
exit; and forty-day stale repair. There is no optimization surface or fallback
signal.

### R3 - Runtime Data Availability

`PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`.

Registered native `XTIUSD.DWX` D1 history, broker time, MT5 symbol metadata,
quotes, spread, ATR, position/deal state, and terminal-global attempt state
supply every input. No futures chain, inventory file, or external dataset is
required. Q02 owns history sufficiency, costs, financing, fills, label
behavior, density, and continuous-CFD basis.

### R4 - ML And Prohibited-Mechanic Ban

`PASS`.

The mechanic uses completed timestamps and closes, logarithms, a deterministic
sort, addition, comparison, ATR risk distance, quotes, positions, deals, and
persistent state. It contains no trained or adaptive output, banned signal,
external runtime feed, grid, martingale, pyramid, scale-in, or result-driven
parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,630 registry identities,
1,298 cards, and 45 Strategy Wiki nodes using the canonical Company Reference
root and returned `CLEAN`:
`artifacts/qm5_wti_mdaily_tailtrim_mom_preallocation_dedup_20260823.json`.

After reservation, the checker found only the exact slug and strategy-ID
self-hits for reserved `QM5_41131` in
`artifacts/qm5_41131_wti_mdaily_tailtrim_mom_postallocation_dedup_20260823.json`.

Manual review separates the one-month endpoint in `QM5_20187`; the
twelve-month-return/two-per-tail statistic in `QM5_20270`; daily-sign breadth
and endpoint agreement in `QM5_41111`; L2 and L1 normalization in
`QM5_41124`/`QM5_41126`; and adjacent-return persistence in `QM5_41127`. This
card alone sorts all daily returns ending in one completed WTI month, removes
exactly its single minimum and maximum array elements, and follows the inner
sum without a raw-endpoint gate. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SINGLE_TAIL_TRIM_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XTIUSD.DWX`, D1, EA `41131`, slot zero, magic `411310000`.
2. One attempt on the first executable normalized D1 bar of each new broker
   month, within 180 minutes of the raw host-bar open.
3. Exactly the immediately completed normalized calendar month, 17 through 23
   unique closes, plus one adjacent older close proving the left boundary.
4. Chronological log returns from the older close into every month session;
   finite arithmetic and raw endpoint identity within `1e-10`.
5. Sort all returns ascending, omit exactly indexes zero and `n-1`, and sum
   exactly indexes `1..n-2`. Positive buys, negative sells, and exact zero or
   malformed state consumes the month flat. Raw endpoint direction is not a
   gate or size input.
6. One position, `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen
   `3.5*ATR(20,D1)` hard stop, no target, and 1,500-point spread ceiling.
7. Persist the month attempt before every fallible gate; no retry after flat,
   rejection, stop-out, restart, or downstream block.
8. Close on the first later normalized broker-month tick, with a forty-day
   stale repair. Flatten malformed or stopless owned exposure immediately.
9. Both news axes and Friday close OFF. Framework kill switch and ownership
   repair remain authoritative.

## Falsification Boundary

The density prior is approximately ten to twelve positions per full year and
is not market evidence. Q02 retires at zero positions, below five in any full
post-warm-up scored year, nonpositive governed economics, or any label, month,
boundary, return, endpoint, sort, deletion, side, attempt, risk, stop,
lifecycle, or determinism defect.

A weak result may not be rescued by changing the tail count, retained indexes,
direction, return inclusion, hold, risk, or carrier, or by adding endpoint
agreement, sign breadth, persistence, volatility, seasonality, event,
external, or prior-result state.

Direct WTI exposure is a different economic carrier from the certified XAU,
SP500, NDX, and XNG book, not a decorrelation finding. Unchanged Q09 alone owns
the realized portfolio decision.

## Approval Scope And Safety

`g0_status: APPROVED` and `execution_contract_status: APPROVED` authorize the
card-aligned branch-only EA source, governed magic row, strict compile/Q01,
one D1 `RISK_FIXED` backtest setfile, deterministic reference tests, and one
paced Q02 enqueue if the fresh resource ceiling permits.

This decision does not authorize a manual tester run, demo/shadow/live/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, or live use. Q09 alone may establish realized portfolio
correlation.
