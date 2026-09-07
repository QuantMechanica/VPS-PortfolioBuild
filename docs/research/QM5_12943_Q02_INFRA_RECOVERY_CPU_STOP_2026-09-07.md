# QM5_12943 Q02 INFRA Recovery — CPU Ceiling Stop

## Outcome

`QM5_12943_robopip-hlhb-trend-catcher-h1` is a distinct FX funnel-recovery
candidate whose only Q02 canary ended in infrastructure failure before a tester
result could exist. The failure is diagnosed and the governed append-only
recovery path is ready, but no Q02 successor was enqueued because the mandatory
fresh host-CPU window reached `97.072027%`, above the strict `<97%` ceiling.

The terminal source row remains unchanged and unclaimed. No tester, portfolio
gate, `T_Live`, live manifest, or AutoTrading state was touched.

## Why This EA

The nominal highest-diversity build-backlog card, `QM5_34008`, was already
rebuilt, audited, committed, and compile-enqueued by another paced agent. Taking
it again would duplicate work. A read-only farm-DB scan then selected the newest
unowned FX Q02/Q03 infrastructure strand with a current on-disk binary:

- EA: `QM5_12943_robopip-hlhb-trend-catcher-h1`
- symbol/timeframe: `EURUSD.DWX` / `H1`
- source work item: `2b04b129-89e8-4489-8653-5dac22f8439a`
- source state: `failed / INFRA_FAIL`, no claimant
- open work for this EA: none
- matching open router/source task: none

The EA also has active registry coverage for seven FX pairs in addition to its
index and gold rows, so recovering its EURUSD canary directly serves the mission's
instrument-diversity constraint.

## Root Cause and Existing Fix

The immutable source payload records `worker_crashed_handling_item`. Its traceback
ends in an SQLite SH3 check-constraint failure while
`record_work_item_spawn_refusal` tried to write `status=failed` without a stored
verdict taxonomy. The tester had not started, and the staged binary had already
been verified byte-for-byte. This is not strategy, history, ONINIT, or binary
evidence.

Commit `c1fe07e30fe27d92233ecae64773ca974abf3493` fixed the defect by writing
`verdict_taxonomy=infra` in both the column and payload for a spawn refusal.
Commit `b63bf8b6e8` added the authenticated same-binary recovery path for this
exact worker-crash family. No source-code change to the EA is justified.

## Identity and Guard Evidence

- source-row expected EX5 SHA-256:
  `95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2`
- current canonical EX5 SHA-256: same value
- current MQ5 SHA-256:
  `6ebb42799e23755d3c31c1de56dca0c9c4023e60ccd4519cd9256f34c239161a`
- EURUSD setfile SHA-256:
  `8e1604e168b117a130a92285d3892352151c85a5c49965e71a9345fadd726586`
- setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- magic row: slot `6`, magic `129430006`, status `active`
- framework-input pin audit: `ok=true`, zero
  `EA_FRAMEWORK_INPUT_PINNED` findings

## Binding CPU Stop

Immediately before the guarded enqueue, five one-second whole-host CPU samples
were:

`89.960634%`, `88.714113%`, `80.568567%`, `97.072027%`, `82.520446%`.

Average utilization was `87.767157%`; maximum utilization was `97.072027%`.
Admission requires both values to be strictly below `97%`. The maximum therefore
bound, and the enqueue command was not executed.

The machine-readable receipt is
`artifacts/qm5_12943_q02_infra_recovery_cpu_stop_20260907.json`.

## Exact Resume

After a new five-sample CPU window clears the same strict ceiling, execute the
already validated append-only command:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12943 --phase Q02 --from-work-item-id 2b04b129-89e8-4489-8653-5dac22f8439a --append-only-rerun-of 2b04b129-89e8-4489-8653-5dac22f8439a --rerun-reason 'same-binary retry after SH3 spawn-refusal taxonomy fix c1fe07e30f; source worker crash authenticated and current EX5 unchanged' --expected-current-ex5-sha256 95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2
```

This preserves the failed source row, authenticates its embedded traceback,
binds the unchanged current EX5, revalidates the fixed-risk setfile, and refuses
duplicates if another agent has created an open successor in the meantime.
