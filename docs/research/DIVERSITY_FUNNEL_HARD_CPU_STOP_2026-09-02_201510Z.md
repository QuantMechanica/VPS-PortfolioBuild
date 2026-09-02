# Diversity funnel hard CPU stop

Date: 2026-09-02 UTC (`2026-09-02T20:15:10Z`); 2026-09-02 22:15
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `0cb9f288e1`

Status: stopped before candidate selection, farm claim/resume, build,
infrastructure repair, compile, smoke, or Q02 enqueue because the explicit
backtest CPU ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at two-second intervals,
was `88.0%`, `100.0%`, `100.0%`, `100.0%`, and `100.0%`. Average utilization
was `97.6%`; maximum utilization was `100.0%`. The paced-fleet stop rule binds
when either measure is at least `97%`, so both the average and maximum triggered
the stop.

The farm coordination snapshot reported 34 approved `build_ea` tasks and no
`build_ea` task in progress. `farmctl mt5-slots` found all ten factory slots
reserved and active tester processes on T2 through T10. The active work included
Q07, Q10_NEWS, OPT_CENSUS, and a separate pipeline run. No task or work item was
claimed or advanced, and no Q02 row was created or changed.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at capacity preflight; no
  approved Card, EA source, binary, setfile, registry row, magic row, or resolver
  was changed.
- Farm coordination and terminal-slot state were inspected. No farm work claim,
  queue mutation, terminal action, worker action, compile, smoke test, or
  backtest was attempted.
- No portfolio gate, `T_Live` manifest, live terminal, deploy artifact, or
  AutoTrading state was touched.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this receipt.

This receipt is non-duplicate relative to the 2026-09-01 17:01 UTC capacity
receipt: the measurement window is next-day fresh and the live factory roster
changed from T1/T4 to T2-T10.

## Resume contract

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
only when both average and maximum are strictly below `97%`; then reconcile the
farm DB and atomically claim exactly one distinct highest-diversity eligible
unit before entering the standard non-live build/recovery and Q02 handoff.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260902T201510Z_board_advisor.json`.
