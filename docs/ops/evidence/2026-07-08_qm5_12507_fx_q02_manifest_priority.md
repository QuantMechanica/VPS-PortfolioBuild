# QM5_12507 EURUSD/GBPUSD FX Q02 Manifest Priority

Date: 2026-07-08
Branch: `agents/board-advisor`
Operator: Codex

## Action

Advanced the existing `QM5_12507_pair-coint-z` forex sleeve by repairing its
basket metadata and priority-marking the two already-pending FX Q02 rows in
place.

- Pair: `EURUSD.DWX` / `GBPUSD.DWX`
- Existing Q02 rows updated: `ff64c149-ba52-48b1-a024-59d910212583`,
  `b2cad7df-8f5c-44d6-8fa6-33c26dbc8a15`
- New work items inserted: none
- Basket manifest added:
  `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`
- DB backup before mutation:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12507_fx_q02_manifest_priority_20260708T160430Z.sqlite`

## Rationale

The strict FX cointegration anchors are not Q02-blocked: `QM5_12532` has Q02
PASS and later Q05 FAIL, while `QM5_12533` has Q02 PASS and later Q04 FAIL.
The extended-screen frontier is already built. `QM5_12507` still had pending
EURUSD/GBPUSD Q02 rows, but the EA is multi-leg and lacked a
`basket_manifest.json`; its pending rows also carried empty payloads.

The repair declares all four symbols warmed by the EA
(`EURUSD.DWX`, `GBPUSD.DWX`, `NDX.DWX`, `WS30.DWX`) while priority-routing only
the two FX rows requested by the portfolio mission.

## Verification

- The two FX Q02 rows remain `pending` and now have
  `priority_track=true`, `portfolio_scope=basket`, `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `from_date=2018.07.02`, `to_date=2024.12.31`,
  `tester_currency=USD`, and `timeout_min=450`.
- Queue snapshot after mutation: 6 active, 5,213 pending.
- Priority pending top included `QM5_12507` EURUSD and GBPUSD behind the
  pre-existing `QM5_12871` priority row.
- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q`:
  12 passed.
- `python tools/strategy_farm/validate_symbol_scope.py --ea QM5_12507_pair-coint-z`:
  `BASKET_OK`.
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_12507_pair-coint-z -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260708_160543.json`.

Guardrails: no manual MT5 dispatch, no duplicate Q02 insertion, no T_Live or
AutoTrading touch, and no portfolio gate / KPI / Q08 contribution mutation.

Machine-readable artifact:
`artifacts/qm5_12507_fx_q02_manifest_priority_20260708T160430Z.json`.
