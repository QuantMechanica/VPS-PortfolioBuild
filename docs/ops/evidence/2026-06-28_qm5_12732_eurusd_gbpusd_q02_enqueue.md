# QM5_12732 EURUSD/GBPUSD Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

The controlling source remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
plus `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`. The strict
66-pair scan survivors were already built as `QM5_12533` and `QM5_12532`.
Later exploratory positive DEV/OOS baskets were already built as `QM5_12624`,
`QM5_12712`, `QM5_12723`, `QM5_12728`, and `QM5_12731`.

Rerunning the same D1 scan locally and excluding those existing builds selected
the next unbuilt positive DEV/OOS candidate:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD~GBPUSD | 0.65 | 0.54 | +2.81% | 20 | 0.91 | 49d |

This is below the original OOS > 0.8 survivor bar, so the card marks it as a
high-risk exploratory sleeve. The source is Chan cointegration pair-trading plus
the OWNER-requested in-house scan; no ML, grid, martingale, or banned indicators
are used.

## Build

EA: `framework/EAs/QM5_12732_edgelab-eurusd-gbpusd-cointegration`

Artifacts completed:

- Strategy card: `strategy-seeds/cards/edgelab-eurusd-gbpusd-cointegration_card.md`
- Basket manifest:
  `framework/EAs/QM5_12732_edgelab-eurusd-gbpusd-cointegration/basket_manifest.json`
- Logical Q02 setfile:
  `framework/EAs/QM5_12732_edgelab-eurusd-gbpusd-cointegration/sets/QM5_12732_edgelab-eurusd-gbpusd-cointegration_QM5_12732_EURUSD_GBPUSD_COINTEGRATION_D1_D1_backtest.set`
- Magic slots:
  - `12732, slot 0, EURUSD.DWX, 127320000`
  - `12732, slot 1, GBPUSD.DWX, 127320001`

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12732_edgelab-eurusd-gbpusd-cointegration/QM5_12732_edgelab-eurusd-gbpusd-cointegration.mq5 -Strict
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12732_edgelab-eurusd-gbpusd-cointegration
```

Result: compile `PASS`; build_check `PASS` with 0 failures and the existing 16
framework include advisory warnings. Build-check report:
`D:/QM/reports/framework/21/build_check_20260628_034115.json`.

## Q02 Enqueue

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12732_q02_enqueue_20260628_034415Z.sqlite`

Inserted one non-duplicate logical-basket Q02 work item after confirming no
existing `QM5_12732` rows:

| Field | Value |
|---|---|
| Work item | `a8c74944-5252-4ce6-839c-abe0065bb953` |
| Parent task | `qm5-12732-initial-q02-enqueue-20260628_034415Z-a8c74944` |
| EA | `QM5_12732` |
| Symbol | `QM5_12732_EURUSD_GBPUSD_COINTEGRATION_D1` |
| Status at verification | `active`, claimed by `T2` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | `USD` / `100000` |
| Host | `EURUSD.DWX`, `D1` |
| Payload scope | `portfolio_scope=basket` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |

No manual MT5 backtest was launched. At verification, the farm had 5328 pending
Q02 rows and 2 active Q02 rows; Q02 execution is left to the paced terminal
worker fleet.
