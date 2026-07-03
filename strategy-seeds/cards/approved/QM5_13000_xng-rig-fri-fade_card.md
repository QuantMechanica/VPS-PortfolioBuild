---
copy_of: strategy-seeds/cards/xng-rig-fri-fade_card.md
ea_id: QM5_13000
slug: xng-rig-fri-fade
type: strategy
strategy_id: BAKERHUGHES-XNG-RIGCOUNT-FRI-FADE-2026
source_id: BAKERHUGHES-RIGCOUNT-2026
target_symbols: [XNGUSD.DWX]
logical_symbol: QM5_13000_XNG_RIGCOUNT_FRI_FADE_D1
period: D1
expected_trade_frequency: "D1 natural-gas last-workday rig-count displacement exhaustion fade; estimate 5-14 entries/year."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
---

# Baker Hughes XNG Rig-Count Friday Fade

Canonical card: `strategy-seeds/cards/xng-rig-fri-fade_card.md`.

Approved G0 summary: D1 `XNGUSD.DWX` exhaustion fade after a large final
broker-week displacement around the weekly Baker Hughes North America Rig Count
release cadence. The EA uses the last completed workday D1 bar as the natural
gas market reaction proxy, then enters opposite the displacement on the first
new-week D1 bar.

This is explicitly non-duplicate versus `QM5_12567` RSI commodity logic and
`QM5_12997_xng-rig-fri-mom` continuation logic. It is also separate from XNG
storage, freeze, hurricane, LNG, month, weekday, weekend, basket, and
metal-ratio sleeves.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the single symbol
`XNGUSD.DWX`. No live manifest, AutoTrading, portfolio gate, external runtime
data, grid, martingale, or ML is involved.

## Hypothesis

Large natural-gas D1 displacement into the Baker Hughes weekly rig-count window
can exhaust over short horizons when the bar closes near its directional
extreme. The sleeve fades that completed final-workday proxy on the first
new-week D1 bar.

## Source Citation

Primary source packet: `strategy-seeds/sources/BAKERHUGHES-RIGCOUNT-2026/`.
Baker Hughes Rig Count Overview and Summary Count URL:
https://rigcount.bakerhughes.com/. Baker Hughes Rig Count FAQ URL:
https://bakerhughesrigcount.gcs-web.com/rig-count-faqs.

## Rules

Rules are deterministic and use completed `XNGUSD.DWX` D1 OHLC, ATR, spread,
broker calendar state, and V5 framework guards only. No runtime Baker Hughes
download, analyst estimate, ML model, grid, martingale, or discretionary
override is permitted.

## Entry Rules

Enter only on a new `XNGUSD.DWX` D1 bar that is the first trading bar of a new
broker week. Use the prior completed Thursday or Friday D1 bar as the signal.
Require a large absolute log return, ATR-scaled displacement, and a close near
the directional extreme. Enter SELL after a qualifying positive displacement
and BUY after a qualifying negative displacement.

## Exit Rules

Stop loss is ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`. The EA exits
after `strategy_max_hold_days`, after favorable closed-bar reversion, after
adverse completed-close continuation, or by the standard Friday Close rule.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Baker Hughes XNG rig-count Friday fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | `strategy-seeds/cards/xng-rig-fri-fade_card.md` |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_13000_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | `work_items.id=b334559b-da23-4b4f-9991-44b7c60c4d36` |
