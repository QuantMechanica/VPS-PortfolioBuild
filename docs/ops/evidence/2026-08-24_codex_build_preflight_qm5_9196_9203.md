# Codex build preflight refusal: QM5_9196 and QM5_9203

Date: 2026-08-24 (Europe/Berlin)  
Lane: `codex` scheduled orchestration  
Checked at: `2026-08-24T01:11:12Z`  
Canonical checkout baseline: `64db89ad28c2b36b4142bf709680e962dfdec2ee`  
Outcome: `BUILD_BLOCKED_PRECONDITION`

## Scope

| Priority | Router task | Card identity | EA registry | Magic rows | Canonical build files |
|---:|---|---|---|---:|---|
| 10 | `31cb89f3-2190-4653-b2b4-8a4dbd86bac7` | `QM5_9196_mql5-macd-obv-zero` | exact active row | 0 | skeleton MQ5 only |
| 10 | `4b0bd563-9542-4ac7-b942-3e3845e66f3d` | `QM5_9203_mql5-cci-zero` | exact active row | 0 | skeleton MQ5 only |

## Deterministic preflight findings

1. Both runtime cards exist under `D:/QM/strategy_farm/artifacts/cards_approved/`, declare the requested identity and slug, and have literal `g0_status: APPROVED`.
2. `C:/QM/repo/framework/registry/ea_id_registry.csv` has one exact active row for each requested EA ID and slug.
3. Exact filtering of `magic_numbers.csv` by EA ID returns zero rows for both 9196 and 9203. Each card targets `EURUSD.DWX`, `GBPUSD.DWX`, and `GER40.DWX`, so the required symbol-slot allocations are absent.
4. Each canonical EA directory contains only its `.mq5` skeleton. Both sources still contain `TODO: Auto-generated skeleton`; neither directory has an `.ex5`, `SPEC.md`, or `.set` file.
5. Separate identity observation: active EA 9198 also uses the exact slug `mql5-cci-zero` and has three of its own magic rows. Those rows belong to EA 9198 and cannot satisfy EA 9203's allocation gate. This cycle did not adjudicate or mutate the duplicate slug.

The `qm-build-ea-from-card` contract requires governed magic rows for every `(ea_id, symbol_slot)` used before implementation and requires stopping on any failed preflight gate.

## Focused verification

A read-only PowerShell verification loaded both canonical CSV registries with `Import-Csv`, matched IDs and slugs using exact string equality, inspected the approved cards and EA directories, and asserted the expected refusal condition. Both assertions passed:

```text
31cb89f3 / QM5_9196: card=APPROVED registry=9196/mql5-macd-obv-zero/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
4b0bd563 / QM5_9203: card=APPROVED registry=9203/mql5-cci-zero/active magic=0 ex5=0 spec=false sets=0 skeleton_todo=true -> FAIL_MAGIC_PRECONDITION
```

Approved-card SHA-256 values, in table order:

```text
fa8030639dcab847255e764a7bbf122bff9c39da75b52bcd4248b6f599f7ae27
4ac8f5fffaffd42d7836810b11a094fd3c2c60ad64eed4bd06318a1226f39173
```

Skeleton MQ5 SHA-256 values, in table order:

```text
f2ab05aedb23a8f0a6fbebfb62809e913c3203dcba2826b01b754f40622d6279
5b4bc1dfbad194ad92b914935325801bbc49dc516c2a6add7ae988aacf02a284
```

## Boundary and required upstream action

No EA source, setfile, registry, resolver, framework, terminal, or pipeline state was changed, and compile was intentionally not run. OWNER-governed intake must allocate complete magic rows for each requested EA and resolve whether the duplicate active `mql5-cci-zero` slug is intended before a future build is routed. Codex cannot manufacture those records or borrow another EA's magic numbers.

## Router disposition

The required `REVIEW` update was attempted once for each task with this artifact and its short prebuild-refusal verdict. The canonical router refused both attempts with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`, because build review requires a hash-bound JSON packet proving committed MQ5, EX5, setfiles, and strict-build PASS.

Neither packet can truthfully exist after the missing-magic preflight gate. Both tasks were therefore transitioned to `BLOCKED` with this artifact and task-specific `PREBUILD_BLOCK` verdicts. EA 9196's first `BLOCKED` update encountered a transient `sqlite3.OperationalError: database is locked` before mutation; the same update was retried and returned `updated=true`. EA 9203 also returned `updated=true`. No infrastructure, build, `REVIEW`, pipeline, or approval verdict was manufactured.
