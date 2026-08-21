# Registry integrity repair — QM5_1354 / QM5_1355 missing ea_id_registry rows

**Operator:** Claude · **Task:** 09291af2 (ops_issue, priority 74)
**Scope:** `framework/registry/ea_id_registry.csv` (canonical checkout `C:\QM\repo`, branch `agents/board-advisor`)
**Date:** 2026-08-21

## Symptom
QM5_1354 (woodie-cci-dual-h1) and QM5_1355 (williams-vix-fix-fx-h4) are fully built
(.mq5/.ex5 present), carry ACTIVE magic-number allocations in
`framework/registry/magic_numbers.csv` (slots 0-7 each, `ea_id*10000+slot`, allocated
2026-08-10 by Gemini), and QM5_1354 already has an ACCEPTED `review_ea` (PASSED). Yet
neither has ever had a row in `ea_id_registry.csv`. `sweep_enqueue_built_eas.py` (the
canonical never-tested sweeper) skips both as `registry_status=None`, so they can never
enter the pipeline.

## Root cause
Both cards were **originally REJECTED 2026-05-19** (`g0_rejection_reason: "R1 FAIL:
... missing source_citation metadata"`) — see `cards_rejected/QM5_1354_woodie-cci-dual-h1.md`
and `cards_rejected/QM5_1355_williams-vix-fix-fx-h4.md`. At that point in the company's
history the current `reserve-ea-ids` governance path (atomic, auto-incrementing,
lock-protected) either did not yet exist or was not invoked for a rejected card — no
registry row was ever written, even though the numeric `ea_id` was already fixed in
the card frontmatter (`ea_id: QM5_1354` / `QM5_1355`).

The cards were later **recovered under the OWNER R1 policy (2026-07-23)** — informational,
non-gating R1 — and re-evaluated fresh on R2-R4, reaching `g0_status: APPROVED` on
2026-07-27 (`legacy_contract_repair: true`, `g0_recovery_origin` pointing at the original
rejected file). Gemini then built both EAs and allocated their magic rows on 2026-08-10.

**The structural gap:** `reserve_ea_ids()` (`tools/strategy_farm/farmctl.py:23025`) is
"the only safe path for autonomous Research allocation" but it only ever **auto-allocates
a new, unused ea_id** (`next_id = max(existing) + 1`) — there is no governed tool to
**backfill a registry row for a legacy card whose ea_id was fixed before rejection**,
which is exactly this case. So the recovery process had no mechanical way to close the
gap, and it silently persisted for four weeks post-approval and eleven days post-build.

## Repair
Confirmed via `git log --all -S"1354,woodie-cci-dual-h1"` (and the 1355 equivalent) over
`ea_id_registry.csv`: **zero hits** — the rows were never written at any point in history,
not removed later.

Appended two rows directly to `ea_id_registry.csv` (via `farmctl._acquire_registry_lock`
+ `_read_csv_dicts_with_columns` + `_write_csv_atomic`, run from the canonical checkout
`C:\QM\repo` — not the worktree, whose `farmctl.py` resolves a different `REPO_ROOT`):

```
1354,woodie-cci-dual-h1,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Research,2026-05-18
1355,williams-vix-fix-fx-h4,6e967762-b26d-59a3-b076-35c17f2e7c36,active,Research,2026-05-18
```

- `strategy_id` = each card's frontmatter `source_id` (confirmed this is the registry
  convention by cross-checking `QM5_1357_as-pragmatic-aa.md`'s `source_id` against its
  existing registry row).
- `owner`/`created_at` = `Research` / `2026-05-18`, matching every other row sharing the
  same `strategy_id` (source-batch siblings 1342-1346, 1357-1361 all use this exact pair).
- **No new ID reserved.** Both ea_ids already existed in the card frontmatter and in
  `magic_numbers.csv`; this only records the binding that should already have existed.
- **No existing row touched or removed.**

## Verification
- `python framework/scripts/validate_registries.py` (canonical repo): the `ea_id_not_in_registry`
  findings for `1354:woodie-cci-dual-h1` and `1355:williams-vix-fix-fx-h4` are gone.
  853 pre-existing unrelated `ea_id_not_in_registry` issues remain for other ea_ids
  (e.g. 1627, 1628, 1630, 2245, 12552) — this is a wider registry-integrity backlog,
  **out of scope for this task** and not touched.
- Post-write duplicate scan over the full 4578-row file: no duplicate `ea_id`, no
  duplicate `slug` introduced by the two new rows (pre-existing unrelated duplicates
  elsewhere in the file are untouched and out of scope).
- `python tools/strategy_farm/farmctl.py health` (canonical repo, post-repair):
  `overall=FAIL` (5 fail / 8 warn / 30 ok) — every FAIL is a pre-existing, unrelated
  factory condition (stale `pump_task.lock` held by dead PID 6076, codex build lane
  idle, drained research source pool, 275 stranded Q02 pairs, 24 aged Q09_NEWS
  sealed-plan holds, 8 rows with artifact binding drift). None reference 1354/1355 or
  the registry file; none were introduced by this change.

## Follow-up (not actioned here, flagged for the next cycle)
- `pump_task.lock` is held by a dead PID (6076, age ~1220s) — pump cycles are
  currently no-op until the 1200s stale threshold self-clears. Worth a health re-check
  next cycle before assuming it is still wedged.
- The 853-issue `ea_id_not_in_registry` backlog suggests this "recovered legacy card,
  never registered" pattern is not unique to 1354/1355. A governed tool to backfill a
  registry row for a pre-numbered card (distinct from `reserve-ea-ids`, which only
  allocates fresh IDs) would close the structural gap this task's root-cause analysis
  identified, rather than requiring a one-off hand-repair each time it recurs.

## Files touched
- `framework/registry/ea_id_registry.csv` (canonical `C:\QM\repo`, branch
  `agents/board-advisor`, commit `5423f0837`) — 2 rows appended, nothing else changed.
