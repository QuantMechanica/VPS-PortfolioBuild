# QUA-774 Blocked Summary (2026-05-08)

## Scope

- Issue: `QUA-774`
- Strategy: `QM5_1004`
- Symbol: `US500.DWX`
- Gate: `P2` redeploy summary (`H1/H4/D1`)

## Evidence

- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_2026-05-08T062617Z.json`
- `docs/ops/QUA-774_P2_REDEPLOY_SUMMARY_20260508T062626Z.json`
- Checker script: `infra/scripts/Test-P2RedeploySummary.ps1`

## Current Result

- `verdict=FAIL`
- `failure_flags=REPORT_MISSING;INCOMPLETE_RUNS`
- `US500.DWX` custom-symbol data missing on `T1,T2,T3,T4,T5`
  - history path + ticks path both absent/non-populated for each terminal
- Timeframe report coverage:
  - `H1=0`, `H4=0`, `D1=0` (`min_required=1`)

## Blocker Owner / Unblock Action

- Unblock owner: DWX source acquisition + import pipeline owner
- Required unblock action:
  1. Provide/import `US500.DWX` history + ticks into `T1` (authoritative source).
  2. Run `infra/scripts/Sync-CustomSymbolData.ps1` to copy to `T2..T5`.
  3. Re-run P2 redeploy for `QM5_1004` on `US500`.
  4. Re-run `Test-P2RedeploySummary.ps1` and attach PASS JSON.

## Re-run Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-P2RedeploySummary.ps1 `
  -StrategyId QM5_1004 `
  -Symbol US500.DWX `
  -JsonOut C:\QM\repo\docs\ops\QUA-774_P2_REDEPLOY_SUMMARY_<UTCSTAMP>.json
```
