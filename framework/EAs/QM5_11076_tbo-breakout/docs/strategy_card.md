---
ea_id: QM5_11076
slug: tbo-breakout
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, TradeBreakOut, GitHub repository and MQL5 source, https://github.com/EarnForex/TradeBreakOut"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/range-breakout]]"
  - "[[concepts/momentum]]"
indicators: [TradeBreakOut]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "Breaks of a 50-bar high/low range on H1 should be frequent but filtered by opposite exits; conservative estimate 60-100 trades/year/symbol."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source links present; R2 H1 50-bar breakout entries/exits mechanical with plausible 60-100 trades/year/symbol; R3 DWX OHLC symbols testable; R4 fixed rules no ML/grid/martingale."
---

# EarnForex TradeBreakOut Range Breakout

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "TradeBreakOut", GitHub, accessed 2026-05-22, URL https://github.com/EarnForex/TradeBreakOut.
- Author / institution: `EarnForex.com`.
- Source location: `TradeBreakOut.mq5` indicator buffers and alert/signal logic; source article URL https://www.earnforex.com/indicators/TradeBreakOut/.
- Source claim: a resistance breakout signal occurs when the green line crosses zero from below.

## Mechanik

### Entry
- Compute TradeBreakOut on closed bars with default `L=50`, `PriceType=PriceHighLow`, current timeframe.
- The resistance breakout buffer is `(current_high - highest_high_over_previous_L_bars) / highest_high`.
- The support breakout buffer is `(current_low - lowest_low_over_previous_L_bars) / lowest_low`.
- Long signal:
  - Resistance breakout buffer crosses above zero from a value at or below zero.
- Short signal:
  - Support breakout buffer crosses below zero from a value at or above zero.

### Exit
- Close long when the support breakout buffer crosses below zero.
- Close short when the resistance breakout buffer crosses above zero.
- Add V5 catastrophic ATR stop for bounded testing because the indicator is signal-only.

### Stop Loss
- V5 P2 baseline: `ATR(14) * 2.5` hard stop.
- Optional P3 target: `2R` fixed take-profit versus opposite-signal-only exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade on closed H1 bars only.
- One active position per symbol/magic.
- News blackout deferred to P8.
- Friday flatten per V5 symbol policy.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | Breakout buffers and zero-cross alert rules are explicit; exit/stop gaps are filled with deterministic V5 defaults. |
| R3 DWX-testbar | PASS | Highest-high/lowest-low range breakout logic is available on all DWX OHLC symbols. |
| R4 No ML | PASS | Fixed lookback and no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- TBD.

## Lessons Learned
- TBD during pipeline run.
