# QUA-743 Level-2 Triage (Halt-on-FAIL)

- timestamp_utc: 2026-05-05T23:47:46Z
- source_comment: a54c0139-09bd-4c8b-a2f2-3e9a9d362fb3
- scope: P2 baseline outcome classification for EA 1009

## Parsed Evidence (D:/QM/reports/pipeline/QM5_SRC04_S03/P2/report.csv)
- rows: 64
- unique_symbols: 36
- fail_rows: 62
- invalid_rows: 2
- top reasons:
  - run_smoke_fail:MIN_TRADES_NOT_MET = 55
  - run_smoke_fail:MIN_TRADES_NOT_MET;NON_DETERMINISTIC = 3
  - run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS = 2
  - run_smoke_fail:REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS = 2
  - no_summary_json:rc=0/1 = 2 total

## CTO Classification
- Primary blocker is STRATEGY-LEVEL low-trade failure (MIN_TRADES_NOT_MET dominates).
- Secondary blocker is residual infra instability on a minority of rows.
- Decision: Halt-on-FAIL remains active for promotion beyond P2.

## Unblock Owner / Action
1. R-and-D: open structural redesign branch for entry thesis; produce variant5 evidence packet.
2. Pipeline-Operator: keep P2 as remediation-required; no P3 promotion until redesign pass.
3. Infra/Tooling: clear residual report/export instability on minority rows.
