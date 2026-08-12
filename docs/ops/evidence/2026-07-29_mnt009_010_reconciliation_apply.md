# MNT-009 / MNT-010 guarded runtime reconciliation

**Applied:** 2026-07-29T12:18:03Z
**Factory:** intentionally OFF throughout
**Plan ID:** `cb494c756acd3a7f9378acf9b6b209f74b06b1960684cd0ce2c5584344c8b713`

## Immutable inputs and recovery point

- Plan manifest SHA-256: `f5249c4cba64bcd6c03b668533fd2eb1d8b81e819c851ee7a6b0ffcde26624b2`.
- Pre-apply database file/logical SHA-256:
  `3f77860fa3962c85ae1c3e4257163044d3322301e9f2b598a9a25491853f1831`.
- `FACTORY_OFF.flag` SHA-256 before and after:
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`.
- Pre-apply SQLite backup:
  `D:\QM\strategy_farm\state\snapshots\farm_state_mnt009_010_pre_20260729T121800Z.sqlite`,
  SHA-256 `caa1bc7bebfa0cc5afaa5fbee7e38661f4b94201d473d090739122eb443ebf7a`.
- Machine-readable apply receipt:
  `docs/ops/evidence/2026-07-29_mnt009_010_reconciliation_apply.json`,
  SHA-256 `3fc9c7084fa95c3a60c2f587677b63c1632b38b5f376a8af0ba736699af001e5`.

The apply revalidated the manifest, database file, serialized SQLite state,
Factory-OFF flag, and every referenced artifact under the global factory
mutation lock. It created the backup, revalidated the database again, and
performed the database mutations in one transaction.

## Applied operations

- 832 legacy terminal NULL dispositions:
  - 804 `failed / INFRA_FAIL`;
  - 27 `done / SUPERSEDED_BY_LOGICAL_BASKET`;
  - 1 `done / RETIRE`.
- 1,005 pre-existing, lineage-valid evidence bindings:
  - 987 dedicated `bind_existing_evidence` transitions;
  - 18 bindings applied atomically with a NULL disposition.
- 43 physical parent zombies closed through the shared CAS:
  - 13 `PASS`;
  - 27 `INFRA_FAIL`;
  - 3 `STRATEGY_FAIL`.

No test result or evidence artifact was reconstructed. The 45,833 rows for
which no existing lineage-valid artifact was found remain explicitly unbound;
MNT-009 therefore remains `PARTIAL` even though its terminal-NULL scope is
complete.

## Post-apply verification

- Terminal work items with `verdict IS NULL`: 0.
- Physical parent zombies eligible for MNT-010: 0.
- Row-by-row checks: 832/832 dispositions, 987/987 dedicated evidence
  bindings, and 43/43 parent closures match the manifest.
- Append-only ledgers for this plan contain exactly 987 evidence bindings,
  832 legacy dispositions, and 43 parent closures.
- Apply-time events contain exactly 987 `mnt009_evidence_bound`, 832
  `mnt009_null_disposition`, and 43 `parent_closed_from_work_items` events.
- All 13 PASS parents contain `DEFERRED_FACTORY_OFF` with next phase `Q04`.
- Tasks created at or after the apply timestamp: 0. Auto-enqueue was false.
- Idempotence plan after apply: 0 NULL dispositions, 0 parent closures, and 0
  additional evidence bindings; 45,833 honestly unbound rows remain.
- Post-apply database file/logical SHA-256:
  `25b3f2620fa8724d88aeb3549e32d65dda8103bca6fb4b079a45558ed63d05f6`.

MNT-010 is `COMPLETED_RUNTIME` for the observed zombie corpus. No Factory_ON,
canary restart, T_Live change, or AutoTrading change was performed.

## Post-audit schema clarification

This clarification was added after the independent audit; it documents the
original guarded apply and is not a second apply or a new runtime mutation.
In addition to the row-level reconciliation above, the apply installed durable,
database-global invariants from `reconcile_terminal_work_items.py::SCHEMA_SQL`:

- `work_item_transition_ledger`, protected by no-update and no-delete triggers;
- `parent_task_transition_ledger`, likewise protected by no-update and no-delete
  triggers; and
- insert and update triggers on `work_items` that reject a terminal
  `done`/`failed` row with a NULL verdict.

These schema objects remain active for all writers after the reconciliation
transaction. They are therefore a separate forward-hardening deliverable, not
merely an implementation detail of the 832/987/43 row changes. Their matching
definitions in `farmctl.py::init_db` keep fresh or repaired databases on the
same invariant. No schema command was executed to add this clarification.
