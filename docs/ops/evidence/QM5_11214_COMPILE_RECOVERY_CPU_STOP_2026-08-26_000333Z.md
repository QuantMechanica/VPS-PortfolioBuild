# QM5_11214 compile recovery: CPU ceiling stop

**Observed:** 2026-08-26T00:03:33Z

**Branch:** `agents/board-advisor`

**Outcome:** `STOPPED_AT_EXPLICIT_BACKTEST_CPU_CEILING`

## Selected non-duplicate recovery

`QM5_11214_ft-clucmay` remains the highest-value diverse infrastructure
recovery identified in this run. Its approved fixed-rule basket is FX-first
(`EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`, with `XAUUSD.DWX` retained only
as the card's comparison sleeve), and its source-ready state is recorded in
`docs/ops/evidence/0252ecca_qm5_11214_ft_clucmay_source_ready_compile_hold_2026-08-25.md`.

A fresh read-only farm query returned zero work items for `QM5_11214`. Therefore
there is no Q02 or Q03 row to duplicate or claim. The next useful governed
action remains a single strict compile, review, and Q02 enqueue after capacity
is admitted.

## Binding capacity stop

Five whole-host CPU samples were `97.39%`, `99.90%`, `99.81%`, `100.00%`, and
`99.90%`. Their average was `99.40%` and their maximum was `100.00%`, above the
explicit `97%` ceiling. The mission's stop condition therefore bound before
any claim, compile, enqueue, terminal action, or backtest.

Machine-readable evidence is
`artifacts/qm5_11214_compile_recovery_cpu_stop_20260826T000333Z_board_advisor.json`.

## Safety

- The farm database was queried read-only.
- No source, card, EA, registry, magic row, or queue row was mutated.
- No terminal, tester, `T_Live`, AutoTrading, portfolio gate, or live manifest
  surface was touched.
- Concurrent unrelated worktree changes were preserved and will not be staged.
