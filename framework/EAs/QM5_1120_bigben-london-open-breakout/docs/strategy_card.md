---
ea_id: QM5_1120
slug: bigben-london-open-breakout
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/session-breakout]]"
  - "[[concepts/london-open-volatility]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "ForexFactory Big Ben London-open breakout (thread #110278, ~2008+): R1 named FF handle + thread URL — relaxed-R1 PASS; R2 Asian-range max-high/min-low + 07:00 OCO stop-pair + 11:00 cancel + 19:00 time-stop + ATR alt-SL all closed-form; R3 5/5 London-session-active DWX FX majors (EURUSD/GBPUSD/EURJPY"
---

# QM5_1120 Big Ben — London Open Breakout (Pre-Open Range + ATR Stop)

## Quelle
- Primary: ForexFactory thread/110278 "The Big Ben Strategy"
- URL: https://www.forexfactory.com/thread/110278
- Author: `Big Ben` (named ForexFactory handle, original poster; classic
  London-open-breakout community thread, ~2008+).
- Mechanic provenance: define the Asian-session pre-London-open range
  (00:00–07:00 broker-time on DXZ NY-Close server = 22:00–05:00 UTC outside
  US DST, 23:00–06:00 UTC during US DST), then trade the break of that
  range immediately after London cash open.

## Mechanik

### Entry
- Define **Asian range** as `[max(High), min(Low)]` over the broker-time
  window 00:00–07:00 (M15 bars). On DXZ NY-Close server, this corresponds
  to the late-Asia → pre-London-open window in UTC and aligns with the
  Big Ben thread's "pre-London-open range" specification.
- At broker-time 07:00 (London cash open), arm a one-shot stop pair:
  - BUY-STOP at `Asian_High + 5 pts`
  - SELL-STOP at `Asian_Low - 5 pts`
- Only ONE side can fire per day per symbol. If long fires, cancel the
  short pending and vice versa.
- If neither side fires by broker-time 11:00 (4 hours after London open),
  cancel both pending orders. No trade that day.

### Exit
- Time stop: flatten any open position at broker-time 19:00 (NY close).
- TP: optional fixed RR = 2.0 from entry-vs-stop (P3 sweepable in
  {1.0, 1.5, 2.0, 3.0}).
- No reverse stop on hit — if the opposite side of the range is hit before
  TP/time-stop, the position simply trails to its hard stop (no flip).

### Stop Loss
- Initial SL: opposite side of the Asian range (long entry → SL at
  Asian_Low – 5 pts; short entry → SL at Asian_High + 5 pts).
- Alternative for P3: `ATR(14, H1) × 1.0`.

### Position Sizing
- `RISK_FIXED = $1000` for P2-baseline (HR4).
- `RISK_PERCENT = 0.5%` for live.

### Filters
- Spread cap: 25 pts at order-placement time. If spread > 25 pts at
  07:00, skip the day.
- Session: hard-bound to 07:00–11:00 broker-time entry window + 19:00
  broker-time hard exit. Outside this window, EA is inactive.
- Day-of-week filter: optional Mon-Thu only (P3 sweepable; default for P2
  is all weekdays).
- News-filter hook (off by default for P2).

## Concepts
- [[concepts/session-breakout]] — primary (Asian range → London break)
- [[concepts/london-open-volatility]] — secondary (mechanic exploits volatility ramp at London cash open)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named FF handle (Big Ben), specific thread URL, multi-year community-canonical London-open thread. Relaxed-R1 (2026-05-15) requires only verifiable link. |
| R2 Mechanisch | PASS | Range definition (max-high/min-low over fixed window), stop-pair placement, time-of-day arm/cancel, time-stop exit — all closed-form and unambiguous. |
| R3 DWX-testbar | PASS | Designed for FX majors active in London session. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, EURJPY.DWX, GBPJPY.DWX, EURGBP.DWX. |
| R4 No ML | PASS | Fixed time windows, fixed range definition, fixed SL/TP logic. No ML, no adaptive params, no grid, no martingale. OCO pending-pair is bounded (max one fill per day). |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from ForexFactory batch 3

## Implementation Notes for Codex (P1)
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, EURJPY.DWX, GBPJPY.DWX,
  EURGBP.DWX** (5 London-session-active majors + crosses).
- Trading timeframe: M15 (range construction) + tick (pending-order
  fill detection).
- Broker time on DXZ NY-Close server: GMT+2 outside US DST, GMT+3 during
  US DST — implementation must read `TimeTradeServer()` not `TimeGMT()`
  for the 00:00 / 07:00 / 11:00 / 19:00 thresholds (per QM broker-time
  memory convention).
- Pending-order management: `OrderSend` BUY_STOP + SELL_STOP at 07:00,
  delete unfilled at 11:00.
- Smoke (P1): EURUSD.DWX M15 one month; full P2: 1-year M15 per symbol.

## Verwandte Strategien
- Cousin of existing breakout cards (1001 breakout-atr, 1004 davey-es-breakout,
  1011 lien-inside-day-breakout, 1013 lien-20day-breakout), but those are
  multi-day-range or ES-specific. 1120 is intraday FX-session-breakout —
  distinct mechanic (Asian range → London-open trigger).
- Adjacent: any "open-range breakout" (ORB) variant. The Robbins Cup
  Unger ORB-INDEX (1062) trades index-CFD ORB; 1120 trades FX-session
  Asian-range → London break.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
