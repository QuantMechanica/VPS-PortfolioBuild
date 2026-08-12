# QM5_20168 XNG autumn dual-trend build and Q02 enqueue

Date: 2026-07-26  
Branch: `agents/board-advisor`

## Outcome

Created one new structural natural-gas sleeve: September-November exposure
conditioned on a directionally aligned and still-moving completed-bar
21/84-D1 trend stack. It is distinct from `QM5_12567` cumulative-RSI
pullback logic and `QM5_20166` autumn channel-breakout logic. Realized
diversification remains a downstream Q09 question.

## Source and identity

- Official lineage: U.S. EIA, “Natural gas use features two seasonal peaks
  per year,” defining winter/summer demand peaks and seasonal transitions.
- Peer-reviewed lineage: Moskowitz, Ooi and Pedersen (2012), *Journal of
  Financial Economics*, for own-price trend persistence.
- EA/slug/magic: `QM5_20168` / `xng-autumn-dualtrend` / `201680000`.
- Carrier: exact `XNGUSD.DWX`, D1.

## Frozen baseline

- Active months: September-November.
- Long state: close above SMA(21), SMA(21) above SMA(84), both averages rising
  over five completed bars; the short state is the exact mirror.
- Frozen hard stop: `3.5 * ATR(20)`; no take profit.
- Exit outside season, on directional-state invalidation, after 35 days, or by
  framework Friday close.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No ML, banned oscillator, external runtime data, grid, martingale, live
  setfile, or parameter sweep.

## Validation and handoff

- Card schema lint: PASS.
- Resolver regeneration: PASS; magic `201680000` present.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260726_034058/QM5_20168_xng-autumn-dualtrend.compile.log`.
- Strict build-check report:
  `D:/QM/reports/framework/21/build_check_20260726_034116.json` (PASS, zero
  failures and warnings).
- EX5 SHA256:
  `0cf338e089e4448d9fb21bdc41423ddf1953cf38dc63bb77f72525b621b21a8a`.
- Exactly one Q02 work item:
  `bf21065b-53cf-49ce-bbce-9a3f95e550af`, pending,
  `XNGUSD.DWX` D1.

No tester was manually started. The paced factory owns dispatch. No portfolio
gate, `T_Live` path, live manifest, or AutoTrading state was touched.
