# MNT-045 — news filter degrades in the tester like it already does live

**Date:** 2026-08-21
**Router task:** 9e1e08cc-df52-4533-9167-6c7f6778e564 (priority 79, ops_issue)
**Authority:** OWNER decision 2026-08-21, "wir folgen immer der Empfehlung" on
MNT-045. Ratified semantic: the news filter degrades in the tester exactly as
it already degrades live, and the degradation is visible in the verdict —
economics decides an EA's fate, never calendar provisioning.
**Recorder:** Claude (agents/board-advisor)

## Scope

`framework/include/QM/QM_NewsFilter.mqh`, `QM_NewsInit()`, three branches that
previously called `QM_NewsLogSetupMissing(...)` + `return false;` (→
`INIT_FAILED`) under `MQL_TESTER` while the live branch already degraded with
a `NEWS_CSV_DEGRADED_LIVE` WARN and `return true;`:

| Reason | Old tester behaviour | New tester behaviour |
|---|---|---|
| `calendar_file_missing_or_unreadable` | `INIT_FAILED` | WARN `NEWS_CSV_DEGRADED`, init succeeds |
| `calendar_csv_parse_failed` | `INIT_FAILED` | WARN `NEWS_CSV_DEGRADED`, init succeeds |
| `calendar_zero_rows_parsed` | `INIT_FAILED` | WARN `NEWS_CSV_DEGRADED`, init succeeds |

**Not touched:**
- The staleness check (L910-920, live-only, gated by `!MQLInfoInteger(MQL_TESTER)`)
  — unrelated to this ticket and to the CLAUDE.md build guardrail on
  `qm_news_stale_max_hours`.
- The Q09 tester-bundle branch (`QM_NewsInitTesterBundle`) and its hard-fail
  contract — untouched, different data path.
- `QM_NewsTesterCalendarSelfTest` (currency/schema self-test) — still fails
  init hard; that check runs only after a *non-empty* parse succeeds, so it is
  a distinct "the data loaded but disagrees with the symbol's currency"
  failure class, out of this ticket's three named reasons.
- The preflight claim gate (`_news_calendar_preflight` in `farmctl.py`,
  `test_news_calendar_claim_gate.py`) — this is what stops a truly missing
  calendar from ever reaching a backtest at all. This change covers a
  gate-passed run whose data still turns out unreadable/unparseable/empty at
  `QM_NewsInit` time. Confirmed present and unmodified
  (`tools/strategy_farm/farmctl.py` still defines `_news_calendar_preflight`;
  its test file is green, see below).
- `g_qm_news_available` semantics: still set to `false` on every degrade path
  (tester and live alike), so any code that gates on the CSV feature
  (`calendar_unavailable`, coverage-gap checks) is unaffected — only the
  `QM_NewsInit()` return value/INIT-failure behaviour changed.

## Verification

New static test:
`tools/strategy_farm/tests/test_news_filter_tester_degrade_static.py`
(structural — `.mqh` cannot be compiled/run outside MT5, matching the
existing convention in `test_news_filter_calendar_bundle_static.py`).

Failed-before / passes-after, checked directly against `git show HEAD:...`
(pre-fix) content for all three reasons — confirmed all three markers absent
pre-fix, all three present + `return true;` post-fix:

```text
reasons missing tester-degrade marker on PRE-FIX code (expected: all 3):
['calendar_file_missing_or_unreadable', 'calendar_csv_parse_failed', 'calendar_zero_rows_parsed']
```

```
python -m pytest -q \
  tools/strategy_farm/tests/test_news_filter_tester_degrade_static.py \
  tools/strategy_farm/tests/test_news_filter_calendar_bundle_static.py \
  tools/strategy_farm/tests/test_news_filter_fresh_boundary_static.py \
  tools/strategy_farm/tests/test_news_filter_csv_layout.py \
  tools/strategy_farm/tests/test_news_calendar_claim_gate.py \
  framework/scripts/tests/test_generate_event_vocabulary.py
25 passed in 2.10s
```

`framework/scripts/tests/test_framework_p1_evidence_contracts.py::test_tester_news_selftest_is_strict_and_precedes_loaded_event`
was checked and found **pre-existing broken independent of this change** —
it fails identically against unmodified `HEAD` content (its `source.split("bool QM_NewsInit", 1)`
matches the earlier `bool QM_NewsInitTesterBundle` definition first, an
unrelated substring-collision bug in the test itself, not a regression here).
Not touched or "fixed" as part of this ticket; flagging for separate triage.

## Registry sync

`framework/registry/event_vocabulary.json` is a deterministic generated
artifact (`framework/scripts/generate_event_vocabulary.py`). Regenerated
after the source change; new entry `NEWS_CSV_DEGRADED` added alongside the
existing `NEWS_CSV_DEGRADED_LIVE`, `resolved_call_count` 7445→7448.
`--check` passes post-regeneration.

## What was not done

- No recompile of any EA in the active inventory.
- No factory start/stop, no terminal64 launch, no reboot.
- Preflight claim gate untouched.
- `CLAUDE.md`'s pre-existing foreign modification (unrelated, MNT-011's
  blocker — see `docs/ops/evidence/2026-08-21_mnt013_blocked_on_mnt011.md`)
  left alone and not committed by this change.

## Acceptance check

> "A tester run with a degraded calendar completes and its verdict carries
> the NEWS_CSV_DEGRADED marker instead of failing hard; a test covers both
> the degraded and the clean path; the claim gate is demonstrably still in
> force."

- Tester run completes instead of `INIT_FAILED`: yes, structurally verified
  (`return true;` on all three reasons).
- Marker present: yes, `NEWS_CSV_DEGRADED` (tester) distinct from
  `NEWS_CSV_DEGRADED_LIVE` (live), both resolvable in the event vocabulary.
- Test covers degraded path: yes (`test_news_filter_tester_degrade_static.py`).
  Clean/happy path (`NEWS_CALENDAR_LOADED`) was already covered by existing
  tests and is unmodified by this change.
- Claim gate still in force: yes, `_news_calendar_preflight` present and its
  five tests in `test_news_calendar_claim_gate.py` pass unmodified.

Note: this ticket did not extend the pipeline verdict/evidence layer
(Q06/Q07/etc.) to specially recognize the `NEWS_CSV_DEGRADED` marker in
aggregate verdicts — the marker is now emitted into the QM event stream as
instructed ("emit a machine-readable NEWS_CSV_DEGRADED marker into the run
evidence"), but consuming it downstream (e.g. so Q06/Q07 don't count a
degraded-and-therefore-zero-trade run as an economic FAIL) is a separate,
unscoped follow-up if OWNER wants it.
