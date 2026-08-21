# Drain classifier and bounded requeue engine — 2026-08-21

## Outcome

`tools/strategy_farm/drain_backlog.py` now provides the single read-only census and bounded-wave entry point requested by the OWNER drain directive. Default invocation is dry-run and prints counts by defect class. Apply requires an exact `--class`, positive `--limit`, and stable `--wave-id` idempotency key.

The engine does not implement another queue mutation. It delegates:

- RECYCLE build/review recovery to `agent_router.reconcile_task_exits`, now with an exact task-UUID filter.
- Built-never-gated enqueue to `sweep_enqueue_built_eas.py`, scoped to the selected EA IDs, with stranded Part 2 disabled for that invocation.
- Stranded-INFRA recovery to `requeue_stranded_infra.py`, retaining its MNT-007 exact Wave-1 size of 5, durable journal, Factory-OFF/quiescence requirements, poison guards, and Wave-2 receipt gate.

The engine itself never writes or synthesizes a gate verdict. Agent-task verdicts are preserved by `COALESCE`; the exact-task extension changes only the rows selected after classification. Existing pipeline evidence remains the judge.

## Mandatory already-gated filter

Every RECYCLE build is checked against current canonical artifacts and the work-item ledger before it can enter an apply class:

1. Compiled EX5 plus at least one `status='done'` work item → `RECYCLE_BUILD_ALREADY_GATED`; no apply class exists for it.
2. Gemini-owned build rows without completed gating → `RECYCLE_BUILD_GEMINI_REVIEW_REQUIRED`; never advanced directly to pipeline.
3. Any pending/active work item on a non-Gemini row → `RECYCLE_BUILD_PIPELINE_IN_FLIGHT`; no duplicate enqueue/rebuild.
4. Compiled EX5 plus setfiles but no work history → `RECYCLE_BUILD_BUILT_NEVER_GATED`; delegates to the existing sweep.
5. MQ5 without EX5 and no work history → `RECYCLE_BUILD_NEEDS_REBUILD`; exact UUIDs delegate to reconcile-exits.

The regression fixture deliberately creates an actionable-looking RECYCLE build with a compiled EX5 and a done PASS work item. Classification returns `RECYCLE_BUILD_ALREADY_GATED`; applying the rebuild class selects zero and moves zero, leaving both state and verdict untouched.

## Wave contract

Example dry run:

```powershell
python tools/strategy_farm/drain_backlog.py
```

Example bounded recovery wave:

```powershell
python tools/strategy_farm/drain_backlog.py --apply --class RECYCLE_BUILD_NEEDS_REBUILD --limit 5 --wave-id mnt039-rebuild-001
```

Each attempted apply first writes an atomic `PLANNED` JSON receipt beneath `docs/ops/evidence/` with the exact selected rows and pre-state, then replaces it with a `COMMITTED` receipt containing the delegated mechanism, before/after class counts, before/after queue counts, rows moved, and explicit zero synthesized/overwritten-verdict counters. A crash leaves the durable selection and the wave ID fails closed until reconciled. Reusing a committed class/limit/wave-id loads the immutable receipt and returns `moved_count_this_invocation=0` without invoking a mechanism again. A new bounded cohort therefore requires a new wave ID.

Stranded-INFRA retains the stricter mechanism contract: limit 5 maps to Wave 1; arbitrary sizes are refused. Limit 25 is not opened by the wrapper without the underlying MNT-007 Wave-1 PASS receipt and must be invoked through that governed mechanism.

## Live dry-run census

The full command ran without `--apply` at 2026-08-21T15:21:21Z and classified 4,777 records. The durable concise receipt is `2026-08-21_drain_backlog_dry_run.json` beside this document. Key recovery cohorts were:

| Defect class | Current count |
|---|---:|
| RECYCLE build already gated (refused) | 10 |
| RECYCLE build built-never-gated | 2 |
| RECYCLE build needs rebuild | 295 |
| Gemini RECYCLE build requiring Codex review (refused) | 50 |
| RECYCLE review | 58 |
| Active EA built-never-gated | 54 |
| Active EA missing EX5 | 1,162 |
| Active EA missing setfiles | 250 |
| Stranded-INFRA retry | 292 |
| Stranded-INFRA blocked/retired | 16 |
| Work items already in flight | 2,239 |

The earlier programme census measured 113 already-gated RECYCLE rows. The lower current number is not threshold drift: concurrent reconciliation moved most of those stale tasks out of RECYCLE before this snapshot. The mandatory compiled-plus-done predicate itself is unchanged.

The reused stranded classifier reported its disposition invariant PASS, zero unresolved groups, and zero retryable invalid-report Q08 groups.

## Verification

- Focused drain/router/SLO tests: `34 passed`.
- Broader existing router + stranded + sweep + drain suite before the final idempotency-key tightening: `90 passed`.
- `python -m py_compile tools/strategy_farm/drain_backlog.py tools/strategy_farm/agent_router.py` → exit 0.
- `git diff --check` on the implementation and tests → no whitespace errors.
- Live default invocation → read-only census above; no queue, task, verdict, terminal, T_Live, or AutoTrading write.

No live apply wave was run during this task. The implementation is ready for review; later capacity releases remain explicit, bounded operator actions.
