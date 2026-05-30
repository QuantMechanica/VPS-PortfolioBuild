# QM5_1203 Ananta FX Rate Momentum

## Strategy Mapping
- Trade Entry: scheduled London/New-York rebalance reads a deterministic local rates CSV, computes `local_short_rate - USD_short_rate`, compares it with an SMA over `strategy_rate_sma_days`, and opens one FX position per symbol/magic slot.
- Trade Close: scheduled rebalance closes when the CSV signal reverses, flattens, or becomes unavailable/stale.
- Trade Management: broker hard stop only, using `2.0x` D1 ATR(20) by default.
- No-Trade: unsupported symbols, invalid rebalance mode, V5 framework kill/news/Friday guards, spread gate, and CSV freshness gate.

## CSV Contract
Default input: `strategy_rates_csv_path=QM5_1203_fx_rates.csv`.

The EA opens the file first from terminal Files and then from Common Files. Expected CSV columns:

```text
date,USD,EUR,GBP,JPY,AUD,NZD,CAD,CHF
2026-05-22,5.25,4.00,5.25,0.10,4.35,5.50,5.00,1.75
```

Rows must be point-in-time and versioned before the run. The EA intentionally makes no web/API calls. If fewer than `strategy_min_observations` rows are available, or if the latest observation is older than `strategy_stale_business_days`, the signal is unavailable and open positions are closed at the next scheduled rebalance.

## Universe And Slots
| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | NZDUSD.DWX |
| 5 | USDCAD.DWX |
| 6 | USDCHF.DWX |

## Parameters
| Input | Default | Meaning |
|---|---:|---|
| `strategy_rate_sma_days` | 15 | ANANTA long-term variant SMA length |
| `strategy_min_observations` | 30 | Minimum valid rate-differential rows before trading |
| `strategy_stale_business_days` | 3 | Maximum age of latest rate observation |
| `strategy_rebalance_mode` | 2 | `0=London`, `1=New York`, `2=both` |
| `strategy_atr_period_d1` | 20 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 2.0 | ATR multiple for hard stop |
| `strategy_daily_loss_r_mult` | 2.0 | Card kill-switch target; enforced by framework kill-switch when configured |

## Notes
- `RISK_FIXED=1000` for backtests, `RISK_PERCENT=0.25` for live setfiles.
- `PORTFOLIO_WEIGHT=0.142857` approximates equal weight across seven FX symbols.
- No backtests or pipeline phases are part of this build.
