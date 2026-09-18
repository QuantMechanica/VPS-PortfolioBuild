# DL-089 zombie-declaration disposition — governed apply — 2026-09-18

**Task:** `2e354912-767c-4405-be5d-7b5f70b2e110` ("Governed DL-089 apply of the
57 Q12 + 2 Q14 SUPERSEDED_DUPLICATE_DECLARATION dispositions"), follow-up of
review task `b093f809-b5bb-404a-8a3d-58a210c78ff8` (APPROVED 2026-09-18
00:54Z: *"root cause quoted ... dry-run plan for 57 Q12 + 2 Q14. APPLY still
owed - follow-up ticket required."*).

**Plan applied:**
`docs/ops/evidence/2026-09-17_dl089_zombie_declaration_disposition_plan.json`
— plan SHA-256 `58fb570c9f4bb7667d3b099d224406066616fae1eb9b3bbb8416202c577e92da`
(matches the task payload exactly; content SHA-256
`ec051a6a42b41d77c8bef18ebccdd7657bdac8a9c9c0cebb313f40feb9c60a39` re-verified
against the recomputed canonical content bytes before any write).

## Tool

`tools/strategy_farm/apply_dl089_zombie_declaration_dispositions.py` (new),
modeled on the established pattern (`apply_q09_retire2_dispositions.py`,
`apply_q10_identity_mismatch_supersede.py`) that the review ticket's own
`evidence` list named as the required shape: hashed plan, online SQLite
backup, `FactoryMutationLock`, one disposition row + one
`work_item_supersedes` edge per entry, never editing or deleting the source
row.

- `validate` mode: read-only, re-checks all 59 plan entries against the live
  database and reports before/after pending counts without writing.
- `apply` mode: re-validates every entry again inside one
  `FactoryMutationLock` + `BEGIN IMMEDIATE` transaction, after one online
  backup; aborts (rollback) on any identity drift, pre-existing disposition
  collision, or count mismatch.

## Finding during validation: 3 of 59 entries were already resolved

`validate` (before any write) found that 3 of the 59 plan entries already
carry a `work_item_supersedes` edge recorded 2026-09-02 — **before** the
2026-09-17 plan was even generated — by an unrelated, independent
disposition (`docs/ops/evidence/2026-09-02_dl089_q12_binding_reconciliation.md`,
`source_encoding=operator:record`, reasons `"...ablation-sourced duplicate
must not rebind the shared program"` and `orphan_q13_q14_chain_minted_from_generic_q12_pass`):

| Source work item | Program | Pre-existing supersession recorded |
|---|---|---|
| `2dad5730-30ed-5ab1-ace1-d5db4ede60db` | DL089_QM5_10706_GBPUSD_DWX_2019_2025 | 2026-09-02T12:56:42Z |
| `64604d7a-9bbe-561c-a70c-44667cdb2e12` | DL089_QM5_10706_GBPUSD_DWX_2019_2025 (Q14) | 2026-09-02T11:46:42Z |
| `f81a14df-14ef-5f15-b808-d19b8c13348c` | DL089_QM5_11421_EURUSD_DWX_2019_2025 (Q14) | 2026-09-02T11:04:00Z |

The plan-generation query (`session_tools/plan_dl089_zombie_declarations_0917.py`)
selects pending Q12/Q14 rows without excluding rows that already carry an
(unrelated) supersession edge, so these 3 slipped into the 09-17 dry-run
scope even though they were already correctly excluded from the
pending/claimable pool. Per the append-only hard limit ("never rewrite or
delete existing rows or verdicts"), the apply tool treats a supersession
recorded strictly before plan generation as **already resolved** and skips
it — writing a second, redundant supersession edge on top of an
independently-valid one would misrepresent provenance. Both affected Q14
rows are exactly the plan's 2 Q14 entries, which is why 0 Q14 dispositions
were written (they were already excluded from the pending board/cockpit
count, `pending_q14_all=0` before this apply too) and only the Q12 side
(56 of 57) required a new disposition.

## Apply result

- **56 disposition work items** inserted (`kind=disposition`,
  `status=failed`, `verdict=SUPERSEDED_DUPLICATE_DECLARATION`,
  `verdict_taxonomy=governance`, `sh3_enforced=0` — a governance record, not
  an economic result).
- **56 `work_item_supersedes` edges** inserted, `source_encoding=router:dl089-zombie-disposition-apply:2e354912-767c-4405-be5d-7b5f70b2e110`.
- **0 source rows edited or deleted** — all 56 (and the 3 pre-resolved)
  remain `status=pending`, `verdict=NULL`, byte-identical to their
  pre-apply identity (re-verified inside the transaction against the
  plan's `source_identity` hash before any insert).
- Online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_dl089_zombie_disposition_20260918T013718Z_764393e0.sqlite`
  (sha256 `4aa8a4e554f1a4ef140fc60eeece5e67bd5af8bd9b3be8181fb1473e36f55503`).
- `PRAGMA quick_check` = `ok`, `PRAGMA integrity_check` = `ok` (re-verified
  independently, read-only, after commit).
- Receipt: `D:/QM/reports/dl089_zombie_disposition/apply_receipt_2e354912.json`
  (receipt sha256 `f59c6fbd2113da203eb0bf6182969d38d668087b09895e07653ba9bd40761642`).

## Board/cockpit count reconciliation (independently re-queried post-apply)

| Surface/count | Before (live, at apply time) | After (live, verified) | Plan's reviewed "after" |
|---|---:|---:|---:|
| Pending Q12, ticket scope | 72 | 16 | 16 |
| Pending Q12, all live rows | 105 | 49 | 49 |
| Pending Q14, all live rows | 0 (already 0 pre-apply; both Q14 dupes were the 2026-09-02 pre-resolved rows) | 0 | 0 |
| Source rows physically deleted or rewritten | 0 | 0 | 0 |

The live "before" counts (72/105/0) differ slightly from the 2026-09-16 plan
snapshot (73/106/2) because of the 3 pre-existing 2026-09-02 supersessions
already discussed and unrelated factory activity between snapshot and apply
time; the **after** counts match the reviewed plan's stated result exactly
(16/49/0), confirming the applied disposition set is the correct remaining
complement.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_pending_superseded_claim_filter.py -q` → 2 passed (confirms the canonical claim selector, which the board/cockpit pending counts key off, excludes any work item with a `work_item_supersedes` row regardless of encoding).
- Independent read-only re-query (separate connection, after commit) reproduced the receipt's `pending_counts_after` exactly and confirmed 56 disposition rows + 56 supersede edges exist with the expected shape, and 2 of the 56 spot-checked source rows are untouched.

RESULT: **PASS** — 56 of 57 Q12 + 0 of 2 Q14 dispositions applied append-only
under plan-hash lock; the remaining 3 plan entries were already resolved by
an independent, earlier (2026-09-02) supersession and correctly skipped
rather than double-dispositioned. Board/cockpit pending-Q12/Q14 counts now
match the reviewed plan's "after" column exactly. No source row, verdict, or
gate criterion was rewritten or deleted.
