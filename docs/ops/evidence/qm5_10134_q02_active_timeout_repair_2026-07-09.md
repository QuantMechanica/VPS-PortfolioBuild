# QM5_10134 Q02 Active-Timeout Repair — 2026-07-09

## Scope

EA: `QM5_10134_bb-double`

Reason: repeated Q02 incomplete reports / active-timeout symptoms on D1 FX rows, including `GBPAUD.DWX`, with tester logs showing terminal launch and incomplete report publication rather than a preflight artifact failure.

## Change

- Moved the news gate below trade management and strategy exit, so management and exits continue during news windows.
- Latched `QM_IsNewBar(_Symbol, strategy_timeframe)` once per tick and reused it for both exit and entry.
- Restricted the Bollinger exit calculation to the latched D1 closed-bar edge instead of recomputing band readers every tick.
- Zeroed `QM_EntryRequest` before strategy population.

## Evidence

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10134_bb-double` -> PASS.
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_10134_bb-double` -> PASS, 0 errors, 0 warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260709_155111.json`.
- `pwsh -File framework/scripts/compile_one.ps1 -EALabel QM5_10134_bb-double` -> PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260709_155133\QM5_10134_bb-double.compile.log`.
- Compile summary: `D:\QM\reports\compile\20260709_155133\summary.csv`.
- Compiled binary: `C:\QM\repo\framework\EAs\QM5_10134_bb-double\QM5_10134_bb-double.ex5`.

## Queue Action

Claimed pending Q02 rows during repair:

- `03ca62c1-e3ca-4aa7-94b5-b7a6a7ed9297`
- `93bfbdc9-ad71-460f-9604-d63942323bfc`
- `1467ddc6-493b-44bf-aa2b-f0cf000e5d3b`

Released them back to `pending` after compile PASS with `requeue_reason=q02_active_timeout_hot_path_exit_newbar_repair`.

No T_Live, deploy manifest, portfolio gate, or AutoTrading state was touched.
