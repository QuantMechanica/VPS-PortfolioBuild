# Preflight-failure SH3 crash repair

- Task: `05016e99-4c3d-4175-b92e-25cd8a18ac3b`
- Recorded: `2026-09-07T18:44:06Z`
- Scope: bookkeeping repair for terminal-worker preflight failures
- Outcome: `REVIEW`

## Finding

The EX5 binding guard correctly rejected five Q02 work items whose recorded
`expected_ex5_sha256` no longer matched the canonical EX5. The rejection writer
then attempted to persist `status='failed'` and `verdict='INFRA_FAIL'` without a
`verdict_taxonomy`. On SH3 rows, the database constraint rejected that update.
The outer worker exception handler subsequently recorded the items as worker
crashes. A second latent defect allowed a legacy string failure value to reach
`.get()`, which would raise before the writer ran.

The affected observations were:

| UTC | Terminal | Work item | EA | Expected EX5 SHA-256 | Current EX5 SHA-256 |
|---|---|---|---|---|---|
| 12:28:32 | T4 | `de8e719f-4075-41a4-b4e6-8f0f1077dbe2` | `QM5_41165` | `196c37...a1d5` | `67c5f9...c328` |
| 12:31:20 | T4 | `fc8770b5-12fc-4ef4-a8e6-90b645fd9b46` | `QM5_41172` | `53fbff...0769` | `97539a...c1a1` |
| 12:33:38 | T4 | `92ee9327-54e9-48b5-a82e-11fa86528a9b` | `QM5_41176` | `663eca...5300` | `ac8b11...52ca` |
| 12:37:11 | T9 | `aa2484aa-c937-4f3a-add8-792b700917e3` | `QM5_41312` | `bddf06...fa1c` | `f16992...a239` |
| 12:39:41 | T8 | `4b6ed242-5045-42ff-acf2-3df2ee4f7d56` | `QM5_41336` | `c62f35...9f6d` | `b393ae...465a` |

The production rows were already recovered by the outer crash handler as
`failed / INFRA_FAIL / infra`; this change does not replay or mutate them.

## Repair

- Normalize every preflight failure before dereferencing it. Mapping inputs are
  copied and defaulted; scalar/string inputs become `{reason, detail}`.
- Persist the existing governed taxonomy `infra` in both the payload and the
  SH3 `verdict_taxonomy` column for preflight/binding failures.
- Audit literal `status='failed'` work-item writers in `terminal_worker.py` and
  `farmctl.py`. All five terminal-worker writers and all four farmctl writers
  now name `verdict_taxonomy`; dynamic completion writers continue to use the
  shared identity update clause.
- Add a migrated-SH3 regression that reproduces a stale EX5 hash through the
  real claimed-item handler, verifies the fail-closed `INFRA_FAIL`, then handles
  a second row with a legacy string failure to demonstrate loop continuity.

No claim order, verdict policy, retry threshold, or EX5 binding rule changed.
A stale binding still fails before tester launch. No terminal or worker was
started, stopped, or restarted; the resident workers receive the change only
through the governed CEO reload bundle.

## Verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_preflight_failure_sh3.py \
  tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py \
  tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py \
  tools/strategy_farm/tests/test_summary_missing_classification.py \
  tools/strategy_farm/tests/test_basket_work_items.py \
  tools/strategy_farm/tests/test_schema_hardening_sh2_sh3.py \
  tools/strategy_farm/tests/test_artifact_identity_hotfix.py -q

91 passed in 6.79s
```

The regression also statically inspects both writer modules and fails if any
literal failed-status update omits the taxonomy column.
