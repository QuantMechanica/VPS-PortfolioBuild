# Diversity funnel — CPU-ceiling stop after non-duplicate backlog audit

Date: 2026-08-30 UTC (`2026-08-30T18:52:48Z`); 2026-08-30 20:52
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7bb7012b307aa3750ec6220a6c33b40b27a25713`

Status: stopped at the explicit backtest CPU ceiling before farm claim, compile,
infrastructure repair, mechanization, or Q02 enqueue.

## Binding capacity result

The fresh five-sample whole-host CPU window measured `98.35%`, `98.42%`,
`85.70%`, `86.34%`, and `85.33%` at two-second intervals. Average CPU was
`90.828%`; maximum CPU was `98.42%`. The governed admission rule requires both
the average and maximum to remain strictly below `97%`, so the maximum bound
and closed this paced wake.

No confirmation window was used to reopen the wake after the explicit stop
condition bound.

## Diversity-first coordination audit

The canonical dry-run priority scorer was consulted before any claim. Its
highest nominal diverse approved-backlog rows were not fresh build work:

- `QM5_36006` (FX, D1) already had canonical source/spec/setfiles and a prior
  governance-blocked rebuild record.
- `QM5_36005` (FX cross, D1) had already received a same-day diversity recovery
  and had a governed compile item pending under a CPU hold.
- `QM5_41172` (WTI, structural monthly edge) already had source/spec/setfile and
  a governed compile item pending.
- `QM5_21508` (EURUSD, D1) already had a completed governed compile artifact and
  concurrent staged paths from another paced worker.

Claiming or rebuilding any of those rows would have duplicated or collided
with existing farm work. A read-only Q02/Q03 failure audit therefore narrowed
the next permissible lane to a distinct FX infrastructure repair. No repair
candidate was claimed because the capacity window then bound.

At the final read-only farm snapshot, `build_ea` contained three active and 58
pending tasks; Q03 and Q04 contained 149 and 68 pending tasks respectively.
Immediately before the CPU window, factory terminals were active on `T2`,
`T4`, `T8`, `T9`, and `T10`. By `2026-08-30T18:54:14Z`, `T8` and `T10` had
completed or exited, leaving `T2`, `T4`, and `T9`. The supported slot view
reported ten worker daemons, no duplicate workers, and no orphaned terminal
process. This was active tester turnover, not a stale-process repair signal.

## Non-duplicate delta

The preceding receipt at `2026-08-30T03:00:31Z` recorded a `79.069796%`
average, a `98.711199%` peak, and an early stop before backlog ranking. This
receipt captures a materially different state 15 hours later: the average had
risen to `90.828%`, the active phase mix had shifted to Q03/Q04/Q07/OPT_CENSUS/
Q10_NEWS, and the diversity backlog was audited far enough to prove that the
nominal leaders were already governed, claimed, compiled, or concurrently
owned. The resulting next lane is a distinct FX infrastructure repair once
capacity reopens.

## Scope and safety boundary

No farm claim, work item, queue row, priority, status, or verdict was mutated.
No Strategy Card, G0 decision, EA source or binary, setfile, registry, magic
row, resolver, or build result was changed. No compile, build check, smoke,
backtest, dispatch tick, terminal reservation, terminal control, or worker
control was started. The portfolio gate, portfolio-admission surfaces,
`T_Live`, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_cpu_ceiling_stop_20260830T185248Z_board_advisor.json`.

## Continuation condition

On a later paced wake, take a new five-sample capacity window. Proceed only
when both average and maximum are strictly below `97%`; then atomically claim
one distinct diverse FX Q02/Q03 infrastructure repair identified by a fresh
farm audit. Keep backtest setfiles at `RISK_FIXED`, enqueue only through the
governed farm path, and do not dispatch or touch portfolio/live surfaces.
