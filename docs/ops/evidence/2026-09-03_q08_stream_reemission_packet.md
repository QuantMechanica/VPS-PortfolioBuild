# Q08 Sealed-Stream Re-Emission Packet (4 qualified pairs, missing bytes)

Date: 2026-09-03
Author: Claude (Orchestrator), read-only preparation
Scope: PREPARE-ONLY. This packet states the exact governed `farmctl enqueue-backtest`
commands to re-emit the missing current-identity Q08 sealed daily-PnL streams for four
qualified pairs. **The commands are NOT run here.** DB was read strictly `mode=ro`.

## 1. Problem

`tools/strategy_farm/assemble_stream_bundle.py` binds each qualified (EA, symbol) pair to
the sealed Q08 stream of its CURRENT identity and copies it into a book-path bundle
(defect D4 of `docs/ops/evidence/2026-09-03_book_path_rehearsal_5pair_pool.md`). Its
binding contract is fail-closed (`assemble_stream_bundle.py:13-24`):

1. Current identity = the `ex5_sha256` that carried the pair's terminal Q14 head-to-head
   verdict (PASS-class: `KEEP_INCUMBENT` / `PROMOTE_CHALLENGER` / `CHALLENGER_PROMOTED` /
   `ADMIT_BOTH`) -- `resolve_identity`, `assemble_stream_bundle.py:53-58,147-166`.
2. The most recent Q08 `done`/`PASS` work item whose `aggregate.json` `portfolio_stream`
   block has `source_ex5_sha256 == identity` pins the sealed `content_sha256` and path --
   `find_bound_q08`, `assemble_stream_bundle.py:183-208`.
3. A physical file whose SHA-256 equals that `content_sha256` must be located on disk;
   otherwise the pair is REFUSED `sealed_stream_bytes_unavailable`, never synthesized --
   `locate_sealed_bytes` / `assemble_pair`, `assemble_stream_bundle.py:229-323`.

Re-run of `assemble_stream_bundle.py` (mode=ro DB, scratch `--out`) over the five-pair
pool returned `bound_count=1, refused_count=4`: only `11421:EURUSD.DWX` bound (bytes
present in `D:\QM\reports\portfolio\sleeve_streams`); the other four refused
`sealed_stream_bytes_unavailable` -- the Q08 `portfolio_stream` block still records
`persisted:true` to `sleeve_streams`, but the physical `.jsonl` was later removed (D:
crisis cleanups), so the recorded `content_sha256` has no matching file on disk.

**Fix:** re-run each pair's Q08 baseline on its CURRENT binary as a governed append-only
rerun. The rerun re-emits the sealed stream; determinism requires it to reproduce the
recorded `content_sha256`; the durable export (`assemble_stream_bundle.py`) or the
backfill CLI then materializes the bytes into the book-path bundle.

## 2. Governed command form (verified guard path)

`--ea` + `--phase Q08` + `--append-only-rerun-of` routes through
`enqueue_cascade_backtest_for_ea` (`farmctl.py:27505`, dispatched at `farmctl.py:33217`),
into the append-only rerun branch (`farmctl.py:27765-27940`). For Q08 the cascade
predecessor is Q07 (`prev_phase`, and `_CASCADE_PASS_VERDICTS_BY_PREDECESSOR["Q07"]={PASS,
MULTI_SEED_PASS}`, `farmctl.py:11690`); `--from-work-item-id` narrows to one exact Q07
`done`/PASS predecessor whose setfile identity the rerun row inherits.

Template (one line per command; substitute per the table):

```
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea <EA> --phase Q08 \
  --from-work-item-id <newest done Q07 PASS/MULTI_SEED_PASS row, current identity> \
  --append-only-rerun-of <newest terminal Q08 row of the current identity> \
  --expected-current-ex5-sha256 <sha256 of framework/EAs/<dir>/<ea>.ex5> \
  --rerun-reason "<audit reason>"
```

Run from `C:\QM\repo` (canonical checkout), NOT a worktree: the binding guard
`_expected_current_execution_bindings` (`farmctl.py:24771-24855`) resolves the EA dir from
the predecessor's setfile and requires it to be the **canonical** EA directory
(`current_execution_binding_not_in_canonical_ea_directory` otherwise, `farmctl.py:24799-
24817`).

## 3. Per-pair binding table

Every pair: current repo `.ex5` sha == Q14 `KEEP_INCUMBENT` identity == Q08 aggregate
`portfolio_stream.source_ex5_sha256`. All three equal (verified below). Present-reference
control `11421:EURUSD.DWX` (already bound, bytes on disk) included for provenance.

| Pair | EA dir | current ex5 = Q14 identity = Q08 source_ex5 | Q14 KEEP_INCUMBENT id | `--from-work-item-id` (Q07 PASS) | `--append-only-rerun-of` (Q08 target) | recorded seal `content_sha256` | stream file (rows/bytes) |
|---|---|---|---|---|---|---|---|
| QM5_1537 / XAGUSD.DWX | QM5_1537_aa-vol-sma10 | `142a019e773a493def0640722efb9d591d094650b35a69d5de39f6af3a048106` | `18859f02-5371-5094-a7a5-b63619482545` | `5e832838-5d29-4405-86b1-b4840eac22cf` | `262514ac-c3c6-4834-9e17-02a42c8878b7` | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` | 1537_XAGUSD_DWX.jsonl (96 / 39136) |
| QM5_10706 / GBPUSD.DWX | QM5_10706_tv-mon-ls | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb` | `b5e18759-1377-5af7-9634-9f66bd293d0c` | `81cd341c-a2c1-4c18-9ec6-6b85f0226080` | `7855588a-9ff8-4896-8d8d-16e1fdc25f72` | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` | 10706_GBPUSD_DWX.jsonl (360 / 149557) |
| QM5_11422 / USDCAD.DWX | QM5_11422_williams-18ma-outside-bar-entry-d1 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `3078ad67-9a19-56cb-a252-0a112596343a` | `474ba0d0-00c1-4672-a14d-a465d635405f` | `d3907c1a-dc69-4498-be2f-80b064a2c02f` | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` | 11422_USDCAD_DWX.jsonl (195 / 80441) |
| QM5_13054 / XTIUSD.DWX | QM5_13054_brent-tom-mom | `2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d` | `4aaa524d-c11a-5725-8de7-f1d00d51eca9` | `fd882da0-8822-427f-9266-1f300154b1d1` | `d62d792e-442a-494b-964f-40963d8365e8` | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` | 13054_XTIUSD_DWX.jsonl (82 / 33657) |
| _11421 / EURUSD.DWX (ref, bound)_ | QM5_11421_ohlc-daily-squeeze-reversal-d1 | `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | `ff733cf6-52a1-5aad-9bff-4f8c31ef4dc6` | _2556a768-... (n/a; bytes present)_ | `c93263aa-a707-45ea-a915-204ec59df077` | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` | 11421_EURUSD_DWX.jsonl (91 / 37522) |

Setfile identity (inherited from the Q07 predecessor; must exist, verified present in the
canonical checkout):

- QM5_1537:  `framework/EAs/QM5_1537_aa-vol-sma10/sets/QM5_1537_aa-vol-sma10_XAGUSD.DWX_D1_backtest.set`
- QM5_10706: `framework/EAs/QM5_10706_tv-mon-ls/sets/QM5_10706_tv-mon-ls_GBPUSD.DWX_H1_backtest_ablation_02.set`  (ablation_02 -- the canonical stream binding; Q07 `81cd341c` and Q08 `7855588a` share it)
- QM5_11422: `framework/EAs/QM5_11422_williams-18ma-outside-bar-entry-d1/sets/QM5_11422_williams-18ma-outside-bar-entry-d1_USDCAD.DWX_D1_backtest.set`
- QM5_13054: `framework/EAs/QM5_13054_brent-tom-mom/sets/QM5_13054_brent-tom-mom_XTIUSD.DWX_D1_backtest.set`

Notes:
- QM5_10706 target `7855588a` is itself an append-only rerun (of `335d9197`) and already
  carries `expected_ex5_sha256 = eaffda6f...` (current identity). Rerunning off it is
  correct: it is the newest Q08 bound to the current identity. The guard looks for
  CHILDREN of the target, not the target's own parent, so its lineage is not a blocker.
- QM5_1537, QM5_11422, QM5_13054 targets predate the current-binary binding convention,
  so their payload `expected_ex5_sha256` is absent; their identity binding lives in the
  aggregate `portfolio_stream.source_ex5_sha256`, which equals the current ex5 for all
  three. The rerun binds the current identity via `--expected-current-ex5-sha256`.

## 4. The four commands (DO NOT RUN)

```
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1537 --phase Q08 --from-work-item-id 5e832838-5d29-4405-86b1-b4840eac22cf --append-only-rerun-of 262514ac-c3c6-4834-9e17-02a42c8878b7 --expected-current-ex5-sha256 142a019e773a493def0640722efb9d591d094650b35a69d5de39f6af3a048106 --rerun-reason "Q08 sealed-stream re-emission: current-identity daily-PnL bytes (content_sha256 1885c21e...) missing from sleeve_streams; append-only rerun to reproduce the seal for the book-path bundle (D4)."

python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10706 --phase Q08 --from-work-item-id 81cd341c-a2c1-4c18-9ec6-6b85f0226080 --append-only-rerun-of 7855588a-9ff8-4896-8d8d-16e1fdc25f72 --expected-current-ex5-sha256 eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb --rerun-reason "Q08 sealed-stream re-emission: current-identity daily-PnL bytes (content_sha256 71fb35b8...) missing from sleeve_streams; append-only rerun to reproduce the seal for the book-path bundle (D4)."

python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_11422 --phase Q08 --from-work-item-id 474ba0d0-00c1-4672-a14d-a465d635405f --append-only-rerun-of d3907c1a-dc69-4498-be2f-80b064a2c02f --expected-current-ex5-sha256 2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66 --rerun-reason "Q08 sealed-stream re-emission: current-identity daily-PnL bytes (content_sha256 7ce6cc3e...) missing from sleeve_streams; append-only rerun to reproduce the seal for the book-path bundle (D4)."

python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_13054 --phase Q08 --from-work-item-id fd882da0-8822-427f-9266-1f300154b1d1 --append-only-rerun-of d62d792e-442a-494b-964f-40963d8365e8 --expected-current-ex5-sha256 2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d --rerun-reason "Q08 sealed-stream re-emission: current-identity daily-PnL bytes (content_sha256 67d4fe2c...) missing from sleeve_streams; append-only rerun to reproduce the seal for the book-path bundle (D4)."
```

## 5. Pre-flight verification (all PASS as of 2026-09-03, mode=ro)

Per pair, confirmed against `D:\QM\strategy_farm\state\farm_state.sqlite` (`?mode=ro`) and
the canonical checkout:

- **current ex5 == Q14 KEEP_INCUMBENT binding == Q08 `expected_ex5_sha256`:** the
  `sha256(framework/EAs/<dir>/<ea>.ex5)` in both the worktree and the `C:\QM\repo` main
  checkout equals the Q14 `KEEP_INCUMBENT` `ex5_sha256` (`resolve_identity`,
  `assemble_stream_bundle.py:147-166`) AND the Q08 aggregate
  `portfolio_stream.source_ex5_sha256` (`find_bound_q08`, `assemble_stream_bundle.py:197-
  199`). All three equal per row in the table.
- **predecessor exists with required status:** the `--from-work-item-id` Q07 row is
  `status=done`, `verdict=PASS` (in `{PASS, MULTI_SEED_PASS}`), and shares the target's
  setfile -- satisfies the predecessor query `farmctl.py:27635-27644`.
- **rerun target exists with required status:** each `--append-only-rerun-of` Q08 row is
  `status=done`, `verdict=PASS` (not None), `claimed_by=NULL`, not superseded, and matches
  ea/phase(Q08)/symbol/setfile -- satisfies `target_matches`, `farmctl.py:27770-27779`.
- **no pending/active Q08 row for the pair:** 0 open (`pending`/`active`, non-superseded)
  Q08 rows for each (ea, symbol, setfile) -- `open_row` guard passes, `farmctl.py:27831-
  27851`.
- **no existing rerun of the target:** 0 non-superseded rows with
  `append_only_rerun_of_work_item == <target>` -- `prior_rerun` guard passes,
  `farmctl.py:27803-27830`.
- **setfiles present:** all four predecessor setfiles exist under `C:\QM\repo\...` (the
  `_setfile_path_exists` guard `farmctl.py:27646-27653` and the binding's setfile-file
  check `farmctl.py:24838-24847`).
- **containment disabled:** `D:\QM\strategy_farm\state\custom_history_containment_mode.json`
  = `enabled:false` (reason `ceo_release_after_copy_on_claim_trip4_20260902`), so the
  archive-admission guard `custom_history_archive_admission` (`farmctl.py:27703-27720`)
  is not fail-closed on containment.

## 6. Which guards could refuse (and why they do not here)

The append-only Q08 rerun branch (`farmctl.py:27765-27940`) can refuse (row appended to
`skipped`, nothing created) for:

1. `append_only_rerun_requires_exact_predecessor_work_item_id` (`farmctl.py:27559-27565`)
   -- `--append-only-rerun-of` without `--from-work-item-id`. Both supplied -> OK.
2. `append_only_rerun_requires_reason` (`farmctl.py:27566-27572`) -- missing
   `--rerun-reason`. Supplied -> OK.
3. Empty predecessor set (`farmctl.py:27635-27644`) -- if `--from-work-item-id` is not a
   Q07 `done` row with verdict in `{PASS, MULTI_SEED_PASS}`, `prev_rows` is empty and the
   command is a silent no-op (`created=[]`). Our Q07 ids are all PASS -> OK.
4. `missing_setfile` (`farmctl.py:27646-27653`) -- predecessor setfile absent. Present ->
   OK.
5. `custom_history_archive_admission` failure (`farmctl.py:27703-27720`) -- archive years
   for the symbol not admitted / containment engaged. Containment off; these pairs ran Q08
   under the same archive recently -> expected OK (live check at enqueue time).
6. `append_only_rerun_target_mismatch_or_not_terminal` (`farmctl.py:27780-27786`) --
   target missing, wrong ea/phase/symbol/setfile, not `done`/`failed`, null verdict, or
   claimed. All targets are done/PASS/unclaimed/matching -> OK.
7. `_expected_current_execution_bindings` refusals (`farmctl.py:27792-27801` ->
   `24771-24864`): `expected_current_ex5_sha256_required_or_invalid` (not 64-hex),
   `setfile_not_bound_to_exact_ea_directory`,
   `current_execution_binding_not_in_canonical_ea_directory` (run from a worktree, not
   `C:\QM\repo`), `current_artifact_missing` (mq5/ex5/setfile absent), or
   `current_ex5_hash_mismatch` (repo ex5 != `--expected-current-ex5-sha256`). All four
   ex5 hashes match the current canonical binary -> OK **provided the command runs from
   `C:\QM\repo`**.
8. `append_only_rerun_already_exists` (`farmctl.py:27803-27830`) -- a non-superseded prior
   rerun of the same target. None exist -> OK. (Re-running any of these commands twice
   trips exactly this guard the second time -- the rerun is idempotent, not duplicative.)
9. `already_pending_or_active` (`farmctl.py:27831-27851`) -- an open Q08 row for the pair.
   None -> OK.

`work_item_supersedes` semantics: guards 8-9 ignore superseded rows
(`NOT EXISTS (... work_item_supersedes ...)`), so a historically superseded Q08 does not
block; the chosen targets are themselves NOT superseded.

## 7. Expected outcome

Each command appends exactly one `pending` Q08 `backtest` work item (`farmctl.py:27874-
27897, 27934-27939`) carrying `append_only_rerun:true`,
`append_only_rerun_of_work_item:<target>`, `historical_work_item_preserved:true`,
`expected_current_ex5_sha256:<ex5>`, the current-binary artifact/symbol/period bindings
(`farmctl.py:27852-27873`), and `timeout_min>=120` (Q08 active budget 120 min,
`PHASE_ACTIVE_TIMEOUT_MIN["Q08"]`, `farmctl.py:612`; applied `farmctl.py:27728-27729`).
The historical terminal Q08 (target) and Q07 predecessor are preserved untouched -- raw
pipeline facts stay immutable (`farmctl.py:27522-27527`).

On execution the aggregator re-runs the full-history Q08 baseline under the current binary
and re-emits the sealed daily-PnL stream to
`...\MetaQuotes\Terminal\Common\Files\QM\q08_trades\<ea>_<sym>.jsonl`, re-persisting it to
`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\`. **Determinism check:** the
re-emitted stream's `content_sha256` MUST equal the recorded seal in the table
(1885c21e / 71fb35b8 / 7ce6cc3e / 67d4fe2c). A match confirms determinism and the bytes
are materialized; the durable export
(`assemble_stream_bundle.py --pairs ... --out <signed bundle root>`) or the backfill CLI
then binds them into the book-path bundle. A mismatch signals non-determinism or binary/
setfile/history drift and MUST be investigated -- NOT overwritten (verdict logic is ROT).

## 8. Cost class and priority

- **Long-run scheduling class:** `q07_q08_longrun`, fleet cap **2** concurrent Q07/Q08
  long regenerations (`longrun_scheduling_policy.py:31,35,89-91,118-119`). These four are
  ordinary (non-lineage-priority) Q08 rows and share that cap of 2.
- **RAM commit class:** each pair is single-symbol and non-index (bases XAGUSD/GBPUSD/
  USDCAD/XTIUSD are not in `INDEX_TICK_SYMBOL_BASES`, `terminal_worker.py:259`), so the
  reservation class is `ordinary` = **8.0 GB** (`ORDINARY_COMMIT_RESERVATION_GB`,
  `terminal_worker.py:204,221`; `_commit_class`/`_commit_reservation_gb`,
  `terminal_worker.py:872-878,908-917`), with the standard post-reservation RAM floor
  (`RAM_MIN_FREE_GB`, `terminal_worker.py:253-257`). The measured-RAM override only
  displaces the flat class for HEAVY single-symbol runs (measured peak > 10 GB,
  `TESTER_MEMORY_HEAVY_GB`, `terminal_worker.py:268,1189-1193`); these D1/H1 FX/metal/
  energy baselines are not heavy.
- **priority_track:** **NO** -- recommend leaving it unset. `priority_track:true` on an
  append-only lineage rerun grants +1 slot over the Q07/Q08 cap (2 -> 3,
  `LINEAGE_RERUN_Q07_Q08_EXTRA_SLOTS`, `longrun_scheduling_policy.py:44,94-110,192-193`).
  These reruns are behind the optimization census (the counter's critical path) and are
  not on the Q10-lock critical path, so they should not pre-empt census cells or short
  gates. Let them flow within the ordinary cap of 2.

## 9. Provenance / method

- Fast-forward merge of `agents/board-advisor` into this worktree: before
  `a92cda60fe1e62eeee73de6068dd2634dba490d2`, after
  `3c0a7a72d51eb34a00b7e035a494e093d6c1d1a9` (clean fast-forward).
- Facts derived by: `assemble_stream_bundle.py` (mode=ro DB, scratch `--out`) for the
  bind/refuse determination and seal hashes; direct mode=ro reads of `work_items` and
  `work_item_supersedes`; reads of the Q08 `aggregate.json` `portfolio_stream` blocks
  under `D:\QM\reports\work_items\...`; `sha256sum` of the current `.ex5` in the worktree
  and the `C:\QM\repo` main checkout. No farm-DB writes; no enqueue/hold/restart; no
  writes under `D:\QM\reports` (scratch `--out` was a session scratch dir).
