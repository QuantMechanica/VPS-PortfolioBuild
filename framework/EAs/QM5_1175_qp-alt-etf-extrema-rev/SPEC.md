# QM5_1175_qp-alt-etf-extrema-rev SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: short-term extrema mean reversion
- Universe: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved port basket, disabled trading, and optional spread cap breaches.
- Trade Entry: on each completed D1 bar, computes the rolling N-day close high and low. A close at the N-day high opens a one-day short; a close at the N-day low opens a one-day long. Simultaneous high/low is skipped.
- Trade Management: no trailing, break-even, partial close, averaging, or pyramiding. The card-authorized hard stop is placed at entry.
- Trade Close: closes the EA's current symbol-slot position after at least one completed D1 bar since entry, or immediately if the symbol becomes non-tradable.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_extrema_lookback_d1` | 10 | Rolling N-day high/low; sweep target 5/10/20 |
| `strategy_min_valid_d1_bars` | 15 | Require at least N+5 valid D1 bars |
| `strategy_atr_period_d1` | 14 | ATR stop period |
| `strategy_atr_sl_mult` | 1.5 | ATR stop multiplier |
| `strategy_hold_bars_d1` | 1 | One-day holding period |
| `strategy_max_spread_points` | 0 | Optional spread cap; 0 disables |

## Magic Slots

| Slot | Symbol |
|---:|---|
| 0 | `NDX.DWX` |
| 1 | `WS30.DWX` |
| 2 | `GDAXI.DWX` |
| 3 | `UK100.DWX` |
| 4 | `XAUUSD.DWX` |
| 5 | `XTIUSD.DWX` |

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live setfiles use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT` remains explicit in all setfiles. Portfolio risk splitting is handled operationally by running one symbol-slot instance per proxy and constraining deployment allocation.

## Notes

- This is a deterministic DWX proxy port of the Quantpedia niche alternative ETF extrema reversal rule.
- The original ETF basket is unavailable in DXZ; the approved card allows the liquid CFD proxy basket used here.
- No external data, web calls, ML, martingale, grid, or averaging are used.
