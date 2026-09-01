# QM5_12943 EURUSD H1 Q02 infrastructure recovery — CPU stop

Recorded: 2026-09-01 12:44:27 UTC  
Branch: `agents/board-advisor`  
Outcome: `STOPPED_CPU_CEILING_NO_ENQUEUE`

## High-value target

`QM5_12943_robopip-hlhb-trend-catcher-h1` is an approved, structural H1
forex trend sleeve sourced from the public Babypips/ForexFactory HLHB rules.
Its fixed EMA/RSI/ATR mechanics require no ML, and the EURUSD backtest set is
bound to `RISK_FIXED=1000` and `RISK_PERCENT=0`. Forex adds the diversity the
current Q08 survivor set lacks.

The EA has exactly one farm row. Work item
`2b04b129-89e8-4489-8653-5dac22f8439a` is a terminal Q02 `INFRA_FAIL`; there
is no Q02 economic verdict, no append-only successor, and no pending or active
row for the same EA/symbol pair.

## Diagnosis and repaired path

The attempt did not produce an MT5 economic result. Its authenticated
traceback shows the worker crashed while recording a pre-spawn refusal:
`record_work_item_spawn_refusal` tried to persist `status=failed` before the
SH3 taxonomy column, violating the `work_items` CHECK constraint.

Two committed farm repairs now close that defect:

- `c1fe07e30fe27d92233ecae64773ca974abf3493` atomically records
  `verdict_taxonomy=infra` for spawn refusals.
- `b63bf8b6e828b8297396d7ae46c841c5f3565191` authenticates this exact crash
  signature and admits a same-binary append-only Q02 retry.

The focused recovery tests passed: `2 passed, 44 deselected` in 2.79 seconds.
The current EX5 hash is identical to the predecessor's verified staged binary:
`95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2`.
The prior history copy also completed as `PASS_PRIVATIZED` for all 108 selected
EURUSD files. No strategy or artifact change is warranted.

## CPU stop boundary

A fresh five-sample admission reading at two-second intervals was:

`99.658897, 100.0, 100.0, 99.80488, 100.0` percent.

Average CPU was `99.892755%` and maximum CPU was `100.0%`, both breaching the
hard `97%` stop ceiling. Therefore this unit did not enqueue, dispatch, or
touch MT5.

When a fresh reading is below the ceiling and the duplicate checks remain
zero, the exact governed action is:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12943 --phase Q02 --from-work-item-id 2b04b129-89e8-4489-8653-5dac22f8439a --append-only-rerun-of 2b04b129-89e8-4489-8653-5dac22f8439a --rerun-reason "retry exact EURUSD H1 identity after SH3 spawn-refusal taxonomy writer repair" --expected-current-ex5-sha256 95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2
```

The machine-readable receipt is
`artifacts/qm5_12943_q02_worker_crash_cpu_stop_20260901T124427Z.json`.

No backtest was enqueued, no manual dispatch occurred, and AutoTrading,
T_Live, the portfolio gate, and the T_Live manifest were untouched.
