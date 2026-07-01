---
ea_id: QM5_12861
slug: xng-hurr-fade
type: strategy
strategy_id: EIA-NOAA-XNG-HURR-2026_S02
source_id: EIA-NOAA-XNG-HURR-2026
source_citation: "U.S. Energy Information Administration hurricane energy-market article plus NOAA/NHC climatology."
strategy_type_flags: [calendar-seasonality, weather-shock-proxy, failed-rally-mean-reversion, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12861_XNG_HURR_FADE_D1
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
expected_trade_frequency: "D1 natural-gas hurricane-window failed-spike fade; estimate 3-7 trades/year."
expected_trades_per_year_per_symbol: 5
g0_approval_reasoning: "R1 PASS official EIA hurricane energy-market source plus NOAA/NHC climatology; R2 PASS deterministic D1 hurricane-window failed-spike fade with ATR/SMA/channel/time exits; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 25.0
risk_class: high
ml_required: false
---

# XNG Hurricane Failed-Spike Fade

Approved copy of `strategy-seeds/cards/xng-hurr-fade_card.md`.

This card mechanizes a deterministic `XNGUSD.DWX` D1 hurricane-window exhaustion
fade. It shorts only after an August 15 through October 31 signal bar makes a
new short-term high, stretches above a slow mean, then closes with bearish
rejection near the low of the D1 range. It exits on SMA normalization, upside
channel invalidation, season end, max-hold, ATR stop, or the V5 Friday-close
guard.

It is not a duplicate of `QM5_12601_eia-xng-hurr-brk`; that sleeve is long-only
breakout continuation. It is also distinct from XNG winter freeze-off fade,
shoulder short, storage event logic, LNG breakout, broad monthly seasonality,
weekend gap, XTI/XNG baskets, metal/index sleeves, and `QM5_12567` RSI
commodity logic. No external runtime feed, ML, grid, martingale, portfolio gate
file, live manifest, or AutoTrading control is involved.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `artifacts/qm5_12861_build_result.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `93fd0dc3-09a4-479c-bbfd-6c9b8b3922d0` |
