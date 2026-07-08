# QM5_13074_eia-jetfuel-fade - Strategy Spec

**EA ID:** QM5_13074
**Slug:** `eia-jetfuel-fade`
**Source:** `EIA-JETFUEL-SEASON-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`. It
shorts D1 failed-rally candles during the August 15 through October 31 late
jet-fuel/post-spike window. Entry requires the prior completed D1 high to tag a
Donchian rejection high, the candle to close weakly below its open and below
SMA(100), and the SMA to be flat/down versus its recent value.

Positions exit when the window ends, the D1 close rises back above the SMA
trend gate, the close breaks the short Donchian take-profit low, the 18-day max
hold expires, or the framework Friday close fires.

This is intentionally not a duplicate of `QM5_12809_eia-jetfuel-brk` or
`QM5_12822_eia-jetfuel-pb`, which are long-only summer continuation builds.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 8 | 8 | Start month for fade window |
| `strategy_start_day` | 15 | 1-15 | Start day for fade window |
| `strategy_end_month` | 10 | 9-10 | End month for fade window |
| `strategy_end_day` | 31 | 15-31 | End day for fade window |
| `strategy_rejection_channel` | 20 | 15-30 | Prior closed-bar high channel for failed-rally tag |
| `strategy_exit_channel` | 10 | 5-15 | Prior closed-bar low channel for downside take-profit exit |
| `strategy_trend_period` | 100 | 63-150 | D1 trend SMA lookback |
| `strategy_sma_slope_shift` | 10 | 5-20 | Flat/down SMA comparison lag |
| `strategy_max_close_location` | 0.40 | 0.30-0.50 | Maximum close location in signal-bar range |
| `strategy_min_rejection_atr` | 0.35 | 0.20-0.55 | Minimum high-to-close rejection distance in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR stop/rejection period |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | Stop distance multiplier |
| `strategy_max_hold_days` | 18 | 10-30 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: several days to a few weeks.
- Regime preference: late jet-fuel/post-spike WTI exhaustion when crude is not
  in a rising long-term trend.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Jet fuel made up a record share of
U.S. refinery output in 2024", Today in Energy, March 24, 2025, URL
https://www.eia.gov/todayinenergy/detail.php?id=64786.

Supplemental EIA context:

- "U.S. jet fuel consumption growth slows after air travel recovers from
  pandemic slowdown", Today in Energy, August 26, 2025, URL
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- "U.S. jet fuel production rises after prices doubled in March", Today in
  Energy, June 8, 2026, URL
  https://www.eia.gov/todayinenergy/detail.php?id=67764.

The sources are used for structural lineage only. No EIA data feed, refinery
feed, airline feed, inventory feed, futures curve, or crack-spread feed is used
at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio gate, AutoTrading, or `T_Live` file is touched by
this build.
