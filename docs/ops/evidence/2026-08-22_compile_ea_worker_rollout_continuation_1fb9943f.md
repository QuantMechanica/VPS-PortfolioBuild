# COMPILE_EA worker rollout continuation — live-contention proof and bounded wave

Date: 2026-08-22
Router task: `1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8`
Branch: `agents/board-advisor`
Verdict: `REVIEW_ROLLOUT_PROVEN_BOUNDED_WAVES` — the canonical worker consumed a canary and a three-EA wave under live factory contention; every build finding remained failed and unenqueued.

## Outcome

The two unblock conditions from the earlier review are satisfied:

1. R11's 91 false `failed/INVALID` historical rows remain immutable and 90 source-fresh append-only successors were created by the separately reviewed revival (`0b826cd3a`).
2. The normal terminal worker path exercised the global include-mirror mutex and per-file atomic replacement while Q-only terminal work was live. Non-claimed terminal include trees were deferred; no running terminal was stopped, restarted, or mirrored into.

This continuation released one exact retry canary and then a bounded wave of three source-fresh revival rows. Workers claimed every row through the ordinary selector/lease/ownership-CAS path. There was no second dispatcher and no targeted worker invocation.

## Incident-safe canary lineage

`QM5_1009_lien-fade-double-zeros` required append-only retry lineage because each failed row is intentionally immutable:

| Work item | Normal claim | Result | Finding |
|---|---|---|---|
| `949b6983-0584-4318-962c-86dfb781fc65` | T8, 06:35:55Z | `COMPILE_FAIL` | `CANDIDATE_RECHECK_REFUSED:WORK_ITEMS_EXIST`; exact predecessor traversal was then fixed in `feaf34bd3`. |
| `525cabcd-2617-450a-a15d-97f5271fc005` | T5, 07:15:36Z | `COMPILE_FAIL` | PowerShell positional array splatting bound the literal `-ClaimedTerminal`; 36 fixed-risk setfiles were generated before refusal. Named bindings were fixed in `0b2e68027`. |
| `e4fe9323-3b8a-43c7-933e-49a7ce06c373` | T10, 07:36:37Z | `COMPILE_FAIL` | Real compiler finding: line 94 calls `RoundPips` with 2 arguments while the framework signature requires 3; 1 error, 0 warnings, no EX5. |

The final canary's durable compiler receipt is
`D:/QM/reports/compile/20260822_073843/summary.csv`; its log is
`C:/QM/repo/framework/build/compile/20260822_073843/QM5_1009_lien-fade-double-zeros.compile.log`.
The receipt records:

- `include_mirror_mutex=D:\QM\strategy_farm\state\locks\include_mirror.lock`;
- `include_mirror_atomic_replace=True`;
- direct sync only to T10's portable include tree and its matching MetaQuotes data tree;
- 15 non-claimed include trees deferred while T1, T3, T4, T6, and T8 were running;
- `reason_class=COMPILE_ERRORS`, `errors=1`, `warnings=0`.

The parent evidence originally collapsed that structured result to `BUILD_CHECK_FAILED` because a child error record terminated capture before the final receipt fields were parsed. `23ad07040` now keeps the diagnostic non-terminating and restores the caller's error preference after collecting the structured output and real exit code. The next live wave proves the fix.

## Bounded three-EA wave

Dry-run selection reported 93 held pending rows, selected exactly the three oldest source-fresh revival successors, and retained SHA-stale `QM5_41097` under hold. The release utility changed only those three holds, after an online backup; resident workers then claimed them normally.

| EA / work item | Worker and live contention | Compile result | Build-check result and final state |
|---|---|---|---|
| `QM5_1345` / `2f5ccf1a-3f2a-4334-8bd2-48abbd698ae4` | T2; T1/T3/T4/T5/T6 running; 15 include trees deferred; atomic replace true | PASS, 0 errors, 0 warnings; EX5 SHA `06a253b7f2cfd6af61100c3cd12383b3d10d1ae78c0aaef1ba1a35b8edb708c8` | FAIL: `EA_Q08_MAE_HOOK_MISSING`, `EA_TRADE_REQUEST_UNINITIALIZED`; `failed/COMPILE_FAIL`, unenqueued |
| `QM5_1404` / `f5ba6093-62ac-4453-bd07-0f18c085365a` | T9; T1/T10/T3/T4/T6 running; 15 include trees deferred; atomic replace true | FAIL: `COMPILE_ERRORS`, 78 errors, 13 warnings, no EX5. First error is missing `Include\Trade\Trade.mqh` in T9's MetaQuotes data tree, followed by dependent declaration errors. | FAIL additionally records `BUILD_CHECK_COMPILE_FAILED`, `EA_Q08_MAE_HOOK_MISSING`, `EA_TRADE_REQUEST_UNINITIALIZED`; `failed/COMPILE_FAIL`, unenqueued |
| `QM5_1405` / `f04926fa-3138-4556-9014-68a59f2292d2` | T8; T1/T10/T3/T4/T6 running; 15 include trees deferred; atomic replace true | PASS, 0 errors, 0 warnings; EX5 SHA `3d3ce7165adb4a0d3d775128137ce0491af99f8925de119428994c98b93f8c00` | FAIL: `EA_Q08_MAE_HOOK_MISSING`, `EA_TRADE_REQUEST_UNINITIALIZED`; `failed/COMPILE_FAIL`, unenqueued |

Per-work receipts:

- `D:/QM/reports/work_items/2f5ccf1a-3f2a-4334-8bd2-48abbd698ae4/QM5_1345/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/f5ba6093-62ac-4453-bd07-0f18c085365a/QM5_1404/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/f04926fa-3138-4556-9014-68a59f2292d2/QM5_1405/COMPILE_EA/compile_evidence.json`

All generated setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`: 36 for QM5_1009 and 13 each for QM5_1345, QM5_1404, and QM5_1405. No news-staleness setting was raised. A live DB read after completion found no non-`COMPILE_EA` work item created for any of the four EAs after release.

## Transaction receipts

| Mutation | Backup | SHA-256 |
|---|---|---|
| Exact first canary retry append | `farm_state_before_compile_recheck_retry_20260822T065029Z_aaed1736.sqlite` | `7c41147a607b722c63bb691592ffb9fb5493c3804805884b260abbb37f0d9739` |
| Exact first retry hold release | `farm_state_before_compile_wave_20260822T065750Z_c9d7a3f2.sqlite` | `15be581f9766cee4acaf0644c3c592f6869f3ea12c8f3c46633e3a8f9f8520a2` |
| Exact binding-failure retry append | `farm_state_before_compile_rollout_retry_20260822T073255Z_2e606371.sqlite` | `3d28ddb913fc147f587d778d47e21067fb9c9b71aedb713dc61807b4686504f4` |
| Exact final canary hold release | `farm_state_before_compile_wave_20260822T073429Z_97943b53.sqlite` | `55199b37193cd77a6ffab461a63b6f63d33da817e88c46118f52d5ad69e68de6` |
| Three-EA wave hold release | `farm_state_before_compile_wave_20260822T075024Z_41a8bf3c.sqlite` | `c56d5d34fdfe045d543cad3009a04c80505ea8e6a5e44c8c75655e2064af0484` |

The append-only retry mutations used the factory mutation lock and released it after verification. Hold releases used their narrower reviewed contract: online SQLite backup, source-SHA revalidation inside `BEGIN IMMEDIATE`, and compare-and-swap update of only the selected active hold.

## Code and verification

Rollout hardening commits on `agents/board-advisor`:

- `0b826cd3a` — exact append-only revival for 90 R11-invalidated source-fresh rows;
- `feaf34bd3` — sanctioned predecessor-lineage traversal;
- `5424bb788` — exact work-item selector for bounded hold release;
- `ad8b9a9fd` — persist mirror mutex and atomic-replace receipt;
- `a2bc214f9` — admit compile utility under reservation pressure without lowering the 24 GB raw commit floor;
- `0b2e68027` — preserve named PowerShell worker bindings;
- `23ad07040` — preserve structured compile failure receipts.

Focused verification completed:

```text
PowerShell parser: framework/scripts/build_check.ps1, framework/scripts/compile_one.ps1
POWERSHELL_PARSE=PASS

python -m pytest \
  tools/strategy_farm/tests/test_build_gate_hardening.py::test_compile_worker_binding_uses_named_splatting \
  tools/strategy_farm/tests/test_build_gate_hardening.py::test_compile_worker_preserves_structured_failure_receipt -q
2 passed in 0.74s
```

The live three-row wave is the end-to-end verification of source binding, normal claims, fixed-risk generation, claimed-terminal-only mirroring, atomic replacement, explicit failure classes, and fail-closed downstream admission.

## Remaining governed state

Exactly 86 of the 90 R11 revival successors remain pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; later operator cycles can continue with the same bounded dry-run/apply ceremony. `QM5_41097` work item `d646713d-c8ba-41ef-98f4-9b544780e714` remains held because its current source SHA does not match its enqueued SHA and requires sanctioned supersede/cancel plus fresh enqueue. Sixteen additional held rows were appended concurrently at 08:01:37Z by the separate DL-089 force-rebuild effort and were not released by this task.
The SHA-stale `QM5_12946` historical R11 row remains immutable `failed/INVALID`, held, and without a successor for the same sanctioned recovery path.

No T_Live or AutoTrading state changed, no terminal was launched/stopped/restarted, no active T1–T10 backtest was interrupted, and COMPILE_EA asserted no pipeline or gate verdict.
