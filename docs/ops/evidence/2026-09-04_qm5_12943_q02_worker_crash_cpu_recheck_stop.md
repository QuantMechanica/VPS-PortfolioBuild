# QM5_12943 EURUSD H1 Q02 recovery recheck — CPU stop

Recorded: 2026-09-04 21:36:13 UTC
Branch: `agents/board-advisor`
Observed HEAD: `cadb7f3322bb6edd29170b748f656dae05316a2b`
Outcome: `STOPPED_CPU_CEILING_NO_CLAIM_OR_ENQUEUE`

## Selected recovery unit

The highest-value unclaimed unit remains the existing Q02 infrastructure
recovery for `QM5_12943_robopip-hlhb-trend-catcher-h1` on `EURUSD.DWX H1`.
It is an approved structural forex trend sleeve whose card basket also includes
GBPUSD, USDJPY, and XAUUSD, so a genuine EURUSD canary result can unlock useful
instrument fanout rather than add another index-only build.

The farm database still contains exactly one matching Q02 row:
`2b04b129-89e8-4489-8653-5dac22f8439a`, terminal `INFRA_FAIL` with taxonomy
`infra`. There is no pending, claimed, running, or append-only successor for
this EA/symbol/phase. The failure occurred before an MT5 economic result when
the old spawn-refusal writer violated the SH3 taxonomy constraint.

The repaired retry path is already committed in
`c1fe07e30fe27d92233ecae64773ca974abf3493` and
`b63bf8b6e828b8297396d7ae46c841c5f3565191`. Its focused regression check was
rerun at the observed HEAD:

```text
python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -k "worker_crash or spawn_refusal" -q
2 passed, 46 deselected in 1.08s
```

The current EX5 still matches the predecessor's expected and staged binary at
`95ba06400a66dfa39e31dd09855beb3f4c64f8ee4d2573d5f6476c63234155b2`.
The EURUSD set remains bound to `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Mandatory CPU stop

The fresh five-sample admission reading, at two-second intervals, was:

`97.3813, 99.0763, 99.3257, 93.7063, 94.7282` percent.

Average CPU was `96.8436%`; maximum CPU was `99.3257%`. Admission requires
both values to be strictly below the `97%` ceiling, so the maximum independently
triggered the user's stop condition. No confirmation sample was taken after
the stop trigger.

Accordingly, this pass did not claim a task, mutate the farm database, enqueue
a backtest, dispatch a terminal, compile an EA, or change strategy artifacts.
AutoTrading, T_Live, the portfolio gate, and the live manifest were untouched.

The machine-readable receipt is
`artifacts/qm5_12943_q02_worker_crash_cpu_recheck_20260904.json`.
