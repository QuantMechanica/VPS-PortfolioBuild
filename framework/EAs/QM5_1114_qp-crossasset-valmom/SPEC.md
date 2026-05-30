# QM5_1114_qp-crossasset-valmom SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: cross-asset value and momentum composite ranking
- Universe: `SP500.DWX`, `NDX.DWX`, `GDAXI.DWX`, `UK100.DWX`, `JPN225.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved universe, symbols with disabled trading, and optional spread cap breaches.
- Trade Entry: on the first D1 bar after a calendar month changes, computes 12-month return rank, 1-month return rank, and value/yield rank from a local versioned CSV. It opens long if the current symbol is in the top quartile of the composite score and short if it is in the bottom quartile.
- Trade Management: no trailing, break-even, partial close, or pyramiding. The card-authorized hard stop is placed at entry.
- Trade Close: at the next monthly rebalance, closes an existing leg if it leaves the selected quartile, switches side, loses required data, or becomes non-tradable.

## Value/Yield CSV Contract

Default input: `strategy_value_csv_path=QM5_1114_crossasset_value.csv`.

The EA reads the file from the terminal files folder first and then from the common files folder. Accepted row shape:

```text
date,symbol,value_score
```

`date` must parse as `YYYY-MM-DD`. `symbol` must be one of the DWX symbols above. Higher `value_score` is treated as cheaper or higher-yielding and receives a higher rank. The EA uses the latest row with `date <= rebalance_day`; no web calls are made at runtime.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_value_csv_path` | `QM5_1114_crossasset_value.csv` | Versioned valuation/yield table |
| `strategy_momentum_12m_bars` | 252 | 12-month price momentum proxy on D1 data |
| `strategy_momentum_1m_bars` | 21 | 1-month price momentum proxy on D1 data |
| `strategy_min_d1_bars` | 270 | Minimum momentum eligibility |
| `strategy_weight_mom_12m` | 0.25 | Composite weight |
| `strategy_weight_mom_1m` | 0.25 | Composite weight |
| `strategy_weight_value` | 0.50 | Composite weight |
| `strategy_bucket_pct` | 25.0 | Top/bottom quartile selection |
| `strategy_min_eligible` | 4 | Minimum symbols before ranking |
| `strategy_value_stale_days` | 45 | Reject stale valuation rows |
| `strategy_atr_period_d1` | 20 | ATR stop period |
| `strategy_atr_sl_mult` | 5.0 | 5x D1 ATR hard stop |
| `strategy_max_spread_points` | 0 | Optional spread cap; 0 disables |

## Magic Slots

| Slot | Symbol |
|---:|---|
| 0 | `SP500.DWX` |
| 1 | `NDX.DWX` |
| 2 | `GDAXI.DWX` |
| 3 | `UK100.DWX` |
| 4 | `JPN225.DWX` |
| 5 | `XAUUSD.DWX` |
| 6 | `XAGUSD.DWX` |
| 7 | `XTIUSD.DWX` |

## Risk Contract

- Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live packaging must use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT` remains explicit in all setfiles.

## Notes

- `GER40.DWX` from the card is mapped to the Darwinex/index registry symbol `GDAXI.DWX`, matching adjacent V5 country-index EAs.
- No bond/rates proxies are included because no approved DWX bond/rates proxy was identified in the adjacent V5 registry patterns. This implements the card's index/commodity subset caveat.
- If `SP500.DWX` is the only passing leg, T6 promotion must honor the card's parallel-validation caveat on `NDX.DWX` or `WS30.DWX`.
