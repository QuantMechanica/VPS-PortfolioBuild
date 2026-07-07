# QM5_13043_xti-resfuel-mom - Strategy Spec

**EA ID:** QM5_13043
**Slug:** `xti-resfuel-mom`
**Source:** `EIA-XTI-RESFUEL-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI residual-fuel pressure momentum setup on
`XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar,
requiring that bar to be Wednesday or Thursday in broker time, proxying the
normal EIA Weekly Petroleum Status Report release window for residual fuel oil
stock information. It trades only during the November-February winter
bunker/industrial/heating demand window.

Entries require a short pullback before the signal bar, a bullish ATR-sized
release-window reaction, upper-range close location, close above a rising
`SMA(55)`, and fixed single-symbol WTI scope. Positions use ATR hard stop, ATR
target, SMA trend-failure exit, seasonal invalidation, max-hold exit, standard
V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 11 | fixed | First month of residual-fuel winter pressure window |
| `strategy_season_end_month` | 2 | fixed | Last month of residual-fuel winter pressure window |
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR holiday drift |
| `strategy_pullback_lookback` | 5 | 3-7 | Completed D1 bars used for pre-signal pullback check |
| `strategy_min_pullback_atr` | 0.25 | 0.15-0.50 | Minimum pullback before signal in ATR units |
| `strategy_sma_period` | 55 | 40-80 | D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.85 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.16 | 0.10-0.30 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.64 | 0.55-0.78 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.80 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.60 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-11 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: winter WPSR residual-fuel pressure windows where WTI
  reacts upward after a short pullback.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration residual fuel oil and WPSR source family:

- https://www.eia.gov/petroleum/supply/weekly/
- https://www.eia.gov/dnav/pet/pet_stoc_wstk_a_eppr_sae_mbbl_w.htm
- https://www.eia.gov/tools/glossary/index.php?id=residual+fuel+oil
- https://www.eia.gov/todayinenergy/detail.php?id=51298

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13043_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13043_q02_enqueue_20260707.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Mission-directed residual-fuel energy sleeve build | Enqueue to Q02 |
