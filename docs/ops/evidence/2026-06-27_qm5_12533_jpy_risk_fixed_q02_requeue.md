# QM5_12533 JPY Fixed-Risk Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. It documents only two strict-threshold survivors:

- `QM5_12533` EURJPY/GBPJPY D1 market-neutral cointegration basket.
- `QM5_12532` AUDUSD/NZDUSD D1 market-neutral cointegration basket.

No third unbuilt FX cointegration pair from that scan meets the documented build threshold
(`DEV > 0`, OOS net Sharpe > 0.8, and at least 4 OOS trades). Per the mission fallback,
this action advances the blocked `QM5_12533` basket instead of creating a weak duplicate.

## Root Cause

The latest logical-basket Q02 row before this repair was
`e9e4e602-77e2-441f-8709-a13ec0285496`.

It completed as a real MT5 run, not an `ONINIT` or `NO_HISTORY` failure:

- Status/verdict: `done` / `FAIL`.
- Summary: `MIN_TRADES_NOT_MET`.
- Total trades: `0`.
- Model: real ticks.
- Tester account currency in payload: `JPY`.

The `basket_manifest.json` correctly pins `tester_currency=JPY` for the EURJPY/GBPJPY
legs, but the logical basket setfile still used `RISK_FIXED=1000`. Under a JPY tester
account that is roughly 1/150 of the canonical USD 1000 backtest risk budget, causing
both leg volumes to fall below broker minimum lot and producing a false zero-trade Q02.

## Repair

Updated the logical basket backtest setfile:

`framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set`

- `set_version=s20260627-001`.
- `RISK_FIXED=150000`.
- Comment documents that `basket_manifest tester_currency=JPY`, so the value preserves
  the canonical USD 1000 fixed-risk budget in native tester currency.

Also updated `SPEC.md` with the Q02 risk-currency note and revision history entry.

Artifact commit: `9eca904d6` (`build: pump auto-commit 1 factory artifact path(s)`)
contains the `QM5_12533` `.ex5`, `SPEC.md`, and setfile changes listed above.

## Validation

- `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration.mq5 -Strict`
  - Result: `PASS`.
  - Errors: `0`.
  - Warnings: `0`.
  - Compile summary: `D:/QM/reports/compile/20260627_010505/summary.csv`.
  - Compile log: `framework/build/compile/20260627_010505/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration.compile.log`.

- `powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12533_edgelab-eurjpy-gbpjpy-cointegration -SkipCompile`
  - Result: `PASS`.
  - Failures: `0`.
  - Warnings: `16` existing framework include advisory warnings.
  - Report: `D:/QM/reports/framework/21/build_check_20260627_010530.json`.

No manual MT5 backtest was launched.

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_jpy_risk_q02_requeue_20260627_010933.sqlite`

Inserted one non-duplicate logical-basket Q02 row:

| Field | Value |
|---|---|
| Parent task | `0f7e0219-c799-4fde-b7a7-ca7ecdbb6bc9` |
| Work item | `6a3884da-336b-4903-85a3-45d00e9ab9bf` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Host | `EURJPY.DWX`, `D1` |
| Payload | `portfolio_scope=basket`, `tester_currency=JPY`, `risk_fixed=150000`, `timeout_min=120`, `priority_track=true` |
| Inserted status | `pending` |
| Enqueued UTC | `2026-06-27T01:09:33+00:00` |

The duplicate guard confirmed no existing `pending`, `active`, `claimed`, or `running`
Q02 row for the same EA/logical symbol before insertion. The immediate post-insert
check showed exactly one pending row for the target.

## CPU Ceiling

At enqueue time, factory MT5 slots were already busy with active `terminal64.exe` and
`metatester64.exe` processes across T1, T2, T3, T4, T5, and T7. The repair therefore
stopped at queue handoff and did not launch another tester process manually.
