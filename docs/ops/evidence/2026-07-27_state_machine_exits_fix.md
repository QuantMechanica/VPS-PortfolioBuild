# State-machine exit fix — RECYCLE / APPROVED / PIPELINE / pipeline_run

Date: 2026-07-27
Author: Claude (board-advisor lane)
Scope: census ranks 4, 5, 8, 9, 12 — the router state-machine dead ends.
Authority for volumes: `docs/ops/evidence/2026-07-27_factory_loose_ends_census.md`.
Constraint honoured: **no bulk transition of the stranded backlog** — the fix builds
the mechanism and reports what would move; applying it is a separate, visible decision.

## 1. The defect

`agent_router.route_once` selects only `state IN ('BACKLOG','TODO')`
(`tools/strategy_farm/agent_router.py:601`). Three states of the documented
contract therefore have **no router exit**, so a task entering one sits there until
an out-of-band event moves it:

| State | Live count (2026-07-27) | Oldest |
|---|---:|---|
| RECYCLE | 431 | 2026-05-26 |
| APPROVED | 209 | 2026-05-23 |
| PIPELINE | 59 | 2026-05-23 |

Plus rank 12: `pipeline_run` required capability `pipeline`, which **no enabled agent
declares**, so it was deterministically unroutable (returned `no_available_agent`
three times before being re-filed as `ops_issue`).
Plus rank 9: 15 tasks recorded a **directory** in `artifact_path`; a directory handed
to the build guardrails made `validate_path` walk the whole `framework/EAs` tree and
time out on close-review.

## 2. Canonical contract checked BEFORE implementing

Source: `G:\My Drive\QuantMechanica - Company Reference\02 Org\AI Agent Routing and Role
Contracts.md`.

```
BACKLOG -> TODO -> IN_PROGRESS -> REVIEW -> APPROVED -> PIPELINE -> PASSED
                                      \-> FAILED / RECYCLE / OPS_FIX_REQUIRED / BLOCKED
```

- "APPROVED heißt: formal sauber genug, damit der **nächste deterministische Prozess**
  starten darf. Für EAs ist die echte Entscheidung weiterhin P2..P8/P10."
- Task-type table: `build_ea` → *MQL5 EA, Registry, Setfiles, Commit*; then the pipeline
  produces *Phase evidence path*.
- Hard Rule / prompt contract: **"Pipeline verdicts come only from the pipeline."**

**Key semantic finding (evidence, not inference):** APPROVED is dominated by task types
that have *no downstream MT5 pipeline* — measured with a read-only query of the live DB:

```
APPROVED  ops_issue=88  research_strategy=48  review_ea=32  review_strategy=27
          triage_failure=8  build_ea=3  card_review=2  q02_infra_repair=1
```

For a research card / review / ops report / triage diagnosis, APPROVED **is already the
accepted verdict** — there is no gate after it. Only `build_ea`'s "next deterministic
process" is the backtest pipeline. So a blanket `APPROVED -> PIPELINE` would shove ~206
tasks into a state where **no pipeline verdict can ever arrive** — inventing a *new* dead
end, the opposite of the fix. This is why the exit is type-aware.

## 3. Implemented exits (deterministic, type-aware)

`_compute_task_exit` (`agent_router.py:1294`), applied by `reconcile_task_exits`
(`agent_router.py:1340`):

| From | Task type | To | Reason | Rationale |
|---|---|---|---|---|
| APPROVED | `build_ea` (`PIPELINE_BOUND_TASK_TYPES`, `:97`) | **PIPELINE** | `approved_build_handed_to_pipeline` | The next deterministic process for a build is the backtest pipeline. |
| APPROVED | everything else | **PASSED** | `approved_accepted_terminal` | No MT5 pipeline exists downstream; APPROVED is the accepted terminal. |
| PIPELINE | any (by referenced EA) | **PASSED / FAILED** | `pipeline_closing_verdict_pass/fail` | Read from `work_items` closing phase Q10/P8 — **never manufactured** (`_ea_pipeline_verdict`, `:1265`). |
| PIPELINE | in-flight EA (no closing verdict) | **leave** | `pipeline_in_flight_no_closing_verdict` | Legitimately waiting on the pipeline; the health invariant surfaces it if it goes stale. |
| RECYCLE | any | **TODO** (bounded) | `recycle_requeue` | Return to the queue for another attempt; `recycle_count++`. |
| RECYCLE | recycled ≥ `RECYCLE_MAX_ATTEMPTS` (3) | **BLOCKED** | `recycle_attempts_exhausted` | A permanently unbuildable card must not loop forever. |
| any | `pipeline_run` (`REMOVED_TASK_TYPES`, `:78`) | **BLOCKED** | `pipeline_run_retired_not_agent_lane` | Retired task type gets a terminal home instead of staying unroutable. |

`PIPELINE -> PASSED/FAILED` resolves strictly on `work_items` where
`phase IN ('Q10','P8') AND status='done' AND verdict IN ('PASS','FAILED')`, PASS winning
over FAIL. This honours "Q10 full-history confirmation is the closing per-(EA,symbol)
verdict" and "pipeline verdicts come only from the pipeline" — the router only *reads* the
factory's verdict, it never writes one.

## 4. pipeline_run — retired, not re-capabilitised

Decision: **remove `pipeline_run` from the agent task-type map** (`agent_router.py:58-67`),
do **not** grant any agent the `pipeline` capability.

Argument: a pipeline verdict is produced by the deterministic Q02–Q10 factory (work_items
+ phase runners + T1–T10 terminal workers), which is not an `agent_tasks` lane at all.
Giving an agent `pipeline` would authorise an AI worker to *manufacture* a pipeline
verdict — a direct Hard-Rule breach ("Pipeline verdicts come only from the pipeline") and
exactly the census's warning ("agents must not manufacture pipeline verdicts"). So
`pipeline_run` as an agent task type is a category error. It had **zero router-enqueue
callers** — the only other repo hit, `farmctl.py:12026`, is an unrelated process-classifier
string. Its one live row (already RECYCLE, self-noted as "re-enqueued as ops_issue") gets a
terminal `BLOCKED` home via the reconciler. Code/ops work a `pipeline_run` was standing in
for is filed as `ops_issue`. `enqueue_task` now raises a helpful error if it is requested
(`:366`).

## 5. Artifact must be a FILE — validated on write

`_directory_artifact_error` (`agent_router.py:189`) rejects an **existing directory** in
any `artifact_path` at the three write sites — `enqueue_task` (`:370`), `update_task`
(post-load), and `close_review_task` (both the passed path and, for APPROVED build_ea, the
resolved evidence before the guardrail scan). This stops a directory being *recorded in the
first place* (validate on write, not only on read), which closes the rank-9 guardrail
timeout at source.

Preserved: the semicolon multi-path form (fixed the same day, four `review_strategy` tasks
depend on it) — each part is checked independently. A **not-yet-written** file path is still
accepted (artifacts are often recorded before they land); only an existing directory is
refused. Covered by `test_multipath_semicolon_files_still_accepted` and
`test_nonexistent_relative_file_path_still_accepted`.

## 6. Detection — health invariant

`chk_agent_task_state_stranded` (`health.py:2534`), registered in `ALL_CHECKS`
(`health.py:2620`), runs every 15 min with the other pipeline invariants. Read-only.

**First-run counts (2026-07-27, live DB):**

```json
{
  "name": "agent_task_state_stranded",
  "status": "WARN",
  "value": 699,
  "threshold": 900,
  "detail": "limbo tasks: RECYCLE=431, APPROVED=209, PIPELINE=59 total=699 (>3d stale=624); directory_artifacts=15"
}
```

WARN (not FAIL) is deliberate: the FAIL threshold (900) sits above the known ~700-row
legacy backlog so today's inherited tail is an actionable amber, not a permanent red
banner, while genuine new growth escalates to FAIL — the same WARN-vs-FAIL discipline the
stress-identity detector uses.

## 7. What WOULD move — and why nothing was moved

`reconcile-exits` is **dry-run by default** and is **not** wired into the autonomous
`run_once` tick. Detection is continuous; remediation is an explicit operator call.

Dry-run against the live DB (`python tools/strategy_farm/agent_router.py reconcile-exits`):

```json
{
  "would_move": {
    "APPROVED->PASSED:approved_accepted_terminal": 206,
    "APPROVED->PIPELINE:approved_build_handed_to_pipeline": 3,
    "PIPELINE->PASSED:pipeline_closing_verdict_pass": 1,
    "RECYCLE->TODO:recycle_requeue": 430,
    "RECYCLE->BLOCKED:pipeline_run_retired_not_agent_lane": 1
  },
  "left_in_place": { "pipeline_in_flight_no_closing_verdict": 58 },
  "moved_count": 0
}
```

**Nothing was applied.** The `RECYCLE->TODO: 430` line is the reason: 411 of RECYCLE are
`build_ea`, so applying it re-queues ~430 rows straight into the build lane — a mass
requeue and a factory-capacity decision that belongs to OWNER, not a side effect of a
state-machine fix. Applying it should be bounded and staged, e.g.:

```
# preview only
python tools/strategy_farm/agent_router.py reconcile-exits
# terminal-accepted APPROVED reclassification only (no lane load):
python tools/strategy_farm/agent_router.py reconcile-exits --apply --state APPROVED --state PIPELINE
# RECYCLE rebuilds, in small OWNER-authorised batches:
python tools/strategy_farm/agent_router.py reconcile-exits --apply --state RECYCLE --limit 20
```

## 8. Tests

`tools/strategy_farm/tests/test_agent_router_state_exits.py` — 18 tests, all passing:
type-aware APPROVED exits, PIPELINE PASS/FAIL/in-flight resolution off `work_items`,
bounded RECYCLE requeue → BLOCKED at cap, dry-run/limit/state-filter behaviour,
`pipeline_run` retirement, and directory-artifact rejection on enqueue/update/close plus
multi-path and not-yet-written-path acceptance.

Regression check: `test_agent_router.py` — 16 pass / 5 fail, and the 5 failures are
**pre-existing** (identical with the two changed files stashed; they concern
`replenish_directed`/`research_matrix` and card-schema drift, not this change).
`test_agent_router_stale_release.py` passes.

## 9. Files changed

- `tools/strategy_farm/agent_router.py` — retire `pipeline_run`; type-aware exit map;
  `reconcile_task_exits` + CLI `reconcile-exits`; artifact-file enforcement on write.
- `tools/strategy_farm/health.py` — `chk_agent_task_state_stranded` invariant + registration.
- `tools/strategy_farm/tests/test_agent_router_state_exits.py` — new tests.

## 10. Not done (deliberately)

- No bulk transition of the 699 limbo tasks (constraint).
- Q02 43k `summary_missing_retries_exhausted` classifier (rank 1) — separate work item.
- Interactive `0x800710E0` scheduled jobs (rank 10) — separate work item.
- QM5_20180 joint-EA fidelity divergence — separate diagnosis.
