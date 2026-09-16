# DL-089 duplicate declarations — 2026-09-17 review

## Scope and root cause

The live read-only census found 73 pending Q12 PATTERN rows created before
2026-09-10 (the ticket's 73-row scope) and two pending Q14 rows. The
re-declaration loop was in `tools/strategy_farm/dl089_matrix_service.py`:
`service_pending()` selected every pending Q12 row and called
`_measurement_sibling()` → `_compile_receipt()` → `_seed_q02()` without first
consulting the program's completed `q12_selection_receipt.json`. `_seed_q02()`
deduplicated only the Q02 measurement binding, so an already-adjudicated
program could be presented again as fresh Q12 work.

The service now calls `_adjudicated_program_receipt()` before that path. It
suppresses a row only when a valid prior selection receipt exists and the
declared `annual_cells_sha256` exactly matches the ledger's annual-cell
universe. Missing receipts, malformed artifacts, or a changed universe remain
eligible for normal fail-closed handling.

## Append-only disposition plan

The plan is dry-run only. No farm-state row, verdict, or supersession edge was
written in this cycle. The future governed apply step must verify the plan
hash, take the normal online backup, hold `FactoryMutationLock`, preserve each
source row, and append one disposition row plus one supersession edge per plan
entry.

- Plan: `docs/ops/evidence/2026-09-17_dl089_zombie_declaration_disposition_plan.json`
- Plan SHA-256: `58fb570c9f4bb7667d3b099d224406066616fae1eb9b3bbb8416202c577e92da`
- Content SHA-256: `ec051a6a42b41d77c8bef18ebccdd7657bdac8a9c9c0cebb313f40feb9c60a39`
- Planned verdict: `SUPERSEDED_DUPLICATE_DECLARATION`

The read-only plan contains 57 safe Q12 dispositions across 24 pairs and two
Q14 dispositions. Sixteen Q12 rows are excluded: six have no completed
receipt and ten have a changed census universe or ledger mismatch. Those
rows are not duplicates on the available evidence and remain untouched.

## Board/cockpit count reconciliation

These are control-plane counts from the live SQLite read model before apply;
the “after” column is the deterministic planned result, not a claim that the
plan has already been applied.

| Surface/count | Before | After planned append-only disposition |
|---|---:|---:|
| Pending Q12, ticket scope | 73 | 16 |
| Pending Q12, all live rows | 106 | 49 |
| Pending Q14, all live rows | 2 | 0 |
| Pending Q12 + Q14, all live rows | 108 | 49 |
| Source rows physically deleted or rewritten | 0 | 0 |

The board/cockpit should therefore stop counting 59 qualified phantom
declarations only after the plan is explicitly confirmed and applied; this
review leaves the dashboard's underlying rows unchanged.

## Verification

`DL089_MATRIX_SERVICE` focused tests: **19 passed** with the host's
`DL089_CELL_SLOTS=3` overridden to the test contract's six-cell fixture
capacity. The new regression test proves an exact annual universe is
recognized as an adjudicated duplicate and a changed universe is not.

RESULT: **PASS for service guard and dry-run plan; APPLY PENDING explicit plan-SHA confirmation.**
