---
ea_id: QM5_1196
slug: qp-fx-meanrev-linear
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/fx-mean-reversion]]"
  - "[[concepts/currency-factor]]"
indicators:
  - "[[indicators/currency-basket-average]]"
  - "[[indicators/monthly-rebalance]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL/author cited; R2 PASS monthly basket mean-reversion entries/exits mechanical; R3 PASS DWX FX majors testable after spot-FX port; R4 PASS fixed-rule non-ML linear sizing with bounded one-slot leg allocation."
---

# Quantpedia FX Linear Mean Reversion

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "How to Build Mean Reversion Strategies in Currencies"
- URL: quantpedia.com/how-to-build-mean-reversion-strategies-in-currencies/
- Citation year: 2024 URL quantpedia.com/how-to-build-mean-reversion-strategies-in-currencies/
- Named source author: Sona Beluska, Quant Analyst, Quantpedia.com.
- Location: Strategy analysis, "Linear position sizing", and "Linear vs Exponential Mean Reversion Trading Strategy".

## Mechanik

### Entry
Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX.

At each month-end:
1. Build a developed-currency basket from DWX FX pairs, default currencies: AUD, GBP, CAD, EUR, CHF, JPY versus USD where direct pairs exist.
2. Convert each instrument to a normalized USD-base currency cumulative-return series over the available history.
3. Compute the cross-sectional average cumulative-return series across all basket members.
4. For each currency whose normalized series is below the basket average, open or maintain a LONG exposure proportional to `abs(currency_value - basket_average)`.
5. For each currency whose normalized series is above the basket average, open or maintain a SHORT exposure proportional to `abs(currency_value - basket_average)`.
6. Normalize gross exposure to a fixed cap of 1.0x notional for P2 baseline.

### Exit
- Rebalance monthly: close or resize all legs at the next month-end signal.
- Exit a leg when its normalized cumulative-return series crosses the basket average.
- Safety exit: close stale legs if a monthly rebalance is missed by more than 5 trading days.

### Stop Loss
- Per-leg hard stop: 3.0x ATR(20) D1 from entry.
- Portfolio kill for this EA: flatten all legs if open basket drawdown exceeds 2.5x planned portfolio risk.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD total basket risk, split by normalized absolute deviation weights.
- Live: `RISK_PERCENT = 0.25` total basket risk.

### Zusaetzliche Filter
- Use the linear sizing variant only. Do not implement the source's exponential sizing variant in P1 because the article itself warns about uncontrolled leverage growth.
- Require at least 24 monthly observations before first signal.
- Use one position slot per traded leg/magic allocation; no pyramiding.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/fx-mean-reversion]] - primary
- [[concepts/currency-factor]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Full Quantpedia article URL and named Quantpedia author Sona Beluska are cited. |
| R2 Mechanical | UNKNOWN | Monthly basket average, above/below-average signals, linear weights, and rebalance exits are deterministic. |
| R3 Data Available | UNKNOWN | DWX FX majors provide a direct spot-FX route, but futures carry embedded in the source must be approximated by spot-pair returns or a local carry adjustment. |
| R4 ML Forbidden | UNKNOWN | Linear fixed-rule version avoids ML, adaptive optimization, exponential leverage growth, grid, and martingale. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1111_qp-fx-momentum-12m]] - same currency universe, opposite factor direction.
- [[strategies/QM5_1091_qp-fx-carry-rates]] - currency carry factor with external rate inputs.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
