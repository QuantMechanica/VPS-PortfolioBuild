# QM5_20167 XNG spring dual-trend build and Q02 enqueue

Date: 2026-07-26  
Branch: `agents/board-advisor`

## Outcome

Created one new structural XNG sleeve: April-May short exposure gated by a
falling completed-bar 21/84-D1 trend stack. It is distinct from `QM5_12567`
cumulative-RSI pullback logic, the calendar-only spring sleeve `QM5_12703`,
the autumn channel breakout `QM5_20166`, and winter/summer long dual-trend
variants. Realized diversification remains a downstream Q09 question.

## Source and identity

- Official lineage: U.S. EIA, “Natural gas use features two seasonal peaks per
  year,” defining winter/summer demand peaks and the intervening shoulder.
- Peer-reviewed lineage: Moskowitz, Ooi and Pedersen (2012), *Journal of
  Financial Economics*, for own-price trend persistence.
- EA/slug/magic: `QM5_20167` / `xng-spring-dualtrend` / `201670000`.
- Carrier: exact `XNGUSD.DWX`, D1.

## Frozen baseline

- Active months: April-May.
- Short state: close below SMA(21), SMA(21) below SMA(84), and both averages
  below their values five completed bars earlier.
- Frozen hard stop: `3.5 * ATR(20)`; no take profit.
- Exit outside season, on trend invalidation, wrong-side detection, after 35
  days, or by framework Friday close.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No ML, external runtime data, grid, martingale, live setfile, or sweep.

## Validation and handoff

- Card schema lint: PASS.
- SPEC validation: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260726_023507/QM5_20167_xng-spring-dualtrend.compile.log`.
- Strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260726_023521.json`.
- Build task: `c9424594-e4e7-4a8d-b18e-101a0726eac3`, status `done`.
- Review task: `20ee45d0-9981-4c0d-8d58-4b61704d8421`,
  `APPROVE_FOR_BACKTEST`.
- Exactly one Q02 work item:
  `3be82258-5dda-4e5b-b82c-9ea3ef546e62`, pending,
  `XNGUSD.DWX` D1.

No tester was manually started. The paced factory owns dispatch. No portfolio
gate, `T_Live` path, live manifest, or AutoTrading state was touched.
