# QM5_11196 Replacement-Set Append-Only Q08 Rerun

Date: 2026-09-06  
Router task: `9ecdd2f9-c9e0-4367-8caa-9a4ad56c4365`  
Requested state after review: `REVIEW`

## Implementation

Commit `e73af54859` adds `farmctl enqueue-backtest --replacement-setfile` to
the cascade append-only rerun path. The option is refused unless
`--append-only-rerun-of` is present. The replacement must:

- be a readable repo-relative file under the canonical EA `sets` directory;
- use the governed `_sYYYYMMDD-NNN.set` suffix and exact
  `<EA>_<symbol>_<timeframe>_backtest_<set-version>.set` name; and
- declare matching `ea_id`, `symbol`, `timeframe`, `set_version`, and
  `environment: backtest` headers.

The new work item path, `expected_setfile_sha256`, `artifact_identity`, DSR
candidate, and append-only transition ledger are all derived from the same
replacement bytes. The historical terminal row is never updated or requeued.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py
  tools/strategy_farm/tests/test_dsr_rerun_window.py
  tools/strategy_farm/tests/test_dsr_cohort.py
  tools/strategy_farm/tests/test_dsr_single_configuration.py -q`:
  `92 passed, 13 subtests passed`.
- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS.
- `git diff --check` on the scoped implementation and tests: clean.
- The DSR single-configuration regression proves both
  `build_identity.setfile_sha256` and `provenance.setfile.sha256` equal the
  replacement candidate SHA.

## Production append

Command inputs:

- EA / phase / symbol: `QM5_11196` / `Q08` / `XAUUSD.DWX`
- Q07 predecessor: `42154e17-73a6-49ec-93ab-ce47d0e4e6e6`
- preserved Q08 rerun target: `a79887e3-7f60-40f6-a2a8-0d7785acf400`
- replacement: `framework/EAs/QM5_11196_ft-heracles/sets/QM5_11196_ft-heracles_XAUUSD.DWX_H4_backtest_s20260906-001.set`
- replacement SHA-256:
  `7cc424d2334be3835815fdbfbf874fc2cabffcdc15d689b64830cffce9c3bf6b`
- current EX5 SHA-256:
  `d3b1aef0507d9997fcb1f28d6f499c5cbebe82e19ca70f261cc43d06a6ca6710`
- reason: `OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 execution 8fe2bac0`

Result: one new pending work item,
`9ec3b856-2040-4870-9f36-797ccb122102`. No existing row was requeued.

Read-only database verification immediately after enqueue found:

- row `setfile_path`, payload `replacement_setfile_sha256`,
  `expected_setfile_sha256`, and `artifact_identity.setfile_sha256` all bound
  the governed replacement;
- payload window `2017.01.01` through `2025.12.31`, symbol `XAUUSD.DWX`, and
  period `H4` remained bound to the exact predecessor identity;
- append-only transition ledger sequence `3097` recorded action
  `append_only_replacement_setfile_bound` and the replacement SHA; and
- historical target `a79887e3-...` remained `done / INVALID`, with its original
  evidence path and `updated_at=2026-09-06T19:03:23+00:00`.

At enqueue time the DSR producer recorded `Q08_CLAIM_ROW_REQUIRED`, as expected
because the enqueue helper has not yet inserted/claimed the new Q08 row. The
terminal worker's existing claim-time attachment calls `dsr_cohort.attach`
with the inserted Q08 row; the new row and payload already carry the identical
replacement binding required by that producer.

No terminal process, scheduler, `T_Live`, or AutoTrading state was changed.
