# Pending artifact-binding repair — 2026-08-29

Task: `e4107fb6-877e-4a83-b14c-f0eadeca49fe`

## Census and disposition

The initial read-only census inspected 265 pending, artifact-bound rows and
found 55 mismatched bindings across 41 rows:

- 28 `CONTENT_CHANGED` bindings;
- 27 `MISSING` bindings;
- 14 rows requiring a governed build successor;
- 27 rows requiring exact artifact restoration or a governed recompiled
  successor.

No row was eligible for a mechanical rebind. A sealed work-item identity was
never changed. Twelve drifted rows already had active non-restart holds.
The two unheld content-change rows and 27 unheld missing-artifact optimization
census rows were routed through `governed_work_item_hold.py`.

While those holds were being applied, six previously active/stale-claim rows in
the same QM5_41097 and QM5_41161 cohorts returned to pending. They carried the
same missing governed binaries, so the same fail-closed disposition was applied
before completion. The final live census therefore covers 273 bound pending
rows and reports 61 mismatched bindings across 47 drifted rows, all 47 protected
by active holds and **zero claimable drift rows**.

## Durable mutation evidence

- QM5_10593 Q04: one `ARTIFACT_BINDING_CONTENT_CHANGED` hold.
- QM5_20096 Q02: one `ARTIFACT_BINDING_CONTENT_CHANGED` hold.
- QM5_41097 OPT_CENSUS: 20 `ARTIFACT_BINDING_MISSING` holds (16 initial plus
  four rows returned from stale claims).
- QM5_41161 OPT_CENSUS: 13 `ARTIFACT_BINDING_MISSING` holds (11 initial plus
  two rows returned from stale claims).

Each apply took a full SQLite backup, revalidated exact `id=symbol`, EA, phase,
pending status, null verdict, and null claimant under `BEGIN IMMEDIATE`, inserted
a non-restart hold plus audit event, and read back `claimable=false` before
commit. Backup paths and SHA-256 digests are bound in the per-group JSON files.
The factory mutation mutex was used to let existing work continue while briefly
preventing old workers from immediately reacquiring a claim transaction; no
active T1-T10 run was interrupted.

## Tool hardening and verification

`pending_artifact_binding_census.py` is a read-only, repeatable census which
mirrors dispatch identity checks and assigns conservative dispositions.
`governed_work_item_hold.py` now retains one pre-mutation backup while reopening
and retrying the complete hold transaction on SQLite busy bursts.

- Python compilation passed for both tools.
- Focused tests: **6 passed** across the census and governed-hold suites.
- Final readback: **47 active holds / 0 claimable drift rows**.

Release conditions remain governed: append a successor bound to reviewed
current artifacts, restore the exact sealed bytes, or append a governed
recompiled successor. The sealed rows must not be rebound in place.
