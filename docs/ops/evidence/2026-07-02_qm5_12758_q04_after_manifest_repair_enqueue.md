# QM5_12758 Q04 After Manifest-Repair Enqueue

Date: 2026-07-02
Branch: `agents/board-advisor`

## Scope

Mission fallback path: advance an existing FX market-neutral cointegration
basket because the registered EdgeLab FX cointegration scan frontier is already
built through `QM5_12803`, and the strict survivors `QM5_12532` / `QM5_12533`
are not Q02-blocked.

Selected EA:

- EA: `QM5_12758_edgelab-gbpusd-euraud-cointegration`
- Pair: `GBPUSD.DWX` / `EURAUD.DWX`
- Conversion history: `AUDUSD.DWX`
- Logical basket: `QM5_12758_GBPUSD_EURAUD_COINTEGRATION_D1`
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Why This Row

`QM5_12758` had a June 30 manifest/payload repair that added `AUDUSD.DWX` as
the required USD conversion symbol for the EURAUD leg. That repaired Q02 row
completed `PASS`:

| Field | Value |
|---|---|
| Fresh Q02 work item | `200f7838-0cf3-456e-bc35-1db11c1db09c` |
| Fresh Q02 verdict | `PASS` |
| Fresh Q02 evidence | `D:\QM\reports\work_items\200f7838-0cf3-456e-bc35-1db11c1db09c\QM5_12758\20260630_215806\summary.json` |

The only Q04 row was older, from June 29, before that manifest/payload repair:

| Field | Value |
|---|---|
| Q04 work item | `9a3aa81f-cd10-4625-9c35-cde0addbbcd5` |
| Prior verdict | `FAIL` |
| Prior reason | `F1:pf_net=1.054;F2:pf_net=0.657;F3:pf_net=1.978` |
| Prior aggregate | `D:\QM\reports\work_items\9a3aa81f-cd10-4625-9c35-cde0addbbcd5\QM5_12758\Q04\QM5_12758_GBPUSD_EURAUD_COINTEGRATION_D1\aggregate.json` |

## Preflight

| Check | Result |
|---|---|
| `validate_symbol_scope.py --ea-label QM5_12758_edgelab-gbpusd-euraud-cointegration --verbose` | `BASKET_OK`, 0 violations |
| `build_check.ps1 -EALabel QM5_12758_edgelab-gbpusd-euraud-cointegration -RepoRoot C:/QM/repo -SkipCompile` | PASS, 0 failures |
| Build-check report | `D:\QM\reports\framework\21\build_check_20260702_000137.json` |
| Duplicate guard before enqueue | 0 pending/active Q04 rows |

Build-check warnings were the 16 existing shared-framework DWX advisory
warnings; no build-check failures.

## Queue Action

Command:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12758 --phase Q04
```

Result:

| Field | Value |
|---|---|
| Requeued work item | `9a3aa81f-cd10-4625-9c35-cde0addbbcd5` |
| Created rows | `0` |
| Status after | `pending` |
| Verdict after | `null` |
| Updated at | `2026-07-02T00:01:50+00:00` |
| Archived prior report root | `D:\QM\reports\work_items\9a3aa81f-cd10-4625-9c35-cde0addbbcd5.requeued_20260702T0001500000` |

Read-back after mutation:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12758
Q02 done PASS; Q02 done PASS; Q04 pending.
```

Payload retained the current basket context:

- `portfolio_scope`: `basket`
- `logical_symbol`: `QM5_12758_GBPUSD_EURAUD_COINTEGRATION_D1`
- `host_symbol`: `GBPUSD.DWX`
- `basket_symbols`: `GBPUSD.DWX`, `EURAUD.DWX`, `AUDUSD.DWX`
- `tester_currency`: `USD`
- `tester_deposit`: `100000`
- `q04_latest_full_year`: `2024`

## Safety

No manual MT5 tester run was launched; paced terminal workers own execution.
No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, Q08 contribution,
portfolio gate, or deploy manifest files were touched.

Machine-readable evidence:
`artifacts/qm5_12758_q04_after_manifest_repair_enqueue_20260702.json`.
