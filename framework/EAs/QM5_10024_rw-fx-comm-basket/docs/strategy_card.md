---
ea_id: QM5_10024
slug: rw-fx-comm-basket
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Robot Wealth, 'Index of Strategies' FX Commodity basket section, https://robotwealth.com/index-of-strategies/; Kris Longmore, 'Exploring mean reversion and cointegration with Zorro and R: part 1', https://robotwealth.com/exploring-mean-reversion-and-cointegration-with-zorro-and-r-part-1/; Kris Longmore, 'Exploring Mean Reversion and Cointegration: Part 2', https://robotwealth.com/exploring-mean-reversion-and-cointegration-part-2/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/fx-stat-arb]]"
  - "[[concepts/cointegration]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/johansen-cointegration]]"
  - "[[indicators/spread-zscore]]"
target_symbols: [AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, AUDNZD.DWX]
period: D1
expected_trade_frequency: "Daily spread evaluation with threshold entry/exit. Conservative estimate 35 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS Robot Wealth links; R2 PASS deterministic basket z-score entry/exit with 35 trades/year/symbol estimate; R3 PASS DWX FX basket testable; R4 PASS no ML/grid/martingale and one basket per magic."
---

# Robot Wealth FX Commodity Basket Stat Arb

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Robot Wealth, "Index of Strategies" (accessed 2026), FX Commodity basket section, https://robotwealth.com/index-of-strategies/
- Supporting public articles: Kris Longmore, "Exploring mean reversion and cointegration with Zorro and R: part 1", https://robotwealth.com/exploring-mean-reversion-and-cointegration-with-zorro-and-r-part-1/ and "Part 2", https://robotwealth.com/exploring-mean-reversion-and-cointegration-part-2/
- Source location: the index states the FX Commodity basket was covered in FX Bootcamp, with research code/Zorro scripts in the FX Pod and public posts exploring relationships between commodity currencies using statistical tools.
- Author / institution: Robot Wealth / Kris Longmore.

## Mechanik

### Entry
- Universe: commodity-linked FX instruments AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, and AUDNZD.DWX where available.
- Weekly or monthly research step: estimate cointegration hedge weights on the in-sample window only; freeze weights for live/backtest segment.
- On each D1 close, compute basket spread from frozen hedge weights.
- Compute rolling z-score of the spread using 60 D1 bars.
- If z-score > +2.0, short the rich side of the basket and long the cheap side according to hedge weights.
- If z-score < -2.0, long the rich-side inverse / short the cheap-side inverse according to hedge weights.
- One basket position per magic; no pyramiding.

### Exit
- Exit when spread z-score crosses back inside +/-0.50.
- Time stop: exit after 20 trading days if mean reversion has not occurred.
- Emergency exit if rolling ADF/Johansen validation fails on the last 252 bars.

### Stop Loss
- Basket-level catastrophic SL = 2.5 * rolling 60-day spread standard deviation from entry.
- Per-leg platform SL = 2.0 * ATR(14,D1) as execution guard.

### Position Sizing
- P2 baseline: allocate `RISK_FIXED = 1000` to basket-level spread risk.
- Convert hedge weights into per-leg lot sizes using current contract values.

### Zusaetzliche Filter
- Only trade if all legs have normal spread and fresh D1 bars.
- Skip during major commodity-currency central-bank rate decisions until P8 review.
- P3 sweep: z-entry 1.5, 2.0, 2.5; z-exit 0.0, 0.5, 1.0; lookback 40, 60, 90.

## Concepts
- [[concepts/fx-stat-arb]] - primary
- [[concepts/cointegration]] - secondary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Robot Wealth index and public Robot Wealth articles cite this FX commodity basket / commodity-currency relationship source family. |
| R2 Mechanical | UNKNOWN | Directional basket mean-reversion mechanics are implementable, but the public index does not expose the private FX Bootcamp script parameters. |
| R3 DWX-testbar | PASS | Commodity FX pairs are available or portable to DWX FX crosses. |
| R4 No ML | PASS | Fixed statistical tests and frozen parameters; no ML, grid, martingale, or adaptive live parameters. |

## R3
Primary P2 basket: AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, AUDNZD.DWX where symbol coverage permits. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10009_rw-fx-cointeg-bb]] - related cointegration idea; this card is the commodity-currency basket family from the strategy index.

## Lessons Learned
- TBD during pipeline run.
