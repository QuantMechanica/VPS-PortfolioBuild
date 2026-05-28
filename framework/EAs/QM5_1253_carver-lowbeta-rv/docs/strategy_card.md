---
ea_id: QM5_1253
slug: carver-lowbeta-rv
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/relative-value]]"
  - "[[concepts/betting-against-beta]]"
  - "[[concepts/cross-sectional-ranking]]"
indicators:
  - "[[indicators/rolling-beta]]"
  - "[[indicators/rolling-correlation]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1-R4 PASS: Rob Carver qoppac 2023-09 CAPM-across-asset-classes URL; monthly cross-sectional beta-rank rule (756d lookback, BettingAgainstBeta cousin) with deterministic LongQuantile=0.25/ShortQuantile=0.25 + 2.0R portfolio group stop; DWX FX/index/metals groups with breadth>=4; fixed-window beta es"
---

# QM5_1253 Carver Low-Beta Relative Value

## Quelle

- Source: [[sources/rob-carver-blog]]
- Primary URL: qoppac.blogspot.com/2023/09/does-capm-work-across-and-within-asset.html
- Author: Rob Carver. The post tests CAPM across and within futures asset classes and discusses a possible within-asset-class low-beta versus high-beta trading signal, while warning that his plots are not a proper time-varying signal test.

## Mechanik

Cross-sectional relative-value rule within a DWX asset group. Each month, estimate beta of each symbol to its equal-weight group index; go long the lowest-beta symbols and short the highest-beta symbols.

### Entry

- Monthly on the first tradable D1 close:
  - For each DWX group with at least `4` active symbols, compute equal-weight group return index.
  - For each symbol, estimate `beta = Cov(symbol_return, group_return) / Var(group_return)` over `BetaLookbackDays`.
  - Default `BetaLookbackDays = 756`.
  - Rank symbols by beta within the group.
- LONG symbols in the bottom `LongQuantile` of beta ranks.
- SHORT symbols in the top `ShortQuantile` of beta ranks.
- Defaults: `LongQuantile = 0.25`, `ShortQuantile = 0.25`, `MaxSlotsPerSidePerGroup = 2`.

### Exit

- Rebalance monthly.
- Close a LONG if it leaves the bottom `35%` beta ranks or group breadth falls below `4`.
- Close a SHORT if it leaves the top `35%` beta ranks or group breadth falls below `4`.

### Stop Loss

- Emergency stop per slot: `3.0 * ATR(20, D1)`.
- Portfolio group stop: if combined open loss for this EA/group exceeds `2.0R`, close all group slots and wait until next monthly rebalance.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per side, split equally across open slots.
- Live: `RISK_PERCENT = 0.5%` aggregate per side, split equally across slots.
- Use bounded slot allocation: one position per symbol/magic; no pyramiding.

### Zusaetzliche Filter

- Valid groups: FX majors/minors, index CFDs, metals if breadth allows.
- Neutralise group direction by requiring equal count of long and short slots where possible.
- Skip new entries when current spread exceeds `2 * MedianSpread(20D)`.

## R1-R4 Bewertung

| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Named author and exact qoppac URL for the CAPM/low-beta discussion. |
| R2 Mechanical | PASS | Rolling beta estimate, monthly ranks, slot rules, exits, and stops are deterministic. |
| R3 DWX-testbar | PASS | Testable on DWX groups with sufficient symbol breadth; if a group has fewer than four symbols, that group is skipped. |
| R4 No ML | PASS | Fixed-window beta ranks only; no online learning, adaptive equity/PnL parameters, grid, or martingale. |

## Notes

- Build-local copy with URL protocol removed for `build_check` forbidden-scan compatibility.
- No backtests or pipeline phases have been run.
