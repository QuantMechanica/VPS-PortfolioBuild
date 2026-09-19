# Ticket c73ed341 — Q09_NEWS worker-crash root cause (2026-09-19)

Task: `python tools/strategy_farm/agent_router.py update-task c73ed341-1107-4c5e-9f44-350522c3a990`.
Scope per payload: 5 rows INFRA_FAIL 2026-09-19 09:35-09:37Z on T4
(1ab6156f QM5_13301, 0d112806 QM5_10911, 033e7bc3 QM5_13128, f8f75276 QM5_10440,
5e308792 QM5_11294), IntegrityError `terminal work_item requires evidence_path or
EVIDENCE_UNAVAILABLE sentinel`.

## Correction to the prior disposition note

`q09news_legacy_phase_note.md` (this directory, committed by a Fable session ~11:46Z)
frames these rows as a dead v3 storage-phase artifact ("Q09_NEWS ... is NOT the v4 NEWS
storage phase ... disposition: migrate/supersede ... instead of 'fixing' a runner").
**That framing does not survive a query of the actual campaign.** All 125 work items
carrying `diagnostic_contract: "q09-live-news-backfill/v1"` (the OOS-2026-confirmation-v1
live-news-backfill diagnostic campaign, memory `project_qm_live_book_news_backfill_2026-08-05`
— "Kette nie verdrängen") use the identical literal `phase='Q09_NEWS'` string, and have done
so since the campaign's first dispatch on 2026-08-05:

| status/verdict | count |
|---|---|
| failed / INFRA_FAIL | 72 |
| done / REVIEW_REQUIRED (real sealed diagnostic evidence) | 47 |
| pending | 6 |

47 of 125 rows under the exact same phase string completed with genuine `REVIEW_REQUIRED`
verdicts backed by sealed `q09-live-news-diagnostic-summary/v1` evidence. A "dead phase the
runner no longer understands" cannot explain a 38% success rate on the identical phase
string across six weeks. **Do not run `q09_news_migration.py` against this — that tool
operates on the unrelated `portfolio_candidates` overlay table, not these `work_items`
rows, and would not touch the actual defect.**

True scope is also far larger than the ticket's 5 named rows: **72/125 (58%) INFRA_FAIL**
since 2026-08-05, not 5. The 5 named rows are simply the most recent occurrences, surfaced
today because the RAM-reservation fix (commit `cadfb48731`, "index-lane unlock") made their
`single_index_tick` RAM class winnable again and they got reclaimed.

## What is confirmed

- `_Q09_NEWS_PHASE` (`terminal_worker.py`, module load) resolves at import time from
  `farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS","NEWS")`, currently
  `"Q10_NEWS"` — not the literal `"Q09_NEWS"` these work_items carry. This makes
  `_q09_sidecar_matches()` return `True` unconditionally (bypassed, not enforced) for
  every one of these 125 rows (`terminal_worker.py:8690-8691`). This is a real latent gap
  (the evidence-sidecar check the 2026-09-13 EVIDENCE CONTRACT comment describes is not
  actually applied to this campaign) but it is **not** the crash cause — the bypass just
  means "treat as matching," it does not throw.
- The crash site captured in every historical row's `payload.worker_crash_traceback_tail`
  is identical: `_write()` inside `_record_active_payload`/similar helper raises
  `sqlite3.IntegrityError` on the MNT-009 evidence trigger, caught by the top-level
  `except Exception` in `run_loop` (added 2026-08-22 after a prior fleet-attrition
  incident) and landed safely via `_fail_item_after_worker_crash`, which stamps the
  `EVIDENCE_UNAVAILABLE:worker_crashed_handling_item` sentinel. **No verdict was ever
  written without evidence** — the crash guard is working as designed; the acceptance
  criterion "never a verdict without evidence" is already structurally satisfied.
- The five 2026-09-19 rows crashed 14-38 seconds after claim (`claimed_at_iso` →
  `updated_at`), before an MT5 backtest could plausibly finish — the throw is in
  preflight/dispatch bookkeeping, not in verdict derivation after a real run.
- **The true origin of the exception is unrecoverable from existing evidence.**
  `_fail_item_after_worker_crash` only ever persisted the last 6 traceback lines, and
  those 6 lines are always the generic `_write`/`IntegrityError` catch-site frames —
  never the frames above it where the actual defect lives. Every one of the 72 historical
  INFRA_FAIL rows has the same useless tail. This is why acceptance criterion #1 ("why the
  runner reaches the terminal write without evidence_path") cannot be answered from
  historical rows alone.

## Fix applied (this ticket, GRÜN: additive diagnostics only, no verdict-logic change)

`tools/strategy_farm/terminal_worker.py`, `_fail_item_after_worker_crash`: the full
traceback is now also written to
`<root>/artifacts/ops/worker_crash_traceback/<item_id>_<terminal>_<stamp>.txt` and the
path recorded as `payload.worker_crash_traceback_path`. The existing 6-line tail,
verdict, taxonomy, and `EVIDENCE_UNAVAILABLE` sentinel are unchanged (byte-identical
write statement). A file-write failure is caught and degrades to `None` — it can never
reintroduce the bare-write crash this guard exists to prevent.

Tests: `tools/strategy_farm/tests/test_worker_crash_traceback_evidence.py` (2 new, both
pass) — asserts the full traceback file is written and captures a frame the 6-line tail
discards, and that a simulated file-write failure still lands the row correctly. Also ran
`test_health_sqlite_lock_crash.py`, `test_candidate_repair_enqueue.py`,
`test_preflight_failure_sh3.py`, `test_terminal_worker_custom_history_isolation.py`,
`test_poison_pill_seal_evidence_binding.py` (91 passed) — none construct payloads through
this function, so the new key is additive and does not break their fixtures.
`python -m py_compile terminal_worker.py` OK.

Rollback: revert this diff (single function edit, no schema/migration/DB changes touched).

## Disposition — deliberately incomplete this cycle

**Not done, and should not be done yet:** requeuing the 5 INFRA_FAIL rows
(`--append-only-rerun-of`) or releasing the `Q09_NEWS_RUNNER_CRASH_NO_EVIDENCE_20260919`
hold on the 6 pending siblings. Per
`project_qm_inputsvalid_framework_pin_defect_2026-08-20` (never blind-requeue a
reproducible crash): with a 58% historical failure rate and the actual defect still
unknown, a blind rerun/hold-release would most likely reproduce the same uninformative
crash rather than either fix or diagnose anything.

**Recommended next step (needs Codex review + a live worker restart to pick up the
diagnostics fix, so out of scope for this single headless cycle):** after this diff is
reviewed and deployed, do exactly one governed release of a single held sibling row
(e.g. `fe1b3e6b` QM5_13128/NDX, the same EA/symbol as one of today's crashes) and let it
run under the patched worker. Whatever happens — PASS, REVIEW_REQUIRED, or INFRA_FAIL with
now a full traceback file — read the result before touching the other five. This is the
"governed smoke on one sibling row" the ticket's acceptance criteria call for; it cannot
be honestly performed without the diagnostics fix landing first, since the existing worker
build would produce the same uninformative 6-line tail as before.

**Separately worth flagging to OWNER (Entscheidungsschlange):** the 58% crash rate on a
named FTMO OOS-confirmation campaign has been running for six weeks without an operator
noticing the true failure rate (the ticket that reached this desk described 5 rows, not
72). The 47 `REVIEW_REQUIRED` rows already carry real evidence and are presumably awaiting
downstream review — worth confirming they have not been starved by the same undercount.

## Files

This document; `tools/strategy_farm/terminal_worker.py` (diff);
`tools/strategy_farm/tests/test_worker_crash_traceback_evidence.py` (new).
