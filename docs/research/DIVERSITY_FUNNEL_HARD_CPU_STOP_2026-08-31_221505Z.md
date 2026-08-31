# Diversity funnel hard CPU stop

Date: 2026-08-31 UTC (`2026-08-31T22:15:05Z`); 2026-09-01 00:15
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `64014b0591`

Status: stopped before farm-DB reconciliation, claim, build, infrastructure
repair, compile, smoke, or Q02 enqueue because the explicit backtest CPU
ceiling was binding.

## Binding capacity evidence

The mandatory five-sample whole-host window, sampled at two-second intervals,
was `85.46%`, `81.76%`, `78.46%`, `98.78%`, and `99.71%`. Average utilization
was `88.83%`; maximum utilization was `99.71%`. The paced-fleet stop rule binds
when either measure is at least `97%`, so the maximum triggered the stop.

The stop occurred before candidate selection or a farm claim. This avoids
colliding with another paced agent and avoids adding compile, smoke, or tester
load while the host is saturated. No Q02 work item was created or changed.

## Scope and safety

- The `qm-build-ea-from-card` workflow remained at preflight; no approved Card,
  EA source, binary, setfile, registry row, magic row, or resolver was changed.
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
`artifacts/diversity_funnel_hard_cpu_stop_20260831T221505Z_board_advisor.json`.
