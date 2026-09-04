# Monitor-budget exhaustion classification

2026-09-04. Router task `b2106bba-e153-4912-a324-77102016b4f9`.
RESULT: IMPLEMENTED, focused verification PASS; leave REVIEW. Code commit `14e65476a1bb313f2f10cdb9169d009c65a66573` on `agents/codex`. [Unapplied code patch](2026-09-04_monitor_budget.patch).

The worker's existing monitor-timeout kill now records an explicit `monitor_kill` before stopping the runner. The record includes item, terminal, runner PID, original start timestamp, kill timestamp, actual elapsed runtime and effective monitor budget. It is flushed into the work-item log, emitted to the worker log, appended as a DB event, and persisted into the still-owned active payload. The final `run_result` carries both the marker and `worker_exit_record`. Adopted runners include elapsed time before adoption; a fresh 900-second monitor adopting a 1,200-second-old runner reports the original 900-second budget and at least 1,200 seconds of elapsed runtime.

`farmctl.classify_summary_missing_run` recognizes either that explicit marker or a recorded worker runtime within **2%, inclusive**, of its recorded effective budget. It emits `failure_subclass=monitor_budget_exhausted`, `failure_class=MONITOR_BUDGET_REVIEW`, `deterministic=true`, `retryable=true`, and `retry_requires_budget_review=true`. Missing, nonfinite or nonpositive budgets are not inferred from today's defaults. A marker tied to another start timestamp is rejected. This cause takes precedence over an incomplete runner log that never reached `terminal_start`.

When the summary is missing, the worker releases its active claim to pending without spending an EA-defect retry or assigning a verdict. It creates the existing operational hold type `MONITOR_BUDGET_REVIEW_REQUIRED`, with `release_on_restart=0`, so an identical budget failure cannot immediately retry. This is an infrastructure budget review, not a trading gate threshold. An existing active OWNER hold is preserved. The ordinary governed hold-release process remains the release path after review; no budget or timeout is changed by this patch. A usable summary still follows its existing evidence-based completion path.

Health adds `monitor_budget_exhausted`: monitor-kill events during the last 24 hours, counts grouped by UTC day, and outstanding budget-review holds. The read-only backfill inventory is `tools/strategy_farm/monitor_budget.py`; it does not rewrite historical payloads or verdicts. Legacy timing classification requires the caller to name the historical budget explicitly and labels that assumption.

## Verification

- **54 tests PASS** across the new monitor-budget suite, existing summary-missing classifier suite, and worker adoption suite. One additional focused worker regression passed. [Captured validation and read-only health result](2026-09-04_monitor_budget_validation.json).
- Tests cover exact 98%/102% boundaries, just-outside values, malformed budgets, explicit markers beyond the timing window, stale attempts, log-before-stop and DB-before-stop ordering, fake-PID monitor completion, `run_result` propagation, pending hold and unchanged attempt count, preservation of an OWNER hold, health counts, and read-only historical inspection. No real terminal PID is terminated by these tests.
- The observed live health count is zero, as expected for an undeployed new event class. The new check is executed against a read-only DB connection for this receipt.
- [Historical T10 inventory](2026-09-04_monitor_budget_backfill.json), using an explicitly assumed legacy 5,400-second budget: four timing candidates, one on September 3 and three on September 4. Today's runtimes are 5,407.938, 5,407.625 and **5,406.734 seconds**. The last is work item `80eac290-815c-4550-9b26-9a5e3cfb3c38`, at `2026-09-04T13:04:11.381+00:00`, matching the reported incident. Old logs have no explicit kill marker, so this is timing evidence, not a retrospective claim of positively observed kill causality.

Reproduce tests:

```text
python -m pytest tools/strategy_farm/tests/test_monitor_budget.py tools/strategy_farm/tests/test_summary_missing_classification.py tools/strategy_farm/tests/test_terminal_worker_adoption.py -q
```

Reproduce the read-only legacy inventory from the code checkout:

```text
python tools/strategy_farm/monitor_budget.py --log D:/QM/strategy_farm/logs/terminal_worker_T10.log --legacy-budget-seconds 5400 --output C:/QM/repo/docs/ops/evidence/2026-09-04_monitor_budget_backfill.json
```

## Base and handoff

The code worktree was rebased onto required base `29d4f083b6`; all five named prerequisite commits are ancestors. The already integrated Q08 patch was dropped by Git as patch-equivalent. The previous pattern-counter commit remains reachable on `agents/codex-pre-monitor-20260904`; its rebased equivalent is `05f970a11e`. Pre-existing MagicResolver bytes remain SHA256 `9ac27556aac81504d263afaec51e88965a73c6be1045565bbd97112a4fa9eefb` and are outside these commits.

This cycle has not deployed the code, changed any active backtest, adjusted `run_smoke.ps1` timeouts, backfilled a verdict, or advanced main. Review is required before accepting the patch; integration remains Claude+OWNER's responsibility.
