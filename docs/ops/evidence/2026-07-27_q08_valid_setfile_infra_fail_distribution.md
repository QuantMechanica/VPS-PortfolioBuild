# Q08 `INFRA_FAIL` rows with currently valid set files

Date: 2026-07-27  
Router task: `4458d308-dc70-481f-a5aa-f8d5585d4f9b`  
Scope: read-only diagnosis; no work-item changes or requeues

## Result

The farm database contained 204 Q08 rows with `verdict='INFRA_FAIL'`. Directly
reading each row's current `setfile_path` reproduced the prior split: 46 current
set files have no non-empty `strategy_*` assignment and 158 do. The 158 are not
one failure class:

| Rows | Root cause from row-bound evidence | Repeat behavior | Recommendation |
|---:|---|---|---|
| 81 | `sub_gate_input_runs.*.error` says the baseline set file had no strategy parameters. The current set file is valid, so the aggregate records an older defective input. | Deterministic for the recorded run; a current-input run may differ. Re-running the old row without rebinding provenance is unsafe. | Retire/reclassify the stale rows; enqueue only a fresh hash-bound run after confirming the repaired set file. |
| 32 | Aggregate verdict is `INVALID` with no Python error. Dominant evidence defects are missing neighborhood lineage and insufficient PBO configurations/slices. | Deterministic with unchanged upstream evidence. | Reclassify as an evidence/setup defect, not generic retryable infra. Fix/produce the missing Q03/neighborhood lineage before a fresh Q08 run, or retire when it cannot be produced. |
| 27 | No readable row-bound aggregate: 19 referenced paths do not exist and 8 rows have no `evidence_path`. Of these, payload reasons are 23 `phase_runner_invalid_report`, 2 `ACTIVE_TIMEOUT`, 1 `FAIL_SOFT`, and 1 absent. | Mixed. The two timeouts are potentially transient; missing evidence is not evidence of a transient runner fault. | Retry only the two timeout rows under normal retry policy. Quarantine/reclassify the other 25 until provenance is recovered; retire if it cannot be recovered. |
| 12 | `sub_gate_input_runs.*.error` reports duplicate `strategy_spread_atr_mult` in the generated ablation set for QM5_10706. | Deterministic generator/input defect. | Fix duplicate-parameter generation, invalidate stale ablation artifacts, then enqueue a fresh hash-bound run. |
| 4 | Aggregate verdict is `INFRA_RECYCLE` with no sub-gate exception. | Deterministic until the aggregate's requested evidence refresh is satisfied. | Preserve the explicit recycle class and satisfy its evidence requirement; do not flatten to generic `INFRA_FAIL`. |
| 1 | Aggregate verdict is `FAIL_HARD` (QM5_10692) with no sub-gate exception. | Deterministic strategy verdict from completed evidence. | Reclassify to strategy failure; do not retry as infra. |
| 1 | Aggregate verdict is `INFRA_FAIL` (QM5_11124) with no sub-gate exception. | Requires its explicit aggregate/payload reason, not blanket retry. | Keep infra only if the specific evidence defect remains actionable; otherwise retire. |

The classes are disjoint and sum to 158. Only 2/158 are directly identified as
transient (`ACTIVE_TIMEOUT`). At least 129/158 are deterministic with unchanged
inputs/evidence (81 stale-input errors, 32 evidence-invalid aggregates, 12
duplicate-parameter errors, 4 explicit recycles). The remaining 27 comprise one
hard strategy failure, one explicit infra failure, and 25 missing-evidence rows.

## INVALID breakdown

Across all readable aggregates in this 158-row cohort, the most frequent
`verdict_classification`/sub-gate details were:

- `8.5_neighborhood`: 94 `artifact_missing`, 10 `degenerate_baseline`, 2
  `evidence_status_missing_or_invalid`, and 1 historical
  `baseline_setfile_defect`.
- `8.7_pbo`: 81 `insufficient_distinct_configs:got=0`, 17 `got=1`, 16
  `insufficient_common_even_slices`, 2 missing scores files, and 1 stale
  scores/meta lineage.

These detail counts overlap within rows and therefore must not be added to infer
population size. The table above performs the row-level, disjoint grouping.

## Boundary finding

The active checkout's classifier maps an upstream `INVALID` back to
`INFRA_FAIL` in `tools/strategy_farm/farmctl.py`:

```text
if verdict_upper == "INVALID":
    return "INFRA_FAIL", reason or "phase_runner_invalid_report"
```

That conversion explains the 32 completed `aggregate.verdict == "INVALID"`
rows: Q08 already recorded deterministic evidence insufficiency, but the
work-item boundary erased the distinction and made it look generically
retryable. The same flattening also leaves historical input defects circulating
after the on-disk set file has changed.

Recommended boundary behavior:

1. Preserve `INVALID` (or a dedicated non-retryable `EVIDENCE_INVALID`) through
   the work-item boundary.
2. Permit automatic retry only for an allow-list of transient reasons such as
   timeout/runner-loss, with bounded attempts.
3. Bind Q08 evidence to set-file and upstream-artifact hashes. A repaired current
   file must create a fresh row; it must not make an old aggregate appear valid.
4. Treat `FAIL_HARD` as strategy evidence and never convert it to infra.

## Reproduction evidence

Database snapshot read read-only:
`D:\QM\strategy_farm\state\farm_state.sqlite`.

Row selection:

```sql
SELECT *
FROM work_items
WHERE phase = 'Q08' AND verdict = 'INFRA_FAIL';
```

For every selected row, classification used only:

- the exact `work_items.setfile_path`;
- the exact `work_items.evidence_path`;
- `aggregate.json.verdict`;
- `aggregate.json.verdict_classification`;
- every `aggregate.json.sub_gate_input_runs.*.error`; and
- payload `verdict_reason` only when the row-bound aggregate was absent.

Representative row-bound aggregate paths:

- Hard strategy failure:
  `D:\QM\reports\work_items\16b48cd4-9493-4eee-90f4-5114fb4082f6\QM5_10692\Q08\NDX_DWX\aggregate.json`
- INVALID evidence:
  `D:\QM\reports\work_items\9b6c3259-82e7-4de6-b558-5194a7fbb619\QM5_10440\Q08\NDX_DWX\aggregate.json`
- Historical empty-parameter error:
  `D:\QM\reports\work_items\95169711-6426-4b66-ab9f-0f0d35ef90af\QM5_12580\Q08\AUDUSD_DWX\aggregate.json`
- Duplicate ablation parameter:
  `D:\QM\reports\work_items\f557fc68-d1bf-4cfc-ac12-9e79cab682e9\QM5_10706\Q08\GBPUSD_DWX\aggregate.json`
- Explicit recycle:
  `D:\QM\reports\work_items\fda4b407-6a4e-41a0-9804-b8211d73f9a5\QM5_13213\Q08\USDJPY_DWX\aggregate.json`

No repository files, work items, factory state, terminals, or queues were
changed during the analysis.
