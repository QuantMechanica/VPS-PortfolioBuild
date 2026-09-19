# EA-ID Allocation Collision — 41479 (task `27ae17d6-beb8-416c-9c25-fade17603fe9`)

## What happened

Running `farmctl.py reserve-ea-ids --slug 100pips-daily-range-bracket-usdjpy-v2
--strategy-id e1222215-8e37-5add-90ba-87c1801691bf` (no `--start-after`) minted
`ea_id 41479` and wrote it into `framework/registry/ea_id_registry.csv`
(row appended 2026-09-19, `strategy_id=e1222215-8e37-5add-90ba-87c1801691bf`,
`status=active`, `owner=Research`).

That numeric ID was already filename-reserved by an existing, unrelated,
already-drafted card: `artifacts/cards_approved/QM5_41479_tail-pyramid-index-session-h1.md`
(H-PY, `QM-RESEARCH-2026-0007`, G0 APPROVED 2026-09-16 under
`OWNER_DIRECT_SESSION_DELEGATION`). That card's own text explains why the CSV
scan missed it: *"ea_id 41479 reserved by filename convention only (verified
free before writing); no registry row allocated ... the central allocator
runs later."* `QM5_41480` (`tail-pyramid-2lvl-index-session-h1`, the child of
41479) is in the same state — filename-reserved, no CSV row.

`farmctl reserve-ea-ids` only scans `framework/registry/ea_id_registry.csv`
for the next free integer; it does not cross-check `artifacts/cards_approved/`
or `framework/EAs/` filenames. Because 41479 and 41480 were reserved by
filename only, the allocator's CSV-only view considered 41479 free and handed
it to this unrelated second-chance retest card.

## Verification

- `grep -n "^41479," framework/registry/ea_id_registry.csv` — only this
  task's own erroneous row (added 2026-09-19) matched before retirement.
- `grep -rl "QM5_41479" artifacts/cards_approved framework/EAs` — matched
  `artifacts/cards_approved/QM5_41479_tail-pyramid-index-session-h1.md`,
  confirming the filename reservation predates and conflicts with this row.
- `grep -n "^41480," framework/registry/ea_id_registry.csv` — no match (41480
  is in the identical filename-only-reserved state; also avoided).
- Highest CSV-registered numeric ID besides the erroneous row: `41478`
  (`grimes-complex-pb-opt`, 2026-09-16). Highest `framework/EAs/QM5_*` numeric
  directory: `41478`.

## Fix

1. Retired the erroneous `41479` row via `farmctl.py retire-ea-ids --ea-id 41479
   --reason allocation_collision_filename_reserved_QM5_41479 --evidence
   docs/ops/evidence/2026-09-19_task_27ae17d6_qm5_11373_finalize/ea_id_41479_allocation_collision.md
   --apply --limit 1` (this file, written first so the evidence path exists
   before the retire call, per the tool's `--evidence` contract).
2. Re-minted with `--start-after 41480` to skip both filename-reserved-but-
   unregistered IDs (41479, 41480) and land clearly above them.

## Scope note

This is a narrow allocator gap (CSV-only free-slot scan vs. filename
reservations also being a valid claim), not a new hard rule or gate-criterion
change. No verdict, gate threshold, or candidate-pool definition was touched.
Reported as GRÜN-zone tool-evidence (infra repair that does not touch verdict
logic; test-first; rollback = the retire is itself reversible via a fresh
`reserve-ea-ids` row if ever needed) per the Stehende Vollmacht.
