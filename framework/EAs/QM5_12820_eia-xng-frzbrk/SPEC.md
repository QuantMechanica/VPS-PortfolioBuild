# QM5_12820_eia-xng-frzbrk - Strategy Spec

**EA ID:** QM5_12820
**Slug:** `eia-xng-frzbrk`
**Source:** `EIA-XNG-FREEZE-2026_S02`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It trades D1 long-only continuation breakouts during
January-February freeze-off risk windows. A signal requires the prior closed D1
bar to close above the previous D1 channel and above a slow SMA, with an
ATR-scaled close-to-close impulse, an expanded D1 range, strong close location,
and limited upper wick. The package exits on winter-window end, SMA failure,
channel failure, max hold, Friday close, or ATR hard stop.

This is not a duplicate of `QM5_12602_eia-xng-frzfade`, which sells bearish
spike-rejection candles. It is also not the broad `QM5_12586` November-March
symmetric winter breakout; this build is January-February, long-only, and
requires explicit shock-continuation confirmation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 12 | 8-20 | Previous-bar D1 channel for upside breakout entry |
| `strategy_exit_channel` | 8 | 5-12 | Previous-bar D1 channel for long failure exit |
| `strategy_trend_period` | 63 | 42-84 | Slow D1 SMA confirmation period |
| `strategy_atr_period` | 20 | 14-30 | ATR stop and impulse period |
| `strategy_min_range_atr` | 0.90 | 0.75-1.10 | Minimum signal-bar range versus ATR |
| `strategy_min_impulse_atr` | 0.55 | 0.40-0.75 | Minimum close-to-close impulse versus ATR |
| `strategy_min_close_location` | 0.62 | 0.55-0.70 | Minimum bar close location from low to high |
| `strategy_max_upper_wick_ratio` | 0.35 | 0.25-0.45 | Maximum upper wick as fraction of bar range |
| `strategy_atr_sl_mult` | 3.25 | 2.5-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 10 | 6-14 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several days to two trading weeks, segmented by Friday close.
- Regime preference: winter natural-gas freeze-off upside shock continuation.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "U.S. natural gas prices spiked in
February 2021, then generally increased through October", Today in Energy,
2022-01-06. Supplemental EIA Today in Energy articles document February 2021
production disruptions and cold-weather spot-price spikes. Sources are used
only for structural lineage; runtime uses Darwinex MT5 OHLC only.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate file is
touched by this build.
