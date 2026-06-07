---
ea_id: QM5_11094
slug: bbs-adv-zero
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, Bollinger Squeeze Advanced, GitHub repository and MQL5 source, https://github.com/EarnForex/Bollinger-Squeeze-Advanced"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/volatility-compression]]"
  - "[[concepts/momentum-zero-cross]]"
indicators: [Bollinger Bands, Keltner Channel, ATR, DeMarker]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "H1 oscillator zero crosses gated by BB/Keltner trend state should be moderate frequency; conservative estimate 35 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source links present; R2 mechanical BB/Keltner trending-state plus DeMarker zero-cross entries/exits with plausible >2 trades/year cadence; R3 OHLC indicator logic testable on DWX CFDs; R4 fixed rules no ML/grid/martingale."
---

# EarnForex Bollinger Squeeze Advanced Zero Cross

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "Bollinger Squeeze Advanced", GitHub, accessed 2026-05-22, URL https://github.com/EarnForex/Bollinger-Squeeze-Advanced.
- Author / institution: `EarnForex.com`.
- Source location: `Bollinger Squeeze Advanced.mq5`, histogram construction and `AlertOnZeroCross` / `AlertOnSidewaysTrending` logic; source article URL https://www.earnforex.com/indicators/Bollinger-Squeeze-Advanced/.
- Source claim: the README says the indicator shows trend strength/direction and alerts when BB/Keltner relationship changes and when the histogram crosses zero.

## Mechanik

### Entry
- Evaluate on completed H1 bars; P3 may test H4.
- Source defaults: `TriggerType=DeMarker`, `DeMarkerPeriod=13`, `TriggerCandle=Previous`.
- Compute `d = DeMarker(13) - 0.5`.
- Compute squeeze/trend state from source: `bbs = BB_Deviation * StdDev / (ATR * KeltnerFactor)`.
- Trending state is active when `bbs >= 1`.
- Long signal: trending state is active and histogram `d` crosses from `<= 0` to `> 0`.
- Short signal: trending state is active and histogram `d` crosses from `>= 0` to `< 0`.

### Exit
- Close long when `d` crosses back below zero or trending state ends.
- Close short when `d` crosses back above zero or trending state ends.
- Catastrophic time stop: 24 H1 bars.

### Stop Loss
- Source is an indicator, not an EA, so no native SL.
- P2 baseline: ATR(14) catastrophic stop at 2.0 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Use completed candles only.
- News blackout deferred to P8.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | The source gives fixed histogram, trend-state, and zero-cross alert logic. |
| R3 DWX-testbar | PASS | Uses OHLC-derived Bollinger Bands, ATR, standard deviation, and DeMarker on DWX symbols. |
| R4 No ML | PASS | Fixed indicators and thresholds; no ML, adaptive parameters, martingale, or grid. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_11080_bb-macd-flip]] - EarnForex momentum histogram conversion.

## Lessons Learned
- TBD during pipeline run.
