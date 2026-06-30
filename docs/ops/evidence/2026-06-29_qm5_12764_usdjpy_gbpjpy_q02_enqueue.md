# QM5_12764 USDJPY/GBPJPY Q02 Enqueue - 2026-06-29

## Scope

- Mission: grow the V5 book with non-duplicate FX market-neutral cointegration sleeves.
- Original strict survivors `QM5_12532` and `QM5_12533` were checked first; both already have logical-basket Q02 PASS records and are not currently blocked by ONINIT or NO_HISTORY.
- The next available existing forex cointegration basket on this branch was `QM5_12764_edgelab-usdjpy-gbpjpy-cointegration`, the rank-18 OOS-positive tail pair from the same 66-pair scan rerun.

## Build Evidence

- Pair: `USDJPY.DWX` / `GBPJPY.DWX`.
- Logical symbol: `QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1`.
- Build task: `6876bf40-5fd9-4445-a7b4-b658b895fb88`.
- Compile command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration.mq5 -Strict`.
- Compile result: `PASS`, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260629_015145\QM5_12764_edgelab-usdjpy-gbpjpy-cointegration.compile.log`.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260629_015202.json`.
- Build-check result: `PASS`, 0 failures, 16 pre-existing shared-framework advisory warnings.
- Build result: `D:\QM\strategy_farm\artifacts\builds\6876bf40-5fd9-4445-a7b4-b658b895fb88.json`.

## Q02 Enqueue

`farmctl record-build` inserted exactly one logical-basket Q02 work item:

| Field | Value |
|---|---|
| work_item_id | `dea115dd-02b5-4c27-a29f-98013541fc3c` |
| ea_id | `QM5_12764` |
| phase | `Q02` |
| status | `pending` |
| symbol | `QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1` |
| host_symbol | `USDJPY.DWX` |
| tester_currency | `USD` |
| setfile | `framework/EAs/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration/sets/QM5_12764_edgelab-usdjpy-gbpjpy-cointegration_QM5_12764_USDJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |

No per-leg Q02 fanout was created. No `T_Live`, AutoTrading, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution artifact was touched.

## 2026-06-30 Q02 Payload Repair

The existing Q02 row remained pending behind the ordinary Q02 pool while newer
basket rows already carried priority and timeout hints. The row was repaired in
place; no duplicate Q02 item was inserted.

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12764_priority_payload_20260630T013333Z.sqlite`

Runtime multisymbol hint backup before mutation:

`D:/QM/strategy_farm/state/backups/multisymbol_eas_before_qm5_12764_20260630T013333Z.txt`

Read-back after mutation:

| Field | Value |
|---|---|
| work_item_id | `dea115dd-02b5-4c27-a29f-98013541fc3c` |
| status | `pending` |
| claimed_by | `NULL` |
| duplicate pending/active rows for same EA/phase/logical symbol | `1` |
| portfolio_scope | `basket` |
| priority_track | `true` |
| timeout_min | `120` |
| tester_currency / tester_deposit | `USD` / `100000` |
| risk_fixed | `1000` |
| basket_symbols | `USDJPY.DWX`, `GBPJPY.DWX` |
| conversion_history_symbols | `USDJPY.DWX` |
| runtime multisymbol hint | `QM5_12764` present |

Post-repair build validation:

| Check | Result |
|---|---|
| command | `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12764_edgelab-usdjpy-gbpjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile` |
| report | `D:/QM/reports/framework/21/build_check_20260630_013422.json` |
| result | `PASS` |
| failures | `0` |
| warnings | `16` existing shared-framework DWX advisories |
| setfile update | refreshed `build_hash` only; risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The paced fleet still owns execution. At repair time all five worker slots were
busy, including active `Q02` rows on `T1` and `T2`, so no manual MT5 launch was
attempted under the CPU-ceiling constraint.
