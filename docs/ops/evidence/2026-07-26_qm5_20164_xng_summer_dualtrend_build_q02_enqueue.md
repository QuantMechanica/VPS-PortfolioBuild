# QM5_20164 XNG summer dual-trend build and Q02 enqueue

Date: 2026-07-26  
Branch: `agents/board-advisor`

## Outcome

Created one new structural XNG sleeve: May-September long-only exposure gated
by a rising completed-bar 21/84-D1 trend stack. It is distinct from
`QM5_12567` cumulative-RSI pullback logic and from the winter-only
`QM5_20162` variant. Realized diversification remains a downstream Q09
question.

## Source and identity

- Official lineage: U.S. EIA, “Natural gas use features two seasonal peaks per
  year,” for summer electric-power demand.
- Peer-reviewed lineage: Moskowitz, Ooi and Pedersen (2012), *Journal of
  Financial Economics*, for own-price trend persistence.
- Dedup preflight: CLEAN across 4,221 EA-registry rows and 375 cards.
- EA/slug/magic: `QM5_20164` / `xng-summer-dualtrend` / `201640000`.
- Carrier: exact `XNGUSD.DWX`, D1.

## Frozen baseline

- Active months: May-September.
- Long state: close above SMA(21), SMA(21) above SMA(84), and both averages
  above their values five completed bars earlier.
- Frozen hard stop: `3.5 * ATR(20)`; no take profit.
- Exit outside season, on trend invalidation, after 35 days, or by framework
  Friday close.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No ML, external runtime data, grid, martingale, live setfile, or parameter
  sweep.

## Validation and handoff

- Card schema lint: PASS.
- SPEC validation: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260726_000338/QM5_20164_xng-summer-dualtrend.compile.log`.
- Strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260726_000405.json`.
- Build task: `b7e822e0-4e15-4012-a70c-6cbbf3315134`, status `done`.
- Exactly one Q02 work item:
  `f4f28101-9b4e-40db-8a46-4a30511a3433`, pending, unclaimed,
  `XNGUSD.DWX` D1.

At preflight, six factory terminals were active, below the documented
seven-terminal paced ceiling. No tester was manually started. The factory
owns dispatch. No portfolio gate, T_Live path, T_Live manifest, AutoTrading
state, or live artifact was touched.
