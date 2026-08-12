# QM5_20025 WTI February-October Daily Rotation Q02 Enqueue

Date: 2026-07-21
Branch: agents/board-advisor

Built a new XTIUSD.DWX D1 calendar sleeve from Gorska and Krawiec (2015),
DOI 10.22630/PRS.2015.15.4.54: buy each February session, sell each October
session, and flatten at the next D1 boundary. This is a daily-reset signed
month rotation, not an existing whole-month hold, weekday carrier, metal
ratio, or QM5_12567 cumulative-RSI strategy.

Validation:

- Card schema: PASS, no ML hits or missing sections.
- SPEC validation: PASS.
- Strict compile: PASS, 0 errors and 0 warnings.
- Backtest set: RISK_FIXED=1000, RISK_PERCENT=0.
- Q02 work item: 86024e4f-9b15-4da7-87a1-8a46d8573a95.
- Q02 state after enqueue: pending on XTIUSD.DWX.

No manual backtest was launched. No T_Live file, AutoTrading setting, deploy
manifest, live manifest, or portfolio gate was touched.
