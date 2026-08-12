---
ea_id: QM5_11442
slug: burke-frd-fgd-daily-pump-m5
type: strategy
source_id: 04305b6c-b4ce-522b-87b5-71708b6b8327
sources:
  - "[[sources/burke-stacey-playbook]]"
concepts:
  - "[[concepts/multi-day-pattern]]"
  - "[[concepts/pump-and-fade]]"
  - "[[concepts/ema-close-back]]"
  - "[[concepts/multi-timeframe]]"
indicators:
  - "[[indicators/ema]]"
period: M5
source_citation: "Stacey Burke, The Stacey Burke Trading Playbook (online/self-published). R1 CONDITIONAL — named individual, no verifiable major-publisher credentials."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; Stacey Burke self-published Playbook is a valid attribution under updated R1 criteria.
r2_mechanical: PASS
r2_reasoning: FRD/FGD D1 OHLC comparisons and M5 EMA20 close check are fully deterministic; news filter gap is a documented limitation but does not disqualify the mechanical core.
r3_data_available: PASS
r3_reasoning: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX on M5/D1 are DWX instruments with adequate history.
r4_ml_forbidden: PASS
r4_reasoning: Fixed EMA(20), fixed D1 pattern conditions, one trade per Day 3 — no ML or adaptive parameters.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 45
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 single source_id/source attribution; R2 mechanical D1 FRD/FGD pattern plus M5 EMA20 entry with defensible multi-day cadence >2 trades/year/symbol; R3 DWX FX M5/D1 testable; R4 deterministic no ML/HR14 conflict."
---

# QM5_11442 Burke — FRD/FGD Daily Pump → M5 EMA20 Fade (M5+D1)

## Quelle

- Source: Stacey Burke, "The Stacey Burke Trading Playbook" (online/self-published, 2022; URL/local PDF archive).
- R1: CONDITIONAL — named individual author, self-published.

## Mechanik

**Concept**: A 3-day D1 pattern called FRD (Fakeout Reversal Day) for bearish
fades or FGD (Fakeout Gap Day) for bullish fades. Day 1 is a "pump" — close
breaks above the prior day's High. Day 2 is the FRD: it opens higher but closes
below its own Open. Day 3 is the trade day: on M5, the first candle that closes
back below EMA20 in the London or NY session is the SHORT entry.

**Pattern logic**: Day 1 exhausts buyers. Day 2 confirms the reversal. Day 3
follows through on M5 with momentum. The EMA20 acts as dynamic resistance.

**News caveat**: Burke explicitly requires "no major red news" events on Day 3.
The approved card records this as a known implementation limitation.

### D1 Pattern Detection (evaluated at start of Day 3 bar)

**FRD (Short setup):**

1. Close[D1,2] > High[D1,3]
2. Close[D1,1] < Open[D1,1] AND Open[D1,1] >= Close[D1,2]
3. Close[D1,1] < Close[D1,2]

**FGD (Long setup, mirror):**

1. Close[D1,2] < Low[D1,3]
2. Close[D1,1] > Open[D1,1] AND Open[D1,1] <= Close[D1,2]
3. Close[D1,1] > Close[D1,2]

### M5 Entry (Day 3 execution)

**SHORT (FRD):**

1. D1 FRD pattern confirmed at Day 3 open.
2. Wait for London (07:00-12:00 GMT) or NY (13:00-17:00 GMT).
3. Close[M5,0] < EMA20[M5,0].
4. Enter SELL at the close of that M5 bar.

**LONG (FGD):**

- Mirror: first M5 bar that closes above EMA20.

### Exit

- TP: entry minus 50 pips for short or entry plus 50 pips for long.
- Time stop: if no fill or 50% TP by session end, close at market.

### Stop Loss

- SHORT: entry plus 20 pips (max; or above EMA20 by 5 pips if EMA20 + 5 is greater than entry + 20).
- LONG: entry minus 20 pips.
- P2 cap: 25 pips.

### Position Sizing

- RISK_FIXED = $1000 for P2.
- RISK_PERCENT = 0.5% for live.

### Zusätzliche Filter

- Timeframe: M5 entry, D1 pattern.
- Session window: London 07:00-12:00 GMT and/or NY 13:00-17:00 GMT.
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX.
- Spread cap: 15 pips.
- One trade per Day 3 per symbol.

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|---|---|---|
| R1 Track Record | CONDITIONAL | Stacey Burke, named author, self-published. |
| R2 Mechanical | PASS | D1 close comparisons are pure OHLC. EMA20 M5 close check is MT5-native. News-filter limitation documented. |
| R3 Data Available | PASS | M5/D1 DWX FX data and MT5-native EMA20 are available. |
| R4 No ML | PASS | Fixed pattern rules and EMA period (20). |

G0 APPROVE eligible with CONDITIONAL R1 note.

## Pipeline-Verlauf

- G0: 2026-05-23 — drafted from Burke Playbook (FRD/FGD pattern).

## Implementation Notes for Codex (P1)

- Detect the D1 pattern on prior closed D1 bars.
- Store or deterministically recover one-trade-per-Day-3 state.
- Convert the stated GMT sessions from broker time.
- P3 sweeps: EMA period 13/20/34, London/NY/both, TP 30/50/75 pips, SL 15/20/25 pips.

## Verwandte Strategien

- QM5_11443 burke-day3-breakout-trap-m5.
- QM5_11447 burke-parabolic-short-squeeze-m5.

## Lessons Learned

- The source's red-news caveat remains explicit at the card boundary.
