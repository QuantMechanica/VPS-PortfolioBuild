# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-11T03:00:22Z (05:00 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `50077147d8e47bb010ab7b1ac6e3415a2004edcc`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
the durable reconciliation in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for 66 relationships, with 66 covered and zero uncovered. Creating a
new scan-derived card or EA identity would duplicate governed work.

The preferred anchors do not have a Q02 setup defect to repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete existing-forex fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 market-neutral basket. Its sole logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, at attempt zero,
and has no verdict. It is already the non-duplicate queued successor, so no
second enqueue or redundant priority mutation was performed.

The package is hash-stable. Its logical backtest setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Binding CPU stop

The first fresh whole-host CPU sample was `100.000%`, above the binding `97%`
backtest ceiling. Free physical memory was `19.362 GiB`, also below the
documented `58 GiB` heavy-multisymbol admission threshold.

Four factory terminals were already testing: T1 and T3 held active
`OPT_CENSUS` work items, while T7 and T8 were pipeline runs. The separately
observed `T_Live` and FTMO processes were excluded and not controlled. The
paced launch cap in `D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`.

Per the mission's explicit stop condition, sampling stopped immediately. No
Q02 enqueue/requeue, priority mutation, dispatch tick, tester launch, terminal
reservation, compile enqueue, source change, or backtest followed. The
existing logical Q02 row remains available to a resident worker after CPU and
memory admission recover.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T030022Z_board_advisor.json`.

## PACER and safety

No MQ5 was generated or edited and no compile work was enqueued. A read-only
PACER audit of the fallback source passed with exit 0 and zero
`EA_FRAMEWORK_INPUT_PINNED` findings. The source remains unchanged with
SHA-256
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.
