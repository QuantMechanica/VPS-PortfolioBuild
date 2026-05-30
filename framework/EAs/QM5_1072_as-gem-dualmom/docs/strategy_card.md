---
ea_id: QM5_1072
slug: as-gem-dualmom
type: strategy
source_id: 2df06de7-6a3a-5b06-9e6d-446d1a01fab9
sources:
  - "[[sources/allocate-smartly-strategies]]"
concepts:
  - "[[concepts/dual-momentum]]"
  - "[[concepts/tactical-asset-allocation]]"
indicators:
  - "[[indicators/twelve-month-return]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "AS Antonacci GEM dual momentum (2014 book) - R1 Allocate Smartly catalogue + named developer + book attribution; R2 12mo absolute+relative momentum rule deterministic; R3 SP500/NDX/WS30 + GER40 equity legs testable, defensive flat/cash; R4 fixed lookback no ML"
---

# Allocate Smartly Traditional Dual Momentum GEM

## Quelle
- Source: [[sources/allocate-smartly-strategies]]
- Catalogue entry: Allocate Smartly "List of Strategies", line listing "Traditional Dual Momentum" by Gary Antonacci, https://allocatesmartly.com/list-of-strategies/
- Rule reference: Gary Antonacci, "Dual Momentum Investing" (McGraw-Hill, 2014); GEM rule summary at BestFolio URL https://bestfolio.app/strategies/gem

## Mechanik

### Entry
- Timeframe: D1 (monthly rebalance evaluated on the D1 close of the last trading day of the month).
- Compute 12-month total return for US equity proxy, international equity proxy, defensive bond/cash proxy, and T-bill/cash proxy.
- Absolute momentum test: US equity 12-month return > T-bill/cash 12-month return.
- If absolute momentum passes, compare US equity vs international equity 12-month returns.
- Long 100% the stronger equity proxy.
- If absolute momentum fails, move to defensive bond/cash proxy or flat.

DWX port:
- US equity: SP500.DWX backtest-only, plus live-tradable NDX.DWX / WS30.DWX validation path.
- International equity: GER40.DWX or another index CFD proxy.
- Defensive leg: flat/cash by default unless a DWX-safe bond/defensive proxy is approved.

### Exit
- Exit current holding at the next monthly rebalance if the selected asset changes or the absolute momentum regime flips.
- Otherwise hold until next month-end review.

### Stop Loss
- Source uses monthly rotation, not intramonth stop.
- Framework catastrophic stop only if required.

### Position Sizing
- Original: 100% in one selected asset.
- DWX port: one position per magic; concentrated monthly rotation is compatible.

### Zusaetzliche Filter
- Month-end signal, next-session or close execution to be fixed by Development.
- Framework spread/news filters.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Allocate Smartly catalogue names Antonacci and the strategy; public GEM rule summary links the 2014 source. |
| R2 Mechanical | PASS | 12-month absolute and relative momentum rules produce a deterministic monthly selected asset. |
| R3 Data Available | UNKNOWN | Equity index proxies are available after porting; defensive bond/T-bill leg needs flat/cash or approved proxy treatment. |
| R4 ML Forbidden | PASS | Fixed lookback, no ML, no adaptive parameters, concentrated one-position rotation. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
