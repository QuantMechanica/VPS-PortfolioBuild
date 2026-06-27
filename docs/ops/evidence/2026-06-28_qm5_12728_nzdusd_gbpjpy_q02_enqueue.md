# QM5_12728 NZDUSD/GBPJPY Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

The controlling source remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
plus `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`. The strict
66-pair scan survivors were already built as `QM5_12533` and `QM5_12532`.
Later exploratory positive DEV/OOS baskets were also already built as
`QM5_12624`, `QM5_12712`, and `QM5_12723`.

Rerunning the same D1 scan locally and excluding those existing builds selected
the next unbuilt positive DEV/OOS candidate:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| NZDUSD~GBPJPY | 0.05 | 0.60 | +6.88% | 21 | 0.04 | 116d |

This is explicitly sub-threshold versus the original OOS > 0.8 survivor bar, so
the card marks it as a high-risk exploratory sleeve. The source is Chan
cointegration pair-trading plus the OWNER-requested in-house scan; no ML, grid,
martingale, or banned indicators are used.

## Build

EA: `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration`

Artifacts completed:

- Strategy card: `strategy-seeds/cards/edgelab-nzdusd-gbpjpy-cointegration_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration.md`
- Basket manifest:
  `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/basket_manifest.json`
- Logical Q02 setfile:
  `framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/sets/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration_QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1_D1_backtest.set`
- Magic slots:
  - `12728, slot 0, NZDUSD.DWX, 127280000`
  - `12728, slot 1, GBPJPY.DWX, 127280001`

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration/QM5_12728_edgelab-nzdusd-gbpjpy-cointegration.mq5 -Strict
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12728_edgelab-nzdusd-gbpjpy-cointegration
```

Result: compile `PASS`; build_check `PASS` with 0 failures and the existing 16
framework include advisory warnings.

## Q02 Enqueue

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12728_q02_enqueue_20260627_235230Z.sqlite`

Inserted one non-duplicate logical-basket Q02 work item after confirming no
existing `QM5_12728` work items:

| Field | Value |
|---|---|
| Work item | `8ecabdc1-8f54-4eff-aa86-ddd4734ba1b0` |
| Parent task | `qm5-12728-initial-q02-enqueue-20260627_235230Z` |
| EA | `QM5_12728` |
| Symbol | `QM5_12728_NZDUSD_GBPJPY_COINTEGRATION_D1` |
| Status | `pending` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | `USD` / `100000` |
| Host | `NZDUSD.DWX`, `D1` |
| Payload scope | `portfolio_scope=basket` |

No manual MT5 backtest was launched. Q02 execution is left to the paced terminal
worker fleet.
