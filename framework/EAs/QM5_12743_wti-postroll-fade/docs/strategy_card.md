---
ea_id: QM5_12743
slug: wti-postroll-fade
type: strategy
source_id: CME-WTI-EXPIRY-BRK-2026
source_citation: "CME Group. Chapter 200 Light Sweet Crude Oil Futures; Understanding Futures Expiration & Contract Roll. URLs https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf and https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
sources:
  - "[[sources/CME-WTI-EXPIRY-BRK-2026]]"
concepts:
  - "[[concepts/wti-roll-pressure]]"
  - "[[concepts/post-expiry-flow-reversion]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-flow, post-roll, mean-reversion, atr-hard-stop, low-frequency, symmetric-long-short]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI post-roll impulse fade; estimate 6-10 entries/year after the post-roll window, impulse, spread, and one-position filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS CME rulebook/education source packet; R2 PASS deterministic post-expiry calendar window, D1 impulse fade, SMA reversion exit, ATR stop, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# WTI Post-Roll Impulse Fade

## Source

- Source: [[sources/CME-WTI-EXPIRY-BRK-2026]]
- Primary citation: CME Group, "Chapter 200 Light Sweet Crude Oil Futures", URL https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf.
- Supplement: CME Group, "Understanding Futures Expiration & Contract Roll", URL https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll.
- Supplement: CME Group, "Crude Oil Futures Contract Specs", URL https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.

## Concept

CME WTI contracts have a recurring monthly termination and roll cycle. This
card does not trade a futures curve or ingest CME data at runtime. It uses the
roll structure only to define a repeatable post-expiry window, then fades
stretched `XTIUSD.DWX` D1 impulses after the default expiry-breakout window has
passed.

This is intended as a low-frequency WTI sleeve that is different from the
current index, XAU, and XNG book exposure. It is also deliberately different
from `QM5_12600_cme-wti-exp-brk`: that EA follows channel breakouts during the
expiry window, while this card starts after that default window and takes the
opposite side of a short post-roll impulse.

## Hypothesis

Position management around WTI expiry and roll can leave short-lived pressure
after the front-month transition. Once the immediate breakout window is over, a
large D1 impulse that remains stretched away from a short mean may mean-revert
over the next few sessions.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  volume, open interest, CME feed, expiry calendar API, CSV, or analyst input.

## Entry Rules

- Evaluate only on a new D1 bar.
- Approximate the CME WTI expiry day with the same deterministic rule used by
  the existing expiry-window build: the third business day before the 25th
  calendar day, after adjusting the 25th backward if it falls on a weekend.
- Entry is allowed only when the prior completed D1 bar is between
  `strategy_post_start_days` and `strategy_post_end_days` calendar days after
  the approximated expiry day.
- Compute the prior completed D1 close-to-close return over
  `strategy_impulse_days`.
- Short fade: if the impulse return is at or above
  `strategy_min_abs_return_pct`, the prior close is above
  SMA(`strategy_reversion_sma`), and the prior close sits in the upper part of
  its own D1 range, SELL `XTIUSD.DWX`.
- Long fade: if the impulse return is at or below
  `-strategy_min_abs_return_pct`, the prior close is below
  SMA(`strategy_reversion_sma`), and the prior close sits in the lower part of
  its own D1 range, BUY `XTIUSD.DWX`.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when the prior completed D1 close recovers above
  SMA(`strategy_reversion_sma`).
- Close a short when the prior completed D1 close falls below
  SMA(`strategy_reversion_sma`).
- Close when the post-roll window ends.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR, SMA, or D1 OHLC history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short mean-reversion.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_post_start_days
  default: 3
  sweep_range: [3, 4, 5]
- name: strategy_post_end_days
  default: 7
  sweep_range: [6, 7, 8]
- name: strategy_impulse_days
  default: 3
  sweep_range: [2, 3, 4]
- name: strategy_min_abs_return_pct
  default: 2.0
  sweep_range: [1.0, 2.0, 3.0]
- name: strategy_reversion_sma
  default: 10
  sweep_range: [8, 10, 14]
- name: strategy_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.70]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from the CME sources. The sources are used
only for structural lineage around WTI contract expiration and roll mechanics.
The Q02+ pipeline tests the deterministic post-roll fade on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-10 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME rulebook and CME education pages.
- [x] R2 mechanical: fixed post-expiry calendar window, D1 impulse fade, SMA
  reversion exit, ATR stop, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: not XAU/XAG, not XTI/XNG, not XNG, not WTI event/news,
  not WTI month/weekday seasonality, not WTI time-series momentum, not WTI
  reversal, not early-month ETF roll fade, and not `QM5_12600` expiry breakout.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: post-expiry D1 impulse fade after the immediate roll breakout
  window.
- trade_management: post-roll window end, SMA mean-reversion, and max-hold exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI post-roll impulse fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
