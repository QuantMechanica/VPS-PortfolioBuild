# QM5_12872_eia-xng-stor-drift - Strategy Spec

**EA ID:** QM5_12872
**Slug:** `eia-xng-stor-drift`
**Source:** `EIA-XNG-STOR-DRIFT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency natural-gas storage-cycle drift proxy on
`XNGUSD.DWX`. It uses EIA storage-report cadence and EIA storage-season
definitions as structural lineage, but it reads no EIA data, expectations,
weather, futures curves, CSV files, APIs, or news feeds at runtime.

On each new D1 bar it evaluates the previous completed D1 bar if that bar falls
inside the storage-report proxy window. Withdrawal-season report-window bars
can trigger long continuation entries after a confirmed upward drift. Injection
shoulder months can trigger short continuation entries after a confirmed
downward drift. The signal must have body quality, close-location quality,
ATR-sized drift, and trend-side SMA displacement. At most one signal is
consumed per broker-calendar month.

Positions use ATR hard stop, SMA trend-failure exit, max-hold exit, standard V5
news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for drift and stop scaling |
| `strategy_trend_period` | 50 | 35-80 | D1 SMA trend anchor |
| `strategy_drift_lookback` | 3 | 2-5 | Completed D1 bars in drift window |
| `strategy_min_drift_atr` | 0.95 | 0.60-1.40 | Minimum drift in ATR units |
| `strategy_min_body_ratio` | 0.25 | 0.15-0.45 | Minimum signal body/range ratio |
| `strategy_min_trend_stretch_atr` | 0.25 | 0.10-0.60 | Minimum close-to-SMA displacement |
| `strategy_high_close_location` | 0.62 | 0.55-0.75 | Minimum close location for long drift |
| `strategy_low_close_location` | 0.38 | 0.25-0.45 | Maximum close location for short drift |
| `strategy_atr_sl_mult` | 3.10 | 2.4-3.8 | ATR stop distance |
| `strategy_max_hold_days` | 6 | 3-9 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.
- `XNGUSD.DWX` is present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-9 before Q02 validation.
- Direction: long in withdrawal season, short in injection shoulder months.
- Typical hold: several D1 bars, capped by ATR stop, SMA trend failure, and
  stale-position guard.
- Regime preference: confirmed storage-window drift aligned with seasonal
  storage pressure.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

- U.S. Energy Information Administration Weekly Natural Gas Storage Report:
  https://www.eia.gov/naturalgas/storage/
- U.S. Energy Information Administration Weekly Natural Gas Storage Report
  schedule: https://ir.eia.gov/ngs/schedule.html
- U.S. Energy Information Administration Today in Energy storage-season context:
  https://www.eia.gov/todayinenergy/detail.php?id=1310

The sources define storage-report cadence and withdrawal/injection-season
lineage. Runtime uses only Darwinex MT5 OHLC and broker state.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
