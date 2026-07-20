# Framework P1 H4 — Codex evidence

Coordination authority: `docs/ops/evidence/2026-07-20_framework_p1_claude_coordination.md`.
The implementation was prepared in the isolated `agents/codex` worktree. No
active factory terminal Include directory was synchronized or changed.

## Implemented contract

- `framework/include/QM/QM_Logger.mqh` adds literal `"sv":1` to every
  `QM_LogEvent` envelope.
- `framework/scripts/generate_event_vocabulary.py` deterministically scans MQL5
  sources, resolves literal / scalar-const / top-level-ternary event expressions
  for `QM_LogEvent` and `QM_LogFatal`, and reports unresolved dynamic calls.
- `framework/registry/event_vocabulary.json` records schema-v1 `qm_events` and
  the deliberately bare `q08_trades` / `TRADE_CLOSED` second schema. The
  generated registry contains 240 event names, 5,983 resolved call sites, and
  three explicit unresolved calls. It includes the H2 state-persistence events
  and H3 `NEWS_TESTER_CALENDAR_SELFTEST` that landed in the shared worktree.
- `framework/scripts/run_smoke.ps1` captures one exact, schema-v1, EA-scoped
  byte delta from the stopped tester agent logger, publishes the selected delta
  as the timestamped report's `logger_sample.jsonl`, and records its path,
  source offsets, hashes, and event count in `summary.json`. It fails closed on
  concurrent/running-terminal use, ambiguous files, prefix mutation, partial
  lines, invalid UTF-8/JSON, schema drift, or an EA-id mismatch.
- `framework/scripts/resolve_logger_sample.py` deterministically resolves the
  newest valid summary-linked sample under the smoke report root.
- `tools/strategy_farm/prompts/codex_build_ea.md` resolves that sample and adds
  `-LoggerSamplePath` to the existing farm `build_check` invocation when one is
  available, retaining the existing no-sample fallback and pass requirement.
- `framework/scripts/build_check.ps1` validates the checked-in registry and its
  schema versions, requires `sv=1` for QM event rows, recognizes the explicitly
  separate bare Q08 trade schema, and emits WARN (not FAIL) for registered-schema
  rows or target-EA literals whose event name is unknown.

## Focused non-MT5 verification

```text
> pwsh -NoProfile -File framework/scripts/tests/Test-RunSmokeLoggerSample.ps1
Test-RunSmokeLoggerSample.result=PASS

> pwsh -NoProfile -File framework/scripts/tests/Test-BuildCheckEventVocabulary.ps1
Test-BuildCheckEventVocabulary=PASS

> python -m pytest framework/scripts/tests/test_generate_event_vocabulary.py framework/scripts/tests/test_resolve_logger_sample.py -q
5 passed in 0.25s

> python framework/scripts/generate_event_vocabulary.py --check
event_vocabulary.check=PASS events=240 unresolved=3 path=C:\QM\worktrees\codex\framework\registry\event_vocabulary.json

> PowerShell Parser.ParseFile(framework/scripts/run_smoke.ps1)
run_smoke.parse=PASS

> python -m py_compile framework/scripts/generate_event_vocabulary.py framework/scripts/resolve_logger_sample.py
exit 0
```

The smoke PowerShell test builds isolated synthetic tester-agent directories and
asserts that the published JSONL is byte-identical to the source append; it also
asserts rejection of a row belonging to a different EA. The build-check test
exercises a valid schema-v1 row, an unknown-event WARN, the separate Q08 schema,
and malformed/legacy rows. A real smoke session was not started because factory
automation owns the tester lanes; the first wave smoke will provide the first
resolvable schema-v1 runtime sample.
