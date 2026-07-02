# QM5_10009 FX Cointegration Review Rework - 2026-07-02

Mission route: no unbuilt strict-threshold pair was available from the documented 66-pair FX cointegration scan. The two strict survivors, `QM5_12532` and `QM5_12533`, both already have logical-symbol Q02 PASS rows in farm state, so the fallback was to advance an existing FX cointegration sleeve.

Selected sleeve: `QM5_10009_rw-fx-cointeg-bb`, the Robot Wealth AUD/NZD/CAD D1 cointegration basket. The active farm build task `6b602cef-3f7b-4acb-a0c4-801874ae146e` was blocked by a code-review finding on runtime adaptive-weight grep surface.

Changes made:

- Renamed the runtime OLS hedge vector from generic weight terminology to `g_hedge_coeff`.
- Renamed the OLS estimator to `EstimateHedgeCoefficients`.
- Recompiled the EA and refreshed the generated RISK_FIXED backtest setfile build hashes.
- Left the monthly cadence on the approved `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1)` framework primitive.

Verification:

- Source grep for the legacy hedge-vector surface and raw calendar-time reader usage returned no matches in the EA source and SPEC.
- `framework\\scripts\\compile_one.ps1 -EAPath framework\\EAs\\QM5_10009_rw-fx-cointeg-bb\\QM5_10009_rw-fx-cointeg-bb.mq5 -Strict`: PASS, 0 errors, 0 warnings.
- `framework\\scripts\\build_check.ps1 -EALabel QM5_10009_rw-fx-cointeg-bb -SkipCompile`: PASS, 0 failures, 19 warnings. Warnings were advisory framework include warnings plus the known `CopyClose` heuristic; the EA reaches `RefreshState()` only after the D1 `QM_IsNewBar()` gate in `OnTick`.
- Farm state read-only check: `QM5_10009` current logical Q02 work item `2ae2c04e-5b5c-47de-a9eb-c46caeeefe0a` is done/PASS, so no duplicate Q02 enqueue was created.
