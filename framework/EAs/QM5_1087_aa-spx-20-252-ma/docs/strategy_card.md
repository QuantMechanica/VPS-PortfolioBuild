---
ea_id: QM5_1087
slug: aa-spx-20-252-ma
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/market-timing]]"
  - "[[concepts/downside-protection]]"
indicators:
  - "[[indicators/twenty-day-simple-moving-average]]"
  - "[[indicators/two-hundred-fifty-two-day-simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 source URL present; R2 explicit SMA20/SMA252 entry/exit; R3 SP500.DWX backtest-only plus DWX CFD ports; R4 fixed crossover no ML/martingale."
expected_trades_per_year_per_symbol: 12
---

# Alpha Architect 20/252 SMA Risk Switch

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Wesley Gray, PhD, "A Simulation Study on Simple Moving Average Rules", 2014-07-28, https://alphaarchitect.com/a-simulation-study-on-simple-moving-average-rules/

## Mechanik

### Entry
Daily at the close on a configured index or CFD:
- Compute the 20-day simple moving average of closes.
- Compute the 252-day simple moving average of closes.
- If SMA(20) > SMA(252), hold long risk exposure.
- If SMA(20) <= SMA(252), hold cash/flat.

### Exit
- Close the long position at the daily close when SMA(20) crosses below or equals SMA(252).
- Re-enter at the daily close when SMA(20) crosses back above SMA(252).

### Stop Loss
- Source tests risk-on/risk-off switching and does not define an intra-signal stop.
- Build default: ATR stop and V5 account-level risk guard.

### Position Sizing
- Long-only single asset exposure when risk-on.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Daily close evaluation only.
- Minimum 252 daily bars required before first trade.
- Optional no-trade filter around extreme spread at daily close.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] — primary
- [[concepts/market-timing]] — secondary
- [[concepts/downside-protection]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Wesley Gray, PhD, dated Alpha Architect post. |
| R2 Mechanical | PASS | Explicit 20-day versus 252-day moving average risk-on/risk-off rule. |
| R3 Data Available | PASS | Original S&P 500 rule is testable on SP500.DWX backtest-only and portable to live-routable index/FX/commodity CFDs. |
| R4 ML Forbidden | PASS | Fixed moving-average crossover rule; no ML or adaptive parameter learning. |

## R3
Primary port candidates: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, and liquid FX majors.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Alpha Architect blog.

## Verwandte Strategien
- [[strategies/QM5_1086_aa-dpm-tmom-ma]] — monthly TMOM/SMA downside-protection variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
