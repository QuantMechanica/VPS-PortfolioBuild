# QM5_12725_eia-xng-prestor - Strategy Spec

**EA ID:** QM5_12725
**Slug:** `eia-xng-prestor`
**Source:** `EIA-XNG-PRESTORAGE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades only on expected EIA weekly natural-gas storage-report
D1 bars. Entry requires compressed recent D1 ranges plus SMA and short momentum
confirmation; positions exit on time or SMA failure. Runtime uses Darwinex MT5
OHLC and broker calendar only.

This is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback.
- `QM5_12575_eia-xng-season`: monthly two-sided calendar/SMA season map.
- `QM5_12584_eia-xng-storage`: post-storage reaction aftershock.
- `QM5_12586`/`12587`/`12588`: seasonal channel breakout variants.
- `QM5_12595`/`12602`: failed-rally or winter spike fades.
- `QM5_12620_comm-reversal-4wk-xngusd`: fixed return-extreme reversal.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression and hard stop |
| `strategy_trend_period` | 63 | 40-84 | Slow D1 SMA trend confirmation |
| `strategy_momentum_period` | 5 | 3-8 | Prior-close directional confirmation |
| `strategy_compression_lookback` | 5 | 3-8 | Prior D1 bars used for average range |
| `strategy_compression_atr_mult` | 0.85 | 0.70-1.00 | Max average-range/ATR ratio |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 2 | 1-3 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10-22.
- Typical hold: one to two calendar days, segmented by Friday close.
- Regime preference: compressed pre-storage event risk in natural gas.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Natural Gas Storage Report",
URL https://www.eia.gov/naturalgas/storage/. Supplemental EIA release schedule:
https://www.eia.gov/naturalgas/schedule/. Sources are used only for structural
lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
