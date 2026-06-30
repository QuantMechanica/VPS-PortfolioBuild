# QM5_12827 cme-gassilver-brk

## Intent

D1 two-leg natural-gas/silver relative-value basket. The EA computes:

`spread = ln(XNGUSD.DWX close) - strategy_beta * ln(XAGUSD.DWX close)`

It opens a market-neutral package only when the latest completed spread closes
outside the prior D1 channel:

- Upside break: BUY `XNGUSD.DWX`, SELL `XAGUSD.DWX`.
- Downside break: SELL `XNGUSD.DWX`, BUY `XAGUSD.DWX`.

Runtime uses Darwinex MT5 D1 OHLC, broker spread, ATR, and trade-session state
only. There are no external feeds, ML, grid, martingale, or live/deploy hooks.

## Registered Symbols

- slot 0: `XNGUSD.DWX`, magic `128270000`.
- slot 1: `XAGUSD.DWX`, magic `128270001`.

## Risk And Pipeline

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Logical basket setfile: `QM5_12827_XNG_XAG_BRK_D1` on host `XNGUSD.DWX`, D1.
- Q02 must evaluate the logical basket via `basket_manifest.json`, not separate
  standalone leg rows.

## Card Mapping

- no_trade: D1 host guard, parameter sanity, spread caps, both-leg session checks.
- trade_entry: prior-channel breakout on the XNG/XAG log spread.
- trade_management: neutral-band exit, max-hold exit, broken-package repair,
  and V5 Friday close.
- trade_close: ATR hard stop on each leg plus deterministic basket exits.
