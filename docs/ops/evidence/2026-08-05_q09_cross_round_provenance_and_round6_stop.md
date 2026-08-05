# Q09 cross-round provenance repair and round-6 stop

Date: 2026-08-05  
Router task: `c0b64a33-94e5-4a6e-a615-7070f7275524`  
Candidate: `QM5_11422 / USDCAD.DWX`  
Governed Q09_NEWS row: `4984cca7-e1a3-49a8-a066-066ac51eb063`

## Outcome

Cross-round Q09 persistence is repaired in canonical-checkout commit
`2a0a0186ff286d7bd9cbe56955c9114c78645c24`. A sealed cell now fails closed
only when deterministic identity or economics fields differ. Execution-local
evidence/report hashes and paths are retained in an append-only occurrence
ledger and do not rewrite the first canonical cell row.

The ordinary worker then resumed round 6 from its 40 authenticated receipts and
persisted cleanly. The pipeline verdict is nevertheless `REVIEW_REQUIRED`, with
reason `expanded_7x4_matrix_required`. This is a genuine adjudication result,
not an infrastructure or persistence failure. The governed serial chain stops
here: no fresh Q09_PORTFOLIO row, Q10 rerun, or `QM5_13036` row was enqueued.

## Failure evidence and classification

The pre-repair attempts failed in `record_q09_adjudication` on sealed run
identity
`97832746b7c45318588ea7ee41e4a43303e951c796164b8a6b50f0e5deb4ac16`.
The reported divergent fields were exactly `evidence_sha256` and
`report_sha256`. All deterministic fields matched. Re-executed reports contain
execution-local bytes, so treating those two hashes as experiment economics
made every legitimate cross-round resume fail forever.

The T10 process spawned at `2026-08-05T10:27:16Z` before the repair was loaded.
It completed all cells and hit the expected old-code persistence refusal at
`2026-08-05T12:32:31Z`. The ordinary worker returned the row to `pending` at
attempt 1 without changing any terminal row or sealed identity. At that point:

- authenticated cell receipts: 40;
- latest receipt timestamp: `2026-08-05T12:32:31.3045114Z`;
- historical immutable cell-failure sidecars: 3; and
- active Q09 plan hold: released (`RUNNABLE_BOUND`).

## Repair contract

Database sidecar schema version 3 adds append-only table
`q09_news_cell_occurrences`. Each occurrence binds:

- Q09 work-item ID and sealed run identity;
- evidence and report SHA-256;
- evidence and report artifact paths; and
- append timestamp.

The canonical `q09_news_cells` row remains immutable. Resume comparison is
exact over the deterministic fields: arm, temporal/compliance modes, requested
and effective seeds, paired/run/setfile identities, selection/holdout/full
metrics, Q07 seed-stability result, and flat-at-event receipt identity. Any
divergence in those fields still raises `SchemaError` with the exact field
names.

View `q09_news_cells_by_work_item` projects reused canonical cells through their
per-work-item occurrences. The Q10 five-seed dependency gate, qualification
trigger, and FTMO admission reader consume that projection while retaining a
legacy-table fallback where appropriate. Same-tree persistence remains
idempotent: an identical occurrence is authenticated and not duplicated.

Production installation was transactional through `farmctl init`. Read-only
verification found schema version 3 plus the occurrence table, compatibility
view, validation trigger, and rebuilt qualification trigger.

## Focused verification

Syntax compilation passed for the schema, runner, and FTMO admission reader.

Focused schema/runner suite:

```text
24 passed in 33.09s
```

Expanded Q09 schema/runner/migration/contract/calendar/farmctl/FTMO/Q10 suite:

```text
56 passed in 31.71s
```

Regression coverage proves:

- an identical same-tree resume remains `ALREADY_RECORDED` with 40, not 80,
  occurrence rows;
- a cross-round rerun with different evidence/report hashes and paths records
  both provenance occurrences without rewriting canonical bytes;
- the work-item reader still exposes all 40 cells when canonical rows are
  shared across rounds; and
- a true deterministic metrics divergence remains fail-closed and names
  `selection_metrics_json`.

## Governed production result

After an unrelated active USDCAD symbol lock completed normally, the ordinary
worker claimed round 6 on T3 at `2026-08-05T12:39:22Z`. The fresh executor was
spawned at `2026-08-05T12:39:50Z`. All 40 receipts predated that spawn, so the
runner took the receipt-only collection/persistence path; it did not start a
new tester window.

Persistence evidence:

| Evidence | Value |
|---|---|
| Row terminal state | `done / REVIEW_REQUIRED` at `2026-08-05T12:40:16Z` |
| Sidecar persistence | `RECORDED` |
| Planned/authenticated cells | `40 / 40` |
| Failed/invalid/missing cells | `0 / 0 / 0` |
| Canonical rows first owned by round 6 | `21` |
| Round-6 provenance occurrences | `40` |
| Work-item reader rows | `40` |
| Reused cells with different physical hashes | `19` |
| Locked arms | `0` |
| Aggregate SHA-256 | `fab89c868167db6ef8743867e4bdd39796abd2974883d5602ed471e88965fea8` |
| Q09 evidence SHA-256 | `119d337cd163c99cd42d61db367f474176f75d74b16452228067f5c947e1ac0b` |
| Embedded adjudication SHA-256 | `f12680afbe987aed0db070d326e9a3a64ba885b5d19a8e55be1c703a7441581d` |

The embedded adjudication hash recomputes exactly. The database
`q09_news_tests.aggregate_sha256` matches the aggregate bytes.

The adjudicator found a material policy effect and requires the expanded 7x4
matrix. Its details record 2,395 control original entries, zero affected-entry
count, material differences in drawdown, net R, and profit factor, and 105
missing expansion cells. `chosen_config` is null. Therefore `CONFIG_LOCKED` is
not established and the ticket's fail-closed stop condition applies.

Read-only exit reconciliation found only the historical downstream rows:

- `QM5_11422` Q09_PORTFOLIO `99ab79c9...` and Q10 `6f9400fa...`;
- `QM5_13036` Q09_NEWS `7efd8e39...`, Q09_PORTFOLIO `6655a7d3...`, and Q10
  `788d2371...`.

No row in those downstream groups was created on 2026-08-05. The
`REVIEW_REQUIRED` adjudication is Claude review input; no pipeline verdict was
overridden and no live or AutoTrading state was touched.
