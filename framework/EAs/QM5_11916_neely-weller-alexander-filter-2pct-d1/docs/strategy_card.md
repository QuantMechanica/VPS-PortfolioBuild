---
copy_of: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11916_neely-weller-alexander-filter-2pct-d1.md
ea_id: QM5_11916
slug: neely-weller-alexander-filter-2pct-d1
source_id: 7e2b8f4a-3c95-5d68-9a47-d3b6e1f4c7a8
g0_status: APPROVED
status: APPROVED
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
---

# QM5_11916 — Neely-Weller / Alexander 1961 Filter Rule (2%, D1)

## Approved source

Christopher J. Neely and Paul A. Weller, “Lessons from the Evolution of
Foreign Exchange Trading Strategies,” Federal Reserve Bank of St. Louis
Working Paper 2011-021C / SSRN, April 2013, Section 2. The card implements
the Alexander (1961) filter family at the source-tested 2% threshold.

## Mechanical rule

The strategy maintains the running low and high since the last directional
turn. On each closed D1 bar it enters or flips long when the close exceeds
the running low by 2%, and enters or flips short when the close falls 2%
below the running high. The extrema reset on a flip. The first signal is
eligible after a 20-bar warm-up.

The position exits on the opposite filter trigger, a defensive 4 x ATR(14)
stop, or a 250-D1-bar timeout. Backtests use `RISK_FIXED=1000` and
`RISK_PERCENT=0`. The implementation remains deterministic, structural,
and free of ML, grid, martingale, or external runtime data.

## Approved universe

The portable baseline contains seven FX majors and three JPY crosses:
`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX`,
`AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX`.
Each symbol has a distinct active magic slot in the canonical registry.

## G0 decision

R1 PASS: reputable Federal Reserve working-paper lineage. R2 PASS:
closed-form extrema and percentage thresholds. R3 PASS: all ten symbols are
present in the DWX matrix. R4 PASS: deterministic arithmetic only. Approved
for the standard V5 build and Q02 pipeline.
