# QM5_13117 EURGBP/AUDJPY Prior-Window Repair

**Date:** 2026-07-11
**Branch:** `agents/board-advisor`
**EA:** `QM5_13117_eurgbp-audjpy`
**Logical symbol:** `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`

## Outcome

Advanced the existing forex fallback without creating another basket. The
historical `QM5_13117` Q02 PASS used the pre-repair binary, and its pending Q03
successor had not run. The EA did not implement the approved card's z-score
window: the newest closed spread was included in the same 60-bar mean and
standard deviation used to score it.

The EA now requests 61 aligned closed D1 observations, scores index 0, and
calibrates only on indices 1 through 60. Beta, thresholds, symbols, risk, and
package mechanics are unchanged. This is a card-to-code conformance repair,
not a parameter variation. Because code changed, the old Q02 PASS cannot
certify the repaired binary: the unrun Q03 row was invalidated and exactly one
replacement Q02 baseline was enqueued.

## Selection

The sign-aware reproduction command remains:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

It returned seven strict rows. Every row now has an EA build, including the
final USDJPY/EURAUD sleeve (`QM5_13119`), so a new build would be duplicate.
The original anchors are not Q02 setup blockers: `QM5_12532` and `QM5_12533`
both have logical-basket Q02 PASS evidence.

`QM5_13117` is the clean existing continuation. Its reproduced scan metrics are
DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`, OOS return `4.4752%`, 20 OOS
state changes, beta `-0.12202869296345396`, and a 36.84-day half-life.

## Verification

- Source repair commit: `72237d508`.
- Strict clean-worktree compile: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:/QM/reports/compile/20260711_020616/summary.csv`.
- Strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260711_020710.json`.
- Strategy-card lint: PASS for canonical, approved, and EA-doc mirrors.
- Spec validation: PASS.
- Symbol-scope validation: `BASKET_OK`, 0 violations.
- Regression suite: `16 passed` in
  `tools/strategy_farm/tests/test_fx_basket_manifests.py`.
- Backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The compile used a detached clean-header worktree at `72237d508`; unrelated
dirty `framework/include` work in the shared checkout was excluded from the
new `.ex5`.

## Queue And Capacity

The stale, unrun Q03 work item
`dc01fd4d-0f8f-414a-a6b1-80441204fefc` is now `failed/INVALID`. Replacement
Q02 work item `fb649d4a-3a9e-42e8-ae99-b492d2c65f5e` is pending, unclaimed,
and at attempt 0. Its payload records the repaired MQ5/EX5/setfile hashes and
clean-build evidence. Exactly one Q02 row is open for `QM5_13117`; no duplicate
open baseline was created.

`FACTORY_OFF.flag` remains present and no factory MT5 terminal is running.
No dispatch, smoke, or manual backtest was started. The row is left for the
paced workers after maintenance ends.

## Safety

No T_Live or AutoTrading action occurred. No live manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08 contribution path was touched.

Machine-readable evidence:
`artifacts/qm5_13117_prior_window_repair_20260711.json`.
