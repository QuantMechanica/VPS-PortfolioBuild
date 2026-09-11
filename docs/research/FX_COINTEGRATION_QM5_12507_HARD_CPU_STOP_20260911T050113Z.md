# FX cointegration QM5_12507 hard CPU stop

Recorded: 2026-09-11T05:01:13Z (07:01 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `9fed18bcbbd28dae46412b0d44e39e7bcbe6f46a`

## Outcome

The frozen sign-aware 66-pair FX cointegration scan remains fully mechanized:
66 relationships are covered and zero are unbuilt. Creating a new Card, EA,
registry identity, basket manifest, or Q02 row would duplicate governed work.

The preferred anchors do not have a current Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then
  terminal Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then terminal
  Q04 `FAIL`.

The concrete existing-forex fallback remains `QM5_12507_pair-coint-z`, the
EURUSD/GBPUSD H1 market-neutral basket. Its sole logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
verdict-free, and already `priority_track=true`. Exactly one open work-item
identity exists for this EA, phase, and logical symbol. No duplicate enqueue,
requeue, priority mutation, or payload rewrite was performed.

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
`PORTFOLIO_WEIGHT=1`. No `.mq5` was generated or modified, so no compile work
was eligible or enqueued.

## Hard CPU stop

Five one-second whole-host CPU samples were `100.000%`, `99.806%`, `98.929%`,
`99.902%`, and `98.243%` (average `99.376%`, maximum `100.000%`). Both the
average and maximum exceeded the explicit 97% ceiling.

Free physical memory was `37.202 GiB` of `63.120 GiB`, also below the
repository's `58 GiB` heavy-multisymbol admission floor. Five factory testers
were active on T1, T5, T7, T8, and T9, while the serialized launch gate
remained `1`.

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
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T050113Z_board_advisor.json`.
