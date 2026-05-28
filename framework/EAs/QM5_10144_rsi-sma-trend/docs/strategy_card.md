---
ea_id: QM5_10144
slug: rsi-sma-trend
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
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
expected_trades_per_year_per_symbol: 18
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa source URL/mirror; R2 deterministic RSI plus SMA agreement entries/exits with ~18 trades/year/symbol; R3 close-only rule portable to DWX incl SP500.DWX caveat; R4 fixed rules no ML/grid/martingale."
---

# RSI Plus Short-Term SMA Trend Agreement

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/4-simple-rsi-trading-strategies-you-can-use-today/
- Accessible mirror used for rule extraction: https://readmedium.com/4-simple-rsi-trading-strategies-db7b9790c690
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Jun. 24, 2021
- Page / Timestamp: "RSI and Short-Term Trend"

## Mechanik

### Entry
- Compute Wilder RSI on completed D1 closes, default `P = 14`.
- Compute `SMA(5)` and `SMA(20)`.
- Enter long at next bar if `RSI > 50` and `SMA(5) > SMA(20)`.
- Enter short at next bar if short mode is enabled, `RSI < 50`, and `SMA(5) < SMA(20)`.

### Exit
- Exit long when either condition is no longer true: `RSI <= 50` or `SMA(5) <= SMA(20)`.
- Exit short when either short condition is no longer true: `RSI >= 50` or `SMA(5) >= SMA(20)`.

### Stop Loss
- Source does not define a hard stop.
- Research default: emergency stop at `3 * ATR(14)` from entry.

### Position Sizing
- Source code tracks full-position returns and does not define lots.
- Use V5 fixed-risk P2 baseline and standard live risk conventions if approved.

### Zusaetzliche Filter
- D1 timeframe.
- Use closed bars only; execute on next bar open.
- Source mirror code appears to contain a typo in the short condition; this card follows the prose rule: short when RSI momentum and SMA trend agree downward.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa URL/mirror with named author handle and date. |
| R2 Mechanical | PASS | RSI centerline plus SMA cross state provide explicit entry and exit rules. |
| R3 Data Available | PASS | Close-only rule portable to DWX symbols; no stock-specific data required. |
| R4 ML Forbidden | PASS | Fixed lookbacks and thresholds; no ML/adaptive/grid/martingale. |

## R3
Raposa example used TWTR, but the rule can be run on any close series. Port to SP500.DWX, NDX.DWX, WS30.DWX, FX, metals, and oil CFDs. If SP500.DWX is used: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source frames this as requiring two signals to agree before entering; when one signal drops, the system exits.
- Source reports the TWTR sample produced about 112 percent return, while warning that a long drawdown after 2017 gives reason for pause.

## Parameters To Test
- `rsi_period`: 10, 14, 21, 28
- `fast_sma`: 5, 8, 10
- `slow_sma`: 20, 30, 50
- `centerline`: 50
- `shorts_enabled`: false, true
- `atr_stop_mult`: 2.5, 3.0, 4.0

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa RSI tutorial.

## Verwandte Strategien
- [[strategies/QM5_10143_rsi-momentum]] - RSI-only momentum without SMA agreement.
- [[strategies/QM5_1239_raposa-ma-atr]] - moving-average trend sibling from same source family.

## Lessons Learned
- TBD
