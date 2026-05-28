# QM5_1255_zarattini-qqq-orb

## Card Mapping

- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1255_zarattini-qqq-orb.md`
- Status: `APPROVED`
- Symbol: `NDX.DWX`
- Timeframe: M5 primary, with M15/M30/H1 opening-range variants as build setfiles.
- Framework: QuantMechanica V5, single-symbol EA, `ea_id=1255`, `magic_slot=0`.

## Strategy Logic

- Records the opening range from the first `strategy_opening_range_min` minutes after the configured US regular-session proxy open.
- Enters long when the latest closed bar closes above the opening-range high.
- Enters short when the latest closed bar closes below the opening-range low.
- Uses one trade per session by default.
- Initial stop is the opposite opening-range boundary with ATR fallback: max(range distance, `strategy_atr_stop_mult * ATR(strategy_atr_period)`).
- Closes at the configured session end flatten window, or earlier on close through the opposite opening-range boundary.

## V5 Alignment

- No-trade: symbol/timeframe/magic-slot validation, minimum history, session state, news handled by framework.
- Entry: deterministic closed-bar opening-range breakout.
- Management: no trailing or partial close; the card does not authorize additional management.
- Close: end-of-session flatten and opposite-boundary close.
- Risk: V5 fixed-risk default for backtest (`RISK_FIXED=1000`, `RISK_PERCENT=0`).

## Build Scope

No backtests or pipeline phases were run for this build.
