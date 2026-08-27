# QM5_41140 NZDJPY carry-unwind build — CPU ceiling stop

Date: 2026-08-27 UTC (`2026-08-27T06:37:16.6290675Z`)

Branch: `agents/board-advisor`

Status: the highest-ranked eligible low-frequency FX diversity card is claimed,
mechanized, registered, supplied with its fixed-risk backtest setfile, and
committed. Q01 compilation and Q02 enqueue stopped at the binding host-CPU
ceiling.

## Selection and claim

`QM5_41140_nzdjpy-carry-unwind-crisis-momentum` was rank 8 in the current
strategy-priority preview and the first candidate satisfying the mission's
structural, low-frequency, and instrument-diversity constraints. Candidates
ranked above it were intraday grid/indicator cards or additional index
exposure. The card has `g0_status: APPROVED`, R1 Tier A, R2-R4 PASS, D1, and an
explicit single-symbol `NZDJPY.DWX` baseline.

The durable farm claim is agent task
`29863320-8536-4252-b02c-6dae6db885d9`. The standard `codex_build_ea` handoff
created pending build task `5f69b208-6e8b-4900-a8c2-020c779eb030`. No other
active claim or work item existed for this EA.

## Structural FX implementation

On a completed target D1 bar, the EA requires an exact shared timestamp across
AUDJPY, NZDJPY, CADJPY, and EURJPY. It then requires:

- the equal-weight five-session simple return to be at most -1%;
- the NZDJPY close to be strictly below the preceding 20-bar low; and
- current 10-session realized volatility to exceed the median of 60 preceding
  rolling 10-session observations.

Only NZDJPY can receive an order. A qualifying state opens one short with a
frozen `2.0 * ATR(14,D1)` stop. The position exits after ten completed D1 bars
or a completed close above the midpoint of the preceding 20-bar channel.
Management and exits remain above the entry-only news gate. Friday close is
disabled because it is not a card exit. The eight declared parameters are the
only strategy inputs; there is no ML, banned indicator, adaptive parameter,
grid, martingale, pyramid, scale-in, stop widening, or auxiliary-symbol order.

The spec validator returned PASS. The card, source, spec, and basket manifest
record the deterministic interpretation that realized volatility is RMS daily
log return, the 60-observation baseline excludes the current window, and finite
zero `.DWX` swap is valid metadata rather than an entry veto.

## Governed identity

The governed allocator added exactly one active row:

- EA ID `41140`, slot `0`, symbol `NZDJPY.DWX`, magic `411400000`.

Resolver regeneration retained 17,928 active rows and reported zero
status-aware magic collisions. The allocation receipt is
`docs/ops/evidence/2026-08-27_qm5_41140_governed_magic_allocation.json`.

Key hashes at the stop:

- card: `95BAB94226A0081A485D971E65314833DEB3278FB9B68A81203238CB82D078C6`;
- MQ5: `9BDFD70380C9040D84CE3AC323A39EE94ACC5D7A9201816FE5EEE6231E387479`;
- spec: `E73DA5BF599EF0F82C88ED440BB920FEFBB0301E23A8FBA268C73EB381DFC4B4`;
- basket manifest: `E80347214E1D93BE5155B475090D0E65BB86416676E296EE619CD6AA3599A1A4`;
- magic registry: `26303559C983702D4322AA5784BB0D69C39555B6E6D1DE04D134860F714C378A`.

## Q01 infrastructure routing

Strict `build_check` did not reach strategy checks. The include-mirror guard
returned `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal64 processes
were alive and required governed `COMPILE_EA` routing. No retry or bypass was
attempted.

The required `farmctl enqueue-compile` call then refused this exact EA with
`BUILD_TASK_EXISTS`, because the standard build task is pending. Read-only
compile status is `NOT_ENQUEUED`. The governed generator produced the one
`RISK_FIXED=1000`, `RISK_PERCENT=0` NZDJPY D1 backtest setfile (SHA-256
`3643CD4B0002FC2F6707E5DBE92F986847C62407324296CB3B885AE7536225E5`),
but there is no EX5, Q01 PASS, smoke, or Q02 row. This is a circular
infrastructure-routing condition, not a compile verdict on the source.

## Binding CPU stop

Five fresh whole-host samples were 97.66%, 100%, 99.90%, 97.27%, and 80.86%.
Their average was 95.14% and their maximum was 100%. The paced-fleet rule stops
when either measure reaches 97%; the maximum triggered the immediate stop.

The supported slot scan showed six active, path-anchored factory terminals:
T2, T3, T4, T6, T8, and T9. The observed `T_Live` and unrelated FTMO processes
were excluded from that count and were not controlled.

A later pass must first recheck capacity, resume the pending standard build
task, and resolve the `BUILD_TASK_EXISTS` versus governed compile route without
bypassing the safety guard. It must then require strict build/compile PASS, run
at most one smoke with the existing fixed-risk setfile, and enqueue exactly one
Q02 row.

## Safety boundary

No terminal or tester was started, stopped, reserved, released, or reaped.
AutoTrading was not toggled. Neither `T_Live`, a deploy manifest, nor the
portfolio gate was touched.

Machine-readable receipt:
`artifacts/qm5_41140_fx_build_cpu_stop_20260827T063716Z_board_advisor.json`.
