---
ea_id: QM5_10493
slug: mql5-sidus
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Mikhail idea, Vladimir Karputov (barabashkakvn) code, Sidus, MQL5 CodeBase, published 2018-08-23, updated 2018-08-27, https://www.mql5.com/en/code/21629"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/alligator-trend]]"
  - "[[concepts/rsi-filter]]"
indicators: [Alligator, RSI]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M15
expected_trade_frequency: "Alligator line-slope trend with RSI 50-cross filter on M15; conservative estimate 60-140 trades/year/symbol after one-position gating."
expected_trades_per_year_per_symbol: 90
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL present; R2 mechanical RSI 50-cross plus Alligator delta entries and bounded exits with ~90 trades/year/symbol; R3 portable to DWX OHLC symbols; R4 fixed non-ML one-position rules."
---

# MQL5 Sidus Alligator RSI Trend Filter

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Mikhail idea, Vladimir Karputov (barabashkakvn) code, "Sidus", MQL5 CodeBase, published 2018-08-23, updated 2018-08-27, URL https://www.mql5.com/en/code/21629.
- Source location: page states the EA uses Alligator as the main indicator and RSI as a trend filter. RSI crossing 50 permits buy/sell checks; Alligator Jaw/Teeth/Lips bar-to-bar deltas define buy/sell signals. The EA checks signals only on new bars.

## Mechanik

### Entry
- Evaluate only when a new bar appears.
- Compute RSI and Alligator Jaw, Teeth, and Lips.
- Long:
  - RSI[2] < 50 and RSI[1] > 50.
  - Jaw[1] - Jaw[2] > `delta`.
  - Teeth[1] - Teeth[2] > `delta`.
  - Lips[1] - Lips[2] > `delta`.
  - No active position for this symbol/magic.
- Short:
  - RSI[2] > 50 and RSI[1] < 50.
  - Jaw[1] - Jaw[2] < -`delta`.
  - Teeth[1] - Teeth[2] < -`delta`.
  - Lips[1] - Lips[2] < -`delta`.
  - No active position for this symbol/magic.
- Baseline `delta` = 0 after symbol-point normalization; P3 sweeps a minimum delta floor.

### Exit
- Source stop is dynamic: long stop at Low[1] - Offset, short stop at High[1] + Offset.
- V5 baseline maps Offset to 0.5 * ATR(14) with a minimum broker stop distance.
- TP baseline = 2.0R.
- Close on opposite confirmed Sidus signal.
- Source trailing is disabled for P2 and can be swept later as fixed trailing.

### Stop Loss
- Recent-bar structural stop with ATR offset, normalized by symbol tick size.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip high-impact news windows when QM news filter is active.
- Spread filter required because source example optimizes on M15.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, publish date, and update date. |
| R2 Mechanical | PASS | Source gives explicit RSI 50-cross and Alligator delta rules for long and short entries. |
| R3 DWX-testbar | PASS | Alligator and RSI are deterministic OHLC-derived indicators portable to DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed indicator rules, no ML, no grid/martingale; V5 enforces one-position gating. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10488_mql5-ccirsi]] - oscillator confirmation family.
- [[strategies/QM5_10467_mql5-sar]] - indicator-trend family.

## Lessons Learned
- TBD during pipeline run.
