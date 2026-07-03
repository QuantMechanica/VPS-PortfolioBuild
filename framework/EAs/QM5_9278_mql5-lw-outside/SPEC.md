# QM5_9278 mql5-lw-outside

**EA ID:** QM5_9278
**Slug:** mql5-lw-outside
**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb

## 1. Strategy Logic

Larry Williams bearish outside-bar reversal implemented mechanically from the approved card.

- Timeframe: D1 only.
- Setup: completed bar 1 is an outside bar (`High[1] > High[2]` and `Low[1] < Low[2]`) and closes below the prior low (`Close[1] < Low[2]`).
- Trigger: on the next D1 bar, buy only after price crosses `Open[0] + strategy_entry_factor * (High[1] - Low[1])`.
- Order handling: use market buy if the current ask has already crossed the trigger, otherwise place one `QM_BUY_STOP` valid for one D1 bar.
- Stop: `strategy_stop_factor * working_range` below entry.
- Take profit: `strategy_take_profit_r` times initial risk.
- Time stop: close after `strategy_max_hold_bars` completed D1 bars.
- Position policy: one open position or pending setup per magic number.

## 2. Parameters

- `strategy_timeframe = PERIOD_D1`
- `strategy_entry_factor = 0.50`
- `strategy_stop_factor = 0.50`
- `strategy_take_profit_r = 3.0`
- `strategy_max_hold_bars = 5`
- `strategy_pending_expiration_bars = 1`
- `strategy_max_spread_points = 0`
- `strategy_trade_monday` through `strategy_trade_friday = true`

## 3. Symbol Universe

- `EURUSD.DWX` slot 0 magic `92780000`
- `GBPUSD.DWX` slot 1 magic `92780001`
- `XAUUSD.DWX` slot 2 magic `92780002`
- `GDAXI.DWX` slot 3 magic `92780003`

The approved card names `GER40.DWX`; that symbol is absent from `framework/registry/dwx_symbol_matrix.csv`. `GDAXI.DWX` is present in the matrix as the available DAX custom symbol and is used as the documented DWX port.

## 4. Timeframe

Primary timeframe is D1. The EA reads only fixed D1 OHLC shifts for the current chart symbol and uses `QM_IsNewBar(_Symbol, strategy_timeframe)` for entry cadence.

## 5. Expected Behaviour

The card expects bearish outside bars to occur occasionally on D1, roughly 12 to 35 trades per year per symbol after trigger filtering. Backtest setfiles are generated for all registered symbols with fixed $1,000 risk.

Management and exits run before the news entry gate so pending cleanup and the five-D1-bar time stop are not suspended during news blackout windows. The spread guard is fail-open for `.DWX` zero-spread tester quotes and only blocks when `strategy_max_spread_points > 0` and spread exceeds that cap.

## 6. Source Citation

- Strategy card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9278_mql5-lw-outside.md`
- Citation: Chacha Ian Maroa, "Larry Williams Market Secrets (Part 9): Patterns to Profit", MQL5 Articles, 2026-02-02.
- URL: https://www.mql5.com/en/articles/21063

## 7. Risk Model

- Backtest default: `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`.
- Live-visible risk input: `RISK_PERCENT`.
- Framework risk sizer derives lots from entry-to-stop distance.
- News axes use V5 defaults: `QM_NEWS_TEMPORAL_PRE30_POST30` and `QM_NEWS_COMPLIANCE_DXZ`.

## Open Questions

- `GER40.DWX` in the card was ported to `GDAXI.DWX` because `GER40.DWX` is not in the DWX matrix.
- The card mentions a P3 alternative "first profitable D1 open"; this build implements the primary card default of static `3.0R` TP plus five-D1-bar hard fail-safe.
