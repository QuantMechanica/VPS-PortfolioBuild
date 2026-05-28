---
ea_id: QM5_1332
slug: chan-london-bb-breakout
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/time-of-day]]"
  - "[[concepts/fx-session-breakout]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/session-time]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS: Ernest Chan blog URLs/comments; R2 PASS: deterministic 09:00 GMT BB breakout with M1 execution and hold/TP/SL exits; R3 PASS: EURUSD.DWX and other FX symbols testable; R4 PASS: fixed rules, no ML/grid/martingale, one position per magic."
---

# Chan London Bollinger Breakout

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Blog URL: https://epchan.blogspot.com/2011/01/high-frequency-trading-ideas.html
- Related Chan follow-up: https://epchan.blogspot.com/2011/03/momentum-strategies.html
- Article/comment locations: "High frequency trading ideas", Ernest/Ernie Chan, 2011-01-25; Ernie Chan comments on 2011-02-26, 2011-02-27, and 2013-08-05 discussing London Breakout, volatility breakout, Bollinger bands, and 9:00 GMT sampling.

## Mechanik

### Entry
For each configured FX symbol, default `EURUSD.DWX`:
- Execution period: `M1` bars inside the London morning window, with the
  09:00 GMT sample taken from the first valid M1 close at/after that timestamp.
- Compute a daily time-of-day Bollinger band from one price sampled at `09:00 GMT` on each of the previous `20` trading days.
- `BB_mid = SMA(sample_price, 20)`.
- `BB_upper = BB_mid + 2.0 * stdev(sample_price, 20)`.
- `BB_lower = BB_mid - 2.0 * stdev(sample_price, 20)`.
- From `09:00 GMT` to `12:00 GMT`, enter long if live price breaks above `BB_upper`.
- Enter short if live price breaks below `BB_lower`.
- One position per symbol/magic/day; no re-entry after an exit on the same day.

### Exit
- Primary: fixed maximum hold of 3 hours after entry.
- Profit cap: close at `+20` pips for EURUSD baseline, scaled by ATR for non-EURUSD symbols.
- Stop loss: close at `-20` pips for EURUSD baseline, scaled by ATR for non-EURUSD symbols.
- Force close before the configured session window ends.

### Stop Loss
Source explicitly says momentum strategies need stop losses. Baseline uses symmetric 20-pip stop/profit for EURUSD, P3 can sweep `10-40` pips or ATR-normalized equivalents.

### Position Sizing
V5 P2 fixed $1,000 risk equivalent, one FX position per magic number. No pyramiding.

### Zusätzliche Filter
- Trade only Monday-Thursday unless P3 explicitly tests Friday.
- Skip if current spread is above the symbol's P2 spread cap.
- Skip if fewer than 20 valid same-time daily samples exist.

## Concepts (was ist das für eine Strategie)
- [[concepts/momentum-breakout]] - primary
- [[concepts/time-of-day]] - secondary
- [[concepts/fx-session-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public Ernest Chan blog URL with named author and timestamped comments describing the rule. |
| R2 Mechanical | PASS | Time sample, Bollinger band, breakout direction, max hold, profit cap, and stop are deterministic. |
| R3 Data Available | PASS | FX symbols such as EURUSD.DWX are standard DWX instruments. |
| R4 ML Forbidden | PASS | Fixed indicator rule; no ML, online learning, adaptive sizing, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, drafted from Ernest Chan blog batch 3.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_1279_chan-es-vrp-reverse]] - another Chan momentum/one-day direction candidate from batch 2.

## Lessons Learned (während Pipeline-Lauf)
- TBD
