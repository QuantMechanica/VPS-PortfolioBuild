# V4a Phase 4 — Build-6090 DEV2 preflight stop

Task: `8f17e236-e5d6-4468-bb1b-a9f888a0c93e`  
Observed at: `2026-08-28T00:56:36Z`  
Verdict: **HONEST NO — PREREQUISITES ABSENT; NO EXECUTION**

The commissioned parity-v2 run was not started. The requested exact Build-6090
runtime package and its signed copy manifest are not present in the governed
installation or evidence roots, and there is no durable OWNER validation seal
binding this new task. Reusing the Phase-3 authorization or substituting the
current Build-6140 factory runtime would break the sealed comparator premise.
DEV2 therefore remains unchanged at Build 5833 and the feature flag remains
Default-OFF.

This is an operations preflight result, not pipeline evidence and not an
activation verdict.

## 1. Runtime inventory

The current signed lane contract is
`framework/registry/dev2_lane_contract.json`, SHA-256
`866e4e346187e47c33e32beb30bb96dc4085e98cc316819fb33f7925306dda06`.
It pins the following physical DEV2 program tuple, which was re-hashed during
this preflight:

| Program | File version | Bytes | SHA-256 |
|---|---:|---:|---|
| `D:/QM/mt5/DEV2/terminal64.exe` | `5.0.0.5833` | 109,817,456 | `abd32f97efea4d3ddaaf694230c13eacef228e71d5115da7202033aa226c6946` |
| `D:/QM/mt5/DEV2/metatester64.exe` | `5.0.0.5833` | 21,256,304 | `d1e991d84243ec913db8c82505ab69eab48babcb2fa6826ab3871b3360abb646` |
| `D:/QM/mt5/DEV2/MetaEditor64.exe` | `5.0.0.5833` | 109,408,696 | `2c0c8e9e5c1239e30e8a908d9205cdb01b9cdfcf876752e43bd7a755cce58ad3` |

The factory copy named by the task is no longer Build 6090. Representative
`D:/QM/mt5/T1/terminal64.exe` is now `5.0.0.6140`, 121,845,984 bytes,
SHA-256
`86c563c8c113e4af8802dc91241ecd51fc06caf92cc86fc40026dd8046e526ed`.
T2 and T10 were independently sampled with the same version, byte count, and
hash. The remaining registered installation roots were inventoried by path;
the DEV1, DEV2, DXZ Truth, and T_Export copies are Build 5833, while the active
factory generation is Build 6140. No governed Build-6090 executable set was
found.

A filename inventory across `D:/QM/reports/dev2`, `D:/QM/reports/state`,
`D:/QM/reports/setup`, `D:/QM/strategy_farm/artifacts`, and the canonical
evidence directory found no artifact for this task, no V4a Phase-4 manifest,
and no DEV2 Build-6090 copy manifest. A native report that says `build 6090`
is evidence of the old test runtime; it is not an authenticated redistributable
program tuple.

## 2. Authorization gate

The only prior validation seal is
`docs/ops/evidence/2cb9d160_v4a_phase3_inputs/validation_authorization.json`,
SHA-256
`77af09ccc6f5036b19758b69c3b9b8aae5043e14a8152475d222c4acd8d504e6`.
It binds Phase-3 task `2cb9d160-d5c0-46ea-ae45-d145a63cf1f4`; it does not bind
this task or authorize replacement of DEV2 program bytes.

As a focused negative test, substituting the current task ID into that manifest
and passing it through the unchanged validator returned exactly:

```text
VALIDATION_TASK_ID_INVALID
VALIDATION_RESTART_TASK_ID_INVALID
```

The current router payload says `commissioned_by: claude-orchestrator
2026-08-28`; it does not contain the required `authorized_by:
OWNER_COMMISSION` validation manifest or a signed program-copy manifest.
No new authorization was inferred or fabricated.

## 3. Acceptance disposition

| Criterion | Result |
|---|---|
| DEV2 is exactly Build 6090 | **BLOCKED / NOT MUTATED** — exact authenticated Build-6090 program tuple and signed copy manifest absent |
| Commission parity in reference cell | **NOT RUN** — runtime/authentication prerequisite failed before launch |
| 20/20 table and complete-batch speedup | **NOT RUN** — no comparable cell may be created on Build 5833 or substituted Build 6140 |
| Activation checklist or honest no | **PASS: HONEST NO** — V4a premise cannot presently be tested as commissioned |
| Durable evidence | **PASS** — this committed preflight record preserves hashes, validator result, and containment state |

The prior parity packet remains unchanged at SHA-256
`1422acd7b9ce935c25ff908e22da5900ab838c7a913a468f8fc0056860cf3f72`.
Its one authenticated deviation and nineteen sealed stop rows remain the last
valid V4a result. No 20/20 parity or speedup value is claimed.

## 4. Required inputs for a future governed attempt

1. An immutable Build-6090 program package containing at least
   `terminal64.exe`, `metatester64.exe`, and `MetaEditor64.exe`, with provenance,
   per-file SHA-256 values, and a signed copy/rollback manifest.
2. An OWNER validation authorization that binds this task (or a newly routed
   successor), the exact program-manifest hash, DEV2-only scope, commission
   configuration, staged-EX5 schema, stop policy, and restoration contract.
3. A reviewed lane-contract/provisioner delta that verifies the complete
   runtime before and after the run and restores the signed Build-5833 lane on
   every closeout path.
4. A reviewed receipt-adapter contract that maps the governed DEV2 result to
   the cold worker's `staged_ex5` and
   `pre_dispatch_verified/required_sha256` semantics without weakening any raw
   report, logger, trade, or schema comparator.

Only after those inputs exist may the reference commission cell run. A full
20-cell batch and batch speedup are downstream of an exact reference cell.

## 5. Safety and containment verification

- `QM_ENABLE_WARM_CELL_RUNNER` was absent in the process environment
  (Default-OFF).
- DEV2 `terminal64.exe` / `metatester64.exe` process count: `0`.
- Residual `QM_DEV2*` Scheduled Task count: `0`.
- No terminal was started manually or through the controller.
- No T1–T10 process was interrupted; active factory work was only observed.
- T_Live and AutoTrading were not enabled or changed.
- No DEV2, factory, cold-reference, lane-contract, commission, EX5, receipt,
  database, queue, or pipeline bytes were changed.

