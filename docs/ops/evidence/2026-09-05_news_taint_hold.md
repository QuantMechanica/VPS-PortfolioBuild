# Governed news-calendar taint hold — REVIEW

Task: `86b7e902-a9a0-4542-bdc0-e22cf11ad74b` (priority 78). Code commit: `a5c9566053429bed4a089779834b98cf1c3c9e90` on `agents/codex-news-taint-hold-20260905`, based on `fe50fd1f65731a9e92fdab779265b751e8a7d522`. The complete [implementation patch](2026-09-05_news_taint_hold/implementation.patch) is attached for review. Evidence is recorded only in the canonical checkout on `agents/board-advisor`.

The proposed policy blocks pending Q09_NEWS/Q10_NEWS work while the pinned calendar content SHA-256 is on the declared list. The default configuration is **disabled**. No production apply, repin, worker reload, terminal launch or gate execution was performed. Current verdicts, work-item payloads, attempt counts and evidence are untouched by this policy.

The declaration names `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` and [the timestamp diagnostic](2026-09-05_news_calendar_diagnose.md), with the routed declaration time 2026-09-05T15:12:29+00:00. This is a claimability rule, not a changed news-gate criterion.

## Dry run

[The exact row list](2026-09-05_news_taint_hold/dry_run.json) contains **85 affected pending rows: 40 Q09_NEWS and 45 Q10_NEWS**. All 85 match the tainted pin. All already carry another active hold, so the prospective sweep reports 85 `PRESERVE_OTHER_HOLD`, zero new physical holds and zero releases. Existing hold codes: OOS_WINDOW_MISMATCH 39; NEWS_CALENDAR_TIMESTAMP_DEFECT 13; Q09_AWAITING_SEALED_PLAN 30; NEWS_RUNNER_SPAWN_SILENT_ABORT 3. This does not remove the need for the guard: a future successor, or a row whose other hold is released, must still be blocked before claim.

## Enforcement and release

Source anchors in the code commit:

- `tools/strategy_farm/news_calendar_taint.py:62`: exact pin-SHA decision, pending news phases only. Invalid policy/pin identity fails closed for those rows.
- `tools/strategy_farm/news_calendar_taint.py:107`: transactional, audited hold synchronization; never commits the caller's transaction or edits a work item. Existing unrelated active holds are retained.
- `tools/strategy_farm/news_calendar_taint.py:132`: claim guard rechecks the policy and writes any necessary hold inside the actual claim transaction.
- `tools/strategy_farm/terminal_worker.py:5358` and `:5833`: resident and targeted claim boundaries, before status/claim-ledger updates.
- `tools/strategy_farm/farmctl.py:13523`: one-shot dispatcher claim boundary; `:21125`: pump sweep before dispatch.

The guard covers successors created after the sweep without requiring successor payload edits. A later untainted global pin automatically releases only this policy's own `NEWS_CALENDAR_TAINTED` holds on the next sweep. Removing the taint entry is the specified rollback. Unrelated holds survive both operations. Existing sealed-plan and consumer binding checks remain independently applicable; this policy neither rewrites plans nor introduces a second plan-level release criterion.

## Verification and activation

**23 new policy tests pass. The focused regression selection passes 120 tests, with seven launch-execution tests outside that selection.** It covers all three actual claim paths, unseen successors, hold-before-claim, zero claim-ledger writes on refusal, no effect on other phases or active/completed rows, repin/removal release, other-hold preservation, idempotence, malformed policy/pin, disabled defaults, read-only preview, and backed-up apply/release against a temporary database.

The initial broader run found two existing launch-fixture failures at staged-EX5 preflight. Both reproduce with the parent commit's unmodified farmctl and worker loaded in memory. A separate missing sparse-checkout decision document was restored before the passing regression run. No unrelated launch code or tests were changed. [Regression output](2026-09-05_news_taint_hold/regression.txt) and [verification/hashes](2026-09-05_news_taint_hold/verification.json) bind the result.

Dry-run reproduction (read-only):

```powershell
python C:/QM/worktrees/codex-news-taint-hold-20260905/tools/strategy_farm/news_calendar_taint.py
```

After CEO review and canonical integration by Claude/OWNER, activation requires the configuration's `enabled=true` and a nonempty `activation_evidence` receipt. The CLI's `--apply` is explicit; without it the command previews only. The pump and workers must consume the integrated guarded implementation for ongoing enforcement. That integration, activation and reload were not executed here. No main branch/worktree was advanced.
