# Evidence: Second-Chance Wave-2 Finalization — Task `27ae17d6-beb8-416c-9c25-fade17603fe9`

- **Task ID:** `27ae17d6-beb8-416c-9c25-fade17603fe9`
- **Agent:** `claude`
- **Task Type:** `research_strategy` (`kind: second_chance_retest`, `lineage: NEW`)
- **Origin EA ID:** `QM5_11373` (`100pips-daily-range-bracket-usdjpy`) — row remains immutable, read-only evidence; never reopened.
- **New EA identity:** `QM5_41481` (`100pips-daily-range-bracket-usdjpy-v3`)
- **Strategy Card:** `D:/QM/strategy_farm/artifacts/cards_review/QM5_41481_100pips-daily-range-bracket-usdjpy-v3.md`
- **Verdict:** `REVIEW_READY` (handed off in router state `REVIEW`; G0 human/Codex approval still pending — not self-approved, not moved to `APPROVED`/`PIPELINE`).

## 1. Starting state

The task's prior review cycle (closed `2026-09-18T00:54:03Z`) returned `RECYCLE`:
`"prescreen REJECT - RISK_CONTRACT_MISSING (per-slot magic is prose-only, needs
strategy_risk_contract.v1) plus missing FALSIFICATION,Q08_Q11_RISK. Also pin
MAGIC_BASE = ea_id*10000 explicitly."` The task was requeued to `TODO` on
`2026-09-19T09:01:45Z` (`recycle_requeue`) and routed back to `claude` at
`2026-09-19T10:42:13Z`.

Between the RECYCLE verdict and this run, a separate task (`80846cbb`, per its
own evidence directory `docs/ops/evidence/2026-09-18_second_chance_wave3_adjudication/`)
had already revised the draft at
`D:/QM/strategy_farm/artifacts/cards_review/PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md`,
adding `## Falsification / Kill Criteria` and `## Q08 / Q11 Crisis & News Risk`
sections and fixing the risk-mechanism negation wording. This run independently
re-verified that fix was real (not just claimed) before building on it — see
§2.

## 2. Verification of the inherited content fix

Ran the actual gate tool, read-only (`--card`, no `--apply`), against the
pending draft before touching anything:

```
python tools/strategy_farm/card_intake_prescreen.py \
  --card "D:/QM/strategy_farm/artifacts/cards_review/PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md"
```

Result: `verdict=KEEP`, `missing_sections=[]`, `reasons=[]` (only a
`NEAR_DUPLICATE:QM5_10001_ff-static-fib-open.md:score=1.0000` warning, which is
non-blocking and already addressed in-card by an explicit differentiation
paragraph against `QM5_10001`'s mechanically distinct rules). Confirmed the
RECYCLE reasons (`RISK_CONTRACT_MISSING`, `FALSIFICATION`, `Q08_Q11_RISK`) no
longer fire.

## 3. Minting the new EA identity (this run's own work)

Per the task payload action (`"mint NEW ea-id via farmctl allocation"`) and
`required_capabilities: [research, strategy]`:

1. `farmctl reserve-ea-ids --slug 100pips-daily-range-bracket-usdjpy-v2
   --strategy-id e1222215-8e37-5add-90ba-87c1801691bf` minted `41479` — but
   that ID collided with the filename-only-reserved (never CSV-registered)
   `artifacts/cards_approved/QM5_41479_tail-pyramid-index-session-h1.md`. Full
   root cause and fix in
   `docs/ops/evidence/2026-09-19_task_27ae17d6_qm5_11373_finalize/ea_id_41479_allocation_collision.md`.
2. Retired the erroneous row: `farmctl retire-ea-ids --ea-id 41479 --reason
   allocation_collision_filename_reserved_QM5_41479 --evidence <the collision
   doc above> --apply --limit 1` — `retired: true`,
   `registry_status_counts` retired count 802 → 803, no magic rows touched
   (`planned_magic_row_count: 0`).
3. Re-minted above both filename-reserved neighbours: `farmctl reserve-ea-ids
   --slug 100pips-daily-range-bracket-usdjpy-v3 --strategy-id
   e1222215-8e37-5add-90ba-87c1801691bf --start-after 41480` → `ea_id 41481`.
   Verified no prior filename references to `QM5_41481` anywhere in
   `artifacts/`, `framework/`, or `docs/` before use.

## 4. Card finalization

Wrote
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41481_100pips-daily-range-bracket-usdjpy-v3.md`
(carrying forward all mechanics, R1-R4, Falsification and Q08/Q11 content
unchanged from the verified pending draft) with the identity fields filled in:
- `ea_id: QM5_41481`, `slug: 100pips-daily-range-bracket-usdjpy-v3`.
- `MAGIC_BASE` pinned to the concrete allocated value `414810000` (=
  `41481 * 10000`) everywhere it appears (per-slot magics `414810001` /
  `414810002` / `414810003`), replacing the formula-only placeholder the
  RECYCLE verdict flagged as insufficiently explicit.
- `revision_note` and `## Pipeline History` updated with the full mint/retire/
  re-mint trail.
- Deleted the superseded `PENDING_27AE17D6_...` draft file (D: runtime
  artifact, not tracked in git) so exactly one current draft exists for this
  lineage.

Re-ran the prescreen tool against the finalized file:

```
python tools/strategy_farm/card_intake_prescreen.py \
  --card "D:/QM/strategy_farm/artifacts/cards_review/QM5_41481_100pips-daily-range-bracket-usdjpy-v3.md"
```

Result: `verdict=KEEP`, `missing_sections=[]`, `reasons=[]`, same
non-blocking `NEAR_DUPLICATE` warning as before (unchanged mechanics).

## 5. Scope discipline

- No gate threshold, contract criterion, verdict, trade stream, or
  candidate-pool definition was touched (ROT zone untouched).
- The registry retire/re-mint is a GRÜN-zone infra action: existing tool
  (`farmctl reserve-ea-ids` / `retire-ea-ids`), unchanged criteria, durable
  evidence for the transition, narrow blast radius (one erroneous CSV row),
  reversible.
- Card remains `g0_status: DRAFT`; this task does not self-approve, does not
  set `APPROVED`/`PIPELINE`, and does not touch `QM5_11373`'s row.
- Repo-side changes (registry CSV + this evidence directory) are committed on
  `agents/board-advisor` in `C:/QM/repo` with explicit pathspecs, per this
  task's hard rules; `main` and `C:/QM/worktrees/cto_main` were not touched.

## 6. Files changed

- `framework/registry/ea_id_registry.csv` — one row retired (`41479`), one row
  added (`41481`).
- `docs/ops/evidence/2026-09-19_task_27ae17d6_qm5_11373_finalize/ea_id_41479_allocation_collision.md` (new).
- `docs/ops/evidence/2026-09-19_task_27ae17d6_qm5_11373_finalize/evidence_task_27ae17d6_qm5_11373_second_chance_finalize.md` (new, this file).
- `docs/ops/evidence/2026-09-19_ea_id_retirement_apply_20260919T111927Z_a890698e.json` (tool-generated retirement receipt).
- `D:/QM/strategy_farm/artifacts/cards_review/QM5_41481_100pips-daily-range-bracket-usdjpy-v3.md` (new, runtime artifact, not tracked in git).
- `D:/QM/strategy_farm/artifacts/cards_review/PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md` (deleted, runtime artifact, not tracked in git).
