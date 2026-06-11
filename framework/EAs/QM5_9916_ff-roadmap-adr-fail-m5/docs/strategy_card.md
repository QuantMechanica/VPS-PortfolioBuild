---
ea_id: QM5_9916
slug: ff-roadmap-adr-fail-m5
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "LauraT, Roadmap - A Way To Read Markets, ForexFactory, 2020, https://www.forexfactory.com/thread/post/12905491"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/level-failure]]"
  - "[[concepts/session-mean-reversion]]"
  - "[[concepts/adr-boundary]]"
indicators:
  - "[[indicators/ema-channel]]"
  - "[[indicators/adr]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M5
expected_trade_frequency: "Medium; ADR/previous-day boundary failures on M5 should appear roughly 40-90 times/year/symbol after session and range filters."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 linked ForexFactory source; R2 deterministic ADR/PDH/PDL failure entry and exits with ~60 trades/year/symbol; R3 testable on DWX FX/metals; R4 fixed-rule no ML/grid/martingale one-position."
---

# ForexFactory Roadmap ADR Failure M5

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: LauraT, "Roadmap - A Way To Read Markets", ForexFactory, 2020, URL https://www.forexfactory.com/thread/post/12905491.
- Thread: "Roadmap - A Way To Read Markets".
- Author / handle: `LauraT`.
- URL: https://www.forexfactory.com/thread/post/12905491
- Source location: post #790/#791 discussion of ADR Failures and Previous Day High/Low Failures; LauraT distinguishes failure entries from counter entries.

## Mechanik

### Entry
- Use completed M5 bars during Frankfurt, London, and early New York.
- Compute Roadmap EMA channel: EMA(8, high), EMA(8, close), EMA(8, low).
- Compute 14-day ADR high/low projected from current daily open, plus previous-day high and previous-day low.
- Long setup:
  - Price is near the downside boundary: either ADR low or previous-day low is within `0.20 * ADR(14)` from the current close.
  - EMA(8, low) and/or EMA(8, close) has moved below that boundary within the last 8 bars.
  - The channel then fails back above the boundary: a completed M5 bar closes with EMA(8, close) back above the boundary and close above EMA(8, close).
  - Failure bar closes bullish and its close is at least `0.15 * ATR(14,M5)` above the boundary.
- Enter long at next M5 open. Short setup mirrors at ADR high or previous-day high after EMA channel returns below the boundary.

### Exit
- Primary TP: nearest of daily open, EMA(200,M5), opposite Roadmap level, or 1.6R.
- Exit if EMA(8, close) crosses back through the failed boundary against the trade.
- Time stop: 30 M5 bars.

### Stop Loss
- Long SL below the failure swing low or boundary minus `0.25 * ATR(14,M5)`, whichever is farther.
- Short SL above the failure swing high or boundary plus `0.25 * ATR(14,M5)`.
- Reject if initial stop is below 0.6 ATR or above 2.4 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Skip if current daily range is below 45% of ADR; the method needs a real boundary test.
- Skip high-impact news windows using standard V5 news filter.
- One active position per magic-symbol; no add-ons.

## Concepts
- [[concepts/level-failure]] - primary
- [[concepts/session-mean-reversion]] - secondary
- [[concepts/adr-boundary]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory Roadmap post URL plus named handle `LauraT`. |
| R2 Mechanical | PASS | ADR/PDH/PDL levels, EMA-channel failure, SL, TP, and time exits are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC-derived ADR, EMA, ATR, and previous-day levels on DWX FX/metals. |
| R4 No ML | PASS | Fixed periods and thresholds; no adaptive parameters, ML, grid, martingale, or multiple positions per magic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9903_ff-roadmap-do-fail-m5]] - daily-open failure; this card uses ADR/previous-day high-low boundary failure.
- [[strategies/QM5_9700_ff-roadmap-channel-m15]] - Roadmap channel cross; this card is boundary-failure mean reversion.

## Lessons Learned
- TBD during pipeline run.
