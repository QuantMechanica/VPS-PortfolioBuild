# Diversity funnel hard CPU stop

Date: 2026-09-01 UTC (`2026-09-01T13:32:10Z`); 2026-09-01 15:32
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `af64044f65`

Status: stopped before candidate selection, farm claim, build, infrastructure
repair, compile, smoke, or Q02 enqueue because the explicit backtest CPU
ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at two-second intervals,
was `95.0%`, `97.7%`, `93.5%`, `94.9%`, and `99.1%`. Average utilization was
`96.0%`; maximum utilization was `99.1%`. The paced-fleet stop rule binds when
either measure is at least `97%`, so the maximum triggered the stop.

The read-only farm snapshot immediately before the sample reported five active
and 70 pending `build_ea` tasks. `farmctl mt5-slots` reported active factory
tester processes on T3, T4, T6, T7, and T8. No task or work item was claimed or
advanced, and no Q02 row was created or changed.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at preflight; no approved Card,
  EA source, binary, setfile, registry row, magic row, or resolver was changed.
- The farm DB and terminal-slot state were inspected read-only. No farm DB
  write, queue mutation, terminal action, worker action, compile, smoke test, or
  backtest was attempted.
- No portfolio gate, `T_Live` manifest, live terminal, deploy artifact, or
  AutoTrading state was touched.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this receipt.

## Resume contract

On a later paced wake, take a fresh five-sample whole-host CPU window. Proceed
only when both average and maximum are strictly below `97%`; then reconcile the
farm DB and claim exactly one distinct highest-diversity approved build
candidate before entering the standard non-live V5 build and Q02 handoff.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260901T133210Z_board_advisor.json`.
