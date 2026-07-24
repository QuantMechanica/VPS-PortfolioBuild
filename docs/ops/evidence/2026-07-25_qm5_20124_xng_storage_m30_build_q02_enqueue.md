# QM5_20124 XNG Storage-Release M30 Build and Q02 Enqueue

Date: 2026-07-25
Branch: `agents/board-advisor`

## Outcome

Built and registered `QM5_20124_xng-stor-m30`, a structural,
low-frequency XNGUSD.DWX M30 sleeve, and enqueued exactly one paced Q02
baseline work item. The strategy trades continuation only after the completed
standard-Thursday EIA natural-gas storage release bar; it is mechanically
different from the book's daily cumulative-RSI XNG exposure.

No performance, decorrelation, or portfolio-admission claim is made. Q02 and
later gates must falsify the edge and measure overlap.

## Source and duplicate boundary

- Source ID: `EIA-XNG-STORAGE-AFTERSHOCK-2026`.
- Strategy ID: `EIA-XNG-STORAGE-INTRADAY-2026_S01`.
- The U.S. Energy Information Administration natural-gas data page identifies
  the regular Weekly Natural Gas Storage Report release as Thursday at
  10:30 a.m. eastern time.
- The official WNGSR schedule documents holiday-week exceptions. Version 1
  therefore trades only the standard Thursday clock and skips shifted weeks;
  it does not guess or use an external runtime calendar.
- EIA supports the event identity and release clock only. The continuation
  rule and all thresholds are QM hypotheses.
- Deterministic research dedup was `CLEAN` across 4,181 registry rows and 374
  cards. Manual storage-family review found no existing M30 post-release
  continuation duplicate. Nearby XNG implementations use daily aftershock,
  daily storage fade, daily inside-day breakout, pre-storage daily trend,
  H4 seasonal volatility breakout, or daily cumulative RSI mechanics.

Official source pages:

- https://www.eia.gov/naturalgas/data.php
- https://ir.eia.gov/ngs/schedule.html

## Frozen mechanics

- Route: `XNGUSD.DWX`, M30, magic slot 0 (`201240000`).
- One standard-Thursday decision after the 10:30-11:00 New York release bar
  closes, with a 15-minute entry grace window.
- The prior 09:30 and 10:00 M30 bars define the pre-release range.
- Release range must be at least `0.75 * ATR(20)` and body/range at least
  `0.50`; enter with the direction of a close beyond the prior range.
- Hard stop: `2.0 * ATR(20)`. No take profit. Flat at 15:55 New York, on a
  New York date change, or after eight hours.
- The weekly attempt is persisted before fallible history, signal, news,
  spread, and order gates, preventing restart retries.
- Runtime inputs are OHLC/calendar/ATR arithmetic only: no ML, banned
  indicators, grid, martingale, storage data, consensus, API, or external
  market feed.
- Backtest contract is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Q01 verification

| Check | Result |
|---|---|
| Card schema lint | PASS |
| G0 card lint | PASS |
| Targeted EA/registry guard | PASS |
| SPEC validation | PASS |
| Strict compile | PASS, 0 errors, 0 warnings |
| Strict build check | PASS, 0 failures, 0 warnings |

Compile log:
`C:/QM/repo/framework/build/compile/20260724_223658/QM5_20124_xng-stor-m30.compile.log`.

Strict compile/build-check report:
`D:/QM/reports/framework/21/build_check_20260724_223658.json`.

Final strict no-compile recheck after card handoff metadata:
`D:/QM/reports/framework/21/build_check_20260724_224539.json`.

| Artifact | SHA256 |
|---|---|
| MQ5 | `781F68439429A80A492534B1C0628B567630E971C2C14A3EA3F031A352327261` |
| EX5 | `9B2752807C1C7216D2AE7B968A3D9289A949B1A992CF3CE7CD48E38B5FE63BD8` |
| RISK_FIXED setfile | `277CA092B1684F417DFA67D6507FDC0E9DB3408EADED3579BA34D66B87977E47` |
| Magic resolver | `3A032FCE081C82061D500745EF41DCD153BF9D804CD53E73F4DA5572D021B523` |

The generated resolver embeds registry SHA256
`F1101903B28BFC60F702624608D3E3DF0076DDB3C28A5C8FFE257E71945BB053`.
The setfile's canonical `build_hash` receipt is
`2d4bb0c3acc298285102e9aa26445588078bc3a7bea4c5050d844f86c3b9ef68`.

## Q02 handoff

- Build task: `6158129f-43b0-45e2-be2d-11e6654a37ad` (`done`).
- Q02 work item: `6ecb71e5-84f6-41ac-b257-507f6aef38e0`.
- Queue state at handoff: `pending`, attempt count `0`, symbol
  `XNGUSD.DWX`.
- Exactly one Q02 row exists for `QM5_20124`.
- The recorded build uses `smoke_result=deferred_p2_smoke`; the paced Q02 run
  owns the first Model-4 trade-generation test.

## CPU and safety boundary

`D:/QM/strategy_farm/state/FACTORY_OFF.flag` remained asserted. The read-only
terminal scan saw one factory pipeline terminal (`T4`), below the
seven-terminal ceiling, plus the separate `T_Live` process. No dispatcher,
pump, sweep, manual backtest, or terminal mutation was run.

No live setfile, AutoTrading action, `T_Live` mutation, deploy/T_Live manifest
change, portfolio-gate change, portfolio admission, or correlation waiver
occurred.
