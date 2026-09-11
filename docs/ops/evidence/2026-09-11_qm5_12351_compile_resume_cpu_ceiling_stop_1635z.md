# QM5_12351 compile continuation stopped at the PACER CPU ceiling

Date: 2026-09-11 16:35Z

Branch: `agents/board-advisor`

## Outcome

The exact non-duplicate continuation for
`QM5_12351_alp-ema12-26` was identified, but the paced-fleet admission check
hit the binding CPU ceiling before a farm claim or compile-hold release.

The five one-second whole-host samples were `100.0%`, `100.0%`, `94.9298%`,
`79.1248%`, and `89.8550%`. Their average was `92.7819%` and their maximum was
`100.0%`. Admission requires both the average and maximum to be strictly below
`97.0%`, so the maximum refused the continuation.

The process snapshot contained seven `terminal64` and five `metatester64`
processes. The farm database had five active work items.

## Collision-safe continuation point

The prior paced build already wrote and committed the EA, its seven canonical
fixed-risk setfiles, and its SPEC. It also enqueued one governed compile item:

- build task: `b63e991a-cf37-4a8d-a884-a3ef1bb5a90e`
- compile work item: `92797bae-0f0d-45cb-872d-6f0bcccb258d`
- status / claim / verdict: `pending` / `NULL` / `NULL`
- active hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- source SHA-256:
  `27da9fb5c285dc78d5bd2ca2a1185c131de6511aa7026d42ea8fd0952df51b34`
- fixed-risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- current Q02 rows: zero
- open agent-task claims for this EA: zero

Creating a second compile row or rebuilding the unchanged source would be a
duplicate. The next admitted paced cycle should recheck the exact item and
source hash, rerun the PACER pin audit, release only this item's governed
compile hold, wait for `COMPILE_OK`, and then use `farmctl intake-first-q02`
for exactly one first Q02 canary.

## PACER input-pin audit

The unchanged canonical source was audited during selection:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12351_alp-ema12-26/QM5_12351_alp-ema12-26.mq5"
exit_code=0
ok=true
predicate=EA_FRAMEWORK_INPUT_PINNED
hit_count=0
hits=[]
```

No MQ5 was generated or modified in this cycle, so the build guard's
post-write/pre-enqueue boundary was not crossed. A future compile enqueue or
hold-release cycle must not rely on this observation; it must audit the exact
then-current source again.

## Boundaries preserved

No farm claim was created, no compile was enqueued or released, no Q02 row was
created, and no EA, setfile, registry, resolver, pipeline verdict, portfolio
gate, deploy manifest, `T_Live`, or AutoTrading state was changed.

Machine-readable receipt:
`artifacts/qm5_12351_compile_resume_cpu_stop_20260911T163506Z.json`.
