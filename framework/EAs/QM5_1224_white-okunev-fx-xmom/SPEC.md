# QM5_1224 white-okunev-fx-xmom SPEC

## Identity
- EA: `QM5_1224_white-okunev-fx-xmom`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1224_white-okunev-fx-xmom.md`
- Status at build: `g0_status: APPROVED`
- V5 ea_id registry row: `1224,white-okunev-fx-xmom,...,active`

## Universe And Slots
| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | AUDUSD.DWX |
| 3 | NZDUSD.DWX |
| 4 | USDCAD.DWX |
| 5 | USDCHF.DWX |
| 6 | USDJPY.DWX |

## Framework Alignment
- No-Trade: blocks non-D1 charts, symbols outside the approved seven-pair DWX universe, invalid parameters, and insufficient history through the rank calculation.
- Entry: on rebalance D1 close, compute USD-normalized `Close / SMA(120) - 1`, rank currencies, and enter only the strongest and weakest legs at the next D1 open.
- Trade Management: broker hard stop at `3.0 * ATR(D1,20)` and basket kill when combined open loss reaches `2R`.
- Close: on rebalance, close an open leg if its currency leaves the top/bottom two ranks or flips direction.

## Card Parameters
- SMA period: `strategy_sma_period_d1 = 120`
- Minimum history: `strategy_min_d1_bars = 160`
- Exit rank band: `strategy_exit_rank_band = 2`
- Stop: `strategy_atr_period = 20`, `strategy_atr_sl_mult = 3.0`
- Basket kill: `strategy_basket_loss_r = 2.0`
- Rebalance: `strategy_rebalance_mode = 1` monthly, with `0` available for the P3 weekly sweep.
- Backtest risk: `RISK_FIXED = 500` per leg, `RISK_PERCENT = 0`
- Live risk: `RISK_PERCENT = 0.125` per leg, `RISK_FIXED = 0`

## Notes
- USD-base pairs are sign-adjusted so each score means foreign-currency strength versus USD.
- This build needs the EA attached to the seven DWX pair charts/setfiles so both basket legs can be opened by their corresponding symbol instance.
- No external data, ML, grid, martingale, trailing, pyramiding, or intramonth re-optimization logic is used.
