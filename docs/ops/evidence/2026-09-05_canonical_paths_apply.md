# Canonical setfile path application review

RESULT: REVIEW. Task `a3ec5b69-ae8f-475c-b939-2c9b04224761`. Isolated implementation **`7ba3be6607`** on `agents/codex-canonical-paths-apply-20260905`. **36 focused tests passed.** All nine individual dry runs are frozen; eight are eligible, and QM5_10151 refuses with `EXISTING_SUPERSESSION`. No canonical database apply was executed.

## Exact authority and mutation boundary

The implementation pins SHA-256 hashes of the nine previously reviewed proposal files. Each binds the original complete row and payload, old and canonical preset bytes, canonical EX5 and deterministic successor UUID. The routed CEO decision selects these exact canonical bytes, including the encoding differences and the QM5_10151 slot correction. That authority is scoped to the nine IDs and cannot repair arbitrary rows or silently absorb later artifact changes.

`canonical_setfile_paths.py apply --work-item-id <id>` and `apply --all-previewed` are read-only unless the additional `--apply` flag is present. Mutation refuses from an isolated checkout; the CEO must use the canonical script after integration. Mutation also requires `--receipt-path` under the canonical evidence directory. Dry runs open SQLite with `mode=ro` and `query_only=ON`, and do not acquire a mutation lock or take a backup.

The apply path acquires exactly one existing nonce-bound factory mutation lock, checks OFF freshly, takes and hashes the governed online state backup, checks OFF again, then opens one BEGIN IMMEDIATE transaction. It revalidates every target, current build/risk/registry gates and lineage, rejects existing or competing open successors, appends the deterministic successor, copies every hold unchanged to that successor, and inserts the canonical supersession edge. Original row bytes, path, verdict, parent and hold records remain unchanged. New rows use the current enforced gate contract and bind the canonical artifact hashes in both columns and payload. The existing database trigger excluding superseded predecessors from claims is required. Artifact hashes and OFF are checked again before commit. A failure rolls back the whole selected batch.

The receipt is persisted in the same transaction as an audit event, then published to the requested evidence sidecar. If sidecar publication fails after commit, the result explicitly says applied and gives receipt-recovery guidance; replaying the mutation is refused. The durable event can reconstruct the sidecar. All holds, including any unknown/path-related hold, are conservatively retained; this tool does not grant a hold release.

## Current gates and dry-run results

Build checks use the existing cached-build source/binary timestamp predicate and require an unambiguous nonempty canonical binary. A build needing compilation refuses instead of running a compiler. The canonical guardrail checker validates the EA with a 336-hour news ceiling. Every preset must have fixed risk above zero and zero percentage risk. Active EA slug, exact symbol/magic/slot registry identity, original parent identity and any requeue ancestor are checked. The original NULL parents on these legacy rows remain NULL; the repair does not create a new phase or infer a new approval. Current runtime/history/news execution gates still govern eventual dispatch.

| Predecessor | Dry-run result |
|---|---|
| `0ff05819-1aab-42ff-a517-58724492c77b` | Eligible |
| `1821432a-2f41-4417-b680-e3947b1c4ef7` | Eligible |
| `7c137654-dcb4-44dd-9cbd-d233b75684b9` | Eligible |
| `85590a54-63e5-443a-8f17-2bee061483b1` | Eligible |
| `995f36e9-b08c-4e28-aa77-5322cc419ecb` | Eligible |
| `adda1ec6-cc3e-4f60-b51f-2b566033adcb` | Eligible |
| `b1384ee3-e582-46ce-8432-193b4865a854` | Eligible |
| `b7189709-abe5-4bff-ab28-d4f6a4fdd1e6` | Eligible |
| `f7950e47-85b7-43dd-bc5f-a67e27e75c6a` | Refused: existing supersession |

`--all-previewed` therefore refuses the entire batch at current state. The CEO can review individual eligible plans; no existing supersession is overwritten or treated as permission to duplicate. Each [individual response](2026-09-05_canonical_paths_apply/) records the exact executed command and exit code. [Batch response](2026-09-05_canonical_paths_apply/all_previewed.json), [collector](2026-09-05_canonical_paths_apply/collect_dry_runs.py), [implementation patch](2026-09-05_canonical_paths_apply/canonical_paths_apply.patch).

## Verification

`python -m pytest tools/strategy_farm/tests/test_canonical_setfile_paths.py tools/strategy_farm/tests/test_canonical_setfile_apply.py tools/strategy_farm/tests/test_factory_mutation_lock.py -q`: **36 passed in 8.93 seconds**. Tests cover the fixture apply, one-lock use, preserved predecessor/holds, old-claim exclusion, dry-run laziness, claimed/changed/missing files, competing and existing successors, supersession, gate failure, three OFF boundaries, backup/transaction failure, missing claim guard, receipt location, batch rollback and artifact drift during validation. Python compilation and `git diff --check` pass.

[Verification](2026-09-05_canonical_paths_apply/verification.json) confirms all nine original rows, holds and supersession records had identical before/after hashes across the read-only collection. No compile, terminal launch, registry edit, worker restart, live action, pipeline verdict or main integration occurred. Evidence stays on board-advisor and implementation stays on its isolated branch for review.
