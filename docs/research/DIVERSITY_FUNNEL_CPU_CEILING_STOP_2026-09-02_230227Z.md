# Diversity funnel CPU-ceiling stop

Date: 2026-09-02 UTC (`2026-09-02T23:02:27Z`); 2026-09-03 01:02
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7d13829a1f`

Status: stopped before candidate selection, farm claim/resume, build,
infrastructure repair, compile, smoke, or Q02 enqueue because the explicit
backtest CPU ceiling was binding.

## Binding capacity evidence

The mandatory fresh five-sample whole-host window was `99.663693%`,
`98.376470%`, `100.000000%`, `98.864119%`, and `99.905341%`. Average
utilization was `99.361925%`; maximum utilization was `100.000000%`. The
paced-fleet stop rule binds when either measure is at least `97%`, so both
measures independently triggered the stop.

The live farm DB contained nine active work items: one Q05, two Q07, three
Q10_NEWS, and three OPT_CENSUS. The supported `farmctl mt5-slots` snapshot saw
factory terminal processes on T1, T2, T3, T4, T5, T7, T9, and T10, with active
reservations also present on T8. A near-contemporaneous process count found
eleven `terminal64` and nine `metatester64` processes. This transitional
process/DB topology is consistent with a saturated, actively rotating fleet
and does not create capacity for another tester-capable unit.

## Non-duplicate coordination value

This is a fresh observation relative to the 21:16 UTC diversity receipt. The
repository advanced from `54602329b7` to `7d13829a1f`, the measurement ended
about one hour and forty-six minutes later, active work moved from ten rows to
nine, and the running factory roster changed from T3/T4/T5/T6/T9 to
T1/T2/T3/T4/T5/T7/T9/T10. The receipt therefore records a distinct fleet
transition rather than repeating the earlier state.

## Scope and safety

- The `qm-build-ea-from-card` workflow stopped at capacity preflight. No card,
  EA source, binary, setfile, registry row, magic row, or resolver changed.
- Farm coordination and terminal-slot state were inspected read-only. No farm
  task or work item was claimed, advanced, enqueued, reprioritized, or changed.
- No compile, smoke, backtest, dispatch tick, terminal action, worker action,
  or retry was started.
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
`artifacts/diversity_funnel_cpu_ceiling_stop_20260902T230227Z_board_advisor.json`.
