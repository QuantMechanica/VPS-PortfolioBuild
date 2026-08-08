# FTMO M1 bootstrap tooling — build-only handoff

Date: 2026-08-08

Router task: `a6322102-d82d-487c-b372-78f46ef5aa84`

Code commit: `ae5331f6713d9f53e06982639fae86894cf67aac`

Scope: tooling and mocked regression tests only; no lane or factory execution

## Outcome

The missing Saturday-window tooling is implemented and ready for independent
Claude review:

- `framework/scripts/mt5_diagnostics/QM_M1_SpreadHarvest.mq5` is a script-only,
  zero-trading-call MQL5 harvester. It accepts a comma-separated symbol list and
  output tag, selects each symbol, progressively requests M1 history from
  `2026-01-01`, retries history errors 4401/4403, writes the requested raw OHLC,
  tick-volume and spread JSONL, and writes coverage last as the completion
  marker. It separately derives `tick_first` / `tick_last` from
  `CopyTicksRange`; unavailable deep ticks are never relabelled as coverage.
- `tools/strategy_farm/ftmo_m1_bootstrap.py` implements two explicit,
  `--execute`-gated paths. `ftmo` operates one registered lane, requires the
  other lane idle, binds the unchanged Program Files challenge process by
  PID/path/CreationDate, compiles through that lane's MetaEditor, starts only
  the lane-local terminal with `/portable`, and can terminate only the exact
  process it spawned. `dxz` additionally requires a process-free and
  active-work-item-free T1-T10 slot, acquires the existing farm terminal
  reservation, rechecks the slot, and releases only its own reservation.
- Raw script rows are validated and atomically projected into the existing
  strict `qm.m1-spread-row/v1` schema at the four reviewed spec paths. The
  reviewed HCC path must exist and is SHA-256-bound before publication.
- Cross-lane history output matches `ftmo_lane_runner.py`'s existing
  `qm.ftmo-history-coverage/v1` contract exactly. The first lane remains
  `HOLD_PARTIAL`; after the second lane produces its artifact, the tool emits
  full lane-root-bound observations for both STREAM1 and STREAM2. Missing M1 or
  real-tick coverage never reaches `_apply_history_observation`.

The code does not edit `ftmo_lane_runner.py` or any Sunday-bound file from
commit `0087a0f96`. It does not write a Q verdict, toggle AutoTrading, enable
Experts, read T_Live files, signal T_Live, or signal the challenge terminal.

## Source identities

| Artifact | SHA-256 |
|---|---|
| `framework/scripts/mt5_diagnostics/QM_M1_SpreadHarvest.mq5` | `7c3b28da74da53eeee3c1d9bdcc50668ee42f90d8900da0c2699e39f2d627cff` |
| `tools/strategy_farm/ftmo_m1_bootstrap.py` | `57d9a70ee25d3d663fb8bd0cd1583e65a2efe1c671da6653ca6d5de23d3c5518` |
| `tools/strategy_farm/tests/test_ftmo_m1_bootstrap.py` | `945bab286c89c23f443a48a668acccced4d67234c5c8b707c312a10fbd28a710` |

## Focused verification

Command:

```text
python -m py_compile tools/strategy_farm/ftmo_m1_bootstrap.py
python -m pytest -q tools/strategy_farm/tests/test_ftmo_m1_bootstrap.py tools/strategy_farm/tests/test_ftmo_lane_runner.py tools/strategy_farm/tests/test_ftmo_spread_calibration.py tools/strategy_farm/tests/test_ftmo_daily_net_export.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_stream_reconciliation.py tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py
```

Verbatim result:

```text
........................................................................ [ 90%]
........                                                            [100%]
80 passed, 5 subtests passed in 3.67s
```

The 19 new tests mock all compile, launch, process-observation, termination and
reservation boundaries. They cover raw-to-spec projection, non-finite and
ordering refusals, coverage binding, partial/full runner handoff, challenge and
other-lane gates, T_Live exclusion, exact PID/path/CreationDate termination,
startup `Enabled=0` / `AllowLiveTrading=0`, 0E/0W compile-log enforcement,
factory process/claim/reservation exclusion, reservation duration, and the
machine-wide serialization lock.

Execution gate check:

```text
python tools/strategy_farm/ftmo_m1_bootstrap.py ftmo --lane FTMO_STREAM1
REFUSED: FTMO bootstrap requires --execute after reviewer authorization
```

Static scans found no `OrderSend`, `OrderSendAsync`, `CTrade`, trade include,
position open/close, `Buy`, or `Sell` call in the MQL5 source.

## Deliberately not performed

- No `terminal64.exe` was launched.
- No real process was terminated.
- No FTMO lane or DXZ extraction ran.
- No real MetaEditor compile ran; MQL compilation is part of the reviewed
  orchestrator execution boundary, and its 0E/0W result is therefore still
  unproven.
- No HCC or calibration projection was produced. At handoff, all four reviewed
  projection paths and both required FTMO HCC paths are absent.
- No spread calibration was run and no pipeline, economic, or deployment
  verdict exists.

A read-only process snapshot observed the Program Files FTMO challenge terminal
and T_Live running, zero FTMO_STREAM lane processes, and active factory work.
None was changed or interrupted.

## Reviewer execution order

After reviewing commit `ae5331f6713d9f53e06982639fae86894cf67aac`, execute
the two shared-account lanes serially, then the reserved DXZ extraction:

```powershell
python tools/strategy_farm/ftmo_m1_bootstrap.py ftmo --lane FTMO_STREAM1 --execute
python tools/strategy_farm/ftmo_m1_bootstrap.py ftmo --lane FTMO_STREAM2 --execute
python tools/strategy_farm/ftmo_m1_bootstrap.py dxz --execute
```

Only after all four projections and HCC bindings exist should the reviewed
calibration be attempted:

```powershell
python tools/strategy_farm/portfolio/ftmo_spread_calibration.py `
  --spec docs/ops/evidence/2026-08-02_ftmo_spread_calibration_spec.json `
  --output D:/QM/reports/ftmo_spread_calibration/ftmo_spread_calibration_2026-08-08.json
```

`--replace-projections` is intentionally omitted because the reviewed projection
paths are currently absent. Any later replacement requires an explicit reviewer
decision and flag.
