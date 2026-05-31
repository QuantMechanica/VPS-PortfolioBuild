---
ea_id: QM5_10543
slug: mql5-turbofx
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "e-TurboFx, RickD2 idea / Rick D. idea / Vladimir Karputov publication / barabashkakvn code, MQL5 CodeBase, published 2017-03-02, updated 2018-02-15, https://www.mql5.com/en/code/17289"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/candle-sequence-reversal]]"
  - "[[concepts/body-expansion]]"
indicators: [Candlestick]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "N consecutive expanding candle bodies should occur several times per month on H1; conservative estimate is 40-100 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title cited; R2 PASS deterministic expanding-candle reversal entry and ATR/TP/time/opposite exits with ~60 trades/year/symbol; R3 PASS OHLC candle logic testable on DWX forex/XAU; R4 PASS no ML/grid/martingale and one-position cap."
---

# MQL5 e-TurboFx Expanding Candle Reversal

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: RickD2 / Rick D. idea / Vladimir Karputov publication / barabashkakvn MQL5 code, "e-TurboFx", MQL5 CodeBase, published 2017-03-02, updated 2018-02-15, URL https://www.mql5.com/en/code/17289.
- Source location: page states the EA analyzes bars containing N consecutive bars of the same type. Example rule: N consecutive bullish bars with each body larger than the previous body gives a sell signal; N consecutive bearish bars with increasing bodies gives a buy signal.

## Mechanik

### Entry
- Evaluate only closed bars.
- Compute candle body size as `abs(close - open)` for each of the last `N` bars.
- Short when the last `N` closed candles are bullish and each candle body is greater than the previous candle body.
- Long when the last `N` closed candles are bearish and each candle body is greater than the previous candle body.
- No existing position for this symbol/magic.

### Exit
- P2 baseline uses ATR(14) hard stop and fixed 1.5R target.
- Optional time stop after 6/12/24 H1 bars.
- Opposite candle-sequence signal closes and reverses in an ablation variant.

### Stop Loss
- ATR(14) hard stop, sweep 1.0/1.5/2.0 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep N = 3/4/5, minimum body size as ATR fraction, H1/H4 timeframe, and optional trend filter suppression.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, idea author/handle, code author, publisher, and publish/update dates. |
| R2 Mechanical | PASS | Same-direction candle count and strictly increasing body condition create deterministic long/short signals. |
| R3 DWX-testbar | PASS | Uses OHLC candle bodies available on DWX instruments. |
| R4 No ML | PASS | No ML, grid, martingale, or online adaptation; one-position V5 baseline enforced. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10538_mql5-morse]] - candle-sequence family.

## Lessons Learned
- TBD during pipeline run.
