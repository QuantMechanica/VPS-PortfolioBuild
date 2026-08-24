# Review — Farm DB schema hardening SH-1..SH-3 (task 4467448f)

**Reviewer:** Claude (review lane) · **Date:** 2026-08-24 · **Type:** ops_issue
**Task:** `4467448f-2448-4daf-9e5f-c22db8328c09` (REVIEW → **APPROVED**)
**Spec / artifact:** `docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md`
**Tool delivered:** `tools/strategy_farm/schema_hardening.py` (commit `be2d24791`; later
extended by `8269d5937`/`0d13c70cb` for SH-2, out of this commission's scope)
**Worker verdict:** SH-1 done+live; SH-3 instruction refuted by measurement, shipped as
monitor + successor commissioned; SH-2 unchanged (needs OFF window + review).

## Verification (read-only, mode=ro)

Ran `python tools/strategy_farm/schema_hardening.py check` and direct `PRAGMA` queries
against `D:\QM\strategy_farm\state\farm_state.sqlite`.

### SH-1 — materialize taxonomy — DELIVERED, ROT-clean
- Columns `verdict_taxonomy_stored`, `clean_status_stored` present on `work_items`
  (`PRAGMA table_info`); additive metadata-only columns, no existing column altered.
- Backfill complete: `count(*) where verdict_taxonomy_stored is null` = **0**.
- Hourly top-up task `QM_StrategyFarm_TaxonomyMaterialize_Hourly` = **Ready** (fills only
  NULLs; never overwrites — verdicts untouched, ROT-compliant).
- View retained as independent validator (design matches spec).

### SH-3 — FK enforcement — instruction correctly refuted, shipped as monitor
- `check` reproduces the spec numbers exactly: **99** orphans
  (`work_items->tasks` 71, `tasks->sources` 28); `parent_task_id` polymorphic
  (39 → work_items, 14 → agent_tasks, 18 → nothing); `tasks.source_id` holds 10 EA-form ids.
- `enforcement_on:false`, `safe_to_enforce:false` with cited reason. Refusing to switch
  `PRAGMA foreign_keys=ON` (which would fail-close the factory write path) is the correct,
  Hard-Rule-compliant call. Successor for the real fix is task `f01d0098` (reviewed
  separately today).

### SH-2 — explicitly deferred by this commission (needs OFF window + review). Not in scope.
Column `ex5_sha256` is present from the later SH-2 commits; those belong to other tasks.

### Tests
`pytest tools/strategy_farm/tests/test_schema_hardening_sh2_sh3.py` → **4 passed**.

## Finding (noted, non-blocking)
`check` now reports `sh1.valid:false` (mismatch taxonomy 239, status 305 of 112,284) — up
from 0 at delivery. This is the documented consequence of the "fill NULLs only, never
overwrite" design: rows whose verdict/status transitions **after** materialization drift,
and the write path does not yet re-materialize on transition (explicitly SH-2/write-path
scope). The validator **surfaces** the drift rather than hiding it, so this is a monitored
gap, not silent corruption. It confirms materialized taxonomy is not self-maintaining until
the write path is integrated — already covered by SH-2 and the SH-3 successor. Does not
defeat this commission, whose own acceptance (0 drift at delivery) was met.

## Verdict: APPROVED
Commission delivered honestly against spec. SH-1 live and additive; SH-3's measured
refutation and fail-safe monitor are a strength; SH-2 correctly deferred. Residual
validator drift is a documented, monitored consequence owned by follow-up (SH-2 write-path
+ successor `f01d0098`).
