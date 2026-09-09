# Diversity funnel hard CPU stop

Date: 2026-09-09 UTC (`2026-09-09T10:15:14.5224283Z`); 2026-09-09 12:15
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `30d6dee8771378e797b1cf458443e2b543258ef9`

Status: stopped before farm-DB reconciliation, candidate selection, claim,
build, infrastructure repair, compile, smoke, or Q02 enqueue because the
explicit backtest CPU ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at two-second intervals,
was `100.0%`, `100.0%`, `100.0%`, `100.0%`, and `100.0%`. Average utilization
was `100.0%`; maximum utilization was `100.0%`. The paced-fleet stop rule binds
when either measure is at least `97%`, so both measures triggered the stop.

The samples came from
`Win32_PerfFormattedData_PerfOS_Processor` with `Name='_Total'`. The stop
occurred before candidate selection or a farm claim, avoiding collision with
another paced agent and avoiding further compile, smoke, or tester load while
the host was saturated.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at capacity preflight; no
  approved Card, EA source, binary, setfile, registry row, magic row, or
  resolver was changed.
- The PACER source-pin audit was not applicable because no source was written;
  no compile enqueue command was issued.
- No farm DB write, queue mutation, terminal action, worker action, compile,
  smoke test, or backtest was attempted.
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
`artifacts/diversity_funnel_hard_cpu_stop_20260909T101514Z_board_advisor.json`.
