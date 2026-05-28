---
ea_id: QM5_10323
slug: payoff-bias
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
source_citation: "Guido Baltussen, Julian Terstegge, Paul Whelan, The Derivative Payoff Bias, SSRN abstract 4562800, 2023/2024, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4562800"
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/expiry-seasonality]]"
  - "[[concepts/intraday-reversal]]"
  - "[[concepts/market-microstructure]]"
indicators:
  - "[[indicators/third-friday-calendar]]"
  - "[[indicators/overnight-return]]"
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
period: M30
expected_trade_frequency: "Monthly AM-settled equity-index derivative expiry; conservative cadence 12 events/year/symbol before filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 SSRN paper URL and attribution; R2 deterministic monthly third-Friday entry/exit with ATR stops, about 12 trades/year/symbol; R3 testable on SP500.DWX backtest plus NDX/WS30 caveat; R4 fixed-rule no ML/grid/martingale."
---

# Derivative Payoff Bias Expiry Drift

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4562800
- Paper: Guido Baltussen, Julian Terstegge, Paul Whelan, "The Derivative Payoff Bias", SSRN, 2023/2024.
- Source location: SSRN abstract. The abstract states that AM-settled U.S. equity index derivatives expire on the third Friday using constituent opening prices, that equity prices drift upward from Thursday close to third-Friday open, and then revert at payoff calculation.

## Mechanik

### Entry
- Evaluate only on the third Friday of each month.
- Primary long leg: if current date is the Thursday before AM-settled third-Friday expiry, enter long on `SP500.DWX` or `NDX.DWX` at the final liquid M30 bar before the U.S. cash close.
- Require the prior 20 trading days' realized volatility to be above a minimum floor so the expected expiry-window move is not dominated by spread.
- Optional reversal leg for P3 ablation: after the Friday cash-open settlement window, enter short if the overnight move from Thursday close to Friday open is positive and exceeds `0.25 * ATR(14,M30)`.

### Exit
- Long leg exits at the first liquid M30 close after the Friday U.S. cash-open settlement window.
- Reversal leg exits after 3 M30 bars or when price retraces 50% of the Thursday-close-to-Friday-open move.
- Friday close flatten remains enforced.

### Stop Loss
- Long leg stop: `0.75 * ATR(14,M30)` below entry.
- Reversal leg stop: `0.75 * ATR(14,M30)` above entry.
- No averaging, no grid, one position per symbol/magic.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live risk deferred to V5 defaults after pipeline validation.

### Zusaetzliche Filter
- Trade only monthly third-Friday AM-settlement window.
- Skip months with broker holiday / missing session bars.
- Skip if spread exceeds rolling 80th percentile on M30.

## Concepts
- [[concepts/expiry-seasonality]] - primary
- [[concepts/intraday-reversal]] - secondary
- [[concepts/market-microstructure]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | SSRN URL plus named authors and institutional affiliations. |
| R2 Mechanical | PASS | Calendar event, entry window, exit window, and ATR stops are deterministic. |
| R3 DWX-testbar | PASS | Index-CFD port is testable on `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`. |
| R4 No ML | PASS | Fixed calendar and price rules; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- "Equity prices drift up from Thursday close to 3rd Friday open" (SSRN abstract).
- "revert at the point derivative payoffs are calculated" (SSRN abstract).

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10317_interday-last-halfhour-momentum]] - equity intraday timing family; this card is monthly derivative-expiry calendar pressure.
- [[strategies/QM5_10324_overnight-drift]] - overnight equity-index timing family; this card is third-Friday specific.

## Lessons Learned
- TBD during pipeline run.

