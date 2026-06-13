---
ea_id: QM5_12551
slug: ict-turtle-soup-asian-false-break-m15
type: strategy
source_id: ict-mmm-notes-2020-turtle-soup
sources:
  - "[[sources/ict-twfx-mmm-notes-2020]]"
  - "[[sources/ict-2022-mentorship-canonical]]"
concepts:
  - "[[concepts/false-breakout]]"
  - "[[concepts/asian-range]]"
  - "[[concepts/judas-swing]]"
  - "[[concepts/two-step-liquidity]]"
  - "[[concepts/fidelity-initiative]]"
indicators:
  - "[[indicators/session-time]]"
  - "[[indicators/asian-range]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "ICT (Michael J. Huddleston) 2022 Mentorship canonical model — Turtle Soup / AMD variant. MMM Notes (Mmari, 2020), p.72, as named educational derivative. Mechanism family validated in-house: QM5_10692 (Q12 survivor) uses ICT liquidity sweep concept. QM5_12540 (AMD/Judas single-step) is already live in the approved pool."
r2_mechanical: PASS
r2_reasoning: "2-step false-break detection on Asian range: (1) initial false break of Asian range boundary (outside → close back inside = fake-out confirmed), (2) subsequent breakout of OPPOSITE Asian range boundary (real Judas swing), (3) pullback entry to the broken boundary. All steps are OHLC comparisons with fixed session time windows. No discretion."
r3_data_available: PASS
r3_reasoning: "M15 DWX FX pairs and XAUUSD; Asian session range defined by fixed time window (23:00-03:00 GMT); M15 bars available in factory."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed session windows, fixed range comparisons; no ML."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
expected_pf: 1.25
expected_dd_pct: 15
last_updated: 2026-06-12
g0_approval_reasoning: "G0 2026-06-12 Claude (library-mining task 7143e208): DEDUP = VARIANT vs QM5_12540 (AMD/Judas single-step). Delta: QM5_12540 enters on the FIRST re-close inside the Asian range (1 step). Turtle Soup adds a SECOND confirmation: after the first fake-out, expect a second and LARGER breakout of the OPPOSITE Asian range boundary before the real directional move. Entering after the second breakout (not the first fake-out re-close) significantly reduces false entries by requiring two confirmations. Mechanically distinct: the wait-for-second-break logic is the load-bearing delta. The name 'Turtle Soup' refers specifically to trapping retail turtles who bought the first breakout (the fake-out), then reversing them when the real move starts."
---

# ICT Turtle Soup — Asian Range False-Break 2-Step (M15)

## Source
- ICT (Michael J. Huddleston) 2022 Mentorship — Turtle Soup / 2-step AMD variant.
- MMM Notes (Reginald Mmari, 2020), p.72. Source cache: `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt`.
- Related approved card: QM5_12540 (AMD/Judas single-step — enter on first fake-out close inside range).

## Dedup Verdict
VARIANT vs QM5_12540. Delta: QM5_12540 enters on the first fake-out (price breaks out of Asian range, closes back inside → enter in direction of the re-close). Turtle Soup adds a second confirmation requirement: after the first fake-out, price must make a SECOND breakout of the OPPOSITE side of the Asian range before entry. This 2-step structure eliminates many of the false entries that plague the simpler AMD approach — specifically, cases where the initial fake-out is followed by price drifting back toward the original breakout direction rather than making the real Judas swing.

## Market Universe
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX

## Timeframe
M15 execution.

## Entry — LONG (Asian Fake-Out Bear Trap; SHORT = mirror)
The most common Turtle Soup setup: Asian session is bearish-leaning (price tested lows), London makes an initial break BELOW Asian Low (Bear Trap), then price returns to Asian range and then breaks ABOVE Asian High (real Judas swing = long).

### Step 1: Asian Range Definition
- Asian session: 23:00 GMT to 03:00 GMT (DWX broker: add UTC+2/+3 offset).
- `asian_high` = highest high of all M15 bars from 23:00 to 03:00 GMT.
- `asian_low` = lowest low of all M15 bars from 23:00 to 03:00 GMT.
- Record at 03:00 GMT (session close); range is now fixed for the day.

### Step 2: Initial Fake-Out Detection (London KZ: 07:00-09:00 GMT)
- **Bearish fake-out (for eventual LONG trade):** An M15 bar's LOW drops BELOW `asian_low` (price breaks the Asian Low).
- The SAME bar or a subsequent bar within the KZ CLOSES BACK ABOVE `asian_low` (fake-out confirmed: price returned inside the Asian range).
- Record: `fakout_extreme = lowest_low_below_asian_low` (the wick below asian_low — this becomes the Turtle Soup SL anchor).
- State: `fake_out_confirmed_BEAR = TRUE`. Look for the next phase.

### Step 3: Real Judas Swing (same London KZ window, within next 8 M15 bars)
- After the bearish fake-out: price re-enters the Asian range and continues toward the Asian High.
- A M15 bar's HIGH exceeds `asian_high` by 1 pip → real Judas LONG breakout confirmed.

### Step 4: Entry
- After the Judas breakout bar closes: place **BUY LIMIT** at `asian_high` (the broken Asian High, now expected to be support on pullback).
  - Valid for 3 M15 bars; cancel if not filled.
- Alternative: if no pullback to asian_high, BUY MARKET at next M15 bar open.
- News blackout active.

### Stop Loss:
- Below `fakout_extreme` (the wick tip of the initial bearish fake-out) + 0.5 × ATR(14, M15).

### Profit Targets:
- TP1: Prior day's high (PDH) or the highest H4 swing high above current price.
- TP2: Next liquidity pool (weekly high, monthly high, key H4 OB zone).
- Exit: 50% at TP1, trail remainder to TP2.

## Risk
RISK_FIXED backtest / RISK_PERCENT live; 1.0% per trade.

## Notes for Codex (P1 implementation)
- Session tracking: compute `asian_high` and `asian_low` each day at 03:00 GMT (end of Asian session).
- Fake-out detection: on each M15 bar during London KZ (07:00-09:00 GMT):
  - If `iLow(NULL, PERIOD_M15, 0) < asian_low` AND `iClose(NULL, PERIOD_M15, 0) > asian_low` → fake_out_bear = TRUE.
  - Record `fakout_extreme = min(fakout_extreme, iLow(NULL, PERIOD_M15, 0))`.
- Judas detection: if `fake_out_bear = TRUE` AND `iHigh(NULL, PERIOD_M15, 0) > asian_high` → Judas confirmed.
- BUY LIMIT at `asian_high`; expiry 3 M15 bars.
- SL: `fakout_extreme - 0.5 × iATR(NULL, PERIOD_M15, 14, 0)`.
- Reset all state variables daily at 23:00 GMT (start of new Asian session).
- State: per-symbol `{asian_high, asian_low, fake_out_bear, fake_out_bull, fakout_extreme, judas_long_confirmed, judas_short_confirmed}`.
- P3 sweep: Asian session window (22:00-03:00 vs 23:00-03:00 vs 23:00-04:00), London KZ entry window (07:00-09:00 vs 07:00-10:00), pullback entry (limit at asian_high vs market on Judas bar close).
