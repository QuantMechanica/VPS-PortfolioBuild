# QM5_12607_wti-cad-confirm - Strategy Spec

**EA ID:** QM5_12607
**Slug:** `wti-cad-confirm`
**Source:** `BOC-CAD-OIL-2017`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
Entries are evaluated on the first available D1 bar of a new broker-calendar
week. A long package requires positive WTI quarterly momentum, negative USDCAD
quarterly momentum, and a WTI close above its D1 SMA. A short package requires
the opposite. USDCAD is a confirmation series only; the EA trades one XTIUSD
position per magic.

The strategy is intentionally not a duplicate of the current WTI book:
calendar weekday/month effects, broad EIA product seasonality, WPSR setups,
hurricane supply risk, refinery fades, OPEC policy windows, CME expiry windows,
oil/metal ratios, Donchian trend baskets, WTI-only 12-month momentum, and RSI
commodity pullbacks all use different timing, traded exposure, or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cad_symbol` | `USDCAD.DWX` | fixed | Closed-bar confirmation symbol |
| `strategy_oil_lookback_d1` | 63 | 42-84 | Completed XTI D1 bars for oil return |
| `strategy_cad_lookback_d1` | 63 | 42-84 | Completed USDCAD D1 bars for CAD confirmation return |
| `strategy_min_oil_return_pct` | 3.0 | 2.0-5.0 | Minimum absolute XTI return threshold |
| `strategy_min_cad_return_pct` | 1.0 | 0.5-1.5 | Minimum opposite-direction USDCAD return threshold |
| `strategy_trend_period` | 84 | 63-126 | XTI D1 SMA trend filter |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 21 | 14-31 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Host/traded symbol: `XTIUSD.DWX`, magic slot 0.
- Confirmation symbol: `USDCAD.DWX`, read-only D1 closed bars.

## 4. Timeframe

- Base timeframe: D1.
- Confirmation timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-16.
- Typical hold: weekly packages, capped at 21 calendar days by default.
- Regime preference: WTI directional moves confirmed by CAD strength/weakness.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Bank of Canada, "The Link Between the Canadian Dollar and Commodity Prices: Has
It Broken?", Staff Analytical Note 2017-1, URL
https://www.bankofcanada.ca/2017/02/staff-analytical-note-2017-1/.

U.S. Energy Information Administration, "Canada", Country Analysis Brief, URL
https://www.eia.gov/international/analysis/country/CAN.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

