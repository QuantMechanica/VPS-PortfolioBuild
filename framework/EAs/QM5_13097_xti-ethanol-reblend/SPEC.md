# QM5_13097_xti-ethanol-reblend - Strategy Spec

**EA ID:** QM5_13097
**Slug:** `xti-ethanol-reblend`
**Source:** `EIA-ETHANOL-REBLEND-XTI-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency WTI spring ethanol/gasoline reblend
pullback-reclaim setup on `XTIUSD.DWX`. It trades only during the late-April to
mid-June source window. Entries require a prior D1 pullback below the SMA, a
completed bullish D1 signal bar that reclaims the SMA, ATR-sized range/body,
upper-range close location, and a non-materially-falling SMA context.

The EA is intentionally not a duplicate of generic WPSR aftershock/fade,
May-August gasoline-stock momentum, broad driving-season channel breakout,
holiday gasoline fade, RBOB crack, XTI/XNG, XAU/XAG, XNG RSI, or
`QM5_12567_cum-rsi2-commodity` logic. It does not import EIA data at runtime.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_window_start_month` | 4 | fixed | Spring reblend start month |
| `strategy_window_start_day` | 20 | 15-25 | Spring reblend start day |
| `strategy_window_end_month` | 6 | fixed | Spring reblend end month |
| `strategy_window_end_day` | 15 | 10-30 | Spring reblend end day |
| `strategy_pullback_lookback` | 12 | 8-16 | Completed D1 bars checked for the prior pullback low |
| `strategy_min_pullback_atr` | 0.60 | 0.40-0.90 | Minimum pullback depth below SMA in ATR units |
| `strategy_sma_period` | 40 | 30-60 | D1 SMA reclaim and exit period |
| `strategy_sma_slope_lag_days` | 5 | 3-10 | Completed D1 bars used for SMA slope tolerance |
| `strategy_max_sma_fall_atr` | 0.10 | 0.05-0.20 | Maximum allowed SMA decline versus lagged value in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.80 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.22 | 0.15-0.35 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.62 | 0.58-0.70 | Minimum close location within signal-bar range |
| `strategy_exit_sma_buffer_atr` | 0.10 | 0.00-0.25 | Exit buffer below SMA in ATR units |
| `strategy_atr_sl_mult` | 2.4 | 1.8-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.0 | 2.2-4.0 | ATR profit target distance |
| `strategy_max_hold_days` | 12 | 7-18 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 2-7.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  spring-window invalidation, stale-position exit, and framework Friday close.
- Regime preference: crude-oil upside recovery after spring ethanol/gasoline
  reblend pullback.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration ethanol/gasoline source packet:

- https://www.eia.gov/todayinenergy/detail.php?id=13271
- https://www.eia.gov/todayinenergy/detail.php?id=32152
- https://www.eia.gov/todayinenergy/detail.php?id=67464
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
