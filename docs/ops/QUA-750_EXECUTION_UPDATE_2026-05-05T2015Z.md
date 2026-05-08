# QUA-750 Execution Update — QM5_1017 smoke dispatch reached infra NO_REPORT

timestamp_utc: 2026-05-05T20:22:00Z
issue: QUA-750
ea_id: QM5_1017
owner: Pipeline-Operator
status: READY_FOR_REVIEW (infra blocker cleared)

## Actions completed this heartbeat

1. Created missing setfile scaffold entry:
   - `framework/EAs/QM5_1017_chan_pairs_stat_arb/sets/QM5_1017_chan_pairs_stat_arb_AUDUSD.DWX_H1_backtest.set`
2. Re-ran dispatch preflight:
   - `python framework/scripts/p2_baseline.py --ea QM5_1017 --dry-run` → DRY success for `AUDUSD.DWX`
3. Ran one-symbol live dispatch:
   - `python framework/scripts/p2_baseline.py --ea QM5_1017 --symbols AUDUSD.DWX --runs 2 --terminal T1`

## Result classification (DL-054 / FS truth / NO_REPORT rule)

- Outcome is **not** G4 invalidation and not EA weakness.
- Outcome is infra-side `NO_REPORT`:
  - summary reason classes: `REPORT_MISSING`, `INCOMPLETE_RUNS`
  - both runs show `report_size_bytes: 0`
  - tester report export path not produced
- Evidence:
  - `D:/QM/reports/pipeline/QM5_1017/P2/report.csv`
  - `D:/QM/reports/pipeline/QM5_1017/P2/QM5_1017/20260505_201057/summary.json`
  - `D:/QM/reports/pipeline/QM5_1017/P2/p2_QM5_1017_result.json`

## Infra blocker resolution

- Root cause confirmed: missing expert binary in terminal `MQL5/Experts/QM` path for QM5_1017.
- Action taken: deployed
  `QM5_1017_chan_pairs_stat_arb.ex5` to `D:\QM\mt5\T1..T5\MQL5\Experts\QM\`.
- Re-test after deployment:
  - Direct run (`run_smoke.ps1` with `-AllowRunningTerminal`) now produces non-zero reports and tester logs.
  - `p2_baseline.py --terminal any` executes and returns `FAIL: MIN_TRADES_NOT_MET` (no REPORT_MISSING / INCOMPLETE_RUNS).

## Residual owner + action

- **Owner:** CTO (review gate) + Quality-Tech (gate-of-record).
- **Required action:**
  1. Confirm two-slot-per-pair registry convention closure (Card §7/§12) in checklist.
  2. Accept scaffold-stage run classification: zero trades with valid report artifacts.
  3. Keep verdict as non-PASS (`ZERO_TRADE`/fail-fast path), not strategy PASS.

## Matrix readiness evidence (36-symbol scaffold)

- Setfile matrix present for `QM5_1017` at:
  - `framework/EAs/QM5_1017_chan_pairs_stat_arb/sets/QM5_1017_chan_pairs_stat_arb_<SYMBOL>_H1_backtest.set`
- File-level validation: 36 matching setfiles (canonical symbol list).
- Dry-run coverage:
  - Full dry-run executed (majority symbols printed in run output).
  - Targeted dry-run for previously non-printed 8 symbols completed clean:
    - `NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, XAGUSD.DWX, XAUUSD.DWX, XNGUSD.DWX, XTIUSD.DWX`
  - All 8 resolved with valid setfile paths and `DRY` verdicts.

## Cross-symbol live evidence (post-fix)

- Executed live smoke through `p2_baseline.py` on:
  - `EURUSD.DWX`
  - `XAUUSD.DWX`
- Both runs completed with:
  - `report_size_bytes = 29600`
  - `total_trades = 0`
  - runner verdict `FAIL` with `MIN_TRADES_NOT_MET` (expected scaffold behavior)
- DL-054 G4 verification on produced `report.htm`:
  - `QM5_1017/EURUSD.DWX` → `passed=True` (`trades=0 with zero-trade ADR present`)
  - `QM5_1017/XAUUSD.DWX` → `passed=True` (`trades=0 with zero-trade ADR present`)

Interpretation: dispatch/runtime path is healthy (non-zero reports, deterministic runs), and the residual outcome is strategy-stage zero-trade scaffold, not infra failure.

## Additional reproduction history (terminal lock ruled out)

- Direct invocation with running-terminal allowance still fails identically:
  - `pwsh -NoProfile -File framework/scripts/run_smoke.ps1 ... -AllowRunningTerminal ...`
- Output:
  - `run_smoke.result=FAIL`
  - `run_smoke.reason_classes=REPORT_MISSING;INCOMPLETE_RUNS`
  - `run_smoke.summary=D:\QM\reports\pipeline\QM5_1017\P2_direct\QM5_1017\20260505_201519\summary.json`
- Evidence file:
  - `D:\QM\reports\framework\22\20260505_201519_QM5_1017_run_smoke.md`
- Conclusion:
  - Failure is persistent runtime/export behavior for this EA path, not a terminal busy/lock artifact.
  - This path was subsequently resolved by deploying the missing `.ex5` binary to terminal expert folders.
