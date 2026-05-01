# QUA-402 Compile Anomaly (2026-05-01T074428Z)

EA: QM5_1009_lien_fade_double_zeros

## Observed
- ramework/scripts/compile_one.ps1 -Strict returned compile_one.result=FAIL with eason_class=METAEDITOR_NONZERO_EXIT.
- Compile log shows: Result: 0 errors, 0 warnings.
- Output binary exists: ramework/EAs/QM5_1009_lien_fade_double_zeros/QM5_1009_lien_fade_double_zeros.ex5 (size 99196 bytes).

## Evidence Paths
- ramework/build/compile/20260501_074402/QM5_1009_lien_fade_double_zeros.compile.log
- D:/QM/reports/compile/20260501_074402/summary.csv

## Impact
- Source implementation appears compile-clean by log, but strict harness status is FAIL due MetaEditor process exit behavior.
- CTO review can proceed for EA-vs-Card; pipeline dispatch remains blocked by policy until CTO pass.
