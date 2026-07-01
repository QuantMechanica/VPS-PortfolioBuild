---
ea_id: QM5_12858
slug: rigcount-fri-mom
type: strategy
strategy_id: BAKERHUGHES-RIGCOUNT-FRI-MOM-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
source_citation: "Baker Hughes. Rig Count Overview and Summary Count. URL https://rigcount.bakerhughes.com/; Baker Hughes Rig Count FAQ. URL https://bakerhughesrigcount.gcs-web.com/rig-count-faqs"
strategy_type_flags: [calendar-seasonality, n-period-max-continuation, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
expected_trade_frequency: "D1 WTI last-workday rig-count displacement continuation; estimate 8-18 trades/year."
expected_trades_per_year_per_symbol: 12
g0_approval_reasoning: "R1 PASS official Baker Hughes rig-count source packet; R2 PASS deterministic D1 first-new-week entry after large last-workday WTI displacement with close-location confirmation, ATR stop, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
---

# Baker Hughes Rig-Count Friday Momentum

Approved copy of `strategy-seeds/cards/rigcount-fri-mom_card.md`.

This card mechanizes a deterministic WTI D1 rig-count reaction proxy. Baker
Hughes publishes the North America rig-count report weekly on the last workday,
normally Friday. The EA does not read the report; it uses the completed final
broker-week `XTIUSD.DWX` bar as the market reaction proxy, enters in the same
direction on the first new-week D1 bar after a large directional close near the
bar extreme, then exits by a short time stop, adverse-close rule, or ATR hard
stop.

It is not a duplicate of static WTI weekday/month rules, weekend-gap sleeves,
WPSR/Cushing/refinery/hurricane/OPEC/SPR/expiry/ETF-roll/seasonality rules,
XTI/XNG or metals baskets, XNG sleeves, or `QM5_12567` RSI commodity logic.
It uses no external runtime feed, ML, grid, martingale, portfolio gate file,
live manifest, or AutoTrading control.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12858_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `4d4748c4-e519-49eb-8a86-00c74f1fbba5` |
