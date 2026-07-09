# QM5_13099_xng-coal-switch - Strategy Spec

**EA ID:** QM5_13099
**Slug:** `xng-coal-switch`
**Source:** `EIA-XNG-COAL-SWITCH-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency `XNGUSD.DWX` D1 demand-floor reclaim. EIA
documents that favorable natural-gas prices can increase gas use and that low
gas prices can make gas-fired generators more competitive with coal. The EA
tests that mechanism only in price-sensitive spring and early-autumn shoulder
windows.

Entry requires the completed D1 close to rank in the bottom quartile of the
preceding 252 closes, cross from below to above SMA(10), print a bullish ATR-
sized range, and close in the upper portion of the bar. It is long-only and
allows at most one accepted entry per spring/autumn season key.

This is not `QM5_12567` RSI2, `QM5_12895` six-month symmetric reversal,
summer-power trend, summer compression, seasonal spring short, winter turn,
storage/event, carry, or cross-commodity basket logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_spring_start_month/day` | 4/1 | fixed | Spring fuel-switch window start |
| `strategy_spring_end_month/day` | 5/31 | fixed | Spring fuel-switch window end |
| `strategy_autumn_start_month/day` | 9/1 | fixed | Autumn fuel-switch window start |
| `strategy_autumn_end_month/day` | 10/15 | 10/1-10/31 | Autumn fuel-switch window end |
| `strategy_price_rank_lookback` | 252 | 189-315 | Completed D1 closes in the annual-rank proxy |
| `strategy_entry_price_percentile` | 0.25 | 0.15-0.30 | Maximum price rank for entry |
| `strategy_exit_price_percentile` | 0.55 | 0.45-0.65 | Normalized rank exit |
| `strategy_reclaim_sma_period` | 10 | 5-15 | Reclaim and failure mean |
| `strategy_atr_period` | 20 | 14-30 | ATR signal/stop/target period |
| `strategy_min_range_atr` | 0.55 | 0.40-0.75 | Minimum signal range in ATR units |
| `strategy_min_close_location` | 0.65 | 0.58-0.72 | Minimum signal close location |
| `strategy_exit_sma_buffer_atr` | 0.30 | 0.10-0.50 | Adverse SMA-exit buffer |
| `strategy_atr_sl_mult` | 2.80 | 2.20-3.40 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.80 | 2.80-5.00 | ATR target distance |
| `strategy_max_hold_days` | 25 | 15-35 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- D1 host and signal timeframe.
- Completed bars only after `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected entries: 0-2/year; at most one in each annual shoulder window.
- Direction: long only.
- Hold: several D1 bars, capped by ATR stop/target, price-rank normalization,
  SMA failure, max hold, and framework Friday close.
- Q02 risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## 6. Source Citation

Official U.S. Energy Information Administration packet:

- https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php
- https://www.eia.gov/todayinenergy/detail.php?id=8450
- https://www.eia.gov/todayinenergy/detail.php?id=67725

No external source is read at runtime and no source performance number is
imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved | RISK_PERCENT | allocated by portfolio process |

No live setfile, `T_Live` file, AutoTrading state, deploy manifest, T_Live
manifest, portfolio gate, or portfolio admission artifact is touched.

## 8. Framework Alignment

- No-Trade: symbol/timeframe, parameter, magic-slot, spread, one-position, and
  one-entry-per-season constraints.
- Entry: shoulder window, annual price rank, bullish SMA reclaim, ATR range,
  and close-location confirmation.
- Management: rank normalization, SMA failure, and max-hold exits.
- Close: ATR stop/target plus deterministic strategy exits.

## 9. Pipeline History

| version | date | reason | next phase |
|---|---|---|---|
| v1 | 2026-07-09 | initial EIA fuel-switching demand-floor build | Q02 |

