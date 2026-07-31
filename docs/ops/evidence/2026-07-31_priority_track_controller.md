# QM5_20007 priority-track source and exact-ID controller evidence

Date: 2026-07-31  
Router task: `ce3d5cef-f62d-4951-af36-92d83a1696ee`  
OWNER authority: `OWNER_DECISION_2026-07-31_QM5_20007_PRIORITY_TRACK`  
Result: **PASS — persistent source repaired; one exact NDX backfill committed; measured live displacement recorded**

## Scope and decision

The OWNER decision authorized an exact backfill of the still-valid NDX work item, including the queue displacement. The committed mutation was limited to:

- EA: `QM5_20007`
- work item: `6dce5d90-4a59-4753-9830-9eebdaeed397`
- symbol: `NDX.DWX`
- field effect: add `priority_track=true`, its OWNER reason, and provenance metadata inside `payload_json`

No wave or bulk mutation was used. SP500 remained excluded. The controller did not alter status, Q-phase, claim ownership, verdict, Factory state, terminal state, or AutoTrading.

## Persistent source

Commit `1c6862975a65f95aedf1e05f78923c47254c82f0` added the versioned registry `framework/registry/owner_priority_tracks.json` and applies its explicit OWNER override in `strategy_priority.compute_scores()`. It also wired the resulting score into the new-Q02 priority inheritance path.

The final read-only scorer check returned:

| Field | Value |
|---|---|
| `ea_id` | `QM5_20007` |
| `priority_track` | `true` |
| `priority_track_source` | `owner_priority_registry` |
| `asset` | `index_metal` |
| `tf` | `M5/M15` |
| target symbols | `GDAXI.DWX`, `NDX.DWX`, `XAUUSD.DWX` |
| excluded symbols | `SP500.DWX` |
| built | `true` |
| `pipeline_verdict_changed` | `false` |

The existing card still has unresolved cost-detail symbols. That claim was not rewritten or treated as evidence; the explicit OWNER registry is intentionally the authoritative priority-track override.

Registry normalized SHA-256: `6f30720bafbb152225e0c256c1aa058a6a4519cff81999945b0cbddaef39d056`.

## Exact-ID controller

Commit `1a549ae05e1015176c1b04f7a83b9d1e956c10a5` added `tools/strategy_farm/set_priority_track.py` with:

- dry-run-first planning against explicit work-item IDs;
- CAS checks for expected status, Q-phase, verdict, claim state, and payload SHA-256;
- `BEGIN IMMEDIATE` with exact row-count assertions;
- the shared mutation mutex;
- durable pre/post journal paths under `D:\QM\reports\state`;
- one farm event per exact committed row;
- a guarded, journal-hash-bound revert path.

Commit `9553e90a8b0488d1648c82e1f802adeae9ebfc4d` hardened the displacement measurement after the first apply attempt exposed a tie-ordering defect. The corrected controller preserves SQLite row IDs in its in-memory clone, records the transaction's live before/after ordering as authoritative, still fails closed on rank regression, and finalizes future failed apply journals as `rolled_back`.

Controller normalized SHA-256 at apply: `990f95bbfddab76ea2f7d5cdd7ebaa755ef0c468bb4175eb463c09c77f6f7a74`.

## Dry runs and CAS binding

The first bound dry run and expectations were committed in `194cca25d4c0576ff5f99329da6079c936c448a5`. At that snapshot, the exact NDX row was predicted to move from rank 551 to rank 7, displacing 544 rows.

After hardening the controller, the corrected dry run was committed in `215317e07e93604ac8df2eb474f7709f93db938d` as `docs/ops/evidence/2026-07-31_priority_track_dry_run_v2.json`. It was `READY_FOR_APPLY`, named only the NDX ID, and performed no mutation. Its snapshot predicted rank 550 to rank 7, displacing 543 rows. The apply was bound to expectations SHA-256 `e54ebf685c65c6a48426fcc4707efae011230ab978ba27877bd3e5df9d6ae228`.

The rank/count drift across snapshots was caused by the active farm queue changing around the read-only measurements. The exact row's CAS state and payload pre-image remained unchanged until the committed transaction.

## Apply history

### Attempt 1 — failed closed and rolled back

The pre-fix controller prepared `D:\QM\reports\state\priority_track_20007_ndx_20260731.json`, then rejected the transaction with `post-update claim rank differs from in-memory simulation`. The database transaction rolled back. Before retry, the NDX payload was verified at its original SHA-256 and no matching apply event existed.

The original journal is retained unchanged with:

- journal state: `planned`
- journal SHA-256: `23c8bbf688afa420d3ae5ea5d45640a6fd327a888998e633de5b1aaf11ae1f99`
- committed database rows: 0
- farm events: 0

The stale `planned` state is a documented limitation of the pre-fix controller: it wrote a durable plan before the transaction but did not finalize a failed journal. It is not evidence of a committed mutation. The fix in `9553e90a8` closes that journal-finalization gap for subsequent attempts.

### Attempt 2 — exact apply committed

After one ordinary shared-mutex contention, the controller waited within a bounded retry and acquired the mutex normally. The lock was not removed or bypassed.

The corrected exact-ID apply committed at `2026-07-31T14:49:40Z`:

| Item | Value |
|---|---|
| changed rows | 1 |
| work item | `6dce5d90-4a59-4753-9830-9eebdaeed397` |
| journal | `D:\QM\reports\state\priority_track_20007_ndx_20260731_v2.json` |
| journal state | `committed` |
| journal SHA-256 | `fd558ab765fd7b353590b24d06b6dc8bbdbae9f7b05275308130436d983fb53a` |
| event | `340273`, `priority_track_backfill_applied` |
| pre-payload SHA-256 | `d62742d555f23e60f2209fbf376daf8abe01ed62c96673465b8c73a81cc722e0` |
| post-payload SHA-256 | `a67a5a9631b5d8bfcf0b1ffa1ced282cc222125d29176a34f0854ec199d16a05` |
| final row state | `pending`, `Q02`, unclaimed, verdict null |
| pipeline verdict changed | `false` |

Exactly one matching event exists, and its detail binds the expectations, registry, pre-image, and post-image hashes.

## Authoritative displacement measurement

The controller measured canonical claim order inside the live transaction before and after the update:

| Measure | Value |
|---|---:|
| pending rows before / after | 2,183 / 2,183 |
| NDX rank before | 549 |
| NDX rank after | 10 |
| rank improvement / rows displaced | 539 |
| displaced Q04+ rows | 51 |
| displaced metal rows | 209 |
| displaced-ID set SHA-256 | `db14c2d5a4e7935d3b5c2179f81850a5c8987642ad13965dead0b95653b348f9` |

The snapshot simulation made during apply predicted rank 549 to rank 7 (542 rows). The live before/after measurement above is authoritative. The three-rank difference is canonical tie ordering under concurrent queue activity; there was no rank regression.

## Final re-census

| Work item | Symbol | State | Priority flag | Action |
|---|---|---|---|---|
| `0928164a-2c70-448b-ae23-4cfaf6c06c6a` | GDAXI | failed / `Q02` / `INFRA_FAIL` | absent | unchanged terminal recovery row |
| `05652c88-8e07-4aaf-934f-1e013ac8deda` | GDAXI | pending / `Q02` / unclaimed | absent | unchanged; separately enqueued recovery row outside the authorized exact NDX ID |
| `6dce5d90-4a59-4753-9830-9eebdaeed397` | NDX | pending / `Q02` / unclaimed | `true` | exact backfill committed |
| `80c64b67-7eaa-461e-ba1c-80892f7cf73d` | XAU | pending / `Q02` / unclaimed | `true` | unchanged; already flagged recovery row |

The separately enqueued pending GDAXI row became visible during the final re-census. It was created before the persistent-source change and was not silently added to an OWNER authorization that named the exact NDX backfill. No SP500 row was changed.

## Verification and durable receipt

Focused test command:

```text
python -m pytest -q tools/strategy_farm/tests/test_set_priority_track.py tools/strategy_farm/tests/test_strategy_priority_owner_registry.py tools/strategy_farm/tests/test_priority_track_new_q02.py tools/strategy_farm/tests/test_strategy_priority_cost_orthogonality.py tools/strategy_farm/tests/test_auto_build_routing.py
```

Result: `62 passed, 12 subtests passed in 9.79s`.

The machine-readable receipt is `docs/ops/evidence/2026-07-31_priority_track_apply_receipt.json`, committed in `c51255ea4`. Its filesystem SHA-256 at verification was `5b243b3ce5e64e2b0383ff14784461429ecff6f5cdd74b1540e153733aed9183`.

Post-apply checks also confirmed:

- exactly one matching apply event (`340273`);
- no residual `D:\QM\strategy_farm\state\FACTORY_MUTATION.lock`;
- no Factory, terminal, AutoTrading, SP500, or pipeline-verdict change;
- no revert performed.

## Reviewer conclusion

The requested persistent source and exact-ID controller are implemented and focused tests pass. The authorized NDX row is durably journaled, event-bound, and committed with its actual displacement measured. This task is ready for Claude REVIEW; this evidence does not self-approve it or advance any pipeline verdict.
