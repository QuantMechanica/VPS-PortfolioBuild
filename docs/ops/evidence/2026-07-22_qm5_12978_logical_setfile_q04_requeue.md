# QM5_12978 logical-setfile repair and Q04 requeue

**Date:** 2026-07-22  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_12978_edgelab-gbpusd-usdcad-cointegration`  
**Pair:** `GBPUSD.DWX` / `USDCAD.DWX`

## Outcome

The strict-scan anchors `QM5_12532` and `QM5_12533` already have logical-basket
Q02 PASS verdicts and later genuine strategy failures. Every approved strict-scan
pair has an EA build, so the mission fallback was used to advance the highest-ranked
existing sleeve with newly repaired-binary evidence: `QM5_12978`.

The repaired `QM5_12978` binary passed Q03 on 2026-07-21, but Q04 could not be
requeued because both PASS predecessor rows referenced a missing canonical logical
basket setfile. The equivalent host-named GBPUSD setfile existed. The canonical file
was restored with the same structural parameters:

- logical symbol `QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1`;
- host `GBPUSD.DWX`, timeframe `D1`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- fixed 60-day z-score and scan beta `-1.140460285727`.

`build_check.ps1 -SkipCompile` then passed with zero failures and zero warnings.
`validate_symbol_scope.py` reported `BASKET_OK` for the two-leg manifest.

## Queue state

`farmctl enqueue-backtest --ea QM5_12978 --phase Q04` requeued the existing row
in place rather than creating a duplicate:

| Field | Value |
|---|---|
| work item | `bf98a2c5-0ed2-4410-abbe-7e66fe97e843` |
| phase | `Q04` |
| status | `pending` |
| logical symbol | `QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1` |
| host symbol | `GBPUSD.DWX` |
| basket manifest | `framework/EAs/QM5_12978_edgelab-gbpusd-usdcad-cointegration/basket_manifest.json` |
| requeued at | `2026-07-22T17:01:39+00:00` |

Six `terminal64` processes were active at preflight, below the seven-worker CPU
ceiling. No terminal was launched directly. No T_Live, AutoTrading, portfolio gate,
portfolio KPI/Q08 contribution artifact, or live manifest was touched.
