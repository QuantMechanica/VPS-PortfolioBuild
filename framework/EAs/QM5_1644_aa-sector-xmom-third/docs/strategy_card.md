---
ea_id: QM5_1644
slug: aa-sector-xmom-third
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/sector-rotation]]"
indicators:
  - "[[indicators/rate-of-change]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; full Alpha Architect URL with named author Jack Vogel and publication date — one canonical source_id satisfies R1."
r2_mechanical: PASS
r2_reasoning: "Fixed 12_2 ROC ranking, top/bottom-third long/short selection with bounded slots, and monthly rebalance are fully mechanical rules."
r3_data_available: PASS
r3_reasoning: "Country/index proxy basket (NDX.DWX, WS30.DWX, GDAXI, FCHI, UK100, SPA35) provides ≥6 DWX instruments for top/bottom-third sector-momentum rotation."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed lookback and rank rule with bounded long/short slots; no ML, adaptive parameters, grid, or martingale."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS Alpha Architect URL; R2 PASS monthly mechanical top/bottom-third ROC_12_2 basket with plausible monthly rebalance cadence; R3 PASS DWX index proxy basket/SP500.DWX caveat; R4 PASS fixed rules no ML/grid/martingale."
expected_trades_per_year_per_symbol: 12
---

# Alpha Architect Sector Momentum Thirds

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Jack Vogel, PhD, "The World's Longest Multi-Asset Momentum Investing Backtest!", 2018-04-24, https://alphaarchitect.com/the-worlds-longest-multi-asset-momentum-investing-backtest/

## Mechanik

The same Alpha Architect summary notes a sector-momentum extension: buy winning sectors and short losing sectors within each country. This draft isolates the sector/index rotation variant rather than the broader multi-asset version.

### Entry
- Evaluate on the final completed MN1 bar.
- Universe: approved sector or country-index proxy basket; if true sector CFDs are unavailable, use geographically diverse equity-index CFDs as a first proxy.
- For each instrument, compute `ROC_12_2 = Close(3) / Close(13) - 1`.
- Rank instruments descending by `ROC_12_2`.
- Go long the top third of instruments.
- Go short the bottom third of instruments.
- Equal-risk weight selected legs with max five long and five short slots.

### Exit
- Rebalance monthly.
- Close instruments no longer in the top or bottom third.
- Stay flat if fewer than six eligible instruments have sufficient history.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Time stop: next monthly rebalance.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000` per selected symbol, capped to configured long/short slots.
- T6-live: `RISK_PERCENT = 0.5` aggregate portfolio risk.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 14 completed monthly bars.
- Skip new entries when D1 spread exceeds 2.5 x 20-day median spread.

## Concepts (was ist das für eine Strategie)
- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/sector-rotation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Jack Vogel and publication date. |
| R2 Mechanical | PASS | Fixed 12_2 sector ranking, top/bottom third selection, and monthly rebalance. |
| R3 Data Available | UNKNOWN | True sector universe may not exist in DWX; country/index CFD proxy needs approval. |
| R4 ML Forbidden | PASS | Fixed lookback and rank rule with bounded slots; no ML, adaptive parameters, grid, or martingale. |

## R3
If no sector CFDs are available, test only as a country/index proxy strategy on DWX equity indices. SP500.DWX has the required backtest-only caveat.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 12 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1642_aa-xasset-xmom-third]] - related 12_2 top/bottom-third momentum.
- [[strategies/QM5_1640_aa-indmom-12-0]] - related industry/sector momentum.

## Lessons Learned (während Pipeline-Lauf)
- TBD
