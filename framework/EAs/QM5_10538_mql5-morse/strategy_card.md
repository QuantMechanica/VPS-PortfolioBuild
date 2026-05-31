---
ea_id: QM5_10538
slug: mql5-morse
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Morse code, Vladimir Karputov, MQL5 CodeBase, published 2017-05-29, updated 2018-02-27, https://www.mql5.com/en/code/18066"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/candlestick-pattern]]"
indicators: [CandlestickPattern, ATR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Preset bullish/bearish candle-sequence pattern with fixed SL/TP; conservative estimate is 30-80 trades/year/symbol on H1 depending on selected pattern."
expected_trades_per_year_per_symbol: 50
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 URL/title/author/date; R2 PASS deterministic candle-sequence entries with fixed exits and 30-80 trades/year/symbol; R3 PASS OHLC/ATR portable to DWX FX/metals; R4 PASS no ML/grid/martingale and one-position baseline."
---

# MQL5 Morse Candle Pattern

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Vladimir Karputov, "Morse code", MQL5 CodeBase, published 2017-05-29, updated 2018-02-27, URL https://www.mql5.com/en/code/18066.
- Source location: page states the EA trades preset candlestick combinations, marks bullish candles as `1` and bearish candles as `0`, chooses the desired candle combination from a drop-down list, and uses Take Profit and Stop Loss.

## Mechanik

### Entry
- Evaluate closed H1 candles.
- Convert the last N candles to a binary string: bullish close > open = `1`, bearish close < open = `0`.
- Enter in the source-configured direction when the binary string matches the selected pattern.
- P2 baseline tests two deterministic variants: continuation with the final candle direction, and reversal against a three-candle exhaustion pattern.
- No existing position for this symbol/magic.

### Exit
- Fixed source-style SL/TP; P2 baseline TP = 1.5R.
- Time stop after 8 H1 bars.

### Stop Loss
- ATR(14) hard stop, sweep 1.0/1.5/2.0 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Sweep pattern length 3/4/5 and selected strings such as `1110`, `0001`, `101`, and `010`.
- V5 spread/news/Friday-close defaults apply.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL, title, author, and publish/update dates. |
| R2 Mechanical | PASS | Binary candle-sequence matching and fixed exits are deterministic. |
| R3 DWX-testbar | PASS | OHLC candle direction and ATR exits are available on DWX instruments. |
| R4 No ML | PASS | No ML, grid, martingale, or online adaptation. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10449_mql5-3inside]] - candlestick pattern family.

## Lessons Learned
- TBD during pipeline run.
