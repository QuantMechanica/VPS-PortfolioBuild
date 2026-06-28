# QM5_12731 USDCAD/EURGBP Cointegration Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate or T_Live manifest edits.

## Decision

The controlling source remains `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
plus `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py`. The strict
66-pair scan survivors were already built as `QM5_12533` and `QM5_12532`.
Later exploratory positive DEV/OOS baskets were already built as `QM5_12624`,
`QM5_12712`, `QM5_12723`, and `QM5_12728`. `QM5_12731` was already built on
this branch and had no Q02 row, so this evidence records the non-duplicate
queue advancement.

Rerunning the same D1 scan locally identified this already-built pair as the
next positive DEV/OOS candidate after the earlier baskets:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDCAD~EURGBP | 0.46 | 0.57 | +3.50% | 19 | 0.49 | 57d |

This is below the original OOS > 0.8 survivor bar, so the card marks it as a
high-risk exploratory sleeve. The source is Chan cointegration pair-trading plus
the OWNER-requested in-house scan; no ML, grid, martingale, or banned indicators
are used.

## Existing Build

EA: `framework/EAs/QM5_12731_edgelab-usdcad-eurgbp-cointegration`

Artifacts completed:

- Strategy card: `strategy-seeds/cards/edgelab-usdcad-eurgbp-cointegration_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12731_edgelab-usdcad-eurgbp-cointegration.md`
- Basket manifest:
  `framework/EAs/QM5_12731_edgelab-usdcad-eurgbp-cointegration/basket_manifest.json`
- Logical Q02 setfile:
  `framework/EAs/QM5_12731_edgelab-usdcad-eurgbp-cointegration/sets/QM5_12731_edgelab-usdcad-eurgbp-cointegration_QM5_12731_USDCAD_EURGBP_COINTEGRATION_D1_D1_backtest.set`
- Magic slots:
  - `12731, slot 0, USDCAD.DWX, 127310000`
  - `12731, slot 1, EURGBP.DWX, 127310001`

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12731_edgelab-usdcad-eurgbp-cointegration/QM5_12731_edgelab-usdcad-eurgbp-cointegration.mq5 -Strict
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12731_edgelab-usdcad-eurgbp-cointegration
```

Result: compile `PASS`; build_check `PASS` with 0 failures and the existing 16
framework include advisory warnings. Build-check report:
`D:/QM/reports/framework/21/build_check_20260628_033436.json`.

## Q02 Enqueue

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12731_q02_enqueue_20260628_033612Z.sqlite`

Inserted one non-duplicate logical-basket Q02 work item after confirming no
existing `QM5_12731` rows:

| Field | Value |
|---|---|
| Work item | `fe6761c8-b431-421d-b3ee-74e8dc6618b9` |
| Parent task | `qm5-12731-initial-q02-enqueue-20260628_033612Z-fe6761c8` |
| EA | `QM5_12731` |
| Symbol | `QM5_12731_USDCAD_EURGBP_COINTEGRATION_D1` |
| Status at verification | `active`, claimed by `T3` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | `USD` / `100000` |
| Host | `USDCAD.DWX`, `D1` |
| Payload scope | `portfolio_scope=basket` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |

No manual MT5 backtest was launched. At verification, the farm had 5328 pending
Q02 rows and 2 active Q02 rows; Q02 execution is left to the paced terminal
worker fleet.
