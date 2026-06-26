# QM5_12533 Launch-Guard Q02 Requeue - 2026-06-26

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` documents only two FX cointegration
pairs from the 66-pair scan that met the strict build threshold:

- `QM5_12533` EURJPY/GBPJPY D1 market-neutral cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD D1 market-neutral cointegration basket.

`QM5_12532` has already passed logical-basket Q02 and then produced a real Q04 low-frequency
strategy failure. The remaining blocked FX basket is `QM5_12533`, whose latest repaired Q02 row
failed before tester startup with a zero-output launch fault, not a strategy verdict.

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12533_launch_guard_requeue_20260626_203215.sqlite`

Inserted one non-duplicate logical-basket Q02 row under the existing pending parent task:

| Field | Value |
|---|---|
| Parent task | `f6c61664-fed0-4c14-9092-b6282d335079` |
| Work item | `e13e4576-f46d-446e-bd3a-ce70ec4ae9fd` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Host | `EURJPY.DWX`, `D1` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `timeout_min=120`, `priority_track=true` |
| Status | `pending` |

Superseded rows kept as evidence:

- `fe14e345-8ea4-4fbd-a77d-831df5fedc51` - logical Q02, `NO_HISTORY;INCOMPLETE_RUNS`.
- `ea488e29-a1b0-4c84-92eb-f1fdc5d06a0a` - logical Q02, `NO_HISTORY;INCOMPLETE_RUNS`.
- `2b530ac6-4de4-4eed-9e5e-a8da335ef9d5` - invalidated stale-worker row.
- `839c832e-127e-4548-b71f-61f255af16e5` - zero-output `INFRA_FAIL` launch fault.

Post-insert check confirmed this is the only `pending` or `active` row for the
`QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` target.

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile
```

Result: `PASS`, 0 failures, 16 existing framework include advisory warnings.

No backtest was launched manually. The paced terminal worker owns the pending Q02 row.
