# DL-054 launcher wiring update (QUA-687 D3)

Date: 2026-05-05  
Owner: CTO

## Files changed

- `framework/scripts/resolve_backtest_target.py`
- `framework/scripts/run_backtest_smoke.ps1`

## Gate-pass control flow implemented

1. `run_backtest_smoke.ps1` now calls `resolve_backtest_target.py` with:
- `--enforce-dl054-prelaunch`
- `--report-csv <ReportRoot>/report.csv`

2. `resolve_backtest_target.py` runs DL-054 prelaunch gates (G1/G2/G5) before scheduling:
- any prelaunch gate fail returns:
  - `status=invalid_prelaunch`
  - `verdict=INVALID`
  - `invalidation_reason=<gate reasons>`
- and appends a row to `report.csv` with schema:
  - `ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence`

3. On `verdict=INVALID`, launcher exits before tester dispatch (`terminal=null`).

## Deliberate fixture evidence

Fixture path:
- `docs/ops/qua687_dl054_fixture_2026-05-05/`

Inputs:
- `job_invalid_symbol.json` with symbol `ZZZTEST.DWX`

Outputs:
- `decision.json` contains:
  - `{"status":"invalid_prelaunch","verdict":"INVALID","invalidation_reason":"G1:no_history_dir; G5:non_canonical_symbol"}`
- `report.csv` row:
  - `QM5_1001,P1,ZZZTEST.DWX,ANY,INVALID,G1:no_history_dir; G5:non_canonical_symbol,resolve_backtest_target.py:prelaunch`

## Remaining D3 closure work

- Wire post-launch G3/G4 verdict path for phase runners into the same `report.csv` contract.
- Ensure phase advancement explicitly stops for rows with `verdict=INVALID`.
