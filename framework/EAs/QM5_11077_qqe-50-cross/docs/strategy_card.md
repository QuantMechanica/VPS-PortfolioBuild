---
ea_id: QM5_11077
slug: qqe-50-cross
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, QQE, GitHub repository and MQL5 source, https://github.com/EarnForex/QQE"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/oscillator-cross]]"
  - "[[concepts/momentum]]"
indicators: [QQE, RSI]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "QQE 50-level regime crosses on H4 should occur roughly monthly to several times per quarter; conservative estimate 35-60 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source links present; R2 QQE line and 50-level cross entries/exits mechanical with plausible H4 monthly-plus cadence >2 trades/year/symbol; R3 DWX OHLC symbols testable; R4 fixed rules no ML/grid/martingale."
---

# EarnForex QQE 50-Level Cross

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "QQE", GitHub, accessed 2026-05-22, URL https://github.com/EarnForex/QQE.
- Author / institution: `EarnForex.com`; source notes earlier QQE versions by Tim Hyder and Roman Ignatov.
- Source location: `QQE.mq5` descriptions, buffers, and alert/arrow logic; source article URL https://www.earnforex.com/metatrader-indicators/QQE/.
- Source claim: buy is when the blue line crosses level 50 from below after crossing the yellow line from below.

## Mechanik

### Entry
- Compute QQE on closed H4 bars with `RSI_Period=14` and `SF=5`.
- Maintain the QQE RSI MA line (`RsiMa`) and smoothed trailing line (`TrLevelSlow`).
- Long setup:
  - `RsiMa` crosses above `TrLevelSlow` from below.
  - After that setup, `RsiMa` crosses above `AlertLevel=50`.
- Short setup:
  - `RsiMa` crosses below `TrLevelSlow` from above.
  - After that setup, `RsiMa` crosses below 50.

### Exit
- Close long when `RsiMa` crosses below `TrLevelSlow` or crosses below 50.
- Close short when `RsiMa` crosses above `TrLevelSlow` or crosses above 50.
- Use closed-bar confirmation only.

### Stop Loss
- Indicator source does not define order stops.
- V5 P2 baseline: `ATR(14) * 2.5` hard stop and opposite-signal exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- News blackout deferred to P8.
- Friday flatten per V5 symbol policy.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | QQE lines, crossover, and 50-level signal are explicit in source code. |
| R3 DWX-testbar | PASS | RSI/EMA-derived QQE can be computed from DWX OHLC data. |
| R4 No ML | PASS | Fixed smoothing and threshold parameters; no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- TBD.

## Lessons Learned
- TBD during pipeline run.
