# RECEIPT — Q08 batch-1 build-identity repair (V2 pattern) — 2026-09-16

- Decision: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916` (parent `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`; D1 receipt `d59b2277`)
- Continuation of D1, which stopped at the batch-1 proof gate: the 8 batch-1 cards were amended but their staged Q08
  rows carried NULL build identity, so `claimability_precheck` refused them
  (`SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5`).
- This run executes the established V2 repair pattern for the 8 batch-1 rows only: append-only **disposition**
  (supersede) of each staged row + **fresh Q08 enqueue from the Q07 predecessor** with the current-build binding.
- Executed by Kimi (interim OWNER delegation). No verdict was overwritten; no card was re-amended; batch-2 cards and
  the 5 excluded EAs are byte-untouched (attested below).

## Mechanism (V2 pattern, as sanctioned)

1. `session_tools/q08_repair_dispositions_0914.py` — constants repointed to V3 (`DECISION_ID=OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916`,
   `OWNER_RECEIPT=d59b2277`, `TASK_ID=c4f2a8e1`, evidence dir = this dir). PLAN = the 8 batch-1 rows (class A,
   `SUPERSEDED_REPAIR`, `release_hold=False`). Append-only: one `kind='disposition'` row (status failed, verdict
   `SUPERSEDED_REPAIR`) + one `work_item_supersedes` edge per staged row. Originals never edited. Online SQLite backup
   before the mutation (`FactoryMutationLock`). Commit `27bab3ecc5` (path-scoped, one tool file).
2. `farmctl enqueue-backtest --ea <EA> --phase Q08 --from-work-item-id <Q07 predecessor> --expected-current-ex5-sha256 <current ex5 sha>`
   — the fresh cascade path. Because each staged row now carries a supersedes edge, the enqueue dedupe ignores it and
   creates a NEW pending Q08 row pinned to the CURRENT build (`expected_mq5/ex5/setfile_sha256` + `artifact_identity`
   in payload, and the `mq5/ex5/setfile_sha256` work_items columns stamped from the same current build). Lineage to the
   Q07 predecessor is recorded in `payload.promoted_from_phase/promoted_from_work_item`.

A read-only preflight (mirror of the enqueue gates: `_ea_build_artifact_failure`, Q07 predecessor done/PASS,
`_expected_current_execution_bindings`) passed for all 8 before any live write (`fresh_enqueue_preflight.txt`).

## Per-row result (old staged row -> fresh row)

| old id | new work-item id | EA | symbol | Q07 predecessor | precheck before | precheck after |
|---|---|---|---|---|---|---|
| 7bc8b34e | 61ddcbdd-b632-4115-957d-1f0dceb67a03 | QM5_1159 | NDX.DWX | c10e8ca8 (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| d4aebc12 | 333f014b-38da-4ae0-8d5e-ccc1944569ac | QM5_10804 | GDAXI.DWX | 4a4f3fec (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| 383c45b0 | 8d04ca70-d8fa-4c8e-bc89-25f334fe8df4 | QM5_10661 | GDAXI.DWX | 78cd0453 (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| 20c533da | 1d575bfc-6583-48fb-bc78-c9884c91674d | QM5_10211 | NDX.DWX | dc60a354 (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| a937b9bc | d5a17dbf-3b54-4d4c-a455-0ba05c211894 | QM5_12958 | GDAXI.DWX | 63c2be07 (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| 15fed5d8 | 35ca4b36-7ebf-4d07-9ac5-9a1d3527be6d | QM5_9123 | NDX.DWX | 9834b27e (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| aa0fa828 | e8377ff0-71ae-495a-a5f2-8ca5d0f16800 | QM5_10291 | NDX.DWX | dfad1213 (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |
| 94d46fe7 | 93ac0ce2-771e-4874-b1bf-59c226333423 | QM5_10267 | NDX.DWX | 68d632bd (done/PASS) | BUILD_IDENTITY_MISMATCH:mq5 | **claimable** |

Precheck before = `precheck_before.json` (all 8 failed `BUILD_IDENTITY_MISMATCH:mq5`, the D1 stop condition).
Precheck after = `proof_gate_new_rows.json` (all 8 claimable). Full id map: `old_to_new_map.json`; Q07 predecessors: `q07_predecessor_map.json`.

## D1 five-proof gate on the NEW rows (`proof_gate_new_rows.json`)

| proof | result |
|---|---|
| (a) card hashes | **PASS 8/8** — live card sha256 == journal `card_sha_after` for each EA |
| (b) declaration correctness | **PASS 8/8** — `dsr_single_configuration.declaration()` parses each card; candidate (ea_id/symbol/timeframe), `spec_sha256`, `complete`, `no_optimization_search`, `research_trial_count=0` all correct; `locked_parameters` byte-equal to `effective_parameters(mq5,setfile)` |
| (c) claimability_precheck | **PASS 8/8** — every new row `claimable` (was `BUILD_IDENTITY_MISMATCH:mq5` before) |
| (d) no false-declaration refusal | **PASS 8/8** — `_factory_search_before_q08_claim` CLEAN (0 optimization rows; 13/42/44/15/22/73/453/63 work items examined) |
| (e) wiki sync health | my 8 nodes **FRESH** (governed `build --only` => written=0 / skipped=1 for all 8, `wiki_build_my8.txt`); ambient lint AMBER-class: stale 1286 / missing 1 (`QM5_41480`, not one of ours) — the ambient REJECTED backlog, `wiki_lint_new_rows.json` |

Supplementary (recorded in the proof gate): every new row's build identity (payload `expected_*` + `artifact_identity`
AND the `mq5/ex5/setfile_sha256` columns) is byte-equal to the current canonical EA-dir disk hashes
(`identity_bound_PASS`), and lineage to the Q07 predecessor is correct for all 8 (`lineage_PASS`). The DSR context
seals at claim time: pending rows show `UNAVAILABLE`, claimed rows show `SEALED`.

## Holds

**None on the new rows — 0 releases.** Verified per new row (`holds_new_rows.json`): no `work_item_holds` row exists
on any of the 8 fresh rows, consistent with the D1 finding for the staged rows. Nothing to release; the 40 unrelated
active Q08_DSR holds were not touched. No governed `release-hold` was invoked (there was no hold to release).

## Worker claims (poll, no manual claims)

Captured by `poll_claims.py` (10 s interval over ~20 min; terminal via `claimed_by` / run-summary, PID via
`farmctl mt5-slots`). Full detail: `claims_result.json` / `poll_claims.log`. **No manual claims were made.**

| old id | new id | EA | claim status | terminal | PID |
|---|---|---|---|---|---|
| 7bc8b34e | 61ddcbdd | QM5_1159 | **claimed + ran to completion** (verdict FAIL_HARD, DSR SEALED) | T2 | (completed before poll; T2 process ended) |
| d4aebc12 | 333f014b | QM5_10804 | **claimed, actively running** | T10 | 20372 |
| 383c45b0 | 8d04ca70 | QM5_10661 | pending — claimable, queued | — | — |
| 20c533da | 1d575bfc | QM5_10211 | pending — claimable, queued | — | — |
| a937b9bc | d5a17dbf | QM5_12958 | pending — claimable, queued | — | — |
| 15fed5d8 | 35ca4b36 | QM5_9123 | pending — claimable, queued | — | — |
| aa0fa828 | e8377ff0 | QM5_10291 | pending — claimable, queued | — | — |
| 94d46fe7 | 93ac0ce2 | QM5_10267 | pending — claimable, queued | — | — |

**2/8 claimed within the window (both terminal-attributed; one full claim→seal→verdict cycle).** The other 6 are
`claimable` per `claimability_precheck` but remain `pending` because the farm runs Q08 backtests with only ~2
concurrent slots behind a **59-row farm-wide pending-Q08 backlog** (long full-history + Monte-Carlo runtimes; only
2 backtests active across all phases at capture time). They are queued, **not refused** — the precheck flip is the
repair's success criterion and it holds for all 8. Claiming the remainder is a function of farm Q08 throughput, not
of this repair. `61ddcbdd` (T2) proves the end-to-end path: claimed → DSR context SEALED → executed → verdict written.

## Newly active backtests

| work item | EA | symbol | terminal | PID | state |
|---|---|---|---|---|---|
| 333f014b-38da-4ae0-8d5e-ccc1944569ac | QM5_10804 | GDAXI.DWX | T10 | 20372 | active (baseline run `20260916_072200`) |
| 61ddcbdd-b632-4115-957d-1f0dceb67a03 | QM5_1159 | NDX.DWX | T2 | (ended) | done FAIL_HARD (run `20260916_065458`, DSR SEALED, ex5 identity held = current build) |

## Hard-boundary attestation

- **Batch-2 cards byte-unamended (8/8):** QM5_10287, QM5_9576, QM5_1230, QM5_9973, QM5_13012, QM5_11882, QM5_10269,
  QM5_10280 — none carries a `qm-dsr-single-configuration` block (re-verified live this run).
- **Excluded-5 byte-untouched (5/5):** QM5_10145, QM5_12350, QM5_12361, QM5_1551, QM5_12484 — live card sha256 ==
  `excluded5_card_hashes_baseline.json` for all 5 (`excluded5_unchanged.json`).
- **No verdict writes:** the 8 staged rows remain `pending`/`NULL` verdict; each keeps only a `work_item_supersedes`
  edge to its `SUPERSEDED_REPAIR` disposition row (append-only history preserved).
- **Commits path-scoped:** `27bab3ecc5` touches only `tools/strategy_farm/session_tools/q08_repair_dispositions_0914.py`.

## Evidence index

`dispositions_dryrun.txt` · `dispositions_apply.txt` · `dispositions_receipt.json` · `ea_current_build_hashes.json` ·
`q07_predecessor_map.json` · `precheck_before.json` · `fresh_enqueue_preflight.txt` · `fresh_enqueue_QM5_1159.json` ·
`fresh_enqueue_remaining7.txt` · `old_to_new_map.json` · `proof_gate_new_rows.json` · `wiki_lint_new_rows.json` ·
`wiki_build_my8.txt` · `holds_new_rows.json` · `claims_result.json` · `poll_claims.log` ·
`excluded5_unchanged.json` · `poll_claims.py` · SQLite backup `farm_state_before_q08_repair_dispositions_20260916T065136Z_*.sqlite`
