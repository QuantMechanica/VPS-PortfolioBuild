# QM5_13042_xti-distdraw-mom - Strategy Spec

**EA ID:** QM5_13042
**Slug:** `xti-distdraw-mom`
**Source:** `EIA-XTI-DISTDRAW-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI winter distillate-stock pressure
momentum setup on `XTIUSD.DWX`. On each new D1 bar it inspects the previous
completed D1 bar, requiring that bar to be Wednesday or Thursday in broker
time, proxying the normal EIA Weekly Petroleum Status Report release window.
It trades only during the October-March heating-season demand window.

Entries require a short pullback before the signal bar, a bullish ATR-sized
release-window reaction, upper-range close location, close above a rising
`SMA(60)`, and fixed single-symbol WTI scope. Positions use ATR hard stop, ATR
target, SMA trend-failure exit, seasonal invalidation, max-hold exit, standard
V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 10 | fixed | First month of winter distillate pressure window |
| `strategy_season_end_month` | 3 | fixed | Last month of winter distillate pressure window |
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR holiday drift |
| `strategy_pullback_lookback` | 4 | 2-6 | Completed D1 bars used for pre-signal pullback check |
| `strategy_min_pullback_atr` | 0.30 | 0.20-0.60 | Minimum pullback before signal in ATR units |
| `strategy_sma_period` | 60 | 40-90 | D1 trend filter period |
| `strategy_sma_slope_shift` | 5 | 3-10 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.60 | 0.45-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.18 | 0.12-0.35 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.66 | 0.55-0.80 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.50 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 6 | 3-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: winter WPSR distillate-stock pressure windows where WTI
  reacts upward after a short pullback.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration distillate-stock and heating-season
source family:

- https://www.eia.gov/petroleum/supply/weekly/
- https://www.eia.gov/dnav/pet/pet_stoc_wstk_a_epd0_sae_mbbl_w.htm
- https://www.eia.gov/energyexplained/heating-oil/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13042_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13042_q02_enqueue_20260707.json`.
- Q02 work item: `f1d9d859-f479-4922-b8f8-f66ccb7f6e2a`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial mission-directed energy sleeve build | Enqueued to Q02 |
