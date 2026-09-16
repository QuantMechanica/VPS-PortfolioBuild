# RECEIPT — Q08 batch-2 build-identity repair (V2 pattern) — 2026-09-16

- Decision: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916` (parent `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`; D1 receipt `d59b2277`)
- Continuation of D1 and of batch-1 (`../repair_fresh_enqueue/RECEIPT.md`): batch-2's 8 cards were
  still unamended (D1 STOP honored) and their staged Q08 rows carried NULL build identity
  (`BUILD_IDENTITY_MISMATCH:mq5`). This run applies the batch-1 pattern to the 8 batch-2 rows only:
  governed card amendment + append-only **disposition** (supersede) of each staged row + **fresh Q08
  enqueue from the done/PASS Q07 predecessor** with the current-build binding.
- Executed by Kimi (interim OWNER delegation). No verdict was overwritten; no card was re-amended
  twice; batch-1 cards and the 5 excluded EAs are byte-untouched (attested below).

## 1. Step-1 staged-amendment re-verification (read-only) — PASS 8/8

All 8 batch-2 cards byte-unamended since D1 stopped: live sha256 == manifest `card_sha_before`,
no `qm-dsr-single-configuration` block, staged `.AMENDED.staged.md` == manifest
`card_sha_after_staged`, DB rows pending / unclaimed / not superseded / no holds.
Evidence: `step1_staged_match.json` (+ script). Q07 landscape captured at the same time
(batch-2 watch: QM5_10269 → Q07 `3b1011e4` done/PASS 2026-09-16T01:51Z, QM5_10280 → Q07 `9a8d31a6`
done/PASS 2026-09-16T02:42Z — both completed TODAY; the fresh PASS rows are the bound predecessors).

## 2. Amendment (governed `q08_single_config_amend_0914.py`, constants already V3) — APPLIED 8/8

Dry-run `batch2_dryrun.txt` (8 ok) → apply `batch2_apply.txt` (8 ok; journal continues in
`../card_amend_journal.jsonl`). D: card is the source of truth (no C: mirror exists for these
cards — identical to batch-1). Applied bytes differ from the staged files ONLY in the authority
citation (staged = V2/2026-09-14/3415f6c0 built at staging time; applied = V3/2026-09-16/d59b2277);
the ```qm-dsr-single-configuration``` declaration block is byte-identical (verified per card).

Post-amend proofs `batch2_proofs.json` — all 8: live hash == journal `card_sha_after` (chained from
manifest before-hash); declaration() correct (candidate/spec/locked-parameters == effective(mq5,set),
truth flags); precheck on the staged rows = `BUILD_IDENTITY_MISMATCH:mq5` (the known D1-class
defect to be repaired below); factory-search clean; full assemble() with `claimed_at_iso` refuses
ONLY at the build-identity gate.

Rows: 456f590f/QM5_10287, ff0b551b/QM5_9576, a591ff4c/QM5_1230, 885b82ab/QM5_9973,
bb5eccf7/QM5_13012, 1494bfb4/QM5_11882, b11e5b43/QM5_10269, aec37e79/QM5_10280.

## 3. Dispositions (append-only, `q08_repair_dispositions_0914.py` PLAN repointed to batch-2) — APPLIED 8/8

ALL 8 batch-2 rows had an existing pending Q08 row (NULL identity columns), so per the task
instruction dispositions ran FIRST for the whole batch, before any enqueue. Tool changes
(path-scoped commit): PLAN → the 8 batch-2 prefixes; EVID/TASK_ID → this dir / d1-batch2; the
online SQLite backup moved INSIDE the mutation lock (backup-before-lock lost the lock race
repeatedly against the live compile wave and burned a 1.2 GB backup per failed attempt; under-lock
backup is strictly more consistent and eliminated the race — applied 8/8 on the next attempt).
Dry-run `dispositions_dryrun.txt`; apply `dispositions_apply.txt`; receipt
`dispositions_receipt.json` (8 rows; backup `farm_state_before_q08_repair_dispositions_20260916T115758Z_a43076e6.sqlite`).

Result per row: original stays `pending`/NULL verdict (never edited); one `kind='disposition'`
row (`failed`/`SUPERSEDED_REPAIR`) + one `work_item_supersedes` edge. Verified live for all 8.

## 4. Fresh enqueue from Q07 predecessor (governed `farmctl enqueue-backtest`) — 8/8

Read-only preflight mirror `fresh_enqueue_preflight.txt` (all gates pass; Q07 done/PASS +
same setfile + artifact-failure=None + bindings ok; `q07_predecessor_map.json`,
`ea_current_build_hashes.json`). Each enqueue used the ex5 sha256 computed from disk at call time.

| old row | EA | Q07 predecessor (done/PASS) | new work-item id |
|---|---|---|---|
| 456f590f | QM5_10287 | 176bd347 NDX.DWX 09-15 | e1c0d6c1-1108-4974-ba3b-0a0bab7bfe9c |
| ff0b551b | QM5_9576 | ed61aeac NDX.DWX 09-15 | 3043d412-a1a9-4330-9442-3b1c6ffb61dc |
| a591ff4c | QM5_1230 | 531d5f03 NDX.DWX 09-15 | db1da509-e2f5-4fc8-8e5d-09a35b43a10b |
| 885b82ab | QM5_9973 | 33044e80 NDX.DWX 09-15 | aa660882-a200-4663-8441-f8e1ebdebcee |
| bb5eccf7 | QM5_13012 | 41def8d1 GDAXI.DWX 09-15 | bc626c1f-5674-454c-92d4-8d6172eb1f1b |
| 1494bfb4 | QM5_11882 | cd38e969 NDX.DWX 09-15 | 8dac9856-3790-41ab-bea9-92c9a445caab |
| b11e5b43 | QM5_10269 | **3b1011e4 NDX.DWX 09-16 (today)** | 12d85591-6842-4255-a305-09507056a982 |
| aec37e79 | QM5_10280 | **9a8d31a6 NDX.DWX 09-16 (today)** | d3f0090c-50e6-43f2-a6cb-6ecf6c109c78 |

Batch-2 watch honored: 10269/10280 are bound to the Q07 rows that completed TODAY
(01:51Z / 02:42Z), not to older same-symbol rows. Per-EA enqueue outputs: `fresh_enqueue_QM5_*.json`
(all `enqueued: true`, `skipped_count: 0` — the superseded staged rows were ignored by dedupe).
`old_to_new_map.json` has the full id map.

## 5. Five-proof gate on the NEW rows — PASS 8/8

`proof_gate_new_rows.json` (+ `../batch2_proofs.json` for the amendment side):

| proof | result |
|---|---|
| (a) card hashes | **PASS 8/8** — live card sha256 == journal `card_sha_after` |
| (b) declaration correctness | **PASS 8/8** — declaration() parses; candidate (ea_id/symbol/timeframe), `spec_sha256`, `complete`, `no_optimization_search`, `research_trial_count=0`; `locked_parameters` == `effective_parameters(mq5,setfile)` |
| (c) claimability_precheck | **PASS 8/8** — every new row `claimable` (staged rows were `BUILD_IDENTITY_MISMATCH:mq5`) |
| identity bound to current | **PASS 8/8** — new-row `mq5/ex5/setfile_sha256` columns AND payload `expected_*`/`artifact_identity` byte-equal to current canonical disk hashes |
| lineage | **PASS 8/8** — payload `promoted_from_phase='Q07'`, `promoted_from_work_item` == bound Q07 |
| (d) factory-search | **PASS 8/8** — `_factory_search_before_q08_claim` CLEAN (0 optimization rows) |
| holds on new rows | **0 active** for all 8 |

## 6. Wiki — ZERO_D1_ATTRIBUTABLE_DRIFT cohort standard — PASS

`wiki_build_batch2.txt`: governed `build --only` refreshed all 8 nodes after the amendment
(first run written=1, then written=0/skipped=1 — FRESH). `wiki_lint_batch2.json`:

- All 8 nodes: missing=0, duplicate=0, orphan=0, invalid_link=0, unresolved_source=0,
  unresolved_lineage=0, **card_hash_current=true** (node carries the amended card hash).
- 7/8 not stale (strict lint model). **QM5_9576** reads stale under lint — diagnosed as a
  PRE-EXISTING tool asymmetry, NOT D1-attributable: `build()` folds the second-chance register
  into `inputs_sha256`; `lint()` omits it. 9576 is a REJECTED-class node with a register entry,
  so the two models disagree forever. Proof: digest WITH register = `5740ec2e…` == exactly what
  is on disk (governed writer's own output, skipped=1 idempotent); digest WITHOUT (lint model) =
  `2b2550a2…`. No action of the repair can make lint see it fresh; per the OWNER clarification
  (unrelated stale historical nodes do not block; no D1-attributable drift) this is recorded, not
  a STOP. Follow-up for OWNER/Fable: fix the build/lint second-chance asymmetry in
  `strategy_wiki_sync.py` (out of batch-2 scope; no recursive patching).
- Ambient lint: **AMBER** (stale 1285, missing 0) — the unrelated historical REJECTED backlog.

## 7. Holds

**None — 0 releases.** None of the 8 staged rows carried a hold (verified step 1); none of the 8
new rows has an active hold (verified in the proof gate). The 40 unrelated active Q08_DSR holds
were not touched.

## 8. Worker claims (poll, no manual claims)

`poll_claims.py` (10 s interval over ~15 min; terminal via `claimed_by` / run-summary, PID via
`farmctl mt5-slots`). Full detail: `claims_result.json` / `poll_claims.log` / `claims_snapshots.json`.

| new id | EA | claim status | terminal | PID |
|---|---|---|---|---|
| e1c0d6c1 | QM5_10287 | **claimed in-window, actively running** (whole 15 min window) | T6 | 21736 |
| 3043d412 | QM5_9576 | **claimed in-window, actively running** (whole 15 min window) | T3 | 4628 |
| db1da509 | QM5_1230 | pending — claimable, queued behind farm Q08 capacity | — | — |
| aa660882 | QM5_9973 | pending — claimable, queued | — | — |
| bc626c1f | QM5_13012 | pending — claimable, queued | — | — |
| 8dac9856 | QM5_11882 | pending — claimable, queued | — | — |
| 12d85591 | QM5_10269 | pending — claimable, queued | — | — |
| d3f0090c | QM5_10280 | pending — claimable, queued | — | — |

**2/8 claimed within the window** (both live-active from before the first poll tick at 12:26Z
through the end of the window; neither finished inside it — Q08 runs are long full-history +
Monte-Carlo). PIDs are the terminal_worker daemon PIDs for T6/T3 (from process command lines;
`mt5-slots` did not map the work-item ids at capture time). The other 6 are `claimable` per
`claimability_precheck` but remain `pending` behind the farm-wide Q08 backlog — queued, not
refused (same pattern as batch-1's 6/8).

**Post-poll development (12:41:48Z, 17 s after the poll closed):** QM5_10287 (`e1c0d6c1`)
completed end-to-end — **done / FAIL_HARD, DSR context SEALED**, evidence
`D:\QM\reports\work_items\e1c0d6c1-…\aggregate.json`, run summary T6 12:41:46Z. Identical shape
to batch-1's first completion (`61ddcbdd` FAIL_HARD): a genuine executed verdict on the repaired
path, not a repair defect. QM5_1230 (`db1da509`) was additionally claimed by T7 after the poll
window. State at final check: 1 done (FAIL_HARD, SEALED), 2 active (9576/T3, 1230/T7),
5 pending-claimable queued.

## 9. Hard boundary

`hard_boundary_untouched.json`: excluded-5 (QM5_10145, QM5_12350, QM5_12361, QM5_1551, QM5_12484)
live hashes == D1 baseline (5/5); batch-1 cards (8/8) unchanged at their journal
`card_sha_after`. No verdict writes anywhere (append-only disposition rows only). No scope
inference was made.

## 10. Newly claimable rows

**8/8** fresh Q08 rows claimable (proof 5c) — the batch-2 repair success criterion. 2/8 claimed
in-window by workers; the remaining 6 are queued behind farm-wide Q08 throughput (same pattern as
batch-1, where 6/8 queued and 1 completed end-to-end).

## Evidence index

`step1_staged_match.py/.json` · `batch2_dryrun.txt` · `batch2_apply.txt` · `batch2_proofs.py/.json` ·
`dispositions_dryrun.txt` · `dispositions_apply.txt` · `dispositions_receipt.json` ·
`q07_predecessor_map.json` · `ea_current_build_hashes.json` · `fresh_enqueue_preflight.txt` ·
`fresh_enqueue_QM5_*.json` (8) · `old_to_new_map.json` · `proof_gate_new_rows.py/.json` ·
`wiki_build_batch2.txt` · `wiki_lint_batch2.json` · `wiki_cohort_check.py` ·
`hard_boundary_untouched.json` · `poll_claims.py/.log` · `claims_result.json` ·
`claims_snapshots.json` · SQLite backup `farm_state_before_q08_repair_dispositions_20260916T115758Z_a43076e6.sqlite`
