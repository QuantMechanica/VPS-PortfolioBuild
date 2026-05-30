---
ea_id: QM5_10141
slug: rsi-meanrev
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS verifiable Raposa URL/mirror; R2 PASS RSI(14) threshold entry and RSI 50 exit with ~20 trades/year/symbol; R3 PASS OHLC-close rules portable to DWX CFDs with SP500 T6 caveat; R4 PASS fixed non-ML one-position logic."
---

# RSI Mean Reversion Centerline Exit

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/4-simple-rsi-trading-strategies-you-can-use-today/
- Accessible mirror used for rule extraction: https://readmedium.com/4-simple-rsi-trading-strategies-db7b9790c690
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Jun. 24, 2021
- Page / Timestamp: "RSI for Overbought and Oversold Positions"

## Mechanik

### Entry
- Compute Wilder RSI over `P = 14` completed D1 closes.
- Enter long at next bar if `RSI < 30` and no position is open.
- Optional short mode: enter short at next bar if `RSI > 70` and no position is open.

### Exit
- Exit any open position when RSI crosses the centerline `50`.
- In short-enabled mode, cover the short on the same centerline cross rule.

### Stop Loss
- Source does not define a hard stop.
- Research default: emergency stop at `3 * ATR(14)` from entry; signal exit remains primary.

### Position Sizing
- Source code tracks full-position returns and does not define lots.
- Use V5 fixed-risk P2 baseline and standard live risk conventions if approved.

### Zusaetzliche Filter
- D1 timeframe.
- Use closed bars only; execute on next bar open.
- Default long-only for equity-index ports; short-enabled variant can be swept.

## Concepts
- [[concepts/mean-reversion]] - primary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa URL/mirror with named author handle and publication date. |
| R2 Mechanical | PASS | RSI thresholds and centerline exit are explicit deterministic rules. |
| R3 Data Available | PASS | Requires only OHLC close series; portable to DWX indices, FX, metals, and oil CFDs. |
| R4 ML Forbidden | PASS | Fixed-parameter oscillator logic; no ML, adaptive sizing, grid, or martingale. |

## R3
Raposa example used TWTR. Port to SP500.DWX, NDX.DWX, WS30.DWX, FX, metals, and oil CFDs because the rule uses only bar closes. If SP500.DWX is used: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source describes the setup as buying low and shorting high, then riding the instrument back to RSI 50.
- Source reports the TWTR example improved total return versus buy-and-hold with lower volatility and shorter drawdowns.

## Parameters To Test
- `rsi_period`: 10, 14, 21
- `long_level`: 20, 30, 35
- `short_level`: 65, 70, 80
- `centerline`: 45, 50, 55
- `shorts_enabled`: false, true
- `atr_stop_mult`: 2.5, 3.0, 4.0

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa RSI tutorial.

## Verwandte Strategien
- [[strategies/QM5_10142_rsi2-sma]] - shorter RSI(2) pullback with SMA trend filter.
- [[strategies/QM5_10143_rsi-momentum]] - uses RSI as momentum, not reversion.

## Lessons Learned
- TBD
