# QM5_1119 stale-emitter rebuild: compile proof, rerun blocker, and bounded cohort recommendations

Date: 2026-08-17  
Router task: `dc283f34-c619-43c7-a242-e97d28230d8f`  
Branch: `agents/board-advisor`  
Scope: non-live Q04 infrastructure recovery only

## Result

QM5_1119 was rebuilt serially from its unchanged source against the current framework. The EA-scoped build check and compile passed with 0 errors and 0 warnings. The new local binary is 374,360 bytes with SHA-256 `e8026a851fd9ec4da2179599643f6749305e84a31d8212c9a0c79a438e882444`.

The requested XAGUSD Q04 proof was **not started**. It would currently fail before producing the evidence under test: QM5_1119 has only six active magic rows, slots 0-5, and XAGUSD.DWX has no row. Its XAGUSD setfile still binds slot 0, which is registered to EURUSD.DWX. The current framework fails closed on that symbol/slot mismatch.

The registry and generated resolver were also already dirty from a separate active allocation transaction (three appended rows for QM5_21502, QM5_21505, and QM5_41049). Changing or regenerating them here would have crossed transactions and violated the serial magic-resolver rule. No terminal was started manually, no active backtest was interrupted, and no pipeline verdict is inferred.

## Independent emitter lineage

The initial statement that the 2026-06-21 binary predates *all* trade-stream emission is too broad.

- Q04 simulated-commission self-reporting and the `Common\\Files\\QM\\q04_sim` JSON writer landed on 2026-05-29 (`541bfdd8e5` / `3818d372bb`), before the old binary was built.
- The complete history-based trade-stream reconstruction, including SL/TP closes whose exit deal carries magic 0, landed on 2026-07-10 in commit `234860d6e6b939ddcf68de1243a99376b50f1339` (`QM_FrameworkQ08EmitFromHistory`, called from `QM_FrameworkShutdown`). The 2026-06-21 binary necessarily predates this fix.
- That distinction fits the observed failure: QM5_1119 traded normally, but the old event-path could not reliably attribute SL/TP exits, leaving both the complete stream and downstream self-report counters absent. A rebuild is still the correct repair; the supported claim is “predates the complete magic-0-safe emitter,” not “never contained any emitter.”

Relevant current-framework locations:

- `framework/include/QM/QM_Common.mqh`: Q04 simulated commission inputs and shutdown JSON writer.
- `framework/include/QM/QM_Common.mqh`: `QM_FrameworkQ08EmitFromHistory()` and the tester-only shutdown call.

## Build evidence

- Command: `framework/scripts/build_check.ps1 -EALabel QM5_1119_fps-toms-ma-rsi-h1`
- Build check: `PASS`, 0 failures, 0 warnings.
- Compile: `PASS`, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260817_174221\QM5_1119_fps-toms-ma-rsi-h1.compile.log`
- Build-check report: `D:\QM\reports\framework\21\build_check_20260817_174221.json`
- Source was unchanged; strategy mechanics, risks, news controls, and phase thresholds were not modified.

The binary is intentionally not committed yet: it embeds the currently dirty resolver snapshot and is not reproducible from the branch tip until the independent registry transaction closes. After that transaction, the repair must allocate the governed XAGUSD slot, update the exact XAGUSD setfile slot, regenerate and verify the resolver, repeat the scoped build, then append a fresh XAGUSD Q04 work item. Rebinding an old row or old hash is not acceptable.

## Remaining census recommendations

The original size-keyed census is a risk screen, not proof. Current Q04 history was checked for each of the other 22 EAs. “Economic evidence” below means at least one existing Q04 `FAIL`, `PASS`, or `PASS_SOFT`, proving that the EA has already produced a consumable Q04 verdict at least once. Those binaries must not be bulk-rebuilt solely because they are small or old.

| EA | Census build | Census pending | Current Q04 evidence | Recommendation |
|---|---:|---:|---|---|
| QM5_1099 | 2026-06-21 | 8 | none | First pending row is a diagnostic canary; inspect stream/self-report before any rebuild. |
| QM5_1130 | 2026-06-21 | 2 | 2 INFRA_FAIL, no economic verdict | Highest follow-up priority: inspect retained journals/files for the exact missing-stream signature; rebuild only if reproduced. |
| QM5_1127 | 2026-06-21 | 2 | 2 economic FAIL | Do not rebuild from census; existing economic evidence disproves guaranteed breakage. |
| QM5_1111 | 2026-06-21 | 2 | 3 economic FAIL | Do not rebuild from census; inspect only a new pair-specific infrastructure failure. |
| QM5_1105 | 2026-06-21 | 2 | none | First pending row is a diagnostic canary; inspect before rebuild. |
| QM5_1103 | 2026-06-21 | 2 | 2 economic FAIL | Do not rebuild from census. |
| QM5_1102 | 2026-06-21 | 2 | 1 economic FAIL | Do not rebuild from census. |
| QM5_1089 | 2026-06-21 | 2 | 15 economic FAIL | Do not rebuild from census; strong evidence the binary can produce Q04 verdicts. |
| QM5_1086 | 2026-06-21 | 2 | 64 economic FAIL | Do not rebuild; no current pending Q04 row and extensive economic evidence. |
| QM5_1128 | 2026-06-21 | 1 | none | Diagnostic canary only; inspect before rebuild. |
| QM5_1126 | 2026-06-21 | 1 | none | Diagnostic canary only; inspect before rebuild. |
| QM5_1104 | 2026-06-21 | 1 | 1 economic FAIL | Do not rebuild from census. |
| QM5_11023 | 2026-06-21 | 1 | 2 economic FAIL | Do not rebuild; no current pending Q04 row. |
| QM5_1095 | 2026-06-21 | 1 | 5 economic FAIL | Do not rebuild from census. |
| QM5_10888 | 2026-06-21 | 1 | 3 economic FAIL | Do not rebuild from census. |
| QM5_10859 | 2026-06-21 | 1 | none | Diagnostic canary only; inspect before rebuild. |
| QM5_10857 | 2026-06-21 | 1 | 4 FAIL + 1 PASS_SOFT | Do not rebuild from census. |
| QM5_10829 | 2026-06-16 | 1 | none | Diagnostic canary only; inspect before rebuild. |
| QM5_10590 | 2026-07-12 | 1 | 8 FAIL + 1 PASS + 2 PASS_SOFT | Explicit control: built after the 2026-07-10 fix and economically proven; no rebuild. |
| QM5_10579 | 2026-06-21 | 1 | 6 economic FAIL | Do not rebuild from census. |
| QM5_10578 | 2026-06-21 | 1 | none | Diagnostic canary only; inspect before rebuild. |
| QM5_1047 | 2026-06-11 | 1 | 5 economic FAIL | Do not rebuild from census. |

## Required close-out sequence

1. Let the existing registry/resolver transaction close cleanly.
2. Allocate an active QM5_1119 XAGUSD.DWX slot and seal that slot in the XAGUSD backtest setfile; do not reuse EURUSD slot 0.
3. Regenerate the resolver under the serial allocator lock and verify no row was dropped.
4. Repeat the EA-scoped strict build so the committed binary is reproducible from the committed resolver.
5. Append one fresh XAGUSD Q04 work item against the new binary; do not rebind the old INFRA_FAIL row.
6. Accept success when stream trade count is positive and equals report trades. The expected economic `FAIL` remains a successful infrastructure outcome for this ticket.

Until steps 1-5 are complete, the rebuild is compile-proven but the Q04 repair is not pipeline-proven.
