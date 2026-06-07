---
ea_id: QM5_11100
slug: csl-strength-cross
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, Currency Strength Lines, GitHub repository and MQL5 source, https://github.com/EarnForex/Currency-Strength-Lines"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/currency-strength]]"
  - "[[concepts/relative-momentum]]"
indicators: [Currency Strength Lines]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX]
period: H1
expected_trade_frequency: "H1 relative-strength crosses after smoothing should be moderate frequency; conservative estimate 45 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL present; R2 deterministic strength-cross entry and opposite/time exits with plausible 45 trades/year/symbol; R3 DWX FX series testable; R4 fixed non-ML one-position logic."
---

# EarnForex Currency Strength Cross

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "Currency Strength Lines", GitHub, accessed 2026-05-22, URL https://github.com/EarnForex/Currency-Strength-Lines.
- Author / institution: `EarnForex.com`.
- Source location: `MQL5/Indicators/MQLTA MT5 Currency Strength Lines.mq5`; input defaults and signal toggles around lines 83-107, strength buffers around lines 902-1117.
- Source claim: the README says the indicator calculates relative strength for up to eight major currencies and supports arrow signals.

## Mechanik

### Entry
- Evaluate on completed H1 bars; P3 may test H4.
- Source defaults: `CalculationMode=Mode_ASITot`, `ROCPeriod=5`, `RSIPeriod=14`, `SmoothingPeriod=5`, `Stochastic_K=5`, `Stochastic_D=3`, `Stochastic_Slowing=3`, `AboveBelow=true`, `OppositeZeros=false`.
- For each FX pair, compute source strength lines for base and quote currency.
- Long signal: base-currency strength crosses above quote-currency strength and both lines are valid on the completed bar.
- Short signal: base-currency strength crosses below quote-currency strength and both lines are valid on the completed bar.
- P3 axis: require `OppositeZeros=true` so long needs base above zero and quote below zero, with symmetric short rule.

### Exit
- Close on opposite strength cross.
- Close after 24 H1 bars if no opposite cross appears.

### Stop Loss
- Source is an indicator, not an EA, so no native SL.
- P2 baseline: `2.5 * ATR(14)` hard stop from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Require all dependent currency-pair series used by the source calculation to be synchronized on the signal bar.
- News blackout deferred to P8.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | Source exposes deterministic strength buffers and arrow-signal logic. |
| R3 DWX-testbar | PASS | Uses FX OHLC series available for DWX major pairs. |
| R4 No ML | PASS | Fixed relative-strength calculations; no ML, adaptive parameters, martingale, or grid. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_11089_trade-asst-conf]] - related multi-indicator panel conversion; this card isolates the currency-strength primitive.

## Lessons Learned
- TBD during pipeline run.
