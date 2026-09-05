# DL-090 retention protection: campaign plan and native exports

Date: 2026-09-05

Verdict: **PASS**. The OOS-2026 campaign plan and all currently declared native calendar/M5/D1 source exports are explicit, SHA-bound `KEEP` inputs in both retention planners. No purge, deletion, move, compression, terminal stop, or live-state change was performed.

## Contract added

`tester_cache_purge_guard.py` now appends the following fail-closed source classes to the `protected_targets` array consumed by `tester_cache_purge.ps1`:

- `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json`
- `D:/QM/mt5/T_Export/MQL5/Files/T_EXPORT_*_HIGH_2018_2025_NATIVE.csv`
- `D:/QM/mt5/T_Export/MQL5/Files/*.DWX_M5.csv`
- `D:/QM/mt5/T_Export/MQL5/Files/*.DWX_D1.csv`

The guard refuses the entire exclusion plan if the campaign plan, export root, or any declared export class is absent. Each emitted target carries its SHA-256. The purge script already constructs its lookup from every `protected_targets` row before considering a deletion and refreshes that lookup after stopping idle workers; this patch preserves that consumer contract.

`build_backup_retention_manifest.py` discovers the identical source classes and writes one exact-path `KEEP_DL090_NATIVE_SOURCE` row per file, including bytes and SHA-256. These dispositions are not phase-2 actions, so they cannot become delete candidates.

## Live tester-cache purge dry run

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:/QM/repo/tools/strategy_farm/tester_cache_purge.ps1 `
  -RepoRoot C:/QM/repo -Mode IdleCaches -DryRun -LowWaterGB 1000
```

Output at 2026-09-05T04:14:09Z:

```text
EVIDENCE_EXCLUSIONS status=PASS db_pairs=38 live_pairs=24 union_pairs=40 targets_scanned=106 protected_targets=33 manifest_sha256=8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6
TRIGGER: D: free 64.38GB < 1000GB -> purge tester caches
IDLE_CACHE_PREFLIGHT targets=32 candidate_gb=14.829 minimum_reclaim_gb=1.000
DRYRUN: would pause new dispatch, protect active/running terminals=[T10,T2,T5,T6,T7,T8,T9], clear 32 idle cache target(s), restart missing workers
```

The artificial 1000 GB threshold forces the planning branch. `-DryRun` returns before factory teardown or cache removal. A direct live invocation of the guard reported 33 `DL090_RETENTION_SOURCE` targets and 106 ordinary tester targets scanned.

## Live backup-retention manifest dry run

Command (outputs were written only to `C:/QM/repo/scratch/dl090_retention_20260905`):

```powershell
python tools/strategy_farm/build_backup_retention_manifest.py `
  --csv C:/QM/repo/scratch/dl090_retention_20260905/manifest.csv `
  --markdown C:/QM/repo/scratch/dl090_retention_20260905/manifest.md `
  --seal C:/QM/repo/scratch/dl090_retention_20260905/manifest.sha256 `
  --now 2026-09-05T04:15:00Z
```

Measured output: DB quick-check `ok`; 527,438 files; 175,862,934,808 bytes; 55,223 aggregate/exact rows; 33 protected sources; CSV SHA-256 `6bbd4daa0d08d54fd8f5842f4492284fc6cec260b73eb7b43c2a2fba2c0faaac`; Markdown SHA-256 `a13377d79426c3a0d2400f6e0d493e34df8fd52295b4714588d4402ee1e49856`. Importing the emitted CSV returned exactly 33 rows with disposition `KEEP_DL090_NATIVE_SOURCE`.

## Protected source bindings

| Source | Bytes | SHA-256 |
|---|---:|---|
| AUDJPY.DWX_D1.csv | 125742 | `1dc1618d5ef0947cbd3c0111fa6e532e4702577c875c3bfd91ff7efe00804f22` |
| AUDUSD.DWX_D1.csv | 102713 | `77a4ac94a899d7005834fa7aa5be133d9d042a13982e6acc1545d9b294d58b51` |
| EURAUD.DWX_D1.csv | 116717 | `fa479535220d5797e3f95ef1d40e20cc7b4577e9a2ee755806de9b0e8b825df6` |
| EURGBP.DWX_D1.csv | 102645 | `30138eca97277c2ac2565ce2699ac86d6797c15c401deca70d45c5a09e4ed61f` |
| EURJPY.DWX_D1.csv | 138749 | `415a6975b4f37dc189d2b5c73dbad8e8918e1c8879f669041b0460deefc65e20` |
| EURUSD.DWX_D1.csv | 119626 | `7ecdc7c45678de73cb9fbe9390b563ee88d3dddd876feace489e3b4add653d0f` |
| EURUSD.DWX_M5.csv | 29189964 | `b7ec4fae50b0e257832cb3e1217a34236f2a1e212844f9ee35b0cc7b86ce91f9` |
| GBPJPY.DWX_D1.csv | 133637 | `5af9da911474229cbc367b5e6305fb6d370b40be181c11b3c3eb4f6328c11859` |
| GBPJPY.DWX_M5.csv | 28508143 | `756faa43b25d97b235f44aa97fa2a0f5b548b5aed8a64c1c1514cd785aa8869b` |
| GBPUSD.DWX_D1.csv | 120957 | `c354b33f801382b8cc508180238c1d4d04e1d743d5d76f1ce7f0634f3ce5b5ea` |
| GBPUSD.DWX_M5.csv | 29258180 | `e483e548e28f611b0d53143eb1e329eff9a568f7d8a7076afc4ce59a8aba31bc` |
| GDAXI.DWX_D1.csv | 115251 | `0b790d26ffbaf2687eded7414bf1e70b0398935f0b9c583499ce07a5b91ea5e8` |
| NDX.DWX_D1.csv | 101831 | `b0529d748e1351446922e2d14992ee5ef4b1f50d5ef6f237715238119e123536` |
| NZDUSD.DWX_D1.csv | 102459 | `1f0bdca2a5ab7252e1d23e3e5f9874f0068f3d727b537ef32cecf3fd01948745` |
| SP500.DWX_D1.csv | 109655 | `ae3c0c52233558b22fb02e58dff7e475b0e400984e5707da67e995211a2fe2e4` |
| T_EXPORT_AUD_HIGH_2018_2025_NATIVE.csv | 13083 | `e08d35bbe409410c29ba19b322e3075528fb15c38c5955e5aa5f09dffb5bf3f8` |
| T_EXPORT_CAD_HIGH_2018_2025_NATIVE.csv | 15942 | `e7ac95686e41f19e9835364e7f247fc460951526a7f0e5232b3639b838bc7676` |
| T_EXPORT_EUR_HIGH_2018_2025_NATIVE.csv | 80769 | `f619007af0a0126f665afe247b6828e21c36a642ca4e6714f962ae7573bf8137` |
| T_EXPORT_GBP_HIGH_2018_2025_NATIVE.csv | 36462 | `8b4291bae1e41911c66fb683b994baece4910c3623feffaa3d43f2c970c1bee4` |
| T_EXPORT_JPY_HIGH_2018_2025_NATIVE.csv | 41091 | `680b5cd69ef84a37523cce2b39ed6533eb73a322c18ef42da258feb50307dcf6` |
| T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv | 306801 | `c1554e52d3456575f51d044cd0097e18b960c7f12485e9b45a07e36536b9ab3b` |
| UK100.DWX_D1.csv | 87528 | `045bd0f258ac2e1e669ed813daa212e771b2132e82a1d161325913edb5ff37ba` |
| USDCAD.DWX_D1.csv | 102907 | `b2231559c1ffd5ea35d8aad80ee6c84e1399c948b838ac011167daab559efbeb` |
| USDCHF.DWX_D1.csv | 102542 | `8566143c2b11feb8438266adc81ed398ef3fb88e4ae09fbcd3cac3bb3f304ed5` |
| USDJPY.DWX_D1.csv | 138327 | `f52a8b96eac15d12085878d324742f261c599d7d74d01383072296b7d5a283bb` |
| USDJPY.DWX_M5.csv | 29251573 | `27d1dc7569385978ef42ae33dfcbbe1b36ed162f06ed031692a157b196159dd4` |
| WS30.DWX_D1.csv | 117929 | `f719a46e527e19ecbabc1b1428ef703e926f1c0e0cfce0650fe520132aa995b5` |
| XAGUSD.DWX_D1.csv | 86572 | `680876d71982619dabbde5b87e62e32b6275bc0cedac688c670f1a8e84ffdf20` |
| XAUUSD.DWX_D1.csv | 116706 | `105aa27a6d0aff0818b9b76b0eb081d917ea8fb90ec077b599a33ea65ab12f13` |
| XAUUSD.DWX_M5.csv | 28128925 | `a0785d25e7ef7811e95509f3e009703617f3996eb8f5d4f0f1acf945d3522c4f` |
| XNGUSD.DWX_D1.csv | 88161 | `a2a4f5bcae9a47765b6245fc693e5d69479442089e9cd74f2f9de681f55f108c` |
| XTIUSD.DWX_D1.csv | 90192 | `b892dd634214578ed7275f29a477ae239996d4670ede479268cb66745e81f211` |
| campaign_plan.json | 51029 | `6ade6b3491dabe74773abc2bfb31d597f48db78f01ece41759667b9b5088dfad` |

All filenames except `campaign_plan.json` are under `D:/QM/mt5/T_Export/MQL5/Files`; the campaign is at the exact path above.

## Cleaner scope audit

- `run_agent_temp_reclaim.ps1` invokes `reclaim_busy_agent_temp.ps1`, whose only candidates are old `bar*.tmp` files below `D:/QM/mt5/T1-T10/Tester/Agent-*/temp`. Neither protected root is in scope.
- `tester_cache_purge.ps1` only proposes `T1-T10/Tester/bases/*` and `T1-T10/Tester/Agent-*`, and now additionally carries the exact protected source bindings through both exclusion-plan reads.
- `reports_log_purge.ps1` only scans `D:/QM/reports/{work_items,smoke,pipeline}` for log/cache suffixes.
- `report_retention_purge.py` is rooted at `D:/QM/reports/work_items`.
- `continuous_retention_runner.py` is rooted at farm-state backups, report work items, and farm logs. It does not traverse `strategy_farm/artifacts` or `mt5/T_Export`.

Therefore no inspected cleaner can select either protected source tree. The explicit bindings also make future retention-plan regressions test-visible.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_tester_cache_purge_guard.py tools/strategy_farm/tests/test_build_backup_retention_manifest.py tools/strategy_farm/tests/test_execute_backup_retention_phase2.py
16 passed
```

The fixture tests prove that purge planning emits SHA-bound protected rows and that the backup manifest classifies the same exact paths as `KEEP_DL090_NATIVE_SOURCE`. Existing phase-2 tests remain green, confirming the added non-action rows do not become executable retention actions.
