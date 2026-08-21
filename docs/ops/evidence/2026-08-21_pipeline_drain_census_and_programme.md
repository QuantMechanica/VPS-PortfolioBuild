# Pipeline drain — census, definition of "empty", and programme

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Status:** census measured, wave 1 applied
**Authority:** OWNER directive 2026-08-21 — *the intermediate goal before any book is built is to
bring every strategy card and every EA through the complete gates, with nothing silting up
anywhere, recycled items going through as well, and the whole thing genuinely running empty once.*

This supersedes "build a book when enough survivors exist" as the operative near-term target. A
book is still the goal; it is no longer the next step.

---

## 1. Why this directive changes something concrete

Two mechanisms in the code were explicitly parked waiting for exactly this decision:

- `agent_router.py reconcile-exits` is **deliberately not wired into the autonomous tick**. Its
  own comment: *"RECYCLE->TODO re-queues 411 build_ea rows into the build lane — a mass requeue
  and an OWNER capacity decision."*
- MNT-039 (`2c9179ac`, closed today) delivered the PIPELINE-orphan disposition but parked the
  RECYCLE sweeper for the same reason.

The capacity decision is now made. Both are unblocked.

## 2. Definition — when is the funnel "empty"?

"Leergelaufen" needs a testable definition, otherwise it is a feeling. Proposed, and used as the
target for this programme:

| # | Condition | Today |
|---|---|---:|
| D1 | No active EA-ID without either a pipeline row or a dated terminal disposition | **1 470 open** |
| D2 | No (EA, symbol) pair sitting on an infra-class failure with no `done` row at that gate | **1 185 open** |
| D3 | `agent_tasks` RECYCLE = 0 (each row either requeued and completed, or terminally disposed with a reason) | **429 open** (was 567) |
| D4 | `work_items` pending = 0 | **2 250 open** |
| D5 | No non-terminal work item older than the phase SLO | Q02 `pending` oldest **2026-07-26** |

D1–D3 are the drain programme. D4 is throughput and drains by itself once D1–D3 stop refilling it.
D5 needs a per-phase SLO, which does not exist yet (MNT-039 deferred it as an aggregate age
bucket).

**A terminal disposition counts as drained.** RETIRE with a reason is a completed outcome — the
goal is that nothing is *unknown*, not that everything passes.

## 3. Census (measured 2026-08-21 against `D:/QM/strategy_farm/state/farm_state.sqlite`)

### 3.1 EAs that never reached a gate — 1 470 of 4 431 active IDs

Only **2 961** of 4 431 active registry IDs have ever produced a work item.

| Class | Count | What it needs |
|---|---:|---|
| No EA directory (ID reserved, never built) | 963 | card decision: build or retire |
| Directory but no source | 8 | disposition |
| `.mq5` source, **never compiled** | 195 | compile + setfiles + review |
| **compiled `.ex5`, never gated** | **304** | enqueue (53 already have setfiles) |

304 EAs were built to a finished binary and no gate ever saw them. That is the sharpest waste in
the house: the expensive part was paid, the cheap part never happened.

### 3.2 Pairs stranded on infrastructure — 1 185

(EA, symbol) pairs whose row at a gate is `failed` with a NULL / `INFRA_FAIL` / `INVALID` /
`TIMEOUT` verdict **and** which have no `done` row at that same gate — i.e. no verdict was ever
produced, on any attempt:

| Gate | Pairs |
|---|---:|
| Q02 | 1 010 |
| Q04 | 127 |
| Q07 | 20 |
| Q05 | 16 |
| Q06 | 5 |
| P2 | 4 |
| Q03 | 3 |

These are invisible in every PASS/FAIL statistic. They are not failures; they are absences.

### 3.3 RECYCLE backlog — 567 rows before wave 1

| Task type | Rows |
|---|---:|
| build_ea | 500 |
| review_ea | 58 |
| ops_issue | 6 |
| other | 3 |

Attempts: 470 rows at `recycle_count=0`, 97 at 1 — all far below `RECYCLE_MAX_ATTEMPTS=3`, so
nothing is looping. Age: 10 from May, 99 June, 307 July, 151 August.

### 3.4 The filter that matters most: "is it already through?"

Of the 384 RECYCLE rows that looked actionable (build_ea, class A/B, EA directory present),
checked against **current** artifacts and pipeline rows:

| Class | Rows | Meaning |
|---|---:|---|
| `NEEDS_REBUILD` (no `.ex5`) | 268 | genuine work |
| **`ALREADY_GATED`** | **113** | the EA was rebuilt later and has `done` work items — the RECYCLE row is stale bookkeeping |
| `BUILT_NEVER_GATED` | 3 | ready to enqueue as-is |

**29 % of the apparently-actionable backlog was already done.** Requeueing by bulk would have
re-run 113 builds for nothing. Spot-verified: QM5_11895 (built 2026-06-21, 120 work items),
QM5_11905 (built 2026-06-30, 23 work items, currently pending at Q04), against QM5_11899 (no
`.ex5`, no setfiles, 0 work items — genuinely unbuilt).

This is the same lesson Recovery-814 (`c72689a2`, closed today) paid for in compute: 814 requeued
items yielded 246 PASS (30.2 %) over 122.4 measured elapsed-hours. **Requeue by defect class,
never by bulk.**

## 4. Wave 1 — applied today

| Action | Rows | Cost |
|---|---:|---|
| `reconcile-exits --state APPROVED --apply` (37 → PASSED, 2 → PIPELINE) | 39 | none, bookkeeping |
| Stale-but-gated RECYCLE rows → PASSED with a documented reason | 113 | none, bookkeeping |
| Genuinely unbuilt RECYCLE rows → TODO (bounded first wave) | 25 | build lane |

RECYCLE: 567 → **429**. REVIEW: 28 → 0 (all closed the same day; six `review_ea` rows were the
lane's head-block).

None of this overwrote a verdict or created a gate result. Every disposition is reversible via
`agent_task_transition_ledger`.

**Explicitly NOT the ROT case:** compiling the 195/268 unbuilt sources is *not* "recompile in
active inventory" — those EAs have no binary, no bound hash and no pipeline row that a recompile
could invalidate. The ROT prohibition protects bound evidence; here there is none to protect.

## 5. What is commissioned (not merely noted)

| Work | Lane | Why there |
|---|---|---|
| Drain classifier + waved requeue engine (per-class, "already through?" filter mandatory, dry-run default, receipt per wave) | Codex | tooling with tests |
| Compile + setfile + build_check batch for the 195 source-only EAs | Codex | mechanical, high volume |
| Enqueue sweep for the 304 built-but-never-gated EAs, per skip reason | Codex | `sweep_enqueue_built_eas.py` already exists and enqueues 1 per run against 769 skips |
| Disposition of the 963 reserved-but-unbuilt IDs | Claude | card-level judgement, touches the card universe |
| Per-phase age SLO so D5 becomes testable | Codex | MNT-039 follow-up |

`sweep_enqueue_built_eas.py` skip reasons on today's dry run (769 skipped, 1 enqueued):
`no_setfiles` 234, `registry_status=None` 239, `no_ex5` 202, `review_entry_gate` 47,
`requeue_excluded_q02` 23, `registry_status=retired` 8, remainder small. Each is a drain class
with a different fix — the sweep is not broken, it is correctly refusing to enqueue incomplete
EAs, and nobody has been fixing what it refuses.

## 6. Risks

1. **The review lane is the real ceiling, not the factory.** Every rebuilt EA needs a `review_ea`
   that only I close. 268 rebuilds at today's demonstrated rate (28 reviews in one session) is
   roughly ten review sessions. Build-gate hardening (`a834b1e20`) reduces per-review load but
   does not remove the review.
2. **Priority floor.** Most RECYCLE build rows carry priority 1–15 and would never be picked. The
   requeue path normalises them to 50, which is correct for draining but does compete with new
   work. If drain and new-card builds are to be ordered explicitly, that is a queue-order change
   I can make — but it should be a stated choice, not a side effect.
3. **Refill.** Research sources are being added while the funnel is clogged (12 added today,
   `7f48a274`). Under this directive they stay parked in the pool; the pool being non-empty is a
   health metric, dispatching from it is not authorised until the drain target is met.
4. **Q09_NEWS remains at 0 PASS** with 24 pending and 24 infra-failed rows. Any drain that pushes
   volume through Q02–Q08 will pile up behind it. Draining is not finished at Q08.

## 7. Reproduction

```powershell
cd C:/QM/repo
python tools/strategy_farm/agent_router.py reconcile-exits            # dry-run, all limbo states
python tools/strategy_farm/sweep_enqueue_built_eas.py                 # dry-run, prints skip reasons
python tools/strategy_farm/inventory_stranded_eas.py --output <path>  # read-only stranded inventory
```

Census queries (work_items status x phase, infra-stranded pairs without a `done` row, registry vs
pipeline set difference on the `QM5_`-stripped ea_id) are in §3 and reproduce directly against
`farm_state.sqlite`.
