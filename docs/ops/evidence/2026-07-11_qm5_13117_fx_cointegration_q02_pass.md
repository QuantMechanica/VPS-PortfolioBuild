# QM5_13117 EURGBP/AUDJPY Q02 PASS and Q03 Handoff

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing market-neutral FX cointegration basket; no live or
portfolio-gate action.

## Selection

The sign-aware reproduction of the OWNER-requested 66-pair scan has seven
strict rows. All seven now have EA builds, including the two original anchors:

- `QM5_12532` AUDUSD/NZDUSD is not Q02-blocked: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY is not Q02-blocked: Q02 PASS, Q04 FAIL.
- The final unbuilt frontier rows were already mechanized as `QM5_13117`
  EURGBP/AUDJPY and `QM5_13119` USDJPY/EURAUD.

Per the mission fallback, this pass advanced the higher-ranked existing
frontier basket, `QM5_13117` EURGBP/AUDJPY, instead of creating a duplicate or
weakening the research threshold.

## Build and Risk Preflight

- Pre-run and post-handoff build checks: `PASS`, zero failures and zero
  warnings.
- Reports: `D:/QM/reports/framework/21/build_check_20260710_225029.json` and
  `D:/QM/reports/framework/21/build_check_20260710_235335.json`.
- EX5 SHA256:
  `477530fc2c9d1ce5b8b8b321e6b0e68f746735b4f6e4d4205f370aa68d881d9d`.
- The Q02 execution used setfile build hash
  `926a3fcc36950f8cb148451d56d01c93999996c15e434c8712872b59a42e8e3f`.
  After the card history was synchronized, the final canonical setfile hash
  was refreshed to
  `2f1e358766a53521b6be73097b33a746a2a4fb68bfdec2a9473b62d42c03e796`.
- Setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, `environment=backtest`.
- `basket_manifest.json` declares EURGBP/AUDJPY as traded legs and
  GBPUSD/USDJPY as USD-account conversion dependencies.

## Serialized-Runner Recovery

The first targeted claim correctly stopped at the global multi-symbol guard.
The blocking `QM5_1058` Q07 row had no live T1 process and already had a final
aggregate. The normal worker classifier closed that orphan as `INFRA_FAIL`
from its recorded seed timeout evidence; it was not bypassed or re-run.

- DB backup before classification:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_target_q02_20260710T225211Z.sqlite`.
- Classified row: `82c0189f-f4a7-4e3f-ac76-79b38037bacb`.
- Evidence:
  `D:/QM/reports/work_items/82c0189f-f4a7-4e3f-ac76-79b38037bacb/QM5_1058/Q07/QM5_1058_EURUSD_GBPUSD_GGR_D1/aggregate.json`.

T5 then failed before EA initialization because its tester account was not
specified. The exact wrapper was stopped only after all T5 MT5 processes had
exited. The original Q02 row returned to pending at attempt 1, T5 was added to
that row's `avoid_terminals`, and no duplicate row was inserted.

- T5 evidence:
  `D:/QM/reports/work_items/ed75430e-2ff4-4ea1-9d50-e49a7912d323/QM5_13117/20260710_225219/raw/run_01/20260711.log`.

This exposed a compatibility defect in
`terminal_worker._smoke_terminal_exit_stalled`: the guard recognized only
legacy `P2/P3` keys, not canonical `Q02/Q03`. The guard now accepts both Q- and
legacy aliases. A focused regression test covers Q02, Q03, P2, P3, and the Q04
non-match.

Verification:

- `python -m unittest tools.strategy_farm.tests.test_terminal_worker_q_phase_stall`: PASS (1 test).
- `python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim`: PASS (34 tests).

## Q02 Result

The same unique work item was retried through the targeted Factory-OFF worker
on recently authorized T3. It ran the full Model-4 real-tick window from
2018-07-02 through 2022-12-31 and passed.

| Field | Value |
|---|---:|
| Work item | `ed75430e-2ff4-4ea1-9d50-e49a7912d323` |
| Logical symbol | `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1` |
| Terminal | T3 |
| Status / verdict | `done` / `PASS` |
| Tester trades | 104 |
| Profit factor | 1.75 |
| Net profit | 6,582.67 |
| Drawdown | 3,049.81 (2.82%) |
| ONINIT failure | false |
| Real-tick marker | true |
| Log bomb | false |

Canonical evidence:
`D:/QM/reports/work_items/ed75430e-2ff4-4ea1-9d50-e49a7912d323/QM5_13117/20260710_230457/summary.json`.

## Q03 Handoff

Because the original standalone Q02 row had no parent task, its PASS could not
auto-cascade. After an online SQLite backup, one guarded Q03 successor was
inserted with inherited basket, conversion, date-window, RISK_FIXED, T5-avoid,
and priority context:

- Q03 work item: `dc01fd4d-0f8f-414a-a6b1-80441204fefc`.
- Parent task: `caf51649-e9fa-4db9-ba79-53632a514992`.
- Status: `pending`.
- DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_q03_enqueue_20260710T235125Z.sqlite`.
- Duplicate guard: exactly one Q03 row exists for this EA/logical symbol/setfile.

Factory_OFF remained in force, so the Q03 row was not launched by this pass.

## Safety

- No `T_Live` path or process was read or changed for execution control.
- AutoTrading was not toggled.
- No live setfile or deploy manifest was created or changed.
- No portfolio gate, `portfolio_admission`, `_kpi`, or `_q08_contribution`
  path was touched.
- The backtest CPU ceiling was not reached; only one new basket job ran.
