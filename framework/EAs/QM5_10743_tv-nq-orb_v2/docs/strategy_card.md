---
ea_id: QM5_10743
slug: tv-nq-orb
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "TradingView script `NQ Opening Range Breakout`, author handle `blinkzssss`, invite-only strategy, published 2025-09-26, https://www.tradingview.com/script/zZVq6KQB-NQ-Opening-Range-Breakout/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-flat]]"
indicators: [OpeningRange, EMA, VWAP, ATR]
target_symbols: [NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX]
period: M5
expected_trade_frequency: "One opening-range breakout per session with optional reversal disabled for V5 baseline; conservative estimate 100 trades/year/symbol."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS direct TradingView URL/author; R2 PASS mechanical OR breakout/SL/TP/time-flat with ~100 trades/year/symbol; R3 PASS NDX.DWX and other DWX CFDs; R4 PASS fixed non-ML one-position rules."
---

# TradingView NQ Opening Range Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Citation: TradingView script `NQ Opening Range Breakout`, author handle `blinkzssss`, published 2025-09-26, URL https://www.tradingview.com/script/zZVq6KQB-NQ-Opening-Range-Breakout/.
- Source location: public page describes configurable opening-range timeframe, EMA/VWAP filters, ATR sizing filter, range-based stop/target choices, and 16:00 flat exit.

## Mechanik

### Entry
- Define the opening range over the configured first-session window; baseline = 09:30-09:45 New York on M5.
- After the range closes, enter long on the first confirmed close above OR high.
- Enter short on the first confirmed close below OR low.
- Require OR height between `0.25 * ATR(14)` and `2.5 * ATR(14)`.
- Optional source filters for P3: long only if price is above VWAP and selected EMA; short only if price is below VWAP and selected EMA.

### Exit
- Baseline TP = 2.0R from entry.
- Exit any open trade at 16:00 New York if neither TP nor SL is hit.
- Source alternative for P3: EMA-close exit where long exits when close falls below selected EMA, short exits when close rises above it.

### Stop Loss
- Baseline SL = opposite side of the opening range.
- P3 alternatives from source: half-range stop, or entry-candle-open stop.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- V5 baseline disables reversal trade after stop-out to preserve one-position-per-magic simplicity.
- One active position per symbol/magic.
- No entries before the opening range has fully completed.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Direct TradingView URL plus author handle `blinkzssss`. |
| R2 Mechanical | PASS | OR window, breakout trigger, SL choices, TP, filters, and time flat are explicit. |
| R3 DWX-testbar | PASS | NQ-origin ORB ports directly to NDX.DWX and other DWX index/metals CFDs. |
| R4 No ML | PASS | Fixed OR/EMA/VWAP/ATR rules, no ML, grid, martingale, or pyramiding in the V5 baseline. |

## R3
Primary P2 basket: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Lessons Learned
- TBD during pipeline run.
