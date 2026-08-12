# Codex independent review — gate-repair plan and WP-2/3/4/6

Date: 2026-07-25  
Branch reviewed: `agents/board-advisor`  
Review mode: read-only against live state; no `--apply`, no backtest started, no commit, no access to
`C:\QM\mt5\T_Live`.

## 1. Plan verdict — REJECT

The programme must not be executed as written. The idea “stop genuine duplicate creation before
large requeues” is right; WP-1 as specified is not. It uses the wrong work-item identity and can
block legitimate variants. The revision also names three new blocking packages without actually
specifying them, leaves the requeue table inconsistent with its own revised ordering, and does not
give every DB-mutating path a rollback.

### Required plan changes

1. **Redesign WP-1 before keeping it first.**

   `work_items` is explicitly a per-`(EA, symbol, phase, setfile)` table
   (`tools/strategy_farm/farmctl.py`, schema comment near line 683). A partial unique index on only
   `(ea_id, symbol, phase)` would collapse legitimate Q03 grids, ablations, and other variants.

   A read transaction at `2026-07-25T09:44:42.540Z` found:

   - 35 open `(ea_id, symbol, phase)` groups containing 105 rows;
   - all 35 groups consisted entirely of different `setfile_path` values;
   - zero open duplicate groups existed when `setfile_path` was included.

   The plan's headline example is also misdiagnosed: QM5_10042/AUDUSD has 386 Q04 FAIL rows but
   **386 distinct setfiles**, fed by 387 distinct Q03 setfiles. That may expose an upstream
   fan-out-policy defect, but it is not 386 duplicate dispatches that a triple-only unique index may
   safely delete.

   WP-1 must:

   - deduplicate an exact normalized request identity, at minimum
     `(ea_id, canonical_symbol, phase, canonical_setfile_path)`, plus a run/evidence revision where
     a code-version rerun is materially different;
   - fix any unwanted grid-to-Q04 fan-out at the promotion policy that creates it, not hide it with
     a broad uniqueness constraint;
   - leave `attempt_count` as an execution/retry counter. Incrementing it for duplicate enqueue
     demand can exhaust a row before it runs and corrupts retry telemetry;
   - provide an explicit force/supersede operation for a new-code rerun when an old-version row is
     pending or active;
   - inventory and snapshot exact open duplicates before adding an index, with a reversible
     survivor/cancellation migration.

   With that redesign, WP-1 should still precede mass requeues. In its present form it would make
   later work cheaper by silently discarding legitimate work.

2. **Write the missing WP-9, WP-10, and WP-11 specifications.**

   The revision says their full specs appear after WP-7, but the document contains only WP-8 after
   WP-7. The review matrix also ends at WP-7. These are not optional details:

   - WP-9 and WP-10 block R-1;
   - WP-11 addresses corrupted KS baselines, including a gross-history/net-live mismatch.

   Each needs owner/reviewer assignment, exact files, rollback, tests, acceptance evidence, and
   an explicit gate in the staged-requeue table.

3. **Repair the R-1/R-2 gates and define the cohort.**

   The revision says WP-9 and WP-10 block R-1, while the table still gates R-1 only on WP-1.
   R-1 must require:

   - WP-9 and WP-10 reviewed and deployed;
   - affected basket EAs recompiled, with the tested EX5 provenance bound to the fixed framework
     header;
   - old Q07 recovery artifacts quarantined or cryptographically rejected by WP-10;
   - a sealed cohort definition. “12 book sleeves” is the stale ever-PASS join; the challenge found
     11 on latest-PASS evidence and 10 on latest-overall PASS state.

   The plan also omits the legacy/no-RNG class. QM5_1567 is in the book cohort and has no effective
   stochastic treatment. Re-running it after WP-9/WP-10 will not make Q07 meaningful. Upgrade those
   EAs to the stress/RNG contract or take an explicit OWNER decision for a non-applicable gate.

4. **Add the phase-dependency/lineage inventory as real work, not a paragraph.**

   The challenge proved that `phase > current_phase` is not a recovery model because Q04-early runs
   in parallel with Q03. Yet R-4 and R-5 still use the old fixed counts. Build the requeue inventory
   from explicit dependency edges, current build/evidence lineage, canonical symbols, active magic
   rows, and basket-aware dispatch. Recompute every R count from a sealed post-repair snapshot.

5. **Make rollback complete.**

   Missing or inadequate rollback paths are:

   - WP-1's index and any open-row consolidation;
   - all R-1..R-5 enqueue/cancellation mutations;
   - WP-6's required requeue of existing terminal `NEED_MORE_DATA` rows;
   - WP-2's schema call, which currently occurs before its snapshot, and its manual-only delete
     instruction rather than a guarded `--revert`.

   Every batch must snapshot exact prior rows and inserted IDs before the first DB write. Revert
   must be guarded on the exact post-state and include downstream rows created from the insertion,
   or downstream consumers must remain stopped until validation completes.

6. **Make WP-2/WP-7 an explicit path-and-schema contract.**

   Applying WP-2 for Q10 before WP-7 is fine. Using it for Q04 is not yet defined.

   WP-2 scans only:

   - `D:/QM/reports/pipeline/QM5_*/<phase>/*/aggregate.json`; and
   - `D:/QM/reports/work_items/**/<phase>/*/aggregate.json`.

   If WP-7 writes Q04 under either exact layout, the scanner will find it. If WP-7 introduces a new
   durable root, it will not. More importantly, current Q04 aggregates have fold-level
   `summary_path` values but no top-level `summary_path`; WP-2 would therefore write
   `setfile_path=''` for all of them. WP-7 must either put immutable setfile provenance in the Q04
   aggregate or WP-2 must resolve and validate a fold summary. Add an integration test that writes
   a WP-7-shaped Q04 artifact and proves WP-2 discovers it with a real, matching setfile.

7. **Keep R-3 → R-4 → R-5 only after strengthening the gates.**

   The direction is correct: exercise the small cross-gate cold-cache cohort, then validate repaired
   Q04 before allowing Q02 successes to cascade into it. The current R-5 gate is not sufficient.

   Before the 50-pair canary:

   - audit a stratified sample from the challenge's surviving 535 report roots, 516 logs, 75
     work-item IDs with summaries, and 104 with reports;
   - seal a registry-clean, canonical-symbol, dependency-correct cohort;
   - retain every canary log, summary, report, retry signature, and downstream row durably;
   - define numerical stop/go criteria for `summary_missing`, launch faults, queue multiplication,
     terminal health, and measured verdict yield.

   Fifty observations around the historical 73.8% rate have an approximate 95% sampling
   half-width of 12 percentage points even before heterogeneity and selection bias. Treat 50 as an
   operational smoke canary, then use at least one larger staged batch before releasing the
   remainder. “Watch the rate” is not an acceptance criterion.

8. **Correct WP-4 in the plan.**

   The exact historical selection is 262, not 254: Q02 242, Q03 11, Q04 4, Q06 1, Q08 4. Remove
   the blanket statement that `trades == 0` at Q05/Q06/Q07 is infrastructure. A clean, completed
   report with zero trades is a valid frequency rejection; malformed/no-history/zero-bars evidence
   is already separated by `summary_invalid_reason`.

9. **Close or explicitly gate the remaining challenge findings.**

   The plan records but does not operationally close the live-binary provenance issue. Eleven live
   sleeves predate both kill-switch path fixes, and WP-11 is not specified. The programme must not
   claim KS safety restored merely because baseline files exist. Q03 evidence-path loss mentioned
   in WP-3 is also not repaired by the verdict-reason backfill and needs a separate disposition.

### Operational stop

The required quiescent state was false during this review. At approximately 09:25 UTC I observed
active Q07 runners on T2 and T7, two `run_smoke.ps1` children, and two `metatester64.exe` processes.
The farm DB mtime advanced at the same time. I did not stop or touch them. No package may be applied
until all factory/backtest writers are demonstrably absent and the DB remains stable across a
quiescence interval.

## 2. Per-work-package verdicts

| WP | verdict | blocking defects |
|---|---|---|
| WP-2 aggregate ingester | **CHANGES-REQUIRED** | Idempotency is not atomic; a concurrent second apply or terminal-worker finish can double-insert. The supersede row is not safe for all consumers. Setfile recovery reads mutable summary provenance and already selects the wrong symbol's setfile for QM5_12567/XNGUSD; Q04 would fall back to empty for every current aggregate. Schema work precedes the snapshot and there is no guarded `--revert`. |
| WP-3 verdict-reason unification | **APPROVE** | No blocking code defect found. Apply only after real quiescence and a full DB backup; record the residual NULL population after the sibling-key backfill. |
| WP-4 ACTIVE_TIMEOUT | **APPROVE** | No blocking code defect found. The exact 262-row cohort and the 23-row exclusion are correct. Apply only after real quiescence and re-count immediately before the snapshot. |
| WP-6 sleeve-stream repair | **CHANGES-REQUIRED** | The “refusal” accepts a partial or unrelated volatile stream once it has 20 volume-bearing rows; it does not bind count or lineage to Q08 evidence. Existing five terminal rows are never requeued by this package. Stream replacement is non-atomic and the new aggregate undercount branch has no direct regression test. |

### WP-2 — CHANGES-REQUIRED

#### Idempotency

A normal sequential second `--apply` is a no-op: the inserted payload preserves
`generated_at_utc`, and the next plan sees an equal timestamp. The dry-run reproduced the claimed
current plan:

- 20 new PASS;
- 3 new INVALID;
- 1 PASS supersede (QM5_20048/XTIUSD);
- 6 skipped equal/newer DB pairs.

But the key is implemented only as a read-time comparison. `apply()` plans through a read-only
connection, closes it, opens a writable connection, and inserts without re-checking
(`ingest_phase_aggregates.py:411-450`). There is no unique constraint on
`(ea_id, symbol, phase, generated_at_utc)`. Two simultaneous applies can both plan fresh UUIDs and
both commit. A terminal worker finishing between plan and insert creates the same race.

Required fix: begin one write transaction (`BEGIN IMMEDIATE` while the factory is off), recompute or
revalidate the plan inside it, and enforce a durable uniqueness key. A generated timestamp alone
should also be paired with an immutable evidence hash so a rewritten aggregate at the same timestamp
is detected rather than silently skipped.

The tool does not literally UPDATE a terminal-worker row. It can still semantically shadow one by
inserting a newer row that downstream treats as authoritative.

#### Supersede branch

`ftmo_qualification._latest_phase_row` is safe for the current insert: it orders done rows by
`updated_at`, `created_at`, and ID, so the ingested row becomes the latest.

Not every consumer does that. `agent_router.sync_q11_candidates` iterates every done Q10 PASS and
keys `portfolio_candidates` by the Q10 work-item ID. With the old and new QM5_20048 PASS rows it can
create two candidate rows for one pair. `render_cockpit.q12_review_ready_count()` and its frontier
use `COUNT(*)`/row lists, so those duplicates inflate the OWNER frontier even though
`portfolio_common.read_candidates()` later deduplicates the trading key.

Required fix: either do not insert a supersede when the existing terminal row already carries the
same terminal verdict, or harden every promotion consumer to select one latest Q10 row per
`(ea_id, symbol)` and represent explicit supersession.

#### INVALID taxonomy

This part is correct. `NON_TERMINAL_VERDICTS` contains `INVALID` and `INFRA_FAIL`; `_build_rows`
preserves the literal verdict, sets status `failed`, and writes the same verdict to `ea_metrics`.
There is no `INVALID -> FAIL` conversion.

#### Setfile provenance

An empty string satisfies SQLite's `NOT NULL` constraint but not the work-item contract. Dispatch,
repair, audit, and cascade code expects a real path. A completed archival row might sit harmlessly
for a while, but any later rerun/repair through that row fails setfile preflight.

The current Q10 apply is not fully clean either. For QM5_12567/XNGUSD the aggregate points to a
shared summary that was later overwritten by the XAUUSD run. `_resolve_setfile()` therefore returns:

`QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_q10_confirmation.set`

for the XNGUSD row. The XNGUSD aggregate's own `report_htm` directory contains `tester.ini` with the
correct XNGUSD setfile. This demonstrates why mutable `summary_path` is not safe provenance.

Required fix: resolve from an immutable aggregate field or the aggregate-linked report/tester
identity, validate EA/symbol/hash, require the path to exist, and refuse the row if identity cannot
be proved. For Q04, follow and cross-check fold summaries or have WP-7 add immutable aggregate-level
setfile identity.

#### Rollback

`ea_metrics.ensure_schema(conn)` runs and commits before `_write_snapshot()`. On a DB requiring a
schema migration, the first mutation therefore precedes the snapshot. The snapshot contains inserted
IDs and makes a manual delete possible, but the tool has no guarded `--revert`, and it does not
cover downstream candidate rows that could be created after ingestion.

Move schema validation/migration into a separately snapshotted migration, add a guarded revert, and
keep all consumers stopped until the no-op second dry-run and downstream checks pass.

### WP-3 — APPROVE

The two `terminal_worker.py` calls are deliberate, necessary, and safe:

- they run only on the two terminal missing-summary/cap-exhausted paths that populate sibling keys;
- `_ensure_verdict_reason` mutates only the already-local payload dictionary;
- it preserves any non-empty existing reason;
- its order `final_failure -> prior_failure -> transient_infra_signature` correctly favors the final
  terminal diagnosis;
- the existing transaction, status, verdict, retry, and claim behavior is unchanged.

The matching farmctl terminal paths are covered as well. Other `prior_failure` assignments found in
the worker are pending/release state, not terminal verdicts.

Replacing `test_q08_invalid_gate_report_remains_infra_fail` is legitimate. The replacement retains
the old protection (`INVALID` remains `INFRA_FAIL`) and strengthens it by asserting the preserved
sub-gate reason. It also adds blocking-gate preference and generic fallback coverage. Actual
aggregates use the tested shapes: for example, Q08 8.5 carries
`neighborhood_evidence_lineage_invalid...` and 8.7 carries
`insufficient_distinct_configs...`.

The backfill is reversible as written:

- snapshot stores the exact prior `payload_json`;
- apply guards on exact prior payload;
- revert reconstructs and guards on the exact sorted post-payload;
- SQL updates only `payload_json`;
- the live DB has no UPDATE trigger, so `updated_at` is genuinely untouched.

The dry-run found 48,427 candidates when executed; the DB was moving, so that is not a sealed apply
count. After the sibling-key backfill, historical NULL reasons will not literally be near zero:
a snapshot query found 19,561 terminal rows with neither canonical reason nor sibling source,
18,995 of them ordinary PASS rows and roughly 556 adverse/administrative rows. This is not a blocker
for the ratified sibling-key repair, but the apply report must state the residual rather than claim
universal historical unification.

No dedicated unit test was added for apply/revert or for the two new terminal-worker reason
assertions. The existing terminal-worker and taxonomy suites passed, but adding those direct
assertions is advisable before restart.

### WP-4 — APPROVE

At the `2026-07-25T09:32:58.652Z` read snapshot, the exact selection was:

| phase | rows | distinct pairs |
|---|---:|---:|
| Q02 | 242 | 117 |
| Q03 | 11 | 10 |
| Q04 | 4 | 4 |
| Q06 | 1 | 1 |
| Q08 | 4 | 4 |
| **total** | **262** | — |

All 262 were `status='failed'`. The plan's 254 omitted Q04 and Q08.

The 23 excluded rows are correctly excluded:

- 18 Q02 rows now carry real minimum-trade verdicts;
- 5 Q04 rows now carry real fold PF/trade verdicts;
- all are `status='done'`.

`ACTIVE_TIMEOUT` remains only in their historical `reason_classes`; their canonical
`verdict_reason` records the later merit verdict. Reclassifying them would resurrect genuine
strategy failures.

The live reaper change is minimal and correct: only `FAIL` becomes `INFRA_FAIL`; status, reason
payload, kill evidence, and timing behavior remain intact.

The backfill snapshots the exact payload and prior/new verdict, guards apply and revert on both
verdict and exact payload, and updates only `verdict`. There are no DB triggers, so `updated_at`
does not change.

Declining a blanket zero-trade rewrite is correct. `summary_invalid_reason` already marks
NO_HISTORY, BARS_ZERO, EMPTY_EXPERT, M0/1970, invalid runs, missing/invalid reports, and related
harness failures as INVALID. If a report ran cleanly and produced zero trades, the strategy failed
the frequency criterion. Existing Q05/Q07 tests explicitly cover both sides of that boundary.

One consistency caveat: 42 of the selected work items have an `ea_metrics` row, including 11 whose
metric verdict is still FAIL. `work_items` is the authoritative latest-state source and
`ea_metrics` is already a historical/stale archive in many places, so this does not block the
backfill. The apply report should nevertheless disclose it, or a separately snapshotted metrics
refresh should reconcile those rows.

### WP-6 — CHANGES-REQUIRED

#### Root cause

The filesystem divergence is real:

| copy | TRADE_CLOSED rows | volume-bearing rows |
|---|---:|---:|
| durable `10911_GDAXI_DWX.jsonl` | 331 | 331 |
| volatile Common-file copy | 40 | 40 |

Only 5 of the volatile 40 `(time, net, volume, symbol)` records match the durable 331, so the
volatile copy is not a simple prefix of the durable run.

The structural mechanism is also real: Q08 and Q04 use the same per-EA/symbol Common-file name;
Q08 clears it before a fresh baseline, Q04 clears it before every fold, and other backtests can
rewrite it. The old exporter then `shutil.copyfile`d that shared file but returned
`n=len(raw_trades)` regardless of the copied file's row count.

One causal detail cannot be proved from surviving evidence: `run_all()` persists its stream before
its own synchronous `_ensure_sub_gate_inputs()` call. Therefore the same invocation's later
perturbation cannot corrupt the copy before persistence. The historical partial capture requires a
concurrent/other-gate overwrite, duplicate run, or stale host fallback. The relevant old Q08
aggregates/logs for the five rows are purged, so the exact historical interleaving is unavailable.
The shared-file defect and silent count lie are proven; the exact writer of the bad historical copy
is not.

#### Refusal paths are unsafe

`_reexport_short_sleeve_stream()` checks only:

- authoritative count is at least the floor; and
- a candidate source has at least 20 TRADE_CLOSED rows with a `volume` key.

It does **not** require the source count to equal the authoritative Q08 count, and it does not bind
the source to the same build, setfile, report, or aggregate lineage.

I reproduced the defect in a temporary test: with `evidence_trade_count=296`, a 10-row destination,
and an unrelated 40-row volume-bearing volatile source, the function returned
`repaired=true`, copied all 40 rows, and labeled it `reexported_from_q08_evidence`.

That is precisely the cited 10911 shape: the payload says 296 while the volatile source has 40.
This path does not refuse; it launders a partial/foreign run into a real Q09 verdict.

Required fix:

- accept only an immutable Q08-linked stream whose validated trade count equals the authoritative
  aggregate count and whose EA/symbol/build/setfile identity matches;
- do not treat unbound Common Files as durable evidence;
- copy through a temporary file, validate the complete destination, then atomically replace;
- catch validation/load errors and return `NEED_MORE_DATA`, never a partial destination or an
  uncaught parser exception;
- add tests for undercount, overcount, same-count/wrong-lineage, malformed volume, copy failure, and
  atomic replacement.

The aggregate-time repair should likewise treat **any** count mismatch as a reason to serialize the
authoritative in-memory list when it has valid volume, not copy an over-count or equal-count foreign
file. Add a direct test for its new undercount branch; none exists in the current diff.

#### Existing five rows are not repaired by the package

All five known Q09 rows remain terminal `NEED_MORE_DATA`, and the normal Q08-to-Q09 promotion uses
`NOT EXISTS` on any Q09 row. WP-6 adds no snapshot-backed requeue/backfill.

Their current durable streams now contain 33, 90, 92, 331, and 94 rows respectively—already above
the 20-row floor—but all five linked Q08 aggregate paths have been purged. Re-running the old rows
would therefore grade mutable newer streams, not necessarily their original Q08 evidence.

Add an explicit, dry-run-default, reversible requeue tool. It must bind each requeue to validated
current Q08 evidence or refuse it. A code deployment alone does not meet the five-pair acceptance
criterion.

#### HTML report exclusion

Excluding the current MT5 HTML fallback is sound. The present parser does not provide trustworthy
per-trade volume, while the portfolio commission model requires volume. Inventing zero volume would
silently undercharge costs. HTML can become a source only after a separately reviewed parser proves
volume and trade identity.

## 3. Apply order

There is **no approved apply sequence for all four packages** in their current form. WP-2 and WP-6
are blocked. WP-3 and WP-4 may be applied only after quiescence is real.

Recommended order after the required repairs:

1. **Quiesce and seal.**

   Verify no `terminal_worker.py`, Q-runner, `run_smoke.ps1`, factory terminal, metatester, pump, or
   other DB writer remains. Confirm the DB file/WAL is stable across an observation interval. Take a
   full SQLite backup plus hashes, then take each tool's semantic snapshot.

2. **Install the reviewed WP-3 and WP-4 write-time code while workers remain down.**

   Run the targeted tests. Do not start the factory yet.

3. **Apply WP-3 backfill.**

   Immediately check:

   - changed + skipped equals the snapshotted candidate count;
   - second dry-run has zero sibling-key candidates;
   - Q02's histogram exposes `summary_missing_retries_exhausted`;
   - `updated_at` hashes/counts are unchanged;
   - the residual NULL/no-sibling population is reported honestly;
   - snapshot JSON is readable and its guarded revert is testable on a DB copy.

4. **Apply WP-4 backfill.**

   Recompute rather than assume 262. Then check:

   - no `work_items` row remains `FAIL` with canonical reason `ACTIVE_TIMEOUT`;
   - exactly the snapshotted rows became `INFRA_FAIL`;
   - the 23 reason-classes-only rows remain unchanged;
   - payload and `updated_at` remain byte-identical;
   - stranded/requeue eligibility is recomputed rather than assumed.

5. **Apply the corrected WP-2 Q10 ingest.**

   Before apply, require an atomic idempotency constraint/recheck, validated setfile identity, safe
   supersede semantics, and guarded revert. Then check:

   - 20 PASS + 3 INVALID new rows and the explicitly resolved 20048 conflict;
   - every setfile exists and matches EA/symbol/report identity;
   - every work item has exactly one matching metrics row;
   - no pre-existing work item changed;
   - a second dry-run is empty;
   - Q10/portfolio consumers remain one-row-per-pair where they claim that contract;
   - FTMO is rerun with the expected result: the challenge found 0/20 otherwise strict-ready, so
     ingestion must not be reported as 20 new challenge-ready candidates.

6. **Deploy corrected WP-6, then use its new snapshot-backed requeue tool.**

   Start with one validated canary. Verify source count and lineage equal the Q08 aggregate, the
   durable write is atomic, and Q09 produces a real verdict from that exact stream. Proceed with the
   remaining rows only after the canary; do not “repair” from an unbound Common-file stream.

Only after all post-checks pass should the broader programme's factory restart/requeue sequence be
considered.

## 4. Anything not verified

- I did not execute any apply or revert path, as required. Sequential WP-2 no-op behavior and
  WP-3/WP-4 reversibility were verified from code and dry-runs, not by mutating the live DB.
- The DB was not sealed because external Q07/backtest activity was present. Counts are timestamped
  observations and must be recomputed at apply time.
- WP-7 does not exist in this worktree, so its final durable root and aggregate schema cannot be
  verified. I could only test WP-2 against the two roots it currently scans and current Q04
  aggregate shape.
- The exact historical writer/interleaving that produced each old short Q08 stream cannot be
  reconstructed because all five linked Q08 aggregates are purged.
- Targeted modified-path tests passed: 145 tests across taxonomy, portfolio contribution,
  terminal-worker storm handling, Q08 aggregation, and Q05/Q07 grading; the four timeout-focused
  basket tests also passed.
- The combined selected suite had 157 passes and 3 failures in untouched basket dispatch tests.
  Those failures are stale `FakeProc`/process-identity mocks outside the WP-4 diff, not failures of
  the ACTIVE_TIMEOUT change. Therefore a fully green enclosing test file was not established.
- No live chart, live terminal state, or `C:\QM\mt5\T_Live` content was inspected.

