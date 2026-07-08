# QM5_13058 AUDCAD/GBPNZD Cointegration Q02 Enqueue

Date: 2026-07-08
Branch: `agents/board-advisor`
Operator: Codex

## Action

Built `QM5_13058_audcad-gbpnzd-coint` as a new two-leg market-neutral FX
cointegration basket and auto-enqueued one logical Q02 work item.

- Pair: `AUDCAD.DWX` / `GBPNZD.DWX`
- Logical symbol: `QM5_13058_AUDCAD_GBPNZD_COINTEGRATION_D1`
- Work item: `df21c7a2-a0e2-467c-9be9-56f490d2e40d`
- Status after enqueue: `pending`
- Setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Basket manifest: `framework/EAs/QM5_13058_audcad-gbpnzd-coint/basket_manifest.json`

## Rationale

The strict 66-pair scan survivors, `QM5_12532` and `QM5_12533`, are already
built and no longer Q02-blocked. The stronger extended-screen siblings,
`QM5_13024` and `QM5_13029`, are also built and later failed Q04. The selected
pair is therefore a watchlist replacement candidate, not a strict survivor:
DEV net Sharpe 1.13, OOS net Sharpe 0.76, OOS return 7.94%, 22 OOS state
changes, 41 rolling-z excursions, and 76.5 day half-life.

## Verification

- `compile_one.ps1 -Strict`: PASS, compile log
  `framework/build/compile/20260708_093742/QM5_13058_audcad-gbpnzd-coint.compile.log`
- `build_check.ps1 -EALabel QM5_13058_audcad-gbpnzd-coint -SkipCompile`: PASS,
  report `D:/QM/reports/framework/21/build_check_20260708_093904.json`
- `validate_spec_doc.py`: PASS
- Q02 auto-enqueue source: `record-build` task
  `f65f1a83-3a20-43da-87ae-ac2e9a806d36`

## CPU Ceiling

No manual MT5 backtest was launched. Queue snapshot after enqueue showed six
active work items and 5,270 pending items, so the paced workers own Q02
dispatch.

Detailed machine-readable artifact:
`artifacts/qm5_13058_q02_enqueue_20260708.json`.
