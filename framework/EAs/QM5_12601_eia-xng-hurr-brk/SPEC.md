# QM5_12601_eia-xng-hurr-brk - Strategy Spec

**EA ID:** QM5_12601
**Slug:** `eia-xng-hurr-brk`
**Source:** `EIA-NOAA-XNG-HURR-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency XNGUSD.DWX hurricane-season supply-risk
breakout sleeve. On each new D1 bar, it evaluates only the prior closed bar.
Entries are allowed only from August 15 through October 15, the peak Atlantic
hurricane activity window. A long trade opens only when XNGUSD.DWX confirms an
upside D1 channel breakout with SMA trend confirmation, minimum ATR-normalized
range, and close-location confirmation.

The strategy is intentionally not a duplicate of the existing XNG family:
storage aftershock, broad seasonality, spring calendar, winter withdrawal
breakout, injection-season breakdown, summer power squeeze, shoulder fade, and
commodity RSI pullback all use different timing or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 20 | 15-40 | Prior completed D1 bars for breakout entry |
| `strategy_exit_channel` | 10 | 7-20 | Prior completed D1 bars for failed-breakout exit |
| `strategy_trend_period` | 63 | 42-84 | SMA trend confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and range filter |
| `strategy_min_range_atr` | 0.75 | 0.60-1.00 | Prior-bar range floor as ATR multiple |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Close location threshold within prior-bar range |
| `strategy_atr_sl_mult` | 3.5 | 2.5-4.5 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 12 | 7-18 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: several D1 bars; capped at 12 calendar days by default.
- Regime preference: Atlantic hurricane peak window, August 15 through October 15.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Forecast strong hurricane season
presents risk for U.S. oil and natural gas industry", Today in Energy,
2024-06-13, URL
https://www.eia.gov/todayinenergy/detail.php?id=62104. Supplemental: NOAA
National Hurricane Center, Tropical Cyclone Climatology, URL
https://www.nhc.noaa.gov/climo/.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
