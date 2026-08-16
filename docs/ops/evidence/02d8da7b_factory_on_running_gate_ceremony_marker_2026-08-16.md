# Factory_ON running-start gate and ceremony-incomplete marker

Date: 2026-08-16

Router task: `02d8da7b-cea9-41f3-92a0-311638331860`

Verdict: `REVIEW — CODE AND REGRESSION TESTS COMPLETE; RUNTIME CEREMONY NOT EXECUTED`

## Scope delivered

The post-start health gate now has one explicit long-runtime allow-list entry:
`QM_StrategyFarm_AgentRouter_5min`. A current Router `Running` instance is
accepted only when its start timestamp is parseable, within the restart
freshness window, and strictly newer than its captured pre-start baseline.
That path deliberately does not inspect `LastTaskResult`, because a concurrent
five-minute trigger can replace it with overlap refusal `0x800710E0` while the
legitimate Router instance is still running.

All other critical tasks retain fresh `Ready`/result-`0` semantics. A `Ready`
row with `0x800710E0` is classified `pending_overlap`, not execution failure;
ordinary nonzero completions are classified `execution_failure`. Latches now
record `acceptance_mode` and normalized `observed_start_utc`. A bounded timeout
emits a sorted `starved_tasks=[...]` list before the last detailed assessment.

`Factory_ON.ps1` now publishes
`D:\QM\strategy_farm\state\FACTORY_ON_CEREMONY_INCOMPLETE.json` immediately
before removing `FACTORY_OFF.flag`. The marker binds the mutation-lock nonce,
runtime decision identity, process, mutation point, and the exact five-task AI
quiet zone. It is removed by exact-content CAS only after:

1. replacement workers start;
2. the post-start health gate passes;
3. all five quiet-zone tasks are released;
4. immediate full task/worker health revalidation passes; and
5. the authorized restart-hold release completes.

Therefore an abnormal PowerShell exit or externally killed host cannot depend
on a `finally` block to surface the incomplete ceremony. Marker presence or
unreadable/invalid marker content is an unconditional `FAIL` in `farmctl
health`. Both the cockpit top-bar and programme safety strip prioritize it as
`CRITICAL`, including when rollback has also asserted an intentional OFF flag.

## Files

- `tools/strategy_farm/factory_restart_health.ps1`
- `tools/strategy_farm/Factory_ON.ps1`
- `tools/strategy_farm/health.py`
- `tools/strategy_farm/render_cockpit.py`
- `tools/strategy_farm/tests/Test-FactoryRestartPostStartHealth.ps1`
- `tools/strategy_farm/tests/test_factory_restart_post_start_health.py`
- `tools/strategy_farm/tests/test_factory_on_ceremony_marker.py`
- `tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py`

## Verification

Isolated PowerShell contract, including all eight required gate cases:

```text
PASS Test-FactoryRestartPostStartHealth.ps1 (37 assertions)
```

Focused Python suites:

```text
41 passed in 16.72s
```

Broader factory/health/cockpit regression selection:

```text
207 passed in 111.13s
```

`git diff --check` passed. The PowerShell parser check is included in the
focused Python suite. The marker round-trip test uses a temporary path and
verifies exact publication, schema/content, exact-content deletion, and absent
post-completion state.

## Runtime non-action evidence

No Factory_OFF or Factory_ON ceremony was run. No scheduled task was enabled,
disabled, started, or stopped by this work; no worker or T1–T10 backtest was
interrupted; T_Live and AutoTrading were not touched.

A final read-only snapshot showed all five quiet-zone tasks registered and
enabled (`CodexOrchestration` was `Running`; Gemini/Claude orchestration,
CodexFleetPacer, and AgyGovernor were `Ready`). Both `FACTORY_OFF.flag` and the
new ceremony-incomplete marker were absent. Claude remains the only actor
authorized to bind this patch into a fresh runtime-activation decision and run
the ceremony.
