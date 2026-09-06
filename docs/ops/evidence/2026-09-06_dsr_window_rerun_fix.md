# DSR Candidate Window Recovery For Q08 Reruns

Date: 2026-09-06
Router task: `acf3637b-abd2-4328-81bd-a2e314da52e1`
State requested after review: `REVIEW`

## Reproduction

The append-only Q08 reruns `045bed75-f005-4787-bde2-05a00b658054` and
`a79887e3-7f60-40f6-a2a8-0d7785acf400` carried neither complete payload dates
nor valid Q08 row dates. Their Q07 predecessors did carry the governed full
window:

- `42ca0f18-f1cb-4946-8e21-c43851197909`: `2017.01.01` to `2025.12.31`.
- `42154e17-73a6-49ec-93ab-ce47d0e4e6e6`: `2017.01.01` to `2025.12.31`.

The producer previously parsed only Q08 payload/row fields and therefore
recorded `CANDIDATE_WINDOW_UNAVAILABLE` before it could seal the OWNER-approved
single-configuration declaration.

## Repair

`dsr_cohort` now resolves a complete, parseable window in this fixed order:

1. `from_date` / `to_date` in the candidate payload.
2. `expected_from_date` / `expected_to_date` in the candidate payload.
3. `data_window_start` / `data_window_end` on the Q08 row.
4. The same governed fields on an identity-matching Q07 predecessor reached by
   `promoted_from_work_item`, `from_work_item_id`, or append-only rerun lineage.

It still refuses `CANDIDATE_WINDOW_UNAVAILABLE` when no complete authoritative
pair exists, rejects reversed pairs, bounds lineage traversal, and ignores
cross-EA/cross-symbol rows. A successful `dsr_context_status` now records
`candidate_window_source`.

The Q08 enqueue helper also copies the Q07 predecessor window into
`expected_from_date` / `expected_to_date`, making future ordinary and
append-only Q08 rows self-contained.

## Read-only replay

The production SQLite database was copied to
`D:/QM/tmp/codex_dsr_replay_20260906_acf3637b/farm_state.sqlite`. After the
QM5_11196 fixture row alone was rebound to its separately reviewed replacement
set, the copy was reopened with `PRAGMA query_only=ON`.

| Q08 row | Window source | Trials | Closed trades | Evaluator |
|---|---|---:|---:|---|
| `045bed75` | Q07 `42ca0f18` row columns | 1 | 311 | `PASS` |
| `a79887e3` | Q07 `42154e17` row columns | 1 | 656 | `PASS` |

Both sealed windows are `2017-01-01` through `2025-12-31`. Context SHA-256
values were `3ac13c66ec5371d7c8846ec78e55897a8fe1cbfa7062a2eb84087b5f39512eba`
and `952374e60f5a7659a03d691482d0c3cbecc9f874e20c4a4be2b2a7aa6690c4b9`.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_dsr_rerun_window.py
  tools/strategy_farm/tests/test_dsr_cohort.py
  tools/strategy_farm/tests/test_dsr_single_configuration.py -q`:
  `32 passed`.
- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q`:
  `58 passed, 13 subtests passed`.
- `git diff --check` on the scoped change set: clean.

No enqueue was performed and no production work item, historical verdict,
terminal, scheduler, `T_Live`, or AutoTrading state was changed. The replay
outcomes are code-path verification only; pipeline verdict authority remains
with pipeline evidence.
