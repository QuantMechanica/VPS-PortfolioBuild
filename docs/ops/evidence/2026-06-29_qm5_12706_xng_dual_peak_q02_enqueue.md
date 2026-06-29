# QM5_12706 XNG Dual Peak Q02 Enqueue Evidence

Date: 2026-06-29
Branch: `agents/board-advisor`

## Scope

Built one new structural commodity/energy sleeve:

- EA: `QM5_12706_xngusd-seasonal-dual-peak`
- Symbol/timeframe: `XNGUSD.DWX` D1
- Source: U.S. Energy Information Administration, "Natural gas use features two seasonal peaks per year", Today in Energy, 2015-09-11
- Logic: long-only natural-gas demand-peak seasonality in November-March and June-August, gated by D1 SMA confirmation with ATR hard stop, season exit, trend-failure exit, max-hold exit, and framework Friday close.

## Non-Duplicate Rationale

- Not `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback logic.
- Not `QM5_12575_eia-xng-season`: long-only in demand-peak months, no shoulder-season short map.
- Not `QM5_12702_xngusd-winter-withdrawal-long` or `QM5_12704_xngusd-summer-power-long`: tests combined winter and summer demand peaks as one allocation rule.
- Not XNG storage/event/fade/weekend-gap logic and not an energy basket.

## Build Evidence

- Build task: `1630d6d7-52cb-4a53-a8e1-1e00abdcebbe`
- Compile: PASS, 0 errors, 0 warnings
- Compile log: `C:\QM\repo\framework\build\compile\20260629_070742\QM5_12706_xngusd-seasonal-dual-peak.compile.log`
- Build check: PASS, 0 failures, 16 advisory warnings
- Build check report: `D:\QM\reports\framework\21\build_check_20260629_071235.json`
- Spec validation: PASS
- Symbol scope validation: `SINGLE_SYMBOL_OK`
- Build result: `C:\QM\repo\artifacts\qm5_12706_build_result.json`

Hashes captured in build result:

- MQ5 SHA256: `5d7d2ba8f532d0822ef7205fd7bf7ba39338b7af1e59d346d338fe80788973e6`
- EX5 SHA256: `1a02c95e03b3f882d8607e48bd582409094f187b8f13e7ef4c39e53f8346027c`
- Setfile SHA256: `a6b71ac60df54be8dafc66dba87424ced376a32870bf3f65dba01c10a1e83664`
- Approved card SHA256: `a4cdd09e6cf7343059682d672495f2fdbeb0adb7cc774deea3c3a4463123c718`

## Q02 Queue Evidence

- Record-build command auto-enqueued Q02.
- Q02 work item: `9b831363-5cb6-4f6d-a19d-9debb27f8588`
- Q02 status at enqueue: `pending`
- Symbol/timeframe: `XNGUSD.DWX` D1
- Setfile: `framework\EAs\QM5_12706_xngusd-seasonal-dual-peak\sets\QM5_12706_xngusd-seasonal-dual-peak_XNGUSD.DWX_D1_backtest.set`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Safety

No `T_Live` manifest, AutoTrading setting, live-terminal file, portfolio gate, portfolio-admission artifact, portfolio KPI, or Q08 contribution artifact was edited. No manual MT5 backtest was launched from this session.
