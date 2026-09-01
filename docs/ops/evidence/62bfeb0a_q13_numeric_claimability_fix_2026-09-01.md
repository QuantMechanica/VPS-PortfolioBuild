# Q13 numeric-cell claimability repair

Date: 2026-09-01
Router task: `62bfeb0a-a049-47a0-b35e-cbcae1577acb`
Program: `DL089_QM5_11421_EURUSD_DWX_2019_2025`
Disposition: REVIEW

## Defect

The 70 Q13 numeric work items created at 2026-09-01 05:47 UTC comprised seven
`NUMERIC_BASELINE` rows and 63 `NUMERIC` rows. All were `pending`, unclaimed,
and null-verdict. Their payloads omitted `arm`, `q12_work_item_id`, and
`q12_declaration_sha256`, so
`terminal_worker._is_governed_dl089_census_payload` returned false.

After those fields were repaired, a second claim-path defect became observable:
the governed frontier preflight authenticated only the original annual
`ledger.cells`, while numeric declarations are stored in
`driver.numeric.runs`. A numeric candidate therefore could not be its declared
arm frontier even with a valid governed payload.

## Fix forward

- `opt_census_select._insert_run` now synthesizes authenticated derived-run
  fields for `WF_COMBO`, `NUMERIC_BASELINE`, `NUMERIC`, and their rerun forms.
- Numeric lane identity is deterministic: `baseline` for the control and
  `param:value` for each numeric trial. Each lane contains the seven ascending
  annual cells, so the existing fleet invariant prevents concurrent years of
  one `(program, arm)`.
- Derived payloads copy the sealed `q12_work_item_id` and
  `q12_declaration_sha256` directly from the ledger.
- Numeric rows receive the same queue-priority-only frontier marker used for
  the post-census critical path. The existing WF-only post-census ordering rank
  now recognizes numeric and derived-rerun stages too. No verdict or gate
  criterion changed.
- The worker frontier preflight now resolves the candidate's authenticated
  derived-stage declaration. It continues to use the existing
  `dl089_scheduling.arm_frontier` validation and transaction-bound token; the
  sealed ledger file is not rewritten.
- Rerun resolution substitutes only the latest append-only rerun ID declared
  in `driver.reruns` while retaining the original immutable cell identity.

## Existing-row repair

The accepted in-place payload-addition option was used because all 70 target
rows were proven `pending`, `claimed_by IS NULL`, and `verdict IS NULL` inside
one `BEGIN IMMEDIATE` transaction. The repair uses a compare-and-swap predicate
on the original payload plus those state guards. This changes claim plumbing
only and preserves deterministic work-item IDs and setfile paths.

First repair result:

```json
{
  "declared": 70,
  "repaired": 70,
  "already_valid": 0,
  "skipped": 0,
  "governed_after": 70,
  "verdict_rows_touched": 0
}
```

After adding the numeric frontier-priority fields, the same guarded repair was
run again: 70 repaired, zero skipped. Post-repair inspection found 70/70 rows
with both `priority_track=true` and `opt_census_frontier_priority=true`.

No completed, failed, active, claimed, or verdict-bearing row was updated.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_opt_census_select.py -q`
  - 18 passed.
  - Covers governed `NUMERIC_BASELINE`, `NUMERIC`, and numeric-rerun payloads,
    deterministic arms, Q12 bindings, derived frontier resolution, and the
    null-verdict-only repair guard.
- `python -m pytest tools/strategy_farm/tests/test_opt_census_dispatch.py -q`
  - 22 passed, including numeric post-census ordering ahead of annual refills.
- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q`
  - 87 passed before the queue-rank-only addition. The final run reported 86
    passed plus one concurrent commit-headroom fixture failure caused by a
    transient `factory_admission_interlock_error`; that exact test passed when
    rerun alone (1 passed). No production assertion failed.
- `python -m py_compile` passed for the changed production and test modules.
- `git diff --check` passed for the explicit task pathspecs.
- Live production preflight for work item
  `3c8b813e-6bad-53f8-9575-be196a1b94af` returned `status=checked`,
  `candidate_pending=true`, lane
  `(DL089_QM5_11421_EURUSD_DWX_2019_2025, baseline)`, year 2019, and a valid
  transaction-bound token with an empty predecessor list.

## Safety

- No verdict/gate-criteria mutation.
- No sealed-ledger mutation.
- No active T1-T10 backtest interruption.
- No terminal or AutoTrading action.
- Existing unrelated canonical-worktree changes were left untouched; the task
  commit uses explicit pathspecs only.
