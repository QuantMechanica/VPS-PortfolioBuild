# Diversity funnel CPU-ceiling stop

Date: 2026-09-02 UTC (`2026-09-02T21:16:04Z`); 2026-09-02 23:16
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `54602329b7`

Status: stopped before candidate selection, farm claim/resume, build,
infrastructure repair, compile, smoke, or Q02 enqueue because the explicit
backtest CPU ceiling was binding.

## Binding capacity evidence

The mandatory fresh five-sample whole-host window was `88.490057%`,
`92.903999%`, `100.0%`, `100.0%`, and `99.902546%`. Average utilization was
`96.259320%`; maximum utilization was `100.0%`. The paced-fleet stop rule binds
when either measure is at least `97%`, so the maximum independently triggered
the stop.

The live farm DB contained ten active work items: one Q07, one Q08, four
Q10_NEWS, and four OPT_CENSUS. The supported `farmctl mt5-slots` snapshot saw
factory terminal processes on T3, T4, T5, T6, and T9, with active reservations
also present on T2 and T8. A near-contemporaneous process count found ten
`terminal64` and eight `metatester64` processes. This transitional process/DB
topology is consistent with a saturated, actively rotating fleet and does not
create capacity for another tester-capable unit.

## Non-duplicate coordination value

This is a fresh observation relative to the 20:15 UTC diversity receipt. The
repository advanced from `0cb9f288e1` to `54602329b7`, the measurement ended
about one hour later, and the observed running factory roster changed from
T2-T10 to T3/T4/T5/T6/T9 while the DB showed all ten work-item claims active.
The receipt therefore records a distinct fleet transition rather than
repeating the earlier state.

## Scope and safety

- The `qm-build-ea-from-card` workflow stopped at capacity preflight. No card,
  EA source, binary, setfile, registry row, magic row, or resolver changed.
- Farm coordination and terminal-slot state were inspected read-only. No farm
  task or work item was claimed, advanced, enqueued, reprioritized, or changed.
- No compile, smoke, backtest, dispatch tick, terminal action, worker action, or
  retry was started.
- The portfolio gate, `T_Live`, AutoTrading, deploy manifests, and live
  manifests were untouched.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this commit.

## Resume contract

On a later paced wake, take a new five-sample whole-host CPU window. Proceed
only when both average and maximum are strictly below `97%`; then reconcile the
farm DB and atomically claim exactly one distinct highest-diversity eligible
unit before entering the standard non-live build/recovery and Q02 handoff.

Machine-readable evidence is
`artifacts/diversity_funnel_cpu_ceiling_stop_20260902T211604Z_board_advisor.json`.
