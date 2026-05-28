---
ea_id: QM5_10142
slug: rsi2-sma
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: D1
expected_trades_per_year_per_symbol: 16
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS verifiable Raposa URL/mirror; R2 PASS RSI(2), SMA(200) entry and SMA(5) exit with ~16 trades/year/symbol; R3 PASS OHLC-close rules portable to DWX CFDs with SP500 T6 caveat; R4 PASS fixed non-ML one-position logic."
---

# RSI(2) Pullback With 200-SMA Trend Filter

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/4-simple-rsi-trading-strategies-you-can-use-today/
- Accessible mirror used for rule extraction: https://readmedium.com/4-simple-rsi-trading-strategies-db7b9790c690
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Jun. 24, 2021
- Page / Timestamp: "RSI(2)"

## Mechanik

### Entry
- Compute Wilder `RSI(2)`, `SMA(200)`, and `SMA(5)` on completed D1 closes.
- Long entry at next bar if `Close > SMA(200)` and `RSI(2) < 10`.
- Short entry at next bar if short mode is enabled, `Close < SMA(200)`, and `RSI(2) > 90`.

### Exit
- Exit long when `Close > SMA(5)`.
- Exit short when `Close < SMA(5)`.

### Stop Loss
- Source does not define a hard stop.
- Research default: emergency stop at `3 * ATR(14)` from entry.

### Position Sizing
- Source code tracks full-position returns and does not define lots.
- Use V5 fixed-risk P2 baseline and standard live risk conventions if approved.

### Zusaetzliche Filter
- D1 timeframe.
- Use closed bars only; execute on next bar open.
- Default long-only on index CFDs; short-enabled variant can be swept.

## Concepts
- [[concepts/mean-reversion]] - primary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa URL/mirror and explicit Connors-style rule description. |
| R2 Mechanical | PASS | RSI(2), SMA(200) trend gate, and SMA(5) exit are fully deterministic. |
| R3 Data Available | PASS | OHLC-close strategy portable to DWX symbols; no equity-only feature required. |
| R4 ML Forbidden | PASS | Fixed thresholds and one-position logic; no ML/adaptive/grid/martingale. |

## R3
Raposa example used TWTR, but the rule needs only close prices. Port to SP500.DWX, NDX.DWX, WS30.DWX and liquid FX/commodity CFDs. If SP500.DWX is used: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source attributes RSI(2) to Larry Connors and frames it as a short-term mean-reversion strategy inside a 200-SMA trend.
- Source reports lower volatility and smaller/shorter drawdowns than buy-and-hold in the TWTR sample.

## Parameters To Test
- `rsi_period`: 2, 3
- `long_level`: 5, 10, 15
- `short_level`: 85, 90, 95
- `trend_sma`: 100, 200
- `exit_sma`: 3, 5, 8
- `shorts_enabled`: false, true
- `atr_stop_mult`: 2.5, 3.0, 4.0

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa RSI tutorial.

## Verwandte Strategien
- [[strategies/QM5_10141_rsi-meanrev]] - classic RSI(14) centerline mean reversion.
- [[strategies/QM5_1235_connors-rsi2]] - related Connors substrate from a different source.

## Lessons Learned
- TBD
