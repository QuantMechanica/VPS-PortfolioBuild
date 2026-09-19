# P0 evidence-loss close-out (`f8432ebf`)

## Result

The deleting mechanism is identified. The original 172 watched paths are fully
accounted for:

| Outcome / process class | Rows | PASS | Durable evidence |
|---|---:|---:|---|
| OWNER backup-retention phase 2, `DELETE_NONRETAINED`, locally irrecoverable | 129 | 95 | exact compressed receipt stream, source size/mtime, batch completion bound and source path |
| Ordinary DL-090 quarantine followed by C-drive relocation; copy recovered | 27 | 0 | receipt-bound source size/mtime/inode plus byte-identical canonical recovered copy |
| Ordinary DL-090 quarantine still present on D: | 16 | 0 | surviving quarantine file plus matching `report_retention.log` snapshot receipt |
| **Total** | **172** | **95** | one row per watched path in `lost_directory_forensics.csv` |

All 95 PASS losses are in the first class. The responsible execution was the
OWNER-authorized backup-retention phase-2 run `4c0a5ae7`, committed as
`99143f421feccc325778dce4ef685b3c9616e6db`. Its exact-path receipts record
`disposition=DELETE_NONRETAINED`, `status=DELETED`, and
`detail=verified_quarantine_then_unlink`. This is a separate path from the daily
DL-090 report-retention job, tester-cache purge, and log purge.

This corrects the “mechanism not conclusively identified” conclusion in
`2026-09-14_p0_evidence_loss_forensics/FORENSICS_AND_REGENERATION_PLAN.md`. The
receipt-backed attribution and 27 recovered copies already existed in commit
`80a577273df55b6797d318f7034f06314cd57862`; the September 14 recheck did not
consult that evidence set.

## Per-directory forensics

`lost_directory_forensics.csv` has exactly 172 rows. Each row binds:

- original work-item identity, Q phase, verdict, and evidence path;
- last known file mtime and logical byte size;
- the surviving parent-directory mtime after removal;
- the process class and disposition;
- exact receipt batch, exact-path stream, line, and batch-completion bound; and
- any preserved/recovered path.

For the 129 deletions, the receipt's `mtime_ns` and `size` are the last recorded
source metadata. The batch completion is an upper bound, not an invented per-file
unlink time. For the 27 recovered copies, source mtime/size and inode were verified
against the receipt. For the 16 current D-drive quarantine copies, the file stat is
bound to the matching snapshot line in `D:/QM/reports/state/report_retention.log`.

The source is `2026-09-05_m05_recovery/per_path_forensics.json` (SHA-256
`79967aeaf9e834a5b573d9943995c86b1091f198b8d1df32ddab0a90bd52b13c`),
augmented only by the 16 surviving D-drive quarantine paths. The complete bindings
and count assertions are in `derived_summary.json`.

## Why the regeneration cohort is 81, not 72

There are 95 deleted PASS rows. A plain `(ea_id, symbol, phase)` grouping produces
72 because it treats every PASS in the same Q phase as interchangeable even when
the tested data windows differ. A defensible measurement-cell comparison also
requires equal, known `data_window_start` and `data_window_end`:

- 14 deleted PASS rows have another PASS with the same EA, symbol, Q phase, and
  both known/equal window bounds;
- the remaining **81** do not have such a comparable PASS;
- a missing window bound cannot prove equivalence and is included fail-closed.

This reproduces the ticket's 81 while making the previously missing comparison rule
explicit. The phase mix is Q03 52, Q05 17, Q06 9, Q07 3.

`sole_pass_regeneration_plan.csv` contains one append-only command per row using:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --append-only-rerun-of <id> --phase <Q-phase> --rerun-reason "P0 evidence regeneration, router task f8432ebf-7f91-422f-8fd6-628c2f86e46c, 2026-08-31 retention loss"
```

The command exposes no priority or RAM-class flag. Omitting a priority override is
the low/default, no-queue-jump path; RAM admission is classified automatically at
claim time. Nothing was enqueued.

Using the already documented latency proxy (Q03 at 3.0 minutes; Q05-Q07 at 11.1
minutes), the plan is **477.9 tester-minutes / 7.97 tester-hours**. The all-p50 and
all-p90 sensitivity bounds are 4.05 and 14.99 tester-hours. The orchestrator should
release rows in bounded waves and remeasure between waves.

## Fail-closed guard for the responsible writer

The phase-2 executor is not listed as a recurring scheduled task in the captured
task inventory, but its code remains callable. The current manifest builder still
adds PASS lineage only when `gate_contract_version == v4`; that is the policy gap
that allowed legacy PASS evidence to reach `DELETE_NONRETAINED`.

Before any future phase-2 execution, its own writer path needs all of these guards:

1. Any work-item row whose verdict begins `PASS` is permanent, independent of gate
   contract version or Q phase. Protect both the literal path and its `.gz`
   representation.
2. A path under `D:/QM/reports/work_items/<work_item_id>/` must resolve to exactly one
   database row. Missing database access, unknown IDs, parse ambiguity, or stale
   snapshot bindings must classify `KEEP_AMBIGUOUS`, never delete.
3. The executor must revalidate the work-item verdict immediately before unlinking,
   rather than trusting only a previously generated manifest. Any PASS match aborts
   the batch before the first unlink and emits a named receipt reason.
4. Bind the manifest to the database snapshot/hash and reject execution after drift.
   Add controls for legacy PASS, v4 PASS, gzip PASS, database failure, ambiguous ID,
   and a verdict changed to PASS between manifest generation and execution.

This is a proposal only. No retention criterion or writer code was changed by this
task.

## Watcher baseline refresh without history rewrite

After each approved regeneration wave:

1. Coordinate an exclusive writer window with
   `QM_EvidenceCohortWatch_Daily_0420`; capture the baseline SHA-256 before running
   anything.
2. Do not change or remove the 172 original `entries{}` records or any historical
   `losses[]` record. A rerun has a new work-item ID and evidence path.
3. Run `evidence_cohort_watch.py --init` only after the new evidence exists. The
   implementation skips existing IDs and appends eligible new IDs.
4. Diff the baseline against the captured copy: every pre-existing entry must be
   byte-equivalent, the number of added entries must equal the completed wave, and
   only `last_init_utc` plus those new entries may change. Refuse/restore from the
   captured copy if that assertion fails.
5. Let the next normal watcher check append its observation. Never “clear” the old
   losses or repoint an old row to a recovered/rerun artifact.
6. Commit the additive baseline delta separately with the wave receipt. Do not mix it
   with verdict, gate, or retention-policy edits.

No baseline writer was invoked during this task.

## Current watch state and verification

The bound baseline (`d85590fe0cab73c067b8601f34762a1a7aea7e0cbc727d809c03c36f85d0b358`)
has 177 logical losses: the original 172 plus five later non-PASS age-outs (two FAIL,
three FAIL_PORTFOLIO). There is no additional PASS loss in that delta.

Verification performed:

- derivation script syntax check passed;
- 172 unique forensic rows = 129 + 27 + 16;
- verdict mix = PASS 95, FAIL 61, FAIL_HARD 6, FAIL_SOFT 2, ZERO_TRADES 8;
- all 95 PASS rows bind to exact phase-2 deletion receipts;
- regeneration plan = 81 rows, with 14 equal-window siblings excluded;
- no database write, baseline rewrite, enqueue, terminal start, pipeline run, or
  verdict mutation.

Reproduce with:

```text
python C:/QM/repo/docs/ops/evidence/2026-09-19_f8432ebf_evidence_loss_closeout/derive_closeout.py
```
