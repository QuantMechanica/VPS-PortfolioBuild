# QM5_11241 EURUSD/GBPUSD Cointegration Q02 Priority

Date: 2026-07-08
Branch: `agents/board-advisor`
Operator: Codex

## Action

Advanced the existing low-frequency FX cointegration basket `QM5_11241`
(`EURUSD.DWX` / `GBPUSD.DWX`) by repairing the selected host setfile and
priority-marking the already-pending Q02 row in place.

- EA: `QM5_11241_ht-coint-spread`
- Pair: `EURUSD.DWX` / `GBPUSD.DWX`
- Logical row label: `QM5_11241_EURUSD_GBPUSD_COINT_D1`
- Work item: `e8bd1527-42dd-4c0a-9c20-14bc7358f4b7`
- Status after update: `pending`
- New work items inserted: none
- DB backup before mutation:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11241_eurusd_gbpusd_q02_priority_20260708T205108Z.sqlite`

## Decision Path

The controlling strict scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`; it names only
`QM5_12533` and `QM5_12532` as strict 66-pair survivors. Both are already built
and no longer Q02-blocked:

| EA | Pair | Current state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, later Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, later Q04 FAIL |

The only local cointegration card without a matching EA folder was
`chan-at-fx-coint-pair`. It is approved and has `ea_id=1026`, but preflight
found no `framework/registry/magic_numbers.csv` rows for the required FX legs.
Per the V5 build skill, the build was not attempted because magic allocation is
a CEO/CTO precondition.

## Repair Details

`QM5_11241` was selected as the non-duplicate fallback because it is D1,
market-neutral, has an approved spec, and already had a pending Q02 row for the
EURUSD/GBPUSD sleeve. The setfile now explicitly binds the host instance to:

- `strategy_partner_symbol=GBPUSD.DWX`
- `strategy_partner_slot=1`
- `strategy_formation_bars=504`
- `strategy_z_window=60`
- `strategy_entry_z=2.0`
- `strategy_exit_z=0.25`
- `RISK_FIXED=1000`
- `RISK_PERCENT=0`

The work-item payload now carries `priority_track=true`, `portfolio_scope=basket`,
`basket_symbols=["EURUSD.DWX","GBPUSD.DWX"]`, and a pair-scoped logical label.
The broad on-disk `basket_manifest.json` remains present, but the row payload is
pair-scoped so the worker does not need to claim unrelated XAU/XAG history for a
EURUSD/GBPUSD test.

## Verification

- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_11241_ht-coint-spread -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260708_205123.json`
- `python tools/strategy_farm/validate_symbol_scope.py --ea QM5_11241_ht-coint-spread --json`:
  `BASKET_OK`, `n_violations=0`
- DB check: exactly one pending `QM5_11241` / `Q02` / `EURUSD.DWX` row after the
  mutation.

No manual MT5 dispatch was launched. No `T_Live`, AutoTrading, deploy manifest,
portfolio admission gate, portfolio KPI, or Q08 contribution file was touched.

Machine-readable artifact:
`artifacts/qm5_11241_eurusd_gbpusd_q02_priority_20260708T205109Z.json`.
