# T5 reactivation

Date: 2026-07-31  
Disposition: **REACTIVATED — controlled Model-4 PASS and 10/10 worker health**

## Result

T5 is no longer quarantined. A controlled positive-control backtest completed
on T5, the canonical worker is alive, and the farm health check sees the exact
10-terminal cohort `T1` through `T10`.

The 2026-07-27 conclusion that T5 had a terminal-local indicator-engine fault
was not a valid isolation result. The later MNT review showed the same
`BarsCalculated=-1` observation on other terminals and established that
`QM5_11144` was not a valid positive control. The reactivation therefore used
an unchanged EA binary with prior positive evidence and required a real report
with trades.

## Controlled verification

T5 was reserved through `farmctl` before the probe and released afterward.

The first attempt used `QM5_20102` on `EURUSD.DWX` and failed with
`NO_HISTORY`; the terminal journal recorded file error `[32]` while another
factory tester was using the shared custom-history store. That is the known
cross-terminal shared-history contention mode and is not evidence of a T5
fault. Evidence:

- `D:/QM/reports/ops/t5_reactivation_20260731/QM5_20102/20260731_133701/summary.json`

The positive control then used an inactive symbol:

```text
EA:       QM5_11912_cheng-triangle-2touch-second-break-h1
Terminal: T5
Symbol:   AUDUSD.DWX
Period:   H1
Window:   2022-07-01 through 2022-12-31
Model:    4
EX5 SHA:  296ed464891ec0a1505c00a2b90e3b98acf9b9af4167a7638f15b05ebece5071
Result:   PASS / OK
Trades:   16
PF:       1.38
```

The source and deployed EX5 hashes matched and remained stable during the run.
The report, tester log, INI, and exact logger sample were latched under:

- `D:/QM/reports/ops/t5_reactivation_20260731/QM5_11912/20260731_134047/summary.json`
- `D:/QM/reports/framework/22/20260731_134047_QM5_11912_T5_AUDUSD_DWX_run_smoke.md`

## Reactivation

The exact quarantine file contained only `T5`. Before removing it, it was
copied to:

- `D:/QM/strategy_farm/state/disabled_terminals.txt.bak_t5_reactivation_20260731T1343Z`

`D:/QM/strategy_farm/state/disabled_terminals.txt` is now absent, which is the
canonical representation of no disabled terminals. Restoration is possible by
copying the retained backup back to the canonical path.

The worker launcher also exposed an independent direct-entrypoint regression:
`terminal_worker.py` imported `framework` before adding the repository root to
`sys.path`. The entrypoint now bootstraps its own import path, with a regression
test that invokes it outside the repository and with `PYTHONPATH` removed.
The focused worker suite passes: `19 passed`.

At the final check:

- T5 worker PID: `14832`, session `1`, canonical pinned Python interpreter;
- reservations: empty;
- worker health: `10/10 design terminal_worker capacity alive; 10/10 enabled daemons alive`;
- T5 was observing `commit_headroom_low_pause` because another test held the
  global commit reservation. This is the expected resource guard and leaves
  the daemon available to claim work automatically when capacity clears.

## Governed full-restart boundary

This reactivation repairs the running worker fleet and the dynamic watchdog
policy. The separately source-bound `Factory_ON.ps1` runtime-activation
contract still encodes the superseded nine-worker/T5-quarantine decision. A
future full `Factory_OFF`/`Factory_ON` cycle will therefore fail closed until a
fresh committed OWNER runtime-activation decision and matching source update
authorize the ten-worker cohort. No full Factory cycle and no T_Live or
AutoTrading state was touched here.
