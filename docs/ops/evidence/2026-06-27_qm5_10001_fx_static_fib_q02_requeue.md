# QM5_10001 FX Static Fib Q02 Requeue

Date: 2026-06-27
Agent: codex-board-advisor
Branch: agents/board-advisor

## Target

- EA: `QM5_10001_ff-static-fib-open`
- Asset gap: forex
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10001_ff-static-fib-open.md`
- Reason: built-but-stuck Q02 INFRA timeout cohort (`TIMEOUT`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`) on FX symbols.

## Fix

- Cached the EA's custom high-impact news blackout check once per chart bar instead of calling `QM_NewsInWindow` on every Model-4 tick.
- Rate-limited time-stop pending-order cancellation to once per chart bar.
- Added the required `SPEC.md` for Q01 reviewability.
- Regenerated backtest setfiles for `GBPUSD.DWX`, `EURUSD.DWX`, `USDJPY.DWX`, and `GBPJPY.DWX`.

## Verification

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10001_ff-static-fib-open` -> PASS.
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_10001_ff-static-fib-open` -> PASS, 0 failures.
- `pwsh -File framework/scripts/compile_one.ps1 -EALabel QM5_10001_ff-static-fib-open -Strict` -> PASS, 0 errors, 0 warnings.
- Direct smoke was deferred because the farm was already at the backtest CPU ceiling: 6 running MT5 terminals and 7 active work items at 2026-06-27T10:07Z.

## Farm State

Recorded build task: `1e0f8486-4193-4f89-8c06-59ef47e6f3d6`

`record-build` accepted `smoke_result=deferred_p2_smoke`, marked the task `done`, and auto-enqueued staged Q02:

| Work item | Symbol | Phase | Status |
|---|---|---|---|
| `64ffd2ce-36ba-43a4-ba9d-2b36d3b2f0e6` | `GBPUSD.DWX` | Q02 | pending |
| `f4165da9-5446-45f1-aa3a-98484b47360e` | `EURUSD.DWX` | Q02 | pending |
| `3e433c95-ddb4-437e-9a5d-70b323bfe12b` | `USDJPY.DWX` | Q02 | pending |

`GBPJPY.DWX` was deferred by the standard Q02 stage-1 symbol rule and remains represented in the generated setfiles.
