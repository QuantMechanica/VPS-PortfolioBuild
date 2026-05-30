# QM5_1156 caldeira-cointegration-pairs-fx

## Build Scope
- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1156_caldeira-cointegration-pairs-fx.md`
- Status: APPROVED / G0
- Framework: QuantMechanica V5
- Build only: no backtests or pipeline phases executed.

## Strategy Mapping
- No-Trade: V5 framework kill-switch, news, Friday close, and strategy host-symbol/timeframe guard.
- Entry: M30 host execution over the six-card FX universe, with D1 rolling OLS on log prices, residual z-score, ADF t-stat approximation, entry at `|z| >= 2.0`, and max four active pair slots.
- Management: pair legs are monitored under one pair magic. Per-leg catastrophic stop is submitted at ATR(D1,14) x 3.
- Close: exit at `|z| <= 0.5`, spread stop at `|z| >= 4.0`, cointegration-loss exit using the ADF threshold for p=0.10, and 30 trading-day time stop.

## Pair Slots
The 15 slots enumerate the six-symbol universe in deterministic order:

0. EURUSD.DWX / GBPUSD.DWX
1. EURUSD.DWX / USDJPY.DWX
2. EURUSD.DWX / USDCHF.DWX
3. EURUSD.DWX / AUDUSD.DWX
4. EURUSD.DWX / NZDUSD.DWX
5. GBPUSD.DWX / USDJPY.DWX
6. GBPUSD.DWX / USDCHF.DWX
7. GBPUSD.DWX / AUDUSD.DWX
8. GBPUSD.DWX / NZDUSD.DWX
9. USDJPY.DWX / USDCHF.DWX
10. USDJPY.DWX / AUDUSD.DWX
11. USDJPY.DWX / NZDUSD.DWX
12. USDCHF.DWX / AUDUSD.DWX
13. USDCHF.DWX / NZDUSD.DWX
14. AUDUSD.DWX / NZDUSD.DWX

## Notes
- The card describes Engle-Granger ADF p-values. The EA implements the standard residual AR(1) ADF t-stat and maps requested p-thresholds to fixed critical values inline; no external packages or APIs are used.
- Both legs of a pair use the same pair-slot magic, matching the card requirement of one position package per pair-magic.
- Weekly OLS refresh occurs on the first run and then on a new week after the latest closed D1 bar is Friday.
- ID collision observed in the approved-card folder: `QM5_1156_qp-pre-election-sp500.md` also exists. This build intentionally targets only `caldeira-cointegration-pairs-fx`.
