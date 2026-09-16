# FINAL RECEIPT — Q08 DSR single-configuration card amendment V3 — 2026-09-16

- Decision: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916` (parent `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, receipt `3415f6c0`)
- Receipt id: `d59b2277` (= sha256(decision id)[:8])
- Executed by: Kimi (interim delegation), governed two-batch plan with mandatory proofs
- **Outcome: PARTIAL APPLICATION + STOP.** Batch 1 (8 cards) amended, journaled, declaration-proofs
  green. Mandatory proof (c) — precheck flip to claimable — **failed on all 8** for a pre-existing,
  out-of-scope reason: the 16 staged work items carry no recorded build identity
  (`BUILD_IDENTITY_MISMATCH:mq5`; details below). Proof (e) wiki health not GREEN (AMBER). Per
  OWNER condition 3, **batch 2 was NOT applied**; per condition 4, **no holds were released**
  (none exist on these rows; amended rows not revalidated claimable). **0 rows newly claimable.**
  No scope inference was made; the divergence is reported for OWNER/Fable disposition.

## 1. Scope reconciliation (pre-apply) — PASS

Exactly 16 eligible cards / 16 work items, matching `manifest.json` and the canonical 21-row Q08
selector table (21 = 16 + QM5_10145 + QM5_12350 + 3×SPEC-missing); none of the five excluded EAs
present; DB ids/ea_ids/status verified; live before-bytes == manifest `card_sha_before`; DB
setfile_path == manifest setfile for all 16. Full receipt: `PREAPPLY_RECEIPT.md`.

## 2. Reconciled counts

- **16 cards** = QM5_1159, QM5_10804, QM5_10661, QM5_10211, QM5_12958, QM5_9123, QM5_10291,
  QM5_10267, QM5_10287, QM5_9576, QM5_1230, QM5_9973, QM5_13012, QM5_11882, QM5_10269, QM5_10280
- **16 work items** = 7bc8b34e-afe9-4d30-b90d-2e70e2f94ef5, d4aebc12-d2a7-4145-912c-8bc7bd5d363b,
  383c45b0-5452-4b43-9397-28273202f946, 20c533da-a745-4dc0-978d-c3dc74e45689,
  a937b9bc-2590-4f7c-b799-5e6b1f75c78f, 15fed5d8-3c9c-4da2-abe1-e943f2156236,
  aa0fa828-5609-4bf6-8e76-bfe813896c10, 94d46fe7-3298-43a6-9663-632d45ca7896,
  456f590f-0ef0-4cbf-8d46-9508f84455ea, ff0b551b-b00c-47d0-9040-110fd75e30a9,
  a591ff4c-a104-4d26-b996-0881e3758703, 885b82ab-b7bb-4c00-85e3-03f1e8170c3d,
  bb5eccf7-1635-4383-9d72-5843408b9567, 1494bfb4-c698-4ad3-99d2-7c3e4e2723a2,
  b11e5b43-f9f5-4238-b00e-3ff73f9c7277, aec37e79-d8e0-41a6-ab34-16ed3f893715

## 3. Batch results + five proofs

### Batch 1 (rows 1–8) — APPLIED, proofs mixed → STOP

Before/after card hashes (journal `card_amend_journal.jsonl`, live re-verified; before == manifest):

| row | EA | before | after |
|---|---|---|---|
| 7bc8b34e | QM5_1159 | 6080b20a…9a2e66e | 0c836211…154fbe74 |
| d4aebc12 | QM5_10804 | 891d79f4…2331e50 | 661a2124…81bca9c |
| 383c45b0 | QM5_10661 | feb2dd71…d10047 | bb782b86…b20f88 |
| 20c533da | QM5_10211 | c3f7ca91…c55e9840 | 4d563e2d…6433112 |
| a937b9bc | QM5_12958 | 86a78c2a…472edfb | 36043cf7…930bbdb |
| 15fed5d8 | QM5_9123 | 042432c4…12f4af0 | 6f23e69e…c4c101 |
| aa0fa828 | QM5_10291 | e0792ffb…c2b6baa | f70710a0…7e80da9 |
| 94d46fe7 | QM5_10267 | c60bb048…87b582 | 3e68c693…56d44b3 |

- (a) card hashes: **PASS 8/8** — (b) declaration correctness: **PASS 8/8** (contract
  `declaration()` + locked-parameter recompute vs live mq5/setfile; spec sha match).
- (c) precheck flip: **FAIL 8/8** — `SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5`.
  Per-row precheck results: `batch1_proofs.json`.
- (d) no false-declaration refusal: **PASS on the declaration axis 8/8** — claim-time
  factory-search-ledger check clean (0 optimization rows for each EA;
  `batch1_factory_search.json`); full in-memory `assemble()` (with `claimed_at_iso`) raises only at
  the build-identity gate, which is orthogonal to the declaration.
- (e) wiki sync health: **AMBER (not GREEN)** — transient RED (06:30Z: stale 1295 / missing 1) →
  AMBER (08:32Z: stale 1286 / missing 0); scheduled sync converging; all 8 amended cards'
  ACTIVE_CANONICAL nodes FRESH; residual stale = ambient REJECTED-class backlog
  (`wiki_lint_batch1.json`).
- Detail: `batch1_proof_summary.md`; logs: `batch1_dryrun.txt`, `batch1_apply.txt`.

### Batch 2 (rows 9–16) — NOT APPLIED (STOP honored)

All 8 cards verified byte-identical to `card_sha_before`, no declaration block present:
456f590f/QM5_10287, ff0b551b/QM5_9576, a591ff4c/QM5_1230, 885b82ab/QM5_9973,
bb5eccf7/QM5_13012, 1494bfb4/QM5_11882, b11e5b43/QM5_10269, aec37e79/QM5_10280.

## 4. Holds released

**None — 0 releases.** None of the 16 rows carries any `work_item_holds` row (verified pre-apply
and per amended row); governed dry-run `farmctl release-hold` on 7bc8b34e returned
`hold_not_found` (`release_hold_dryrun_7bc8b34e.json`). Condition 4 releases only holds of
successfully amended **and revalidated** rows — the 8 amended rows are not revalidated claimable,
and no holds exist to release. The 40 unrelated active Q08_DSR holds were not touched.

## 5. Newly claimable rows

**0.** The 8 amended rows now fail one gate later than before (build identity instead of missing
declaration). The 8 unamended rows are unchanged (still declaration-gated).

## 6. Root cause + required disposition (for OWNER/Fable)

The 16 staged work items have `mq5_sha256/ex5_sha256/setfile_sha256` NULL and no payload
`artifact_identity`/`expected_*_sha256`. The Q08 single-configuration contract requires the row to
assert build identity (`dsr_single_configuration.validate`, `BUILD_IDENTITY_MISMATCH:<role>`). The
2026-09-16 precheck baseline could not show this because the declaration check runs first
(`EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` masked it). This is a cohort-level
enqueue-time defect of the 2026-09-15/16 parked rows (only 14 of 86 pending Q08 rows carry any
stamped identity). Repair is outside this decision's scope. Options: governed identity backfill for
the 16 rows (columns + payload, journaled, CAS, with re-run of the five proofs), or the V2 pattern
(supersede + fresh Q08 enqueue from the Q07 predecessor with current bindings). The batch-1
amendments remain valid regardless of which repair is chosen.

## 7. Untouched-exclusions attestation

The five excluded EAs' cards are byte-untouched (hashes identical to pre-apply baseline,
`excluded5_card_hashes_baseline.json` vs live):

| EA | card sha256 (unchanged) |
|---|---|
| QM5_10145 | 14e394fb…f6e5c6 |
| QM5_12350 | 6c11196b…247be059a |
| QM5_12361 | d936e429…5815a6912 |
| QM5_1551 | af7a55c6…06a73d11 |
| QM5_12484 | 8a6f0afb…7e7a62e7 |

Batch-2 cards (also unamended) and all historical verdicts/streams/previous card bytes are
preserved (append-only amend; prior bytes in `manifest.json` +
`../2026-09-16_q08_dsr_unblock/staged_card_amendment/`). The 2026-09-14 V2 journal and cards are
untouched by this run.

## 8. Evidence index

`PREAPPLY_RECEIPT.md` · `batch1_dryrun.txt` · `batch1_apply.txt` · `batch1_proofs.json` ·
`batch1_factory_search.json` · `batch1_proof_summary.md` · `wiki_lint_batch1.json` ·
`release_hold_dryrun_7bc8b34e.json` · `card_amend_journal.jsonl` ·
`q08_precheck_baseline_check.json` (before-state) · `excluded5_card_hashes_baseline.json`
