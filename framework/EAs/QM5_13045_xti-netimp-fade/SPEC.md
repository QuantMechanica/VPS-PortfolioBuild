# QM5_13045_xti-netimp-fade - Strategy Spec

**EA ID:** QM5_13045
**Slug:** `xti-netimp-fade`
**Source:** `EIA-XTI-NETIMP-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI net-import shock fade on `XTIUSD.DWX`.
On each new D1 bar it inspects the previous completed D1 bar. That signal bar
must be Wednesday or Thursday in broker time, ATR-sized, and part of a multi-day
same-direction extension away from a D1 SMA anchor. The EA then trades
contrarian toward mean reversion and consumes at most one signal per
broker-calendar month.

No external EIA, CSV, web, analyst, or calendar feed is used at runtime. EIA is
source lineage only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_report_start_dow` | 3 | fixed | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | fixed | Thursday WPSR holiday-drift proxy |
| `strategy_run_lookback` | 5 | 3-8 | D1 bars used for same-direction extension |
| `strategy_sma_period` | 50 | 35-80 | D1 mean-reversion anchor |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.90 | 0.65-1.20 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.25 | 0.15-0.45 | Minimum signal-bar body in ATR units |
| `strategy_min_sma_distance_atr` | 0.70 | 0.45-1.10 | Minimum close distance from SMA |
| `strategy_min_run_atr` | 0.80 | 0.50-1.30 | Minimum multi-day run in ATR units |
| `strategy_low_close_location` | 0.30 | 0.20-0.40 | Max close location for long-fade setup |
| `strategy_high_close_location` | 0.70 | 0.60-0.80 | Min close location for short-fade setup |
| `strategy_atr_sl_mult` | 2.60 | 2.0-3.4 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.10 | 1.5-3.0 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA mean-reversion,
  stale-position, and framework Friday close.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration net-imports and WPSR source packet:

- https://www.eia.gov/petroleum/supply/weekly/
- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WTTNTUS2
- https://www.eia.gov/energyexplained/oil-and-petroleum-products/imports-and-exports.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
