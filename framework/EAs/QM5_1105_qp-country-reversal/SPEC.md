# QM5_1105_qp-country-reversal SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: long-term reversal across broad equity-index CFDs
- Universe: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `SP500.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved universe, and disabled trading status.
- Trade Entry: on the configured 36-month rebalance date, ranks eligible symbols by 756 closed D1-bar return. Bottom bucket opens long, top bucket opens short.
- Trade Management: no trailing, break-even, partial close, or pyramiding. The card-authorized hard stop is placed at entry.
- Trade Close: closes existing positions on the next 36-month rebalance date or when the current symbol loses valid trading status.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_return_lookback_d1` | 756 | Prior 36-month D1 return rank |
| `strategy_min_bars_d1` | 800 | Minimum rank-eligible history |
| `strategy_rebalance_month` | 1 | Anchor month |
| `strategy_rebalance_cadence_m` | 36 | Three-year rebalance cadence |
| `strategy_bucket_size` | 2 | Bottom-2 long / top-2 short |
| `strategy_atr_period_d1` | 20 | ATR stop period |
| `strategy_atr_sl_mult` | 4.0 | 4x adverse ATR stop |

## Magic Slots

| Slot | Symbol |
|---:|---|
| 0 | `NDX.DWX` |
| 1 | `WS30.DWX` |
| 2 | `GDAXI.DWX` |
| 3 | `UK100.DWX` |
| 4 | `SP500.DWX` |

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live packaging must use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT` remains explicit in all setfiles.

## Notes

- `GER40.DWX` in the card mechanics is mapped to the existing Darwinex/index registry symbol `GDAXI.DWX`, matching the G0 approval note and adjacent V5 index EAs.
- `SP500.DWX` is included as the fifth research/backtest leg per the approval note. T6 promotion must honor the card caveat if SP500 is the only passing live leg.
