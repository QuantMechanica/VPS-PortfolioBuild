---
ea_id: QM5_10481
slug: mql5-exec-ao
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/ao-reversal]]"
  - "[[concepts/momentum-turn]]"
  - "[[concepts/new-bar-signal]]"
indicators:
  - "[[indicators/awesome-oscillator]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase URL/title/author present; R2 deterministic AO bend entry plus opposite/TP/time exits with ~100 trades/year/symbol; R3 AO/ATR/OHLC testable on DWX CFDs; R4 no ML/grid/martingale and one-position-per-magic."
---

# MQL5 Executor AO Momentum Bend

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Page / Timestamp: MQL5 CodeBase, "Executor AO - expert for MetaTrader 5", idea by Alex, code by Vladimir Karputov / barabashkakvn, published 2018-12-18, https://www.mql5.com/en/code/22613

## Mechanik

### Entry
- Baseline symbols: liquid DWX FX majors, XAUUSD.DWX, oil, and liquid index CFDs.
- Timeframe: M15 or H1; baseline M15.
- Evaluate only on new bars.
- Compute Awesome Oscillator on closed bars.
- Require no open position.
- Long setup:
  - AO[0] is at least `Minimum indent AO from 0.0` away from zero.
  - AO[0] > AO[1] and AO[1] < AO[2], forming an upward bend.
- Short setup:
  - AO[0] is at least the minimum indent away from zero.
  - AO[0] < AO[1] and AO[1] > AO[2], forming a downward bend.
- Baseline minimum AO indent = 0.10 x ATR-normalized point value; exact source input can be confirmed during build.

### Exit
- Close on opposite AO bend signal.
- Baseline TP = 2R.
- Time stop after 24 M15 bars if neither stop nor target is hit.

### Stop Loss
- V5 baseline: SL = 1.5 x ATR(14).

### Position Sizing
- V5 baseline: fixed-risk $1,000 per backtest trade.
- Live sizing deferred to V5 risk conventions.

### Zusätzliche Filter
- One-position-per-magic.
- New-bar execution only.
- V5 default spread guard.
- No grid, martingale, averaging, adaptive parameters, or multi-position behavior.

## Concepts (was ist das für eine Strategie)
- [[concepts/ao-reversal]] - primary
- [[concepts/momentum-turn]] - secondary
- [[concepts/new-bar-signal]] - execution

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable MQL5 CodeBase page with title, author/code attribution, publish date, and URL. |
| R2 Mechanical | PASS | Source gives explicit AO bend conditions for BUY and SELL and new-bar checking. |
| R3 Data Available | PASS | AO, ATR, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | No ML, online adaptation, grid, martingale, or required multi-position behavior. |

## Pipeline-Verlauf
- G0: Pending batch review.

## Verwandte Strategien
- [[strategies/QM5_10476_mql5-pamxa]] - AO regime plus stochastic trigger.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: expected cadence assumes oscillator bends occur regularly on M15 but are reduced by the minimum-indent filter and one-position rule.*
