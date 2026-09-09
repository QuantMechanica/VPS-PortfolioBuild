# FX cointegration fallback — QM5_12507 Q02 hard CPU stop

Date: 2026-09-09

Captured: `2026-09-09T17:01:36.5224758Z`

Branch: `agents/board-advisor`

Observation head: `b870457256e2d1d46cf6cc8dc840633313252de4`

## Outcome

The frozen, sign-aware 66-pair FX cointegration frontier remains fully
mechanized: the approved cointegration-card inventory contains no card without
an EA directory, and the durable reconciliation accounts for all 66
relationships. Creating another scan-derived Strategy Card or basket EA would
duplicate governed work.

The two preferred anchors require no Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has logical-basket Q02 `PASS`, Q04
  `PASS`, then Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has logical-basket Q02 `PASS`,
  then Q04 `FAIL`.

The permitted existing-card fallback is `QM5_12507_pair-coint-z`, the
low-frequency EURUSD/GBPUSD H1 basket. It is already built with a compiled
`.ex5`, `basket_manifest.json`, and a logical backtest setfile sealing
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Its one current
logical Q02 row, `547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains pending,
unclaimed, at attempt zero. No duplicate Q02 row was created.

## Binding CPU stop

The canonical farm query returned five active work items, all `OPT_CENSUS`,
below the configured active-row limit of seven. The independent whole-host CPU
gate nevertheless bound: five one-second samples were `100.000000%`,
`99.512025%`, `99.512024%`, `100.000000%`, and `99.609627%`. The average was
`99.726735%`, and the maximum exceeded the binding `97%` ceiling.

The path-aware slot snapshot observed four running factory terminals: `T2`,
`T4`, `T5`, and `T10`. `T_Live` was observed only to exclude it and was not
controlled.

Per the explicit CPU-ceiling stop rule, no queue mutation, dispatch tick,
tester launch, terminal control, compile, or backtest followed.

## PACER guard and safety

- No `.mq5` was generated or modified, so the mandatory post-write
  `audit_framework_input_pins.py --check-source` compile boundary was not
  entered.
- No compile or backtest work was enqueued and no existing work-item state was
  changed.
- No Strategy Card, EA source, binary, setfile, basket manifest, registry, or
  magic-number row changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated dirty-worktree changes were left untouched.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260909T170136Z_board_advisor.json`.
