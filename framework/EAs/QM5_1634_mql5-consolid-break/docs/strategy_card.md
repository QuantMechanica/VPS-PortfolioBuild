---
ea_id: QM5_1634
slug: mql5-consolid-break
type: strategy
source_id: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX]
period: H1
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
---

# MQL5 Consolidation Range Breakout — Approval Receipt

This is a concise receipt, not a verbatim copy. The authoritative approved card
remains
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1634_mql5-consolid-break.md`.

## Source

- Allan Munene Mutiiria, “Developing an Expert Advisor (EA) based on the
  Consolidation Range Breakout strategy in MQL5,” 2024-07-17.
- https://www.mql5.com/en/articles/15311

## Mechanical Rules

- Target symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`.
- Timeframe: H1.
- Define a consolidation from the preceding completed-bar high-low range.
- Buy when the next completed bar closes above the consolidation high.
- Sell when it closes below the consolidation low.
- Place the stop beyond the range, subject to a minimum ATR distance.
- Use a fixed risk/reward target; optionally exit on a close back through the
  range midpoint.
- One position per symbol/magic; no ML, grid, martingale, or adaptive sizing.

## Approval

R1–R4 and G0 are `PASS` / `APPROVED` in the authoritative farm card. Backtests
use `RISK_FIXED=1000`; no live or portfolio artifacts are part of this build.
