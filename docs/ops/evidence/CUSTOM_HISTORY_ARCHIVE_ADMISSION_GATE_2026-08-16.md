# Custom-history archive admission gate — 2026-08-16

## Router binding

- Agent task: `1ed12619-14d1-4e0c-895b-6066457644d1`
- Assigned agent: `codex`
- Priority: `70`
- Review disposition: `REVIEW`
- Implementation commit on `agents/board-advisor`: `7df940703`

## Defect reproduced

The active OWNER-approved archive manifest is:

- Path:
  `D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\archive_manifest_owner_approved.json`
- Manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- Activation SHA-256:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`

Direct admission against the production manifest selected 108 archive rows for
QM5_11078/EURUSD.DWX. The same admission for QM5_21524 resolved both basket
members (`XTIUSD.DWX`, `XCUUSD.DWX`) and failed with:

`custom_history_manifest_archive_coverage_missing: XCUUSD.DWX`

This confirms that the archive has no XCUUSD.DWX row and that host-symbol-only
validation was insufficient.

The seven pre-existing Q02 rows identified by the router remain preserved with
the prior `xcuusd_no_archive_coverage_await_data_intake_manifest_extension_20260816`
defer reason: QM5_13080, QM5_13081, QM5_13085, QM5_13098, QM5_20060,
QM5_21524, and QM5_21525. This change does not choose between history intake
and strategy retirement; that remains an OWNER decision.

## Implementation

`tools/strategy_farm/farmctl.py` now has one admission authority that:

1. Loads and validates the active isolation receipt and its OWNER-approved
   archive manifest.
2. Resolves the union of the explicit host symbol, logical-basket members,
   traded symbols, conversion symbols, the EA dependency manifest, and card
   universe symbols.
3. Uses the same validated archive-row selector as copy-on-claim.
4. Refuses admission before a queue insert if any `.DWX` member lacks rows,
   returning the stable reason
   `custom_history_manifest_archive_coverage_missing` and the exact missing
   symbol list.
5. Hash-binds successful admission metadata into the work-item payload.

The guard is applied to:

- Strategy Card approval and prebuild validation.
- Parent-task backtest fan-out.
- Automatic Q02 enqueue after a build.
- Fresh and append-only exact-row Q02 reseeds.
- Exact-identity Q03 enqueue.
- All later cascade enqueue and requeue paths.
- Every insert path in `sweep_enqueue_built_eas.py`, including deferred
  promotion and stranded-infrastructure retries.

The sweep's priority calculation was also bound to its configured `FARM_ROOT`
and database. Production resolves to the same paths as before; hermetic sweep
tests no longer open the live farm database.

## Verification

- `py_compile` for `farmctl.py` and `sweep_enqueue_built_eas.py`: PASS.
- Admission-specific regressions: 4 passed. They cover a fabricated
  XTIUSD/XCUUSD logical basket whose approved manifest contains only XTIUSD,
  assert that no Q02 row is written, and assert both approval and prebuild
  refusal without card mutation.
- Admission + sweep + basket regression group: 25 passed.
- Q02/Q03 exact repair-enqueue regressions (excluding unrelated Q04 full-cache
  scans): 30 passed, 4 deselected.
- `git diff --check` on the implementation and tests: PASS (line-ending notice
  only).
- Production safe-path check: QM5_11078/EURUSD.DWX admitted 108 rows.
- Production failing-path check: QM5_21524 rejected with missing
  `XCUUSD.DWX`.
- Governed Q02 work item `aa23aaed-0933-4f0a-b109-8b82096b8a55` was created
  only after safe admission and contains the active activation and manifest
  hashes plus the selected EURUSD archive-row count.

No terminal was started or interrupted, and no live-trading control was changed.
