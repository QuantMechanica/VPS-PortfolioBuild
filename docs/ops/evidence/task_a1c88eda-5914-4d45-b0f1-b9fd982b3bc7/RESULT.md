# Q08 Option-W predecessor unlock — governed-path result

Task: `a1c88eda-5914-4d45-b0f1-b9fd982b3bc7`  
Verdict: **REVIEW — no admissible mutation; compile-provenance authority is missing**

## Outcome

No COMPILE_EA, Q02, or Q08 row was created. The five historical rows and verdicts remain unchanged. The live-state probes established that the binaries currently in the canonical EA directories are byte-identical to the binaries bound by the target Q08 rows, but none of the five EAs has a governed COMPILE_EA row. The available historical build records cannot be converted into compile receipts because they predate the session-attestation contract and have no authenticated `session_compile_ok.json`.

Creating a receipt or a fresh chain without that provenance would waive the identity bar. This cycle therefore stopped fail-closed.

Stable hashes and row IDs are in `blocker_state.json`; the row journal is `created_rows.jsonl`. The no-change reservation accepted this first state as `cd89ef377f91fd031123a182209d584e1ea9cf3eab0cd226d7c7072574930d02`.

## Per-EA disposition

| EA | Live-path result | Created rows | Expected time to Q08 |
|---|---|---:|---|
| `QM5_12548` | Current EX5 `30fae11a…` equals Q08 `d64e26f7` and Q07 `ec825ea0`. The Q07 base set binds under identity v2, but the target Q08 variant set (`a920b4aa…`) is a different identity. Historical build task `9919ec02…` has no session attestation, so `--receipt-session-build` is not authorized. The canonical-base Q02 identity is already terminal in `345cb963…`; an unauthenticated duplicate seed is not admissible. | 0 | **Unbounded while blocked.** With a same-byte governed compile receipt, direct append-only Q08 is possible; if governed recompilation changes the binary, a fresh Q02→Q08 chain is required. Queue time has no bounded SLA. |
| `QM5_10412` | Current EX5 `f032a74b…` equals Q08 `e77c1d8c` and Q07 `a38c13e5`. The target variant (`f8c175ee…`) differs from the Q07 base-set identity. Historical build task `4f2301e7…` has no session attestation. Canonical-base Q02 identity is already terminal in `3764dcd6…`. | 0 | **Unbounded while blocked.** Same conditional path as 12548. |
| `QM5_20266` | Identity-v2 legacy probe on Q07 `cc8e760d` fails `q08_current_build_compile_provenance_unavailable`: MQ5, setfile, and include-closure identities are absent and there is no compile row. Post-binding Q02 requalification of `8927c178…` dry-runs to `current_ex5_has_no_pass_bound_compile_record`. The later Q08 still also requires peer-cohort regeneration for `PEER_COHORT_WINDOW_SHORT`. | 0 | **Unbounded while blocked.** A governed COMPILE_OK must precede fresh Q02 and peer-cohort regeneration; only then can Q08 be scheduled. |
| `QM5_13138` | Identity-v2 probe on Q07 `0dc8813d` reaches the legacy qualifier and correctly refuses `source_or_set_commit_after_q02_runs`, bound to commit `1d4b14d173`. Post-binding Q02 requalification dry-runs to `current_ex5_has_no_pass_bound_compile_record`. Historical task `20cbe942…` has no session attestation. | 0 | **Unbounded while blocked.** Governed COMPILE_OK, then append-only Q02 requalification and the normal cascade. |
| `QM5_13137` | Identity-v2 probe on Q07 `8bfc728a` correctly refuses the same commit-after-Q02 hard bar. Post-binding Q02 requalification dry-runs to `current_ex5_has_no_pass_bound_compile_record`. Historical task `fbafe53d…` has no session attestation. | 0 | **Unbounded while blocked.** Governed COMPILE_OK, then append-only Q02 requalification and the normal cascade. |

## Required next governed action

One of these evidence-producing paths must exist before another execution pass:

1. land a task-scoped, source-hash-bound COMPILE_EA repair authority for the exact five labels, backed by this task and the Option-W execution receipt; or
2. run a new governed build session that emits an authenticated `session_compile_ok.json`, then enqueue its receipt compile.

After COMPILE_OK:

- 12548/10412 may rerun Q08 directly only if the receipt authenticates the same EX5 and the variant-set identity passes the unchanged Q08 binding; otherwise restart at Q02 with the canonical base set;
- 20266/13138/13137 use the append-only post-binding Q02 requalification path, preserving all old Q02–Q08 evidence;
- 20266 additionally waits for a full-window peer cohort.

Retroactively synthesizing a session attestation from a historical build JSON is explicitly not acceptable provenance.

## Verification

- Read-only canonical binary/source/set hashing matched every bound SHA recorded in `blocker_state.json`.
- Read-only COMPILE_EA census: zero rows for all five EAs.
- Receipt classifier on historical build tasks: `SESSION_RECEIPT_ATTESTATION_INVALID` with the exact missing attestation paths recorded in `blocker_state.json`.
- Ordinary compile classifier: refuses all five on existing binary/work-item/setfile identity; no repair authority is registered for this task.
- `farmctl requalify-q02 --dry-run` for 20266, 13138, and 13137: all refuse `current_ex5_has_no_pass_bound_compile_record` with zero rejected compile records.
- `_q08_promotion_execution_binding` against a read-only DB with `QM_Q08_CLOSURE_CURRENCY_V2=own_rows` and `QM_Q08_IDENTITY_BINDING_V2=1`: 12548/10412 base predecessors bind; 20266 refuses missing compile provenance; 13138/13137 refuse the legacy commit-after-Q02 hard bar.
- No registry, verdict, historical work item, T_Live setting, AutoTrading setting, or terminal process was changed.
