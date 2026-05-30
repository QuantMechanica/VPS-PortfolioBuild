# QM5_1191_qp-pair-switch-spx-gold

## Scope
- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1191_qp-pair-switch-spx-gold.md`
- EA ID: `1191`
- Slug: `qp-pair-switch-spx-gold`
- Framework: QuantMechanica V5

## Card Mapping
- Entry: on the first tradable D1 bar of a rebalance month, compare prior 3 closed monthly total-return proxies for `SP500.DWX` and `XAUUSD.DWX`; open long only on the stronger leg.
- Exit: close the current leg at each rebalance event before the next allocation, or close stale positions after `70` calendar days.
- Stop: initial D1 ATR(20) stop at `3.0x`.
- Sizing: `RISK_FIXED=1000` for backtests, `RISK_PERCENT=0.25` for live setfiles.
- Spread: optional absolute cap plus rolling current-spread check against `3x` a 20-D1-sample median after warmup.

## Symbols And Magic
- Slot 0: `SP500.DWX`, magic `11910000`
- Slot 1: `XAUUSD.DWX`, magic `11910001`

## Notes
- `SP500.DWX` is a T6 live-promotion caveat from the card; live deploy requires parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX`.
- No backtests or pipeline phases are part of this build.
