# Recovery-814 sealed compute-yield closeout

Date: 2026-08-21

Task: `c72689a2-e786-4b8d-ba73-ff9e77d92c34`

Scope: read-only reconciliation of the exact two-stage Recovery-814 requeue cohort

## Verdict

**Recovery-814 did not earn its compute under a PASS-majority criterion.** All 814 requeued work items now have terminal statuses and terminal verdicts, but only 246/814 (30.22%) are `PASS`; 568/814 (69.78%) are non-PASS. The recovery was not pure waste: it produced 246 Q02 PASS results and 602/814 (73.96%) substantive, non-infrastructure verdicts. A Q02 PASS is only a phase result and is not evidence of strategy profitability or portfolio admission.

## Sealed cohort definition

The cohort is the set union of the `canary[*].work_item_id` values in these immutable execution journals:

- `D:/QM/reports/state/requeue_stage1_20260727T203434Z.json`: 50 rows
- `D:/QM/reports/state/requeue_stage2_20260727T203456Z.json`: 764 rows

The union contains 814 unique IDs (no duplicates). Both journals identify `requeue_stranded_infra.py` as their generating tool. The operational provenance is also recorded in:

- `C:/QM/repo/docs/ops/evidence/2026-07-27_stranded_requeue_executed.md`
- `C:/QM/repo/docs/ops/evidence/2026-07-27_stranded_canary_update.md`
- `C:/QM/repo/docs/ops/CODEX_BRIEF_fresh_infra_fail_diagnosis_2026-07-27.md`

No later work item was added, and no row was selected by a mutable time window or EA-name heuristic.

## Terminal-state reconciliation

Read-only source: `D:/QM/strategy_farm/state/farm_state.sqlite`, table `work_items`, joined by the 814 sealed `id` values.

| Measure | Count | Share of cohort |
|---|---:|---:|
| `status=done` | 701 | 86.12% |
| `status=failed` | 113 | 13.88% |
| All terminal statuses | 814 | 100.00% |
| `verdict=PASS` | 246 | 30.22% |
| `verdict=FAIL` | 181 | 22.24% |
| `verdict=ZERO_TRADES` | 167 | 20.52% |
| `verdict=INFRA_FAIL` | 212 | 26.04% |
| `verdict=RETIRE` | 6 | 0.74% |
| `verdict=RETIRED_LOW_FREQ` | 2 | 0.25% |
| All terminal verdicts | 814 | 100.00% |

The substantive/non-infrastructure yield is 602/814 (73.96%), calculated as all verdicts except `INFRA_FAIL`. Within those 602 substantive outcomes, 246/602 (40.86%) passed. The overall non-PASS yield is 568/814 (69.78%).

## Terminal elapsed-hours accounting

The database does not retain a complete claim/finish event ledger, so exact terminal compute-hours are **not measurable**. The best reproducible proxy is terminal elapsed wall-clock time for each row:

1. Start = current `payload_json.started_at_iso`, falling back to `payload_json.claimed_at_iso`.
2. End = the JSON at `evidence_path` field `timestamp_utc` when it is not earlier than start; otherwise current `payload_json.killed_at` when it is not earlier than start.
3. Duration = `(end - start) / 3600`.

This produces:

| Timing result | Value |
|---|---:|
| Rows with measurable elapsed time | 755/814 (92.75%) |
| End from `evidence_path.timestamp_utc` | 698 |
| End from `payload_json.killed_at` | 57 |
| Measured terminal elapsed-hours | 122.421 h |
| Median measured duration | 6.018 min |
| Maximum measured duration | 1.321 h |
| Rows without a retained start | 59 |

The 59 unmeasurable rows comprise 53 `INFRA_FAIL` and 6 `RETIRE` verdicts. Because the current row payload overwrites prior claim details and there is no comprehensive historical claim/finish ledger, **122.421 hours is a measured lower bound, not a cohort-total compute-hours estimate**. No duration is imputed for the missing rows, and elapsed time is not claimed to equal CPU time.

## Reproduction query and formulas

After parsing the two journal files and binding their 814 IDs as parameters, the database projection was:

```sql
SELECT id, status, verdict, payload_json, evidence_path, updated_at
FROM work_items
WHERE id IN (?, ..., ?);
```

Counts were grouped directly over `status` and `verdict`. Ratios use the sealed denominator of 814; substantive yield excludes only `INFRA_FAIL`. Timing uses the field precedence stated above and rejects any end timestamp earlier than its start. The reconciliation was executed read-only and made no factory, queue, work-item, or pipeline mutation.

## Decision

Close Recovery-814 as **terminal but compute-negative by the explicit PASS-majority test**. Preserve the 246 Q02 PASS rows as legitimate phase evidence, keep the 212 infrastructure failures distinct from strategy failures, and record the missing historical start timestamps as an observability gap rather than estimating them.
