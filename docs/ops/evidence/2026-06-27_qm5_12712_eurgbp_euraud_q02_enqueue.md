# QM5_12712 EURGBP/EURAUD Cointegration Q02 Enqueue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The controlling FX cointegration scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

Strict-threshold survivors were already built:

- `QM5_12533` EURJPY/GBPJPY: logical-basket Q02 `PASS`, later Q04 `FAIL`.
- `QM5_12532` AUDUSD/NZDUSD: logical-basket Q02 `PASS`, later Q04 `FAIL`.

`QM5_12624` EURJPY/AUDJPY was already built as the first exploratory next-best
pair and hit the Q02 backtest CPU/log ceiling. To avoid duplicate work, this
pass advanced the next unbuilt positive DEV/OOS pair from the same D1 scan:

| pair | DEV Sharpe | OOS net Sharpe | OOS ret | OOS state changes | hedge | half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURGBP~EURAUD | 0.66 | 0.62 | +3.54% | 25 | 0.31 | 40d |

## Build

EA: `framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration`

Artifacts completed:

- Strategy card: `strategy-seeds/cards/edgelab-eurgbp-euraud-cointegration_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12712_edgelab-eurgbp-euraud-cointegration.md`
- Basket manifest:
  `framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/basket_manifest.json`
- Logical Q02 setfile:
  `framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/sets/QM5_12712_edgelab-eurgbp-euraud-cointegration_QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1_D1_backtest.set`
- Magic slots:
  - `12712, slot 0, EURGBP.DWX, 127120000`
  - `12712, slot 1, EURAUD.DWX, 127120001`

Validation:

```powershell
framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/QM5_12712_edgelab-eurgbp-euraud-cointegration.mq5 -Strict
framework/scripts/build_check.ps1 -EALabel QM5_12712_edgelab-eurgbp-euraud-cointegration
```

Result: compile `PASS`; build_check `PASS` with 0 failures and the existing 16
framework include advisory warnings.

## Q02 Enqueue

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12712_q02_enqueue_20260627_175707Z.sqlite`

Inserted one non-duplicate logical-basket Q02 row after confirming no existing
`QM5_12712` work items:

| Field | Value |
|---|---|
| Work item | `dcc9e3f9-0639-4423-b6e2-ddd03c0188a6` |
| Parent task | `qm5-12712-initial-q02-enqueue-20260627_175736-dcc9e3f9` |
| EA | `QM5_12712` |
| Symbol | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| Status | inserted as `pending`; observed `active`, `claimed_by=T6` at `2026-06-27T17:59:01+00:00` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Tester currency/deposit | `USD` / `100000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |

No manual MT5 backtest was launched. The paced terminal worker fleet owns Q02
execution.
