---
ea_id: QM5_10514
slug: mql5-frac-stop
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Scriptor idea, Vladimir Karputov / barabashkakvn MQL5 code, Fractured Fractals, MQL5 CodeBase, published 2018-04-18, https://www.mql5.com/en/code/20127"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/fractals]]"
  - "[[concepts/pending-stop-breakout]]"
indicators: [Fractals]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Fractal structure pending-stop entries on H1 with order lifetime; conservative estimate is 35-100 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL present; R2 deterministic fractal pending-stop entry/exit with 60 trades/year/symbol estimate; R3 DWX FX/metals testable; R4 fixed non-ML one-slot rules."
---

# MQL5 Fractured Fractals Pending Stop

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Scriptor idea, Vladimir Karputov / barabashkakvn MQL5 code, "Fractured Fractals", MQL5 CodeBase, published 2018-04-18, URL https://www.mql5.com/en/code/20127.
- Source location: page states a Buy Stop condition occurs when two upper fractals exist and the latest upper fractal is higher than the previous upper fractal; Buy Stop SL is set at the latest lower fractal, and sell conditions are opposite.

## Mechanik

### Entry
- Evaluate confirmed Fractals on completed H1 bars only after their confirmation lag.
- Long setup:
  - Latest confirmed upper fractal is above the prior confirmed upper fractal.
  - Place Buy Stop at the latest upper fractal price plus a small spread/point buffer.
  - Initial SL at the latest confirmed lower fractal.
  - Pending order expires after fixed source lifetime.
- Short setup:
  - Latest confirmed lower fractal is below the prior confirmed lower fractal.
  - Place Sell Stop at the latest lower fractal price minus a small spread/point buffer.
  - Initial SL at the latest confirmed upper fractal.
  - Pending order expires after fixed source lifetime.
- No active position or pending order for this symbol/magic.

### Exit
- Source trails position SL by the latest opposite fractal.
- P2 baseline: keep fractal SL trailing as a bounded structural stop variant; TP = 1.5R.
- Cancel stale pending orders at the configured lifetime.

### Stop Loss
- Opposite latest confirmed fractal with ATR floor if the fractal distance is too tight.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position/pending order per symbol/magic.
- Parameter sweep: fractal confirmation timeframe, pending buffer, order lifetime, TP R-multiple.
- Skip high-impact news windows when QM news filter is active.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Fractal ordering, pending stop placement, order lifetime, and opposite-fractal stop are deterministic. |
| R3 DWX-testbar | PASS | Fractal OHLC logic and stop orders are portable to DWX FX, metals, oil, and index CFDs. |
| R4 No ML | PASS | Fixed structural rules, no ML, no grid/martingale; V5 limits to one active slot. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10510_mql5-absorb-stop]] - pending-stop breakout family.
- [[strategies/QM5_10512_mql5-donchian-ctr]] - structural channel expansion family.

## Lessons Learned
- TBD during pipeline run.
