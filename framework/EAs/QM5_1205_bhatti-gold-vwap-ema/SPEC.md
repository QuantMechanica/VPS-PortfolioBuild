# QM5_1205 bhatti-gold-vwap-ema

## Scope

Build-only V5 EA for APPROVED Strategy Card `QM5_1205_bhatti-gold-vwap-ema`.

## Card Mapping

- Universe: `XAUUSD.DWX`.
- Timeframe: `M15`.
- Regime: long only when close is above EMA(200) and session VWAP; short only when close is below EMA(200) and session VWAP.
- Pullback: signal bar must touch or close within `strategy_pullback_atr_mult * ATR(14)` of EMA(50), then close back on the continuation side of EMA(50).
- Entry: market order on the next M15 bar after the rejection bar closes.
- Initial stop: `strategy_sl_atr_mult * ATR(14)` beyond the rejection candle extreme.
- Exit: close-based EMA(50) trailing exit; long exits when M15 close is below EMA(50), short exits when M15 close is above EMA(50).
- VWAP: session VWAP from configured broker session start using M15 typical price and MT5 tick volume.
- Stabilization filter: skip entries during the first `strategy_vwap_skip_minutes` after session start.
- News: FOMC, CPI and NFP exclusion intent is mapped to V5 high-impact `SKIP_DAY` plus DXZ compliance.

## V5 Alignment

- Uses the V5 framework lifecycle and strategy hooks.
- Uses `QM_EMA`, `QM_ATR`, `QM_EntryMarketPrice`, `QM_FrameworkMagic`, and framework trade management.
- Uses native MT5 `XAUUSD.DWX` bars and tick volume only; no external market-data/API calls.
- No ML, grid, martingale, or adaptive parameters.

## Build Boundary

No backtests or pipeline phases are part of this build.
