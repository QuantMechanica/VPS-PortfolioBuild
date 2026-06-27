# QM5_12723 NZDUSD/EURJPY Cointegration Q02 Enqueue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` and
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` remain the
controlling 66-pair FX cointegration scan artifacts.

Existing FX cointegration baskets found:

- `QM5_12532` AUDUSD/NZDUSD: Q02 `PASS`, later Q04 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: Q02 `PASS`, later Q04 `FAIL`.
- `QM5_12624` EURJPY/AUDJPY: Q02 `INFRA_FAIL` after log-bomb / CPU-disk ceiling.
- `QM5_12712` EURGBP/EURAUD: built and Q02 active under the paced fleet.

The strongest remaining unbuilt positive DEV/OOS scan candidate by OOS net
Sharpe was selected:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| NZDUSD~EURJPY | 0.06 | 0.68 | +8.02% | 21 | 0.04 | 115d |

This is explicitly sub-threshold versus the original OOS > 0.8 survivor bar, so
the card marks it as a high-risk exploratory sleeve. The source is Chan
cointegration pair-trading plus the OWNER-requested in-house scan; no ML, grid,
martingale, or banned indicators are used.

## Build

EA: `framework/EAs/QM5_12723_edgelab-nzdusd-eurjpy-cointegration`

Artifacts completed:

- Strategy card: `strategy-seeds/cards/edgelab-nzdusd-eurjpy-cointegration_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12723_edgelab-nzdusd-eurjpy-cointegration.md`
- Basket manifest:
  `framework/EAs/QM5_12723_edgelab-nzdusd-eurjpy-cointegration/basket_manifest.json`
- Logical Q02 setfile:
  `framework/EAs/QM5_12723_edgelab-nzdusd-eurjpy-cointegration/sets/QM5_12723_edgelab-nzdusd-eurjpy-cointegration_QM5_12723_NZDUSD_EURJPY_COINTEGRATION_D1_D1_backtest.set`
- Magic slots:
  - `12723, slot 0, NZDUSD.DWX, 127230000`
  - `12723, slot 1, EURJPY.DWX, 127230001`

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12723_edgelab-nzdusd-eurjpy-cointegration/QM5_12723_edgelab-nzdusd-eurjpy-cointegration.mq5 -Strict
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12723_edgelab-nzdusd-eurjpy-cointegration
```

Result: compile `PASS`; build_check `PASS` with 0 failures and the existing 16
framework include advisory warnings.

## Q02 Enqueue

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12723_q02_enqueue_20260627_185635Z.sqlite`

Inserted one non-duplicate logical-basket Q02 work item after confirming no
existing `QM5_12723` work items:

| Field | Value |
|---|---|
| Work item | `ccc72498-a291-44a7-baa9-8b60de27c0d7` |
| Parent task | `qm5-12723-initial-q02-enqueue-20260627_185635-ccc72498` |
| EA | `QM5_12723` |
| Symbol | `QM5_12723_NZDUSD_EURJPY_COINTEGRATION_D1` |
| Status | `pending` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | `USD` / `100000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |

No manual MT5 backtest was launched. At verification, all factory slots had
active `terminal64.exe` and `metatester64.exe` processes, so Q02 execution is
left to the paced terminal worker fleet.
