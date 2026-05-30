---
ea_id: QM5_10351
slug: et-rally-x
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "rajesheck, Principle based day trading strategies, Elite Trader, 2016-12-07, https://www.elitetrader.com/et/threads/principle-based-day-trading-strategies.304974/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/rally-retest]]"
  - "[[concepts/event-window-entry]]"
indicators:
  - "[[indicators/price-change-percent]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
period: M1
expected_trade_frequency: "Intraday percent-rally retest rule with max one setup per direction per session; conservative estimate 60 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/author present; R2 mechanical percent-rally retest with exits and ~60 trades/year/symbol; R3 DWX FX/metal/index testable; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader Percent Rally Retest

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/principle-based-day-trading-strategies.304974/
- Author / handle: `rajesheck`.
- Date: 2016-12-07.
- Location: post #1. The post defines an intraday rally threshold, a wait period, a retest/crossover entry window, and reversal-based exit.

## Mechanik

### Entry
- Evaluate M1 bars during the instrument's primary liquid session.
- Define session anchor price `P` as the first tradable M1 close after the session open.
- Long setup when price rallies at least `X%` from `P` within 20 minutes.
- Wait 2 completed M1 bars after a gradual rally; use fixed V5 baseline of 2 minutes because the source's faster-rally branch is discretionary.
- Enter long when price retests and crosses back above the rally threshold before 60 minutes have elapsed from the first threshold touch.
- Short setup mirrors the rule: price falls at least `X%` from `P` within 20 minutes, wait 2 bars, enter short when price retests and crosses back below the threshold within 60 minutes.
- Enter one position per symbol/magic only.

### Exit
- Exit long immediately when price crosses back below the rally threshold.
- Exit short immediately when price crosses back above the decline threshold.
- Time exit at session close.
- Friday close enforced by framework.

### Stop Loss
- Threshold-reversal exit is the primary stop.
- Protective emergency stop: `1.0 * ATR(14,M5)` from entry.
- Skip trade when threshold distance is less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Use source X defaults by segment: Forex 0.12%, index futures/CFD 0.18%, commodities 0.50%.
- One long and one short setup maximum per session.
- Skip entries when spread exceeds 2.5x rolling median spread.

## Concepts
- [[concepts/intraday-momentum]] - first 20 minutes define a directional impulse.
- [[concepts/rally-retest]] - entry occurs on recross of the impulse level after waiting.
- [[concepts/event-window-entry]] - source limits the valid entry to a 60-minute window.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `rajesheck`. |
| R2 Mechanical | PASS | Percent move, time windows, entry recross, and reversal exit are explicit after deterministic baseline choices. |
| R3 DWX-testbar | PASS | Forex, index CFD, and commodity CFD percentage moves are directly testable on DWX symbols. |
| R4 No ML | PASS | Fixed thresholds and time windows; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`.

## Author Claims
- The source states the same principle used for entry should govern exit.
- The source provides different percent thresholds for index, equity, forex, and commodity segments.

## Parameters To Test
- Forex X threshold: 0.08%, 0.12%, 0.16%.
- Index X threshold: 0.12%, 0.18%, 0.24%.
- Commodity X threshold: 0.30%, 0.50%, 0.70%.
- Wait bars: 2, 5, 10.
- Entry window: 30, 60, 90 minutes.

## Initial Risk Profile
Intraday impulse/retest profile. Main risk is whipsaw around the threshold after an early-session move.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
