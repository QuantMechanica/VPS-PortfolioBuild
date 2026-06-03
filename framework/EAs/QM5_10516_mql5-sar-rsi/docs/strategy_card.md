---
ea_id: QM5_10516
slug: mql5-sar-rsi
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Collector idea, Vladimir Karputov / barabashkakvn MQL5 code, SAR RSI MTS, MQL5 CodeBase, published 2018-03-01, https://www.mql5.com/en/code/19940"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/parabolic-sar]]"
  - "[[concepts/rsi]]"
indicators: [Parabolic SAR, RSI]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M30
expected_trade_frequency: "Parabolic SAR direction plus RSI 50-line confirmation on M30; conservative estimate is 60-180 trades/year/symbol."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/date; R2 PASS deterministic SAR+RSI entries and exits/stops with ~100 trades/year/symbol; R3 PASS portable to DWX FX/metals; R4 PASS no ML/grid/martingale, one-position gated."
---

# MQL5 SAR RSI Trend Confirmation

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Collector idea, Vladimir Karputov / barabashkakvn MQL5 code, "SAR RSI MTS", MQL5 CodeBase, published 2018-03-01, URL https://www.mql5.com/en/code/19940.
- Source location: page defines BUY when SAR on bar 1 is below close of bar 0, SAR on bar 1 is below SAR on bar 0, and RSI on bar 0 is above 50; SELL uses SAR above close, SAR rising above prior SAR, and RSI below 50.

## Mechanik

### Entry
- Evaluate on completed M30 bars.
- Long:
  - `SAR[1] < Close[0]`.
  - `SAR[1] < SAR[0]`.
  - `RSI[0] > 50`.
  - No active position for this symbol/magic.
- Short:
  - `SAR[1] > Close[0]`.
  - `SAR[1] > SAR[0]`.
  - `RSI[0] < 50`.
  - No active position for this symbol/magic.

### Exit
- Source exposes fixed SL, TP, trailing stop, and trailing step.
- P2 baseline: disable trailing; close on opposite signal, SL = source/swept fixed pip stop or 1.5 * ATR(14), TP = 1.5R.

### Stop Loss
- ATR-normalized hard stop for V5 baseline.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Parameter sweep: SAR step/max step, RSI period, ATR multiplier, TP R-multiple.
- Skip high-impact news windows when QM news filter is active.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | SAR side/slope conditions and RSI 50-line filter are deterministic. |
| R3 DWX-testbar | PASS | SAR/RSI OHLC indicator logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | Fixed indicator rules, no ML, no grid/martingale; V5 enforces one-position gating and fixed risk. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10508_mql5-sar-tm]] - SAR trend-change family.
- [[strategies/QM5_10505_mql5-macd-sar]] - SAR plus oscillator confirmation family.

## Lessons Learned
- TBD during pipeline run.
