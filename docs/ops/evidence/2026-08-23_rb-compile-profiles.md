# rb-compile-profiles — roaming MetaEditor stdlib repair

Date: 2026-08-23

Ticket: `rb-compile-profiles`

Status: implemented, runtime profiles repaired, standalone compile verified
Authority: OWNER standing GRUEN infrastructure-repair authorization stated in the ticket

## Scope and safety boundary

- Changed only the COMPILE_EA compile/provisioning path, its unit tests, a read-only dry-run classifier, and the four explicitly named Administrator roaming Include profiles.
- Runtime profile blast radius: T6, T7, T9, and DEV1 under `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\<hash>\MQL5\Include`.
- The standalone verification also exercised the existing mirror into `D:\QM\mt5\T6\MQL5\Include`; its stdlib parity check copied zero files and its 58 governed framework headers were atomically synchronized by the existing toolchain behavior.
- Did not touch `C:\QM\mt5\T_Live`, AutoTrading, factory state, queue contents, backtest rows, gate thresholds/criteria, or verdict rows.
- Every SQLite access in this ticket used `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` with `uri=True`. The new classifier additionally executes `PRAGMA query_only=ON` (`tools/strategy_farm/reclassify_compile_profile_failures.py:59-62`).
- No Include file was deleted. Pre-repair trees remain recoverable in the backup below.

## Reproduction: compile path and profile resolution

The production path is:

1. `terminal_worker._run_claimed_item` routes `COMPILE_EA` to `compile_work_items.run_compile_work_item`.
2. `run_compile_work_item` invokes `framework/scripts/build_check.ps1` with the claimed terminal.
3. `build_check.ps1` invokes `framework/scripts/compile_one.ps1`.
4. For a claimed work item, `compile_one.ps1` resolves `D:\QM\mt5\<terminal>\MetaEditor64.exe`, takes its parent as the install root, and discovers roaming data folders whose `origin.txt` equals that install root (`framework/scripts/compile_one.ps1:76-172,351-387`).
5. The claimed-terminal ownership filter retains the install Include root and the matching roaming profile Include root (`framework/scripts/compile_one.ps1:195-219,421-434`).
6. Before this ticket, `include_mirror.py` copied only `framework/include` (QM project headers). It did not provision the MT5 standard library, so a profile could contain `QM/QM_Common.mqh` while lacking its `<Trade/Trade.mqh>` dependency.

Observed compile evidence:

- T6: `C:\QM\repo\framework\build\compile\20260822_134657\QM5_9965_bandy-index-gap-and-go-continuation.compile.log` — `QM_Common.mqh(4,10) : error 106: file 'Include\Trade\Trade.mqh' not found`.
- T9: `C:\QM\repo\framework\build\compile\20260822_141549\QM5_9983_bandy-wide-range-bar-fade-mr-index.compile.log` — the same missing-Trade error 106.
- T7: `C:\QM\repo\framework\build\compile\20260822_150727\QM5_41102_wti-mrange-migrate-mom.compile.log` — `Trade.mqh(6,10) : error 106: file 'Include\Object.mqh' not found`, followed by 57 cascade errors and nine warnings.

The T7 work-item evidence binds the resolved targets directly:

`D:\QM\reports\work_items\ec323614-4d44-4d8e-b8c0-1553fb7801f7\QM5_41102\COMPILE_EA\compile_evidence.json`

It records `include_sync_targets=D:\QM\mt5\T7\MQL5\Include;C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\AC9F...\MQL5\Include`.

## Terminal → roaming profile mapping

Mapping evidence was read from each profile's `origin.txt`; required-file state was measured before repair and is preserved in the timestamped backup.

| Terminal | MetaEditor build | Roaming hash | Pre-repair `Object.mqh` | Pre-repair `Trade/Trade.mqh` |
|---|---:|---|---:|---:|
| T1 (intact comparator) | 6140 | `AE0A37E2EC2BC870ED414E4143BA21BF` | yes | yes |
| T6 | 6140 | `E082C3FA2B8AF7675CA9E80BEEFDB6FC` | no | no |
| T7 | 6140 | `AC9F706B929ADCFBE60C8EDA2C379CFC` | no | yes |
| T9 | 6140 | `62611A7492286AC58551265C585B8217` | no | no |
| DEV1 | 5833 | `28E47E87AA76CCE760DDF8997279C02D` | no | no |

Build evidence came from `(Get-Item D:/QM/mt5/<terminal>/MetaEditor64.exe).VersionInfo`: T1/T6/T7/T9 are `5.0.0.6140`; DEV1 is `5.0.0.5833`. Therefore T6/T7/T9 were repaired from their own build-6140 install Include trees, while DEV1 was repaired from its own build-5833 install Include tree. No cross-build copy was used.

## Include-tree diff and exact missing sets

The MT5 stdlib set `S` is the 263 install-owned relative files under each terminal's `MQL5/Include`, excluding QuantMechanica-owned `QM/**`, `news_rules/**`, and `QM_Branding.mqh`. All four install trees and the intact T1 roaming tree have the same 263-path stdlib shape. The comparison was both against intact T1 and against each terminal's own same-build install root.

`S` consists of every file in these standard-library families:

- `Arrays/**`, `Canvas/**`, `ChartObjects/**`, `Charts/**`, `Controls/**`, `Expert/**`, `Files/**`, `Generic/**`, `Graphics/**`, `Indicators/**`, `Math/**`, `OpenCL/**`, `Strings/**`, `Tools/**`, `Trade/**`, and `WinAPI/**`.
- Top-level files `MovingAverages.mqh`, `Object.mqh`, `SmoothAlgorithms.mqh`, `StdLibErr.mqh`, and `VirtualKeys.mqh`.

The missing-file lists are exact set definitions over `S`:

| Profile | Files before | Missing vs own install/T1 | Exact missing stdlib list | Other drift |
|---|---:|---:|---|---|
| T6 | 60 | 262 | every path in `S` except `SmoothAlgorithms.mqh` | none |
| T7 | 130 | 192 | all files under `Canvas/**`, `ChartObjects/**`, `Charts/**`, `Controls/**`, `Files/**`, `Generic/**`, `Graphics/**`, `Math/**`, `OpenCL/**`, `Strings/**`, `Tools/**`, `WinAPI/**`; plus `MovingAverages.mqh`, `Object.mqh`, `StdLibErr.mqh`, `VirtualKeys.mqh` | `Expert/Expert.mqh` existed but differed from its same-build install source |
| T9 | 60 | 262 | every path in `S` except `SmoothAlgorithms.mqh` | none |
| DEV1 | 59 | 263 | every path in `S` | none |

For clarity, T7's present stdlib families were `Arrays/**`, `Expert/**`, `Indicators/**`, `Trade/**`, and `SmoothAlgorithms.mqh`; all other `S` paths are listed above as missing. The backup directories are the durable pre-repair source for reproducing every relative-path comparison.

## Repair and backup evidence

Backup created before the first write:

`D:\QM\strategy_farm\backups\compile_profiles_20260823_103658Z`

| Backup child | Files preserved |
|---|---:|
| `T6_E082C3FA2B8AF7675CA9E80BEEFDB6FC\Include` | 60 |
| `T7_AC9F706B929ADCFBE60C8EDA2C379CFC\Include` | 130 |
| `T9_62611A7492286AC58551265C585B8217\Include` | 60 |
| `DEV1_28E47E87AA76CCE760DDF8997279C02D\Include` | 59 |

Repair used the new atomic `repair_stdlib_targets` path under the global Include mutex. First pass:

| Profile | Missing files copied | Byte-drifted files corrected | Source |
|---|---:|---:|---|
| T6 | 262 | 0 | `D:\QM\mt5\T6\MQL5\Include` |
| T7 | 192 | 1 (`Expert/Expert.mqh`) | `D:\QM\mt5\T7\MQL5\Include` |
| T9 | 262 | 0 | `D:\QM\mt5\T9\MQL5\Include` |
| DEV1 | 263 | 0 | `D:\QM\mt5\DEV1\MQL5\Include` |

A second repair/verification pass reported for every profile: `stdlib_file_count=263 missing=0 mismatch=0 copied=0`, with both `Object.mqh=True` and `Trade/Trade.mqh=True`.

## Code changes

- `tools/strategy_farm/include_mirror.py:274-394` adds the required stdlib contract, complete same-install stdlib discovery, byte comparison, atomic repair, and post-repair verification. Project namespaces are excluded so install-tree QM headers cannot replace repository-governed headers.
- `tools/strategy_farm/include_mirror.py:448-490` makes stdlib repair part of the existing mutex-protected provisioning operation; the CLI requires `--stdlib-source` at line 505.
- `framework/scripts/compile_one.ps1:175-190,493-499` verifies `Object.mqh` and `Trade/Trade.mqh` in every resolved claimed Include root after provisioning and before the MetaEditor launch at line 515. Missing stdlib is emitted as `COMPILE_PROFILE_STDLIB_MISSING`; repair provenance is emitted at lines 589-611.
- `tools/strategy_farm/compile_work_items.py:42,926-970` maps that exact failure class to farm taxonomy `status='failed', verdict='INFRA_FAIL', verdict_reason='COMPILE_PROFILE_STDLIB_MISSING', verdict_taxonomy='infra'`. It does not write `COMPILE_FAIL` for this condition and does not create a gate verdict.
- `tools/strategy_farm/compile_work_items.py:1143-1151` binds source, missing-file, and repair receipts into compile evidence.
- `tools/strategy_farm/reclassify_compile_profile_failures.py:16-138` reads failure evidence/logs, matches error 106 for missing `Object.mqh` or `Trade/Trade.mqh`, deduplicates by `(ea_id,mq5_sha256)`, excludes a later open/successful successor, and outputs append-only rerun eligibility. It supports no apply mode and reports `mutation_count=0`.
- Tests: `test_include_mirror.py:87-166`, `test_compile_work_items.py:602-644`, and `test_reclassify_compile_profile_failures.py:36-129`.

## Standalone compile verification

Previously failed row selected read-only:

- work item `8987f9d0-6ca0-4efa-9add-206437432944`
- EA `QM5_9965_bandy-index-gap-and-go-continuation`
- historical terminal T6
- before: `status=failed`, `verdict=COMPILE_FAIL`, `updated_at=2026-08-22T13:47:21+00:00`

The direct invocation used `framework/scripts/compile_one.ps1 -Strict -CompileWorkItemId <historical-id> -ClaimedTerminal T6` with matching process environment. It invoked no worker completion code and performed no database write.

Result:

```text
compile_one.result=PASS
compile_one.reason_class=OK
compile_one.errors=0
compile_one.warnings=0
compile_one.metaeditor_exit_code=1
compile_one.compile_profile_stdlib_missing=
standalone_exit=0
```

Evidence:

- Compile log: `C:\QM\worktrees\rb-compile-profiles\framework\build\compile\20260823_103845\QM5_9965_bandy-index-gap-and-go-continuation.compile.log`
- Summary: `D:\QM\reports\compile\20260823_103845\summary.csv`
- Archived generated EX5: `D:\QM\reports\compile\20260823_103845\QM5_9965_bandy-index-gap-and-go-continuation.ex5`
- EX5 SHA-256: `a0bdab1dce56ab7c534346d84d4f6b4174766dcd0b92d2db7f2da1b398997804`; size 393,110 bytes.
- After the compile, the same read-only DB query returned the identical historical state and timestamp: `failed / COMPILE_FAIL / 2026-08-22T13:47:21+00:00`.

MetaEditor exit code 1 is an accepted successful CLI compile convention in this existing toolchain; the authoritative compile log and script receipt both report zero errors and zero warnings.

## Dry-run reclassification output

Command:

`python tools/strategy_farm/reclassify_compile_profile_failures.py --dry-run`

Observed against the runtime DB after repair:

```text
database_mode=ro
matched_signature_count=32
deduplicated_signature_count=32
eligible_count=32
mutation_count=0
apply_supported=false
```

Each listed row carries `reason=COMPILE_PROFILE_STDLIB_MISSING` and `eligible_action=APPEND_ONLY_COMPILE_EA_RERUN`. No rerun was enqueued and no existing row was reclassified or overwritten.

## Test evidence

Test-first red run:

```text
python -m pytest -q tools/strategy_farm/tests/test_include_mirror.py \
  tools/strategy_farm/tests/test_compile_work_items.py \
  tools/strategy_farm/tests/test_reclassify_compile_profile_failures.py
ERROR collecting ... ImportError: cannot import name 'reclassify_compile_profile_failures'
```

Focused final run:

```text
23 passed in 3.78s
```

Touched compile-path run:

```text
python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py \
  tools/strategy_farm/tests/test_raw_mq5_quarantine.py \
  tools/strategy_farm/tests/test_include_mirror.py \
  tools/strategy_farm/tests/test_compile_work_items.py \
  tools/strategy_farm/tests/test_reclassify_compile_profile_failures.py
57 passed in 124.37s

pwsh -NoProfile -File framework/scripts/tests/Test-CompileOneIncludeTargets.ps1
PASS Test-CompileOneIncludeTargets
```

Full requested strategy-farm suite:

```text
python -m pytest -q tools/strategy_farm/tests
225 failed, 4135 passed, 3 skipped, 2 warnings, 42 subtests passed in 1224.23s
```

None of the 225 failures names this ticket's modified/new test files. Failure clusters are pre-existing repository/environment contract surfaces, primarily `agent_router` canonical-generation fixtures, FTMO book/lane artifact contracts, pipeline-books/dashboard/dossier snapshots, registry rekey/static identity, target rulepacks, and task-watch notifier. The 57-test touched-path run and all 23 direct ticket tests are green.

Additional checks passed:

- `python -m py_compile` for all three touched/new Python modules.
- PowerShell parser returned zero errors for `compile_one.ps1`.
- `git diff --check` returned no errors (line-ending conversion warnings only).

## Rollback

Prerequisite: wait until T6/T7/T9/DEV1 have no `terminal64.exe` or `MetaEditor64.exe` process. Do not stop a process merely to perform rollback. The following is recoverable and deletes nothing: it renames each repaired Include tree, then restores the backup tree at the original path.

```powershell
$pairs = @(
  @('C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\E082C3FA2B8AF7675CA9E80BEEFDB6FC\MQL5', 'T6_E082C3FA2B8AF7675CA9E80BEEFDB6FC'),
  @('C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\AC9F706B929ADCFBE60C8EDA2C379CFC\MQL5', 'T7_AC9F706B929ADCFBE60C8EDA2C379CFC'),
  @('C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\62611A7492286AC58551265C585B8217\MQL5', 'T9_62611A7492286AC58551265C585B8217'),
  @('C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\28E47E87AA76CCE760DDF8997279C02D\MQL5', 'DEV1_28E47E87AA76CCE760DDF8997279C02D')
)
$backup = 'D:\QM\strategy_farm\backups\compile_profiles_20260823_103658Z'
foreach ($pair in $pairs) {
  $mql5 = $pair[0]
  Rename-Item -LiteralPath (Join-Path $mql5 'Include') -NewName 'Include.rb_compile_profiles_repaired_20260823_103658Z'
  Copy-Item -LiteralPath (Join-Path $backup "$($pair[1])\Include") -Destination $mql5 -Recurse
}
```

Code rollback after deployment is the normal revert of this ticket commit. Reverting code does not automatically roll back roaming profiles; use the preserved backup procedure above if profile rollback is also required.

## Residual risks and open questions

- The fail-closed classification is active only after this commit is deployed to the worker checkout/restarted through the existing governed rollout. Until then, repaired runtime profiles remove the immediate error, but old worker code would still classify any new recurrence as `COMPILE_FAIL`.
- The dry-run found 32 directly signature-proven rows. It intentionally does not infer additional rows from terminal correlation or cascade-error shape, and it does not enqueue them.
- Administrator profiles outside T6/T7/T9/DEV1 and system-profile roaming trees were not changed. They are outside the named blast radius; the production evidence for these failures resolves to the Administrator hashes listed above.
- No question blocks this repair. A separate governed action is required if the OWNER wants the 32 eligible append-only reruns applied.
