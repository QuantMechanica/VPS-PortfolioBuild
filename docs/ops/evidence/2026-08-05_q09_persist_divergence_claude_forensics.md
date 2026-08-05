# Q09 persistence divergence — Claude independent forensics

Date: 2026-08-05 (~12:00–13:00Z)
Author: Claude (independent investigation, OWNER-directed dual forensics)
Cross-review counterpart: Codex SOL-MAX independent investigation (router ticket, see below)
Related: router tickets c0b64a33 (fix), 0805ad16 (round 6), evidence
`2026-08-05_q09_cell_failure_retry_stability.md`

## 1. Symptom and timeline

Round-6 Q09_NEWS row `4984cca7-e1a3-49a8-a066-066ac51eb063` (QM5_11422/USDCAD.DWX,
append-only rerun-of 3c1fea0e):

- T8 attempt (spawned 04:46:27Z): transient cell failures + the (since fixed)
  sidecar immutability crash.
- T2 attempt (spawned 08:55:47Z): completed cells, then died at persist:
  `q09_news_schema.SchemaError: Q09 persistence divergence:
  {"divergent_fields":["evidence_sha256","report_sha256"],
  "identity":"97832746b7c45318588ea7ee41e4a43303e951c796164b8a6b50f0e5deb4ac16",
  "row_kind":"q09_news_cells"}`
  (log `D:/QM/strategy_farm/logs/work_item_4984cca7-….log`).
- T10 attempt (spawned 10:27:16Z, module state c8ee2dabe): finished the remaining
  cells; its persist would have died at the same wall.
- A worker respawn after fix commit `2a0a0186f` (12:31:50Z +0200) took the fast
  path over the 40 existing receipts and **persisted successfully at 12:40:16Z**
  (`sidecar.status=RECORDED`, row terminal `done/REVIEW_REQUIRED` — a
  substantive A/B verdict, not an infrastructure failure).

## 2. Source-level root cause

`c8ee2dabe` (2026-08-04 20:10Z, "restart-idempotent persistence") built
`cell_content` as the full 17-field dict — including `evidence_sha256`
(SHA-256 of `cell_evidence.json`) and `report_sha256` (SHA-256 of
`report_manifest.json`) — and passed it wholesale to
`_assert_persistence_match(existing_cell, cell_content, row_kind="q09_news_cells")`.
Verified via `git show c8ee2dabe:tools/strategy_farm/q09_news_schema.py`.

Cell run identities are **global sealed experiment identities** (by design,
per the c8ee2dabe docstring). Round-4 row `6a305d8a` partially persisted cells
before dying; any later append-only rerun of the same sealed plan re-encounters
those rows. Because the two compared hashes cover files that necessarily
differ per execution (see §3), **every cross-round rerun of a
partially-persisted sealed plan deterministically died at persist** — the
resume path could only ever succeed within the same tree with bit-identical
artifacts.

## 3. Primary-evidence proof: divergence is provenance-only

Cell `control_off__m0__c0__s42`, run identity `97832746…` — present in both
trees (round-4 `6a305d8a`, round-6 `4984cca7`):

- `cell_evidence.json` deep-diff: **exactly 1 divergent leaf** —
  `report_sha256`. All identities, seeds, and metrics byte-identical.
- `report_manifest.json` deep-diff: **27 divergent leaves, all provenance**:
  - absolute artifact paths (they embed the work-item UUID → guaranteed
    divergence across rounds);
  - per-window artifact hashes of timestamp-bearing execution files
    (`report.htm`, `summary.json`, `run_smoke.log`, `logger_sample.jsonl`);
  - `news_calendar.age_hours` (59 vs 43 — wall-clock at run time).
- Economic fields of the divergent `summary.json` files, all three windows:
  - selection: net 8997.81, PF 1.16, 132 trades — **MATCH**
  - holdout: net 8793.84, PF 1.74, 48 trades — **MATCH**
  - full: net 17791.65, PF 1.27, 180 trades — **MATCH**
- Seed stability across the whole round-6 matrix: all 5 seeds per
  configuration produce identical metrics (e.g. CONTROL_OFF full:
  net_r 17.79165 / PF 1.27 / DD 12.28 on every seed).

**Conclusion:** economics determinism holds across terminals (T3 round 4 vs
T2/T10 round 6) and across rounds. The defect was purely comparison scope:
per-execution provenance was treated as identity. No evidence damage; the
fail-closed refusal was the guard working as designed on a mis-scoped field
set.

## 4. Fix assessment (commit 2a0a0186f, codex, ticket c0b64a33)

- `_CELL_DETERMINISTIC_FIELDS` (14 fields: identities, seeds, arms, modes,
  setfile hash, all three metrics JSONs, seed-stability flag, flat-at-event
  receipt hash) — exact-match fail-closed retained; true deterministic
  divergence still raises (genuine non-determinism alarm preserved).
- Per-execution provenance recorded append-only in new
  `q09_news_cell_occurrences` (immutable via BEFORE UPDATE/DELETE triggers,
  insert-validation trigger), keyed by occurrence identity.
- New view `q09_news_cells_by_work_item` restores per-work-item cell
  attribution for readers (Q10 dependency gate seed counts,
  candidate_qualifications trigger, `ftmo_q09_admission.py`) — necessary
  because a reused canonical cell row keeps the FIRST work item's id.
- Production proof: the 12:40:16Z persist of a cross-round rerun succeeded and
  produced a canonical adjudication aggregate.

## 5. Residual questions (input for Codex cross-review)

1. Transient cell failures (3 cells: holdout/full `run_smoke exited with
   code 1` on T2/T8 attempts, all clean on re-run): separate class — is it the
   window-succession wait interacting with something else, or plain tester
   flake? Needs its own root-cause pass (receipts exist; failure sidecars
   preserved).
2. Sanity invariant: `POLICY_ON/OFF/DXZ` ≡ CONTROL_OFF byte-equal metrics —
   confirms DXZ minimum enforcement is a no-op for this EA. Should the
   adjudicator record this invariant check explicitly?
3. Migration idempotency: `CREATE TABLE/VIEW/TRIGGER IF NOT EXISTS` on the
   live DB — verify first fresh-spawn migration ran exactly once and old
   `q09_news_cells.q09_news_work_item_id` consumers are all view-migrated
   (grep for any remaining direct reader).
4. Attempt-ceiling interaction: the divergence class consumed two attempts
   (T2, T10-would-have) before the fix landed; confirm the ceiling semantics
   did not mask any other failure.

## 6. Verdict

Root cause CONFIRMED at source and primary-evidence level: c8ee2dabe's
verify-or-resume compared per-execution provenance hashes as identity;
cross-round reruns therefore always failed at persist. Economic determinism
across rounds/terminals is proven intact. Fix 2a0a0186f implements the correct
deterministic/provenance split with an immutable occurrence ledger and is
production-proven. Formal code review of the fix follows in the c0b64a33
review; independent Codex forensics + mutual cross-review per OWNER directive
2026-08-05.

## 7. Cross-review outcome (addendum, post Codex Phase A/B)

Codex's independent forensics
(`2026-08-05_q09_persist_divergence_codex_forensics.md`, sealed before reading
this document) reached the identical root cause and fix verdict. I accept all
four factual corrections to my narrative:

1. **Ownership correction (material, verified live):** the reused canonical
   cells that triggered the divergence were owned by round-3 row `fd88398c`
   (19 cells; its `REVIEW_REQUIRED` adjudication legitimately persisted), NOT
   a partial persist of round-4 `6a305d8a` — that transaction rolled back
   atomically (`BEGIN IMMEDIATE`) and owns 0 rows. Verified in the live DB:
   19 `fd88398c` + 21 `4984cca7`, occurrences 40×`4984cca7`.
2. The immutable-sidecar collision belonged to the T5 spawn (08:21:47Z), not
   T8; my §1 compressed two retry episodes.
3. Timestamp notation: `12:31:50Z` (not "Z +0200").
4. §3 quoted cash net values from `summary.json`; receipts carry normalized
   net R — same economics at the expected scale.

Codex Phase A additionally closed my residual questions: live migration proven
idempotent (double `ensure_schema` fingerprint), reader migration complete
(view-based, no stray direct work-item-scoped reader), retry ceilings bounded
(generic 3 / transient 6; the row ended at 1/4), SQLite integrity ok. One
maintenance note adopted: 57 pre-existing legacy foreign-key violations in
non-Q09 tables (24 task rows, 33 work-item rows) — untouched by this incident,
parked for the maintenance stream. Joint verdict stands:
**ROOT CAUSE CONFIRMED / FIX COMPLETE / NO EVIDENCE DAMAGE.**
