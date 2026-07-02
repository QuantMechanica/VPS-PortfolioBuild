# QM5_12871 Brent January Fade Q02 Enqueue

Date: 2026-07-02
Branch: agents/board-advisor
Farm task: `deefcb2f-ae5c-4d91-90d8-97228ef76e45`
EA: `QM5_12871_brent-jan-fade`

## Scope

Mechanized a new low-frequency energy sleeve: Brent January calendar fade on
`XBRUSD.DWX` D1. The edge is structural and source-backed by the Arendas et al.
oil month-of-year seasonality paper. It is distinct from WTI January, existing
Brent April/May/November/December calendar sleeves, Brent weekday sleeves,
Brent trend/anchor logic, WTI/Brent spread logic, XTI/XNG, XNG, XAU/XAG, and
`QM5_12567` commodity RSI logic.

No portfolio gate, deploy manifest, `T_Live`, or AutoTrading state was touched.
No manual MT5 backtest was launched; paced Q02 owns baseline execution.

## Build Artifacts

- Approved card:
  `artifacts/cards_approved/QM5_12871_brent-jan-fade.md`
- EA:
  `framework/EAs/QM5_12871_brent-jan-fade/QM5_12871_brent-jan-fade.mq5`
- Compiled binary:
  `framework/EAs/QM5_12871_brent-jan-fade/QM5_12871_brent-jan-fade.ex5`
- Fixed-risk backtest setfile:
  `framework/EAs/QM5_12871_brent-jan-fade/sets/QM5_12871_brent-jan-fade_XBRUSD.DWX_D1_backtest.set`
- Build result:
  `artifacts/qm5_12871_build_result.json`

## Verification

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12871_brent-jan-fade`
  - PASS
- `python tools/strategy_farm/compile_ea.py --ea-label QM5_12871_brent-jan-fade --force --json --fail-on-error`
  - COMPILED, errors 0, warnings 0
  - compile log:
    `C:\QM\repo\framework\build\compile\20260702_050653\QM5_12871_brent-jan-fade.compile.log`
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_12871_brent-jan-fade -Strict`
  - PASS, failures 0, warnings 16
  - warnings are the existing shared-framework DWX advisory warnings
  - report:
    `D:\QM\reports\framework\21\build_check_20260702_050653.json`

## Registry

- `framework/registry/ea_id_registry.csv`
  - `12871,brent-jan-fade,ARENDAS-OIL-SEASON-2018_BRENT_JAN_S02,active,Codex,2026-07-02`
- `framework/registry/magic_numbers.csv`
  - `12871,brent-jan-fade,0,XBRUSD.DWX,128710000,2026-07-02,Codex,active`

## Farm DB Update

Recorded build result:

- `D:\QM\strategy_farm\artifacts\builds\deefcb2f-ae5c-4d91-90d8-97228ef76e45.json`

Q02 work item created by `record_build_result.auto_q02`:

- Work item: `da441d49-ccac-477e-9bab-fa13a44a5e96`
- Phase: `Q02`
- Symbol: `XBRUSD.DWX`
- Timeframe: `D1`
- Status at enqueue: `pending`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_12871_brent-jan-fade\sets\QM5_12871_brent-jan-fade_XBRUSD.DWX_D1_backtest.set`
- Payload:
  `{"host_symbol":"XBRUSD.DWX","host_timeframe":"D1","enqueued_by":"record_build_result.auto_q02","build_task_id":"deefcb2f-ae5c-4d91-90d8-97228ef76e45"}`
