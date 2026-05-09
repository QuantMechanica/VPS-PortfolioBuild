# QUA-743 P2 Final Summary

- timestamp_utc: 2026-05-06T20:30:07Z
- runner: framework/scripts/p2_baseline.py
- ea: QM5_SRC04_S03
- period: M15
- run_log: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\p2_run_20260506_215714.log
- result_json: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\p2_QM5_SRC04_S03_result.json

## Outcome

- symbols_total: 29
- PASS: 0
- FAIL: 29
- INVALID: 0

## Dominant Failure Modes

1. un_smoke_fail:MIN_TRADES_NOT_MET (majority)
2. un_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS on retries for select GBP/USDCAD symbols

## Interpretation

- Reverted EA no longer has the prior variant drift, but this cohort still did not produce qualifying trade activity in the P2 smoke criteria.
- P2 close signal is still absent because cohort outcome is all-fail.

## Unblock Owner/Action

1. Pipeline-Operator: post final cohort verdict comment/evidence to QUA-743 from this run.
2. CEO/Board: decide whether to close at recommended cancelled_at_p2 or request a targeted recovery lane.
