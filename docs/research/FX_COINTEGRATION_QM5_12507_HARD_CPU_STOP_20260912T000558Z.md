# FX cointegration QM5_12507 hard-CPU stop

Recorded: 2026-09-12T00:05:58Z (02:05 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `24ac8132cb70ea47644a9f814899a4657fb88811`

## Outcome

The OWNER-requested 66-pair FX cointegration frontier remains fully
mechanized, so a new Strategy Card or EA identity would duplicate governed
coverage. The two preferred anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

The non-duplicate existing-forex fallback remains the EURUSD/GBPUSD H1 basket
`QM5_12507_pair-coint-z`. Its exact logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread from the canonical farm DB
as pending, unclaimed, attempt zero, verdict-free, and already
`priority_track=true`. It is still declared as a four-symbol dependency set
because the checked-in EA warms EURUSD, GBPUSD, NDX, and WS30. No duplicate
enqueue, requeue, priority mutation, or dependency understatement was made.

## PACER guard and artifact bindings

No MQ5 source was generated or modified and no compile work was requested. A
fresh precautionary audit of the selected source passed:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The logical backtest setfile remains in the required risk mode:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`

Current artifact bindings:

- MQ5 SHA256: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5 SHA256: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest SHA256: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile SHA256: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Binding CPU ceiling

Five one-second whole-host CPU samples were `99.219728%`, `97.170554%`,
`95.120805%`, `95.020111%`, and `98.243584%`. Their average was `96.954956%`
and their maximum was `99.219728%`, so the mission's explicit 97% ceiling
fired. Free physical memory was 34.983 GiB of 63.120 GiB.

At the final database read the farm held five active and 6,994 pending work
items. Factory MT5 terminals were running on T3, T4, and T10. `T_Live` was
observed only to exclude it and was not controlled.

Per the mission contract, work stopped before any Card/EA/manifest change,
compile enqueue, Q02 enqueue or dispatch, tester launch, terminal reservation,
or terminal control. The unique pre-existing Q02 row remains available to the
resident paced workers after host admission recovers.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface changed.
- No deploy manifest, `T_Live`, AutoTrading, or live artifact changed.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_hard_cpu_stop_20260912T000558Z_board_advisor.json`.
