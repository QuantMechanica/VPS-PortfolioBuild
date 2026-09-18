# build_ea parent-state vs gating review_ea reconciliation — 2026-09-18

Task `a4e82d86-550f-4bdd-85e9-353e9af26dcc` (router title: "Reconcile build_ea
parent states with their FAILED/BLOCKED gating cross-reviews: 4b97cf9e
(PASSED), e48c6a6c (PASSED), 2d3a6323 (PIPELINE) - evidence-integrity
follow-up of the 2026-09-18 review triage"). Source finding:
`D:/QM/reports/ai_exchange/20260918_review_triage/REVIEW_TRIAGE.md` §1a.

## What §1a found

Three `review_ea` rows sit BLOCKED with an explicit card-defect verdict while
their parent `build_ea` row (`agent_tasks.parent_id`, confirmed by direct
query, not inferred) had already reached a positive terminal/in-flight
`agent_tasks.state`:

| build_ea | state | review_ea (child) | review state | review verdict |
|---|---|---|---|---|
| `4b97cf9e` (QM5_33008) | PASSED | `da921b20` | BLOCKED | card never defines the sigma lookback for its RVI (10-bar window invented); `expected_dd_pct` 15 vs 5% body stop |
| `e48c6a6c` (QM5_34004) | PASSED | `33203a5c` | BLOCKED | card still underdefines entry/management; rework would require invented mechanics |
| `2d3a6323` (QM5_33002) | PIPELINE | `c734242f` | BLOCKED | card gives no precedence between the daily-open entry instruction and the rollover blackout |

(The fourth §1a row, `5d5cc9f6`/`fb52c402`, was already flagged
"consistent" — PIPELINE parent, PASS review — and is out of scope here.)

## Disposition: LEGITIMATE_NON_HAZARDOUS divergence, not a live risk — corrected append-only

Two independent facts settle this without touching any verdict or state:

1. **`agent_tasks.state` on `build_ea` is task-lifecycle bookkeeping, not EA
   admission.** Read from `agent_router.py`: `PIPELINE_BOUND_TASK_TYPES =
   {"build_ea"}`; nothing reads `build_ea` state to gate further pipeline
   dispatch. Per `CLAUDE.md`: *"APPROVED means 'formally clean enough for the
   next deterministic process' — the pipeline (Q02–Q13) remains the real
   judge of an EA"* and *"Pipeline verdicts come only from pipeline
   evidence."* The two `PASSED` verdicts are themselves explicit dedupe
   bookkeeping ("bereits durch ... Q03 PASS 2026-08-19" /
   "... Q02 PASS 2026-08-17") — they record that an equivalent build/compile
   already happened, not that the strategy is sound.
2. **The live `work_items` pipeline — the actual judge — already stalled all
   three independently of this review**, verified by direct query
   (`D:/QM/strategy_farm/state/farm_state.sqlite`, read-only):
   - QM5_33008: latest Q04 row is `pending` (never resolved), stale since
     2026-08-19T22:41:45Z — over a month with no further progress.
   - QM5_34004: latest Q04 row is `FAIL`, 2026-08-19T13:56:51Z.
   - QM5_33002: latest Q04 row is `FAIL`, 2026-09-13T15:09:53Z (most recent
     of the three, still negative).

   None of the three EAs has advanced past Q04 since. Nothing currently
   treats the stale `build_ea` bookkeeping state as license to progress them
   further — the review_ea BLOCKED finding and the Q04 stall are pointing
   the same direction.

**Conclusion:** the divergence is real (confirmed by direct DB query, not
assumed) but not operationally hazardous — no live process is currently
reading `build_ea` PASSED/PIPELINE as "this EA is validated" to justify
further work. It is, however, a genuine trap for a future reader (dashboard,
cockpit, or agent) who sees `PASSED`/`PIPELINE` on the parent without
noticing the child review.

## Action taken (append-only, verdict/state untouched)

Per the Hard Rule that verdicts are never deleted/overwritten, and per the
router's own closure-mechanics doc (§0: *"the ledger stays append-only"*
pattern already used by `blocked_agent_task_sweeper.py`'s
`payload.blocked_backlog_journal`), a new tool —
`tools/strategy_farm/session_tools/reconcile_build_ea_parent_review_divergence_0918.py`
— appended one compare-and-swapped ledger entry per row to
`payload.parent_review_divergence_ledger` on each of the three `build_ea`
rows. It does **not** touch `state`, `verdict`, or `artifact_path`. Verified
post-apply: all three rows retain their original `state` and `verdict`
verbatim; each now carries exactly one ledger entry cross-referencing its
`review_ea` id, the review's verdict hash, and the live Q04 disposition at
apply time. Result: `docs/ops/evidence/2026-09-18_build_ea_parent_review_divergence_reconciliation/apply_result.json`.

The tool is idempotent (`already_journaled` skip) and uses compare-and-swap
against `updated_at`, matching the concurrent-write discipline the rest of
`tools/strategy_farm` uses against the live SQLite state DB.

## What this does not do

- Does not change any EA's pipeline admission — that was already decided by
  Q04 independent of this reconciliation.
- Does not close, RECYCLE, or otherwise dispose of the three `review_ea`
  rows — those are already BLOCKED terminal per the router (verified live,
  `updated_at` 2026-09-18T00:53:5[7-9]Z), evidently closed by an earlier
  agent following the triage's recommended commands.
- Does not touch cards, registries, or gate criteria (ROT).

## Recommended next step

No further router action is required for these three EAs — they are already
correctly stalled pre-Q04 pending a card amendment (33008, 34004) or a card
precedence ruling (33002), which is OWNER/Research card authority, not an
agent task. If a dashboard/cockpit widget is later found to surface
`build_ea` state as an EA-quality signal without cross-checking its
`review_ea` children, that would be a distinct, separately-scoped ops ticket
(none identified in this task's scope).
