# Calendar bundle as an effective EA input — implementation and requalification adjudication

**Date:** 2026-08-02/03

**Router task:** `870f730d-151e-4373-901e-4b56d91c8509`

**Authority:** `docs/ops/CODEX_BRIEF_2026-08-02_calendar_bundle_input.md`

**Predecessor:** `docs/ops/evidence/2026-08-02_q09_news_executor.md`

**Implementer:** Codex

**Required reviewer:** Claude

**Disposition:** `REVIEW` only. This document is not a pipeline verdict, admission, deployment authority, or permission to enqueue.

## Result and recommendation

The Q09 calendar bundle is now a report-visible, authenticated **tester input**. When any bundle field is supplied, the tester requires all three fields, reads only the sealed `FILE_COMMON` relative path, verifies the SHA-256 before parsing, re-verifies the bytes after parsing, and refuses initialization on every absence, malformed binding, hash mismatch, parse failure, zero-row result, or replacement race. Empty legacy inputs continue through the pre-existing loader. Live decisions remain on the native MT5 calendar path.

The five requested binaries were built serially. Every accepted build has `0 errors, 0 warnings`; hashes are recorded below. No tester, pipeline phase, enqueue, T_Live operation, deployment, AutoTrading change, or manual `terminal64.exe` start was performed.

**Single requalification recommendation:** restart at **Q02** on the new binary for `QM5_11422`, `QM5_13013`, `QM5_13036`, and `QM5_20048`, then advance append-only through Q08 and Q09. Do not use the Q08-only exception. It saves an estimated four to six terminal-hours for those four candidates, but would require a new governed old/new binary staging and deal-comparison artifact, an OWNER exception to the current vintage doctrine, and a fallback full restart on any mismatch. The touched shared initialization include and changed EA input layout make source inspection or compile success insufficient as identity proof.

`QM5_10440` is **blocked from enqueue**, not silently included in that command sequence. Its available Q02 rows lack the execution bindings required by the append-only stale-PASS guard, and a separate current brief identifies `10440/NDX` as a live DXZ sleeve while this brief calls it an admission candidate and simultaneously prohibits recompiling live-book EAs. The repository EX5 was compiled because this brief explicitly listed 10440, but it must remain a review/requalification artifact and must not be deployed. Claude/OWNER must resolve the live-book contradiction and establish a provenance-bound Q02 source before any 10440 chain action.

## Framework diff rationale

### Effective tester inputs

`framework/include/QM/QM_NewsFilter.mqh` declares three plain inputs:

```mql5
input string qm_news_calendar_bundle_id = "";
input string qm_news_calendar_expected_sha256 = "";
input string qm_news_calendar_common_relative_path = "";
```

Plain `input string` declarations make MT5 record the effective values in the report Inputs region. `tools/strategy_farm/q09_news_runner.py` now authenticates all three report values, together with the seed, temporal/compliance modes, fixed-risk contract, and the 336-hour maximum stale-news guard. The runner test removes one calendar field from a fixture report and proves collection refuses it.

### Fail-closed sealed-bundle loader

The tester-only branch implements these checks in order:

1. Any non-empty bundle field makes the bundle requested. A partial declaration returns `SETUP_DATA_MISSING` with `calendar_bundle_inputs_partial`.
2. Bundle IDs must be non-empty `Q09CAL-...` identifiers; the expected digest must be exactly 64 hexadecimal characters.
3. The Common path must be relative. Absolute paths, drive prefixes, doubled separators, empty segments, `.`/`..`, and whitespace-altered segments are rejected.
4. `QM_NewsReadCommonFileBytes` opens exactly the supplied relative path with `FILE_COMMON`. It contains no terminal-local lookup and no basename fallback.
5. The bytes are SHA-256 hashed and matched against `qm_news_calendar_expected_sha256` before `QM_NewsLoadCsv(..., true)` is called.
6. The parser's `common_only=true` mode reopens only that same `FILE_COMMON` path. It cannot fall through to the legacy search sequence.
7. A second strict read/hash after parsing detects replacement during parsing. On mismatch it clears the parsed events and refuses init.
8. Zero parsed rows or calendar self-test failure refuses init. Success builds the index and emits one structured `NEWS_CALENDAR_BUNDLE_LOADED` event with `bundle_id`, `sha256`, `rows`, and `common_relative_path`.
9. `QM_Common.mqh` treats a requested tester bundle as active even in a Q09 `CONTROL_OFF` cell, so the control arm authenticates the same sealed bytes instead of bypassing initialization.

There is deliberately no legacy fallback once a bundle is requested.

### Live-path untouchability, branch by branch

| Location | Change | Why live behavior is unchanged |
|---|---|---|
| Global declarations | Three strings are added as inputs. | Declarations alone do not select a calendar source or make a news decision. |
| `QM_FrameworkInitCoreAfterRuntimeStateArmed` | Adds `tester_bundle_requested`. | Its first conjunct is `MQLInfoInteger(MQL_TESTER) != 0`; it is always false on live attach. Thus the pre-existing live `any_news_active` truth table is unchanged. |
| `QM_NewsInit` | Adds a bundle branch before the legacy loader. | The branch has the same explicit `MQL_TESTER` guard. Live initialization cannot enter it. |
| `QM_NewsLoadCsv` | Adds optional `common_only=false`. | Every legacy caller omits the argument. Its original terminal-local, Common, then Common-basename sequence remains in the `false` branch. |
| Strict byte loader and bundle initializer | New functions. | They are reachable only through the tester guard above. |
| `QM_NewsLiveTemporalAllows`, `QM_NewsLiveComplianceAllows`, `QM_NewsNextBlockStartLive` | No production logic change. | A static contract test extracts each body and proves none references any `qm_news_calendar_*` input. Native MT5 calendar decisions therefore remain the only live verdict source. |

This is a semantic preservation argument, not a behavior-identity certificate. The common include and binary hashes changed, so historical trade evidence is not inherited by assertion.

## Serial compile evidence

The requested `compile_ea.py --force` builds were run one at a time. The first 11422 attempt was rejected because it emitted a narrowing warning:

```text
C:\Windows\system32\config\systemprofile\AppData\Roaming\MetaQuotes\Terminal\AE0A37E2EC2BC870ED414E4143BA21BF\MQL5\Include\QM\QM_NewsFilter.mqh(421,19) : warning 43: possible loss of data due to type conversion from 'uint' to 'int'
Result: 0 errors, 1 warnings, 6859 ms elapsed, cpu='X64 Regular'
```

The count was changed to `uint` with an explicit final comparison. That output was not accepted. The five accepted `D:\QM\reports\compile\<EA>\result.json` objects were:

```json
{
  "ea_label": "QM5_11422_williams-18ma-outside-bar-entry-d1",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_11422_williams-18ma-outside-bar-entry-d1\\QM5_11422_williams-18ma-outside-bar-entry-d1.ex5",
  "ex5_size_bytes": 367794,
  "ex5_mtime_utc": "2026-08-02T22:27:53+00:00",
  "mq5_mtime_utc": "2026-07-03T19:21:52+00:00",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260802_222726\\QM5_11422_williams-18ma-outside-bar-entry-d1.compile.log",
  "symbol_scope_verdict": "SINGLE_SYMBOL_OK",
  "elapsed_seconds": 27.88,
  "timestamp_utc": "2026-08-02T22:27:53+00:00",
  "cached": false
}
{
  "ea_label": "QM5_13013_grimes-trendday-v2",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_13013_grimes-trendday-v2\\QM5_13013_grimes-trendday-v2.ex5",
  "ex5_size_bytes": 380382,
  "ex5_mtime_utc": "2026-08-02T22:28:40+00:00",
  "mq5_mtime_utc": "2026-07-04T21:28:48+00:00",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260802_222817\\QM5_13013_grimes-trendday-v2.compile.log",
  "symbol_scope_verdict": "SINGLE_SYMBOL_OK",
  "elapsed_seconds": 23.96,
  "timestamp_utc": "2026-08-02T22:28:40+00:00",
  "cached": false
}
{
  "ea_label": "QM5_13036_balke-go-long-regime",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_13036_balke-go-long-regime\\QM5_13036_balke-go-long-regime.ex5",
  "ex5_size_bytes": 365274,
  "ex5_mtime_utc": "2026-08-02T22:29:11+00:00",
  "mq5_mtime_utc": "2026-07-08T20:36:30+00:00",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260802_222842\\QM5_13036_balke-go-long-regime.compile.log",
  "symbol_scope_verdict": "SINGLE_SYMBOL_OK",
  "elapsed_seconds": 30.23,
  "timestamp_utc": "2026-08-02T22:29:11+00:00",
  "cached": false
}
{
  "ea_label": "QM5_20048_wti-preholiday",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_20048_wti-preholiday\\QM5_20048_wti-preholiday.ex5",
  "ex5_size_bytes": 364030,
  "ex5_mtime_utc": "2026-08-02T22:29:35+00:00",
  "mq5_mtime_utc": "2026-07-22T18:16:37+00:00",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260802_222912\\QM5_20048_wti-preholiday.compile.log",
  "symbol_scope_verdict": "SINGLE_SYMBOL_OK",
  "elapsed_seconds": 24.08,
  "timestamp_utc": "2026-08-02T22:29:35+00:00",
  "cached": false
}
{
  "ea_label": "QM5_10440_mql5-ohlc-mtf",
  "verdict": "COMPILED",
  "reason": "fresh build, 0 warnings",
  "ex5_path": "C:\\QM\\repo\\framework\\EAs\\QM5_10440_mql5-ohlc-mtf\\QM5_10440_mql5-ohlc-mtf.ex5",
  "ex5_size_bytes": 368704,
  "ex5_mtime_utc": "2026-08-02T22:30:29+00:00",
  "mq5_mtime_utc": "2026-07-15T21:10:49+00:00",
  "compile_one_exit_code": 0,
  "compile_one_errors": 0,
  "compile_one_warnings": 0,
  "compile_log_path": "C:\\QM\\repo\\framework\\build\\compile\\20260802_222941\\QM5_10440_mql5-ohlc-mtf.compile.log",
  "symbol_scope_verdict": "SINGLE_SYMBOL_OK",
  "elapsed_seconds": 53.61,
  "timestamp_utc": "2026-08-02T22:30:29+00:00",
  "cached": false
}
```

The compile logs end verbatim with:

```text
QM5_11422: Result: 0 errors, 0 warnings, 8407 ms elapsed, cpu='X64 Regular'
QM5_13013: Result: 0 errors, 0 warnings, 6920 ms elapsed, cpu='X64 Regular'
QM5_13036: Result: 0 errors, 0 warnings, 7841 ms elapsed, cpu='X64 Regular'
QM5_20048: Result: 0 errors, 0 warnings, 7711 ms elapsed, cpu='X64 Regular'
QM5_10440: Result: 0 errors, 0 warnings, 16063 ms elapsed, cpu='X64 Regular'
```

### EX5 hash transition

| EA | Pre-change bytes | Pre-change SHA-256 | Accepted bytes | Accepted SHA-256 |
|---|---:|---|---:|---|
| `QM5_11422` | 342502 | `159e616880681047f5c071850b42615aa046a7f1d301255d22ffeeba5726f064` | 367794 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` |
| `QM5_13013` | 309842 | `c0038770ceac17691e79f0f05eea9cd75b02a6229c380a07675bee02f41d917a` | 380382 | `bf2cc2ecaff8ae556c06986aac8b6fb5e55d828d5ef5f6c81d8a4fc48bd44c41` |
| `QM5_13036` | 322664 | `1cfe279753f0d73bc8a9d7ac92abf15643fbb4ba72853cec621d9b89575809ab` | 365274 | `2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be` |
| `QM5_20048` | 338934 | `5c689d241cb29e79fa4153c8738fd27774167c2b381a7cdadef7daa84c3a9d73` | 364030 | `8eec30092bbd4c593247a575e622ffb933d7a67ef1efeb58b7c1cca0b94dd784` |
| `QM5_10440` | 344240 | `efb71824bcfd921205a95f93d51e2a8d16290c9f61490f036b1f1173b3e7f021` | 368704 | `d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db` |

The latest 20048 Q02 PASS row is bound to the still earlier hash `848d3501af80547f2b6fe340b5c415f4322daf327696ca6f4d8bc55c693f8e83`, not the immediate pre-ticket repository hash. Its lineage was already vintage-stale before this change; the prescribed append-only Q02 restart still resolves it against the new current hash.

The brief required the factory to remain running. During verification, its artifact autocommit captured the five compiled EX5 paths in canonical commit `46bc38f73` together with other contemporaneous factory build artifacts. The source, tests, and this evidence document follow that commit; the hashes above were re-read from HEAD/worktree after the autocommit and still match the accepted compile results.

## Verification output

### Build guardrails

Command:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_11422_williams-18ma-outside-bar-entry-d1 framework/EAs/QM5_13013_grimes-trendday-v2 framework/EAs/QM5_13036_balke-go-long-regime framework/EAs/QM5_20048_wti-preholiday framework/EAs/QM5_10440_mql5-ohlc-mtf
```

Output:

```json
{
  "checked_at": "2026-08-02T22:46:44.667214Z",
  "results": [
    {"files_checked": 14, "findings": [], "max_news_stale_hours": 336, "path": "framework\\EAs\\QM5_11422_williams-18ma-outside-bar-entry-d1", "verdict": "PASS"},
    {"files_checked": 10, "findings": [], "max_news_stale_hours": 336, "path": "framework\\EAs\\QM5_13013_grimes-trendday-v2", "verdict": "PASS"},
    {"files_checked": 12, "findings": [], "max_news_stale_hours": 336, "path": "framework\\EAs\\QM5_13036_balke-go-long-regime", "verdict": "PASS"},
    {"files_checked": 10, "findings": [], "max_news_stale_hours": 336, "path": "framework\\EAs\\QM5_20048_wti-preholiday", "verdict": "PASS"},
    {"files_checked": 208, "findings": [], "max_news_stale_hours": 336, "path": "framework\\EAs\\QM5_10440_mql5-ohlc-mtf", "verdict": "PASS"}
  ],
  "verdict": "PASS"
}
```

The candidate baseline setfiles also contain `RISK_FIXED=1000` and `RISK_PERCENT=0`. No stale-news limit was raised; recovery from a stale seed remains refresh of `D:\QM\data\news_calendar` and its FILE_COMMON copy.

### Focused tests

Command:

```text
python -m pytest tools/strategy_farm/tests/test_news_filter_calendar_bundle_static.py tools/strategy_farm/tests/test_news_filter_csv_layout.py tools/strategy_farm/tests/test_q09_news_runner_v2.py -q
```

Verbatim output:

```text
................                                                         [100%]
16 passed in 17.27s
```

`python -m py_compile` for the changed runner/tests and scoped `git diff --check` both returned exit code 0. Git printed only its repository line-ending advisory; no whitespace error was reported.

A wider selected news/Q09/guardrail run passed every non-refresh test but encountered the production factory interlock in the five refresh-script tests:

```text
...................................................................FFFFF [ 65%]
......................................                                   [100%]
5 failed, 105 passed in 44.13s
```

Each failure was the test harness's explicit precondition:

```text
assert not REAL_FACTORY_LOCK.exists()
E AssertionError: assert not True
E  where exists = WindowsPath('D:/QM/strategy_farm/state/FACTORY_MUTATION.lock').exists
```

The factory was active as required by the brief. The lock was not removed, modified, or waited out, and those refresh tests do not exercise the changed MQL bundle loader or report-input validator. This interlock result is recorded rather than misrepresented as a green full-suite run.

No compile or unit-test result is promoted to a pipeline verdict.

## Requalification-scope adjudication

### Actual historical state

The brief's claim that these chains had “barely started” is not supported by the current farm rows. Four candidates have older chains reaching Q08; the rows are simply stale for the new EX5:

| Candidate | Relevant historical state before this build | Finding |
|---|---|---|
| `11422 / USDCAD.DWX / D1` | Q02 PASS `2b085f1e-...`; older Q04→Q08 PASS chain; Q09 `PENDING_RUNNER`; Q10 PASS exists | Full historical chain, not one early gate. New hash invalidates inheritance. |
| `13013 / NDX.DWX / M15` | Q02 PASS `129df6ea-...`; recent Q04 `PASS_LOWFREQ`; older Q05/Q06 and Q08 PASS; Q09 `PENDING_RUNNER` | Mixed/migrated lineage; still not “barely started.” |
| `13036 / GDAXI.DWX / M15` | Q02 PASS `8bac496f-...`; Q04→Q08 PASS; Q09 `PENDING_RUNNER` | Full historical chain; Q08 alone took about 7.1 hours. |
| `20048 / XTIUSD.DWX / D1` | Q02 PASS `bc486533-...`; Q04 `PASS_SOFT`; Q05→Q08 PASS; Q09 `PENDING_RUNNER` | Full historical chain and already stale relative to the immediate pre-ticket EX5. |
| `10440 / NDX.DWX / H1` | Many old/duplicate rows; latest Q08 rows include repeated `INFRA_FAIL`, `FAIL_SOFT`, and `FAIL_HARD`; no clean current bound chain | Not suitable for a mechanical restart command without upstream provenance repair and live-book adjudication. |

### Cost of Q02 restart

Observed phase wall-clock envelopes from the farm rows (which can include queue gaps and are therefore conservative) are:

| Candidate | Approximate current-binary Q02→Q08 terminal envelope |
|---|---:|
| `11422` | 1.9 h |
| `13013` | 2–3 h; migrated timestamps make a tighter bound dishonest |
| `13036` | 9.5–10 h, dominated by Q08 at 7.1 h |
| `20048` | 1.2 h |
| Four governed candidates | approximately 15–17 terminal-hours |
| `10440` if separately repaired | not presently governable; historical behavior suggests at least another 4–8 h plus high retry risk |

This path uses existing hash-bound append-only tooling and yields fresh evidence at every gate. Its cost is machine time rather than a new exception mechanism.

### Cost of Q08-only with behavior identity proof

An honest exception requires, for every candidate, the exact pre-change binary and recursive include closure, the new binary, bundle inputs unset on both, at least one complete Q02-class reference window on each binary, hash-bound MT5 reports, and a deal-by-deal comparator covering order/deal sequence, time, type, price, volume, costs, and terminal result. Compilation and source inspection are not substitutes.

For the four clean candidates, eight reference runs are roughly 1–2 terminal-hours from observed Q02 durations. Fresh Q08 runs add about 9 terminal-hours, so raw machine time is approximately 10–12 hours—about four to six hours less than the full restart. That estimate excludes old-binary/closure recovery, isolated staging, comparator implementation and validation, reviewer time, and the mandatory full-restart fallback if even one deal differs. A rigorous identity package is therefore not free merely because its tester time is lower.

The alternative is also fragile here:

- the change is in shared `QM_Common.mqh`/`QM_NewsFilter.mqh` initialization code, not in a detached post-processing adapter;
- it changes the EA input table and the conditions under which the news module initializes in tester control cells;
- there is no existing governed one-command old/new deal-identity artifact in this ticket;
- the MNT-043 vintage doctrine treats a new EX5 as stale evidence unless a separately authorized exception is proved;
- 10440 has neither a bound source row nor an unambiguous admission-only identity.

Therefore the small estimated machine-time saving does not justify creating and reviewing an exception path. The single recommendation is the Q02 restart for the four clean candidates and a separate upstream block for 10440.

## Exact post-review operator sequence

**Do not execute any command in this section until Claude accepts the code, hashes, and adjudication.** Run one enqueue at a time. Let the ordinary factory claim it; never start a terminal manually. Run the next command only after the exact predecessor has a pipeline-produced accepted verdict. Stop on any refusal, unexpected row count, non-accepted verdict, missing evidence, hash drift, or factory interlock.

### Shared PowerShell helpers

Start in the canonical checkout and define these helpers once:

```powershell
Set-Location C:\QM\repo

function New-QAppendOnlyRerun {
  param(
    [Parameter(Mandatory=$true)][string]$Ea,
    [Parameter(Mandatory=$true)][string]$Phase,
    [Parameter(Mandatory=$true)][string]$Predecessor,
    [Parameter(Mandatory=$true)][string]$OldPhaseRow,
    [Parameter(Mandatory=$true)][string]$Ex5Sha
  )
  $result = python tools/strategy_farm/farmctl.py enqueue-backtest `
    --ea $Ea --phase $Phase `
    --from-work-item-id $Predecessor `
    --append-only-rerun-of $OldPhaseRow `
    --rerun-reason 'BOOK_ADMISSION_REQUAL_2026-08-03_CALENDAR_BUNDLE_CURRENT_BINARY' `
    --expected-current-ex5-sha256 $Ex5Sha | ConvertFrom-Json
  if (-not $result.enqueued -or @($result.created).Count -ne 1) {
    throw "$Ea $Phase enqueue refused or ambiguous: $($result | ConvertTo-Json -Depth 8 -Compress)"
  }
  return [string]$result.created[0].id
}

function Assert-QGate {
  param(
    [Parameter(Mandatory=$true)][string]$Ea,
    [Parameter(Mandatory=$true)][string]$WorkItem,
    [Parameter(Mandatory=$true)][string[]]$Accepted
  )
  $row = (python tools/strategy_farm/farmctl.py work-items --ea $Ea | ConvertFrom-Json).items |
    Where-Object { $_.id -eq $WorkItem }
  if (@($row).Count -ne 1 -or $row.status -ne 'done' -or $row.verdict -notin $Accepted) {
    throw "$Ea predecessor $WorkItem has no accepted pipeline verdict"
  }
  if (-not (Test-Path -LiteralPath $row.evidence_path -PathType Leaf)) {
    throw "$Ea predecessor $WorkItem evidence missing"
  }
}
```

Q02 uses the stricter exact-source path directly. Q04–Q09 use `New-QAppendOnlyRerun` because historical rows already occupy those candidate/phase identities; this preserves rather than overwrites them.

### `QM5_11422 / USDCAD.DWX / D1`

```powershell
$sha11422 = '2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66'
$r = python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11422 --phase Q02 `
  --from-work-item-id 2b085f1e-40d6-4076-b9f4-ae60104e8b9f `
  --append-only-rerun-of 2b085f1e-40d6-4076-b9f4-ae60104e8b9f `
  --rerun-reason 'BOOK_ADMISSION_REQUAL_2026-08-03_CALENDAR_BUNDLE_CURRENT_BINARY' `
  --expected-current-ex5-sha256 $sha11422 | ConvertFrom-Json
if (-not $r.enqueued -or @($r.created).Count -ne 1) { throw ($r | ConvertTo-Json -Depth 8 -Compress) }
$q02_11422 = [string]$r.created[0].id

# After the factory finishes each exact row, run its assertion before the next enqueue.
Assert-QGate QM5_11422 $q02_11422 @('PASS')
$q04_11422 = New-QAppendOnlyRerun QM5_11422 Q04 $q02_11422 a15b83f2-6533-4da7-a855-b1a66f26c8f8 $sha11422
Assert-QGate QM5_11422 $q04_11422 @('PASS','PASS_SOFT','PASS_LOWFREQ')
$q05_11422 = New-QAppendOnlyRerun QM5_11422 Q05 $q04_11422 9cf0f72d-8273-4d2d-ba93-8269a1bc704f $sha11422
Assert-QGate QM5_11422 $q05_11422 @('PASS')
$q06_11422 = New-QAppendOnlyRerun QM5_11422 Q06 $q05_11422 05a2843a-d5fc-4fa8-b22a-e93f6dcf9979 $sha11422
Assert-QGate QM5_11422 $q06_11422 @('PASS')
$q07_11422 = New-QAppendOnlyRerun QM5_11422 Q07 $q06_11422 0efc4460-8bfe-4707-a15e-47ff0ef7f31f $sha11422
Assert-QGate QM5_11422 $q07_11422 @('PASS')
$q08_11422 = New-QAppendOnlyRerun QM5_11422 Q08 $q07_11422 6f2bc654-3a18-40d8-9959-e4984591c6d3 $sha11422
Assert-QGate QM5_11422 $q08_11422 @('PASS')
$q09_11422 = New-QAppendOnlyRerun QM5_11422 Q09_NEWS $q08_11422 87af2578-b9ba-4010-9776-07faa4e729d5 $sha11422
```

### `QM5_13013 / NDX.DWX / M15`

```powershell
$sha13013 = 'bf2cc2ecaff8ae556c06986aac8b6fb5e55d828d5ef5f6c81d8a4fc48bd44c41'
$r = python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_13013 --phase Q02 `
  --from-work-item-id 129df6ea-4f80-465b-8988-57b9d2f511f4 `
  --append-only-rerun-of 129df6ea-4f80-465b-8988-57b9d2f511f4 `
  --rerun-reason 'BOOK_ADMISSION_REQUAL_2026-08-03_CALENDAR_BUNDLE_CURRENT_BINARY' `
  --expected-current-ex5-sha256 $sha13013 | ConvertFrom-Json
if (-not $r.enqueued -or @($r.created).Count -ne 1) { throw ($r | ConvertTo-Json -Depth 8 -Compress) }
$q02_13013 = [string]$r.created[0].id

Assert-QGate QM5_13013 $q02_13013 @('PASS')
$q04_13013 = New-QAppendOnlyRerun QM5_13013 Q04 $q02_13013 3184e512-32e3-423e-9108-3a48501aa1d7 $sha13013
Assert-QGate QM5_13013 $q04_13013 @('PASS','PASS_SOFT','PASS_LOWFREQ')
$q05_13013 = New-QAppendOnlyRerun QM5_13013 Q05 $q04_13013 c53decc4-67ba-4769-9718-839f44a96fd4 $sha13013
Assert-QGate QM5_13013 $q05_13013 @('PASS')
$q06_13013 = New-QAppendOnlyRerun QM5_13013 Q06 $q05_13013 87998789-1c8f-48ef-90a0-841a9492dbe7 $sha13013
Assert-QGate QM5_13013 $q06_13013 @('PASS')
$q07_13013 = New-QAppendOnlyRerun QM5_13013 Q07 $q06_13013 50afe7d8-b012-40dc-89d0-dc9f0484bb72 $sha13013
Assert-QGate QM5_13013 $q07_13013 @('PASS')
$q08_13013 = New-QAppendOnlyRerun QM5_13013 Q08 $q07_13013 64bf0e5d-183d-47e1-8c8e-59d34eaeff91 $sha13013
Assert-QGate QM5_13013 $q08_13013 @('PASS')
$q09_13013 = New-QAppendOnlyRerun QM5_13013 Q09_NEWS $q08_13013 2571184b-22cc-431b-8c12-aad057a98931 $sha13013
```

The Q07 rerun target above is the terminal historical `INFRA_FAIL` row. It is used only as the immutable append-only target; the newly produced current-binary Q06 PASS is the actual predecessor, and Q08 is prohibited unless the new Q07 row produces `PASS`.

### `QM5_13036 / GDAXI.DWX / M15`

```powershell
$sha13036 = '2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be'
$r = python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_13036 --phase Q02 `
  --from-work-item-id 8bac496f-128f-4cea-a2bc-2465b00581ce `
  --append-only-rerun-of 8bac496f-128f-4cea-a2bc-2465b00581ce `
  --rerun-reason 'BOOK_ADMISSION_REQUAL_2026-08-03_CALENDAR_BUNDLE_CURRENT_BINARY' `
  --expected-current-ex5-sha256 $sha13036 | ConvertFrom-Json
if (-not $r.enqueued -or @($r.created).Count -ne 1) { throw ($r | ConvertTo-Json -Depth 8 -Compress) }
$q02_13036 = [string]$r.created[0].id

Assert-QGate QM5_13036 $q02_13036 @('PASS')
$q04_13036 = New-QAppendOnlyRerun QM5_13036 Q04 $q02_13036 8a363c83-6494-47ee-96c8-ee6d9466aaa0 $sha13036
Assert-QGate QM5_13036 $q04_13036 @('PASS','PASS_SOFT','PASS_LOWFREQ')
$q05_13036 = New-QAppendOnlyRerun QM5_13036 Q05 $q04_13036 4035283e-be7a-498d-924c-5d614c18768b $sha13036
Assert-QGate QM5_13036 $q05_13036 @('PASS')
$q06_13036 = New-QAppendOnlyRerun QM5_13036 Q06 $q05_13036 6ea9a6bb-6a5b-4d44-8341-a086f990180d $sha13036
Assert-QGate QM5_13036 $q06_13036 @('PASS')
$q07_13036 = New-QAppendOnlyRerun QM5_13036 Q07 $q06_13036 37bdfd72-0601-4540-bff3-63c8c5088b87 $sha13036
Assert-QGate QM5_13036 $q07_13036 @('PASS')
$q08_13036 = New-QAppendOnlyRerun QM5_13036 Q08 $q07_13036 85aadb10-6860-43df-bfb4-8c164246efc2 $sha13036
Assert-QGate QM5_13036 $q08_13036 @('PASS')
$q09_13036 = New-QAppendOnlyRerun QM5_13036 Q09_NEWS $q08_13036 7efd8e39-4d1c-4b6d-8cfd-637122aad25f $sha13036
```

### `QM5_20048 / XTIUSD.DWX / D1`

```powershell
$sha20048 = '8eec30092bbd4c593247a575e622ffb933d7a67ef1efeb58b7c1cca0b94dd784'
$r = python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_20048 --phase Q02 `
  --from-work-item-id bc486533-4803-4e9d-9c35-98a75ff53f76 `
  --append-only-rerun-of bc486533-4803-4e9d-9c35-98a75ff53f76 `
  --rerun-reason 'BOOK_ADMISSION_REQUAL_2026-08-03_CALENDAR_BUNDLE_CURRENT_BINARY' `
  --expected-current-ex5-sha256 $sha20048 | ConvertFrom-Json
if (-not $r.enqueued -or @($r.created).Count -ne 1) { throw ($r | ConvertTo-Json -Depth 8 -Compress) }
$q02_20048 = [string]$r.created[0].id

Assert-QGate QM5_20048 $q02_20048 @('PASS')
$q04_20048 = New-QAppendOnlyRerun QM5_20048 Q04 $q02_20048 178597bc-8469-4982-9999-223998119d0b $sha20048
Assert-QGate QM5_20048 $q04_20048 @('PASS','PASS_SOFT','PASS_LOWFREQ')
$q05_20048 = New-QAppendOnlyRerun QM5_20048 Q05 $q04_20048 611345a8-6def-4d88-99f1-099a5c8197a8 $sha20048
Assert-QGate QM5_20048 $q05_20048 @('PASS')
$q06_20048 = New-QAppendOnlyRerun QM5_20048 Q06 $q05_20048 b1ca5246-ed70-463a-8822-426d76d52966 $sha20048
Assert-QGate QM5_20048 $q06_20048 @('PASS')
$q07_20048 = New-QAppendOnlyRerun QM5_20048 Q07 $q06_20048 0c1613f6-9d23-4463-9295-af58c17e252d $sha20048
Assert-QGate QM5_20048 $q07_20048 @('PASS')
$q08_20048 = New-QAppendOnlyRerun QM5_20048 Q08 $q07_20048 cee49d90-32ae-462d-a830-fd753595715b $sha20048
Assert-QGate QM5_20048 $q08_20048 @('PASS')
$q09_20048 = New-QAppendOnlyRerun QM5_20048 Q09_NEWS $q08_20048 eca6862c-4f3e-462f-89f4-c8895d3dbfa7 $sha20048
```

### Bind each new Q09 plan

Creating a Q09 row is not enough: it must be planned against its exact fresh Q08 evidence, reviewed recursive include closure, current EX5, and OWNER-approved calendar manifest. The two bracketed paths are future reviewed artifacts and must not be guessed.

Define this helper after each candidate's fresh Q09 row exists:

```powershell
function New-Q09NewsPlan {
  param(
    [Parameter(Mandatory=$true)][string]$Ea,
    [Parameter(Mandatory=$true)][string]$EaLabel,
    [Parameter(Mandatory=$true)][string]$Symbol,
    [Parameter(Mandatory=$true)][string]$Period,
    [Parameter(Mandatory=$true)][string]$Q08,
    [Parameter(Mandatory=$true)][string]$Q09,
    [Parameter(Mandatory=$true)][string]$ExpectedEx5Sha,
    [Parameter(Mandatory=$true)][string]$IncludeClosure,
    [Parameter(Mandatory=$true)][string]$CalendarManifest
  )
  $symbolDir = $Symbol.Replace('.', '_')
  $q08Evidence = "D:\QM\reports\work_items\$Q08\$Ea\Q08\$symbolDir\aggregate.json"
  $eaRoot = "C:\QM\repo\framework\EAs\$EaLabel"
  $baseline = "$eaRoot\sets\${EaLabel}_${Symbol}_${Period}_backtest.set"
  $ex5 = "$eaRoot\$EaLabel.ex5"
  foreach ($path in @($q08Evidence,$baseline,$ex5,$IncludeClosure,$CalendarManifest)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "required reviewed input missing: $path" }
  }
  $currentEx5Sha = (Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($currentEx5Sha -ne $ExpectedEx5Sha) { throw "$Ea current EX5 hash drift" }
  $bundleId = [string](Get-Content -LiteralPath $CalendarManifest -Raw | ConvertFrom-Json).bundle_id
  if ($bundleId -notmatch '^q09cal-') { throw 'calendar is not a Q09 v2 content-addressed bundle' }
  $q08Sha = (Get-FileHash -LiteralPath $q08Evidence -Algorithm SHA256).Hash.ToLowerInvariant()
  $lineageText = "$Ea|$Symbol|$Period|$Q08|$q08Sha"
  $lineageKey = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lineageText))
  ).ToLowerInvariant()
  $planRoot = "D:\QM\reports\work_items\$Q09\q09_plan"

  python tools/strategy_farm/q09_news_runner.py plan `
    --work-item-id $Q09 `
    --candidate-lineage-key $lineageKey `
    --deployment-target DXZ `
    --q08-work-item-id $Q08 `
    --q08-evidence $q08Evidence `
    --baseline-setfile $baseline `
    --ex5 $ex5 `
    --include-closure $IncludeClosure `
    --calendar-manifest $CalendarManifest `
    --calendar-common-relative-path "QM/q09_news/$bundleId/events.csv" `
    --full-from-utc 2019-01-01T00:00:00Z `
    --full-to-utc 2025-12-31T23:59:59Z `
    --selection-from-utc 2019-01-01T00:00:00Z `
    --selection-to-utc 2023-12-31T23:59:59Z `
    --holdout-from-utc 2024-01-01T00:00:00Z `
    --holdout-to-utc 2025-12-31T23:59:59Z `
    --complete-months 60 `
    --holdout-complete-months 24 `
    --tester-model REAL_TICKS `
    --cost-profile DXZ_CANONICAL_REAL_TICKS_V1 `
    --output-root $planRoot
  if ($LASTEXITCODE -ne 0) { throw "$Ea Q09 plan refused" }

  $plan = "$planRoot\run_plan.json"
  $planSha = (Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant()
  python tools/strategy_farm/farmctl.py bind-q09-plan `
    --work-item-id $Q09 `
    --plan $plan `
    --plan-file-sha256 $planSha `
    --cell-timeout-sec 3600
  if ($LASTEXITCODE -ne 0) { throw "$Ea Q09 binding refused" }
}

$includeClosure11422 = '<REVIEWED_11422_CURRENT_EX5_RECURSIVE_INCLUDE_CLOSURE_JSON>'
$includeClosure13013 = '<REVIEWED_13013_CURRENT_EX5_RECURSIVE_INCLUDE_CLOSURE_JSON>'
$includeClosure13036 = '<REVIEWED_13036_CURRENT_EX5_RECURSIVE_INCLUDE_CLOSURE_JSON>'
$includeClosure20048 = '<REVIEWED_20048_CURRENT_EX5_RECURSIVE_INCLUDE_CLOSURE_JSON>'
$calendarManifest = '<OWNER-APPROVED_Q09_NEWS_CALENDAR_BUNDLE_V2_DIR>\manifest.json'

New-Q09NewsPlan QM5_11422 QM5_11422_williams-18ma-outside-bar-entry-d1 USDCAD.DWX D1 $q08_11422 $q09_11422 $sha11422 $includeClosure11422 $calendarManifest
New-Q09NewsPlan QM5_13013 QM5_13013_grimes-trendday-v2 NDX.DWX M15 $q08_13013 $q09_13013 $sha13013 $includeClosure13013 $calendarManifest
New-Q09NewsPlan QM5_13036 QM5_13036_balke-go-long-regime GDAXI.DWX M15 $q08_13036 $q09_13036 $sha13036 $includeClosure13036 $calendarManifest
New-Q09NewsPlan QM5_20048 QM5_20048_wti-preholiday XTIUSD.DWX D1 $q08_20048 $q09_20048 $sha20048 $includeClosure20048 $calendarManifest
```

There is deliberately no manual `execute`, terminal launch, or Q10 command. The ordinary factory supplies a reserved tester slot. Q10 remains dependent on pipeline-produced Q09 evidence and the existing paired dependency gate.

### `QM5_10440 / NDX.DWX / H1` — no command

Do not adapt the four-candidate commands to 10440. The candidate rows `3969e217-d815-48ae-ac9e-534203ff9226` (ablation set) and `5cb043ef-53c3-49b7-ba55-c748b32b9331` (base set) have no `expected_ex5_sha256`, `expected_mq5_sha256`, `expected_setfile_sha256`, `expected_symbol`, `expected_period`, or `expected_expert`. The governed Q02 stale-PASS rerun path therefore correctly refuses them. In addition, `docs/ops/CODEX_BRIEF_2026-08-02_10440_q10_path.md` identifies this exact sleeve as live. The next action is an OWNER/Claude provenance and scope adjudication, not an invented enqueue.

## Safety and scope record

- The implementation does not enable T_Live or AutoTrading.
- No T_Live path was contacted and no live EX5 was read, copied, replaced, or compared.
- No terminal was manually started; active T1–T10 work was not interrupted.
- No backtest or pipeline row was enqueued or mutated by this ticket.
- The factory's active mutation lock was preserved.
- No pipeline verdict is inferred from compilation, static checks, unit tests, or this recommendation.
- All operator-facing phase names in this document are Q-only.
- The stale-news ceiling remains 336 hours; setfiles use fixed positive risk and zero percent risk.
- The Edge Lab charter remains binding: FTMO + DXZ target, daily DD no more than 5%, total DD no more than 10%, mandatory news blackout, swing/scalping only, mechanical, no HFT, martingale/grid, or ML in the EA.
