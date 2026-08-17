---
ea_id: QM5_21505
slug: xag-weekly-lowvol-momentum
type: strategy
source_id: 28681f5d-aa78-584e-9698-750d1402e485
sources:
  - "[[sources/zhao-ding-yu-kang-2026]]"
concepts:
  - "[[concepts/short-term-time-series-momentum]]"
  - "[[concepts/order-flow-proxy]]"
  - "[[concepts/commodity-momentum]]"
indicators:
  - "[[indicators/lookback-return]]"
  - "[[indicators/tick-volume]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [time-series-momentum, weekly-rebalance, volume-gate, single-symbol, atr-hard-stop, both-direction]
target_symbols: [XAGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21505_XAG_WEEKLY_LOWVOL_MOM_D1
period: D1
expected_trade_frequency: "Weekly evaluation, entry only when trailing 5-bar volume sum is in the bottom tercile of its trailing baseline (roughly 33% of weeks); estimate 15-18 trades/year on XAGUSD."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Zhao, Ding, Yu & Kang (SSRN 6425598, 2026): the paper's residual (non-flow) return component positively predicts next-week return; the residual is by construction the part of the weekly move NOT explained by heavy speculator trading, motivating a low-volume filter as the complementary proxy to the flow-driven reversal card."
r2_mechanical: PASS
r2_reasoning: "Deterministic: rank the trailing week by tick-volume-sum percentile; if in the low-volume tercile, continue (trade with) the sign of that week's return next week; ATR hard stop; no discretion."
r3_data_available: PASS
r3_reasoning: "XAGUSD.DWX D1 close and native MT5 tick volume are both natively available; no COT/position-flow feed is used. Tick volume is used only as an observable PROXY for the absence of flow intensity, not as a replication of the paper's investor-position decomposition."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive/PnL-dependent parameters (volume percentile depends only on price/volume history, not the strategy's own PnL); no grid/martingale."
pipeline_phase: G0
last_updated: 2026-08-13
expected_pf: 1.13
expected_dd_pct: 23.0
risk_class: medium
ml_required: false
g0_approval_reasoning: "R1 lineage recorded to one source; R2 PASS mechanical weekly return continuation gated by the native low-tick-volume tercile, with explicit flip, ATR, and time exits and a plausible 16 trades/year cadence; R3 PASS on XAGUSD.DWX using only native OHLC and tick volume, with no COT or external feed dep"
---

# XAGUSD Weekly Low-Volume Momentum Continuation (Residual-Proxy)

## Source

- Source: [[sources/zhao-ding-yu-kang-2026]]
- Citation: Shen Zhao, Yiyi Ding, Jianfeng Yu, Wenjin Kang (2026). "Momentum and
  Reversal on the Short-Term Horizon: Evidence from Commodity Markets." SSRN
  Working Paper, abstract_id=6425598.
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598
- Key finding used here: the residual return component (the part of a
  weekly move NOT attributable to speculators' net trading flow)
  "significantly and positively predicts next-week return"; the flow
  component does the opposite. By construction, weeks with LOW trading
  intensity should have a larger residual-to-flow ratio in their return,
  so a low-volume filter is used here as the observable complement to the
  high-volume fade tested in the sibling card.

## Edge / Thesis And Disclosed Porting Gap

Same disclosed gap as the sibling cards in this batch: QM has no runtime
COT/investor-position feed, so the paper's actual flow/residual decomposition
cannot be implemented. This card and `QM5_21504_xng-weekly-flowrev-volume`
together form a matched pair testing the same volume-as-flow-proxy
hypothesis from opposite ends: `QM5_21504` fades high-volume weeks (proxy
for flow-dominated, reversal-prone moves) on XNGUSD; this card continues
low-volume weeks (proxy for residual-dominated, momentum-prone moves) on
XAGUSD. The two cards are intentionally on different symbols and are each
independependently falsifiable -- neither depends on the other's Q02 result, and
the pairing exists only to give a cleaner overall read on whether volume is
a useful observable proxy for the paper's unobservable flow/residual split.

## Markets And Timeframe

- Target symbol: `XAGUSD.DWX` only.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: native MT5 D1 OHLC and tick volume on XAGUSD only; no
  external feed, no position/COT data, no ML model.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Every 5 completed D1 bars, compute:
  - `weekly_ret = (Close[0] - Close[5]) / Close[5]` using completed bars only.
  - `weekly_vol = sum(TickVolume[1..5])` over the same 5-bar window.
- Compute the rolling `strategy_vol_lookback`-window (default 40 prior
  5-bar windows, i.e. roughly 200 D1 bars) percentile rank of `weekly_vol`
  against its own trailing history.
- `LOW_VOL_WEEK` is true when `weekly_vol` is at or below the
  `strategy_vol_percentile` percentile (default: 33rd percentile) of that
  rolling window.
- If `LOW_VOL_WEEK` is true and `weekly_ret != 0`: open a position in the
  SAME direction as `weekly_ret` (continuation). If `weekly_ret > 0`, go
  long; if `weekly_ret < 0`, go short.
- If `LOW_VOL_WEEK` is false, take no new entry this cycle.
- If a position is already open and a new continuation signal points the
  same direction: hold, do not re-enter.
- No entry if XAGUSD spread exceeds `strategy_max_spread_points`.
- No entry if fewer than `strategy_vol_lookback * 5 + 5` completed D1 bars of
  history are available.

## Exit Rules

- Time exit: close after `strategy_max_hold_bars` completed D1 bars (default
  10, i.e. two weekly cycles) -- wider than the reversal sibling card since
  a continuation thesis is expected to persist somewhat longer than a
  single-week reversal.
- Signal-flip exit: if a subsequent low-volume-week re-evaluation produces a
  continuation signal opposite the held position's direction, close and
  reverse.
- Stop loss: fixed hard SL at `strategy_atr_sl_mult` x `ATR(strategy_atr_period,
  D1)` from entry.
- Friday close remains enabled by the V5 framework.
- No trailing stop, no take-profit, no partial close in v1.

## Filters

- Only trade `XAGUSD.DWX` on D1.
- Low-volume-tercile gate suppresses entries during heavy-volume weeks
  (those are left for the complementary high-volume reversal hypothesis
  tested on a different symbol/card).
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Both long and short (direction follows the low-volume week's return sign).
- One open position per magic.
- No pyramiding, gridding, martingale, or scale-in.
- No partial close.

## Parameters To Test

- name: strategy_vol_lookback
  default: 40
  sweep_range: [26, 40, 60]
- name: strategy_vol_percentile
  default: 33
  sweep_range: [20, 33, 40]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 3.5]
- name: strategy_max_hold_bars
  default: 10
  sweep_range: [7, 10, 15]
- name: strategy_max_spread_points
  default: 250
  sweep_range: [150, 250, 400]

## Dedup Assessment

| Card | Overlap? | Verdict |
|---|---|---|
| QM5_12900_xag-xau-filter-trend (cards_review) | XAGUSD trend gated by XAUUSD SMA direction filter | DIFFERENT MECHANISM -- dual-SMA cross-asset filter vs single-symbol volume-gated weekly return continuation; no cross-asset read here |
| QM5_12902_xag-vol-regime-donchian (cards_review) | XAGUSD Donchian-20 breakout gated by ATR(5)>ATR(20) vol-EXPANSION | Different entry primitive (Donchian channel breakout vs 5-bar return sign) and different gate variable (ATR-ratio expansion vs tick-volume-sum percentile) |
| QM5_21502_xau-weekly-tsmom / QM5_21503_xti-weekly-tsmom-lowvol | Sibling weekly TSMOM cards, same source | DIFFERENT GATE -- those use no gate / an ATR-percentile vol-regime gate; this card uses a tick-volume-percentile gate on a third symbol (XAG) |
| QM5_21504_xng-weekly-flowrev-volume | Sibling volume-gated card, same source, opposite tercile and opposite direction | Matched-pair design, deliberately distinct: HIGH-volume fade on XNG vs LOW-volume continuation on XAG; different symbol, different gate threshold, different trade direction logic |

## Low-Correlation Argument

- Continuation (momentum), not reversal -- structurally opposite trade
  direction logic from the volume-fade sibling card.
- Volume-percentile gate (tercile, low side) is distinct from both the
  unconditional TSMOM card and the ATR-percentile vol-regime TSMOM card in
  this same batch.
- No existing XAG card conditions a return-continuation signal on trailing
  tick volume.

## Net-Cost Check

XAGUSD commission ~$0.4-$6.7/round-trip. ~16 trades/year with a 10-bar max
hold keeps turnover moderate; low-volume-week entries should also see
tighter/typical spreads (avoiding the volatile high-volume tail), keeping
net close to gross.

## Initial Risk Profile

- expected_pf: 1.13
- expected_dd_pct: 23.
- expected_trade_frequency: approximately 15-18 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Framework Alignment

- no_trade: D1 XAGUSD.DWX guard, history-length guard, low-volume-tercile
  gate, spread cap.
- trade_entry: continuation of trailing 5-bar return, gated by tick-volume
  percentile.
- trade_management: ATR hard stop, 10-bar max-hold time stop, signal-flip
  reversal.
- trade_close: signal-flip close/reopen, ATR stop, time stop, framework
  Friday close.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED | `D:\QM\strategy_farm\artifacts\cards_approved\QM5_21505_xag-weekly-lowvol-momentum.md` |
