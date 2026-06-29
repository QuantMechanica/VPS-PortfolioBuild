# QM5_12766 USDJPY/USDCHF Q02 Priority Payload Repair

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

Mission fallback path. The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`; its strict FX
cointegration survivors, `QM5_12532` and `QM5_12533`, already have
logical-basket Q02 PASS rows. All currently carded EdgeLab FX cointegration
pairs found in `strategy-seeds/cards` have matching EA folders, so no
non-duplicate unbuilt carded pair was available.

Advanced existing forex basket: `QM5_12766` USDJPY/USDCHF cointegration, a
rank-20 exploratory tail candidate from the same 66-pair scan rerun.

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
or live manifest files were touched. No manual MT5 backtest was launched.

## Validation

Build validation before queue mutation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12766_edgelab-usdjpy-usdchf-cointegration -RepoRoot C:/QM/repo -SkipCompile
```

Result:

| Field | Value |
|---|---|
| Report | `D:/QM/reports/framework/21/build_check_20260629_104819.json` |
| Result | `PASS` |
| Failures | `0` |
| Warnings | `16` existing shared-framework DWX advisory warnings |

The check refreshed the backtest setfile `build_hash` only. The setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12766_priority_payload_20260629T104928Z.sqlite`

Runtime multisymbol hint backup before mutation:

`D:/QM/strategy_farm/state/backups/multisymbol_eas_before_qm5_12766_20260629T104928Z.txt`

Updated the existing pending Q02 row in place:

| Field | Value |
|---|---|
| Work item | `c097d38d-f428-4c8b-a90c-104d1e072c0d` |
| EA | `QM5_12766` |
| Symbol | `QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_12766_edgelab-usdjpy-usdchf-cointegration/sets/QM5_12766_edgelab-usdjpy-usdchf-cointegration_QM5_12766_USDJPY_USDCHF_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `USDJPY.DWX`, `D1` |
| Basket symbols | `USDJPY.DWX`, `USDCHF.DWX` |
| Payload scope | `portfolio_scope=basket` |
| Risk | `RISK_FIXED=1000`, `tester_currency=USD`, `tester_deposit=100000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |
| Status after repair | `pending`, `claimed_by=NULL` |

Added `QM5_12766` to
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
| Runtime multisymbol hint | `QM5_12766` present |

The paced fleet still owns execution. At the time of this repair, another FX
basket Q02 row (`QM5_12768`) was active, so this pass stopped at queue-state
repair and did not launch MT5 manually.
