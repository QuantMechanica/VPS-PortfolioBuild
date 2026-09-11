# FX cointegration QM5_12507 CPU ceiling stop

Recorded: 2026-09-11T08:33:00Z (10:33 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `452bbfdda8f685f47b5b96213cb7b6d40fadfa54`

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
`547c4fd3-f3fd-4c59-b9dc-654e96521251` remains pending, unclaimed, attempt
zero, verdict-free, and already `priority_track=true`. The governed priority
dry-run returned `already_priority_track=true`; no duplicate enqueue, requeue,
priority mutation, or payload rewrite was performed.

## Binding checks

The source is hash-stable at
`569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`.
The binding PACER audit passed with exit 0, `ok=true`, and zero
`EA_FRAMEWORK_INPUT_PINNED` findings:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
```

The basket-manifest regression also passed:

```text
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q -k qm5_12507
1 passed, 46 deselected
```

The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No `.mq5` was generated or modified, and no compile work
was eligible or enqueued.

## Hard CPU stop

Five one-second whole-host CPU samples were `95.021263%`, `97.274816%`,
`95.221871%`, `94.047861%`, and `92.969633%` (average `94.907089%`, maximum
`97.274816%`). The maximum exceeded the binding 97% ceiling.

Free physical memory was `43.611 GiB` of `63.120 GiB`, also below the
repository's `58 GiB` heavy-multisymbol admission floor. The path-aware scan
immediately before admission observed four factory testers on T2, T3, T7, and
T10. A post-stop scan showed the rotating fleet on T1 and T2, ten unique worker
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
`artifacts/fx_cointegration_qm5_12507_cpu_ceiling_stop_20260911T083300Z_board_advisor.json`.
