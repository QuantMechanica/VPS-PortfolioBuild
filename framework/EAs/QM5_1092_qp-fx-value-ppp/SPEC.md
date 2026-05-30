# QM5_1092_qp-fx-value-ppp SPEC

## Source

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1092_qp-fx-value-ppp.md`
- Local copy: `docs/strategy_card.md`
- EA id: `1092`
- Slug: `qp-fx-value-ppp`

## Universe and Slots

| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | USDCHF.DWX |
| 6 | NZDUSD.DWX |

## Strategy Mapping

- No-Trade: block unsupported symbols and invalid rebalance cadence.
- Entry: on the first eligible H1 bar of a new quarter by default, read deterministic PPP/CPI fair values from `strategy_ppp_csv_path`, compute `spot_usd_per_ccy / fair_value - 1`, rank the 7 non-USD currencies, long the 3 lowest deviations and short the 3 highest deviations against USD.
- Trade management: none beyond the broker hard stop specified by the card.
- Exit: at the next scheduled rebalance, close positions whose symbol leaves the top/bottom bucket or flips direction.
- Stop: ATR(20) hard stop at 5.0x D1 ATR.
- Sizing: V5 risk contract. Backtest sets use `RISK_FIXED=1000`, live convention is `RISK_PERCENT=0.25`.
- Spread filter: skip new entry when current spread is greater than 3x median D1 spread over 20 days.
- Staleness: monthly mode rejects PPP/CPI observations older than 45 days; quarterly mode rejects observations older than 120 days.

## External Data Contract

`strategy_ppp_csv_path` is opened first from the terminal files sandbox and then from common files. Expected CSV columns:

```text
date,currency,ppp_fair_value,cpi_adjusted_fair_value
2026-03-31,EUR,1.1800,1.1700
```

The EA uses `cpi_adjusted_fair_value` when present and positive, otherwise `ppp_fair_value`. Values are USD per one unit of the non-USD currency. For USD-base pairs (`USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX`) the EA converts spot to USD per non-USD currency with `1 / close`.

Missing, future-dated, non-positive, or stale rows produce no signal rather than falling back to synthetic data.
