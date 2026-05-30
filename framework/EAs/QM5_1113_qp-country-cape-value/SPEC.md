# QM5_1113_qp-country-cape-value SPEC

## Strategy

- Source card: `docs/strategy_card.md`
- Status: APPROVED / G0
- Concept: yearly country-index value allocation by CAPE ratio
- Universe: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `JPN225.DWX`, `AUS200.DWX`, `SP500.DWX`
- Timeframe: D1

## Framework Alignment

- No-Trade: blocks non-D1 charts, symbols outside the approved universe, and symbols with disabled trading.
- Trade Entry: on the first D1 bar after calendar year-end, reads the latest local CAPE CSV observation at or before the rebalance date, ranks eligible countries ascending by CAPE, and opens long only for the cheapest configured bucket where CAPE is below the threshold.
- Trade Management: no trailing, break-even, partial close, or pyramiding. The card-authorized hard stop is placed at entry.
- Trade Close: closes an existing leg at the next yearly rebalance if the symbol is no longer in the selected CAPE bucket, if its CAPE row is missing/stale, or if the symbol becomes non-tradable.

## CAPE CSV Contract

Default input: `strategy_cape_csv_path=QM5_1113_country_cape.csv`.

The EA reads the file from the terminal files folder first and then from the common files folder. Accepted row shapes:

```text
date,symbol,cape
date,country,symbol,cape
```

`date` must parse as `YYYY-MM-DD`. `symbol` is one of the DWX symbols above; `country` may use the internal names from the EA. The EA uses the latest row with `date <= rebalance_day`; no web calls are made at runtime.

## Parameters

| Input | Default | Card mapping |
|---|---:|---|
| `strategy_cape_csv_path` | `QM5_1113_country_cape.csv` | Deterministic external CAPE table |
| `strategy_cape_threshold` | 15.0 | CAPE must be below 15 |
| `strategy_bucket_pct` | 33.0 | Cheapest 33% bucket |
| `strategy_min_eligible` | 3 | Minimum eligible CAPE rows before ranking |
| `strategy_csv_stale_days` | 800 | Reject stale CAPE observations |
| `strategy_atr_period_d1` | 20 | ATR stop period |
| `strategy_atr_sl_mult` | 5.0 | 5x D1 ATR hard stop |

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

- `GER40.DWX` in the card mechanics is mapped to the existing Darwinex/index registry symbol `GDAXI.DWX`, matching adjacent country-index V5 EAs.
- `SP500.DWX` is included as a backtest/research leg per the card caveat. If it is the only passing leg, T6 promotion requires the card's parallel-validation condition.
