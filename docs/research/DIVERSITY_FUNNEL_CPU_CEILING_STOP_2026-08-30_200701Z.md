# Diversity funnel — governed CPU-ceiling stop at 20:07Z

Date: 2026-08-30 UTC (`2026-08-30T20:07:01Z`); 2026-08-30 22:07
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `6816a046a8e05c99f004569ebd868da86d4e4039`

Status: stopped at the explicit backtest CPU ceiling before any farm claim,
compile, smoke, repair, or Q02 enqueue.

## Binding capacity result

A fresh five-sample whole-host CPU window measured `92.09%`, `97.37%`,
`88.29%`, `82.91%`, and `90.93%`. Average CPU was `90.318%`; maximum CPU was
`97.37%`. The governed admission rule requires both average and maximum to
remain strictly below `97%`, so the maximum bound this paced wake.

The farm had nine active work items during the capacity check. One Q02 item on
T10 completed during the read-only follow-up, leaving eight active items across
T1, T2, T3, T5, T6, T7, T8, and T9. This was live tester turnover, not stale
process evidence.

## Non-duplicate coordination result

The canonical diversity scorer and farm claim guards were consulted before any
mutation. The highest-ranked eligible FX-cross build, `QM5_36005`, remains
owned by a prior paced recovery and has governed `COMPILE_EA` work pending under
its CPU hold. It was not touched.

The next unowned diverse handoff is `QM5_21508_qs-ma-envelope-eur`, a
single-symbol EURUSD D1 mean-reversion sleeve. Its approved card, active EA and
magic registry rows, committed source/spec/setfile, and completed governed
compile were all confirmed. Compile work item
`845bdd8a-c0a3-4a6c-b94e-f1bc8d6114b9` is `COMPILE_OK`; its source and binary
hashes are sealed. Build task `e6472d61-e9f6-4a9a-b9a4-44dcc75c0e79` remains
pending and has not yet produced the Q01 smoke/build-record/Q02 handoff.

This wake did not claim that task because the CPU ceiling had already bound.
An attempted scoped validation stopped safely: `validate_spec_doc.py` passed,
while `build_check.ps1` refused before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory terminals were alive.
The governed compile evidence remains the authoritative build result.

A read-only fallback scan also identified `QM5_20178` as a distinct FX
infrastructure-repair candidate after capacity reopens: its GBPUSD Q03 row
`c5fc6f91-f316-4bd1-b75a-643171c7cf90` ended `INFRA_FAIL/ACTIVE_TIMEOUT`, and
the EA had no pending or active work item at the observation time. This is a
candidate for a fresh claim-time verification, not an authorization or verdict.

## Farm snapshot

- build tasks: 3 active, 61 pending
- pending legacy P2 tasks: 35
- pending Q03 tasks: 149
- pending Q04 tasks: 68
- free physical memory: 39.10 GiB of 63.12 GiB
- final active work-item count: 8

## Scope and continuation

No farm claim, task/work-item state, queue priority, registry, resolver, EA
source, binary, setfile, card, gate verdict, or portfolio surface was mutated.
No backtest or terminal control was started. `T_Live`, AutoTrading, live/deploy
manifests, and the portfolio gate were untouched. Existing unrelated worktree
changes were preserved.

On a later paced wake, take a new capacity window. Only if both average and
maximum are below `97%`, atomically claim one distinct unit. Prefer completing
the governed Q01/build-record/Q02 handoff for `QM5_21508` if it remains
unclaimed; otherwise verify and claim the `QM5_20178` FX infrastructure repair
or the next eligible diverse row. Keep all backtest setfiles `RISK_FIXED` and
use the governed farm path only.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260830T200701Z_board_advisor.json`.
