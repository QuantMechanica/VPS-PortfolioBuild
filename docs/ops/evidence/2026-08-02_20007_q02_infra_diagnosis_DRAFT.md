# QM5_20007 GDAXI/NDX Q02 INFRA_FAIL diagnosis (DRAFT)

**Date:** 2026-08-02  
**Mode:** read-only diagnosis during OWNER-approved factory-OFF window  
**Scope:** `QM5_20007`, with detailed treatment of the seven recent `GDAXI.DWX` rows and three 2026-08-01 `NDX.DWX` rows  
**Disposition:** no MT5 terminal was started; `farm_state.sqlite` was opened with SQLite URI `mode=ro` plus `PRAGMA query_only=ON`; no row was changed, no work was requeued, and no code fix or commit was made.

## Executive diagnosis

These are non-merit failures, but there are **two independent primary defects plus one runtime/profile defect**:

1. **GDAXI is principally a runner/classifier failure.** `run_smoke.ps1` reaches `terminal_exit`, but its post-exit report path can take up to 240 seconds (`framework/scripts/run_smoke.ps1:2441-2487`). The outer worker declares a wrapper stalled after only 60 seconds of quiet following `terminal_exit` (`tools/strategy_farm/terminal_worker.py:165`, `:2105-2130`, called at `:2826-2829`) and kills it before `summary.json` is written. Four of the seven final attempts had already latched complete 931,900-byte GDAXI reports; one more final attempt was actually an unconfigured-account failure. Because no summary remains, `_detect_history_lock_storm()` then scans the tails of up to six recent logs without a current-run time, work-item, or symbol boundary (`tools/strategy_farm/terminal_worker.py:973-1025`) and misclassifies stale/unrelated `some error after pass finished` text as a current shared-history storm. It increments a separate transient counter rather than `attempt_count` and fails at the seventh such classification (`tools/strategy_farm/terminal_worker.py:2355-2431`). This directly explains the seven rows with `attempt_count=0`.

2. **NDX full-window runs have an EA-specific deterministic journal bomb.** On T4 and T7 the tester emits the same rejected modification on every tick, including an unchanged normalized stop: `sl: 12935.8 ... -> sl: 12935.8 ... [Invalid stops]` (`D:\QM\mt5\T4\Tester\logs\20260801.log:2980-2987`; independently repeated at `D:\QM\mt5\T7\Tester\logs\20260801.log:600946-600953`). The runner kills each journal at 1.48 GB and approximately 8.8 GB/min (`D:\QM\strategy_farm\logs\work_item_c2e34ae2-4c02-495d-99f8-aa83aba65bb1.log:11-16`; `D:\QM\strategy_farm\logs\work_item_74c0678e-04f8-4ffa-a01b-7d4d11565660.log:11-17`). The causal code path uses bar-cached VWAP/ATR values but calls the trail every tick (`framework/EAs/QM5_20007_intraday-config-engine/QM5_20007_intraday-config-engine.mq5:340-365`, `:451-477`); the trade manager normalizes the price, deliberately disables failed-modify suppression and stop-distance checks in the tester, and sends/logs the request (`framework/include/QM/QM_TradeManagement.mqh:44-60`, `:135-212`, `:368-374`).

3. **The last NDX row also hit real per-profile history sharing violations, not permanent missing history.** Its final reports are `NO_HISTORY` with `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, `BARS_ZERO`, `NO_HISTORY_LOG`, and `HISTORY_CONTEXT_INVALID` (`D:\QM\reports\work_items\dfa4ecdb-2db1-454c-95e3-8f24bf380fd7\QM5_20007\20260801_225851\summary.json:163-180`). The immediately bound T4 terminal log shows repeated `NDX.DWX file opening or reading error [32]` (`D:\QM\mt5\T4\logs\20260802.log:48-69`, then again `:74-121`); the same row has the same current-run signature on T9, T10, and T1 (`D:\QM\mt5\T9\logs\20260802.log:144-217`; `D:\QM\mt5\T10\logs\20260802.log:134-207`; `D:\QM\mt5\T1\logs\20260802.log:24-46`). Windows error 32 is a sharing violation. It is transient/profile-level because the same EA's six-month NDX prescreens passed on T9, T6, and the newly reactivated T5, and another EA completed a two-year NDX M15 Q02 on T9.

This is **not** a calendar-hard, setfile-parse, permanent-history, or recent OnInit failure. Every recent work-item log reports the news calendar `OK`; the full-run summaries say `oninit_failure_detected=false`; the source and deployed EX5/setfile hashes match; and all three recent NDX rows first produced an identical successful six-month prescreen with 356 trades. Paths are given below.

## Read-only state extraction

The authoritative source is `D:\QM\strategy_farm\state\farm_state.sqlite`. The database was queried through `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`, with `PRAGMA query_only=ON`. A second read using SQLite immutable mode agreed on both the 34-row count and latest `updated_at`, which guards against an accidental WAL-only view. The query was:

```sql
SELECT id, symbol, status, verdict, attempt_count,
       payload_json, evidence_path, updated_at
FROM work_items
WHERE ea_id = 'QM5_20007'
ORDER BY updated_at, id;
```

There are 34 rows. The exact `payload_json` cells total 72,269 characters, so the table below records a SHA-256 prefix over each exact UTF-8 cell plus the requested per-row `verdict_reason` / `verdict_taxonomy` extraction instead of duplicating 72 KB of raw JSON. The unabridged values remain in the cited read-only database. Where `verdict_reason` is absent, `final_failure` or `prior_failure` is shown in that order. A dash means the field is absent.

| updated_at | id | symbol | status | verdict | attempt | extracted reason | taxonomy | payload SHA-256 (12) | evidence_path |
|---|---|---|---|---|---:|---|---|---|---|
| 2026-07-23T08:59:38+00:00 | d9e153f5-833d-4eb6-a2e9-a63ac7f4f4c0 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 9ff681fd4dcc | `D:\QM\reports\work_items\d9e153f5-833d-4eb6-a2e9-a63ac7f4f4c0\QM5_20007\20260723_085350\summary.json` |
| 2026-07-23T09:30:26+00:00 | ff065f50-f601-400b-a235-e504ad1737ea | NDX.DWX | failed | INFRA_FAIL | 0 | ex5_missing | strategy | 8a4d48275683 | `D:\QM\reports\work_items\ff065f50-f601-400b-a235-e504ad1737ea\QM5_20007\Q02\preflight_failure.json` |
| 2026-07-23T09:51:58+00:00 | 3c374021-1a75-41b8-94b5-947a10aedebd | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | f98496865a05 | — |
| 2026-07-23T10:13:11+00:00 | 41a0e249-efa3-476e-b13a-a82c9e60571c | NDX.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS | infra | 300654ce6db3 | `D:\QM\reports\work_items\41a0e249-efa3-476e-b13a-a82c9e60571c\QM5_20007\20260723_101219\summary.json` |
| 2026-07-23T10:20:23+00:00 | cf6adb40-ee1c-40d6-bc83-0c5f2950600c | XAUUSD.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | da641e400a59 | `D:\QM\reports\work_items\cf6adb40-ee1c-40d6-bc83-0c5f2950600c\QM5_20007\20260723_100225\summary.json` |
| 2026-07-23T11:36:14+00:00 | 04ad12c0-6eac-4793-9b52-62fbe5f678c5 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 5e6a5fd1a5ad | `D:\QM\reports\work_items\04ad12c0-6eac-4793-9b52-62fbe5f678c5\QM5_20007\20260723_112654\summary.json` |
| 2026-07-23T16:01:42+00:00 | e5915858-8fd7-46ac-87f4-266cafda73c6 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 8f8b399df24f | `D:\QM\reports\work_items\e5915858-8fd7-46ac-87f4-266cafda73c6\QM5_20007\20260723_155211\summary.json` |
| 2026-07-24T03:45:50+00:00 | f829723d-af51-487e-92e4-d72773412fc1 | NDX.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS | infra | 1b99be1e55ac | `D:\QM\reports\work_items\f829723d-af51-487e-92e4-d72773412fc1\QM5_20007\20260724_034519\summary.json` |
| 2026-07-24T20:51:54+00:00 | 876faa54-26ca-45e0-ae16-0d99ca4a8b3a | SP500.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 38e2b06f3be9 | — |
| 2026-07-25T06:40:02+00:00 | eecf18cb-7112-4b7c-9f84-65069054f150 | NDX.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS | infra | 969a771e35cc | `D:\QM\reports\work_items\eecf18cb-7112-4b7c-9f84-65069054f150\QM5_20007\20260725_063839\summary.json` |
| 2026-07-26T00:50:16+00:00 | b3d2dfd4-4625-4281-9404-16be3490bf2a | SP500.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 06e792f82574 | — |
| 2026-07-26T01:25:49+00:00 | 96bc5dd3-b020-4cdc-95b2-f5890b030ff9 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | b93c3308d03f | `D:\QM\reports\work_items\96bc5dd3-b020-4cdc-95b2-f5890b030ff9\QM5_20007\20260726_011956\summary.json` |
| 2026-07-26T05:08:23+00:00 | 9f2c5fc5-d693-418e-a75f-5d1e8b767d14 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 5808fe48c889 | `D:\QM\reports\work_items\9f2c5fc5-d693-418e-a75f-5d1e8b767d14\QM5_20007\20260726_050206\summary.json` |
| 2026-07-26T10:10:27+00:00 | 630362f3-b532-4702-8c71-dde4a42337e2 | SP500.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 05f8c436053c | — |
| 2026-07-26T15:26:07+00:00 | 0728c588-258e-402b-ad7f-eb208cb2b033 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 2176b0cf03e8 | `D:\QM\reports\work_items\0728c588-258e-402b-ad7f-eb208cb2b033\QM5_20007\20260726_151936\summary.json` |
| 2026-07-26T17:53:16.803239+00:00 | 80c64b67-7eaa-461e-ba1c-80892f7cf73d | XAUUSD.DWX | pending | — | 0 | — | — | fc7d3fa66d69 | — |
| 2026-07-27T14:37:53+00:00 | f792f7e5-56d4-4073-86a7-7a3a8e7c9aab | NDX.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS | infra | 91551f2d8fb4 | `D:\QM\reports\work_items\f792f7e5-56d4-4073-86a7-7a3a8e7c9aab\QM5_20007\20260727_143512\summary.json` |
| 2026-07-27T19:19:54+00:00 | a1c84d31-101b-4bb6-94f5-434d64fc47b6 | SP500.DWX | done | INFRA_FAIL | 0 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | f7edd8934213 | `D:\QM\reports\work_items\a1c84d31-101b-4bb6-94f5-434d64fc47b6\QM5_20007\20260727_191337\summary.json` |
| 2026-07-29T00:24:37+00:00 | 93a3c65c-1de7-4ed8-9125-dd51e6090d21 | NDX.DWX | failed | INFRA_FAIL | 3 | cold_cache_retries_exhausted:NO_HISTORY | infra | 5b49a211c860 | `D:\QM\reports\work_items\93a3c65c-1de7-4ed8-9125-dd51e6090d21\QM5_20007\20260729_001130\summary.json` |
| 2026-07-29T12:18:03+00:00 | 141d7226-714a-48fd-bae5-e6d9c235c072 | SP500.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 5556cf7abfd5 | `D:\QM\reports\work_items\141d7226-714a-48fd-bae5-e6d9c235c072\QM5_20007\20260724_022539\raw\run_01\report.htm` |
| 2026-07-29T12:18:03+00:00 | 152944aa-d695-411a-b6d7-63016fedfd1f | SP500.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | cbe9584eff2b | `D:\QM\reports\work_items\152944aa-d695-411a-b6d7-63016fedfd1f\QM5_20007\20260723_222759\raw\run_01\report.htm` |
| 2026-07-29T12:18:03+00:00 | 59aef46f-3980-400c-919a-263b4edf720b | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 05031b6a1cdd | `D:\QM\reports\work_items\59aef46f-3980-400c-919a-263b4edf720b\QM5_20007\20260728_221635\raw\run_01\report.htm` |
| 2026-07-29T12:18:03+00:00 | 6e9a4581-2342-4d31-a0cc-1512f1c07454 | NDX.DWX | failed | INFRA_FAIL | 1 | cold_cache_retry:NO_HISTORY | strategy | 185b2dab5d8c | `D:\QM\reports\work_items\6e9a4581-2342-4d31-a0cc-1512f1c07454\QM5_20007\20260727_151106\summary.json` |
| 2026-07-31T10:43:10+00:00 | 0928164a-2c70-448b-ae23-4cfaf6c06c6a | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 0795f7c6b168 | — |
| 2026-07-31T15:22:21+00:00 | 05652c88-8e07-4aaf-934f-1e013ac8deda | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | b5ef28981b9f | — |
| 2026-07-31T15:37:23+00:00 | 6dce5d90-4a59-4753-9830-9eebdaeed397 | NDX.DWX | failed | INFRA_FAIL | 3 | cold_cache_retries_exhausted:NO_HISTORY | infra | 54f0d4691702 | `D:\QM\reports\work_items\6dce5d90-4a59-4753-9830-9eebdaeed397\QM5_20007\20260731_153517\summary.json` |
| 2026-07-31T21:19:50+00:00 | 8875b7e3-2627-4112-8e16-ffd260e286ff | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 6491f08e8261 | — |
| 2026-08-01T00:44:16+00:00 | e07c872a-09f9-4dcc-9497-5d84e3004209 | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | fed86dd0860f | — |
| 2026-08-01T06:17:51+00:00 | c2e34ae2-4c02-495d-99f8-aa83aba65bb1 | NDX.DWX | done | INFRA_FAIL | 1 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 9d55f43a4898 | `D:\QM\reports\work_items\c2e34ae2-4c02-495d-99f8-aa83aba65bb1\QM5_20007\20260801_060108\summary.json` |
| 2026-08-01T15:39:26+00:00 | a9e68f4e-e77b-4a51-b258-f505f869f507 | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | 1dab000ae842 | — |
| 2026-08-01T17:49:48+00:00 | 7becdbe6-842a-41ae-a03c-750ee79eb579 | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | fb21b43a0e9c | — |
| 2026-08-01T19:37:54+00:00 | 74c0678e-04f8-4ffa-a01b-7d4d11565660 | NDX.DWX | done | INFRA_FAIL | 1 | run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS | infra | 7baaf6bb2b7d | `D:\QM\reports\work_items\74c0678e-04f8-4ffa-a01b-7d4d11565660\QM5_20007\20260801_192044\summary.json` |
| 2026-08-01T22:05:05+00:00 | 60b25bb0-c921-484f-8ea0-150db9e5b4b9 | GDAXI.DWX | failed | INFRA_FAIL | 0 | shared_bases_history_lock_transient_cap_exhausted | — | c7d1bb3631d6 | — |
| 2026-08-01T22:59:40+00:00 | dfa4ecdb-2db1-454c-95e3-8f24bf380fd7 | NDX.DWX | failed | INFRA_FAIL | 3 | cold_cache_retries_exhausted:NO_HISTORY | infra | c00e41d560f6 | `D:\QM\reports\work_items\dfa4ecdb-2db1-454c-95e3-8f24bf380fd7\QM5_20007\20260801_225851\summary.json` |

## Recent-row failure signatures

The table distinguishes the **stored classifier verdict** from the **current-run artifact signature**. `WI` below means `D:\QM\reports\work_items`; every work-item log is under `D:\QM\strategy_farm\logs`.

| row / updated_at | final slot and stored payload result | actual bound signature | report_root / primary evidence |
|---|---|---|---|
| `0928164a-2c70-448b-ae23-4cfaf6c06c6a` / 2026-07-31 10:43:10Z | T9; failed/INFRA_FAIL; attempt 0; `shared_bases_history_lock_transient_cap_exhausted`; taxonomy absent | Genuine conversion-history sharing violation: six `EURUSD.DWX ... error [32]`, then `some error after pass finished`; wrapper later ends without a summary. | `WI\0928164a-2c70-448b-ae23-4cfaf6c06c6a`; `D:\QM\mt5\T9\logs\20260731.log:547-565`; `D:\QM\strategy_farm\logs\work_item_0928164a-2c70-448b-ae23-4cfaf6c06c6a.log:7-11` |
| `05652c88-8e07-4aaf-934f-1e013ac8deda` / 2026-07-31 15:22:21Z | T5; failed/INFRA_FAIL; attempt 0; same cap reason; taxonomy absent | Genuine conversion-history sharing violation: six `EURUSD.DWX ... error [32]`, then `some error after pass finished`. | `WI\05652c88-8e07-4aaf-934f-1e013ac8deda`; `D:\QM\mt5\T5\logs\20260731.log:285-303`; `D:\QM\strategy_farm\logs\work_item_05652c88-8e07-4aaf-934f-1e013ac8deda.log:7-11` |
| `8875b7e3-2627-4112-8e16-ffd260e286ff` / 2026-07-31 21:19:50Z | T1; failed/INFRA_FAIL; attempt 0; same cap reason; taxonomy absent | **False classifier result.** Terminal says `successfully finished`; runner latched a complete 931,900-byte report, then vanished after `terminal_exit` before summary publication. The report contains GDAXI/M15/2022-H2 and 450 trades. | `WI\8875b7e3-2627-4112-8e16-ffd260e286ff`; `D:\QM\strategy_farm\logs\work_item_8875b7e3-2627-4112-8e16-ffd260e286ff.log:7-12`; `D:\QM\mt5\T1\logs\20260731.log:2473-2487`; `D:\QM\mt5\T1\QM5_20007_GDAXI_DWX_20260731_211606_run_01.htm` |
| `e07c872a-09f9-4dcc-9497-5d84e3004209` / 2026-08-01 00:44:16Z | T9; failed/INFRA_FAIL; attempt 0; same cap reason; taxonomy absent | **False classifier result.** Runner latched a complete 931,900-byte report and stopped after `terminal_exit`. Its recorded classifier evidence is the prior day's `T9\logs\20260731.log`, not the current run in `20260801.log`. | `WI\e07c872a-09f9-4dcc-9497-5d84e3004209`; `D:\QM\strategy_farm\logs\work_item_e07c872a-09f9-4dcc-9497-5d84e3004209.log:7-12`; `D:\QM\mt5\T9\logs\20260801.log:122-133`; `D:\QM\mt5\T9\QM5_20007_GDAXI_DWX_20260801_004026_run_01.htm` |
| `c2e34ae2-4c02-495d-99f8-aa83aba65bb1` / 2026-08-01 06:17:51Z | T4; done/INFRA_FAIL; attempt 1; `run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS`; infra | Deterministic full-window invalid-stop journal bomb: 1.48 GB at ~8,762 MB/min. `oninit_failure_detected=false`; no report was completed. Its prior six-month prescreen passed on T9 with 356 trades. | `WI\c2e34ae2-4c02-495d-99f8-aa83aba65bb1`; final `summary.json:5-17,97-107,135-150`; work log `D:\QM\strategy_farm\logs\work_item_c2e34ae2-4c02-495d-99f8-aa83aba65bb1.log:11-18`; journal `D:\QM\mt5\T4\Tester\logs\20260801.log:2980-2987`; prescreen `WI\c2e34ae2-4c02-495d-99f8-aa83aba65bb1\QM5_20007\20260801_043556\summary.json:5-32,96-106,138-157` |
| `a9e68f4e-e77b-4a51-b258-f505f869f507` / 2026-08-01 15:39:26Z | T5; failed/INFRA_FAIL; attempt 0; history-lock cap; taxonomy absent | **False classifier result.** T5 says `successfully finished`; runner latched a complete 931,900-byte report and then stopped before summary publication. | `WI\a9e68f4e-e77b-4a51-b258-f505f869f507`; `D:\QM\strategy_farm\logs\work_item_a9e68f4e-e77b-4a51-b258-f505f869f507.log:7-12`; `D:\QM\mt5\T5\logs\20260801.log:1079-1091`; `D:\QM\mt5\T5\QM5_20007_GDAXI_DWX_20260801_153522_run_01.htm` |
| `7becdbe6-842a-41ae-a03c-750ee79eb579` / 2026-08-01 17:49:48Z | T3; failed/INFRA_FAIL; attempt 0; history-lock cap; taxonomy absent | **False classifier class.** The bound current run says `tester not started because the account is not specified` and exits `-1000012353`; the payload instead cites stale `D:\QM\mt5\T3\logs\20260729.log` for `some error after pass finished`. | `WI\7becdbe6-842a-41ae-a03c-750ee79eb579`; `D:\QM\mt5\T3\logs\20260801.log:1304-1314`; `D:\QM\strategy_farm\logs\work_item_7becdbe6-842a-41ae-a03c-750ee79eb579.log:7-12`; payload in `D:\QM\strategy_farm\state\farm_state.sqlite` |
| `74c0678e-04f8-4ffa-a01b-7d4d11565660` / 2026-08-01 19:37:54Z | T7; done/INFRA_FAIL; attempt 1; `run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS`; infra | Same deterministic full-window invalid-stop journal bomb: 1.48 GB at ~8,805 MB/min. Its six-month prescreen passed on T6 with the same 356 trades as the other NDX prescreens. | `WI\74c0678e-04f8-4ffa-a01b-7d4d11565660`; final `summary.json:5-17,97-107,135-150`; work log `D:\QM\strategy_farm\logs\work_item_74c0678e-04f8-4ffa-a01b-7d4d11565660.log:11-19`; journal `D:\QM\mt5\T7\Tester\logs\20260801.log:600946-600953`; prescreen `WI\74c0678e-04f8-4ffa-a01b-7d4d11565660\QM5_20007\20260801_175528\summary.json:5-32,96-106,138-157` |
| `60b25bb0-c921-484f-8ea0-150db9e5b4b9` / 2026-08-01 22:05:05Z | T2; failed/INFRA_FAIL; attempt 0; history-lock cap; taxonomy absent | **False classifier result.** T2 says `successfully finished`; runner latched a complete 931,900-byte report. Payload cites the previous day's `T2\logs\20260801.log`, while this current run is the first record in `20260802.log`. | `WI\60b25bb0-c921-484f-8ea0-150db9e5b4b9`; `D:\QM\strategy_farm\logs\work_item_60b25bb0-c921-484f-8ea0-150db9e5b4b9.log:7-12`; `D:\QM\mt5\T2\logs\20260802.log:1-13`; `D:\QM\mt5\T2\QM5_20007_GDAXI_DWX_20260801_220053_run_01.htm` |
| `dfa4ecdb-2db1-454c-95e3-8f24bf380fd7` / 2026-08-01 22:59:40Z | T4; failed/INFRA_FAIL; attempt 3; `cold_cache_retries_exhausted:NO_HISTORY`; infra | Three final T4 attempts yielded 22,320-byte skeleton reports with empty expert/symbol, M0/1970, zero bars/ticks/symbols, matching immediate `NDX.DWX ... error [32]`. Earlier full attempts on T9, T10, and T1 show the same signature. Prescreen passed on T5 with 356 trades. | `WI\dfa4ecdb-2db1-454c-95e3-8f24bf380fd7`; work log `D:\QM\strategy_farm\logs\work_item_dfa4ecdb-2db1-454c-95e3-8f24bf380fd7.log:7-37`; final `summary.json:5-17,123-133,162-180`; raw report `...\20260801_225851\raw\run_01\report.htm:38-85`; terminal paths cited in Executive diagnosis; prescreen `...\20260801_215226\summary.json:5-32,96-106,138-157` |

## GDAXI: why complete runs became `attempt_count=0` INFRA_FAIL

### 1. The inner and outer post-exit timers contradict each other

After a complete report appears, `Start-TesterRun` latches it, force-stops terminal/metatester processes, logs `terminal_exit`, and returns (`framework/scripts/run_smoke.ps1:1683-1752`). The caller then waits for metatester quiescence, snapshots the structured logger, and decides whether to wait as long as 240 seconds for report export before copying/publishing it (`framework/scripts/run_smoke.ps1:2441-2487`). Its process query is an unbounded `Get-CimInstance Win32_Process` operation (`framework/scripts/run_smoke.ps1:1872-1920`).

The outer worker, however, regards a Q02 wrapper as stalled when its log has contained `terminal_exit`, no summary exists, and the log has been quiet for only 60 seconds (`tools/strategy_farm/terminal_worker.py:165`, `:2105-2130`). It kills both the wrapper tree and terminal slot (`tools/strategy_farm/terminal_worker.py:2826-2829`). It then loses the real child status and hard-codes `exit_code=0` whenever the process is gone after a plausible runtime (`tools/strategy_farm/terminal_worker.py:2927-2979`), so `run_smoke_exit_code=0` does not prove a clean wrapper exit.

The artifact timings match this path closely. MT5 terminal logs are local Europe/Berlin time; conversion below is to UTC for comparison with the database:

| row | bound outcome/report UTC | DB `updated_at` | delay |
|---|---:|---:|---:|
| `0928164a` | 10:41:47 (`D:\QM\mt5\T9\logs\20260731.log:565`) | 10:43:10 | 83 s |
| `05652c88` | 15:21:01 (`D:\QM\mt5\T5\logs\20260731.log:303`) | 15:22:21 | 80 s |
| `8875b7e3` | 21:18:38 (`D:\QM\mt5\T1\logs\20260731.log:2487`) | 21:19:50 | 72 s |
| `e07c872a` | 00:43:03 (UTC mtime of `D:\QM\mt5\T9\QM5_20007_GDAXI_DWX_20260801_004026_run_01.htm`) | 00:44:16 | 73 s |
| `a9e68f4e` | 15:38:16 (`D:\QM\mt5\T5\logs\20260801.log:1091`) | 15:39:26 | 70 s |
| `7becdbe6` | 17:48:36 (`D:\QM\mt5\T3\logs\20260801.log:1312-1314`) | 17:49:48 | 72 s |
| `60b25bb0` | 22:03:50 (`D:\QM\mt5\T2\logs\20260802.log:13`) | 22:05:05 | 75 s |

All seven are consistent with the 60-second watchdog plus the worker's two-second polling and classification/DB time. Four work logs end immediately after `valid_report_latched` / `terminal_exit`; none reaches `report_wait_skipped`, `run_smoke.result`, or `run_smoke.summary` (`D:\QM\strategy_farm\logs\work_item_8875b7e3-2627-4112-8e16-ffd260e286ff.log:11-12`; the same terminal ending is at lines 11-12 in the `e07c872a`, `a9e68f4e`, and `60b25bb0` work logs). By contrast, a clean comparison run continues from `terminal_exit` through report publication and summary (`D:\QM\strategy_farm\logs\work_item_6f59ddb6-ca3c-4c8b-ac80-dbacfd83814e.log:11-20`).

The precise post-exit subcall that held each dead wrapper cannot be recovered because the watchdog recorded no stack and discarded the real exit code. The proven defect is still sufficient: the outer 60-second deadline is shorter than the inner contract, and it can destroy an already-complete report handoff.

### 2. The fallback classifier is not bound to the failed run

Only when no summary is found does the worker scan terminal, dispatcher, and agent log tails (`tools/strategy_farm/terminal_worker.py:2355-2367`). `_detect_history_lock_storm()` sorts all log files by mtime and searches up to six 256-KiB tails for either `history synchronization error` or `some error after pass finished`; it never checks the claimed start time, work-item ID, tested symbol, tester ini, or even same-day log (`tools/strategy_farm/terminal_worker.py:103-142`, `:973-1025`).

Concrete false bindings are present in the payloads in `D:\QM\strategy_farm\state\farm_state.sqlite`:

- `e07c872a` ran in `D:\QM\mt5\T9\logs\20260801.log:122-133`, but payload evidence points to `D:\QM\mt5\T9\logs\20260731.log`.
- `7becdbe6` actually failed because T3 had no configured account (`D:\QM\mt5\T3\logs\20260801.log:1310-1314`), but payload evidence points to `D:\QM\mt5\T3\logs\20260729.log` and calls it a history storm.
- `60b25bb0` successfully finished in `D:\QM\mt5\T2\logs\20260802.log:1-13`, but payload evidence points to `D:\QM\mt5\T2\logs\20260801.log`.

Once any stale token matches, the code increments `transient_infra_attempts`, clears runtime keys, and steers to another terminal without incrementing `attempt_count`; after a cap of six retries, the seventh classification becomes `shared_bases_history_lock_transient_cap_exhausted` (`tools/strategy_farm/terminal_worker.py:2373-2431`). Each recent GDAXI payload has `transient_infra_attempts=7` and seven avoided terminals. That is 49 classified attempts spread across the fleet: T1=7, T9=7, T2=6, T3=6, T5=6, T6=6, T4=5, T8=4, T7=2 (the individual `retrying_transient_infra` / `transient_cap_exhausted` events are in `D:\QM\strategy_farm\logs\terminal_worker_T1.log` through `terminal_worker_T9.log`). This is not a one-terminal cluster.

### 3. Four final reports prove the rows were not all data failures

The retained complete reports are:

- `D:\QM\mt5\T1\QM5_20007_GDAXI_DWX_20260731_211606_run_01.htm` (931,900 bytes)
- `D:\QM\mt5\T9\QM5_20007_GDAXI_DWX_20260801_004026_run_01.htm` (931,900 bytes)
- `D:\QM\mt5\T5\QM5_20007_GDAXI_DWX_20260801_153522_run_01.htm` (931,900 bytes)
- `D:\QM\mt5\T2\QM5_20007_GDAXI_DWX_20260801_220053_run_01.htm` (931,900 bytes)

For example, the T2 report identifies the expected EA, GDAXI, M15, and 2022-07-01 through 2022-12-31 (`...220053_run_01.htm:38-47`), and contains net profit -3,484.61, PF 0.98, and 450 completed trades (`:272-300`, `:334-339`). It is a valid prescreen artifact, not an empty shell. The four files have different SHA-256 values because report metadata/embedded image references differ, but their tested identity and headline metrics agree.

## NDX: deterministic log bomb and separate history-lock rows

### 1. Reproduction and code-level cause of `LOG_BOMB`

The two full-window failures are independently identical:

- T4: the runner killed `D:\QM\mt5\T4\Tester\Agent-127.0.0.1-3002\logs\20260801.log` at 1.48 GB, rate ~8,762 MB/min (`D:\QM\strategy_farm\logs\work_item_c2e34ae2-4c02-495d-99f8-aa83aba65bb1.log:11-16`; summary `...\20260801_060108\summary.json:97-107,135-150`).
- T7: the runner killed `D:\QM\mt5\T7\Tester\Agent-127.0.0.1-3004\logs\20260801.log` at 1.48 GB, rate ~8,805 MB/min (`D:\QM\strategy_farm\logs\work_item_74c0678e-04f8-4ffa-a01b-7d4d11565660.log:11-17`; summary `...\20260801_192044\summary.json:97-107,135-150`).

The surviving dispatcher mirrors expose the exact flood. Eight consecutive logical lines on T4 and T7 show the current stop and requested stop both normalize to 12935.8, yet MT5 receives and rejects the modification on every tick (`D:\QM\mt5\T4\Tester\logs\20260801.log:2980-2987`; `D:\QM\mt5\T7\Tester\logs\20260801.log:600946-600953`).

The causal chain is:

1. Momentum VWAP trail inputs `g_session_vwap` and `g_mb_atr` are cached on a new bar, but `Strategy_ManageOpenPosition()` runs on every tick (`framework/EAs/QM5_20007_intraday-config-engine/QM5_20007_intraday-config-engine.mq5:340-365`, `:451-477`).
2. The EA compares the **raw** `vwap_sl` with `cur_sl`. A raw value slightly above 12935.8 therefore passes even when symbol-digit normalization produces the existing 12935.8 (`...mq5:351-365`; normalization occurs in `framework/include/QM/QM_TradeManagement.mqh:44-52`, `:135-140`).
3. The common trade manager contains suppression and minimum-stop-distance hygiene specifically designed to stop repeated invalid modifies (`QM_TradeManagement.mqh:55-61`), but line 147 defines it as live-only. Both identical-target suppression and the stops-level precheck are skipped in the tester (`:142-187`), after which every call is sent and logged (`:189-212`).

The runner's log-bomb verdict is therefore correct and non-merit, but its source is EA/framework behavior, not terminal capacity.

### 2. Why six months passes but two years bombs

Each recent NDX row first completed the exact same six-month M15 prescreen with 356 trades and no OnInit or log-bomb flag:

- T9: `D:\QM\reports\work_items\c2e34ae2-4c02-495d-99f8-aa83aba65bb1\QM5_20007\20260801_043556\summary.json:5-32,96-106,138-157`
- T6: `D:\QM\reports\work_items\74c0678e-04f8-4ffa-a01b-7d4d11565660\QM5_20007\20260801_175528\summary.json:5-32,96-106,138-157`
- T5: `D:\QM\reports\work_items\dfa4ecdb-2db1-454c-95e3-8f24bf380fd7\QM5_20007\20260801_215226\summary.json:5-32,96-106,138-157`

The longer 2021-2022 run reaches the same invalid-target condition and produces enough per-tick output to trip the growth guard. Passing prescreen therefore proves initialization/data availability for that run; it does not disprove the deterministic full-window journal bomb.

### 3. `dfa4ecdb`: `NO_HISTORY` is a sharing violation, not absent data

All three T4 run attempts publish 22,320-byte skeleton reports. The first has blank expert and symbol, M0/1970, zero deposit, and zero bars/ticks/symbols (`D:\QM\reports\work_items\dfa4ecdb-2db1-454c-95e3-8f24bf380fd7\QM5_20007\20260801_225851\raw\run_01\report.htm:38-85`). The summary correctly maps this to `NO_HISTORY` and its concrete invalid classes (`...\summary.json:163-180`). The bound T4 log begins the tester and immediately emits nine `NDX.DWX ... error [32]` lines for each run (`D:\QM\mt5\T4\logs\20260802.log:48-121`). T9, T10, and T1 show the same sequence for prior attempts of this same row (paths in Executive diagnosis).

At inspection time, `D:\QM\mt5\T1\bases` through `D:\QM\mt5\T10\bases` are ordinary directories, not reparse-point junctions, and their `Darwinex-Live\history\EURUSD\2022.hcc` files have distinct NTFS file IDs. This conflicts with the older junction assumption still documented in `tools/strategy_farm/terminal_worker.py:108-121`. Accordingly, the evidence supports a **local/profile handle collision or lingering terminal/metatester process**, but not a claim that the current T2-T10 directory entries still junction to T1. A future online canary with handle tracing is required to name the exact owning process/file. No data was repaired or refreshed in this read-only investigation.

## Successful index control and terminal clustering

A same-timeframe control exists: work item `6f59ddb6-ca3c-4c8b-ac80-dbacfd83814e` (`QM5_10399`, NDX M15, 2021-2022) completed Q02 on T9 at 2026-08-01 01:28:44Z. Its summary is `PASS`, has `oninit_failure_detected=false`, `log_bomb_detected=false`, a complete 863,944-byte report, and 404 trades (`D:\QM\reports\work_items\6f59ddb6-ca3c-4c8b-ac80-dbacfd83814e\QM5_10399\20260801_012559\summary.json:5-32,96-106,135-157`). Its work log proceeds normally from `valid_report_latched` through summary publication (`D:\QM\strategy_farm\logs\work_item_6f59ddb6-ca3c-4c8b-ac80-dbacfd83814e.log:1-20`). This isolates the difference to QM5_20007's behavior and transient profile state, not a universal NDX/M15 history outage.

There is no stable terminal cluster:

- The seven GDAXI rows exhausted 49 classifications across nine slots; their final slots were T9, T5, T1, T9, T5, T3, and T2. Evidence is distributed across `D:\QM\strategy_farm\logs\terminal_worker_T1.log` through `terminal_worker_T9.log` and the per-row payload `avoid_terminals` arrays in `D:\QM\strategy_farm\state\farm_state.sqlite`.
- NDX prescreen succeeded on T9, T6, and T5, while full-window log bombs occurred on T4 and T7 and sharing violations occurred on T9, T10, T1, and T4 (paths above).
- T5 is specifically exonerated as a unique cause: it had one GDAXI `[32]` final attempt (`D:\QM\mt5\T5\logs\20260731.log:285-303`), later completed the `a9e68f4e` GDAXI report (`D:\QM\mt5\T5\logs\20260801.log:1079-1091`), and passed the `dfa4ecdb` NDX prescreen (`...\20260801_215226\summary.json:5-32,96-106,138-157`). Reactivation alone did not cause the cohort.
- T3 did have a separate actionable configuration fault: `account is not specified` for `7becdbe6` and subsequent work (`D:\QM\mt5\T3\logs\20260801.log:1304-1369`).

## EA source, setfiles, and OnInit requirements

The recent failures do not reveal an unmet EA-specific OnInit dependency:

- `OnInit()` only delegates to `QM_FrameworkInit()` and returns `INIT_FAILED` if that common initialization fails (`framework/EAs/QM5_20007_intraday-config-engine/QM5_20007_intraday-config-engine.mq5:404-427`).
- The common initialization resolves magic/risk, installs a single-symbol guard, and loads the shared news calendar when news is active (`framework/include/QM/QM_Common.mqh:170-245`). The momentum/ORB design has no multi-symbol dependency; only the gold lane has a D1 reference (`framework/EAs/QM5_20007_intraday-config-engine/SPEC.md:56-62`).
- All ten recent work logs say `run_smoke.news_calendar_status=OK` at line 5 of their cited `D:\QM\strategy_farm\logs\work_item_<uuid>.log`. Both final NDX log-bomb summaries explicitly say `oninit_failure_detected=false`, and the three NDX prescreens passed.
- The NDX failure summary binds the repository EX5 and deployed EX5 to identical SHA-256 `07ecef...fbc3`, and the repository/deployed NDX setfile to identical SHA-256 `d8d3...6b5a`; both remained stable during the run (`D:\QM\reports\work_items\c2e34ae2-4c02-495d-99f8-aa83aba65bb1\QM5_20007\20260801_060108\summary.json:38-95`).
- The GDAXI and NDX setfiles have the expected EA ID/risk fields and differ materially only in symbol metadata and magic slot 0 versus 1; both select `LANE_MOMENTUM_BAND` (`framework/EAs/QM5_20007_intraday-config-engine/sets/QM5_20007_intraday-config-engine_GDAXI.DWX_M15_backtest.set:1-24`; `.../QM5_20007_intraday-config-engine_NDX.DWX_M15_backtest.set:1-24`). There is no evidence of a setfile parse failure.

The broader 2026-07-31 stranded-pair packet counted 279 pairs, including 98 `ONINIT_FAILED` and 46 `ACTIVE_TIMEOUT`, but it also found zero calendar-hard members (`docs/ops/evidence/2026-07-31_q02_stranded_pairs_classification.md:13-34`, `:112-114`). Those cohort counts are context, not the concrete class for the recent QM5_20007 rows.

## Recommended correction and effort

### P0 — runner/classifier code fix before any requeue (0.5-1.0 developer day)

1. Make `valid_report_latched` a durable handoff: copy/publish and validate the complete terminal-root report before optional WMI/logger cleanup, or have the outer watchdog salvage a complete bound report before killing/reclassifying. A complete current-run report must take precedence over tail tokens. Relevant code: `framework/scripts/run_smoke.ps1:1683-1752`, `:2441-2487`; `tools/strategy_farm/terminal_worker.py:2105-2130`, `:2826-2829`.
2. Align the outer deadline with the inner contract: either emit a post-exit heartbeat and bound the WMI call, or set the watchdog beyond the 240-second maximum plus margin. Sixty seconds cannot safely supervise a documented 240-second inner wait (`terminal_worker.py:165`; `run_smoke.ps1:2470-2477`).
3. Scope `_detect_history_lock_storm()` to the current claim: require log mtime/current-run time, exact terminal and symbol, and a marker after this work item's tester ini/start. Never use a prior-day tail. Persist the actual matched line/time rather than only the path (`terminal_worker.py:973-1025`).
4. Preserve the real wrapper return code or record that it was killed by the post-exit watchdog; do not hard-code zero for every disappeared process (`terminal_worker.py:2927-2979`).

### P0 — QM5_20007 SL-modify code fix and rebuild (0.5 developer day)

For the momentum lane, normalize the candidate before comparing it with `POSITION_SL`, require at least one point/tick of real improvement, and attempt a bar-cached VWAP target at most once per new bar (or remember/suppress an unchanged failed target). Also add an unconditional framework no-op guard when normalized requested SL/TP equals the current SL/TP; a no-op guard cannot change a successful trade path. Do not merely disable the log-bomb guard. Relevant code: `QM5_20007...mq5:340-365,451-477`; `QM_TradeManagement.mqh:44-60,135-212,368-374`.

Compile a new EX5 and verify its identity under the normal build gate. The two-year NDX canary must show no repeated identical `Invalid stops`, bounded journal growth, and a canonical summary. This ticket authorizes diagnosis only, so no source or EX5 was changed.

### P1 — targeted runtime/profile correction in the OFF window (2-4 operator hours)

1. Repair T3's missing account/profile configuration before it returns to service (`D:\QM\mt5\T3\logs\20260801.log:1310-1369`).
2. With all MT5 processes still stopped, verify each slot has its own current account/history profile and no unintended reparse/hard-link sharing. The current read-only observation already shows distinct bases/file IDs, so a blanket “de-junction T2-T10” change is not supported without reconfirmation.
3. After ON, run one controlled handle-traced canary to identify which process/file owns the `[32]` collision. Validate both the tested index and GDAXI's `EURUSD.DWX` conversion history. Quarantine a slot on a current-run `[32]`; do not rotate through stale-tail evidence.
4. Do not rebuild or bulk-reimport history unless the stopped-state integrity check fails. Successful NDX/GDAXI reports prove that history exists; `[32]` is access contention, not `file not found`.

### P1 — canary, then requeue (2-4 elapsed hours after build/runtime fix)

Run one GDAXI prescreen canary and one NDX 2021-2022 full-window canary on known-good, configured slots. Acceptance requires: bound current-run logs; calendar/setfile/EX5 identity; no stale-tail classification; canonical `summary.json`; no repeated normalized no-op modifies; and no error 32. Only after both pass should OWNER authorize repair/requeue of the affected rows. The four retained complete GDAXI reports may support an audited prescreen-state repair, but they must not be silently promoted by this diagnosis.

**Total estimate:** approximately 1-1.5 developer days plus 0.5 operator day, usually two working days including canaries. A bare “requeue after ON” is not recommended: GDAXI would repeat the 60-second/stale-tail cycle and NDX would deterministically bomb again.

## Root-cause statement

QM5_20007's recent Q02 INFRA_FAILs are caused by a 60-second outer watchdog and unscoped stale-tail classifier discarding/mislabeling GDAXI report handoffs, plus an EA-specific per-tick normalized no-op/invalid-stop loop that log-bombs NDX full runs, with intermittent local history-handle `[32]` and T3 account configuration faults as secondary runtime defects.
