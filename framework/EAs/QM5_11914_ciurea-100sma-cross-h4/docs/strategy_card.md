---
ea_id: QM5_11914
slug: ciurea-100sma-cross-h4
source_id: a5e8f4b2-6c91-5d47-8b39-d2a6c4e7f3b8
source_citation: "Cristina Ciurea, 'The Truth Behind Commonly Used Indicators' (ScientificForex.com, approximately 2013), Section III 'Simple Moving Average Findings'."
title: "Ciurea 100-Period SMA Close-Cross H4"
edge_type: simple_ma_close_cross
period: H4
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 55
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_status: APPROVED
last_updated: 2026-05-25
---

# QM5_11914 - Ciurea 100-Period SMA Close-Cross (H4)

## Setup

Ciurea's empirical study tested simple moving-average periods across several
timeframes on EURUSD and GBPUSD. The 100-period SMA on H4 was profitable on
both pairs in the published four-year tables: 216 EURUSD trades with 29.86%
account growth and 269 GBPUSD trades with 55.08% growth.

## Entry Rules

On closed H4 bars, buy when the close crosses from at or below SMA(100) to
above it. Sell when the close crosses from at or above SMA(100) to below it.
An opposite cross closes the current position and flips direction.

## Exit Rules

- Primary exit: the opposite SMA(100) close-cross.
- Protective stop: 3.0 x ATR(14) from entry.
- Hard timeout: 250 H4 bars.
- Backtests use `RISK_FIXED=1000`; live sizing remains outside this build.

## Universe

The approved portability basket is EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX,
USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX,
and AUDJPY.DWX. Q02 must determine whether the published EURUSD/GBPUSD effect
survives outside the two source pairs.

## Source

Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
ScientificForex.com, Section III, mirrored at
`https://www.mql5.com/en/blogs/post/736967`. The Q00 card is canonical at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11914_ciurea-100sma-cross-h4.md`.
