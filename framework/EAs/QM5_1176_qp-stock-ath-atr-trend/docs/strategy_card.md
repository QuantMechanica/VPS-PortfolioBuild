---
ea_id: QM5_1176
slug: qp-stock-ath-atr-trend
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia All-Time-High ATR Trend Port

## Quelle

- Source: Quantpedia Encyclopedia, 2024, "Trend-following Effect in Stocks".
- Named source authors: George Pruitt, "The Ultimate Algorithmic Trading System Toolbox", Wiley 2016; related trend-following literature includes Hurst, Ooi, and Pedersen 2017.
- Location: Simple trading strategy section.

## Mechanik

### Entry

On each completed D1 bar:

1. Trade one confirmed broad index CFD at a time: primary `SP500.DWX` for backtest, live-validation proxies `NDX.DWX` and `WS30.DWX`.
2. Compute the highest completed D1 close since the start of available history, excluding the current signal bar.
3. If today's completed close is greater than or equal to that historical highest close, open LONG on the next executable bar.
4. Hold one active long position only; no pyramiding on repeated all-time-high closes.

### Exit

- Maintain a 10-period ATR trailing stop on D1 bars.
- Close the long position when the D1 close falls below the trailing stop.
- Optional P3 variant: use intrabar stop execution rather than close-only stop.

### Stop Loss

- Initial stop: 2.0x ATR(10) below entry until the trailing stop advances.
- Time stop: none; trend remains active until stopped.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter

- Source used individual U.S. stocks; DWX implementation ports the same all-time-high plus ATR-stop rule to broad index CFDs.
- Require at least 500 D1 bars before the first signal.
- No volatility targeting, parameter adaptation, grid, or martingale.

## R3 - T6 Live-Promotion-Caveat

Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
