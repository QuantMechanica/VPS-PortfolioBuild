---
ea_id: QM5_12754
slug: eia-wti-hurr-fade
type: strategy
source_id: EIA-WTI-HURRICANE-2025
source_citation: "U.S. Energy Information Administration. Refining industry risks from 2025 hurricane season. Today in Energy. URL https://www.eia.gov/todayinenergy/detail.php?id=65304"
sources:
  - "[[sources/EIA-WTI-HURRICANE-2025]]"
concepts:
  - "[[concepts/wti-hurricane-season]]"
  - "[[concepts/energy-supply-risk-exhaustion]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-risk-window, structural, mean-reversion, short-only, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12754_XTI_HURR_FADE_D1
period: D1
expected_trade_frequency: "Late-summer WTI hurricane-risk failed-spike fade; estimate 3-7 trades/year after D1 rejection and framework filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official EIA hurricane-season petroleum-risk source; R2 PASS deterministic D1 failed-spike mean-reversion rules; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# EIA WTI Hurricane-Season Failed-Spike Fade

## Source

- Source: [[sources/EIA-WTI-HURRICANE-2025]]
- Primary citation: U.S. Energy Information Administration, "Refining industry
  risks from 2025 hurricane season", Today in Energy, URL
  https://www.eia.gov/todayinenergy/detail.php?id=65304.

## Concept

EIA documents the Atlantic hurricane-season petroleum risk window and the U.S.
Gulf Coast refining/logistics exposure to severe storms. This card does not
forecast weather or consume hurricane, refinery, inventory, or EIA runtime
feeds. It uses that structural window only as a calendar gate, then requires the
WTI market itself to show an exhaustion bar before entering.

The card is a distinct WTI energy sleeve: it is short-only, late-summer gated,
and mean-reversion based. It is not the existing `QM5_12591_eia-wti-hurr-brk`
long-only hurricane breakout, not the `QM5_12593_eia-wti-ref-fade` refinery
turnaround shoulder-month two-sided fade, and not the WPSR, OPEC, ETF roll,
month/weekday, CAD/oil, XTI/XNG, XAU/XAG, or XNG RSI sleeves.

## Hypothesis

Hurricane-season supply-risk headlines can produce fast upside WTI repricing.
When the prior D1 bar stretches above a slow mean but then closes as a bearish
rejection bar inside the peak storm-risk months, the move may be an exhausted
risk premium rather than a confirmed trend. A short, time-bounded D1 fade back
toward the mean should add energy exposure that is structurally different from
index, metal, natural-gas, and existing WTI breakout/seasonal cards.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Evaluate only on a new D1 bar.
- Entry window is broker-calendar month `strategy_start_month` through
  `strategy_end_month`, default August through October.
- Short-only entry: SELL when the prior completed D1 bar is a bearish rejection
  bar above SMA(`strategy_mean_period`).
- The prior D1 high must be stretched above the SMA by at least
  `strategy_min_stretch_atr` ATR(`strategy_atr_period`).
- The prior D1 range must be at least `strategy_min_range_atr` times ATR.
- The prior D1 real body must be at least `strategy_min_body_ratio` of the
  D1 range.
- The prior close must sit in the lower `strategy_reversal_tail_ratio` of the
  bar's high-low range.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if the spread exceeds `strategy_max_spread_points`.
- Exit at or below SMA(`strategy_mean_period`), when the calendar window ends,
  or after `strategy_max_hold_days`.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The EA is short-only,
one-position-only, and uses a fixed ATR hard stop. No grid, martingale,
pyramiding, partial close, external feed, discretionary input, or ML component
is permitted.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only.

## Entry Rules

- Load the prior completed D1 bar, ATR(`strategy_atr_period`), and
  SMA(`strategy_mean_period`) on each new D1 bar.
- Require the signal bar month to be inside the configured hurricane fade
  window.
- Require `bar_close > SMA`.
- Require `(bar_high - SMA) / ATR >= strategy_min_stretch_atr`.
- Require `(bar_high - bar_low) >= strategy_min_range_atr * ATR`.
- Require `abs(bar_close - bar_open) / (bar_high - bar_low) >=
  strategy_min_body_ratio`.
- Require `bar_close < bar_open`.
- Require `(bar_close - bar_low) / (bar_high - bar_low) <=
  strategy_reversal_tail_ratio`.
- Enter SELL at market with an ATR hard stop.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit if the prior completed D1 close is at or below SMA(`strategy_mean_period`).
- Exit if the prior completed D1 bar is outside the configured hurricane fade
  window.
- Exit after `strategy_max_hold_days` calendar days.
- Framework Friday close remains enabled.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR, SMA, or prior-bar state is unavailable.
- Framework news, kill-switch, magic, stress-reject, and Friday-close guards
  remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_mean_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_min_range_atr
  default: 0.90
  sweep_range: [0.70, 0.90, 1.10, 1.30]
- name: strategy_min_body_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.45]
- name: strategy_reversal_tail_ratio
  default: 0.35
  sweep_range: [0.25, 0.35, 0.45]
- name: strategy_min_stretch_atr
  default: 1.10
  sweep_range: [0.90, 1.10, 1.40, 1.80]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_start_month
  default: 8
  sweep_range: [6, 7, 8]
- name: strategy_end_month
  default: 10
  sweep_range: [9, 10, 11]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from EIA. EIA is used only as official structural
lineage for hurricane-season petroleum supply risk. The edge claim is tested by
the QM Q02+ pipeline on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-7 trades/year during the
  hurricane-risk fade window.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA hurricane-season petroleum-risk article.
- [x] R2 mechanical: fixed calendar window, D1 failed-spike/rejection rules,
  ATR stop, SMA mean exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] No duplicate of `QM5_12591`: this fades failed upside spikes instead of
  buying hurricane-season breakouts.
- [x] No duplicate of `QM5_12593`: this uses the EIA hurricane peak window and
  short-only upside-exhaustion logic, not refinery-turnaround shoulder-month
  two-sided mean reversion.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, hurricane-window calendar gate,
  parameter guard, and spread cap.
- trade_entry: prior D1 bearish rejection bar above SMA with ATR stretch,
  minimum range, and close-location confirmation.
- trade_management: mean exit, window exit, max-hold exit, and ATR hard stop.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI hurricane-season failed-spike fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
