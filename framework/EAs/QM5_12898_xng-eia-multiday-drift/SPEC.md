# QM5_12898_xng-eia-multiday-drift - Strategy Spec

**EA ID:** QM5_12898
**Slug:** `xng-eia-multiday-drift`
**Source:** `EIA-XNG-MULTIDAY-DRIFT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It uses the EIA Weekly Natural Gas Storage Report only as a
recurring official event structure. On each new D1 bar it checks whether the
immediately preceding completed D1 bar was a likely storage-report event bar
that closed directionally. If the event bar is large enough, has sufficient
body, closes near the directional extreme, and agrees with the D1 SMA trend,
the EA enters one market position for a short multiday continuation drift.

Runtime uses MT5 OHLC and broker calendar only. It does not import EIA storage
levels, storage surprises, consensus forecasts, weather data, futures curves,
CSV files, APIs, or discretionary inputs.

This is intentionally not a duplicate of the existing XNG family:
`QM5_12567` is a cumulative RSI2 pullback, `QM5_12761` is a post-storage
inside-day breakout, `QM5_12744` is a storage-bar fade, and `QM5_12725` is a
pre-storage positioning sleeve.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_min_dow` | 3 | 3 | Earliest broker weekday for likely storage event; Wednesday=3 |
| `strategy_event_max_dow` | 5 | 4-5 | Latest broker weekday for likely storage event |
| `strategy_entry_min_dow` | 1 | 1 | Earliest broker weekday for next-bar entry; Monday=1 |
| `strategy_entry_max_dow` | 5 | 5 | Latest broker weekday for next-bar entry |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event-size filter and hard stop |
| `strategy_trend_period` | 50 | 40-63 | D1 SMA trend confirmation and exit |
| `strategy_min_event_range_atr` | 0.80 | 0.70-1.00 | Minimum event-bar range in ATRs |
| `strategy_max_event_range_atr` | 3.50 | 2.50-4.50 | Maximum event-bar range in ATRs |
| `strategy_close_location_threshold` | 0.65 | 0.60-0.70 | Required directional close location |
| `strategy_min_body_ratio` | 0.25 | 0.20-0.35 | Minimum candle body as share of full range |
| `strategy_atr_sl_mult` | 3.00 | 2.50-3.50 | Stop distance multiplier |
| `strategy_atr_tp_mult` | 0.00 | 0-5.0 | Optional target multiplier; 0 disables |
| `strategy_signal_valid_days` | 1 | 1-2 | Cached signal expiry |
| `strategy_max_hold_days` | 4 | 3-5 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |
| `strategy_require_trend` | true | true | Require event close to agree with SMA trend |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: setup formation is `QM_IsNewBar()` gated. Entry uses the cached
  D1 signal and current market bid/ask only.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-18.
- Typical hold: one to four calendar days, segmented by Friday close.
- Regime preference: directional follow-through after official natural-gas
  storage-report bars.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Natural Gas Storage Report",
URL https://www.eia.gov/naturalgas/storage/. Supplemental release schedule:
https://www.eia.gov/naturalgas/schedule/. Sources are used only for structural
lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from approved card | Enqueue Q02 |
