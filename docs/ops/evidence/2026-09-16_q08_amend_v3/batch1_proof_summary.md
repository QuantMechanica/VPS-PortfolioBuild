# Batch 1 — apply + five proofs — 2026-09-16

Decision: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916` (receipt `d59b2277`).
Rows (manifest order 1–8): 7bc8b34e (QM5_1159), d4aebc12 (QM5_10804), 383c45b0 (QM5_10661),
20c533da (QM5_10211), a937b9bc (QM5_12958), 15fed5d8 (QM5_9123), aa0fa828 (QM5_10291),
94d46fe7 (QM5_10267).

- Dry-run: `batch1_dryrun.txt` — 8 DRY ok / 0 skipped / 0 failed; locked-parameter counts equal the
  manifest (29/33/36/31/27/31/30/30).
- Apply: `batch1_apply.txt` — 8 APPLY ok / 0 failed; journaled to `card_amend_journal.jsonl`
  (before/after hashes, decision id, receipt id).

## Proof results

| proof | result |
|---|---|
| (a) card hashes | **PASS (8/8)** — live re-hash == journal `card_sha_after`; journal `card_sha_before` == manifest `card_sha_before` for all 8 (`batch1_proofs.json`) |
| (b) declaration correctness | **PASS (8/8)** — `dsr_single_configuration.declaration()` parses each amended card; candidate (ea_id/symbol/timeframe), `spec_sha256`, `complete`, `no_optimization_search`, `research_trial_count=0` all correct; `locked_parameters` byte-equal to `effective_parameters(mq5, setfile)` recompute; locked-parameter count == manifest |
| (c) claimability_precheck flip | **FAIL (0/8)** — precheck now fails with `SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5` on every row |
| (d) no false-declaration refusal | **PASS on the declaration axis (8/8)** — claim-time factory-search-ledger check `_factory_search_before_q08_claim` CLEAN for all 8 (0 optimization rows; 13/42/44/15/22/73/453/63 work items examined) (`batch1_factory_search.json`). The full in-memory `assemble()` still raises — at the build-identity gate, not the declaration gate |
| (e) Strategy Wiki sync health | **AMBER, not GREEN** — first lint 06:30Z: RED (stale 1295, missing 1, transient); second lint 08:32Z: AMBER (stale 1286, missing 0). All 8 amended cards' `ACTIVE_CANONICAL` nodes re-rendered **FRESH** by the scheduled sync; remaining stale set is ambient `REJECTED`-class backlog (`wiki_lint_batch1.json`) |

## Root cause of proof-(c) failure (STOP condition)

All 16 staged work items (and specifically these 8) carry **no recorded build identity anywhere**:
`work_items.mq5_sha256/ex5_sha256/setfile_sha256` columns are NULL and the payload has no
`artifact_identity` / `expected_*_sha256` (verified row-by-row). The Q08 single-configuration
contract (`dsr_single_configuration.validate`) requires the work item to assert
`{mq5,ex5,setfile}_sha256` and compares them with live disk bytes; `None != live` ⇒
`BUILD_IDENTITY_MISMATCH:mq5`. The two rows that claimed successfully on 2026-09-16
(d02a1128/a6f023c9) both carry stamped identity.

This defect pre-dates the amendment: `claimability_precheck` evaluates the card declaration
**before** build identity, so with no declaration the rows failed earlier at
`EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` (see 09-16 baseline) and the identity gap was
invisible. The card amendment removed the first mask and exposed the second gate. It is **not** a
false-declaration refusal — the declarations are true (proof d) — and it is **not** caused by the
amendment (identity columns were NULL before; baseline BUILD_IDENTITY_MISMATCH rows do not
intersect the 16).

Of 86 pending Q08 rows only 14 have any stamped identity → this is a cohort-level enqueue-time
defect on the 2026-09-15/16 parked rows, outside the sanctioned scope of this decision (card
amendment + governed hold release). Repair options for OWNER/Fable: governed identity backfill for
the 16 rows (payload + columns, journaled, CAS), or the established V2 pattern
(supersede + fresh Q08 enqueue from the Q07 predecessor with current bindings, cf.
`session_tools/q08_repair_dispositions_0914.py` + `q08_repair_fresh_enqueue_0914`).

## Consequence per OWNER conditions

Condition 3 requires proofs (a)–(e) before batch 2. (c) fails and (e) is not GREEN ⇒ **batch 2 NOT
applied** (its 8 cards verified byte-unamended), **no holds released** (none of the 16 rows carries
any hold — governed dry-run: `hold_not_found`, `release_hold_dryrun_7bc8b34e.json` — and amended
rows are not revalidated claimable, so condition 4 releases nothing). **0 rows newly claimable.**
Batch-1 card amendments remain in place: they are truthful, OWNER-approved, append-only and
journaled; prior bytes preserved in `manifest.json` + staged dir (OWNER condition 5).
