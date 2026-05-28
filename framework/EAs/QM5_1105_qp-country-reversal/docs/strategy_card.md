---
ea_id: QM5_1105
slug: qp-country-reversal
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/long-term-reversal]]"
  - "[[concepts/equity-index-long-short]]"
indicators:
  - "[[indicators/thirty-six-month-return-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia Richards 1997 JF country-index 36mo reversal R1-R4 PASS: R1 verifiable Quantpedia URL + named JF 1997 paper + Balvers/Wu 2000 supporting; R2 deterministic 756-bar return rank + 36-month rebalance + 4xATR safety stop; R3 5 DWX indices (NDX/WS30/GDAXI/UK100/SP500) enable bottom-2/top-2 long"
---

# Quantpedia Country Index 36 Month Reversal

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Reversal Effect in International Equity ETFs"
- URL: https://quantpedia.com/strategies/mean-reversion-effect-in-country-equity-indexes
- Named source author: Richards, "Winner-Loser Reversals in National Stock Market Indices: Can They be Explained?", Journal of Finance 1997, URL: https://doi.org/10.1111/j.1540-6261.1997.tb02738.x; Quantpedia also cites Balvers/Wu 2000 and related long-term mean-reversion papers.

## Mechanik

### Entry
At each three-year rebalance date:
1. Universe: Darwinex broad equity-index CFDs with sufficient D1 history, candidate set `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `UK100.DWX`, `JPN225.DWX`, `AUS200.DWX`, plus `SP500.DWX` for backtest-only research if needed.
2. For each index, compute total return over the prior 756 D1 bars.
3. Rank indexes ascending by 36-month return.
4. Open LONG positions in the bottom 25% or bottom 2 indexes with the worst 36-month return.
5. Open SHORT positions in the top 25% or top 2 indexes with the best 36-month return.

### Exit
- Close and rebalance at the next three-year rebalance date.
- Safety exit: close any leg if price crosses a 4.0x ATR(20) adverse stop.
- Operational exit: close all legs if a symbol loses valid trading status.

### Stop Loss
- ATR(20) hard stop at 4.0x D1 ATR from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per slot.

### Zusaetzliche Filter
- Rebalance every 36 months from the configured anchor month.
- Require at least 800 D1 bars before an index is rank-eligible.
- Optional P3 sweep: rebalance cadence 24/30/36 months and bucket size 1/2 symbols.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/long-term-reversal]] - primary
- [[concepts/equity-index-long-short]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Richards plus supporting long-term-reversal literature. |
| R2 Mechanical | UNKNOWN | 36-month return rank, fixed long/short buckets, and scheduled rebalance are deterministic. |
| R3 Data Available | UNKNOWN | Original ETF/country-index universe ports to DWX broad index CFDs; symbol breadth needs confirmation. |
| R4 ML Forbidden | UNKNOWN | Fixed rank/hold rule, no ML, no online learning, no grid/martingale. |

## R3 - T6 Live-Promotion-Caveat
If SP500.DWX is an active traded leg and the EA passes P0-P9 on SP500.DWX only, T6 deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. If SP500.DWX is omitted and only live-routable index CFDs are traded, this caveat is N/A.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1059_jegadeesh-stm-reversal-indices]] - related reversal family, but 1059 is short-term weekly reversal and this card is 36-month country-index reversal.
- [[strategies/QM5_1104_qp-country-bab]] - same country-index CFD port, different ranking signal.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
