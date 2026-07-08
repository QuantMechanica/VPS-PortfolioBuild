# QM5_13066_xti-padd4-fade - Strategy Spec

**EA ID:** QM5_13066
**Slug:** `xti-padd4-fade`
**Source:** `EIA-XTI-PADD4-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI Rocky Mountain PADD 4 failed-upside fade
on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar,
requiring that bar to fall inside a deterministic PADD 4 pressure season
window and Thursday/Friday post-WPSR proxy window.

Entries are short-only. A setup requires an upside probe above the prior D1
context high, a close back below that high in the lower part of the bar, a
bearish body, and a falling SMA trend filter. Positions use ATR hard stop, ATR
target, max-hold exit, fast-SMA invalidation, seasonal invalidation, standard
V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month_a` | 1 | 1-12 | First month in first PADD 4 pressure window |
| `strategy_season_end_month_a` | 4 | 1-12 | Last month in first PADD 4 pressure window |
| `strategy_season_start_month_b` | 9 | 1-12 | First month in second PADD 4 pressure window |
| `strategy_season_end_month_b` | 12 | 1-12 | Last month in second PADD 4 pressure window |
| `strategy_report_start_dow` | 4 | 3-5 | First broker day-of-week allowed for post-WPSR signal |
| `strategy_report_end_dow` | 5 | 4-5 | Last broker day-of-week allowed for post-WPSR signal |
| `strategy_context_lookback` | 14 | 10-20 | Completed D1 bars used for context high/low |
| `strategy_sma_period` | 55 | 34-80 | Fast trend SMA period |
| `strategy_slow_sma_period` | 120 | 90-160 | Slow trend SMA period |
| `strategy_sma_slope_shift` | 6 | 3-10 | Fast-SMA falling-trend comparison shift |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.50 | 0.40-0.80 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.12 | 0.05-0.25 | Minimum signal-bar body in ATR units |
| `strategy_min_probe_atr` | 0.06 | 0.00-0.15 | Minimum outside-context probe in ATR units |
| `strategy_max_close_location` | 0.45 | 0.35-0.55 | Maximum close location for failed-upside short |
| `strategy_atr_sl_mult` | 2.40 | 1.75-3.25 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.60 | 1.75-3.50 | ATR target distance |
| `strategy_max_hold_days` | 6 | 3-9 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-6.
- Direction: short only.
- Typical hold: several D1 bars, capped by ATR target/stop, max-hold exit,
  fast-SMA invalidation, and seasonal invalidation.
- Regime preference: January-April and September-December Rocky Mountain PADD 4
  crude-stock pressure windows where WTI probes above the recent D1 range and
  fails back inside it after the weekly WPSR window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Official U.S. Energy Information Administration source family:

- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP41
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13066_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13066_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Mission-directed EIA PADD 4 failed-upside WTI sleeve build | Enqueue to Q02 |
