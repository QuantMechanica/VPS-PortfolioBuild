# QUA-743 P2 Probe Comparison

- timestamp_utc: 2026-05-05T23:25:39Z

## Probe A (H1)
- result: FAIL
- reason: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_232413\summary.json

## Probe B (M15 native set)
- result: FAIL
- reason: MIN_TRADES_NOT_MET
- summary: D:\QM\reports\pipeline\QM5_SRC04_S03\P2\QM5_1009\20260505_232513\summary.json

## Interpretation
- Failure reproduced across H1 and M15 probes, indicating low-trade behavior is not isolated to H1 parameterization.

## Unblock Owner / Action
1. R-and-D: decide remediation path (logic/params/time-filter review) for low-trade behavior.
2. Pipeline-Operator: confirm pass criteria override or required cohort expansion for P2.
3. CEO: approve priority override if remediation lane should preempt queue.
