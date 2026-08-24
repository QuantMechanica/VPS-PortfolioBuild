# Review: SH-3 successor schema migration (f01d0098)

- Reviewer: Claude (review lane)
- Date: 2026-08-24
- Task: `f01d0098-c28b-448c-a0c1-769360997b11` (ops_issue, codex)
- Title: "SH-3 successor: replace the polymorphic parent_task_id and the mislabelled tasks.source_id"
- Worker artifact: `docs/ops/evidence/f01d0098_schema_successor_off_window_blocker_2026-08-23.md`
- Worker verdict: `BLOCKED_OFF_WINDOW_AND_SCHEMA_CONTRACT`
- Review verdict: **BLOCKED (endorsed)**

## What was reviewed

Read-only verification (DB `mode=ro`, no writes) of the worker's decision to refuse
the live schema migration. The worker changed no code, DB, schema, writer, reader,
verdict, FK setting, or scheduled task — `git log/status` on
`tools/strategy_farm/schema_hardening.py` is clean (last real commit
`0d13c70cb`, no working-tree diff), consistent with a BLOCKED (no-mutation) outcome.

## Independent re-measurement (2026-08-24)

`python tools/strategy_farm/schema_hardening.py check` and a direct SQL
classification reproduce the worker's numbers (1-row drift on the live totals
because the factory kept writing between 08-23 and 08-24; the typed split is exact):

| Class | Worker (08-23) | Reviewer (08-24) |
|---|---:|---:|
| `work_items.parent_task_id` non-null | 4,911 | 4,912 |
| resolves to `tasks(id)` | 4,840 | 4,841 |
| resolves to `work_items(id)` only | 39 | 39 |
| resolves to `agent_tasks(id)` only | 14 | 14 |
| resolves to none | 18 | 18 |
| `tasks.source_id` non-null | 31 | 31 |
| resolves to `sources(id)` | 3 | 3 |

`schema_hardening.py check` corroborates: `sh3.by_table` = work_items->tasks 71
(= 39+14+18), tasks->sources 28; polymorphic breakdown 14/18/39;
`tasks_source_id_holding_ea_ids` 10; `safe_to_enforce=false`, `PRAGMA foreign_keys=OFF`.

## Finding — the instruction is unexecutable as written (confirmed)

The task's prescribed target — split `parent_task_id` into `parent_work_item_id`
and `parent_agent_task_id` — accounts only for the 39 work-item + 14 agent-task
references (53 rows). It has no home for the **dominant 4,841 valid
`tasks(id)` references**. Executing the two-column split as specified would drop or
misclassify the largest valid lineage relation in `work_items`. The worker is
correct: this is a schema-contract gap in the instruction, not a codex defect.
`tasks.source_id` is likewise a decision, not a migration contract — 3 genuine
source refs, 10 EA-shaped, 18 other; blanket rename to `ea_id` would be false.

## Finding — OFF window required and absent (confirmed)

Changing SQLite FK declarations requires a table rebuild + coordinated writer
rollout, which needs an OWNER-authorized Factory-OFF window. No such window is
active: only a superseded flag
(`FACTORY_OFF.flag.superseded_governor_throttled_map_20260813T200933Z`) exists; no
live `FACTORY_OFF.flag`. The factory is running (worker measured 3,232 pending /
9 active). `CODEX_BURN_AUTHORIZED.flag` is a quota bypass, not an OFF window. FK
migration + enforcement is ROT-adjacent (schema touching verdict lineage,
factory-wide blast radius); codex correctly refused to mutate live.

## Verdict rationale

BLOCKED is the correct close state. Not RECYCLE: there is no actionable defect for
codex to fix in a deliverable — the worker did the right measurement and refused.
Not FAILED: the worker performed correctly and produced a sharpened, reproduced
measurement. Not APPROVED: nothing was migrated. The blocker is OWNER-side.

## Unblock path (for OWNER/Claude)

1. Ratify a complete typed schema that **explicitly retains or re-homes the 4,841
   `tasks(id)` parents** (a third typed relation, or keep `parent_task_id` for that
   class) alongside `parent_work_item_id` (39) and `parent_agent_task_id` (14).
2. Name a disposition marker for the 18 dangling parents (retain, not delete).
3. Decide `tasks.source_id`: separate the 3 source refs / 10 EA-shaped / 18 other
   without guessing; specify writer/reader mapping.
4. Provide an OWNER-approved OFF window; run on a DB copy first, then a factory
   regression before `PRAGMA foreign_keys=ON`.
5. SH-1 baseline must return `valid=true` (taxonomy/status mismatches) without
   rewriting verdict evidence before `schema_hardening.py check` can go green.
