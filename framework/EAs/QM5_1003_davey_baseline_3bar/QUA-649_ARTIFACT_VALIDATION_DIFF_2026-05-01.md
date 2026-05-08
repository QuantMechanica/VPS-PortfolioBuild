# QUA-649 Artifact Validation Delta

## Summary
- PASS control run: D:\QM\reports\smoke\QM5_1003\20260501_092115\artifact_validation.json
- FAIL run A: D:\QM\reports\smoke\QM5_1003\20260501_104253\artifact_validation.json
- FAIL run B: D:\QM\reports\smoke\QM5_1004\20260501_104125\artifact_validation.json

## Control (PASS)
- run_01: report_exists=True, report_size_bytes=27508, tester_log_exists=True, status=OK
- run_02: report_exists=True, report_size_bytes=27508, tester_log_exists=True, status=OK

## Current Blocked (FAIL)
- QM5_1003 run_01: report_exists=False, report_size_bytes=0, tester_log_exists=False, status=FAIL
- QM5_1003 run_02: report_exists=False, report_size_bytes=0, tester_log_exists=False, status=FAIL
- QM5_1004 run_01: report_exists=False, report_size_bytes=0, tester_log_exists=False, status=FAIL
- QM5_1004 run_02: report_exists=False, report_size_bytes=0, tester_log_exists=False, status=FAIL

## Key Delta
- PASS run has non-empty report.htm and tester log for each run_*.
- FAIL runs have no report.htm and no tester log for each run_*, leaving only tester.ini.
