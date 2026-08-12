# QM5_20156 XNG Wednesday Trend — Build And Q02 Evidence

Date: 2026-07-25  
Branch: `agents/board-advisor`

`QM5_20156_xng-wed-trend` sells a genuine Wednesday `XNGUSD.DWX` D1 session
only when the completed 252-D1 log return is negative. Borowski (2016)
supplies the Wednesday natural-gas weakness lineage; Moskowitz, Ooi and
Pedersen (2012) supply the instrument-own trailing-return-sign state.

The weekday and slow trend state are jointly load-bearing. This differs from
the unconditional `QM5_20018_xng-wed-short` and the two-day oscillator logic
in `QM5_12567_cum-rsi2-commodity`.

Evidence:

- approved card: `strategy-seeds/cards/approved/QM5_20156_xng-wed-trend_card.md`
- source packet: `strategy-seeds/sources/BOROWSKI-MOP-XNG-WEDTREND-2026/source.md`
- allocation: EA 20156, slot 0, XNGUSD.DWX, magic 201560000
- card schema/ML lint: PASS, no missing sections or ML hits
- strict compile: PASS, 0 errors, 0 warnings
- compile log: `framework/build/compile/20260725_150238/QM5_20156_xng-wed-trend.compile.log`
- Q02 work item: `5564f272-2c9f-429b-854e-df6c7b24b191`, pending
- setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

No manual backtest was started. The paced fleet owns Q02. No portfolio gate,
live setfile, deploy/T_Live manifest, `T_Live` file, AutoTrading state, or
live terminal was touched.
