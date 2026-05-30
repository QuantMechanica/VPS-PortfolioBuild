# QM5_1111 qp-fx-momentum-12m SPEC

## Identity
- EA: `QM5_1111_qp-fx-momentum-12m`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1111_qp-fx-momentum-12m.md`
- Status at build: `g0_status: APPROVED`
- V5 ea_id registry row: `1111,qp-fx-momentum-12m,...,active`

## Universe And Slots
| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | AUDUSD.DWX |
| 3 | NZDUSD.DWX |
| 4 | USDJPY.DWX |
| 5 | USDCHF.DWX |
| 6 | USDCAD.DWX |

## Framework Alignment
- No-Trade: blocks non-D1 charts, symbols outside the approved 7-pair universe, and invalid strategy parameters.
- Entry: on month-end D1 closed bar, rank 252-bar foreign-currency returns versus USD; open top-3 long foreign currency and bottom-3 short foreign currency.
- Trade Management: none beyond the broker ATR hard stop specified by the card.
- Close: at next month-end, close a leg if it leaves its bucket or flips direction.

## Card Parameters
- Lookback: `strategy_lookback_d1_bars = 252`
- Minimum history: `strategy_min_d1_bars = 270`
- Buckets: `strategy_bucket_size = 3`
- Stop: `strategy_atr_period = 20`, `strategy_atr_sl_mult = 4.0`
- Spread filter: `strategy_spread_days = 20`, `strategy_spread_mult = 3.0`
- Backtest risk: `RISK_FIXED = 1000`, `RISK_PERCENT = 0`
- Live risk: `RISK_PERCENT = 0.25`, `RISK_FIXED = 0`

## Notes
- USD-base symbols are inverted for scoring so every score represents foreign-currency appreciation versus USD.
- The EA is a basket-style ranker and calls `QM_SymbolGuardInit` plus `QM_BasketWarmupHistory` for the seven-symbol universe after framework initialization.
- No external data, ML, grid, martingale, trailing, or pyramiding logic is used.
