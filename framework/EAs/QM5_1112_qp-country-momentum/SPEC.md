# QM5_1112_qp-country-momentum SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: long-only country equity-index momentum rotation
- Universe: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `JPN225.DWX`, `AUS200.DWX`, `SP500.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved universe, disabled trading status, insufficient data, and current spread above 3x the median D1 spread over the prior 20 trading days.
- Trade Entry: at the first closed D1 bar of each new month, ranks eligible symbols by prior closed-month lookback return. Default lookback is 11 months. Opens long only in the top bucket.
- Trade Management: no trailing, break-even, partial close, or pyramiding. The card-authorized hard stop is placed at entry.
- Trade Close: on the next monthly rebalance, closes an existing position when the symbol leaves the selected top bucket or loses valid trading status.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_return_lookback_months` | 11 | Prior 10/11/12 month return rank; 11 months default |
| `strategy_min_bars_d1` | 270 | Minimum rank-eligible D1 history |
| `strategy_bucket_size_small` | 2 | Top-2 when eligible universe has fewer than 10 symbols |
| `strategy_bucket_size_large` | 5 | Top-5 when eligible universe has at least 10 symbols |
| `strategy_large_universe_min` | 10 | Card threshold for top-5 basket |
| `strategy_atr_period_d1` | 20 | ATR hard-stop period |
| `strategy_atr_sl_mult` | 4.0 | 4x adverse D1 ATR hard stop |
| `strategy_spread_filter_enabled` | true | Enables card spread filter |
| `strategy_max_spread_median_mult` | 3.0 | Max current spread vs prior-20 D1 median |

## Magic Slots

| Slot | Symbol |
|---:|---|
| 0 | `NDX.DWX` |
| 1 | `WS30.DWX` |
| 2 | `GDAXI.DWX` |
| 3 | `UK100.DWX` |
| 4 | `JPN225.DWX` |
| 5 | `AUS200.DWX` |
| 6 | `SP500.DWX` |

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live packaging must use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT` remains explicit in all setfiles.

## Notes

- `GER40.DWX` in the card mechanics is mapped to `GDAXI.DWX`, matching the local Darwinex/index registry convention and adjacent Country Index V5 EAs.
- `SP500.DWX` is included as a research/backtest leg per the card caveat. T6 promotion must honor the caveat if SP500 is the only passing live leg.
- The default card universe has seven symbols, so the default build selects the top 2 rather than top 5.
