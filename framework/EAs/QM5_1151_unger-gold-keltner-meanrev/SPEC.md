# QM5_1151 unger-gold-keltner-meanrev

## Scope

Build-only V5 EA for APPROVED Strategy Card `QM5_1151_unger-gold-keltner-meanrev`.

## Card Mapping

- Universe: `XAUUSD.DWX`
- Timeframe: `M30`
- Entry: Keltner false-break re-entry around channel extremes.
- Long: prior completed bar trades below the lower channel, then the signal bar closes back above the lower channel inside the NY long window.
- Short: prior completed bar trades above the upper channel, then the signal bar closes back below the upper channel inside the NY short window.
- Keltner defaults: EMA 20, ATR 20, multiplier 2.0.
- Stop/Target: ATR(14) based first build, SL 2.0 ATR and TP 4.0 ATR.
- Exit: stop loss, take profit, optional Keltner midline exit, or max hold of 48 M30 bars.
- Risk: backtest fixed risk, live percent risk by setfile.
- News: FOMC/CPI/NFP skip-day intent mapped through V5 high-impact `SKIP_DAY` and DXZ compliance.

## V5 Alignment

- Uses the V5 framework lifecycle and strategy hooks.
- Uses `QM_EMA`, `QM_ATR`, `QM_EntryMarketPrice`, `QM_StopATRFromValue`, and `QM_TakeATRFromValue`.
- Uses `QM_FrameworkMagic()` and registry magic resolution.
- No external data/API calls.
- No ML, grid, martingale, or adaptive parameter logic.

## Build Boundary

No backtests or pipeline phases are part of this build.
