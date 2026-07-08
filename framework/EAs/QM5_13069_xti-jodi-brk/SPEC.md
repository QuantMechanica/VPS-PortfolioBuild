# QM5_13069_xti-jodi-brk - Strategy Spec

**EA ID:** QM5_13069
**Slug:** `xti-jodi-brk`
**Source:** `JODI-OIL-UPDATE-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly global-oil data update-window
breakout on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed
D1 bar, requiring that bar to fall inside a deterministic mid-to-late-month
JODI/IEF update proxy window.

Entries are symmetric long/short. A setup requires a completed-bar Donchian
closing breakout, minimum ATR range/body, and SMA trend/slope confirmation.
Positions use ATR hard stop, ATR target, max-hold exit, trend-SMA invalidation,
standard V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 18 | 16-20 | First broker-calendar day in JODI monthly proxy window |
| `strategy_event_end_day` | 23 | 21-25 | Last broker-calendar day in JODI monthly proxy window |
| `strategy_breakout_lookback` | 34 | 20-55 | Completed D1 bars used for Donchian context |
| `strategy_trend_sma_period` | 100 | 63-150 | Trend SMA period |
| `strategy_sma_slope_shift` | 5 | 3-10 | Prior SMA sample for slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.70 | 0.50-1.20 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.25 | 0.15-0.50 | Minimum signal-bar body in ATR units |
| `strategy_min_break_atr` | 0.05 | 0.00-0.15 | Minimum close-through breakout buffer |
| `strategy_atr_sl_mult` | 2.40 | 1.75-3.25 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.20 | 2.25-4.25 | ATR target distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target/stop, max-hold exit,
  trend-SMA invalidation, and Friday close.
- Regime preference: mid-to-late monthly global-oil data update windows where
  WTI closes through a prior D1 range in the direction of its SMA trend.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Official JODI/IEF/IEA source family:

- https://www.jodidata.org/oil/
- https://www.jodidata.org/oil/support/update-calendar.aspx
- https://www.ief.org/data/oil-gas-data-review
- https://www.iea.org/about/international-collaborations/joint-organisations-data-initiative

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13069_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13069_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Mission-directed JODI monthly global-oil WTI breakout build | Enqueue to Q02 |
