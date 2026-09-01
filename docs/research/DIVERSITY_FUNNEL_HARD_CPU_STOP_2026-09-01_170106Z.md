# Diversity funnel hard CPU stop

Date: 2026-09-01 UTC (`2026-09-01T17:01:06Z`); 2026-09-01 19:01
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4411c9b907`

Status: stopped before farm claim/resume, build, infrastructure repair, compile,
smoke, or Q02 enqueue because the explicit backtest CPU ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at two-second intervals,
was `91.0%`, `90.0%`, `94.0%`, `97.0%`, and `99.0%`. Average utilization was
`94.2%`; maximum utilization was `99.0%`. The paced-fleet stop rule binds when
either measure is at least `97%`, so the maximum triggered the stop.

The read-only farm snapshot immediately before the sample reported five active
and 72 pending `build_ea` tasks. `farmctl mt5-slots` reported active factory
tester processes on T1 and T4, both running `OPT_CENSUS` work. The existing
`QM5_36005` forex build handoff was not resumed, no other task or work item was
claimed or advanced, and no Q02 row was created or changed.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at capacity preflight; no
  approved Card, EA source, binary, setfile, registry row, magic row, or resolver
  was changed.
- The farm DB and terminal-slot state were inspected read-only. No farm DB
  write, queue mutation, terminal action, worker action, compile, smoke test, or
  backtest was attempted.
- No portfolio gate, `T_Live` manifest, live terminal, deploy artifact, or
  AutoTrading state was touched.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this receipt.

This is distinct from the 13:32 UTC capacity receipt: the measurement window is
fresh and the live factory roster changed from T3/T4/T6/T7/T8 to T1/T4.

## Resume contract

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
only when both average and maximum are strictly below `97%`; then atomically
reconcile ownership of the existing `QM5_36005` forex handoff before resuming
it, or claim exactly one distinct highest-diversity eligible unit through the
farm DB.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260901T170106Z_board_advisor.json`.
