# QM5_41182 WTI Median-Runs Source Build And CPU-Ceiling Handoff

Date: 2026-08-27  
Branch: `agents/board-advisor`  
Outcome: `SOURCE_BUILT_COMPILE_ENQUEUED_Q02_NOT_ENQUEUED_CPU_CEILING`

## Status

`QM5_41182_wti-median-runs-tr` is a committed, G0-approved, non-duplicate
source build with deterministic EA ID `41182`, slot-zero magic `411820000`,
one `XTIUSD.DWX` D1 fixed-risk backtest preset, a complete SPEC, and an
independent reference suite. The source build commit is
`46b072d877707e286f72409f509947679b39d81d`.

Strict Q01 compilation is still pending. The live-factory interlock correctly
refused ad-hoc `build_check`/compile with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. Exactly one governed compile work item,
`a994435a-61b0-46a3-8b46-0a07e24a9e4b`, was then enqueued. It remains pending
with zero attempts under `COMPILE_EA_WORKER_ROLLOUT_PENDING`; no `.ex5` exists.

Q02 was not enqueued. It is ineligible before compile/Q01 PASS, and the fresh
five-sample CPU series reached the mission's mandatory stop condition.

## What Changed

- Added the approved monthly WTI median-runs EA source. It reconstructs
  thirteen consecutive completed month-end closes, assigns strict ranks,
  omits rank seven before adjacency, proves six lows/six highs, counts the
  twelve-sign chronological runs, and continues the newest nonmedian regime
  only at inclusive `runs<=7`.
- Locked one fixed-risk backtest set:
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Added a SPEC and independent Python reference test covering median omission,
  boundary behavior, newest-median flat state, exact density, fail-closed
  inputs, non-duplicate separation, month continuity, setfile scope, card
  identity, and magic identity.
- Allocated exactly one active registry row:
  `41182,wti-median-runs-tr,0,XTIUSD.DWX,411820000,...,active`, then regenerated
  the resolver without collisions or dropped rows.
- Enqueued one governed compile row only. No Q02 row or manual tester run was
  created.

## Evidence Files

- Approved card:
  `strategy-seeds/cards/approved/QM5_41182_wti-median-runs-tr_card.md`
- Source packet:
  `strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`
- Canonical dedup receipt:
  `artifacts/qm5_wti_median_runs_tr_preallocation_dedup_20260827.json`
- EA source:
  `framework/EAs/QM5_41182_wti-median-runs-tr/QM5_41182_wti-median-runs-tr.mq5`
- SPEC:
  `framework/EAs/QM5_41182_wti-median-runs-tr/SPEC.md`
- Fixed-risk setfile:
  `framework/EAs/QM5_41182_wti-median-runs-tr/sets/QM5_41182_wti-median-runs-tr_XTIUSD.DWX_D1_backtest.set`
- Reference suite:
  `framework/EAs/QM5_41182_wti-median-runs-tr/docs/test_monthly_median_runs_reference.py`
- Machine-readable handoff:
  `artifacts/qm5_41182_wti_median_runs_source_build_cpu_ceiling_20260827T122753Z.json`

## Validation Evidence

- Reference suite: 10/10 PASS.
- Strategy Card schema lint: PASS; no ML hits or missing sections.
- G0 card lint: PASS.
- Build prerequisite guard: PASS for registry row, magic row, and EA directory.
- SPEC validator: PASS.
- Build guardrails: PASS for the `.mq5` and the only `.set` file.
- Magic resolver tests: 14/14 PASS.
- Banned/ML runtime scan: no hits.
- Exact combinatorics: 6,744 qualified of 12,012 balanced-sign-plus-median
  representations, 3,372 per side; `562/1001` density; 3,496,089,600 of 13!
  strict rank paths.
- Strict compile/Q01: pending governed compile; no `.ex5`, no PASS claim.

## CPU Stop

At `2026-08-27T12:27:53Z`, five one-second host samples were:

```text
100.00, 100.00, 100.00, 100.00, 100.00 percent
average = 100.00 percent
maximum = 100.00 percent
governed ceiling = 97.00 percent
```

Six factory terminals were running (`T1`, `T3`, `T4`, `T7`, `T8`, `T10`),
six `metatester64` processes were present, and eight farm rows were active.
`T_Live` and FTMO were observed read-only and excluded from factory control.

The ceiling is binding. Per the mission, work stopped here: no Q02 enqueue,
smoke, dispatch, retry, terminal/worker control, priority mutation, AutoTrading
change, `T_Live` change, portfolio admission, portfolio-gate change, or live
manifest change occurred.

## Risks And Blockers

- The source is not compiled; Q01 is not PASS and Q02 cannot legitimately be
  enqueued yet.
- The compile row is rollout-held and has not been claimed.
- The edge is a source-backed structural hypothesis, not an established
  profitable or decorrelated sleeve. Q02 owns activity/economics; Q09 alone
  may establish realized correlation against the incumbent book.
- Continuous-CFD roll/basis, financing, gaps, median information loss, and the
  inclusive density boundary remain explicit risks.
- Unrelated concurrent public-snapshot/Q13/strategy-farm worktree changes were
  preserved and excluded from these commits.

## Recommended Next Step

Let the governed compile worker claim the existing hash-bound compile row and
produce a strict 0-error/0-warning `.ex5` plus Q01 PASS. After capacity drops
below the 97% ceiling, recheck source/binary hashes and enqueue exactly one
`XTIUSD.DWX` D1 `RISK_FIXED` Q02 baseline. Do not create a second compile or
Q02 row.

`docs/ops/OPEN_ITEMS_STATUS.md` remains unchanged by this mission; this handoff
is the attached status evidence for the new candidate.
