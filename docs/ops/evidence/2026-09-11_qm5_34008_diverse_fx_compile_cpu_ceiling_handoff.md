# QM5_34008 diverse-FX compile handoff at CPU ceiling

Date: 2026-09-11 04:40Z

Branch: `agents/board-advisor`

Pre-work HEAD: `50ba1b7e464da434d7dc0104782f3e2e9758fc85`

## Outcome

`QM5_34008_multicurrency-basket-dispersion-hedger` was selected from the farm
database as the highest-diversity eligible build handoff: one structural H1
basket spanning `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`,
`USDCAD.DWX`, `USDCHF.DWX`, and `USDJPY.DWX`. Its approved card has exact
`PASS` values for R1-R4, an approved G0, active EA/magic registry rows, and a
canonical fixed-risk backtest setfile for every symbol.

The source-only build is already present and has exactly one open farm row:

- work item: `1c77fcf2-39ef-47f6-a448-5dd1457bce03`
- phase/status: `COMPILE_EA` / `pending`
- claim/verdict/attempts: `NULL` / `NULL` / `0`
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`, active,
  `release_on_restart=1`
- source SHA-256 in both the queue payload and working tree:
  `7203979e4a508dee2a5e041c57538e29b8bb107dbdf0cf0d53b0d76c977266ae`
- approved-card SHA-256:
  `5f9c08183854aeb2e6c91e361401dfd9956685f952334b35a10ca1aac4835050`

The exact-item rollout dry-run reported `release_count=1`, no deferred rows,
and matching expected/actual source hashes. No second compile or Q02 row was
created.

## Binding PACER input-pin audit

Run after resolving the generated source and before any possible compile-hold
release:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger/QM5_34008_multicurrency-basket-dispersion-hedger.mq5"

exit_code=0
ok=true
predicate=EA_FRAMEWORK_INPUT_PINNED
source_count=1
hit_count=0
hits=[]
```

The source therefore passes the PACER build guard. In particular, this check
found no forbidden equality pin involving RNG, News, Friday Close, or Stress
framework inputs.

## CPU hard stop

Before applying the exact compile-hold release, the resident worker admission
guard emitted:

```json
{"event":"cpu_high_pause","terminal":"T1","at_utc":"2026-09-11T04:40:19.113541+00:00","cpu_load_percent":97.2,"threshold_percent":97.0,"hysteresis_latched":true}
```

This crossed the binding 97% backtest CPU ceiling. Work stopped immediately:
the activation hold was not released, the compile was not claimed, no EX5 was
produced, no Q02 work was enqueued, and no farm-database mutation was made.
The existing exact work item remains the collision-safe continuation point for
a later paced cycle after CPU admission reopens; it should be released only by
the governed exact-item rollout path, then allowed to compile through the
resident worker.

No portfolio gate, `T_Live`, AutoTrading, deployment manifest, or live account
state was touched.
