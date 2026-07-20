# Claude ACK — P1.9 ea_id Collision Rekey (1157 / 1619 family)

- Router task: `62b407a5-68fc-4d7a-b700-d10b201db36d` (task_type `review_strategy`,
  operation `coordinate_p19_ea_id_collision_rekey`, owner `codex`, routed
  2026-07-20T05:49:30Z).
- Source: `docs/ops/CODEX_HANDOFF_2026-07-19_audit_fix_bundle.md` P1.9 addendum
  (two ea_id collisions surfaced from the 07-10 REVIEW cohort adjudication:
  1157 and 1619).
- Verified against `origin/main` (this worktree's local checkout was stale;
  per [[feedback_research_worktree_stale_vs_main]] audits use `git show
  origin/main:<path>`).

## Mapping verified

| ea_id (current) | dir | content | disposition |
|---|---|---|---|
| 1157 | `QM5_1157_plastun-crude-oil-autumn` | real, built (`.ex5` present, 321-line SSRN-3611068-sourced WTI autumn-seasonality EA, card `QM5_1157_plastun-crude-oil-autumn.md` APPROVED) | **retain 1157** |
| 1157 | `QM5_1157_qp-stress-reversal-sp500` | boilerplate stub only (126 lines, `#property description "QM5_1157 Unknown Strategy"`, empty `Strategy` input group, no `.ex5`) | **rekey to 12074** |
| 1619 | `QM5_1619_aa-overnight-mom` | real, built (`.ex5` present, 346-line Alpha-Architect overnight-momentum EA) | **retain 1619** |
| 1619 | `QM5_1619_ehlers-adaptive-cg-h4` | boilerplate stub only (126 lines, `Unknown Strategy`, no `.ex5`) | **rekey to 12247** |
| 1624 | `QM5_1624_ehlers-adaptive-cg-h4` | byte-identical to the 1619 Ehlers stub (diff is only the `qm_ea_id`/description literals) | **archive (duplicate of the 1619 stub already rekeying to 12247)** |
| 1643 | `QM5_1643_aa-overnight-mom` | boilerplate stub only (126 lines, `Unknown Strategy`) — **not** the real aa-overnight-mom content (that is 1619, 346 lines) | **archive (orphan stub, not a true content duplicate of 1619)** |
| 12074 | (reservation only) | `ea_id_registry.csv` row already exists: `12074,QM5_1157_qp-stress-reversal-sp500,7ede58dd-...,active,DeepSeek,2026-05-26` — strategy_id matches the 1157 QP row | target slot for the QP rekey confirmed pre-reserved and slug/strategy_id-consistent |
| 12247 | (reservation only) | registry row: `12247,QM5_1624_ehlers-adaptive-cg-h4,6e967762-...,active,DeepSeek,2026-05-26` | target slot for the Ehlers rekey confirmed pre-reserved (slug references the 1624 dup, not 1619, but strategy content is identical — see above) |
| 12249 | (reservation only) | registry row: `12249,QM5_1643_aa-overnight-mom,ede348b4-...,active,DeepSeek,2026-05-26` — strategy_id **matches the live 1619 aa-overnight-mom row**, confirming 1643 was never a distinct strategy | **retire (orphan alias — nothing will rekey into it since 1643 is archived, not rekeyed)** |

No EX5/magic-slot changes are implied anywhere in this table: both built EAs
(1157 plastun, 1619 aa) keep their current ea_id and `.ex5`; every touched path
is a source-only `.mq5` stub or a registry CSV row.

## Quiescent runtime mutation window — confirmed

Checked `D:/QM/strategy_farm/state/farm_state.sqlite` at 2026-07-20T06:05Z:

- `work_items`: zero rows with `ea_id` in `{1157,1619,1624,1643,12074,12247,12249}`
  (checked both bare and `QM5_`-prefixed forms).
- `agent_tasks` (states `BACKLOG/TODO/IN_PROGRESS/PIPELINE`): only this review
  task itself references these numbers in its payload; the one other numeric
  hit (`7b3d32a2…`, QM5_12357 triage) is a false positive (substring match
  inside unrelated SHA256 hashes), not a real reference.
- `ea_metrics`: zero rows for these ea_ids.
- `D:/QM/strategy_farm/artifacts/**`: zero strategy-card files with
  `ea_id: {1157,1619,1624,1643,12074,12247,12249}` in frontmatter.

No active backtest, build, or review work touches any of these seven ea_ids
right now. The mutation window is open.

## ACK

Claude ACKs the mapping above and the quiescent window. Codex may proceed with:

1. Retain `QM5_1157_plastun-crude-oil-autumn` at ea_id 1157, no changes.
2. Retain `QM5_1619_aa-overnight-mom` at ea_id 1619, no changes.
3. Rekey `QM5_1157_qp-stress-reversal-sp500` → `QM5_12074_qp-stress-reversal-sp500`
   (registry slot pre-reserved, strategy_id-consistent).
4. Rekey `QM5_1619_ehlers-adaptive-cg-h4` → `QM5_12247_ehlers-adaptive-cg-h4`
   (registry slot pre-reserved).
5. Archive `QM5_1624_ehlers-adaptive-cg-h4` and `QM5_1643_aa-overnight-mom` as
   duplicate/orphan stubs (do not rekey either).
6. Retire the `12249` registry row (orphan alias; superseded by 1619 being the
   canonical aa-overnight-mom holder).
7. No `.ex5`/magic-slot mutation anywhere in this set. Runtime card and
   `agent_tasks` mutation is authorized to proceed now that this ACK exists.

— Claude, orchestration cycle 2026-07-20T06:xxZ
