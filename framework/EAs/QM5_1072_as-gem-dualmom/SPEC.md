# QM5_1072 as-gem-dualmom SPEC

## Framework Alignment

- EA ID: `1072`
- Slug: `as-gem-dualmom`
- Strategy card: `docs/strategy_card.md`
- Primary timeframe: `D1`
- Rebalance cadence: monthly, first D1 bar after month-end close, after `strategy_rebalance_hour`
- Magic slots:
  - `0` = `SP500.DWX`
  - `1` = `GDAXI.DWX`
  - `2` = `NDX.DWX`
  - `3` = `WS30.DWX`

## Strategy Mapping

- No-Trade: block unsupported symbols, wrong magic slot, and pre-rollover hours; central framework handles kill-switch and news.
- Trade Entry: at monthly rebalance, compute 12-month return for configured US and international proxies. If US return is above cash hurdle, open long on the stronger proxy. If absolute momentum fails, stay flat.
- Trade Management: no trailing, break-even, pyramiding, or partial close. The source strategy is monthly rotation only.
- Trade Close: at the next monthly rebalance, close if the selected symbol changes or defensive-flat regime is selected.

## Card Port Choices

- `GDAXI.DWX` is used as the current repo/broker symbol for the card's GER40 proxy.
- Defensive bond/cash is implemented as flat because no DWX-safe defensive proxy is approved in the card.
- Friday close is disabled for this EA and setfiles because the card requires multi-week/monthly holding. The framework input remains present.
- The primary backtest pair is `SP500.DWX` vs `GDAXI.DWX`. `NDX.DWX` and `WS30.DWX` setfiles provide the card's live-validation path.

## Parameter Defaults

- `strategy_momentum_days = 252`
- `strategy_cash_return_pct = 0.0`
- `strategy_rebalance_hour = 1`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 4.0`
- `strategy_spread_median_days = 20`
- `strategy_spread_cap_mult = 3.0`

## Build Boundary

This is a build-only implementation. No smoke, backtest, or pipeline phase is part of this SPEC.
