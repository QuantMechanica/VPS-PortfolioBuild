# QM5_9936 timer-fidelity curve — execution attempt

Date: 2026-07-27
Router task: `c6e5ed49-ef62-4e67-88f1-e79648f168af`
Verdict: **NOT ESTABLISHED — no admissible curve was produced**

## Result

The requested interval-to-fidelity curve and economic deltas are not established.
Publishing values would be fabrication: the same-vintage control run did not produce
a report or durable trade stream, and the reserved terminal was reclaimed by the
factory immediately after that run stopped.

The measurement variant was built, but none of its six interval configurations was
run because there was no longer an exclusively held terminal. No active factory run
was interrupted and `-AllowRunningTerminal` was not used.

## Same-vintage build evidence

Both arms were compiled serially on 2026-07-27 with the same T1 MetaEditor and current
include tree:

| arm | compile evidence | result | EX5 SHA-256 |
|---|---|---|---|
| tick control | `framework/build/compile/20260727_183750/QM5_9936_ff-range-breakout-gmt3-h1.compile.log` | 0 errors, 0 warnings | `7ea6234d772aa161f00c66ebb06eb8df5f592251f143ca119fea64e4bed0929f` |
| timer measurement | `framework/build/compile/20260727_183812/QM5_9936_timer-fidelity-measurement.compile.log` | 0 errors, 0 warnings | `32ceed06daffac35312f27a20d9bc803a8d3c101a723530755b0d1189fd03201` |

The separate measurement source is
`framework/EAs/QM5_9936_timer-fidelity-measurement/QM5_9936_timer-fidelity-measurement.mq5`.
It preserves the strategy and framework inputs, adds only
`measurement_timer_interval_ms`, installs/kills the timer, removes
`Strategy_ManageOpenPosition()` plus `Strategy_ExitSignal()` handling from `OnTick`,
and invokes the same operations from `OnTimer` behind the same kill/news/Friday/no-trade
guards. The gated source was not edited. Six fixed-risk sets were prepared for 100,
500, 1,000, 5,000, 60,000 and 3,600,000 ms; every set retains `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## Execution evidence and blocker

1. T2 was reserved at `2026-07-27T18:35:33.747969Z` through
   `farmctl.py reserve-terminal`, until `20:35:33Z`.
2. The already-active T2 Q04 item was allowed to finish naturally.
3. The control was launched through `framework/scripts/run_smoke.ps1`, not by manually
   starting `terminal64.exe`. Its exact INI is
   `D:/QM/reports/timer_fidelity_9936/control/QM5_9936/20260727_184011/raw/run_01/tester.ini`.
4. The terminal log records start at `20:40:17`, only 19% progress at `20:45:22`,
   then `last test passed with result "some error after pass finished"` and shutdown
   at `20:48:03`. No report and no `9936_USDJPY_DWX.jsonl` were harvested.
5. At `20:48:10`, the persistent T2 worker immediately launched work item
   `ef0303b5-cebd-45d3-948b-5b53201a3798` again. This demonstrates that this running
   worker did not honor the reservation at its next claim, so T2 was not exclusive.

The hard constraints prohibit interrupting that work item or sharing its portable
terminal. Therefore the sweep stopped before the timer arm.

## Requested curve

| interval | match rate | mismatch decomposition | net P&L delta | wDD_p90 delta | FUND_SCORE delta |
|---:|---:|---|---:|---:|---:|
| 100 ms | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| 500 ms | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| 1 s | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| 5 s | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| 60 s | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| H1 bar | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |

## Plain answer

How large the timer deviation is, and whether it matters economically, remains
**NOT ESTABLISHED**. The build precondition is complete; the execution precondition
failed. The experiment must be rerun only after a terminal reservation is demonstrably
honored at claim time by the already-running worker, with the control harvested before
the six timer arms.
