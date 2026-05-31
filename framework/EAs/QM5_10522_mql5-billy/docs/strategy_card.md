---
ea_id: QM5_10522
slug: mql5-billy
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "bobbybo / Boris idea, Vladimir Karputov / barabashkakvn code, Billy expert, MQL5 CodeBase, published 2018-01-22, updated 2018-02-28, https://www.mql5.com/en/code/19467"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/multi-timeframe-confirmation]]"
indicators: [Candles, iStochastic]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M15
expected_trade_frequency: "Three-down-bar pullback plus two higher-timeframe Stochastic confirmations on M15; conservative long-only estimate is 40-120 trades/year/symbol."
expected_trades_per_year_per_symbol: 70
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase URL cited; R2 deterministic three-down-bar plus dual Stochastic long entry with fixed SL/TP/time exits and ~70 trades/year/symbol; R3 DWX M15 FX/XAU testable; R4 no ML/grid/martingale and one position per magic."
---

# MQL5 Billy Pullback

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: bobbybo / Boris idea, "Billy expert", MQL5 CodeBase, published 2018-01-22, updated 2018-02-28, URL https://www.mql5.com/en/code/19467.
- Source location: page states the main idea: after three down bars on the current timeframe, if the main Stochastic line is above the signal line on two other timeframes, a Buy signal emerges. The source states "The strategy handles only Buy signals" and shows M15 tests for EURUSD, GBPUSD, and USDJPY.

## Mechanik

### Entry
- Evaluate on M15 closed bars.
- Long only:
  - Bar 1, bar 2, and bar 3 are bearish/down bars on the current timeframe.
  - On Stochastic timeframe #1, main line > signal line.
  - On Stochastic timeframe #2, main line > signal line.
  - No existing position for this symbol/magic.
- No short branch in baseline because the source explicitly says it handles only Buy signals.

### Exit
- Source supports Lots, Stop Loss, Take Profit, Max positions, Stochastic timeframe #1/#2, and magic number.
- P2 baseline: SL = 1.5 * ATR(14), TP = 1.25R, no pyramiding, no averaging.
- Optional time stop after 5 M15 bars if neither SL nor TP is hit, included in P3 sweep rather than baseline if source code has no time exit.

### Stop Loss
- ATR-normalized hard stop mapped from source Stop Loss input.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Source max positions fixed to 1 for V5.

### Zusaetzliche Filter
- Sweep Stochastic periods, timeframe pair, ATR stop multiple, TP R multiple, and optional time stop.
- V5 news/spread/Friday-close defaults apply.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, named idea/code attribution, publish/update dates, and test symbols/timeframe. |
| R2 Mechanical | PASS | Three bearish bars plus two Stochastic main-over-signal confirmations and fixed exits are deterministic. |
| R3 DWX-testbar | PASS | M15 OHLC and Stochastic values are available on DWX symbols. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive online parameters; Max positions is fixed to one. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10511_mql5-n-candles]] - consecutive-candle continuation/reversal family.
- [[strategies/QM5_10499_mql5-cloud]] - Stochastic confirmation/reversal family.

## Lessons Learned
- TBD during pipeline run.
