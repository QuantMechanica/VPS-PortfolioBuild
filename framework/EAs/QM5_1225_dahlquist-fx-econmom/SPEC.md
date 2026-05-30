# QM5_1225 dahlquist-fx-econmom

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1225_dahlquist-fx-econmom.md`
- Status: APPROVED
- EA ID: 1225
- Slug: dahlquist-fx-econmom

## Framework Alignment

- No-Trade: blocks symbols outside the approved seven-pair DWX FX basket.
- Entry: at the first D1 bar of a new month, reads `QM5_1225_fx_econmom.csv`, computes 6-month changes in industrial production YoY and CPI YoY, z-scores the cross-section, and enters the top or bottom economic-momentum currency.
- Management: no discretionary management beyond framework risk controls and hard ATR stops.
- Exit: at monthly rebalance, closes if the currency is no longer in the top/bottom exit bucket or if the macro table is unavailable/stale.

## Data Contract

The EA never calls external APIs. The OWNER-provided macro file must be available in the MT5 files path or common files path:

```text
QM5_1225_fx_econmom.csv
country,date,industrial_production_yoy,cpi_yoy
EUR,2026-04-30,1.2,2.1
GBP,2026-04-30,0.8,2.8
```

Accepted `country` keys are `EUR`, `GBP`, `AUD`, `NZD`, `CAD`, `CHF`, and `JPY`. The EA stays flat when fewer than `strategy_min_eligible` currencies have usable lookback observations or when the latest common macro observation is older than `strategy_macro_stale_days`.

## Symbols And Magic Slots

| Slot | Symbol |
| ---: | --- |
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | AUDUSD.DWX |
| 3 | NZDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | USDCHF.DWX |
| 6 | USDJPY.DWX |

## Inputs

- `strategy_macro_lookback_months`: default `6`; P3 sweep candidate `{3, 6, 12}`.
- `strategy_rank_count_entry`: default `1`; P3 sweep candidate `{1, 2}`.
- `strategy_rank_count_exit`: default `2`; implements the card's exit if a leg leaves top/bottom two ranks.
- `strategy_atr_period_d1`: default `20`.
- `strategy_atr_sl_mult`: default `3.0`.

## Build Notes

- Build-only artifact. No backtests or pipeline phases were run.
- Runtime can intentionally produce no trades until the macro CSV is present and fresh.
