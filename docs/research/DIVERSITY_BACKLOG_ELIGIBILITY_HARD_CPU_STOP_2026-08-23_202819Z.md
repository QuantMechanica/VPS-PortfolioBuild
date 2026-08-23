# Diversity backlog eligibility — hard CPU stop

Date: 2026-08-23 UTC (`2026-08-23T20:28:19Z`)

Branch: `agents/board-advisor`

Status: stopped without a farm claim, build, smoke, Q02/Q03 requeue, or tester
launch because the explicit backtest CPU ceiling is binding

## Outcome

The diversity-first preflight prevented two unsafe duplicate actions before the
capacity stop bound:

- `QM5_30001`, the nominal `strategy_priority.py` leader, is a retired EA
  identity. This lane cannot reactivate it.
- `QM5_36005`, the highest-ranked uncompiled FX candidate found after excluding
  already-built results, already has a `BLOCKED` task and a governed
  force-rebuild authorization hold. The existing hold is documented in
  `docs/ops/evidence/cf9b27fd_qm5_36005_card_remediation_compile_hold_2026-08-23.md`.

The other leading no-work-item results were also not clean build backlog:
`QM5_20087` lacks allocated magic rows and has assigned ownership, while
`QM5_11716` and `QM5_11848` already have compiled EX5 artifacts. The priority
scorer's no-work-item filter is not sufficient evidence that an EA is unbuilt.

No candidate was claimed. Before selecting a diverse Q02/Q03 infrastructure
repair, the mandatory capacity sample crossed the hard ceiling, so the mission's
explicit stop condition applied.

## Binding capacity stop

Five fresh one-second whole-host CPU samples were all `100.00%`. Their average
and maximum were both `100.00%`, above the `97%` average-or-maximum ceiling.
The machine still had 21.03 GiB physical memory and 139.10 GiB free on `D:`, so
CPU—not disk or memory—was the binding resource.

The supported path-aware scan at `2026-08-23T20:27:33Z` found active factory
terminal processes on T1, T2, T3, T4, T7, and T10, with worker services present
for T1–T10. The read-only farm snapshot at `2026-08-23T20:29:16Z` had nine
active work items: one Q02 and eight Q10_NEWS. The Q02 slot was already occupied
by `QM5_20206` on T4. Process and database snapshots are intentionally reported
as non-atomic observations.

This is non-duplicate relative to the `19:50:33Z` stop receipt. The active item
count changed from ten to nine, the current active phase mix is now explicitly
one Q02 plus eight Q10_NEWS, and this run adds the retired-identity and governed
compile-hold exclusions produced by the live diversity backlog ranking.

Machine-readable evidence is
`artifacts/diversity_backlog_eligibility_hard_cpu_stop_20260823T202819Z_board_advisor.json`.

## Safety and workspace isolation

Only this receipt and its JSON evidence are committed. Concurrent worktree
changes were not staged. No Strategy Card, EA, registry, magic, resolver,
setfile, queue row, task priority, terminal reservation, portfolio gate, Q08
contribution path, T_Live manifest, T_Live terminal, or AutoTrading state was
changed.

## Continuation

When a fresh five-sample whole-host window remains below the 97% hard ceiling,
rerun the live ranking and registry/task collision checks. Claim exactly one
eligible diverse build or one append-only diverse Q02/Q03 infrastructure repair
through the farm database.
