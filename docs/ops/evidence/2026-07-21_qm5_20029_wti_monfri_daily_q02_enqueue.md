# QM5_20029 WTI Monday-Friday Daily Rotation Q02 Enqueue

Date: 2026-07-21
Branch: agents/board-advisor

Built a new XTIUSD.DWX D1 structural calendar sleeve from Gorska and Krawiec
(2015), DOI 10.22630/PRS.2015.15.4.54. The source reports a WTI Monday mean of
-0.000943, Friday mean of 0.001731, and a significant Monday-Friday contrast
(z=-2.3617). The carrier sells Monday, buys Friday, and resets daily.

This is one signed two-state risk stream, not either existing one-sided weekday
EA, a month-of-year carrier, an event/inventory rule, a trend rule, or
QM5_12567 cumulative-RSI logic.

Validation:

- Full primary paper read, Tables 1-2 and conclusions captured in the card.
- Card schema: PASS; no ML or banned indicator logic.
- SPEC validation: PASS.
- Strict compile: PASS, 0 errors and 0 warnings.
- Build check: PASS, 0 failures and 0 warnings.
- Backtest set: RISK_FIXED=1000, RISK_PERCENT=0, fixed parameters only.
- Q02 work item: 37ecc49c-ff2e-4ca4-bf9e-7a492661610e.
- Q02 state after enqueue: pending on XTIUSD.DWX D1.

The magic resolver retained the new 20029 row. Its strict regeneration also
reported unrelated pre-existing missing EA directories for IDs 1001, 1015,
and 1016; they were not altered in this scoped build.

No manual backtest was launched. No T_Live file, AutoTrading setting, deploy
manifest, live manifest, or portfolio gate was touched.
