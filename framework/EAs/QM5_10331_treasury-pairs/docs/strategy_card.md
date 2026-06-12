---
ea_id: QM5_10331
slug: treasury-pairs
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
source_citation: "Purnendu Nath, High Frequency Pairs Trading with U.S. Treasury Securities: Risks and Rewards for Hedge Funds, SSRN abstract 565441, 2003, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=565441"
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/spread-mean-reversion]]"
  - "[[concepts/extreme-risk-control]]"
indicators:
  - "[[indicators/zscore-spread]]"
  - "[[indicators/rolling-hedge-ratio]]"
  - "[[indicators/atr]]"
target_symbols: [GER40.DWX, FRA40.DWX, SP500.DWX, NDX.DWX, WS30.DWX]
period: M15
expected_trade_frequency: "Pairs spread entries on liquid correlated index-CFD pairs; conservative estimate 50-100 spread trades/year/pair, reported as 70 per primary symbol."
expected_trades_per_year_per_symbol: 70
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r1_reasoning: "Single source_id with SSRN URL and named author (Nath 2003)."
r2_reasoning: "Rolling hedge ratio, z-score entry/exit, bounded extreme-risk stop are deterministic; two-leg pairs logic fully specified."
r3_reasoning: "Pairs concept ports from Treasuries to correlated DWX index-CFD pairs (GER40/FRA40, NDX/WS30); both legs have valid DWX symbols."
r4_reasoning: "Fixed z-score rules, bounded stop, no ML, no martingale, no pyramiding."
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN paper URL/attribution; R2 PASS deterministic rolling hedge-ratio/z-score pairs entry, mean-reversion/time exit and 70 trades/year/pair; R3 PASS port-testable on correlated DWX index pairs with SP500 T6 caveat; R4 PASS fixed bounded two-leg spread rules no ML/grid/martingale."
---

# Treasury Pairs

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=565441
- Paper: Purnendu Nath, "High Frequency Pairs Trading with U.S. Treasury Securities: Risks and Rewards for Hedge Funds", SSRN, 2003.
- Source location: SSRN abstract. The abstract describes a simple pairs trading strategy with automatic extreme risk control in liquid U.S. Treasury securities.

## Mechanik

### Entry
- Source-native universe is liquid U.S. Treasury securities; DWX port uses highly correlated index-CFD pairs.
- For each approved pair, estimate a rolling hedge ratio over the prior 20 trading days on M15 closes.
- Compute spread `A - hedge_ratio * B` and its 20-day rolling z-score.
- If z-score is above `+2.0`, short spread: short A and long hedge-adjusted B.
- If z-score is below `-2.0`, long spread: long A and short hedge-adjusted B.
- Preferred first P2 pair: `GER40.DWX` versus `FRA40.DWX`; secondary: `SP500.DWX` versus `NDX.DWX`, and `SP500.DWX` versus `WS30.DWX`.

### Exit
- Exit when spread z-score crosses 0.
- Time stop after 16 M15 bars.
- Forced exit before weekend close.

### Stop Loss
- Extreme risk control: close both legs if spread z-score reaches `3.5` against entry or combined mark-to-market loss reaches `1.25 * planned risk`.
- Do not add to losers; no grid.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` per spread trade.
- Split risk across the two legs by hedge ratio so the synthetic spread has one bounded risk unit.

### Zusaetzliche Filter
- Trade only if 60-day pair correlation is above 0.75.
- Skip if either leg has spread above rolling 80th percentile.
- Skip if either leg has missing M15 bars in the hedge-ratio lookback.

## Concepts
- [[concepts/pairs-trading]] - primary
- [[concepts/spread-mean-reversion]] - primary
- [[concepts/extreme-risk-control]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | SSRN URL plus named author and London Business School affiliation. |
| R2 Mechanical | PASS | Rolling hedge ratio, z-score entry, mean-reversion exit, and bounded extreme-risk stop are deterministic. |
| R3 DWX-testbar | UNKNOWN | Source uses U.S. Treasuries; DWX port tests the same pairs-trading mechanics on correlated index CFDs. |
| R4 No ML | PASS | Fixed spread rules; no ML, online learning, martingale, or unbounded grid. |

## R3
Primary P2 pairs: `GER40.DWX/FRA40.DWX`, `SP500.DWX/NDX.DWX`, `SP500.DWX/WS30.DWX`. SP500.DWX caveat if used: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Author Claims
- "simple pairs trading strategy" (SSRN abstract).
- "automatic extreme risk control" (SSRN abstract).

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10320_index-leadlag]] - index-CFD relative-value cousin.

## Lessons Learned
- TBD during pipeline run.

