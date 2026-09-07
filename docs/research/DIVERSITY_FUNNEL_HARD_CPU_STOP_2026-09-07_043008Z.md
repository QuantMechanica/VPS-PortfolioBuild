# Diversity funnel hard CPU stop

Date: 2026-09-07 UTC (`2026-09-07T04:30:08Z`); 2026-09-07 06:30
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `fa2593814d`

Status: stopped before candidate selection, farm claim, build, infrastructure
repair, compile enqueue, smoke, or Q02 enqueue because the explicit backtest
CPU ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at one-second intervals,
was `95.8%`, `94.6%`, `90.4%`, `91.1%`, and `98.1%`. Average utilization was
`94.0%`; maximum utilization was `98.1%`. The paced-fleet stop rule binds when
either measure is at least `97%`, so the maximum triggered the stop.

The read-only farm snapshot immediately before the sample reported six active
and 77 pending `build_ea` tasks. `farmctl mt5-slots` reported active factory
tester processes on T1, T5, T7, T8, and T9: four `OPT_CENSUS` items and one
Q07 item. The preceding diversity build `QM5_41374_xtixng-weffdiv-rv` already
has the distinct compile handoff `5621eafd-50aa-4974-93fc-be10f053b99d`, so it
was not claimed or duplicated. No task or work item was claimed or advanced,
and no Q02 row was created or changed.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at preflight; no approved Card,
  EA source, binary, setfile, registry row, magic row, or resolver was changed.
- Because no generated `.mq5` was written, the PACER source-pin audit and
  compile-enqueue boundary were not reached.
- The farm DB and terminal-slot state were inspected read-only. No farm DB
  write, queue mutation, terminal action, worker action, compile, smoke test,
  or backtest was attempted.
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
`artifacts/diversity_funnel_hard_cpu_stop_20260907T043008Z_board_advisor.json`.
