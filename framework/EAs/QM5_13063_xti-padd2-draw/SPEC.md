# QM5_13063_xti-padd2-draw - Strategy Spec

**EA ID:** QM5_13063
**Slug:** `xti-padd2-draw`
**Source:** `EIA-XTI-PADD2-DRAW-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI Midwest PADD 2 crude-stock draw
pressure setup on `XTIUSD.DWX`. On each new D1 bar it inspects the previous
completed D1 bar, requiring that bar to be Thursday or Friday in broker time
and inside the April-October Midwest stockdraw pressure window. It consumes
at most one signal per broker-calendar month.

Entries require a short pre-signal pullback, a bullish ATR-sized WPSR proxy
reaction, upper-range close location, local high reclaim, close above a rising
`SMA(55)`, fast-over-slow `SMA(55) > SMA(120)` trend confirmation, and fixed
single-symbol WTI scope. Positions use ATR hard stop, ATR target, SMA
trend-failure exit, seasonal invalidation, max-hold exit, standard V5 news and
Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 4 | fixed | First Midwest stockdraw pressure month |
| `strategy_season_end_month` | 10 | fixed | Last Midwest stockdraw pressure month |
| `strategy_report_start_dow` | 4 | fixed | First broker day-of-week for post-WPSR proxy window |
| `strategy_report_end_dow` | 5 | fixed | Last broker day-of-week for post-WPSR proxy window |
| `strategy_pullback_lookback` | 5 | 4-8 | Completed D1 bars used for pre-signal pullback check |
| `strategy_reclaim_lookback` | 4 | 2-6 | Local high window reclaimed by signal close |
| `strategy_min_pullback_atr` | 0.28 | 0.15-0.55 | Minimum pullback before signal in ATR units |
| `strategy_sma_period` | 55 | 40-80 | Fast D1 trend filter period |
| `strategy_slow_sma_period` | 120 | 90-160 | Slow D1 trend filter period |
| `strategy_sma_slope_shift` | 6 | 4-12 | Completed D1 bars used for fast SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.85 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.16 | 0.10-0.32 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.62 | 0.55-0.78 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.65 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.20 | 1.8-3.4 | ATR target distance |
| `strategy_max_hold_days` | 6 | 4-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-6.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: April-October Midwest/PADD 2 stockdraw pressure windows,
  with Thursday/Friday lag after WPSR publication.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration Midwest PADD 2 crude stocks and WPSR:

- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP21
- https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r20_w.htm
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
