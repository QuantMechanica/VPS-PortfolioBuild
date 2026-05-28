# QM5_1216 bell-gold-fix-overnight

## Scope

Build-only V5 EA for APPROVED Strategy Card `QM5_1216_bell-gold-fix-overnight`.

## Card Mapping

- Universe: `XAUUSD.DWX` only.
- Timeframe: `M5`.
- Entry: open long on the first new M5 bar whose London-local open crosses the configured PM fix proxy. Defaults to 15:00 London.
- Exit: close on the first new M5 bar after the next trading day's configured AM fix proxy. Defaults to 10:30 London; if MT5 was closed at the proxy, the first tradable bar after reopening triggers the exit.
- Calendar: London-local clock conversion uses UK DST rules; entries are blocked on weekends and UK bank holidays.
- Missing bars: entry requires recent M5 bars around the fix window and blocks large data gaps via `strategy_missing_bar_grace_min`.
- Stop: initial hard stop is `strategy_atr_sl_mult * H1 ATR(strategy_atr_period_h1)`, default `1.0 * ATR(20)`.
- Positioning: one open position per magic number, no stacking. Daily entry key prevents duplicate PM-fix entries.
- Sweep controls: PM proxy, AM proxy, and ATR stop multiple are parameterized for P3 grid sweeps.

## V5 Alignment

- Uses V5 framework lifecycle, risk, magic, news, Friday-close, kill-switch and equity-stream hooks.
- Uses `QM_BrokerToUTC`, `QM_ATR`, `QM_EntryMarketPrice`, `QM_FrameworkMagic`, and `QM_TM_ClosePosition`.
- Uses native MT5 `XAUUSD.DWX` bars only; no external market data or APIs.
- No ML, grid, martingale, or adaptive parameters.

## Build Boundary

No backtests or pipeline phases are part of this build.
