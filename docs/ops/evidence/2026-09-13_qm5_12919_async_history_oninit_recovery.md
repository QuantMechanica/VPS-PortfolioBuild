# QM5_12919 asynchronous basket-history OnInit recovery

Date: 2026-09-13

Branch: `agents/board-advisor`

EA: `QM5_12919_amp-value-momentum-xasset`

Claim: `a9e1950c-3348-4532-a415-3571c76e66c4`

## Selection

No collision-free unbuilt approved diversity card was available. The only clean
unbuilt card was already represented by an active Codex rework task. QM5_12919
was therefore selected under PACER priority 2: it is a low-frequency monthly
cross-asset sleeve spanning four G10 FX pairs and four equity indices, and its
latest USDJPY Q02 row was stopped by infrastructure before strategy evaluation.

## Bound failure and diagnosis

| Item | Evidence |
|---|---|
| Q02 predecessor | `4ae565d6-d87b-4c9e-8ac5-38f97ad95e56` |
| Result | `INFRA_FAIL` |
| Reason | `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` |
| Report | `D:/QM/reports/work_items/4ae565d6-d87b-4c9e-8ac5-38f97ad95e56/QM5_12919/20260910_204553/summary.json` |
| Reproduction signature | framework initialization and eight `BASKET_WARMUP` requests succeeded, followed in the same OnInit instant by `STRATEGY_DIAG ready=0 required=4` and `SETUP_DATA_MISSING` |

`CopyClose`/`CopyRates` warmup for foreign symbols is asynchronous in MT5. The
EA requested all eight histories and then synchronously required four complete
histories before returning from `OnInit`. That converted ordinary terminal
history loading into `INIT_FAILED`; the test never reached a strategy decision.
This is a setup/implementation defect, not evidence that the card has no entry
opportunities.

## Repair

Commit `77d5dfaa54` removes the synchronous basket-readiness veto from `OnInit`.
The existing exact-depth refresh remains in the monthly decision path, which
retries history loading and fails closed unless at least
`strategy_min_eligible_symbols=4` are ready. A bounded
`SETUP_DATA_MISSING` strategy diagnostic now records persistent insufficient
eligibility. The card mechanics and economics are unchanged: 21-day skip,
252-day momentum, 1260-day value, fixed 50/50 composite, top three, minimum
four eligible symbols, and monthly rebalance.

The mandatory source audit was run after the final MQ5 write and immediately
before the compile enqueue:

```text
ok=true
predicate=EA_FRAMEWORK_INPUT_PINNED
hit_count=0
```

Final repaired MQ5 SHA-256:
`91b04d4e5791accda221029f1806627f816ca0e4fa9b114860237eb9c82a27b5`.
The exact source-repair registration is bound by
`docs/ops/evidence/2026-09-13_qm5_12919_async_history_compile_authority.json`.

Focused contract test:

```text
python -m pytest framework/EAs/QM5_12919_amp-value-momentum-xasset/docs/test_history_readiness_contract.py -q
3 passed
```

## Compile handoff

The governed enqueue created COMPILE_EA work item
`626dfaf7-ab5b-40f5-9cab-3a2422fa53b7`. It was released through the compile-wave
utility, claimed on T4, and refused before MetaEditor execution:

```text
verdict=COMPILE_FAIL
reason=CANDIDATE_RECHECK_REFUSED
candidate reasons=SOURCE_REPAIR_AUTHORITY_INVALID;EX5_ALREADY_PRESENT;WORK_ITEMS_EXIST;BOUND_SETFILE_HASH_EXISTS
```

Evidence:
`D:/QM/reports/work_items/626dfaf7-ab5b-40f5-9cab-3a2422fa53b7/QM5_12919/COMPILE_EA/compile_evidence.json`.

The enqueue process loaded the committed source-repair registration and
accepted the row. The resident T4 worker reported an empty
`source_repair_artifact_bindings` array and `source_repair_authorized=false`,
which proves it was still running a pre-registration module image. No compiler
or build check ran, no EX5 changed, and no Q02 successor was enqueued.

A repair-successor dry-run was also correctly refused because this legacy card
has no open canonical `tasks.kind=build_ea` binding. The normal `build-ea`
preflight then raised the durable follow-up task
`27cdbc58-6086-4eac-ba43-51431d565476` because the approved legacy card lacks
machine-readable `target_symbols`, despite eight active registry/magic rows.
Neither refusal was bypassed.

## Next governed action

After a reviewed terminal-worker reload, rerun the mandatory pin audit and
enqueue the same source hash with authority
`router_build_rework:a9e1950c-3348-4532-a415-3571c76e66c4:QM5_12919`.
Release `COMPILE_EA_WORKER_ROLLOUT_PENDING` only after that reload. On compile
PASS, enqueue an append-only, exact-EX5-hash Q02 successor of
`4ae565d6-d87b-4c9e-8ac5-38f97ad95e56`, subject to the backtest CPU admission
ceiling. No T_Live, AutoTrading, portfolio-gate, or deploy-manifest state was
touched.
