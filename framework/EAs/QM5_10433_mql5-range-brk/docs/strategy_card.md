---
ea_id: QM5_10433
slug: mql5-range-brk
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Osmar Sandoval Espinosa, Easy Range Breakout EA - MT5, MQL5 CodeBase, 2026-04-21, https://www.mql5.com/en/code/68764"
sources:
  - "[[sources/mql5-codebase-mt5]]"
concepts:
  - "[[concepts/session-range-breakout]]"
  - "[[concepts/fixed-risk-reward]]"
indicators: []
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX]
period: M5
expected_trade_frequency: "One post-range breakout per configured daily session; conservative estimate 80-160 trades/year/symbol after no-break and one-position filters."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 linked MQL5 CodeBase source; R2 mechanical session range breakout with explicit SL/TP/time exit and ~120 trades/year/symbol; R3 DWX FX/metal/index testable; R4 fixed non-ML one-position rule."
---

# MQL5 Easy Range Breakout EA

## Quelle
- Source: [[sources/mql5-codebase-mt5]]
- Citation: Osmar Sandoval Espinosa, "Easy Range Breakout EA - MT5", MQL5 CodeBase, published 2026-04-21, URL https://www.mql5.com/en/code/68764.
- Author / handle: `Osmar Sandoval Espinosa`.
- Source location: CodeBase description states the EA calculates a user-defined start/end range, records minute-based highs/lows, and after the range closes enters on breakout with TP equal to range size and stop at the opposite boundary.

## Mechanik

### Entry
- Configure a daily range window, default V5 port: 08:00-09:00 broker time.
- During the range window, compute `RangeHigh` and `RangeLow` from M1 bars.
- After range end, evaluate the latest completed candle.
- Long:
  - No active position for this symbol/magic.
  - Completed candle close is above `RangeHigh`.
  - Enter long at market on the next tick/bar open.
- Short:
  - No active position for this symbol/magic.
  - Completed candle close is below `RangeLow`.
  - Enter short at market on the next tick/bar open.
- Only the first breakout per configured session is traded.

### Exit
- Long TP = entry price + (`RangeHigh - RangeLow`).
- Short TP = entry price - (`RangeHigh - RangeLow`).
- Time stop: close any remaining position at configured session close, default 22:00 broker time.

### Stop Loss
- Long SL = `RangeLow`.
- Short SL = `RangeHigh`.
- Skip if range width is below 0.25 x ATR(14,M5) or above 3.0 x ATR(14,M5).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip if spread > 10% of range width.
- Default P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.

## Concepts
- [[concepts/session-range-breakout]] - primary
- [[concepts/fixed-risk-reward]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL plus named author and publish date. |
| R2 Mechanical | PASS | Range construction, breakout entry, opposite-boundary stop, and range-size TP are explicit. |
| R3 DWX-testbar | PASS | Uses OHLC range and breakout logic portable to DWX FX, metal, and index CFDs. |
| R4 No ML | PASS | Fixed range breakout, one-position interpretation, no ML/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9357_mql5-orb-break]] - related MQL5 opening-range article card; this card preserves the CodeBase EA's range-size target and opposite-boundary stop.
- [[strategies/QM5_9936_ff-range-breakout-gmt3-h1]] - related ForexFactory range breakout with different source window/management.

## Lessons Learned
- TBD during pipeline run.
