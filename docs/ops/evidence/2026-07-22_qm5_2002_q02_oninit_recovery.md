# QM5_2002 Q02 ONINIT recovery

- Scope: `QM5_2002_nnfx-qqe-trend`, `USDCAD.DWX`, Q02 work item
  `9a1ff21c-90de-45f5-88cc-475322ef63a8`.
- Farm claim: task `99ba519a-337c-4399-8cd4-87c30951dbe6`, claimed by
  `codex:agents/board-advisor` before repair.
- Original evidence:
  `D:/QM/reports/work_items/9a1ff21c-90de-45f5-88cc-475322ef63a8/QM5_2002/20260722_073447/summary.json`.
  The report was structurally complete for the requested EA, symbol, D1 period,
  and date range, but the run was classified `ONINIT_FAILED` with zero trades.
  The summary's tester-log path was absent from the isolated run directory.
- Diagnosis: this run completed at 2026-07-22 07:37 UTC, before commit
  `983baef6d` (2026-07-22 11:48 UTC) scoped OnInit detection to the current test
  section of MetaTester's shared daily journal. This is the repaired
  shared-log-contamination class, not evidence of an EA initialization defect.
- Classifier verification:
  `framework/scripts/tests/Test-RunSmokeOnInitTradeScope.ps1` PASS on
  2026-07-22. The regression proves an older EA's OnInit failure is excluded
  while a current-run OnInit failure remains detected.
- Build verification: strict compile PASS with 0 errors and 0 warnings.
  Compile log:
  `framework/build/compile/20260722_134603/QM5_2002_nnfx-qqe-trend.compile.log`.
  Compile summary: `D:/QM/reports/compile/20260722_134603/summary.csv`.
  Rebuilt EX5 SHA256:
  `FD8042D679F374A541B3693338A9F8D0059A8C31A93553737F055A73E71DFC11`.
- Disposition: requeue the existing work item at Q02 with priority-track
  metadata. Do not create a duplicate work item and do not launch MT5 manually.
- Live boundary: no T_Live file, manifest, process, or AutoTrading state was
  touched.
