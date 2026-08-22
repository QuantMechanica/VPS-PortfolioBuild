# Codex non-ready task triage - 2026-08-22

Status: complete audit artifact for router task `e8545314-b6e7-424d-8418-0de6f4045913`.

## Scope and method

The fixed intake was all 80 Codex rows named by the OWNER burn ticket: 64 `BLOCKED`, 14 `FAILED`, and 2 `OPS_FIX_REQUIRED`. Each row was checked against the live router database and, where applicable, later work items, canonical files, registry state, and existing evidence. The prior blocked-retest campaign covered 31 of these rows; a live comparison found 29 unchanged blockers and two allocator blockers cleared.

The intake cutoff is the task's 2026-08-22 08:24 UTC routing time. Task `6def383b` entered `BLOCKED` at 09:28 UTC from a separate governed build and is deliberately outside this fixed 80-row audit.

No pipeline verdict was inferred. No terminal was launched or interrupted, and no live-trading control was changed. Ambiguous rows were left in their existing non-ready state.

## Disposition

| Category | Count | Router action |
|---|---:|---|
| `entblockbar` | 2 | Two verified rows returned to `TODO` |
| `tot` | 28 | 14 already-final failures retained; 14 unequivocally obsolete/superseded rows marked `FAILED` |
| `echt_gated` | 34 | State retained pending named evidence gates |
| `OWNER_noetig` | 16 | State retained; decision template below |

Result-state snapshot after the audit action: `BLOCKED`=49, `FAILED`=28, `OPS_FIX_REQUIRED`=1, `TODO`=2.

Returned to TODO: 1f400c88 (QM5_11899), f3254781 (QM5_12946). Both now have active magic allocations; neither has a compiled artifact, so they return only to the governed build/review path.

Newly terminalized as obsolete or superseded: e9dc4e21, aa0b64d4, 09f78f65, 47666b69, fe1f8186, aa3b2125, b2bf2460, 7333402c, 813a5fe2, 68f6d518, b7cd20bf, 9743ea84, 53f6ee0f, 268d88ed. Their replacement/completion evidence is recorded per row in the CSV; no inconclusive row was terminalized.

## OWNER decision template

| Task | EA | Required decision / authority |
|---|---|---|
| e8f31c15 | QM5_1249 | Issue a dated card disposition: re-specify the edge using governed reproducible data and re-approve it, or reject/retire the card and close the EA identity. Development must not requeue the current card. |
| 534917fa | QM5_11214 | Resolve the approved/rejected card conflict with a dated G0 disposition. If APPROVED remains authoritative, hand the exact card to Development for a complete Q01 build and Codex review; otherwise retire the build task. Do not fabricate source from the directory name. |
| 7432e7ca | QM5_11212 | Resolve the approved/rejected card conflict with a dated G0 disposition. If APPROVED remains authoritative, hand the exact card to Development for a complete Q01 build and Codex review; otherwise retire the build task. Do not fabricate source from the directory name. |
| e388ce49 | QM5_11213 | Resolve the approved/rejected card conflict with a dated G0 disposition. If APPROVED remains authoritative, hand the exact card to Development for a complete Q01 build and Codex review; otherwise retire the build task. Do not fabricate source from the directory name. |
| e561d846 | QM5_12351 | Resolve the approved/rejected card conflict with a dated G0 disposition. If APPROVED remains authoritative, hand the exact card to Development for a complete Q01 build and Codex review; otherwise retire the build task. Do not fabricate source from the directory name. |
| 7a9aa79c | QM5_35007 | Issue a corrected, closed-form card or a terminal rejection; if corrected, require Development to rebuild and Codex to re-review before any downstream evidence can be relied upon. Do not promote the current build, and do not interrupt active backtests. |
| 9df810a8 | QM5_20179 | OWNER / Strategy Governance: repair or reject the incomplete, out-of-charter card before any rebuild. |
| b8886e40 | QM5_35006 | Issue a corrected, closed-form card or a terminal rejection; if corrected, require Development to rebuild and Codex to re-review before any downstream evidence can be relied upon. Do not promote the current build, and do not interrupt active backtests. |
| bc910727 | QM5_35002 | Issue a corrected, closed-form card or a terminal rejection; if corrected, require Development to rebuild and Codex to re-review before any downstream evidence can be relied upon. Do not promote the current build, and do not interrupt active backtests. |
| cf62861c | QM5_34006 | Issue a corrected, closed-form card or a terminal rejection; if corrected, require Development to rebuild and Codex to re-review before any downstream evidence can be relied upon. Do not promote the current build, and do not interrupt active backtests. |
| 1b00f708 | - | OWNER / Custom Symbol Governance: authorize isolated serial FTMO M1 bootstrap under shared-account constraints. |
| a3ba2414 | - | OWNER / Registry: authorize a safe legacy identity backfill or explicit retirement path; do not invent registry rows. |
| 61cfbaf3 | - | OWNER: provide a maintenance window and proven rollback path before any T5 tester rebuild. |
| 71eba21c | - | OWNER: approve a catalog-lifecycle design and require real-terminal preactivation acceptance; restoring archive files alone is insufficient. |
| 27143c34 | QM5_10001 | OWNER: decide the requeue-exclusion policy for QM5_10001 before any requeue. |
| 51c83e3f | QM5_11561 | OWNER: decide the low-frequency mission exception or exclusion before Q02. |

## Operational evidence

- The five live CPU samples during the audit were 100%, 97.76%, 98.65%, 100%, and 99.71%; the two capacity-bound Q02 rows therefore remain genuinely gated.
- The sparse custom-history repair remains `OPS_FIX_REQUIRED`: the archive-only repair was reverted after a 100% `BARS_ZERO` result. A catalog-lifecycle design plus real-terminal preactivation acceptance is still required.
- The Q09 rerun pilot remains pending, so the larger review-required backlog remains blocked.
- The governed compile queue already contains the 16 exact DL-089 wave rows; the obsolete shell batch was closed without creating duplicates.

## Verification

The companion CSV contains exactly 80 unique task IDs. Reconstructed source counts are `BLOCKED=64`, `FAILED=14`, and `OPS_FIX_REQUIRED=2`. Category counts sum to 80. The CSV is the per-row evidence and recommendation ledger.

Companion artifact: `docs/ops/evidence/2026-08-22_codex_nonready_task_triage.csv`.
