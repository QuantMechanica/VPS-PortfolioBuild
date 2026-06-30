# QM5_12822_eia-jetfuel-pb - Strategy Spec

**EA ID:** QM5_12822
**Slug:** `eia-jetfuel-pb`
**Source:** `EIA-JETFUEL-SEASON-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It buys D1 controlled pullback-continuation candles only during the May 15
through August 31 jet-fuel summer air-travel demand window. Entry requires the
prior completed D1 close to be above a rising SMA(100), the prior D1 bar to
show an ATR-sized pullback from recent highs, and the candle to close in the
upper part of its range without being too extended above the trend SMA.

Positions exit when the window ends, the D1 close falls below the SMA trend
gate, the close breaks the short Donchian exit low, the 21-day max hold expires,
or the framework Friday close fires.

The strategy is intentionally not a duplicate of:

- `QM5_12809_eia-jetfuel-brk`: no Donchian upside breakout entry.
- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or commodity
  oscillator pullback logic.
- `QM5_12576_eia-wti-season`: not a broad monthly WTI season map.
- `QM5_12581_eia-rbob-crack`, `QM5_12585_eia-rbob-pullback`, and
  `QM5_12589_eia-rbob-shoulder`: not gasoline/RBOB crack-spread logic.
- `QM5_12583_eia-distillate-winter`: not winter distillate logic.
- WPSR, hurricane, refinery-maintenance, OPEC, expiry-roll, weekday,
  month-premium, oil-ratio, XNG, XAU/XAG, broad commodity-RSI, and long-horizon
  momentum sleeves already in the registry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 5 | 5 | Start month for jet-fuel window |
| `strategy_start_day` | 15 | 1-15 | Start day for jet-fuel window |
| `strategy_end_month` | 8 | 8-9 | End month for jet-fuel window |
| `strategy_end_day` | 31 | 15-31 | End day for jet-fuel window |
| `strategy_trend_period` | 100 | 63-150 | D1 trend SMA lookback |
| `strategy_fast_sma_period` | 20 | 10-30 | Pullback reference SMA |
| `strategy_sma_slope_shift` | 10 | 5-20 | Rising trend comparison lag |
| `strategy_pullback_lookback` | 3 | 3-8 | Recent high lookback for depth |
| `strategy_max_pullback_close_atr` | 1.25 | 0.75-1.75 | Max close extension above SMA |
| `strategy_min_pullback_depth_atr` | 0.45 | 0.25-0.75 | Min pullback depth from recent high |
| `strategy_max_pullback_depth_atr` | 2.75 | 2.0-3.5 | Max pullback depth from recent high |
| `strategy_min_close_location` | 0.55 | 0.50-0.65 | Min close location in signal-bar range |
| `strategy_exit_channel` | 8 | 5-13 | Closed-bar breakdown exit channel |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 21 | 13-34 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several days to a few weeks.
- Regime preference: WTI continuation during the EIA-documented jet-fuel
  refinery-yield and air-travel demand window after shallow trend pullbacks.
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

No live manifest, portfolio gate, or `T_Live` file is touched by this build.
