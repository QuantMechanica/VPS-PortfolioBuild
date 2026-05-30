# QM5_1176_qp-stock-ath-atr-trend SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: all-time-high trend following with ATR trailing stop
- Universe: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved proxy basket, disabled trading, invalid ATR/history settings, and optional spread cap breaches.
- Trade Entry: on each completed D1 bar, compares the signal close with the highest completed D1 close in earlier available history. A new all-time-high close opens one long position on the next executable D1 bar.
- Trade Management: maintains the card-authorized ATR(10) trailing stop, advanced only from completed D1 bars and never loosened.
- Trade Close: closes the EA's current symbol-slot long when the completed D1 close falls below the current trailing stop. The broker-side stop remains present as the card's optional intrabar stop execution variant and as the initial risk stop.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_min_history_d1_bars` | 500 | Minimum completed D1 bars before first signal |
| `strategy_atr_period_d1` | 10 | ATR trailing stop period |
| `strategy_initial_sl_atr_mult` | 2.0 | Initial stop 2.0x ATR(10) below entry |
| `strategy_trail_atr_mult` | 2.0 | ATR trailing stop distance |
| `strategy_close_only_exit` | true | Baseline close-only trailing-stop exit |
| `strategy_max_spread_points` | 0 | Optional spread cap; 0 disables |

## Magic Slots

| Slot | Symbol |
|---:|---|
| 0 | `SP500.DWX` |
| 1 | `NDX.DWX` |
| 2 | `WS30.DWX` |

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live setfiles use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT` remains explicit in all setfiles.

## Notes

- `SP500.DWX` is the primary backtest symbol from the card but remains a T6 live caveat.
- `NDX.DWX` and `WS30.DWX` are provided as live-validation proxies.
- No external data, web calls, ML, martingale, grid, averaging, volatility targeting, or adaptive parameters are used.
