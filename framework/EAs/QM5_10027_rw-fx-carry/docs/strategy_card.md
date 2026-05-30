---
ea_id: QM5_10027
slug: rw-fx-carry
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Robot Wealth, 'Index of Strategies' FX Carry section, https://robotwealth.com/index-of-strategies/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/fx-carry]]"
  - "[[concepts/risk-premium]]"
indicators:
  - "[[indicators/broker-swap]]"
  - "[[indicators/momentum-filter]]"
target_symbols: [AUDJPY.DWX, NZDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCHF.DWX]
period: D1
expected_trade_frequency: "Weekly carry ranking and occasional rebalance. Conservative estimate 26 trades/year/symbol."
expected_trades_per_year_per_symbol: 26
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked Robot Wealth source; R2 weekly carry/momentum ranking with explicit exits and ~26 trades/year/symbol; R3 DWX FX pairs testable; R4 fixed rules no ML/grid/martingale."
---

# Robot Wealth FX Carry Basket

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: 2026 Robot Wealth, "Index of Strategies", FX Carry section URL: https://robotwealth.com/index-of-strategies/
- Source location: the index states the strategy was explored in FX Bootcamp, has research code/Zorro scripts in the FX Pod, has an Edge Database entry, and was retired at the start of 2022.
- Author / institution: Robot Wealth.

## Mechanik

### Entry
- Weekly after broker rollover, read current long/short swap rates and 60-day realized volatility for eligible FX pairs.
- For each pair, compute carry score = favorable daily swap in trade direction / 60-day realized volatility.
- Long a pair if long-swap score is in the top quartile and 60-day price momentum is positive.
- Short a pair if short-swap score is in the top quartile and 60-day price momentum is negative.
- Hold up to one position per symbol and magic; no pyramiding.

### Exit
- Exit when the pair drops out of the top half of carry scores.
- Exit if 60-day momentum flips against the carry direction.
- Exit on Friday before close if swap/rollover data are unavailable or abnormal.

### Stop Loss
- SL = 3.0 * ATR(14,D1).
- Portfolio guard: stop opening new positions if basket open risk exceeds V5 per-EA cap.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` per symbol.
- Optional P3 variant: inverse-volatility weighting across selected carry positions, capped at equal risk per leg.

### Zusaetzliche Filter
- Skip symbols with negative carry in both directions after broker costs.
- Skip if spread > 20% of ATR(14,D1).
- Treat the source-retired status as a research risk; pipeline data decides.

## Concepts
- [[concepts/fx-carry]] - primary
- [[concepts/risk-premium]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public Robot Wealth strategy index names FX Carry, its content path, and its retired status. |
| R2 Mechanical | UNKNOWN | Directional carry ranking is implementable, but exact private FX Bootcamp parameters are not public. |
| R3 DWX-testbar | PASS | FX pairs and broker swap data are available through MT5/DWX for backtest/live feasibility checks. |
| R4 No ML | PASS | Fixed carry/momentum ranking; no ML, grid, martingale, or adaptive live parameters. |

## R3
Primary P2 basket: AUDJPY.DWX, NZDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCHF.DWX where available. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10028_rw-risk-premia]] - both harvest risk premia, but this card is FX swap/carry specific.

## Lessons Learned
- TBD during pipeline run.
