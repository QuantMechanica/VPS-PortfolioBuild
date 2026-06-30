---
ea_id: QM5_12819
slug: xng-thu-fade
type: strategy
source_id: MEEK-HOELSCHER-XNG-DOW-2023
source_citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023. DOI https://doi.org/10.1080/23322039.2023.2213876; open pointer https://www.econstor.eu/handle/10419/304091"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12819_XNG_THU_FADE_D1
period: D1
expected_trade_frequency: "Weekly D1 natural-gas Thursday-calendar fade sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.08
expected_dd_pct: 23.0
g0_approval_reasoning: "R1 PASS peer-reviewed petroleum and natural-gas day-of-week source; R2 PASS deterministic Thursday D1 short/next-bar flat rule with ATR stop; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# XNG Thursday Calendar Fade

## Source

Meek, H. and Hoelscher, S. A., "Day-of-the-week effect: Petroleum and
petroleum products", Cogent Economics and Finance 11(1), 2023, DOI
https://doi.org/10.1080/23322039.2023.2213876. Open pointer:
https://www.econstor.eu/handle/10419/304091.

## Concept

The source reports Natural Gas day-of-week structure, including a negative
Thursday effect. This card mechanizes only that leg: sell `XNGUSD.DWX` on the
broker-calendar Thursday D1 bar and flatten on the first subsequent
non-Thursday D1 bar.

## Entry Rules

- Trade only `XNGUSD.DWX` on D1.
- Enter short only when the current broker-calendar D1 bar is Thursday.
- Use ATR(20) with a 2.75x hard stop.
- Skip when spread exceeds 2500 points or a position is already open.

## Exit Rules

- Close on the first new D1 bar that is not Thursday.
- Close after one calendar day as a stale-position guard.
- No grid, martingale, pyramiding, partial close, trailing stop, external data,
  or ML.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XNGUSD.DWX` D1
setfile. No live, AutoTrading, T_Live, deploy manifest, or portfolio gate
artifact is touched.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | strategy-seeds/cards/approved/QM5_12819_xng-thu-fade_card.md |
| Q02 Baseline Screening | 2026-06-30 | QUEUED | work_items/28150970-d62e-4b55-9d77-dda6ad847396 |
