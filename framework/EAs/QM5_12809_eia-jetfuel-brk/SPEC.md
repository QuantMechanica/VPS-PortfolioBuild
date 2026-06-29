# QM5_12809_eia-jetfuel-brk - Strategy Spec

**EA ID:** QM5_12809
**Slug:** `eia-jetfuel-brk`
**Source:** `EIA-JETFUEL-SEASON-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It buys D1 upside breakouts only during the May 15 through August 31 jet-fuel
summer air-travel demand window. Entry requires the prior completed D1 close to
be above SMA(100) and to break the highest high of the prior 15 completed D1
bars, excluding the signal bar. Positions exit when the window ends, the D1
close falls below the SMA trend gate, the close breaks the short Donchian exit
low, the 45-day max hold expires, or the framework Friday close fires.

The strategy is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or commodity
  pullback logic.
- `QM5_12576_eia-wti-season`: not a broad monthly WTI season map.
- `QM5_12581_eia-rbob-crack`, `QM5_12585_eia-rbob-pullback`, and
  `QM5_12589_eia-rbob-shoulder`: not gasoline/RBOB crack-spread logic.
- `QM5_12583_eia-distillate-winter`: not winter distillate logic.
- WPSR, hurricane, refinery-maintenance, OPEC, expiry-roll, weekday,
  month-premium, oil-ratio, XNG, XAU/XAG, and long-horizon momentum sleeves
  already in the registry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 5 | 5 | Start month for jet-fuel window |
| `strategy_start_day` | 15 | 1-15 | Start day for jet-fuel window |
| `strategy_end_month` | 8 | 8-9 | End month for jet-fuel window |
| `strategy_end_day` | 31 | 15-31 | End day for jet-fuel window |
| `strategy_entry_channel` | 15 | 10-20 | Closed-bar breakout channel |
| `strategy_exit_channel` | 8 | 5-13 | Closed-bar breakdown exit channel |
| `strategy_trend_period` | 100 | 63-150 | D1 trend SMA lookback |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 45 | 21-70 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Typical hold: several days to several weeks.
- Regime preference: WTI continuation during the EIA-documented jet-fuel
  refinery-yield and air-travel demand window when crude is already trending.
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

No live manifest or `T_Live` file is touched by this build.
