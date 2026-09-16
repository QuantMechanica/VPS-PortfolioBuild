# PRE-APPLY RECEIPT — Q08 DSR single-configuration card amendment (V3)

- Decision: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916` (parent: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, receipt `3415f6c0`)
- Receipt id: `d59b2277` (= sha256(decision id)[:8], deterministic)
- Authority: OWNER-approved governed Q08 DSR single-configuration card amendments for the staged
  cohort, under Kimi's interim delegation; conditions: scope reconciliation first, two batches of 8
  with five proofs between, governed hold release only, append-only journaled amend, exclusions
  byte-untouched.
- Tool: `tools/strategy_farm/session_tools/q08_single_config_amend_0914.py` (constants repointed to V3,
  commit `2b141a1b91`, path-scoped)
- Manifest under reconciliation:
  `docs/ops/evidence/2026-09-16_q08_dsr_unblock/staged_card_amendment/manifest.json`

## Reconciliation result (OWNER condition 1)

- Manifest resolves to **exactly 16 eligible cards / 16 Q08 work items**. ✔
- All 16 manifest rows are inside the canonical 22-row selector set (21 Q08 + 1 Q06,
  `q08_selector_rows.json`); the 21 Q08 rows = these 16 + the 4 not-amendable + QM5_12350 candidate
  mismatch. ✔
- None of the five excluded EAs (`QM5_10145`, `QM5_12361`, `QM5_1551`, `QM5_12484`, `QM5_12350`)
  appears in the manifest. ✔
- DB (`farm_state.sqlite`, read-only): each work-item id resolves exactly, `ea_id` matches, all rows
  `status=pending`. ✔
- Live card bytes on `D:\QM\strategy_farm\artifacts\cards_approved` match `card_sha_before` for all
  16; none carries an existing `qm-dsr-single-configuration` block. ✔
- DB `setfile_path` equals the manifest `setfile` for all 16 (0 mismatches) → the apply tool resolves
  identical inputs to the staged set. ✔
- Baseline precheck (all 16): `claimable=false`,
  `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED`
  (`q08_precheck_baseline_check.json`). ✔

Counts reconcile exactly — proceeding. No STOP condition.

## The 16 approved EA IDs and work-item IDs

| # | EA | work item | symbol/tf | card (D:) `card_sha_before` |
|---|---|---|---|---|
| 1 | QM5_1159 | 7bc8b34e-afe9-4d30-b90d-2e70e2f94ef5 | NDX.DWX/D1 | 6080b20a…9a2e66e |
| 2 | QM5_10804 | d4aebc12-d2a7-4145-912c-8bc7bd5d363b | GDAXI.DWX/H1 | 891d79f4…2331e50 |
| 3 | QM5_10661 | 383c45b0-5452-4b43-9397-28273202f946 | GDAXI.DWX/H1 | feb2dd71…d10047 |
| 4 | QM5_10211 | 20c533da-a745-4dc0-978d-c3dc74e45689 | NDX.DWX/D1 | c3f7ca91…c55e9840 |
| 5 | QM5_12958 | a937b9bc-2590-4f7c-b799-5e6b1f75c78f | GDAXI.DWX/D1 | 86a78c2a…472edfb |
| 6 | QM5_9123 | 15fed5d8-3c9c-4da2-abe1-e943f2156236 | NDX.DWX/D1 | 042432c4…f4af0 |
| 7 | QM5_10291 | aa0fa828-5609-4bf6-8e76-bfe813896c10 | NDX.DWX/D1 | e0792ffb…2b6baa |
| 8 | QM5_10267 | 94d46fe7-3298-43a6-9663-632d45ca7896 | NDX.DWX/D1 | c60bb048…7b582 |
| 9 | QM5_10287 | 456f590f-0ef0-4cbf-8d46-9508f84455ea | NDX.DWX/D1 | 816fb37b…dcc2096 |
| 10 | QM5_9576 | ff0b551b-b00c-47d0-9040-110fd75e30a9 | NDX.DWX/D1 | 8dd23c27…ce4a4 |
| 11 | QM5_1230 | a591ff4c-a104-4d26-b996-0881e3758703 | NDX.DWX/D1 | ed320a5e…17a |
| 12 | QM5_9973 | 885b82ab-b7bb-4c00-85e3-03f1e8170c3d | NDX.DWX/D1 | e50f231f…7721 |
| 13 | QM5_13012 | bb5eccf7-1635-4383-9d72-5843408b9567 | GDAXI.DWX/H1 | 6e569c0d…61e60 |
| 14 | QM5_11882 | 1494bfb4-c698-4ad3-99d2-7c3e4e2723a2 | NDX.DWX/D1 | a504a0ab…0af8d9 |
| 15 | QM5_10269 | b11e5b43-f9f5-4238-b00e-3ff73f9c7277 | NDX.DWX/D1 | f400ae47…3bc3d |
| 16 | QM5_10280 | aec37e79-d8e0-41a6-ab34-16ed3f893715 | NDX.DWX/D1 | 00541c8c…fcbbb |

Full 64-hex hashes, spec sha, setfile sha, locked parameter counts: see `manifest.json`
(byte-level identity of the staged set; live before-bytes re-verified identical at reconciliation).

Batches (manifest order): batch 1 = rows 1–8 (`7bc8b34e,d4aebc12,383c45b0,20c533da,a937b9bc,15fed5d8,aa0fa828,94d46fe7`);
batch 2 = rows 9–16 (`456f590f,ff0b551b,a591ff4c,885b82ab,bb5eccf7,1494bfb4,b11e5b43,aec37e79`).

## Excluded (NOT covered, must stay byte-untouched)

| EA | work item | disposition (per verification_20260916.md) | card sha256 baseline |
|---|---|---|---|
| QM5_10145 | bdba95f1-… | sealed DL-089 census history on XAUUSD; declaration would be false | 14e394fb…f6e5c6 |
| QM5_12350 | 0031f42d-… | card already declares XAUUSD.DWX/D1; one declaration per card | 6c11196b…059a |
| QM5_12361 | 2276786b-… | SPEC.md missing — tool fails closed | d936e429…6912 |
| QM5_1551 | 3b320089-… | SPEC.md missing | af7a55c6…3d11 |
| QM5_12484 | dfb2f622-… | SPEC.md missing | 8a6f0afb…62e7 |

(baselines: `excluded5_card_hashes_baseline.json`; attested again post-apply in RECEIPT.md)

Note (from staged COMMANDS.md, no blocker): row 2 (QM5_10804) locks an `_ablation_00` setfile; the
n=1 declaration remains mechanically true (single parameter set, no optimizer `||`), and the
amendment text names the exact set file.

## Hold state at pre-apply

None of the 16 rows carries any `work_item_holds` row (active or historical) — they sit in the
claim order failing the cheap precheck (starvation-safe by design). The governed release step will
therefore verify per row: no active `Q08_DSR_CONTEXT_UNAVAILABLE` hold → no release required; any
hold found on an amended+revalidated row → released via `farmctl release-hold` (dry-run first, CAS).
The 40 unrelated active Q08_DSR holds (other rows) are out of scope and untouched.
