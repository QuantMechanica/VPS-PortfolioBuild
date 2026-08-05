# Q09 cross-round persistence divergence — Codex forensics

Date: 2026-08-05

Scope: QM5_11422 / USDCAD.DWX / Q09_NEWS

Primary affected work item: `4984cca7-e1a3-49a8-a066-066ac51eb063`

Repair under review: `2a0a0186f` (`Fix Q09 cross-round provenance persistence`)

Disposition: **root cause confirmed; repair is correct for the current trusted-writer path; no evidence loss found**

## Phase A — independent analysis

This section was produced from the repository history, live SQLite state, work-item log, and immutable Q09 artifacts. The Claude forensic report was deliberately not read before this section was written and committed.

### Executive verdict

The failure was a deterministic false-positive in restart-idempotency validation, not an economic-result divergence.

Commit `c8ee2dabe` correctly made same-work-item restart persistence fail closed, but it treated `evidence_sha256` and `report_sha256` as globally deterministic properties of a Q09 run identity. They are not. A cross-round rerun deliberately reuses the same economic run identity while writing a new physical report tree. The new tree contains execution-local paths, timestamps, logs, and summary material, so its report-manifest hash changes; the cell evidence embeds that report hash, so its evidence hash changes as well. The pre-repair schema stored one globally unique canonical cell per `run_identity_sha256`, and `_assert_persistence_match` compared these two execution-local hashes. Every retry therefore failed on the first reused identity even though all strategy inputs and all economic metrics were identical.

Commit `2a0a0186f` separates those two concepts:

- `q09_news_cells` remains the canonical, globally deduplicated economic cell.
- `q09_news_cell_occurrences` records the physical evidence/report occurrence for each work item.
- `q09_news_cells_by_work_item` projects canonical economic data with occurrence-local provenance.
- deterministic comparisons exclude only the physical occurrence fields while retaining the economic identity, setfile/base identity, seed fields, metrics, and stability result.

This is the correct model. The repair preserves fail-closed detection of economic drift and preserves every round's evidence provenance.

### Timeline and exact failure mechanism

The authoritative execution log is:

`D:\QM\strategy_farm\logs\work_item_4984cca7-e1a3-49a8-a066-066ac51eb063.log`

Relevant UTC events:

| Time | Terminal | Result |
|---|---:|---|
| 04:46:36 | T8 | A transient holdout exit `1` occurred; persistence then failed on identity `97832746...` because only `evidence_sha256` and `report_sha256` differed. |
| 07:34:23 | T6 | Same two-field persistence divergence. |
| 08:21:47 | T5 | A transient full-run exit `1` was followed by an immutable `cell_failure.json` collision. |
| 08:55:47 | T2 | Same two-field persistence divergence. |
| 10:27:16 | T10 | Spawned before the repair was loaded; it completed the receipts but failed through the old persistence code. |
| 12:31:50 | — | Repair commit `2a0a0186f` was created. |
| 12:39:50 | T3 | Loaded the repair, authenticated the existing 40 receipts, persisted occurrence provenance, and completed in about one second. |
| 12:40:16 | — | Work item reached `DONE / REVIEW_REQUIRED`. |

The failing identity was:

`97832746b7c45318588ea7ee41e4a43303e951c796164b8a6b50f0e5deb4ac16`

Its canonical physical hashes were:

- evidence: `87d14693...beb4`
- report: `1fd6b96e...e0c1`

The round-6 occurrence hashes were:

- evidence: `51fd4475...42c3`
- report: `bb74430d...5e63`

No deterministic identity field and no selection, holdout, or full-period metric differed. The two differing values describe where and how that occurrence was materialized, not what was tested or what it earned.

Before `2a0a0186f`, `q09_news_cells.run_identity_sha256` was globally unique. Persistence used `BEGIN IMMEDIATE`; when the strict comparison raised `SchemaError`, the Q09 test/cell transaction rolled back. The report tree was already durably written, so retries could authenticate the files but could not register the new round in SQLite. This explains the repeatable combination of complete disk evidence, absent test registration, and a persistence exception.

### Cross-round economic determinism proof

The compared report trees are:

- `D:\QM\reports\work_items\6a305d8a-81ef-49a3-94bb-2fd1aaeb822e`
- `D:\QM\reports\work_items\4984cca7-e1a3-49a8-a066-066ac51eb063`

Each tree contains 40 authenticated receipts. The sets of 40 `run_identity_sha256` values are exactly equal. Across those matched identities:

- stable identity/input-field mismatches: `0`
- selection/holdout/full metric mismatches: `0`
- different evidence hashes: `40 / 40`
- different report hashes: `40 / 40`

The aggregates are byte-identical:

`fab89c868167db6ef8743867e4bdd39796abd2974883d5602ed471e88965fea8`

The aggregate evidence wrappers are correctly distinct by occurrence:

- earlier tree evidence: `7dba2112...62e0`
- round-6 evidence: `119d337cd163c99cd42d61db367f474176f75d74b16452228067f5c947e1ac0b`

Plan authentication also passed:

| Work item | Plan file SHA-256 | Logical plan SHA-256 |
|---|---|---|
| `6a305d8a...` | `319727ee...edb3` | `7f685382...ddc5` |
| `4984cca7...` | `75fe706331131c6aa0d30ea4498c7a597ec37310263c33688fb739f2e877f9c0` | `92de747c...008` |

The aggregate and receipt comparison proves economic determinism much more strongly than merely observing that persistence eventually succeeded.

### POLICY_ON / POLICY_OFF / DXZ control interpretation

For every seed, `POLICY_ON / OFF / DXZ` is economically identical to `CONTROL_OFF / OFF / NONE` in selection, holdout, and full windows. All eight groups—one control plus seven DXZ temporal-policy groups—also have one metric digest across their five seeds.

Control metrics were:

| Window | Entries | Trades | Net R | Profit factor | Drawdown |
|---|---:|---:|---:|---:|---:|
| Selection | 347 | 132 | 8.99781 | 1.16 | 12.28 |
| Holdout | 132 | 48 | 8.79384 | 1.74 | 4.75 |
| Full | 479 | 180 | 17.79165 | 1.27 | 12.28 |

This equality is expected for this negative-control slice. With temporal blackout mode `OFF`, the compliance profile is inert, so selecting DXZ cannot alter entry timing. It validates deterministic execution and policy wiring; it is not evidence that the active news policy adds economic benefit.

### Evidence-damage audit

No Q09 evidence was deleted, overwritten, or rendered unauthentic.

- Both compared trees authenticate all 40 receipts.
- Both aggregates exist and authenticate to the same aggregate SHA-256.
- The successful round-6 Q09 evidence authenticates as `119d337cd163c99cd42d61db367f474176f75d74b16452228067f5c947e1ac0b`.
- Three historical failure sidecars remain immutable, as designed:
  - `policy_on__m2__c1__s17` holdout exit `1`: `49e46479...a01`
  - `policy_on__m2__c1__s7` holdout exit `1`: `317f4080...d73`
  - `policy_on__m4__c1__s17` full exit `1`: `f7e251f2...506`
- Successful receipts now take precedence over those stale historical failure sidecars.
- SQLite `PRAGMA integrity_check` returned `ok`.
- `PRAGMA foreign_key_check` returned 57 pre-existing, unrelated legacy violations (24 task rows and 33 work-item rows), with zero Q09-table violations.

The pre-repair rollback meant one failed attempt was not registered as a Q09 test, but its files remained intact. That is missing historical database registration, not evidence destruction.

### Repair completeness audit

#### Live migration and idempotency

The live database is `D:\QM\strategy_farm\state\farm_state.sqlite`. It reports Q09 schema version `3`.

Before the probe, the relevant live counts were:

- `q09_news_tests`: 4
- `q09_news_cells`: 40
- `q09_news_cell_occurrences`: 40
- `q09_news_cells_by_work_item`: 59 projected rows
- `q09_news_arms`: 0

`ensure_schema(conn)` was invoked twice against that live database while fingerprinting Q09 row counts, Q09 rows, schema object SQL, and schema metadata. The state after the first call exactly matched the state before it; the state after the second call exactly matched the first. The migration is idempotent on the live v3 database.

Round-6 has 40 occurrence rows, all created at `2026-08-05T12:39:51Z`. Their hashes and paths exactly match the authenticated receipts, and the by-work-item view returns all 40 cells. Among those identities, 19 canonical cells remain owned by `fd88398c-7288-4f6d-b3b0-4847487e35a8`; 21 were first persisted by round-6. For all 40, the canonical deterministic fields and metrics match the occurrence. Physical hashes differ only for the 19 reused identities, as expected.

#### Reader migration

The production read audit found no remaining work-item-scoped consumer that incorrectly filters the canonical cell owner's work-item column.

- Q09 qualification seed counts read `q09_news_cells_by_work_item`.
- The Q10 dependency gate reads `q09_news_cells_by_work_item`.
- FTMO Q09 admission selects the view when present and retains a canonical-table fallback only for pre-v3 databases.
- The live `trg_cq_validate_insert` trigger was drop/recreated by the repair and reads the view for its Q09 predicates.
- Remaining direct canonical-table reads are intentional implementation details: canonical identity lookup/deduplication, occurrence referential checks, and view construction/fallback.

#### Trigger and append-only coverage

The live schema requires an occurrence insert to reference both an existing Q09 test header and an existing canonical cell. Occurrence updates and deletes are rejected. The canonical Q09 tables retain their append-only protections, and qualification validation uses the by-work-item projection.

This is complete for the repository's trusted writer path: the runner authenticates receipt bytes before calling the record API, and the schema then enforces referential and append-only invariants. Direct out-of-band SQL remains inside the database trust boundary; the occurrence insert trigger does not independently hash files on disk.

#### Retry ceilings

The persistence defect was bounded, not an infinite retry loop.

- Generic retry ceiling: `MAX_WORK_ITEM_RETRIES = 3`; generic retries increment `attempt_count` and fail the item at the ceiling.
- Shared-base history-lock retry ceiling: `TRANSIENT_INFRA_RETRY_CAP = 6`; these retries use `transient_infra_attempts` and do not consume generic attempts.
- The affected work item ended at `attempt_count = 1` and `transient_infra_attempts = 4`.

Because a persistence exception prevented a valid Q09 sidecar from being accepted, the terminal worker ignored the otherwise complete aggregate and entered the generic retry path. Without a repair, the deterministic fault would have exhausted the generic ceiling. The repaired T3 run registered all existing receipts before that happened.

### Transient MT5 exit `1` and retry-sidecar collision

The MT5 exit `1` incidents are not the cause of the cross-round persistence divergence. They are a separate transient execution/transport condition.

Commit `d22dfee9e`, already in the ancestry of `2a0a0186f`, fixed the retry artifact collision by preserving the first immutable `cell_failure.json` and appending later failures as `cell_failure_2.json`, etc. Tests also require a valid receipt to override stale failure sidecars during recovery. Commit `2a0a0186f` did not remove the underlying possibility of MT5 returning exit `1`; it did not need to. That operational condition remains bounded by the normal retry policy.

T10 is not counterevidence against the repair: it spawned at `10:27:16Z`, roughly two hours before the repair commit, loaded the old Python module, and later failed through that in-memory code even though the repository had changed by completion. T3 spawned after the repair and persisted the same 40 receipts immediately.

### Residual risks and recommendations

No additional code change is justified by this forensic task. The active cross-round correctness defect is fixed.

The remaining items are maintenance or defense-in-depth concerns:

1. Future work-item-scoped readers must use `q09_news_cells_by_work_item`, not the canonical owner's work-item column.
2. `CREATE VIEW IF NOT EXISTS` is safe for the current v3 definition, whose live SQL was verified. A future view-definition change must bump the schema version and explicitly recreate the view.
3. Occurrence authenticity depends on the trusted runner/record API before insert. A future hardening change could narrow direct database write authority or add application-level re-authentication at every administrative import path.
4. A deterministic future `SchemaError` will still consume generic retry budget. Classifying it earlier could improve diagnostics, but the ceiling already prevents an infinite loop and the present cause has been removed.
5. MT5 exit `1` can recur operationally. Its immutable sidecar behavior is fixed, but transport/root-terminal diagnostics remain an infrastructure concern rather than a Q09 schema concern.

### Focused verification

Repository tests at the repair-bearing canonical checkout:

```text
python -m pytest \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q09_news_schema_v2.py \
  tools/strategy_farm/tests/test_q09_news_contract_v2.py -q

32 passed in 131.30s
```

```text
python -m pytest \
  tools/strategy_farm/tests/test_q09_news_migration_v2.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_ftmo_q09_admission.py \
  tools/strategy_farm/tests/test_q10_confirmation_contract_v2.py -q

20 passed in 3.32s
```

Combined result: **52 passed**.

### Independent root-cause statement

Q09 combined globally deterministic economic identity with round-local physical provenance in one uniqueness record. Restart hardening then compared both categories as though they shared the same determinism scope. Cross-round reuse correctly reproduced every input and economic metric but necessarily produced new report/evidence hashes, causing a deterministic persistence rejection. Schema v3 fixes the category error by retaining one canonical economic cell and appending per-work-item physical occurrences, then presenting the correct occurrence through a work-item view.

**Phase A independence seal:** the analysis above was completed before opening the Claude report. Cross-review follows only after this document is committed as a standalone Phase A artifact.

## Phase B — Claude/Codex cross-review

Phase A was sealed before this cross-review in canonical commit `3088212a0` and merged to `main` as `91b1da416`. Only then was the Claude report opened:

`docs/ops/evidence/2026-08-05_q09_persist_divergence_claude_forensics.md`

### Point-by-point disposition

| Claude finding or question | Codex disposition | Cross-review result |
|---|---|---|
| `c8ee2dabe` passed the complete cell dict, including evidence/report hashes, into strict resume comparison. | Confirmed directly from the historical source. The pre-fix dict contains 16 compared fields; the table row has the owner work-item id plus those fields and `created_at`. | Agreement on mechanism; Claude's “17-field dict” is harmless shorthand for the stored cell content, but the compared mapping itself has 16 keys. |
| Cross-round physical artifacts necessarily differ although the sealed run identity is stable. | Confirmed across all 40 identities, not only the example cell. Stable fields and all three metric payloads match; every evidence and report hash differs. | Full agreement. |
| The example cell evidence differs at exactly `report_sha256`, and its report manifest has 27 provenance-only leaf differences. | Accepted. Claude's deep file-level diff adds useful precision beyond the Codex aggregate/receipt comparison. Paths, timestamp-bearing file hashes, and calendar `age_hours` explain the physical hash difference without an economic change. | Claude adds detail; no contradiction. |
| T10's failure after the repair appeared in Git does not disprove the repair. | Confirmed. T10 spawned at `10:27:16Z`; `2a0a0186f` was committed at `12:31:50Z` (`14:31:50+02:00`). The long-lived process retained the old module. T3 spawned at `12:39:50Z` and succeeded. | Full agreement. |
| `2a0a0186f` makes the deterministic/provenance split correctly. | Confirmed by source review, live migration probe, production recovery, view/reader audit, trigger audit, and 52 focused tests. | Full agreement. |
| Transient MT5 exit `1` failures are a separate class. | Confirmed. The three immutable historical failure sidecars remain, and later receipts authenticate. `d22dfee9e` fixed retry-sidecar naming/precedence; it did not claim to eliminate tester exit `1`. | Agreement. Underlying transport cause remains outside this schema ticket. |
| `POLICY_ON/OFF/DXZ` equals control and therefore “DXZ minimum enforcement is a no-op for this EA.” | The equality is real, but the conclusion needs narrower wording. It proves the `temporal_mode=OFF` negative-control slice is inert, because there is no temporal blackout for the compliance profile to constrain. | Partial agreement. It does not prove that active DXZ temporal modes are globally a no-op. |
| Migration idempotency and reader migration still needed confirmation. | Closed by Codex Phase A: two consecutive live `ensure_schema` calls left all fingerprinted rows, counts, SQL objects, and metadata unchanged. Qualification, Q10, FTMO admission, and the live qualification trigger use the by-work-item view. | Question resolved; no unmigrated production work-item reader found. |
| Attempt-ceiling interaction still needed confirmation. | Closed by Codex Phase A: generic ceiling is 3, history-lock transient ceiling is 6, and the recovered row ended at generic attempt 1 / transient-infra attempt 4. | Question resolved; bounded retry, no hidden infinite loop. |

### Factual corrections to the Claude narrative

These corrections do not change Claude's root-cause verdict.

1. **The `6a305d8a...` round did not partially persist Q09 database cells.** Live state has no Q09 test, canonical cell, or occurrence row owned by `6a305d8a-81ef-49a3-94bb-2fd1aaeb822e`; that work item is `failed / INFRA_FAIL`. The current canonical ownership of the shared identity set is 19 cells from the earlier successful work item `fd88398c-7288-4f6d-b3b0-4847487e35a8` and 21 inserted by repaired work item `4984cca7-e1a3-49a8-a066-066ac51eb063`. `BEGIN IMMEDIATE` rolled back the failed `6a305d8a...` registration atomically while leaving its physical report tree intact. The reused rows that triggered the divergence therefore predated `6a305d8a...`; they were not a partial commit from it.
2. **The immutable sidecar collision belongs to the T5 spawn at `08:21:47Z`.** The T8 spawn at `04:46:36Z` encountered a transient holdout failure and then the two-field persistence divergence. Claude's compressed T8 description blends two retry episodes.
3. **The repair timestamp should be expressed as either `12:31:50Z` or `14:31:50+02:00`.** “`12:31:50Z +0200`” mixes UTC and offset notation.
4. **Metric units differ between the reports, not the economics.** Claude quoted cash-like net values (`8997.81`, `8793.84`, `17791.65`); Phase A quoted normalized net R (`8.99781`, `8.79384`, `17.79165`). Both representations agree after the expected scale conversion.

### What each investigation added

Claude contributed the clearest single-cell file-level proof: one divergent leaf in `cell_evidence.json`, 27 provenance-only leaves in `report_manifest.json`, and concrete examples including absolute work-item paths, timestamp-bearing output hashes, and calendar age. Claude also explicitly framed the fail-closed guard as sound behavior applied to the wrong determinism scope.

Codex contributed the matrix-wide and live-system closure:

- all 40 identities and all metric payloads compared across both artifact trees;
- byte-identical aggregate proof;
- current canonical ownership and occurrence distribution (`19 + 21`, with 40 round-6 occurrences);
- atomic rollback/evidence-damage reconciliation;
- two-call live migration idempotency;
- production-reader and live-trigger migration audit;
- append-only trigger coverage and trusted-writer boundary;
- generic versus transient retry ceilings and actual counters;
- the separate `d22dfee9e` sidecar fix;
- the precise negative-control interpretation; and
- SQLite integrity plus Q09-specific foreign-key verification.

Claude did not close its four residual questions; Codex Phase A closes three and classifies the remaining MT5 exit `1` cause as a separate, bounded infrastructure investigation. Codex Phase A did not enumerate Claude's 27 report-manifest leaf differences or explicitly identify `news_calendar.age_hours`; those details are adopted here.

### Joint root-cause statement

Commit `c8ee2dabe` strengthened restart idempotency by applying one strict equality scope to a canonical Q09 cell. That cell combined two categories with different lifetimes: globally deterministic experiment identity/economics and work-item-local physical provenance. An append-only rerun correctly reproduced the former but necessarily generated new report/evidence bytes for the latter. Existing canonical identities—19 of the final shared set were owned by the earlier successful `fd88398c...` work item—therefore caused a deterministic rejection on the first reuse. The transaction rolled back database registration while preserving already-written evidence, making every unchanged retry hit the same wall.

Commit `2a0a0186f` resolves the category error by retaining one fail-closed canonical economic cell, appending each work item's physical provenance to an immutable occurrence ledger, and routing work-item consumers through the occurrence-aware view. Economic drift still fails closed; legitimate cross-round provenance no longer does. The repair is live-migration idempotent, reader-complete for current production code, bounded by existing retry ceilings, production-proven by the T3 recovery, and covered by the focused test suite.

### Joint verdict

**ROOT CAUSE CONFIRMED / FIX COMPLETE FOR CURRENT TRUSTED PATH / NO EVIDENCE DAMAGE / NO FURTHER CODE CHANGE AUTHORIZED BY THIS TASK.**

The transient MT5 exit `1` remains a separate operational question. The `POLICY_ON/OFF/DXZ == CONTROL_OFF/OFF/NONE` result is a valid negative-control invariant, not proof of active-policy benefit or global policy ineffectiveness.
