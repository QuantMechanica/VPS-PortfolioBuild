# July-cohort Q02/Q04 zombie queue — park (79) + retire (223) execution

- Router task: `c9a1bdab-b40b-443b-9b12-2063958c7311` (claude, `ops_issue`, priority 60)
- Executes the classification approved in
  `docs/ops/evidence/2026-09-02_2093b38e_july_cohort_zombie_queue_disposition.md`
  (router task `2093b38e-8eb4-4bcd-931b-25c50ada861f`)
- Cycle: claude, 2026-09-02 ~17:40–17:42Z
- Mode: **append-only mutation.** No `work_items` row was edited or deleted;
  no verdict was overwritten; no active/claimed row was touched.

## What was applied

New tool: `tools/strategy_farm/apply_july_cohort_park_retire.py` (dry-run
`build_plan` + apply `apply_plan`; mirrors the `apply_q10_identity_mismatch_supersede.py`
pattern: plan-hash-bound apply, one online backup, `BEGIN IMMEDIATE` transaction(s),
pre-commit readback). Unit tests:
`tools/strategy_farm/tests/test_apply_july_cohort_park_retire.py` (5 tests, all pass).

**Cohort predicate** (unchanged from the classification pass):

```sql
status='pending' AND phase IN ('Q02','Q04') AND created_at < '2026-09'
```

For each cohort row, `latest_terminal` = the `done`/`failed` row with the
greatest `created_at` for the same `(ea_id, symbol, phase)`. Bucketing:

| bucket | prior verdicts in scope | rows |
|---|---|---:|
| **park** | `PASS`, `PASS_SOFT`, `PASS_LOWFREQ`, `RETIRE`, `CANCELLED_DUPLICATE_REQUEUE` | **79** |
| **retire** | `FAIL`, `INVALID`, `ZERO_TRADES`, `DRAFT_DEFECT` | **223** |
| *(out of scope, never touched)* | `INFRA_FAIL` | 1,705 |
| *(out of scope, never touched)* | `NO_PRIOR_RUN` | 148 |
| cohort total (re-derived, live) | | 2,155 |

Re-derived counts matched the CEO-approved figures **exactly** (79 park,
223 retire) — the plan's own `EXPECTED_PARK_COUNT`/`EXPECTED_RETIRE_COUNT`
guard (79/223) passed on the first read, so execution proceeded per the
task's instruction ("if the row list cannot be re-derived exactly ... STOP").
The one drift from the classification-pass snapshot (`INFRA_FAIL` 1,706→1,705;
cohort total 2,156→2,155) fell entirely inside the untouched `INFRA_FAIL`
bucket (one row was claimed by a factory worker in the intervening ~7 hours) —
it did not affect the park/retire counts.

## Mechanism

One `work_item_supersedes` edge per row (schema `tools/strategy_farm/work_item_supersedes.py`),
never an `UPDATE`/`DELETE` on `work_items`:

- `work_item_id` = the pending row being parked/retired
- `superseded_by_work_item_id` = **the prior terminal row's id** (set in both
  buckets — in park it is the PASS-family row that makes the rerun redundant,
  in retire it is the FAIL-family row that already settled the cell; in both
  cases it is the existing authoritative terminal record for the same
  `(ea_id, symbol, phase)`)
- `reason` = generated per row, e.g.
  `july_cohort_park: prior_verdict=PASS for QM5_1234/EURUSD.DWX/Q02, prior terminal row <uuid> (created 2026-08-04T...). PARK: ... Classification: 2093b38e...; execution: c9a1bdab...`
- `source_encoding` = `router:july-cohort-park:c9a1bdab-...` or
  `router:july-cohort-retire:c9a1bdab-...` (one per bucket, so the two
  batches are independently queryable)
- `evidence_path` = the classification document (hash-bound in the plan)
- `recorded_by` = `claude`

The existing trigger `trg_work_items_superseded_no_activate` (already live in
the schema) makes any row with a `work_item_supersedes` entry permanently
unclaimable (`pending → active` becomes a no-op `RAISE(IGNORE)`) without ever
touching `status`, `verdict`, or `payload_json`. This is the park/retire
effect: the row is inert but its full history stays exactly as it was.

Apply took **one** online SQLite backup for the whole run (both batches), then
committed the park batch and the retire batch as two separate
`BEGIN IMMEDIATE` transactions, both under one `FactoryMutationLock` hold.
Each row was revalidated (`status='pending'`, `verdict IS NULL`,
`claimed_by IS NULL`, identity hash unchanged, not already superseded)
immediately before its `INSERT`; a drifted row would be *skipped* (not
force-applied, and not allowed to abort the rows that did not drift) — in
this run, **zero rows drifted and zero were skipped**.

## Backup

| field | value |
|---|---|
| path | `D:\QM\strategy_farm\state\backups\farm_state_before_july_cohort_park_retire_20260902T174204Z_79f696d5.sqlite` |
| sha256 | `f7acabde393601f7a2b5944d128fb475181c7e3da5ac863af8c6b5c47bffe3eb` |
| size | 734,773,248 bytes (734 MB, full online copy) |
| count | exactly 1 for the whole batch (park + retire) |

## Verification

### Row-level (all 302 targets)

Re-queried after apply: all 79 park ids and all 223 retire ids —

- `work_items.status = 'pending'`, `verdict IS NULL`, `claimed_by IS NULL` (unchanged from pre-apply)
- exactly one `work_item_supersedes` row each, with the expected
  `source_encoding` and `superseded_by_work_item_id` = the plan's recorded
  prior terminal row id
- **0 mismatches** across all 302 rows

### Table-level (before → after)

| metric | before | after | delta |
|---|---:|---:|---:|
| `work_items` total | 122,262 | 122,262 | 0 |
| `work_items.status='pending'` | 7,793 | 7,793 | 0 |
| `work_items.status='active'` | 9 | 9 | 0 |
| `work_items.status='done'` | 65,412 | 65,412 | 0 |
| `work_items.status='failed'` | 49,048 | 49,048 | 0 |
| `verdict='PASS'` count | 26,589 | 26,589 | 0 |
| `verdict='FAIL'` count | 21,818 | 21,818 | 0 |
| `verdict='INFRA_FAIL'` count | 55,690 | 55,690 | 0 |
| `verdict='INVALID'` count | 2,224 | 2,224 | 0 |
| `verdict='ZERO_TRADES'` count | 1,171 | 1,171 | 0 |
| `verdict='RETIRE'` count | 154 | 154 | 0 |
| `work_item_supersedes` total | 1,152 | 1,454 | **+302** |
| `work_item_supersedes` (park encoding) | 0 | 79 | +79 |
| `work_item_supersedes` (retire encoding) | 0 | 223 | +223 |
| `events` (`work_item_superseded`, this router task) | 0 | 302 | +302 |

No `work_items` status or verdict distribution changed at all — the only
table-level delta anywhere in the database is the `+302` in
`work_item_supersedes` (and its paired `events` rows). `trg_work_items_superseded_no_activate`
was confirmed present in the live schema.

### Scope discipline

- The 1,705 `INFRA_FAIL`-prior rows (treasure candidates) and the 148
  `NO_PRIOR_RUN` rows (assess bucket) were never queried into a target list
  by construction (the plan only ever selects rows whose prior verdict is in
  the park or retire verdict sets) and carry zero new `work_item_supersedes`
  entries — spot-checked directly.
- No `Factory_OFF`/`ON`, no worker/terminal interruption, no T_Live or
  AutoTrading action, no gate-threshold or candidate-universe change.

## Artifacts

- `tools/strategy_farm/apply_july_cohort_park_retire.py` — plan/apply tool
- `tools/strategy_farm/tests/test_apply_july_cohort_park_retire.py` — 5 unit tests, all pass
- `docs/ops/evidence/2026-09-02_july_cohort_park_retire_plan.json` — dry-run plan
  (sha256 `7499620c1fbfedfeb275be0a53f3740d099c00e8a61c885a8e13e5057d82a04f`)
- `docs/ops/evidence/2026-09-02_july_cohort_park_retire_receipt.json` — apply receipt
  (`total_inserted=302`, `total_skipped=0`, `quick_check=ok`)

## Next step

Per the classification pass's own "Gap" section, the 1,705 `INFRA_FAIL` rows
still need root-cause sub-classification (stale-EX5, setfile-exponent,
ONINIT-pin, launch-fault) before a paced requeue schedule can go to the CEO
for approval; that work is unchanged by this execution and remains open under
the classification task's "Next step".
