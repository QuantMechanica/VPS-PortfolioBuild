# QUA-270 Step 22 History Verification (2026-04-27)

- issue: `QUA-270`
- generated_at_local: `2026-04-27T21:57:34+02:00`
- m1_rebuild_path: `D:\QM\reports\setup\tick-data-timezone\EURUSD_GMT+2_US-DST_M1.csv`
- m1_first_line: `2017.10.02,00:05:00,1.1795,1.17963,1.17948,1.17962,58`
- m1_last_line: `2026.04.06,02:59:00,1.15096,1.15098,1.15092,1.15096,50`
- seed_status: `restored` action=`stage_prepare_import`
- seed_done_sidecar: `D:\QM\mt5\T1\MQL5\Files\imports\done\20260427_205944_EURUSD.DWX.import.txt`
- latest_step22_command: `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\framework\scripts\run_smoke.ps1 -EAId 1001 -Expert "QM\QM5_1001_framework_smoke" -Symbol "EURUSD.DWX" -Year 2024 -Terminal T1 -Model 4`
- latest_run_tag: `20260427_185959`
- latest_run_result: `FAIL` (`TIMEOUT`, `REPORT_MISSING`)

## Tester Evidence (post-fix)
- `RJ	0	21:00:04.470	Tester	EURUSD.DWX,H1 (Darwinex-Live): testing of Experts\QM\QM5_1001_framework_smoke.ex5 from 2024.01.01 00:00 to 2024.12.31 00:00`
- `EE	0	21:30:04.329	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`
- `HQ	0	21:30:04.333	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`
- `LO	0	21:30:04.859	Tester	EURUSD.DWX,H1 (Darwinex-Live): testing of Experts\QM\QM5_1001_framework_smoke.ex5 from 2024.01.01 00:00 to 2024.12.31 00:00`
- `KR	0	21:56:59.358	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`
- `FN	0	21:56:59.364	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`
- `PJ	0	21:57:07.672	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`
- `OF	0	21:57:07.677	Tester	EURUSD.DWX: history data begins from 2017.10.02 00:00`

## Prior Abort Signatures (for contrast)
- `OO	3	19:33:29.851	Tester	EURUSD.DWX: no history data from 2025.01.01 00:00 to 2025.12.31 00:00`
- `PP	3	19:33:29.851	Tester	no history data, stop testing`
- `IH	3	19:43:18.548	Tester	EURUSD.DWX: no history data from 2024.01.01 00:00 to 2024.12.31 00:00`
- `JO	3	19:43:18.548	Tester	no history data, stop testing`
- `PP	3	19:43:24.928	Tester	EURUSD.DWX: no history data from 2024.01.01 00:00 to 2024.12.31 00:00`
- `OG	3	19:43:24.928	Tester	no history data, stop testing`

- conclusion: 2024 tester start now recognizes EURUSD.DWX history (`history data begins ...`) and no longer immediately aborts with `no history data` on the post-fix attempts.
- json_artifact: `C:\QM\repo\docs\ops\QUA-270_STEP22_HISTORY_VERIFICATION_2026-04-27.json`
