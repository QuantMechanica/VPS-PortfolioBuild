# Adversarial review — router state-machine + Q02 failure-classification fixes

Date: 2026-07-27
Reviewer role: adversary for the ROUTER changes (assume broken; verify against code, not docs).
Commits under review:
- `20f5ff6d` fix(router): RECYCLE/APPROVED/PIPELINE exits + retire pipeline_run
  (`docs/ops/evidence/2026-07-27_state_machine_exits_fix.md`)
- `3e811661` fix(q02): classify summary_missing graveyard
  (`docs/ops/evidence/2026-07-27_failure_classification_fix.md`)

Verification method: read the two commit diffs, traced the claim path, read the consumers
(`render_cockpit.py`, `health.py`, `requeue_stranded_infra.py`, `sweep_enqueue_built_eas.py`,
`_aggregate_work_item_verdict`), queried the live DB read-only
(`D:/QM/strategy_farm/state/farm_state.sqlite`, WAL), confirmed the real run_smoke emitter,
and ran the test suites (incl. a parent-commit run to prove the pre-existing failures).

## Headline verdict

**Both fixes SURVIVE the adversarial review.** No change touches the MT5 claim path; no
bulk mutation occurred; no new path fabricates a pipeline verdict; the failure-vocabulary
change is back-compatible with every consumer I checked, including the cockpit CRITICAL
gate. The remediation tools (`reconcile-exits`, `classify_summary_missing.py`) are dry-run
by default and are NOT wired into the autonomous tick — verified in code and in the DB.

Nothing rises to a fleet-stall or verdict-corruption defect. The findings below are
MEDIUM-LOW caveats and apply-time hazards worth recording; none block the commits.

---

## Attack 1 — THROUGHPUT / claim path

**Claim path is untouched — SURVIVES.** The MT5 saturation loop is
`terminal_worker.claim_atomic` + `farmctl.pending_claim_order_sql` /
`recovery_claim_allowed`. Neither commit modifies any of them:
- `terminal_worker.py` diff touches only `_finish_work_item` (the exhaustion boundary).
- `farmctl.py` diff adds only `classify_summary_missing_run` + `SM_*` constants (one hunk,
  118 insertions); no edit to claim ordering, recovery cap, or `claim_atomic`.
- `agent_router.py` is the *agent-task* lane, a different table from the MT5 backtest queue.

**F1 (LOW) — new unbounded log read at the finish boundary.**
`terminal_worker.py:2108` reads the whole run_smoke log with `Path(...).read_text()` at
final exhaustion. Mitigants that de-fang it: (a) the read happens *before* the write lock
is taken — the `UPDATE` is at `:2127`, so no SQLite writer lock is held during the read;
(b) it fires only at `attempt >= MAX_WORK_ITEM_RETRIES`, and the live rate is ~0/day
(`chk_q02_summary_missing_unclassified` first run: 0 in 48h); (c) it is the run_smoke
*orchestration* log, not the MT5 journal, and a full read already exists on this path
(`terminal_worker.py:1765`). Nit: a bounded tail helper exists (`_read_tail_bytes` /
`_decode_log_tail`, `terminal_worker.py:951`) and the classifier only needs the LAST
`terminal_exit` line — a tail read would be strictly safer for the log-bomb class it
targets. Not a regression vs. prior behavior; recommend a tail read on hardening.

**F2 (LOW) — `reconcile-exits --apply` holds one write transaction across the batch.**
`agent_router.py:1369` opens `BEGIN IMMEDIATE`; the loop then runs, per PIPELINE row, two
`work_items` lookups inside that transaction (`_ea_pipeline_verdict`, `:1265`) and up to
`limit` `agent_tasks` UPDATEs, committing only at the end (`:1395`). `agent_tasks` and
`work_items` share one DB file (verified), so the write lock contends with
`claim_atomic`. Why this is LOW, not HIGH: the `_ea_pipeline_verdict` query is index-served
(`EXPLAIN`: `SEARCH work_items USING INDEX idx_work_items_ea_phase`), `agent_tasks` is 762
rows, WAL + `_with_sqlite_retry` absorb brief contention. Residual: it is dry-run by
default and OWNER-gated, but the evidence doc does not warn that `--apply` serializes
against the claim path. **Recommendation: apply only with `--limit`, and prefer a
quiescent window — the sibling `classify_summary_missing.py` already mandates "Factory OFF
while applying"; `reconcile-exits --apply` deserves the same note.**

## Attack 2 — FAIL-OPEN

**No new check stalls the fleet — SURVIVES.**
- Forward classifier fail-open verified: unreadable/ambiguous evidence →
  `UNCLASSIFIED` → `retryable=True` → `INFRA_FAIL`, i.e. prior behavior
  (`farmctl.py:2480-2482`; `terminal_worker.py:2120-2125`). Log read failure is caught
  (`OSError` → `log_text=None`, `terminal_worker.py:2111`).
- `_directory_artifact_error` fails open on error: `OSError` → `continue` (treated as
  not-a-directory), non-existent path → allowed; only an *existing* directory is refused
  (`agent_router.py:189-217`).
- `_ea_pipeline_verdict` fails safe: `sqlite3.OperationalError` (table absent) → `None` →
  "in flight, leave in place" (`agent_router.py:1279-1281`), never a forced verdict.

**F3 (MEDIUM-LOW) — clean-exit-no-summary is classified non-retryable INVALID, which
removes it from the auto-requeue sweep.** In `classify_summary_missing_run`, a
`terminal_exit` with `timed_out=False`, `log_bomb=False`, and no whitelisted transient
token is asserted DETERMINISTIC → `INVALID` (`farmctl.py:2458-2467`). `INVALID` is
excluded from the hourly re-enqueue (`requeue_stranded_infra.py:254`,
`sweep_enqueue_built_eas.py:307` both filter `verdict='INFRA_FAIL'`), so a genuinely
transient failure mode that still produces a clean exit with no report (e.g. a momentary
report-file lock) — and that has already failed its 3 inline retries — loses its future
auto-requeue. This is a deliberate, defensible design (a tester that finished cleanly and
produced nothing usable is a deterministic no-summary; the doc's fail-open scope is
honestly limited to *unreadable/ambiguous* evidence), and the measured transient share is
0.1%. It is not a fail-open violation in the fleet-stall sense. Recorded as the one place
"deterministic" rests on absence-of-transient-token rather than presence-of-defect;
`SM_TRANSIENT_TOKENS` (`farmctl.py:2397`) is the lever if a new clean-exit transient mode
appears — `chk_q02_summary_missing_unclassified` will not catch it (it is classified, just
into the wrong bucket), so this class is only visible via the requeue-drain rate.

**F4 (LOW) — `close_review_task` directory guard fails CLOSED for ALL close states.**
The early `_directory_artifact_error(artifact_path)` runs before the `close_state` branch
(`agent_router.py:1178`), so closing a REVIEW task to FAILED/BLOCKED/RECYCLE while passing
an *existing directory* as `--artifact-path` is now refused (`closed: False`), not only for
APPROVED. Passing a file, or omitting the path, is unaffected (`None` → no error). Narrow
(only fires on an explicitly-passed existing directory; 2 REVIEW rows today), but it is a
fail-closed behavior change on the review-close lane — an agent that insists on a directory
path can no longer close its review. Acceptable given the rank-9 intent, but worth noting.

## Attack 3 — SILENT SKIP

**No silent decline reintroduced — SURVIVES.** The documented starvation class lives in
`claim_atomic`, which is untouched. The new code logs everything: the classifier stamps
`failure_class` + `failure_subclass` + `failure_class_evidence` + `verdict_reason`
(`terminal_worker.py:2114-2118`); `reconcile_task_exits` returns `would_move` /
`left_in_place` / `moved` and records an `exit_reconciliations` history on each moved row
(`agent_router.py:1387-1391`); the health invariants surface limbo/tail/unclassified
counts every 15 min.

**F5 (LOW) — `reconcile-exits --apply` does not check rowcount on the guarded UPDATE.**
The write is `... WHERE id=? AND state=?` (optimistic concurrency, good), but
`n_applied`/`moved.append` run unconditionally (`agent_router.py:1395-1409`). If a row's
state changed between the SELECT and the UPDATE, the UPDATE matches 0 rows yet the run
reports it as moved. Reporting-only overcount under concurrency; never a wrong write
(the guard prevents that). Manual command → low impact.

## Attack 4 — MASS MUTATION

**No bulk transition or requeue occurred — SURVIVES (verified in the DB).**
Read-only live queries (`D:/QM/strategy_farm/state/farm_state.sqlite`):
- `agent_tasks` with `exit_reconciliations` in payload: **0** → `reconcile-exits --apply`
  never ran.
- `work_items` with `failure_class` in payload: **0** → the historical reclassifier never
  applied.
- `work_items` with `verdict_reason` prefix `summary_missing:`: **0** → forward classifier
  has not fired on a live row yet (consistent with ~0 exhaustions/48h).
- `agent_tasks` state counts NOW: RECYCLE=431, APPROVED=209, PIPELINE=59 — unchanged from
  the census; `summary_missing_retries_exhausted` verdict split unchanged (44,051
  INFRA_FAIL).
Structurally confirmed: `reconcile_task_exits` and `classify_summary_missing_run`/
`classify_summary_missing.py` have no caller in `run_once` or any tick — the only callers
are the `reconcile-exits` CLI (`agent_router.py:1633`), the `terminal_worker` exhaustion
boundary (single row), and the standalone historical CLI. Both remediation tools are
dry-run by default.

## Attack 5 — STATE-MACHINE CORRECTNESS

**No fabricated verdict; no illegal transition — SURVIVES.**
- **PIPELINE→PASSED/FAILED only READS the factory verdict.** `_ea_pipeline_verdict`
  (`agent_router.py:1265`) is a pure `SELECT` against `work_items` closing phases; it never
  writes a `work_items` verdict. The router moves the *agent-task* state only.
- **Verdict vocabulary matches the DB.** Code queries `verdict IN ('PASS','FAIL')` (loop
  `for want in ("PASS","FAIL")`). The DB has `FAIL` (19,980 rows; Q10 done = 40 PASS / 1
  FAIL) and **no `FAILED` value at all**. So the code is correct. NOTE: the state-machine
  doc §3 prose says `verdict IN ('PASS','FAILED')` — a cosmetic doc typo; the code is right.
- **REVIEW still requires a verdict.** `reconcile` targets only RECYCLE/APPROVED/PIPELINE
  (`LIMBO_STATES`); it never touches REVIEW. `close_review_task` still requires
  `--verdict`.
- **RECYCLE cannot loop forever.** Bounded by `recycle_count` vs `RECYCLE_MAX_ATTEMPTS=3` →
  BLOCKED (`agent_router.py:1288-1292`); the count persists in the row payload across
  transitions. Manual + bounded.
- **APPROVED non-build → PASSED** is a task-completion state, not a pipeline PASS verdict,
  and is applied only by the explicit dry-run-first reconcile — defensible.

**F6 (MEDIUM-LOW) — `_ea_pipeline_verdict` is EA-level, not (EA,symbol)-level, and PASS
wins over FAIL.** It returns PASS if *any* Q10/P8 done row for the `ea_id` is PASS,
ignoring symbol (`agent_router.py:1274-1288`). For a multi-symbol EA whose symbol A passed
Q10 while symbol B failed or is in flight, a PIPELINE agent-task keyed to that EA reconciles
to PASSED on symbol A's pass. In the cleanup context (stranded PIPELINE rows, oldest
2026-05-26, manual/dry-run) this is a reasonable heuristic, but it can label an EA-task
"PASSED" when only one of its symbols passed. If these tasks are ever per-(EA,symbol),
tighten the query to match symbol.

**F7 (LOW) — `_task_ea_id` regex `(\d{3,6})` is not QM5-anchored.** `agent_router.py:1261`
uses `re.search(r"(\d{3,6})")`, unlike the QM5-anchored `_portfolio_admission_key` right
below it. It works for 5-digit ids ("QM5_10692" → skips the 1-digit "5", captures "10692"),
but a 7-digit id would be truncated to its first 6. No such ids exist today; flagged as a
latent fragility, consistent with the MEMORY note on the `QM5_(\d+)` vs `\d+` trap.

## Attack 6 — VOCABULARY / consumers

**The INFRA_FAIL→INVALID flip and the new reason string break no consumer — SURVIVES.**
- **Parent aggregation unchanged.** `_aggregate_work_item_verdict` buckets `INVALID`
  together with `INFRA_FAIL` in `infra_fail_count` (`farmctl.py:5553-5558`), so a child
  flipping to INVALID yields the same parent aggregate ("INFRA_FAIL"). INVALID is already a
  first-class Q02 verdict (1,586 rows live).
- **Requeue effect is the intended one.** INVALID is excluded from the auto-requeue sweeps
  (`requeue_stranded_infra.py:254`, `sweep_enqueue_built_eas.py:307`), so the flip *reduces*
  pointless re-runs of deterministic no-summary rows — if anything a saturation *gain*, not
  a regression.
- **Back-compat key preserved.** `final_failure` stays `summary_missing_retries_exhausted`
  (`terminal_worker.py:2103`), so every consumer keying on it still works
  (`health.py:2658`, `requeue_stranded_infra.py`, `classify_summary_missing.py`,
  `backfill_verdict_reason.py`). No consumer does exact-equality on the *reason* string
  (only an unrelated `== "LOG_BOMB"`), so `verdict_reason = summary_missing:<subclass>` only
  makes reason histograms more granular.
- **Cockpit CRITICAL gate intact.** `render_cockpit.py:1589` gates CRITICAL on a
  `_FACTORY_DOWN_CHECKS` allowlist that does NOT include the three new checks; a new FAIL
  falls to the `_any_fail` branch → pill degrades to WARN at most (`:1631`). The
  "CRITICAL only when the factory is down" invariant holds.
- **Health pass is crash-safe.** The runner wraps each check in try/except → degrades a
  raising check to WARN (`health.py:2756`), and `con=None` degrades con-checks to WARN
  (`:2750`); a new check cannot take down the whole pass. `REPO_ROOT` is defined
  (`health.py:43`), so the new dir-scan check has no NameError.
- `phase_label()` operates on phase keys (P*→Q*), which neither commit touches — unaffected.

## Production-reality checks (fix is not inert)

- The forward classifier's `_SM_TERMINAL_EXIT_RE` (`farmctl.py:2403`) expects
  `timed_out=… valid_report_latched=… log_bomb=…` in that order. The real emitter,
  `framework/scripts/run_smoke.ps1:1677`, prints exactly
  `... timed_out={2} valid_report_latched={3} log_bomb={4}`. **The regex matches production
  logs** — the classifier will actually classify, not just fail-open forever. A format drift
  degrades to fail-open (INFRA_FAIL), not a crash.

## Tests (run, not trusted from the doc)

- `test_agent_router_state_exits.py` + `test_summary_missing_classification.py`: **43
  passed** (from repo root).
- Regression `test_agent_router.py`: **16 pass / 5 fail** — and the 5 failures are
  **pre-existing**: I checked out the parent version of `agent_router.py`
  (`20f5ff6d~1`) and got the identical 5 failures (all in `replenish_directed` /
  `research_review_card`, code the diff never touches). The router fix introduced none.
  Working tree restored clean.

## What SURVIVES (summary)

| Attack | Result |
|---|---|
| 1 Throughput — claim path untouched | SURVIVES (F1/F2 apply-time LOW) |
| 2 Fail-open — no fleet-stall path | SURVIVES (F3 MEDIUM-LOW, F4 LOW) |
| 3 Silent skip — everything logged | SURVIVES (F5 LOW reporting) |
| 4 Mass mutation — 0 rows written | SURVIVES |
| 5 State machine — no fabricated verdict | SURVIVES (F6 MEDIUM-LOW, F7 LOW) |
| 6 Vocabulary — consumers intact | SURVIVES |

## Recommendations (non-blocking)

1. Document that `reconcile-exits --apply` serializes one write transaction against the
   claim path; require `--limit` and a quiescent window (parity with
   `classify_summary_missing.py`). [F2]
2. Switch the exhaustion-boundary log read to the existing bounded tail helper. [F1]
3. If PIPELINE agent-tasks are ever per-(EA,symbol), make `_ea_pipeline_verdict` match the
   symbol. [F6]
4. Check `cursor.rowcount` in the reconcile apply loop before counting a move. [F5]
5. Fix the doc typo `('PASS','FAILED')` → `('PASS','FAIL')` in the state-machine evidence.
