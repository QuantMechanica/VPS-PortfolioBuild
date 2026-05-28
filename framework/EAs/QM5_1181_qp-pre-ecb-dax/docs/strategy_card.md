---
ea_id: QM5_1181
slug: qp-pre-ecb-dax
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/calendar-effect]]"
  - "[[concepts/event-drift]]"
indicators:
  - "[[indicators/ecb-calendar]]"
  - "[[indicators/session-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL+author cited; R2 deterministic ECB D-2 close long to D-1 close exit; R3 GER40.DWX DAX proxy testable; R4 fixed rules no ML/grid/martingale."
---

# Quantpedia Pre-ECB DAX Drift

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Uncovering the Pre-ECB Drift and Its Trading Strategy Applications"
- Retrieved 2026-05-17, URL recorded in approved source vault.
- Named author: Cyril Dujava, Quantpedia.
- Location: Results / "Market Reactions to ECB Announcements" and conclusions.

## Mechanik

### Entry
On each confirmed European Central Bank press-conference date:
1. Let `D0` be the ECB press-conference trading day.
2. At `GER40.DWX` D1 close on `D-2`, open LONG `GER40.DWX`.
3. Trade only if `GER40.DWX` has valid D1 bars for `D-3` through `D-2` and spread is within P1 defaults.
4. Hold exactly one position per magic number; ignore overlapping ECB events.

### Exit
- Close at `GER40.DWX` D1 close on `D-1`, before the ECB announcement day.
- Safety exit: close at the next available D1 close if the `D-1` bar is missing.

### Stop Loss
- Initial stop: 2.0x ATR(20) on completed D1 bars.
- Optional P3 variant: no ATR stop, event-window exit only.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Requires checked-in ECB press-conference calendar.
- Use `GER40.DWX` as DAX proxy. Optional confirmation route: `STOXX50.DWX` if available.
- No macro surprise, NLP, or policy-text input is used.

## Concepts
- [[concepts/calendar-effect]] - primary
- [[concepts/event-drift]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia source is verifiable and names Cyril Dujava as article author. |
| R2 Mechanical | UNKNOWN | ECB calendar date, D-2 close entry, and D-1 close exit are deterministic. |
| R3 Data Available | UNKNOWN | Source studies DAX/STOXX and European ETFs; `GER40.DWX` is the direct DAX CFD proxy if present in the test matrix. |
| R4 ML Forbidden | UNKNOWN | Fixed event window only; no ML, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1094_qp-fomc-sp500]] - analogous central-bank event drift for FOMC.

## Lessons Learned
- (noch keine)
