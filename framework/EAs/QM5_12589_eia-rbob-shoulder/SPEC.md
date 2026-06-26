# QM5_12589_eia-rbob-shoulder - Strategy Spec

**EA ID:** QM5_12589
**Slug:** `eia-rbob-shoulder`
**Source:** `EIA-RBOB-CRACK-SEASON-2025`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades short-only during the post-summer gasoline crack-spread shoulder:
September 1 through November 15. Entry requires a recent gasoline-season high
inside the setup window, a failed D1 trend state below a falling SMA, and a
break below a short trigger low. Positions exit on date-window expiry, trend
recovery, recovery-channel break, max-hold timeout, or the ATR stop.

The strategy is intentionally not a duplicate of:

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback.
- `QM5_12576_eia-wti-season`: monthly WTI SMA/ROC seasonality.
- `QM5_12579_eia-wti-aftershock`: weekly WPSR aftershock.
- `QM5_12581_eia-rbob-crack`: two-sided seasonal channel breakout/breakdown.
- `QM5_12585_eia-rbob-pullback`: gasoline-window long pullback continuation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_setup_lookback` | 42 | 30-63 | Bars searched for the failed gasoline-season high |
| `strategy_peak_recent_bars` | 15 | 10-21 | Max age of setup-window peak |
| `strategy_trend_period` | 63 | 42-100 | D1 SMA trend-failure period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars for falling-SMA confirmation |
| `strategy_trigger_lookback` | 5 | 3-8 | Previous-bar low trigger for short entry |
| `strategy_exit_lookback` | 8 | 5-13 | Previous-bar high recovery exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 25 | 15-35 | Calendar-day max hold |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: several days to a few weeks.
- Regime preference: post-summer crude shoulder after gasoline crack support fades.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of
the summer driving season", This Week in Petroleum, 2025-03-12, URL
https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php.

The source is used only for structural lineage; the EA uses Darwinex MT5 OHLC
at runtime and no external EIA, RBOB, refinery, inventory, or futures-spread feed.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
