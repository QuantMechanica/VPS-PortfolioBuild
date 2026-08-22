# EXECUTION_CONTRACT Requal-Flag Coverage — 7 Live-EAs — 2026-08-22

Router task `8e334e3b-4d2b-4705-a32c-77b0e8e929b8` (claude, IN_PROGRESS). **READ-ONLY** against
`T_Live` — no deployed artifact, preset, or AutoTrading state touched.

## Question

`2026-08-22_tlive_ea_warn_classification.md` Finding 2: 7 live EAs self-declare
`EXECUTION_CONTRACT.declaration=DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED` in their live logs
(10911, 10919, 10939, 11132, 11421, 12567, 12989). Are they already inside an open
requalification item, or does each need one created?

## Answer: all 7 are covered by one existing programme — no new requal item needed

All 7 are inside **DL-089** (`decisions/DL-089_live_book_full_chain_requalification.md`,
OWNER-ratified 2026-08-21), which puts all 21 live EAs / 24 sleeves of the current DXZ book
through rebuild → Q02…Q10 → Q14…Q16 → Q11 before the next book ceremony. There is no separate
per-EA "legacy book policy requal" item to reconcile against — DL-089 *is* the item, and it
already names these EAs as in scope. What differs between the 7 is only how far each has moved
through DL-089 Wave 1 (rebuild), not whether it is covered.

| EA | Symbol(s) | Flag source | DL-089 Wave-1 status | Open item |
|---|---|---|---|---|
| QM5_10911 | GDAXI | `EXECUTION_CONTRACT` self-decl. | **Rebuilt + compiled PASS, Q02 enqueued** — batch 1 (`4b88e5bf`, PASSED/APPROVED 2026-08-21) | none — already progressing through Q02 (`096636c3-ba56-4643-a5cd-85d16c41eb6f`) |
| QM5_10919 | XTIUSD | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** Named individually as the EA whose `compile_one` 120s timeout blocked batch 2 (`b2bf2460`, BLOCKED 2026-08-21) | none new — carried by batch-2 continuation, gated on COMPILE_EA rollout (see below) |
| QM5_10939 | GBPUSD | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** In the 16-EA `remaining_ea_ids` list of batch 1's manifest; batch 2 attempt BLOCKED before reaching it | same as above |
| QM5_11132 | SP500 | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** Same remaining-16 list, same block | same as above |
| QM5_11421 | AUDUSD, EURUSD | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** Same remaining-16 list, same block | same as above |
| QM5_12567 | XAUUSD (+XNGUSD rescue row) | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** Same remaining-16 list, same block | same as above |
| QM5_12989 | (no Q11/Q12 portfolio_candidates row found — pre-DL-089 sleeve) | `EXECUTION_CONTRACT` self-decl. | **Not yet rebuilt.** Same remaining-16 list, same block | same as above |

## The one open item behind the 6 not-yet-rebuilt EAs

Chain, all verified against `farm_state.sqlite` `agent_tasks` and evidence docs:

1. `4b88e5bf` (batch 1, PASSED) — rebuilt 5/21 (incl. 10911). 16 remain, listed by ID in
   `2026-08-21_dl089_wave1_batch1_manifest.json`.
2. `b2bf2460` (batch 2, **BLOCKED** 2026-08-21T17:20) — attempted the remaining 16, hit a
   `compile_one` 120s timeout on QM5_10919 (live-factory compile contention), produced zero
   fresh EX5s. OWNER decision recorded in the verdict: compiling belongs in the pipeline, not
   an ad-hoc agent-lane call — unblock via a governed `COMPILE_EA` phase.
3. `251b9724` (**APPROVED** 2026-08-21T20:05) — built that `COMPILE_EA` phase. Held 82 rows
   under `COMPILE_EA_WORKER_ROLLOUT_PENDING` pending worker rollout. Note: that 82-row manifest
   is the *source-only-EA drain* cohort (mq5 present, ex5 absent, never built) — a different,
   larger population than DL-089's live EAs (which already have a deployed EX5). None of the 6
   remaining flagged EAs appear in it; confirmed by direct query (`work_items` has zero
   `COMPILE_EA` rows for QM5_10919/10939/11132/11421/12567/12989 as of this pass).
4. `1fb9943f` (rollout, **IN_PROGRESS**, latest close BLOCKED 2026-08-22) — released the
   rollout hold, then discovered `repair.py::R11_pending_unclaimable_work_item` was mass-
   invalidating the freshly-released `COMPILE_EA` rows (91/92 → `verdict=INVALID`,
   `ex5_missing`) because R11 asserted backtest preconditions against a phase whose entire job
   is to produce the missing EX5. Fixed in-task; 90 invalidated rows revived via `83be33f3`
   (**APPROVED**); claim-rank ordering committed; still owes a live-contention proof before the
   next governed wave-release. Next in the Codex dispatch sequence after `cbd73e04`
   (**APPROVED**).
5. **DL-089 Wave-1 batch-2 continuation for the 16 remaining EAs (incl. our 6) has not yet been
   re-dispatched** as its own router task — it was explicitly named as the next step in
   `251b9724`'s verdict but is currently sequenced behind stabilizing the shared `COMPILE_EA`
   consumer it depends on.

## Bottom line for OWNER

No coverage gap and no new requal item to create: all 7 self-flagging EAs sit inside DL-089,
which is the OWNER-ratified answer to exactly this flag. 1 of 7 (10911) is already moving
through Q02. The other 6 are blocked on shared compile-pipeline infrastructure that is actively
being repaired (chain above), not on a missing decision or a missing queue entry. Recommended
next step, once `COMPILE_EA` clears its live-contention proof: re-dispatch DL-089 Wave-1 batch 2
for the 16-EA remainder (a router `ops_issue`, GRÜN — re-running an existing programme with
unchanged criteria) rather than opening 6 separate per-EA items.

## Sources

- `docs/ops/evidence/2026-08-22_tlive_ea_warn_classification.md` / `.csv` (Finding 2, trigger)
- `decisions/DL-089_live_book_full_chain_requalification.md`
- `docs/ops/evidence/2026-08-21_dl089_wave1_batch1.md` /
  `2026-08-21_dl089_wave1_batch1_manifest.json`
- `docs/ops/evidence/2026-08-21_dl089_wave1_batch2_partial.md`
- `docs/ops/evidence/2026-08-21_compile_ea_pipeline_251b9724.md`
- `docs/ops/evidence/2026-08-22_compile_ea_worker_rollout_1fb9943f.md`
- `farm_state.sqlite`: `agent_tasks` (4b88e5bf, b2bf2460, 251b9724, 1fb9943f, 83be33f3,
  cbd73e04), `work_items` (COMPILE_EA rows), `portfolio_candidates`,
  `framework/registry/ea_id_registry.csv` (all 7 confirmed `status=active`)
