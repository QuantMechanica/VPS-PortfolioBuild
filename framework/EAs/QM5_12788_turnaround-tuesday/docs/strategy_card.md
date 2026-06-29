---
ea_id: QM5_12788
slug: turnaround-tuesday
type: strategy
source_id: sm-mining-sm012-turnaround-tuesday-2026
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Turnaround-Tuesday is a documented weekly calendar anomaly (down-Monday -> up-Tuesday reversal). Mined + walk-forward-validated in OWNER's SM strategy-mining campaign (SM_012): best out-of-sample in the campaign."
r2_mechanical: PASS
r2_reasoning: "Deterministic calendar rule: Monday close versus Friday close, Monday range versus ATR, close-location filter, Tuesday entry, ATR stop, Tuesday time exit."
r3_data_available: PASS
r3_reasoning: "GBPUSD.DWX H1 history; optional EURUSD.DWX and USDCAD.DWX FX-broad tests; calendar + ATR only; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no martingale/grid, single bounded position, hard ATR SL."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
expected_pf: 1.35
expected_dd_pct: 12
last_updated: 2026-06-29
---

# Turnaround Tuesday (SM_012 -> V5 port)

Build the weekly FX calendar anomaly from the approved card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12788_turnaround-tuesday.md`.

Mechanical rule:
- At the Tuesday 00:00-01:00 broker-time open, evaluate the just-finished Monday.
- Go long when Monday closed below the prior Friday close, Monday range is at least 0.5 x ATR(20), and Monday closed in the lower 40% of its range.
- Mirror short when Monday closed above the prior Friday close and in the upper 40% of its range.
- Use a hard ATR(20) stop, optional RR take-profit, and a Tuesday 22:00 broker-time exit.

Lead instrument is `GBPUSD.DWX`; `EURUSD.DWX` and `USDCAD.DWX` are authorized optional FX-broad tests.
