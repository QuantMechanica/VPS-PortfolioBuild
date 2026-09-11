# FX cointegration QM5_12507 hard-CPU stop

Recorded: 2026-09-11T23:16:02.4129883Z (2026-09-12 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `6a627ac4ac0d9bf2a89841b0e1ccdccfe032e5db`

## Outcome

The governed 66-pair FX cointegration frontier is already fully mechanized, so
creating another Strategy Card or EA would duplicate governed work. The two
preferred anchors are not Q02 infrastructure blockers:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The non-duplicate existing-forex fallback remains the EURUSD/GBPUSD H1 basket
`QM5_12507_pair-coint-z`. Its single logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was read directly from the canonical
farm database as pending, unclaimed, attempt zero, verdict-free, and already
`priority_track=true`. No second row was inserted and no existing queue field
was changed.

## PACER guard and artifact binding

No MQ5 source was generated or modified and no compile was requested. A fresh
read-only source audit nevertheless passed:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The logical backtest setfile remains in the required risk mode:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`

Current bindings:

- MQ5 SHA256: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5 SHA256: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- Basket manifest SHA256: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- Logical setfile SHA256: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Binding CPU ceiling

Five one-second whole-host CPU samples were `96%`, `100%`, `97%`, `100%`, and
`100%` (average `98.6%`, maximum `100%`). The mission's explicit 97% ceiling
therefore fired. Free physical memory was 37.652 GiB of 63.120 GiB.

The canonical farm held seven active and 7,096 pending work items. Six factory
terminals were running (`T1`, `T2`, `T4`, `T8`, `T9`, and `T10`). `T_Live`
was observed only to exclude it and was not controlled.

Per the mission contract, work stopped before any card/build change, compile
enqueue, Q02 enqueue or dispatch, tester launch, terminal reservation, or
terminal control. The unique pre-existing Q02 row remains available to the
resident paced workers after host admission recovers.

## Safety

- No Strategy Card, EA source, EX5, setfile, basket manifest, registry, magic
  row, queue identity, priority, claim, or verdict changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live`, AutoTrading state, or live artifact changed.
- Unrelated shared-worktree changes were preserved and excluded from this
  evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260911T231602Z_board_advisor.json`.
