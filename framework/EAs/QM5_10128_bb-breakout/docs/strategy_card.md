---
ea_id: QM5_10128
slug: bb-breakout
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/bollinger-bands]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 20
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL; R2 mechanical BB breakout entry/exit with ~20 trades/year/symbol; R3 portable to DWX CFDs incl SP500 backtest caveat; R4 fixed rules no ML/martingale."
---

# Bollinger Band One-Sigma Breakout

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/4-simple-strategies-to-trade-bollinger-bands/
- Author / institution: Raposa
- Date: 2021-07-21
- Location: section "Trading Bollinger Band Breakouts" and `BBBreakout`

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute TP = (high + low + close) / 3.
- Compute SMA(TP, 20), rolling standard deviation of TP over 20 bars, upper band = SMA(TP) + 1 * STD, lower band = SMA(TP) - 1 * STD.
- Enter long when close > upper band.
- Enter short when close < lower band.

### Exit
- Exit long when close is no longer above the upper band, i.e. close <= upper band.
- Exit short when close is no longer below the lower band, i.e. close >= lower band.

### Stop Loss
- Source has no explicit stop. Development should apply V5 default emergency stop for backtest safety.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter
- Warmup: 20 D1 bars.
- Optional P3 variant: double-band exit from the same article, entering on 1-sigma breakout and exiting on either re-entry into the inner band or overshoot beyond 2-sigma outer band.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/volatility-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL with author/institution and date. |
| R2 Mechanical | PASS | Band calculation, directional entries, and band re-entry exits are explicit. |
| R3 Data Available | PASS | Equity example ports to DWX indices, FX, XAUUSD, and oil CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no martingale. |

## R3
SP500.DWX is valid for backtest-only S&P analog testing. Live promotion T6 gate requires NDX.DWX or WS30.DWX parallel validation if SP500.DWX is the only passing instrument.

## Author Claims
- Source says the breakout example "blows away the baseline".
- Source also warns the example had a large drawdown after a strong spike.

## Parameters To Test
- Period: 10, 20, 30.
- Entry sigma: 0.75, 1.0, 1.5.
- Exit: re-enter band vs middle-band cross vs 2-sigma overshoot double-band exit.
- Long-only vs symmetric long/short.

## Initial Risk Profile
Fast trend/volatility breakout with high whipsaw risk and source-observed drawdown. Needs transaction-cost and spread sensitivity checks.

## Pipeline-Verlauf
- G0: PENDING.

