# QM5_1127 menkhoff-carry-fxvol-filter SPEC

## Identity
- EA: `QM5_1127_menkhoff-carry-fxvol-filter`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1127_menkhoff-carry-fxvol-filter.md`
- Status at build: `g0_status: APPROVED`
- V5 ea_id registry row: `1127,menkhoff-carry-fxvol-filter,...,active`

## Universe And Slots
| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | AUDUSD.DWX |
| 4 | NZDUSD.DWX |
| 5 | USDCHF.DWX |
| 6 | USDCAD.DWX |

## Framework Alignment
- No-Trade: blocks non-D1 charts, symbols outside the approved seven-pair G10 USD-cross universe, and invalid strategy parameters.
- Entry: on the first D1 bar of a new month, rank 63-bar foreign-currency momentum versus USD as the carry proxy; enter top-2 long foreign currency and bottom-2 short foreign currency only when the global-FX-vol filter allows risk.
- Trade Management: none beyond the card's ATR(D1,14) x 3 hard stop and the V5 portfolio kill-switch.
- Close: at the next monthly rebalance, close a leg if the volatility filter blocks risk, the symbol leaves the selected buckets, or the required direction flips.

## Card Parameters
- Carry proxy: `strategy_momentum_d1_bars = 63`
- Global volatility: `strategy_realized_vol_bars = 21`, `strategy_vol_baseline_bars = 252`, `strategy_vol_threshold_mult = 1.5`
- Bucket: `strategy_bucket_size = 2`, `strategy_min_valid_symbols = 6`
- Stop: `strategy_atr_period_d1 = 14`, `strategy_atr_sl_mult = 3.0`
- Spread filter: `strategy_spread_days = 20`, `strategy_spread_mult = 3.0`
- News: two-axis V5 news filter enabled by default (`PRE30_POST30`, `DXZ`)
- Backtest risk: `RISK_FIXED = 1000`, `RISK_PERCENT = 0`
- Live risk: `RISK_PERCENT = 0.25`, `RISK_FIXED = 0`

## Notes
- USD-base symbols are inverted for scoring so every score represents foreign-currency appreciation versus USD.
- "Global FX vol" is the arithmetic mean of 21-day annualized realized volatility across available USD crosses and must have at least six valid symbols.
- The baseline implementation uses monthly volatility checks, as specified for the card baseline; intra-month volatility exit remains a P3 variant.
- No external data, ML, grid, martingale, trailing, or pyramiding logic is used.
