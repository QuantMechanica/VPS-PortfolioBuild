# QM5_12585_eia-rbob-pullback - Strategy Spec

**EA ID:** QM5_12585
**Slug:** `eia-rbob-pullback`
**Source:** `EIA-RBOB-PULLBACK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It buys controlled D1 pullbacks only during the gasoline crack-spread support
window from March through August. Entry requires the prior close to remain
above a 100-bar D1 trend SMA, three consecutive lower closes, and a pullback
depth between 0.35 and 2.25 ATR. Positions exit on a bounce back above the
recent closed-bar high watermark, a trend break, date-window expiry, max-hold
timeout, or the framework Friday close.

The strategy is intentionally not a duplicate of:

- `QM5_12576_eia-wti-season`: monthly WTI SMA/ROC season map.
- `QM5_12579_eia-wti-aftershock`: weekly WPSR event-day aftershock continuation.
- `QM5_12581_eia-rbob-crack`: gasoline-window D1 channel breakout/breakdown.
- `QM5_12583_eia-distillate-winter`: winter distillate long breakout.
- `QM5_12567_cum-rsi2-commodity`: RSI-style commodity pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 100 | 63-150 | D1 trend SMA lookback |
| `strategy_pullback_days` | 3 | 2-5 | Consecutive lower closes required |
| `strategy_min_pullback_atr` | 0.35 | 0.25-0.75 | Minimum pullback depth in ATR |
| `strategy_max_pullback_atr` | 2.25 | 1.5-3.0 | Maximum pullback depth in ATR |
| `strategy_bounce_exit_lookback` | 8 | 5-13 | Prior-close high watermark for bounce exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop/depth period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 14 | 7-21 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several days to two weeks.
- Regime preference: temporary WTI pullbacks inside EIA-documented gasoline crack-spread support months.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of
the summer driving season", This Week in Petroleum, March 12, 2025, URL
https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php.

The source is used for structural lineage only: gasoline crack-spread definition
and seasonal support into the summer driving season. No EIA data feed is used
at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
