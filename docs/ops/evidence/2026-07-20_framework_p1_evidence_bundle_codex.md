# Framework P1 evidence bundle — Codex execution (2026-07-20)

Scope was coordinated with Claude before framework/include work. The recorded
decision is `docs/ops/evidence/2026-07-20_framework_p1_claude_coordination.md`:
Codex owns these edits and compile tests; Claude retains the 2026-07-26 serial
wave manifest and final T_Live verification. The work was performed in
`C:\QM\worktrees\codex` on `agents/codex`; no active terminal Include tree and
none of the protected P0 fixture paths were modified.

## H1 — canonical MAE hook

Changed:

- `framework/templates/EA_Skeleton.mq5` and the build prompt put
  `QM_FrameworkTrackOpenPositionMae()` first in `OnTick`, before every guard.
- `framework/scripts/build_check.ps1` emits
  `EA_Q08_MAE_HOOK_MISSING` as WARN when a production EA has `OnTick` but
  neither the direct call nor the approved `QM_KillSwitchCheck` compatibility
  path.
- `framework/scripts/q08_davey/__init__.py` records the evidence-lineage rule:
  pre-`715b0c077` or unknown-provenance binaries are untrusted realized-floor
  MAE and must not be used to recalibrate MAE gates.

Audit correction: the handoff's direct-call count was correct but its fleet-wide
runtime inference was not. Since commit `715b0c077` (2026-06-30),
`QM_KillSwitchCheck` calls the tracker. The final post-P1.9 production-source
audit found 3,172 active `OnTick` sources, 2 direct calls, 3,172 kill-switch compatibility calls,
and zero sources with neither path. The wave remains the conservative binary
provenance boundary.

Evidence and result:

- `D:\QM\reports\state\framework_mae_hook_source_audit_20260720.csv`
- `D:\QM\reports\state\framework_mae_hook_source_audit_20260720.summary.json`
- `framework/scripts/tests/Test-BuildCheckMaeHook.ps1`: PASS
- `framework/scripts/tests/test_framework_p1_evidence_contracts.py`: PASS

## H3 — tester news symbol self-test

Changed: `QM_NewsFilter.mqh` derives a strict, symbol-scoped currency set, logs
`NEWS_TESTER_CALENDAR_SELFTEST`, and returns false (propagating to `INIT_FAILED`)
when an applicable tester symbol has zero exact event-currency matches. Blank,
`ALL`, and permissive substring matches cannot satisfy the test.

Evidence and result:

- `D:\QM\reports\state\news_tester_symbol_selftest_preflight_20260720.csv`
  records 96,123 parsed seed rows and PASS for all applicable probe symbols
  (USD 25,121; EUR 20,432; EURUSD combined 45,553; production JPN225/JPY
  8,912; AUS200/AUD 7,588).
- `D:\QM\reports\state\framework_p1_include_compile_20260720.log`: MetaEditor
  compile PASS, 0 errors / 0 warnings.
- `D:\QM\reports\state\framework_p1_include_compile_20260720.json`: hermetic
  T_Export manifest; `terminal_include_modified=false`.

## H4 — event schema and registry

Changed:

- `QM_LogEvent` adds numeric `"sv":1`.
- `generate_event_vocabulary.py` produces the deterministic checked-in
  `framework/registry/event_vocabulary.json`, including the deliberately bare
  `q08_trades` / `TRADE_CLOSED` second schema.
- `build_check.ps1` validates registry/schema versions and required fields, and
  WARNs on unknown runtime or target-EA literal event names.
- `run_smoke.ps1` publishes an exact stopped-agent logger byte delta as
  `logger_sample.jsonl`; `resolve_logger_sample.py` selects the newest valid
  summary-linked sample; the farm prompt passes it as `-LoggerSamplePath`.

Evidence and result:

- `docs/ops/evidence/2026-07-20_framework_p1_h4_codex.md`
- Registry check: PASS, 240 names, 5,983 resolved call sites, three explicitly
  unresolved dynamic calls.
- `Test-BuildCheckEventVocabulary.ps1`: PASS.
- `Test-RunSmokeLoggerSample.ps1`: PASS.
- The resolver currently returns NOT_FOUND against pre-schema-v1 smoke reports;
  the embedded schema-v1 fallback remains active until the first wave smoke.

## H2 — account equity scope and persistent baselines

Changed:

- `QM_EquityStream.mqh` adds `"scope":"account"` and persists day/month
  baseline key/value pairs in non-tester terminal GlobalVariables, namespaced by
  account login and EA id. Value is written before the key commit marker;
  stale/invalid state is re-baselined. Tester runs never read or write terminal
  GlobalVariables. Restore, stale-ignore, and persist-failure events follow the
  kill-switch state logging pattern.
- Q08 readers normalize legacy rows to account scope, select the physical
  emitter symbol (including basket hosts), and use last-write-per-symbol/day
  semantics. The portfolio log consumer is locked by a regression test to
  median account snapshots across sleeves rather than summing one account's
  equity repeatedly.

Evidence and result:

- The hermetic include compile manifest above covers `QM_EquityStream.mqh` via
  `QM_Common.mqh`: PASS, 0 errors / 0 warnings.
- Combined focused Python suite (H1-H4, Q08, portfolio, P1.9, retirement,
  priority and health): 115 passed.

## H5 — non-FX tick-value verification only

Changed: added a seven-symbol diagnostic and guarded T_Export-only runner. The
runner requires an assigned `IN_PROGRESS` Codex ops task, refuses T1-T10 and
T_Live, compiles an isolated source copy, uses only symbol reads plus
`OrderCalcProfit`, and verifies the `QM_RiskSizer.mqh` hash is unchanged.

Runtime result: VERIFY completed but is `INCOMPLETE`, not a sizing PASS. All
seven `.DWX` instruments are custom symbols. Six report zero `tick_size`; the
remaining SP500 row has a native tick value but all four `OrderCalcProfit`
probes fail. Consequently all 7/7 rows are `UNRESOLVED`. This is evidence of an
unusable verification surface on T_Export, not authority to change sizing.

Evidence and result:

- `D:\QM\reports\state\dwx_tickvalue_dump_2026-07-20.csv`
- `D:\QM\reports\state\dwx_tickvalue_dump_2026-07-20.json`
- compile log: 0 errors / 0 warnings; terminal exit 0.
- ops task `3a32ab4b-807f-4367-8ce1-fcfca1b2e6a8` is in REVIEW with verdict
  `VERIFY_COMPLETE_INCOMPLETE`.
- `QM_RiskSizer.mqh` SHA-256 is identical before/after; no sizing source was
  edited.

The first startup-race run is preserved separately under
`D:\QM\reports\state\dwx_tickvalue_dump_2026-07-20_incomplete_startup_race*`.
