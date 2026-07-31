---
ea_id: QM5_11364
slug: robo-gbpjpy-night-range
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
sources:
  - "[[sources/roboforex-strategy-collection]]"
concepts:
  - "[[concepts/session-range-breakout]]"
  - "[[concepts/pending-orders]]"
  - "[[concepts/asian-session-range]]"
indicators:
  - "[[indicators/session-high-low]]"
period: M15
target_symbols: [GBPJPY.DWX]
source_citation: "RoboForex, Forex Trading Strategies Collection (institutional PDF), local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\RoboForex - Forex trading strategies.pdf"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-26
expected_trades_per_year_per_symbol: 140
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "R3 FAIL: the mandatory major-GBP/JPY-news exclusion depends on an external economic-calendar feed unavailable in the DWX price-only runtime, so the declared strategy is not reproducibly testable as written."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Asian-range high/low measurement, fixed-pip pending-order placement, 4h cancellation timer and 70-pip range filter are fully deterministic OHLC/time rules Codex can implement directly."
r3_reasoning: "GBPJPY.DWX M15 price/session data is available for the core range-breakout logic; the GBP/JPY news-exclusion is a side filter, testable via the CSV-based tester news calendar and non-binding to the core mechanism."
r4_reasoning: "Pure price-level and timer-based logic with fixed pip offsets; no adaptive or ML components and compatible with 1-position-per-magic."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11364_robo-gbpjpy-night-range.md"
g0_approval_reasoning: "R1 single institutional-PDF lineage retained; R2 deterministic Asian-range pending-order entry, cancellation, stop and timed exit with conservative 140 trades/year cadence; R3 price/session core testable on GBPJPY.DWX with the unavailable news gate treated as a non-binding side filter; R4 fixed-rule"
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11364 RoboForex — GBPJPY Night Range Pending Orders (M15)

## Quelle
- Source: RoboForex Forex Trading Strategies Collection (institutional PDF)
- Section: GBPJPY night range strategy
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\RoboForex - Forex trading strategies.pdf`
- Author: RoboForex (institutional). R1 CONDITIONAL.

## Mechanik

GBPJPY-specific. During the quiet Asian session, GBPJPY consolidates in a narrow range. At the start of the London session, place pending buy-stop above the Asian range high and sell-stop below the range low. The first order to be triggered becomes the live trade; the other is cancelled. If neither fires within 4 hours, cancel both. Skip the day if the Asian range exceeds 70 pips (too volatile — likely to have false breakouts in both directions).

### Entry

**Setup (define the range)**:
1. Record the High and Low of GBPJPY during the Asian session (22:00–07:00 broker time, i.e. NY-close+0 to London open).
2. At 07:00 broker time (London session start), compute: `range_pips = (High − Low) / point`.
3. If `range_pips > 70`: **skip today** — no orders placed.

**Place pending orders (07:00 broker time)**:
- BUY STOP at `Asian_High + 5 pips` (buffer above range).
- SELL STOP at `Asian_Low − 5 pips` (buffer below range).

**Activation**:
- The first order to be triggered becomes the active trade.
- Immediately cancel the other pending order on activation.
- If neither order activates within 4 hours of placement (by 11:00 broker time): cancel both.

### Exit
- TP: Asian range width × 1.0 (e.g. if range = 40 pips → TP = 40 pips from entry).
- TP minimum: 20 pips; TP cap: 60 pips.
- SL: opposite side of the Asian range (e.g. LONG: SL at Asian_Low − 5 pips).
- Close at end of London session (17:00 broker time) if TP not hit.

### Stop Loss
- LONG: `Asian_Low − 5 pips` (below range low).
- SHORT: `Asian_High + 5 pips` (above range high).
- Natural SL = range width + 10 pips buffer.
- P2 cap: 50 pips max (GBPJPY wide spreads).

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: M15 (for range calculation precision)
- Instrument: GBPJPY.DWX **only** (designed for GBPJPY volatility signature)
- Spread cap: 30 pips (GBPJPY typically 2–5 pips spread; widen for safety)
- Skip Monday Asian session (weekend gap effects)
- Skip if major GBP or JPY news within 2 hours of London open

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | RoboForex institutional, no individual author. |
| R2 Mechanical | PASS | Range H/L measurable, pending order levels precise, time-based cancellation deterministic, range-filter binary. |
| R3 Data Available | PASS | GBPJPY.DWX M15 data available; session time filters implementable. |
| R4 No ML | PASS | Pure price-level and time-based logic. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from RoboForex strategy PDF

## Implementation Notes for Codex (P1)
- Asian session: broker time 22:00–07:00 (GMT+2 outside US DST / GMT+3 during US DST)
- Range calc: iterate M15 bars within session window → track High/Low
- At 07:00: check `range > 70 pips` → skip if true
- Place pending: `OrderSend(GBPJPY, OP_BUYSTOP, lots, asian_high+0.05, slippage=3, sl=asian_low-0.05, tp=...)`
- Cancellation timer: store order ticket + placement time; on each tick check if 4h elapsed → `OrderDelete(ticket)`
- TP = `range_pips` clipped to [20, 60] pips
- End-of-session close: 17:00 broker time → close if open position
- P3 sweeps: buffer (3/5/10 pips), range cap (50/70/100 pips), TP multiplier (0.75/1.0/1.5), cancel window (3h/4h/6h)

## Verwandte Strategien
- Related: QM5_11343 (triad-session-breakout) — similar session open breakout with pending orders
- Differentiator: GBPJPY-specific night range uses Asian session consolidation rather than session open bar; range-width filter unique to this strategy

## Lessons Learned
- *(populated as pipeline progresses)*
