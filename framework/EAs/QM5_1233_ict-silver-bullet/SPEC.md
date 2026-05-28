# QM5_1233 ICT Silver Bullet

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1233_ict-silver-bullet.md`
- Local build copy: `docs/strategy_card.md`
- Status: APPROVED
- EA ID: 1233
- Slug: `ict-silver-bullet`

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-M5 charts, insufficient warmup, and mismatched magic slot; cancels own pending orders after the 11:00 New York window and invalidated pending limits.
- Entry: trades only during 10:00-10:59 New York time. Builds the previous completed H1 and 09:00-09:59 New York M5 liquidity range, then requires a liquidity sweep, close back inside liquidity, and a three-bar FVG before placing a midpoint limit order.
- Management: records the filled session so the EA does not re-enter after one filled trade per symbol per session.
- Close: closes open positions at or after 11:55 New York time.

## Parameters

- Execution timeframe: M5.
- Reference timeframe: previous completed H1 plus 09:00-09:59 New York M5 range.
- Risk contract: `RISK_FIXED=1000` for backtest sets, `RISK_PERCENT=0.25` for live sets.
- News: high-impact temporal and DXZ compliance filter defaults are enabled through V5 framework inputs.

## Symbols

Slots 0-11 map to `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`.

## Notes

- The Strategy Card's spread filter references a median of historical same-hour spreads. MT5 does not expose historical spread consistently for every DWX symbol in the EA layer, so the build uses a conservative `strategy_max_spread_points` input as the executable gate.
- Index symbols require the registry/deploy symbol mapping caveat from the card before any T6 promotion.
- This is a build-only handoff. No backtests or pipeline phases were run.
