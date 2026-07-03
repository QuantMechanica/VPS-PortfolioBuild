# QM5_12918 Q02 ONINIT Calendar Repair

Date: 2026-07-03
Branch: agents/board-advisor
EA: QM5_12918_jegadeesh-1w-reversal-fx

## Decision

Priority 1 was exhausted for the highest-diversity approved forex build candidate found in the backlog: QM5_12978 was already built and already had a pending Q02 row. I therefore used priority 2 on QM5_12918, a built structural G10 FX reversal EA stuck at Q02 with INFRA-class ONINIT failures.

## Diagnosis

Three Q02 rows completed with INFRA_FAIL:

| Work item | Symbol | Reason |
|---|---|---|
| 6e06e8a2-0c55-4e8d-a88c-9a993f70baba | EURUSD.DWX | run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS |
| 2ec934d4-5383-41a4-80dd-5d2ac4d66caa | GBPUSD.DWX | run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS |
| 3797a3a8-6e1e-4525-8a87-dd2241d9258e | USDJPY.DWX | run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS |

The MT5 agent logs showed symbol history loaded before the tester stopped because `OnInit` returned non-zero code 1. The rate calendar file exists in both `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` and Common Files, so the likely defect was the loader using the raw setfile string, including literal quotes, for `QM_NewsBasename` and `FileOpen`.

## Repair

`Strategy_LoadRateDecisionWeeks()` now strips quotes from `strategy_rate_calendar_path` before basename and absolute `FileOpen` attempts. `OnInit` no longer aborts when the optional calendar load fails; the entry filter remains fail-closed through `Strategy_RateDecisionWeekBlocked()`.

Refreshed binary:

- `framework/EAs/QM5_12918_jegadeesh-1w-reversal-fx/QM5_12918_jegadeesh-1w-reversal-fx.ex5`
- SHA256: `5C1E3B35FD124E362A8F96BBDF5860C1D3EE04F800731BB1BEF5B95FCFEA2A38`

Validation:

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings, `framework/build/compile/20260703_020643/QM5_12918_jegadeesh-1w-reversal-fx.compile.log`
- `build_check.ps1 -Strict`: PASS, 0 failures, 16 existing shared-framework advisory warnings, `D:\QM\reports\framework\21\build_check_20260703_020643.json`
- `build_check.ps1 -Strict -SkipCompile` after evidence/SPEC updates: PASS, 0 failures, 16 existing shared-framework advisory warnings, `D:\QM\reports\framework\21\build_check_20260703_021105.json`

## Queue Action

No duplicate Q02 rows were inserted. The existing pending stranded-INFRA rows were annotated with `priority_track: true` and a repair payload; their `updated_at` values were preserved to avoid demoting FIFO order.

DB backup before annotation:

- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12918_oninit_calendar_repair_20260703T020839Z.sqlite`

Pending Q02 rows after annotation:

| Work item | Symbol | Status |
|---|---|---|
| 50b584ea-2351-4e0d-bacb-42d4e4fa8493 | EURUSD.DWX | pending |
| 517eba56-47d9-4c00-8eb7-3cb844d7924d | GBPUSD.DWX | pending |
| 12fe26b6-84be-45b0-a475-fd2697902e52 | USDJPY.DWX | pending |

No T_Live, AutoTrading, portfolio gate, or deploy manifest files were touched.
