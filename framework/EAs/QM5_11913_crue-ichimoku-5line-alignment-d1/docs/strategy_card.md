---
ea_id: QM5_11913
slug: crue-ichimoku-5line-alignment-d1
source_id: f9b3c7a4-2e58-5d63-9c47-a1d6e4b7f2c8
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
---

# Cruë Ichimoku 5-Line Alignment Trend-Following

This build-time copy records the mechanical rules from the approved farm card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11913_crue-ichimoku-5line-alignment-d1.md`.

## Entry

On a closed D1 bar, buy when the card's strict bullish ordering holds:
Tenkan(9) > Kijun(26) > displayed Senkou A > displayed Senkou B > the 26-bar
lagged-close Chikou proxy. Sell when every inequality is reversed. Enter at the
next market opportunity and allow one position per EA magic and symbol.

## Exit and risk

Exit when the strict alignment breaks, after 180 D1 bars, or through the V5
Friday-close and kill-switch controls. Place the initial protective stop at
3.0 × ATR(14). Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Source

Emeric Cruë, “Back-Testing: Ichimoku Trading Strategy Using Python,” Python in
Quantitative Finance, May 2019. The underlying fixed 9/26/52 system is Goichi
Hosoda's published Ichimoku Kinko Hyo method. No ML, adaptive sizing, grid, or
martingale logic is authorized.
