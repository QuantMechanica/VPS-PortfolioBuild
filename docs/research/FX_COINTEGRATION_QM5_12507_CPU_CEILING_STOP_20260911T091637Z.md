# FX cointegration QM5_12507 CPU ceiling stop

Recorded: 2026-09-11T09:16:37Z (11:16 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `b47288f44510939c0d0eed4cf652b991ada665ce`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
66 relationships are covered and zero are unbuilt. A new Card, EA, registry
identity, basket manifest, or Q02 row would duplicate governed work.

The preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete existing-forex fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 market-neutral basket. Its sole logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was read directly from the farm database
as pending, unclaimed, attempt zero, verdict-free, and already
`priority_track=true`. No duplicate enqueue, requeue, priority mutation, or
payload rewrite was performed.

## Binding checks

The EA source remains hash-stable at
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.
The basket manifest and logical setfile are present, and the setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No `.mq5` was generated or modified. Therefore the PACER pre-compile audit was
not triggered in this run, no compile command was eligible, and no compile work
was enqueued. The unchanged source hash matches the immediately prior durable
receipt in which the PACER audit passed with zero
`EA_FRAMEWORK_INPUT_PINNED` findings.

## Hard CPU stop

Five one-second whole-host CPU samples were `98.439523%`, `95.912013%`,
`97.461393%`, `98.438264%`, and `94.438269%` (average `96.937892%`, maximum
`98.439523%`). The maximum exceeded the binding 97% ceiling.

Free physical memory was `39.899 GiB` of `63.120 GiB`, also below the
repository's `58 GiB` heavy-multisymbol admission floor. The path-aware scan
observed six factory testers on T1, T4, T5, T6, T7, and T8, ten unique worker
daemons, no duplicate workers, and no orphaned terminal processes.

Per the mission's explicit ceiling rule, work stopped before Q02 enqueue or
requeue, dispatch tick, tester launch, terminal reservation, terminal control,
or compile. The unique existing Q02 row remains available to the paced worker
after host admission recovers.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry row, or
  magic row changed.
- No work item, verdict, priority, claim, queue identity, tester, reservation,
  or terminal process changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  `T_Live`, deploy, AutoTrading, or live-manifest surface was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_cpu_ceiling_stop_20260911T091637Z_board_advisor.json`.
