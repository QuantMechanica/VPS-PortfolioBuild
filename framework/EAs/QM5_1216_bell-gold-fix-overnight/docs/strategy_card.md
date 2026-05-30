---
ea_id: QM5_1216
slug: bell-gold-fix-overnight
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/gold-seasonality]]"
  - "[[concepts/intraday-session-effect]]"
indicators:
  - "[[indicators/london-fix-clock]]"
  - "[[indicators/session-clock]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 SSRN URL/author; R2 fixed London-fix clock entry/exit; R3 XAUUSD.DWX testable; R4 static non-ML one-position no grid/martingale."
---

# Bell Gold London-Fix Overnight Hold

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=6077836
- Named source author: Peter Bell, "Arbitrage Trading Strategy in Gold Futures" (SSRN, 2019/2026 posting).
- Location: SSRN abstract describes a gold strategy that is long gold overnight between London fixes and reports profits from 2000 to 2010.

## Mechanik

### Entry
1. Trade `XAUUSD.DWX` only.
2. At the configured London PM fix proxy time, open LONG at the next M5 bar open.
3. Default PM fix proxy: 15:00 London time.
4. Skip entry on UK holidays, early closures, and days with missing M5 bars around the fix window.

### Exit
- Close at the configured London AM fix proxy time on the next trading day.
- Default AM fix proxy: 10:30 London time.
- If the next AM fix proxy falls during an MT5 closure, close at the first tradable M5 bar after reopening.

### Stop Loss
- Hard stop at 1.0x H1 ATR(20).
- No same-day re-entry after stop.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.
- One position per magic number; no stacking across overlapping fix windows.

### Zusätzliche Filter
- Use broker-time conversion from London local time with DST handling.
- P3 sweep: PM entry proxy `{14:55, 15:00, 15:05 London}`, AM exit proxy `{10:25, 10:30, 10:35 London}`, stop `{0.8, 1.0, 1.2} * ATR(20)`.

## Concepts (was ist das für eine Strategie)
- [[concepts/gold-seasonality]] - primary
- [[concepts/intraday-session-effect]] - secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | SSRN URL is verifiable and names Peter Bell; source quality is weaker than peer-reviewed papers but meets relaxed R1 attribution. |
| R2 Mechanical | UNKNOWN | Long between two fixed London clock timestamps is fully deterministic. |
| R3 Data Available | UNKNOWN | XAUUSD.DWX is available; London fix times are external static schedule inputs. |
| R4 ML Forbidden | UNKNOWN | Static clock rule only; no ML, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1144_baur-gold-autumn]] - XAUUSD seasonal calendar effect.
- [[strategies/QM5_1205_bhatti-gold-vwap-ema]] - intraday XAUUSD VWAP/EMA continuation.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
