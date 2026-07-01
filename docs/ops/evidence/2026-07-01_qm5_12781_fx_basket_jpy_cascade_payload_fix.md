# QM5_12781 FX Basket JPY Cascade Payload Fix - 2026-07-01

## Scope

Branch: `agents/board-advisor`.

Mission constraints honored:

- No `T_Live` access.
- No AutoTrading change.
- No portfolio gate edits.
- No manual MT5 tester launch.
- No duplicate Q02 row inserted.

## Selection

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration source. The two strict survivors, `QM5_12532` and
`QM5_12533`, are no longer blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 `PASS`, Q04 `PASS`, Q05 currently
  blocked by stress-run timeout / CPU ceiling.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 `PASS`, later Q04 `FAIL`.

All registered EdgeLab FX cointegration pairs through `QM5_12803` already have
EA folders, `.ex5` artifacts, logical setfiles, and basket manifests. The
non-duplicate action was therefore to advance/fix the closest existing forex
basket lane.

`QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1` is the closest active FX basket:

- Q04 `PASS_SOFT`
- Q05 `PASS`
- Q06 `PASS`
- Q07 `INFRA_FAIL` from incomplete/missing seed evidence

## Fault

The existing Q07 log for work item `38226031-b41f-4f03-ab86-d1697ca5e203`
showed earlier seed runs using:

```text
-TesterCurrencyOverride USD -TesterDepositOverride 100000
```

The current basket manifest and logical setfile for `QM5_12781` require the JPY
account path:

```text
tester_currency=JPY
tester_deposit=15000000
RISK_FIXED=150000
```

A corrected logical-basket Q02 row already exists and is pending:

| Field | Value |
|---|---|
| Work item | `54c04ac1-e5f7-4060-ae60-6814cb930fd5` |
| Phase | Q02 |
| Status | pending |
| Symbol | `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1` |
| Host | `USDJPY.DWX`, D1 |
| Tester | `JPY`, deposit `15000000` |

Duplicate guard found this row, so no second Q02 enqueue was made.

## Change

`tools/strategy_farm/farmctl.py` now refreshes manifest-derived basket metadata
when promoting logical basket work items. This makes Q04/Q05/Q06/Q07 cascade
payloads inherit the current `basket_manifest.json` host symbol, basket symbols,
tester currency, and tester deposit instead of carrying stale parent payload
values.

Q02's extended basket timeout remains Q02-scoped; the manifest refresh does not
inject Q02 timeout metadata into later cascade payloads.

## Validation

Focused regression tests:

```powershell
python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_enqueue_q05_checks_basket_manifest_symbols_not_logical_symbol tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q05_runner_cmd_receives_latest_full_year_cap tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q06_runner_cmd_keeps_basket_logical_symbol tools/strategy_farm/tests/test_farmctl_cascade.py::CascadePromotionTests::test_q07_runner_cmd_keeps_basket_logical_symbol
```

Result: `4 passed`.

Manifest checks:

```powershell
python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py
```

Result: `5 passed`.

## Next

Let the pending corrected Q02 row run under the paced worker fleet. If it passes,
the fixed cascade payload path should carry the JPY tester account through the
later Q04/Q05/Q06/Q07 rows instead of recreating the stale USD-account path.
