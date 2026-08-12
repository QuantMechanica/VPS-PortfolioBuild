# Codex re-review — WP-2 and WP-6 after CHANGES-REQUIRED fixes

Date: 2026-07-25  
Review mode: read-only against live state; write-path validation only on temporary SQLite backups
created with the SQLite backup API. No live `--apply`, no backtest, no terminal start, no commit, and
no access to `C:\QM\mt5\T_Live`. WP-7 identity-hash hunks in
`framework/scripts/q08_davey/aggregate.py` were excluded from this verdict as instructed.

## 1. Verdicts

| Work package | Verdict | Summary |
|---|---|---|
| WP-2 aggregate ingester | **CHANGES-REQUIRED** | Atomic ingester idempotency and same-verdict suppression are genuinely fixed, and the Q10 DB-copy apply/no-op/revert path works. However, the real Q04 dry-run crashes before reaching its claimed refusal, Q10 setfile resolution still proves a mutable basename/path rather than the required setfile hash, and revert does not restore the full pre-schema/pre-row state demanded in the original review. |
| WP-6 sleeve-stream repair | **CHANGES-REQUIRED** | Refusing the five evidence-purged sleeves is the honest outcome, the positive repair control works, stream replacement is atomic, and the undercount test exists. The repair is still not evidence-bound at the original bar: above-floor mismatches bypass all validation, path + row count accepts same-count foreign content, malformed volume can crash after replacement, and the new requeue tool can apply without a mandatory snapshot or transaction-local evidence revalidation. |

These are not REJECT verdicts. Both designs are repairable without replacing the packages wholesale.

## 2. WP-2 findings

### Defect 1 — idempotency was not atomic: **CLOSED for the aggregate ingester**

The side-table choice is acceptable and is preferable to the rejected WP-1-style unique index on
`work_items`. `work_items` is per setfile/variant; imposing an `(ea_id, symbol, phase)` uniqueness
rule there would repeat the WP-1 identity error. The separate
`ingest_phase_aggregate_ledger` primary key scopes uniqueness to this reconciliation operation:

`(ea_id, symbol, phase, generated_at_utc, evidence_sha256)`.

The write path:

- creates the work-item, metric, and ledger row in one `BEGIN IMMEDIATE` transaction;
- re-checks the ledger and current work-item timestamps after acquiring the write reservation;
- commits the three records atomically;
- surfaces an already-ingested same-timestamp/different-hash rewrite as
  `same_timestamp_content_changed` on a subsequent plan.

Validation:

- `tools/strategy_farm/tests/test_ingest_phase_aggregates.py`: **13 passed**;
- barrier-synchronised concurrency test repeated in 25 independent pytest runs:
  **25/25 passed**;
- a Q10 apply against a temporary backup of the live DB inserted 23 work items, 23 matching
  `ea_metrics` rows, and 23 ledger rows;
- a second apply against that copy inserted zero rows;
- live `sqlite_master` still had no ledger table after the review, confirming no live apply.

The test named `test_prior_committed_row_blocks_reinsert_via_revalidation` does not literally stage a
terminal-worker commit between plan and insert—it retains a prior ledger entry after deleting the
associated rows. The two-apply race is nevertheless covered, and the code's transaction-local
work-item timestamp check covers a row committed before the ingester obtains its lock. Factory
quiescence remains a required operational precondition.

### Defect 2 — supersede broke COUNT consumers: **CLOSED**

`plan()` now suppresses a strictly newer aggregate when the newest terminal DB row carries the same
verdict, and keeps a supersede when the verdict changes.

The live Q10 dry-run produced:

- 20 new PASS;
- 3 new INVALID;
- 6 idempotent skips;
- 0 supersedes;
- 1 `supersede_suppressed_same_verdict` observation for QM5_20048/XTIUSD;
- 0 setfile refusals.

The tests prove both same-verdict suppression and FAIL→PASS ingestion. This closes the original
phantom-`portfolio_candidates`/Q12 `COUNT(*)` defect without imposing an unsafe uniqueness rule on
the shared work-item table.

### Defect 3 — wrong or unproved setfile: **PARTLY CLOSED; blocking remainder**

The concrete QM5_12567 error is fixed. The live Q10 dry-run resolved:

- XAUUSD to
  `QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_q10_confirmation.set`;
- XNGUSD to
  `QM5_12567_cum-rsi2-commodity_XNGUSD.DWX_D1_q10_confirmation.set`.

All 23 planned Q10 rows had an existing setfile, and all 23 filenames carried the expected symbol.
No empty-string write path remains. The resolver also ignores the shared mutable `summary.json` and
uses the aggregate-linked run directory's `tester.ini`, which closes the specific XAU/XNG mix-up.

It does not yet meet the complete provenance demand from the original review:

1. `_resolve_setfile()` reconstructs a path from the `tester.ini` basename and verifies current
   existence, but it does not authenticate the current bytes against a hash from the run. A repo
   setfile edited after the run is therefore accepted as though it were the file that ran.
2. The symbol check is conditional on `tester.ini` containing a non-empty `Symbol`; a missing symbol
   does not cause refusal.
3. The actual Q04 dry-run does not report a refusal. It exits with `UnicodeDecodeError` while
   `_existing_generated_at()` attempts to parse this UTF-16 HTML evidence path as UTF-8 JSON:

   `D:\QM\reports\smoke\ict_fvgce_2024\QM5_20002\20260716_170925\raw\run_01\report.htm`

   The affected DB row is
   `137b7aac-2f2f-4916-9e81-a1c81dbe3608`
   (QM5_20002/EURUSD Q04).

A read-only diagnostic that treated that non-JSON evidence path as unparseable showed the intended
safe result: 0 actions, 2,438 skips, and 1 explicit `setfile_unresolved` refusal for
QM5_11297/GBPUSD. Separately, the Q10-only resolver returned `None` for all 2,439 current Q04
candidates. Thus it does not currently mis-ingest Q04, but the builder's stronger claim that the
live Q04 dry-run **refuses** is false: it crashes before classification.

Q04 ingestion must remain disabled until a separately reviewed resolver validates WP-7's
top-level `setfile_path` against `setfile_sha256` and cross-checks EA plus logical/runner symbol
identity. The existing non-JSON evidence-path crash also needs a regression test and a fail-closed
classification.

### Defect 4 — no guarded revert: **PARTLY CLOSED; original full-rollback bar not met**

The improvements are real:

- the snapshot file is written before `ea_metrics.ensure_schema()` or ledger schema creation;
- revert fingerprints the inserted `work_items` row;
- it refuses a changed work item;
- it refuses a row referenced through `portfolio_candidates.q11_work_item_id`;
- tests cover clean deletion and both refusal cases.

On a live-DB backup, revert deleted all 23 inserted work items, metrics rows, and ledger rows, and
restored the original work-item and metric counts.

The original review required complete rollback, however. The current snapshot explicitly says
additive schema is not reverted. The DB-copy test confirmed that a newly introduced ledger table
remains after revert. Revert also fingerprints only `work_items`; a modified `ea_metrics` or ledger
row would be deleted without a corresponding modification guard. Either the ledger/schema change
must be handled as a separately approved persistent migration with its own rollback decision, or
the guarded revert must restore the true pre-apply schema state. Metric and ledger records should
also be guarded if “modified since ingestion” is the contract.

## 3. WP-6 findings

### Merit of the revised five-pair acceptance criterion

The builder is right on this point. The original five-pair criterion must not be read as “produce
five real verdicts regardless of surviving provenance.” All five linked Q08 aggregates are purged.
A forced re-export from a mutable or unrelated stream would reproduce the laundering defect the
review was meant to stop.

A direct simulation over the five rows produced **0 re-export / 5 refuse**, every refusal being
`q08_aggregate_stream_lineage_unavailable`. “Re-export from evidence that is actually bound to the
Q08 run, otherwise refuse and require a fresh sealed Q08 run” is the correct acceptance principle.

The implementation still falls short of that principle.

### Defect 1 — refusal was not bound to evidence: **NOT CLOSED**

Improvements that are valid:

- volatile `Common\Files` is no longer a re-export source;
- a missing aggregate refuses;
- `portfolio_stream.n` must equal the authoritative count on the short-stream repair branch;
- a source must be named in the aggregate and have the exact expected row count;
- the positive control remains live: a 12-row destination plus an aggregate-recorded 30-row source
  repairs to 30 and reaches a real mocked admission verdict. The function has not become
  refuse-everything.

Blocking gaps:

1. **Above-floor mismatches bypass the repair/refusal path entirely.** The call to
   `_reexport_short_sleeve_stream()` occurs only when `trade_count < min_portfolio_trades`.
   An adversarial 40-row stream, authoritative Q08 count 296, and floor 20 reached
   `PASS_PORTFOLIO` under a positive admission mock with no `stream_reexport` check at all.
   Evidence equality must be checked whenever an authoritative count is supplied, not only below
   the admission floor.
2. **A recorded mutable path plus row count is not immutable lineage.** The re-export code ignores
   `content_sha256`, host-copy hash, source artifact hash, report hash, EX5 hash, and setfile hash.
   In a direct test, a source with 30 rows but a SHA256 different from the aggregate's recorded
   `content_sha256` was accepted and returned `repaired=true`.
3. **The Q08 writer still accepts equal-count foreign content.** If the in-memory authoritative
   list and volatile source each contain three rows but different times, symbols, and P/L, the
   writer selects `source=common_copy`, persists the foreign bytes, and records `n=3`. Count
   equality does not prove that the volatile file is the list loaded and graded.
4. **Malformed volume is not validated.** `_volume_bearing_trade_count()` checks only for the
   presence of the `volume` key. Thirty rows with `volume: null` pass with count 30, are atomically
   installed, and then `load_streams()` raises `TypeError` on `float(None)`. The original demand
   explicitly required malformed-volume/load failures to return `NEED_MORE_DATA`, not crash.

This finding does not review whether WP-7 generates its identity hashes correctly. It reviews only
the WP-6 decision paths, which do not enforce those identities.

### Defect 2 — stranded rows were never requeued: **NOT CLOSED as a safe tool**

The live dry-run exactly reproduced the builder's headline:

- total terminal Q09 `NEED_MORE_DATA`: 13;
- REQUEUE: 0;
- REFUSE: 13;
- reasons: 5 `q08_evidence_purged`, 5 `authoritative_q08_count_unknown`, and
  3 `authoritative_below_floor`.

The five evidence-purged rows are correctly refused. They need new sealed Q08 evidence, not a stream
requeue. The five unknown-count rows are also correctly refused absent an authoritative count.

The three below-floor classifications are not all proven correct:

- QM5_10069/XAUUSD records 3 against its historical floor of 30; its linked aggregate is purged.
- QM5_11125/WS30 records 18 against a floor of 20; its linked aggregate is purged.
- QM5_13128/NDX records 1 in the old Q09 payload, but the exact linked current Q08 aggregate now
  records `n_trades=57` and `portfolio_stream.n=57`; its matching `ea_metrics.trades` and durable
  stream also contain 57. The tool returns `authoritative_below_floor` before comparing that
  surviving aggregate. This row is still correctly **refused**, because payload and evidence
  lineage disagree, but it is not correctly classified as a genuine current low-frequency case.

The mutation tool itself has four blocking safety defects:

1. `--snapshot-out` is optional even with `--apply`; mutation can therefore occur with no durable
   revert record.
2. Classification is performed before `BEGIN IMMEDIATE`. `_apply()` re-checks only
   `status='done'` and `verdict='NEED_MORE_DATA'`; it does not revalidate the aggregate, stream,
   counts, or hashes inside the transaction.
3. A DB-copy simulation planned one eligible requeue, deleted its qualifying Q08 aggregate, and
   then called `_apply()`. The row was still changed to pending.
4. `prior_state` stores only status and verdict. Revert writes a new `updated_at` rather than
   restoring the original timestamp, so it is not an exact restoration. The same simulation
   confirmed the original timestamp was not restored.

No test in the claimed 103-test selection imports or exercises
`requeue_q09_stranded_sleeves.py`. Direct plan/apply/revert, mandatory-snapshot, stale-evidence,
hash/content mismatch, and exact-state restoration tests are required.

### Defect 3 — non-atomic stream writes: **CLOSED**

Both WP-6 stream writers stage a sibling temporary file and use `os.replace()`:

- aggregate persistence/host mirroring in
  `framework/scripts/q08_davey/aggregate.py`;
- Q09 re-export in
  `tools/strategy_farm/portfolio/portfolio_q08_contribution.py`.

The Q09 copy-failure test proves the old durable file remains byte-identical and no temporary file
is left. The aggregate helpers likewise replace only after the temporary write/copy completes.

### Defect 4 — no undercount regression test: **CLOSED narrowly**

`test_serialises_authoritative_set_when_common_copy_undercounts` is a direct regression test and
passes. The implementation serialises the authoritative in-memory list for undercount, overcount,
or unreadable-count mismatch when volume is available, and reports the actual persisted count.

The equal-count/foreign-content hole remains under defect 1; row-count equality alone is not a
lineage check.

## 4. Test and dry-run evidence

| Validation | Result |
|---|---|
| WP-2 new test file | **13 passed** |
| WP-2 concurrency test repeated separately | **25/25 passed** |
| WP-2 live Q10 dry-run | 23 inserts planned: 20 PASS + 3 INVALID; 6 skips; 1 QM5_20048 observation; 0 refusals |
| WP-2 live Q04 dry-run | **FAILED** with `UnicodeDecodeError`; no writes |
| WP-2 apply/second apply/revert on SQLite backup | 23 inserted / 0 inserted / 23 deleted; original data counts restored |
| WP-6 inferred claimed suite: Q08 contribution + portfolio admission + Q08 sub-gates | **103 passed** |
| WP-6 live requeue dry-run | 0 REQUEUE / 13 REFUSE |
| Five purged-pair re-export simulation | 0 re-export / 5 refuse |
| WP-6 positive repair unit control | repairs 12 → 30 and proceeds to real mocked admission |
| WP-6 adversarial above-floor mismatch | 40/296 bypassed validation and reached mocked PASS |
| WP-6 adversarial same-count/hash mismatch | incorrectly repaired |
| WP-6 malformed `volume: null` source | incorrectly passed precheck, then raised `TypeError` |

## 5. Updated WP-2 apply order

WP-3 and WP-4 are already applied. They should not be reordered, reverted, or re-applied merely to
run WP-2. The corrected order from the current state is:

1. **Fix and re-review the remaining WP-2 blockers above.**
2. **Quiesce and seal the DB.** Confirm all factory/runner/worker/other DB writers are absent,
   observe DB/WAL stability, and take a full SQLite backup plus hashes.
3. **Run a Q10-only dry-run.** Reconfirm the then-current plan. At this review it was 20 PASS +
   3 INVALID inserts, 6 skips, the QM5_20048 same-verdict observation, no supersede, and no
   refusal.
4. **Run `ingest_phase_aggregates.py --phase Q10 --apply`.** This recovers the 20 orphaned Q10
   PASS rows and also records the 3 orphaned INVALID outcomes; the apply is therefore 23 rows, not
   20 total rows.
5. **Run immediate post-checks while consumers remain stopped:** one metric and ledger row per
   inserted work item, no pre-existing work-item changes, all setfiles authenticated, second Q10
   dry-run empty/idempotent, and no duplicate portfolio frontier rows.
6. **Only then resume the relevant consumers/factory.**

Do **not** run WP-2 with `--phase Q04`. Q04 remains gated on the reviewed
`setfile_path`/`setfile_sha256` resolver branch and a dry-run that completes with explicit
fail-closed classifications.

WP-6 deployment/requeue remains after WP-2 in this repair sequence, but the current requeue tool
must not be applied. Its current live plan has no eligible rows anyway; the five purged cases need
fresh sealed Q08 runs.

## 6. What could not be verified

- No apply or revert was executed against the live farm DB. Write-path results came only from
  temporary SQLite backups or isolated temporary databases.
- No backtest, MT5 terminal, worker, or live environment was started or inspected.
- The exact historical writer/interleaving for the five bad streams remains unrecoverable because
  their Q08 aggregates are purged.
- The two purged below-floor rows can be corroborated only from their historical Q09 payloads and
  work-item state, not from the original Q08 aggregates. The third below-floor label is contradicted
  by its surviving current evidence as described above.
- The positive repair control is synthetic; no fresh, real, sealed Q08 aggregate was generated
  because backtests were prohibited.
- WP-7's identity-hash generation and schema correctness were not reviewed. Only WP-6's failure to
  consume/enforce such identities was tested.
- The complete repository test suite was not run. The requested/new WP-2 tests, the 25-run
  concurrency stress, and the inferred claimed 103-test WP-6 selection were run.

