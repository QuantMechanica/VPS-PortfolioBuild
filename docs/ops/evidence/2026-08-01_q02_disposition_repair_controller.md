# Q02 disposition-repair controller and pre-window dry-run

**Prepared:** 2026-08-01

**Router task:** `f9b2b014-deca-4fd5-ba95-ea5e8ce83e9f`

**Approved predecessor:** `27086064-a384-4e30-b04a-2043c4edeecf`
**Apply authority:** canonical `qm-q02-disposition-repair-plan/v1` SHA-256
`5abc62608f1fc5ebce7ee226490c261132aa592a1d5569601bf74cb35666a25d`
(5,676 canonical bytes)

## Outcome

The guarded controller and its focused tests are committed in canonical commit
`7d7488a824e3966b0a268fff7876e76a8a34b09c`. The live database dry-run is
`READY_FOR_AUTHORIZED_WINDOW` for the exact ten approved Q02 rows. No row was
changed.

The apply did **not** run on 2026-08-01. The task contract permits mutation only
on Sunday 2026-08-02 in Europe/Berlin while Factory is OFF and the active
work-item count is zero. At dry-run time it was Saturday, the Factory-OFF flag
was absent, and five work items were active. The controller rejects apply before
acquiring the mutation lock or creating a backup when the date gate is closed.

Accordingly, `docs/ops/evidence/2026-08-02_q02_disposition_repair_apply.md` does
not yet exist. It must be written only from the Sunday apply journal and
post-commit evidence; creating it now would falsely claim execution.

## Durable artifacts

| Artifact | Identity |
|---|---|
| Controller | `tools/strategy_farm/q02_disposition_repair.py`; SHA-256 `ebbf563e7765c75b584b19a2b2ff998cbbe66b02f589a704cee2aee58cdfe5c9` |
| Focused tests | `tools/strategy_farm/tests/test_q02_disposition_repair.py` |
| Immutable execution plan | `docs/ops/evidence/2026-08-01_q02_disposition_repair_execution_plan.json`; raw SHA-256 `69602d1daa89d5e6b86ea0484edd3063103d3c5dc6df20e5200a4b7f434b9752` |
| Dry-run receipt | `docs/ops/evidence/2026-08-01_q02_disposition_repair_dry_run.json`; raw SHA-256 `ac4bf67533b6556a809e71845fa060402b40024cbb32fd570b9aa83b67e44ab6` |

The execution plan is an immutable envelope around the reviewed canonical plan.
For every target it additionally binds all 15 `work_items` columns including the
exact historical `payload_json` bytes, a canonical full-preimage hash, evidence
path/bytes/SHA-256, PASS facts, and zero open/other-non-infrastructure pair
counts. The controller re-reads both plan layers inside the single mutation
transaction.

Six pre-`run_smoke/v2` summaries are not treated as schema-equivalent. They have
an explicit allowlist of the evidence SHA-256, OK-run count, and positive trade
count accepted by this task. The other four rows must retain their
`run_smoke/v2` execution-identity stability envelope.

## Apply and revert safety contract

The controller implements the accepted seven-step contract:

1. Re-read the raw execution-plan hash and the accepted canonical authority
   hash; verify controller bytes and exact task authority.
2. Refuse every mutation outside local date 2026-08-02.
3. Hold the global Factory mutation lock; require the exact Factory-OFF flag
   hash and zero active work items.
4. Revalidate every row, payload/evidence hash, PASS/OK/positive-trade fact, and
   pair-level gate before and again inside `BEGIN IMMEDIATE`.
5. Create and verify a fresh online SQLite backup, then exact-CAS all 15
   preimage columns from `failed / INFRA_FAIL` to `done / PASS` in one
   transaction. Evidence, attempt count, parent reference, and historical
   payload are retained; the payload gains a bound audit object.
6. Append ten per-row events and one cohort event, run transaction and
   post-commit `PRAGMA quick_check`, and persist the complete pre/post journal.
   The tool never enqueues or reruns a row and does not infer a pipeline verdict.
7. Revert requires the exact journal hash, the same date/Factory-OFF/zero-active
   gates and mutation lock, and all ten exact postimages before it restores any
   row. It appends revert events and refuses partial or drifted state.

## Focused verification

```text
python -m py_compile tools/strategy_farm/q02_disposition_repair.py tools/strategy_farm/tests/test_q02_disposition_repair.py
PASS

python -m pytest -q tools/strategy_farm/tests/test_q02_disposition_repair.py
.........                                                                [100%]
9 passed in 2.10s

live read-only execution-plan build
authority plan SHA-256: 5abc62608f1fc5ebce7ee226490c261132aa592a1d5569601bf74cb35666a25d
canonical bytes: 5676
targets: 10
database quick_check: ok

live dry-run, 2026-08-01T01:54:46Z
status: READY_FOR_AUTHORIZED_WINDOW
mutation_performed: false
date_gate_open: false
Factory-OFF flag: absent
active work items: 5
```

The tests cover exact ten-row apply and revert, full-preimage preservation,
outside-window refusal before backup, active-work refusal, authority/preimage
drift, mid-cohort rollback, raw-plan tampering, partial postimage revert refusal,
and explicit legacy-summary binding.

## Sunday continuation

In the authorized window, first wait for active T1-T10 work to finish; do not
interrupt it. With the Factory-OFF flag present, bind its current SHA-256 and
run the controller with the immutable plan and a new journal/receipt path:

```powershell
python tools/strategy_farm/q02_disposition_repair.py apply `
  --plan C:/QM/repo/docs/ops/evidence/2026-08-01_q02_disposition_repair_execution_plan.json `
  --expected-execution-plan-sha256 69602d1daa89d5e6b86ea0484edd3063103d3c5dc6df20e5200a4b7f434b9752 `
  --expected-authority-plan-sha256 5abc62608f1fc5ebce7ee226490c261132aa592a1d5569601bf74cb35666a25d `
  --expected-factory-off-sha256 <current-FACTORY_OFF-sha256> `
  --journal-out D:/QM/strategy_farm/state/q02_disposition_repair_20260802_journal.json `
  --receipt-out C:/QM/repo/docs/ops/evidence/2026-08-02_q02_disposition_repair_apply.json
```

The Sunday evidence document must quote the actual backup, journal, receipt,
event IDs, ten postimage hashes, and post-commit quick-check result before this
apply task is represented as complete.

No T_Live or AutoTrading state was changed, no terminal was started or stopped,
no T1-T10 run was interrupted, no history or news seed was changed, and no
pipeline verdict was invented.
