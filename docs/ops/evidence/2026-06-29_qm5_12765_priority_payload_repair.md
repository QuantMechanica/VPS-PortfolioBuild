# QM5_12765 GBPUSD/NZDUSD Q02 Priority Payload Repair

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

Mission fallback path. The strict FX cointegration survivors `QM5_12532` and
`QM5_12533` already have logical-basket Q02 PASS rows, and the allocated
EdgeLab FX cointegration registry/card set currently extends through
`QM5_12772`, so this pass advanced an existing forex basket rather than
building a duplicate or unallocated pair.

Selected basket: `QM5_12765_edgelab-gbpusd-nzdusd-cointegration`, the rank-19
exploratory GBPUSD/NZDUSD tail candidate from the same 66-pair scan rerun.

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
or live manifest files were touched. No manual MT5 backtest was launched.

## Validation

Build validation before queue mutation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12765_edgelab-gbpusd-nzdusd-cointegration -RepoRoot C:/QM/repo -SkipCompile
```

Result:

| Field | Value |
|---|---|
| Report | `D:/QM/reports/framework/21/build_check_20260629_113118.json` |
| Result | `PASS` |
| Failures | `0` |
| Warnings | `16` existing shared-framework DWX advisory warnings |

The check confirmed the logical backtest setfile hash and risk mode. The
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12765_priority_payload_20260629T113200Z.sqlite`

Runtime multisymbol hint backup before mutation:

`D:/QM/strategy_farm/state/backups/multisymbol_eas_before_qm5_12765_20260629T113200Z.txt`

Updated the existing pending Q02 row in place:

| Field | Value |
|---|---|
| Work item | `735a3ca6-6012-4897-8603-9ec5353b11d9` |
| EA | `QM5_12765` |
| Symbol | `QM5_12765_GBPUSD_NZDUSD_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_12765_edgelab-gbpusd-nzdusd-cointegration/sets/QM5_12765_edgelab-gbpusd-nzdusd-cointegration_QM5_12765_GBPUSD_NZDUSD_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `GBPUSD.DWX`, `D1` |
| Basket symbols | `GBPUSD.DWX`, `NZDUSD.DWX` |
| Payload scope | `portfolio_scope=basket` |
| Risk | `RISK_FIXED=1000`, `tester_currency=USD`, `tester_deposit=100000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |
| Status after repair | `pending`, `claimed_by=NULL` |

Added `QM5_12765` to
`D:/QM/strategy_farm/state/multisymbol_eas.txt` for older worker runtime
guards.

## Verification

Read-back checks after mutation:

| Check | Result |
|---|---|
| Pending/active duplicate count for same EA/phase/logical symbol | `1` |
| `portfolio_scope` | `basket` |
| `basket_symbol_count` | `2` |
| `priority_track` | `true` |
| `tester_deposit` | `100000` |
| Runtime multisymbol hint | `QM5_12765` present |

The paced fleet still owns Q02 execution.
