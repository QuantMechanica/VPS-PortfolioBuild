# Registry ea_id collision rekey — Claude ACK (P1.9 cohort: 1157/1619 family)

Task: `agent_tasks` id `62b407a5-68fc-4d7a-b700-d10b201db36d` (review_strategy,
routed 2026-07-20T05:49:30Z). Operation: `coordinate_p19_ea_id_collision_rekey`,
owner Codex. Origin: `docs/ops/CODEX_HANDOFF_2026-07-19_audit_fix_bundle.md`
item 9 + P1.9 addendum (07-10 REVIEW cohort collisions, same class as the
already-landed ea_id 12784 fix).

## Codex's proposed plan (as routed)

> Retain built 1157 plastun and 1619 aa, rekey source-only QP to reserved
> 12074 and earlier Ehlers to reserved 12247, archive duplicates 1624/1643,
> retire orphan alias 12249; no EX5/magic changes; runtime cards+agent_tasks
> only after ACK.

## Independent verification (evidence, not trust)

Cross-checked `framework/registry/ea_id_registry.csv`,
`framework/registry/magic_numbers.csv`, `framework/EAs/` directory contents,
`D:/QM/strategy_farm/artifacts/cards_approved/`, and the `work_items` /
`agent_tasks` tables in `D:/QM/strategy_farm/state/farm_state.sqlite` directly
(python `csv.DictReader` + sqlite3, not naive text scans).

| ea_id (current) | slug | registry row | magic_numbers.csv | EA dir | card |
|---|---|---|---|---|---|
| 1157 | `plastun-crude-oil-autumn` | **none** (no registry row today) | 1 row, `status=reserved`, magic 11570000 (Claude, 2026-06-18) | `QM5_1157_plastun-crude-oil-autumn/` (.mq5 only) | `QM5_1157_plastun-crude-oil-autumn.md` | KEEP at 1157 |
| 1157 | `qp-stress-reversal-sp500` | active, created 2026-05-17, strategy_id `7ede58dd-...` | none | `QM5_1157_qp-stress-reversal-sp500/` (.mq5 only) | `QM5_1157_qp-stress-reversal-sp500.md` | → REKEY to 12074 |
| 1619 | `aa-overnight-mom` | active, created 2026-05-19, strategy_id `ede348b4-...` | **5 active rows** (16190000-16190004, Development, 2026-05-19) | `QM5_1619_aa-overnight-mom/` | (pre-dates card scheme; none found) | KEEP at 1619 |
| 1619 | `ehlers-adaptive-cg-h4` | **none at 1619** | none | `QM5_1619_ehlers-adaptive-cg-h4/` (.mq5 only) | `QM5_1619_ehlers-adaptive-cg-h4.md` | → REKEY to 12247 ("earlier Ehlers") |
| 1624 | `ehlers-adaptive-cg-h4` | **none at 1624** | none | `QM5_1624_ehlers-adaptive-cg-h4/` (.mq5 only, byte-identical strategy) | `QM5_1624_ehlers-adaptive-cg-h4.md` | → ARCHIVE (duplicate of the 1619 copy) |
| 1643 | `aa-overnight-mom` | **none at 1643** | none | `QM5_1643_aa-overnight-mom/` (.mq5 only, duplicate strategy) | `QM5_1643_aa-overnight-mom.md` | → ARCHIVE (duplicate of the 1619 keeper) |
| 12074 | `QM5_1157_qp-stress-reversal-sp500` (malformed slug) | active stub, DeepSeek, 2026-05-26, same strategy_id as 1157/qp | none | none yet | none yet | rename slug to bare `qp-stress-reversal-sp500`; move dir here |
| 12247 | `QM5_1624_ehlers-adaptive-cg-h4` (malformed slug) | active stub, DeepSeek, 2026-05-26, own strategy_id `6e967762-...` | none | none yet | none yet | rename slug to bare `ehlers-adaptive-cg-h4`; move the 1619 dir here |
| 12249 | `QM5_1643_aa-overnight-mom` (malformed slug) | active stub, DeepSeek, 2026-05-26, same strategy_id as 1619/aa | none | none | none | RETIRE (registry row only — orphan alias of the 1619 keeper, no dir exists) |

Root cause read: a 2026-05-26 (owner `DeepSeek`) rekey attempt reserved
12074/12247/12249 but wrote the slug field as `QM5_<old_id>_<slug>` instead of
a bare slug, and never actually moved the directories or retired the old
registry rows — leaving both the malformed stubs and the original colliding
rows live simultaneously. Codex's plan completes that abandoned rekey
correctly.

**Confirms all payload claims:**
- "1157 plastun" and "1619 aa" are the correct keepers — plastun has the only
  magic-number claim at 1157 (reserved), aa-overnight-mom has 5 *active*
  magics at 1619 — clearly the live-built identity in both cases.
- "source-only QP" / "earlier Ehlers" (the 1619 copy, not the 1624 duplicate)
  — verified: neither has any magic_numbers.csv row, `.mq5` source only, no
  `.ex5`.
- **No EX5/magic changes required** — none of the touched rows (1157/qp,
  1619/ehlers, 1624, 1643, 12074, 12247, 12249) have any magic_numbers.csv
  entry today, so this is pure `ea_id_registry.csv` + directory + card
  metadata hygiene. No resolver regen, no compile, no dirty-guard interaction.
- **Zero pipeline exposure** — `work_items` and `agent_tasks` have no rows
  referencing any of `QM5_1157_qp-stress-reversal-sp500`,
  `QM5_1619_ehlers-adaptive-cg-h4`, `QM5_1624_*`, `QM5_1643_*`, or the 12074/
  12247/12249 stubs (checked by exact `QM5_<id>_` prefix match, not SQL
  `LIKE` — `_` is a single-char wildcard in SQLite LIKE and false-matched
  `QM5_1157_%` against `QM5_11577`/`QM5_11578` on the first pass).

## ACK

**Approved as proposed.** End state:
- 1157 → `plastun-crude-oil-autumn` only (unchanged)
- 1619 → `aa-overnight-mom` only (unchanged)
- 12074 → `qp-stress-reversal-sp500` (bare slug; dir moved from `QM5_1157_qp-stress-reversal-sp500/`)
- 12247 → `ehlers-adaptive-cg-h4` (bare slug; dir moved from `QM5_1619_ehlers-adaptive-cg-h4/`)
- `QM5_1624_ehlers-adaptive-cg-h4/` and `QM5_1643_aa-overnight-mom/` → archived (e.g. `_obsolete_` prefix per the resolver's existing skip convention), registry rows for 1157/qp and 1619(none)/1624/1643 retired, not deleted (append-only audit trail convention)
- 12249 registry row → `status=retired`, no dir action needed (never existed)
- Matching moves for the two `cards_approved` duplicate files (1624, 1643) → archived alongside their dirs; `cards_approved` files for 1157/qp and 1619/ehlers renamed to the 12074/12247 ids

## Quiescent runtime mutation window

Scope is `framework/registry/ea_id_registry.csv`, EA directory
renames/archival, and the 5 matching `cards_approved` files — no
`magic_numbers.csv`, no `.ex5`, no `QM_MagicResolver.mqh` regen. Risk is a
torn read of `ea_id_registry.csv` or a stale card path if the router/pump is
mid-cycle while Codex edits. None of the touched ea_ids have any live
`work_items` (verified above), so there is no in-flight backtest to race.

Before mutating: confirm no concurrent `agent_router.py run` /
`route-many` / `farmctl.py pump` process is active (process list or the pump
scheduled task's last-run timestamp), then do the CSV/dir/card edits in one
pass. After: re-`grep` `^1157,`, `^1619,`, `^1624,`, `^1643,`, `^12074,`,
`^12247,`, `^12249,` on `ea_id_registry.csv` to confirm exactly the intended
one-active-row-per-id end state (per the standing duplicate-build-dispatch
lesson), and re-run `farmctl.py health` to confirm `ea_id_slug_uniqueness`
drops from 8 to 7 tracked WARN rows (this cohort is 3 of today's 8; the
remaining 5 — 1158, 1258, 1492, 9197/9198, 11277, 11857 — are a separate,
already-diagnosed-lower-severity orphan-row class per
`iv_registry_dual_id_rekey_plan.md`, out of scope for this task).

No T_Live, no AutoTrading, no magic-number formula change, no live-trading
exposure. Codex may proceed.
