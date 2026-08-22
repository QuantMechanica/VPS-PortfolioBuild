# FX cointegration frontier: Q06 hard-CPU stop

**Date:** 2026-08-22 UTC (`2026-08-22T20:32:30Z`)

**Branch:** `agents/board-advisor`

**Status:** rank-27 FX basket remains Q06-eligible; queue mutation prohibited by
the explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware reconciliation
in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships from the frozen scan: 66 covered and zero
uncovered. Creating another scan-derived identity would duplicate governed
work.

The preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

## Existing-pair fallback

The rank-27 `NZDUSD.DWX` / `EURAUD.DWX` logical basket
`QM5_20208_nzdusd-euraud` remains the strongest non-duplicate successor. A
fresh canonical query returned exactly three terminal rows:

- Q02 `1935fc01-6eaa-4db1-8397-660d22ebdfbb`: PASS.
- Q04 `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2`: PASS_LOWFREQ.
- Q05 `1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d`: PASS.

No Q06 work item was present. The compiled EX5 exists, both registry magic rows
are active, and `D:` has 125.67 GiB free. The prior Q06 preflight record seals
the generated stress setfile to the required backtest risk contract:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The exact append-only successor remains:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20208 --phase Q06 --from-work-item-id 1a53b4bd-abbd-4c6e-a13a-5f1a1542bf8d
```

That command was recorded only and was not executed.

## Binding CPU stop

The five-sample whole-host preflight returned 100%, 100%, 100%, 100%, and
100%. Both the average and maximum were 100%, above the 97% hard ceiling. The
path-aware slot scan observed eight factory terminals: `T1`, `T2`, `T3`, `T4`,
`T6`, `T7`, `T8`, and `T9`. All ten enabled terminal-worker daemons were
present.

`T_Live` and the unrelated FTMO terminal were observed only to exclude them;
neither was controlled. Per the explicit stop condition, no Q06 enqueue,
dispatch, tester launch, reservation, repair, requeue, or terminal action
followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_q06_cpu_stop_20260822T203230Z_board_advisor.json`.

## Safety

- Concurrent unrelated worktree changes were left unstaged and untouched.
- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
