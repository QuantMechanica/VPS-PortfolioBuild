# Registry dispatch drain blocker: governed precondition and live-cohort result

Date: 2026-08-23  
Router task: `8d1d903f-39cc-461f-ab90-7b932ce62fee`  
Implementation commit: `c3751fddd` (`fix(farm): gate builds on governed registry proof`)  
Disposition: `REVIEW — IMPLEMENTED_FAIL_CLOSED; LIVE_BATCH_BLOCKED_BY_CARD_IDENTITY_CONTRACTS`

## Result

The structural dispatcher defect is closed in code. A build prompt can now be produced only after one exact active EA identity, one exact active magic row for every card-declared symbol, and the same complete tuples in `QM_MagicResolver.mqh` have been proven. Missing clean identity/magic state creates one deduplicated governed-allocation precondition task; retired, ambiguous, partial, mismatched, or resolver-incomplete state remains fail-closed.

No live registry batch was applied. The current refusal cohort contains no card that the governed allocator may safely allocate:

- 53 historical refusal-class `build_ea` rows are present now, all `BLOCKED` (45 Codex, 8 Gemini). The task's original 45 prebuild/refusal rows have since gained 8 later Gemini `BUILD_NOT_STARTED` rows; the five source-complete compile holds in the original 50-row headline are not registry-backfill candidates.
- 52/53 have exactly one approved-card file; QM5_1426 has none.
- 52/53 have no usable top-level `target_symbols` contract. The gate therefore returns `card_target_symbols_missing_or_invalid` for 51 cards and has no card to inspect for QM5_1426.
- The sole symbol-complete card, QM5_1487, is an identity conflict: the approved card requests `raschke-3-10-oscillator-cross-h4`, while active EA ID 1487 belongs to `as-kda-defensive`.
- Consequently, 0/53 current refusal-class rows are build-ready and 0 rows became newly buildable by registration in this cycle. Against the original 50-row headline, the registration delta is likewise 0; the five compile holds were orthogonal to identity allocation.

Applying any row would require inventing card symbol scope, rekeying an active identity, or selecting unrelated global allocator candidates. All three are outside this task and violate the fail-closed registry contract.

## Closed root-cause chain

The missing deterministic step was the transition from final card approval to governed EA identity reservation. `farmctl approve-card` previously finalized the approved card without proving or scheduling its exact EA-ID/magic contract. Separately, the allocator's default discovery used frozen 2026-08-17 worklists, so later approved cards could never enter its candidate set.

Commit `c3751fddd` closes both gaps:

1. `farmctl.magic_allocation_precheck` proves the full card/identity/magic/resolver contract, including exact slug, contiguous slots, formula `ea_id * 10000 + slot`, symbol order, and generated resolver tuples.
2. `render_codex_build_prompt` performs that proof before producing build work. On failure it creates a deduplicated, actionable registry-precondition task through `agent_router.ensure_magic_precondition_task`; it does not create a build prompt.
3. Final `approve-card` now calls `_approved_card_registry_precondition` on the final approved-card path. That is the deterministic approval-to-reservation link that was missing.
4. The allocator's normal discovery now reads `D:/QM/strategy_farm/artifacts/cards_approved/`. Duplicate card identity groups are excluded as groups rather than resolved arbitrarily.
5. A clean missing identity can be reserved together with its exact magic rows in one governed transaction. The allocator still orders directory/card materialization before EA-ID CSV and magic CSV writes, then regenerates the resolver and verifies identity, collisions, and every exact tuple. All three registry/generated files are backed up and rolled back together on failure.

The dispatcher and approval paths schedule the governed prerequisite; they do not grant Development permission to hand-edit registries or silently repair conflicts.

## Live read-only measurements

### Refusal cohort

The repeatable census selected `build_ea` tasks updated on 2026-08-22 whose durable artifact contains one of the task's five refusal markers, excluding unrelated QM5_1404 (a card/data contradiction):

| Marker | Rows |
|---|---:|
| `BUILD_NOT_STARTED` | 25 |
| `PREBUILD_BLOCK` | 15 |
| `PRECHECK_FAIL_MISSING_REGISTRY` | 5 |
| `PREFLIGHT_FAIL` | 4 |
| `BLOCKED_PRE_FLIGHT` | 4 |
| Total | 53 |

Current registry/card measurements:

| Measurement | Rows |
|---|---:|
| No active EA identity | 37 |
| No active magic rows | 45 |
| Exactly one approved card | 52 |
| Card with usable explicit symbols | 1 |
| Precheck: missing/invalid card symbols | 51 |
| Precheck: approved card absent | 1 |
| Precheck: registry identity conflict | 1 |
| Precheck: ready | 0 |

The exact QM5_1487 precheck returned:

```json
{
  "action": "REVIEW_REQUIRED_DO_NOT_REACTIVATE",
  "classification": "registry_identity_conflict",
  "ea_id": "QM5_1487",
  "identity_active": true,
  "identity_registry_rows": 1,
  "identity_slug_matches": false,
  "active_magic_rows": 0,
  "target_symbols": ["EURUSD.DWX", "GBPUSD.DWX", "XAUUSD.DWX"]
}
```

This is not eligible for automatic reservation. Reusing ID 1487 would corrupt the active `as-kda-defensive` identity; assigning another ID changes the approved card and requires OWNER adjudication.

### Live approved-card discovery

Read-only live discovery found:

- 3,171 unambiguous approved-card candidates;
- 100 fail-closed discovery findings (38 unreadable/non-approved/invalid card contracts and 62 members of duplicate identity groups);
- a full dry-run plan of 63 globally eligible allocations, including 9 missing identities.

Those 63 are not members of the refusal cohort and were not selected as substitute work. The task authorizes draining the measured cohort, not allocating unrelated inventory.

The post-worklist discovery regression constructs `QM5_9001_post-0817.md` only in the live approved-card directory and proves that it appears as stage `approved_live`; no frozen worklist is edited.

## Governed batch refusal

The exact allocator dry-run was attempted for the only symbol-complete cohort card:

```text
python tools/strategy_farm/governed_magic_allocator.py --dry-run --max-eas 1 --card D:/QM/strategy_farm/artifacts/cards_approved/QM5_1487_raschke-3-10-oscillator-cross-h4.md
```

It correctly aborted before planning or writing:

```json
{
  "reason": "dirty_registry_abort: M framework/include/QM/QM_MagicResolver.mqh",
  "schema": "qm.governed-magic-allocation/v1",
  "status": "aborted"
}
```

The dirty resolver belongs to concurrent canonical-checkout work and was not touched. Both registry CSVs are clean. Even after that unrelated dirty path clears, QM5_1487 must still be refused by the identity mismatch. Therefore there is no safe first bounded batch, and no duplicate scan/resolver post-write proof can honestly be claimed.

## Verification

Focused affected suite:

```text
python -m pytest -q tools/strategy_farm/tests/test_magic_allocation_precheck.py tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_mnt012_build_guards.py
...........................                                              [100%]
27 passed in 6.29s
```

The suite directly covers:

- negative dispatch refusal and positive dispatch after exact proof;
- approval-to-precondition scheduling and task deduplication;
- complete resolver-tuple enforcement;
- post-2026-08-17 live-card discovery;
- missing identity plus magic allocation in one governed write;
- directory/card-before-CSV ordering;
- dirty-registry abort and rollback path;
- ambiguous identity refusal;
- retired-history non-reactivation;
- default bounded cap and `--max-eas 0` dry-run-only semantics.

No EA source, binary, setfile, terminal, queue row, verdict, trade stream, `T_Live`, or AutoTrading state was changed.

## Required OWNER follow-up

Before a live backfill can begin, OWNER/Card Governance must provide a durable card amendment or re-identification for the allocation targets:

1. restore or adjudicate the missing QM5_1426 approved card;
2. add explicit canonical `target_symbols` to the 51 scope-incomplete cards;
3. assign the Raschke card a non-conflicting EA identity, or explicitly retire/rekey the existing QM5_1487 identity under the normal governance process;
4. let the unrelated dirty resolver writer finish and return all three registry/generated paths clean.

After those prerequisites, `governed_magic_allocator.py` can process exact cards serially in batches of at most five, with its existing duplicate/collision scan and resolver verification after every batch. Until then, REVIEW is the only truthful disposition: the code defect is fixed, while acceptance item D is blocked by upstream card identity contracts rather than allocator behavior.
