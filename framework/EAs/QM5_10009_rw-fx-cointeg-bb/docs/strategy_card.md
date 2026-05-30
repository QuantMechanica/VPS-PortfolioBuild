---
ea_id: QM5_10009
slug: rw-fx-cointeg-bb
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Kris Longmore, Robot Wealth, 'Exploring Mean Reversion and Cointegration: Part 2', 2016-01-02, https://robotwealth.com/exploring-mean-reversion-and-cointegration-part-2/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/cointegration]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/bollinger-band]]"
indicators:
  - "[[indicators/johansen-test]]"
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/half-life]]"
target_symbols: [AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX]
period: D1
expected_trade_frequency: "Daily spread check; source example uses x=2 and y=1 on an AUD-NZD-CAD portfolio. Conservative estimate 20-40 round trips/year per anchor symbol."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL cited; R2 deterministic Johansen/Bollinger basket entry-exit with ~30 trades/year/symbol; R3 AUDUSD/NZDUSD/USDCAD DWX-testable; R4 fixed rules, no ML/martingale."
---

# Robot Wealth FX Cointegration Bollinger Bands

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Kris Longmore, "Exploring Mean Reversion and Cointegration: Part 2", Robot Wealth, 2016-01-02, https://robotwealth.com/exploring-mean-reversion-and-cointegration-part-2/
- Source location: sections "Johansen test", "Mean reversion of a portfolio of more than two instruments", and "A practical approach to linear mean reversion".
- Author claim: The post presents an AUD/USD, NZD/USD, USD/CAD portfolio, derives hedge ratios from Johansen eigenvectors, then describes a Bollinger approach where entry occurs beyond x standard deviations and exit occurs at y standard deviations. The example implementation uses x = 2 and y = 1.

## Mechanik

### Entry
- Build a daily synthetic spread from AUDUSD.DWX, NZDUSD.DWX, and inverted USDCAD.DWX so quote-currency direction is consistent.
- Monthly at the first tradable bar, estimate Johansen hedge ratios over the prior 500 D1 bars; freeze those ratios for the month.
- Compute rolling mean and rolling standard deviation of the spread using lookback = max(20, rounded half-life) with default cap 120 bars.
- Enter a spread-reversion basket when spread z-score >= +2.0: short positive spread weights and long negative spread weights.
- Enter the opposite basket when spread z-score <= -2.0.
- Enforce one basket position per magic; no pyramiding.

### Exit
- Close the basket when absolute spread z-score <= 1.0.
- Time stop after 3 * half-life bars, capped at 90 D1 bars.
- Emergency close if absolute z-score expands beyond 4.0 after entry.

### Stop Loss
- Basket stop at 1.5 * entry spread excursion beyond entry z-score, or fixed P2 risk stop equivalent if conversion to individual-symbol stops is required.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` distributed across legs by absolute hedge-ratio weights.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade only if the spread half-life is between 5 and 60 D1 bars.
- Skip if Johansen/CADF tests cannot form a stable finite hedge ratio.
- Skip entries during major AUD, NZD, CAD, or USD high-impact news windows.

## Concepts
- [[concepts/cointegration]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Robot Wealth URL, named author Kris Longmore, article title and date. |
| R2 Mechanical | PASS | Source gives hedge-ratio construction, Bollinger entry/exit framework, and example thresholds x=2/y=1; gaps are filled deterministically. |
| R3 DWX-testbar | PASS | AUDUSD, NZDUSD, and USDCAD are DWX FX instruments. |
| R4 No ML | PASS | Fixed statistical rules, frozen hedge-ratio schedule, no ML, grid, martingale, or online PnL adaptation. |

## R3
Primary P2 basket: AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10013_rw-fx-weekend-gap]] - related FX basket implementation from same source index.

## Lessons Learned
- TBD during pipeline run.

