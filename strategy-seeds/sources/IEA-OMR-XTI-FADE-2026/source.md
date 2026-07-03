# IEA-OMR-XTI-FADE-2026

## Source Packet

- Primary source: International Energy Agency, Oil Market Report (OMR).
  URL: https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr
- Context source: International Energy Agency, Oil Market Report - June 2026.
  URL: https://www.iea.org/reports/oil-market-report-june-2026
- Access date: 2026-07-03.
- Quality tier: A, official agency report/data-product source.

## Use In QM

The source establishes a recurring official monthly oil-market information
window covering supply, demand, inventories, prices, refinery activity, and oil
trade. QM does not import performance claims or runtime report values from the
source.

`QM5_12994_iea-omr-fade` expresses the source as an OHLC-only `XTIUSD.DWX` D1
shock-fade proxy during broker-calendar days 10 through 18 of each month.
Runtime is restricted to MT5 OHLC, ATR, spread, broker calendar, and V5
framework state.
