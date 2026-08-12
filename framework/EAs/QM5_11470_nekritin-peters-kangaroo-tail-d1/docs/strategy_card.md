---
ea_id: QM5_11470
slug: nekritin-peters-kangaroo-tail-d1
type: strategy
source_id: 7f773fbb-884e-54c9-a5d8-3f4087497622
period: D1
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 10
---

# Nekritin/Peters Kangaroo Tail / Pin Bar (D1)

Build-time copy of the OWNER-approved card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11470_nekritin-peters-kangaroo-tail-d1.md`.

The EA evaluates the last completed D1 candle. A bullish setup requires a
lower shadow at least twice the real body, the body in the upper half of the
candle, and a low below the preceding seven-bar room-to-the-left window. The
bearish setup mirrors those rules. It places a one-day stop order beyond the
tail candle, protects beyond the opposite tail extreme, and targets the
nearest bounded fractal support/resistance level in the trade direction.

Approved symbols are `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`,
and `USDCAD.DWX`. Baseline inputs use the 2:1 tail/body ratio, seven room bars,
no optional ATR or trend filter, a one-pip entry and stop offset, a 100-pip
maximum stop, and a 25-pip spread cap. Pending orders expire after one D1 bar;
new Friday entries are blocked. Backtests use `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Source: Alex Nekritin and Walter Peters, *Naked Forex: High-Probability
Techniques for Trading without Indicators*, Chapter 8, Wiley Trading (2012).
This build authorizes non-live testing only.
