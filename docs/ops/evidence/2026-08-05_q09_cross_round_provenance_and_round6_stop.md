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

## Round-7 expanded 7x4 matrix handoff

Router task `0c56fd4e-3bbd-4734-ad4e-0999f349e22d` applied the adjudicator's
expansion order without modifying any historical work item or terminal state.
The append-only Q09_NEWS row is
`9fabcddb-8c2e-4b01-9295-4ef4dbb6892d`, rerun-of round 6
`4984cca7-e1a3-49a8-a066-066ac51eb063`, with the same exact Q08 input
`9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` and candidate-lineage key
`c963164be8b0677f76ec6cc812f40b0f7f5a9149eb493c31735a85a38c298a7b`.

The canonical sealed-plan builder, invoked with its expanded-matrix switch,
created the cell set; no cell or setfile was hand-edited. The resulting plan
contains 145 unique cells: five `CONTROL_OFF/OFF/NONE` seeds plus 140
`POLICY_ON` cells covering seven temporal modes, four compliance modes
(`NONE`, `DXZ`, `FTMO`, `5ERS`), and five seeds. The 40-cell overlap with
round 6 retained identical run identities, setfile hashes, and paired-base
identity. The other 105 keys compare exactly equal to
`aggregate.details.missing_cells` from round 6.

| Identity | Value |
|---|---|
| New Q09_NEWS work item | `9fabcddb-8c2e-4b01-9295-4ef4dbb6892d` |
| Append-only rerun of | `4984cca7-e1a3-49a8-a066-066ac51eb063` |
| Exact Q08 predecessor | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` |
| Calendar bundle | `q09cal-20150101-20260809-0bb19b5bb9790b76` |
| Tester model / cost profile | `REAL_TICKS / DXZ_CANONICAL_REAL_TICKS_V1` |
| Matrix / cells | `7x4 / 145` |
| Logical plan SHA-256 | `6bf79bf3c4639cce94b2b7ce210e5334ba3f26e7e611f810d26e8a1c5e2c0956` |
| Exact plan-file SHA-256 | `7be29db5c55df1347192c0622971218c9c3e6233e014734ab4fe8f7b6f0100fa` |
| Input-manifest SHA-256 | `c879e9c594012800fd5c7b471f91b90e5e19f59cf5da36506aee8bdfc8bd250e` |
| Dispatch-binding SHA-256 | `4a85bb0ad42d8099c9b2b4552cfb1d30d862c8dce416f80c5b0132fe61374825` |

Preflight re-authenticated the unchanged Q08 aggregate, baseline setfile,
current EX5, reviewed include closure, and approved calendar manifest at the
same SHA-256 identities recorded for round 6. All 145 generated setfiles match
their sealed hashes, use `RISK_FIXED=1000` and `RISK_PERCENT=0`, and contain no
`qm_news_stale_max_hours` value above 336.

Binding completed at `2026-08-05T13:10:01Z`, released the activation hold as
`RUNNABLE_BOUND`, and left the row `pending` for an ordinary factory worker.
No executor, terminal, AutoTrading, or live surface was started or changed by
the orchestrator. Based on round 6's approximately 7h46m wall time for 40
cells, the 105 genuinely new cells imply a central completion estimate near
`2026-08-06T09:35Z` (`11:35 CEST`), plus ordinary queue and retry delay; the
honest operational expectation is Thursday, not a guaranteed deadline.

The serial chain remains closed. Only pipeline-produced `CONFIG_LOCKED` on
this exact row may open a fresh Q09_PORTFOLIO row from Q08 `9fe3eb5f...`;
only a resulting `PASS_PORTFOLIO` may open a Q10 append-only rerun of
`6f9400fa...`; and only then may the `QM5_13036/GDAXI.DWX` chain begin from
Q08 `fb3f0e20...`, historical Q09_NEWS `7efd8e39...`, and Q10 rerun-of
`788d2371...`. At handoff no downstream row was added and no pipeline verdict
was inferred.
