---
ea_id: QM5_1110
slug: unger-crude-ma-crossover
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/session-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger crude oil SMA(30)/SMA(140) M15 crossover with ATR(14)*2.5 stop + 5-session cap + ATR(D1) liquidity filter: R1 article+book-ISBN, R2 fully mechanical, R3 XTIUSD.DWX present, R4 fixed parameters no ML"
---

# Unger Crude Oil MA Crossover - 30/140 Trend Following

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy crude-oil strategy article.
- Article: "Trading Strategies on Crude Oil: Two Trend Following Systems That Beat Volatility" - https://ungeracademy.com/blog/trading-strategies-on-crude-oil-two-trend-following-systems-that-beat-volatility
- Location: section "Strategy No. 1: Multiday Trend Following with Moving Average Crossovers".
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- The article describes a crude-oil 15-minute strategy using SMA(30) and SMA(140): long when the fast average crosses above the slow average, short when it crosses below, with a trading window and filters.

## Mechanik

Universe: XTIUSD.DWX primary. Execution timeframe M15.

### Entry
At every closed M15 bar inside the trading window:
1. Compute `FAST = SMA(Close, 30)`.
2. Compute `SLOW = SMA(Close, 140)`.
3. LONG if `FAST[1] > SLOW[1]` and `FAST[2] <= SLOW[2]`.
4. SHORT if `FAST[1] < SLOW[1]` and `FAST[2] >= SLOW[2]`.
5. First build allows reversal only after the current position is closed; no simultaneous long/short.

### Exit
- Close on opposite crossover.
- Close on stop loss or take profit.
- Time cap: close after 5 trading sessions if no opposite signal appears, to keep exposure bounded for V5.

### Stop Loss
- Hard stop `SL = 2.5 * ATR(14,M15)` from entry.
- Optional `TP = 4.0R`; default disabled because trend following should let winners run.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Source mentions proprietary filters and a trading window. First build uses a deterministic window excluding the least liquid first/last hour of the XTIUSD.DWX session.
- Volatility filter: trade only if `ATR(14,D1) / Close` is above its 120-day 30th percentile.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-crossover]] - primary
- [[concepts/energy]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy article URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | SMA(30)/SMA(140) cross entries, opposite-cross exit, ATR stop, time cap. |
| R3 Data Available | UNKNOWN | XTIUSD.DWX is listed in the DWX commodities matrix. |
| R4 ML Forbidden | UNKNOWN | Fixed moving-average/ATR parameters, no ML/adaptive online tuning, one position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1096_unger-donchian-channel-tf]] - same broad trend-following family, channel trigger instead of moving-average crossover.
- [[strategies/QM5_1056_moskowitz-tsmom-multiasset]] - related commodity trend exposure with much slower time-series momentum cadence.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
