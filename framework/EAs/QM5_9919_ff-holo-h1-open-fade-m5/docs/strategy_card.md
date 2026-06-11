---
ea_id: QM5_9919
slug: ff-holo-h1-open-fade-m5
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
source_citation: "TooSlow, Highest Open / Lowest Open Trade, ForexFactory, 2016-2026, https://www.forexfactory.com/thread/post/8944866"
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/intraday-level-fade]]"
  - "[[concepts/session-mean-reversion]]"
  - "[[concepts/open-price-level]]"
indicators:
  - "[[indicators/h1-open-level]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: M5
expected_trade_frequency: "High; current-day highest/lowest H1-open retests on M5 should produce roughly 90-180 trades/year/symbol after spacing filters."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/handle present; R2 deterministic H1-open fade entry/SL/TP/time exits with ~120 trades/year/symbol; R3 DWX FX/metals OHLC/ATR testable; R4 fixed no-ML single-position rules."
---

# ForexFactory HOLO H1 Open Fade M5

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Citation: TooSlow, "Highest Open / Lowest Open Trade", ForexFactory, 2016-2026, URL https://www.forexfactory.com/thread/post/8944866.
- Thread: "Highest Open / Lowest Open Trade".
- Author / handle: `TooSlow`.
- URL: https://www.forexfactory.com/thread/post/8944866
- Source location: post #990 states to place lines at the highest and lowest H1 opens for the current day and fade retests after price moves through and returns.

## Mechanik

### Entry
- Use M5 execution with current broker day boundaries.
- At each new H1 bar, update the current-day highest H1 open and lowest H1 open.
- Short setup:
  - Current day has at least 3 completed H1 bars.
  - Price trades above the current-day highest H1 open by at least `0.20 * ATR(14,M5)`.
  - Within the next 12 M5 bars, a completed M5 bar closes back below the highest H1 open.
  - The signal bar high is not more than 1.5 ATR above the level.
- Enter short at next M5 open or with sell stop at the highest H1 open after the above-through / back-below sequence. Long setup mirrors at the lowest H1 open after price trades below it and closes back above.

### Exit
- Primary TP: 1.2R or 15 pips, whichever is closer.
- If trade reaches +5 pips, move SL to break-even plus 1 pip.
- Exit at end of London/New York session if still open.
- Time stop: 24 M5 bars.

### Stop Loss
- Initial SL: 15 pips or `1.2 * ATR(14,M5)`, whichever is larger, capped at 2.2 ATR.
- For XAUUSD, use `1.2 * ATR(14,M5)` instead of fixed pips.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default `RISK_PERCENT` after approval.

### Zusaetzliche Filter
- Skip first 90 minutes after broker-day open; TooSlow notes HOLO is not meant to be traded at the open of a new day.
- Skip if current daily range already exceeds 130% of ADR(14), to avoid strong breakout days.
- One active position per magic-symbol.

## Concepts
- [[concepts/intraday-level-fade]] - primary
- [[concepts/session-mean-reversion]] - secondary
- [[concepts/open-price-level]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full ForexFactory HOLO post URL plus named handle `TooSlow`. |
| R2 Mechanical | PASS | Highest/lowest H1-open levels, through-and-return trigger, BE rule, SL, TP, and time exits are deterministic. |
| R3 DWX-testbar | PASS | Uses OHLC H1/M5 levels and ATR available on DWX FX/metals. |
| R4 No ML | PASS | Fixed rules and single-position-per-magic; no ML, adaptive tuning, grid, martingale, or averaging. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1151_fx-london-fix-reversal]] - intraday level fade; this card uses current-day H1 open extremes, not fix levels.
- [[strategies/QM5_9903_ff-roadmap-do-fail-m5]] - daily-open failure; this card fades current-day highest/lowest H1 opens.

## Lessons Learned
- TBD during pipeline run.
