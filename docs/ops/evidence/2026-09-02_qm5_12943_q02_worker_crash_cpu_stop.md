# QM5_12943 EURUSD H1 Q02 recovery — CPU stop (2026-09-02)

Recorded: `2026-09-02T08:16:04.1413325Z`

Branch: `agents/board-advisor`

Outcome: `STOPPED_CPU_CEILING_NO_ENQUEUE`

## Scoped recovery unit

The paced-fleet claim for `QM5_12943_robopip-hlhb-trend-catcher-h1` was
resumed to finish the already-repaired Q02 infrastructure recovery. This is a
structural EURUSD H1 trend sleeve with no ML dependency. Its approved card,
MQ5, EX5, and backtest set retained their pinned hashes, and the set retained
`RISK_FIXED=1000` with `RISK_PERCENT=0`.

The failed predecessor is
`2b04b129-89e8-4489-8653-5dac22f8439a`. Immediately before admission it was
still the only QM5_12943 Q02 row; there was no open same-stream row and no
entry in `work_item_supersedes`. The authenticated repair commits
`c1fe07e30fe27` and `b63bf8b6e828` are both ancestors of the observed HEAD.
The focused recovery regression passed: `2 passed, 45 deselected`.

## Mandatory CPU stop

The decisive five one-second CPU samples were:

`95.117284, 95.231196, 97.659653, 99.718635, 96.685818` percent.

Their average was `96.882517%` and their maximum was `99.718635%`. The maximum
breached the `97%` stop threshold, so the conditional shell guard exited before
invoking `farmctl.py enqueue-backtest`.

Post-stop DB verification found only the historical failed row and zero
supersession links. No Q02 successor was enqueued or dispatched. No MT5
process was started or stopped, and AutoTrading, T_Live, the portfolio gate,
and the T_Live manifest were untouched.

The machine-readable receipt is
`artifacts/qm5_12943_q02_worker_crash_cpu_stop_20260902T081604Z.json`.

When a later paced run observes all five fresh CPU samples below `97%`, it may
repeat the exact hash-bound append-only enqueue documented in the 2026-09-01
recovery evidence after rechecking the duplicate guards.
