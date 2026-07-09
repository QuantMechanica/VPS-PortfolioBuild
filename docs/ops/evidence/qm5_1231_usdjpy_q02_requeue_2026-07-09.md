# QM5_1231 USDJPY Q02 Infra Requeue - 2026-07-09

## Unit

- EA: `QM5_1231_carver-pca-alpha`
- Sleeve: `USDJPY.DWX` / `D1`
- Source/card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1231_carver-pca-alpha.md`
- Rationale: approved Rob Carver cross-sectional PCA alpha card, D1, FX-major universe, expected 12 trades/year/symbol, `RISK_FIXED=1000` backtest setfile.

## Selection

- Avoided approved build backlog because the most diverse pending build cards were not clean build targets:
  - `QM5_1457_as-predict-bonds` and `QM5_1459_as-lumber-gold` require external/custom macro or futures series before a standard DWX build.
  - `QM5_13031_wayward-bbrsi-stopmr` is a high-frequency M15 scalper and lower priority for the current diversity/funnel mission.
- Avoided stale-row traps where logical replacement sleeves had already advanced or failed with a real strategy verdict (`QM5_12532`, `QM5_12533`, `QM5_10024`).
- Avoided `QM5_11916` because it already had pending Q02 rows from another agent.

## Diagnosis

- Farm DB before requeue had no `pending` or `active` rows for `QM5_1231`, and no Q03/Q04/Q05/Q08 rows.
- Latest `USDJPY.DWX` Q02 attempt before this work:
  - work item `1545f321-2855-4206-a112-4e5378820c75`
  - status `failed`, verdict `INFRA_FAIL`
  - final failure `summary_missing_retries_exhausted`
  - updated `2026-06-25T00:09:01+00:00`
- Current checked-in EA state was verified strict-clean after recompilation:
  - command: `powershell -ExecutionPolicy Bypass -File framework\scripts\build_check.ps1 -EALabel QM5_1231_carver-pca-alpha -Strict`
  - result: `PASS`, `failures=0`, `warnings=0`
  - report: `D:\QM\reports\framework\21\build_check_20260709_131216.json`

## Action

- Targeted dry run:
  - `python tools\strategy_farm\sweep_enqueue_built_eas.py --ea QM5_1231 --symbols USDJPY.DWX --max-infra-attempts 99 --max-part2-per-run 1`
  - proposed exactly one Q02 stranded-infra row for `USDJPY.DWX`.
- Applied targeted enqueue:
  - `python tools\strategy_farm\sweep_enqueue_built_eas.py --apply --ea QM5_1231 --symbols USDJPY.DWX --max-infra-attempts 99 --max-part2-per-run 1`
  - new work item `11937fe1-dea6-46b3-88bc-cd4859a431d1`
  - phase `Q02`, status `pending`, symbol `USDJPY.DWX`
  - setfile `C:\QM\repo\framework\EAs\QM5_1231_carver-pca-alpha\sets\QM5_1231_USDJPY.DWX_D1_backtest.set`

No T_Live, AutoTrading, portfolio gate, or T_Live manifest touched.
