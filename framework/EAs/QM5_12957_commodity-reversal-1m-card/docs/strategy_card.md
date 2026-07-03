---
ea_id: QM5_12957
slug: commodity-reversal-1m-card
type: strategy
source_id: 05abad87-420d-5a51-8a9b-3c35ad795385
source_citation: "Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures. SSRN working paper. URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
sources:
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/cross-sectional-reversal]]"
  - "[[concepts/market-neutral-commodity-basket]]"
  - "[[concepts/commodity-overreaction]]"
indicators:
  - "[[indicators/n-day-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [cross-sectional-reversal, market-neutral, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "Monthly two-leg commodity basket package; estimate 5-10 packages/year after dispersion, energy-leg, spread, news, and one-package filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS academic commodity futures momentum/reversal source; R2 PASS deterministic monthly cross-sectional D1 return rank with ATR hard stops and time exits; R3 PASS XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, and XAGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 18.0
---

# One-Month Market-Neutral Commodity Reversal Basket

## Source

- Source: [[sources/YANG-COMM-REVERSAL-2017]]
- Primary citation: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures", SSRN, URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## Concept

Commodity futures reversal research documents that fixed-horizon commodity
moves can overshoot before reverting. This card converts that structural
premise into a low-frequency market-neutral DWX basket: once per month, rank
energy and precious-metal CFDs by their prior one-month D1 log return, buy the
worst performer, and short the best performer. A package is allowed only when
at least one selected leg is an energy symbol, keeping the sleeve materially
different from the existing XAU/XAG ratio book.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, no two-day oscillator pullback, no
  SMA(200) continuation filter, and no single-symbol commodity fanout.
- `QM5_12620_comm-reversal-4wk-xngusd` and
  `QM5_12621_comm-reversal-4wk-xtiusd`: this is a monthly cross-sectional
  market-neutral basket, not a weekly single-symbol overreaction threshold.
- `QM5_12733_xti-xng-xmom`: this fades the prior one-month winner versus loser
  across four commodities, not XTI/XNG relative momentum.
- `QM5_12577_cme-xauxag-ratio` and `QM5_12724_cme-xauxag-brk`: no gold/silver
  ratio, no z-score, no channel breakout, and an energy selected-leg
  requirement.
- WTI or XNG calendar/event sleeves: no weekday, month-of-year, WPSR, EIA,
  weather, hurricane, OPEC, refinery, storage, or expiry-window trigger.

## Market Universe

- `XTIUSD.DWX` - WTI oil; host chart and magic slot 0.
- `XNGUSD.DWX` - natural gas; magic slot 1.
- `XAUUSD.DWX` - gold; magic slot 2.
- `XAGUSD.DWX` - silver; magic slot 3.
- Logical basket symbol for Q02: `QM5_12709_COMM_REV1M_D1`.

## Timeframe

- Period: D1.
- Evaluate entries only on the first D1 bar of a new broker-calendar month.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no futures curve, inventory feed,
  CFTC data, CSV, API, analyst forecast, or external data call.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current D1 bar must be the first bar of a new broker-calendar month.
- Compute each symbol's prior `strategy_lookback_d1` completed-bar log return.
- Long leg: BUY the worst-returning symbol.
- Short leg: SELL the best-returning symbol.
- No entry unless best-minus-worst dispersion is at least
  `strategy_min_return_diff_pct`.
- No entry unless `strategy_require_energy_leg` is true and at least one of the
  selected long/short legs is `XTIUSD.DWX` or `XNGUSD.DWX`.
- No entry if an open package exists for this EA magic family.
- No entry if either selected leg exceeds its spread cap.

## Exit Rules

- Stop loss: fixed hard SL per leg at ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit a broken package if exactly two basket legs are not open.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Risk is divided equally across the two selected legs.
- Live risk, if ever approved later, is allocated only by the portfolio process.
- No `T_Live`, deploy manifest, AutoTrading, or portfolio-gate file is part of
  this card.

## Filters

- Only trade from `XTIUSD.DWX` on D1 with `qm_magic_slot_offset=0`.
- Skip entries when any basket symbol lacks D1 history.
- Skip entries when ATR is unavailable for either selected leg.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open package per month at most.

## Parameters To Test

- name: strategy_lookback_d1
  default: 21
  sweep_range: [15, 21, 42]
- name: strategy_min_return_diff_pct
  default: 4.0
  sweep_range: [2.0, 4.0, 6.0]
- name: strategy_require_energy_leg
  default: true
  sweep_range: [true]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 35
  sweep_range: [25, 35, 45]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 4000]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [100, 200, 350]

## Author Claims

No performance claim is taken from the source. The source is used only for
structural lineage around commodity momentum/reversal families; the QM Q02+
pipeline tests this mechanical DWX basket.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-10 monthly packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic commodity futures momentum/reversal paper.
- [x] R2 mechanical: fixed monthly gate, D1 return rank, energy selected-leg
  filter, ATR hard stops, and deterministic time exits.
- [x] R3 testable: all four target symbols exist in the DWX symbol matrix.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one basket package per magic family.
- [x] Non-duplicate: four-symbol monthly cross-sectional reversal basket with
  energy-leg requirement, not single-symbol reversal, XTI/XNG momentum,
  XAU/XAG ratio/breakout, WTI/XNG seasonality, or commodity RSI pullback.

## Framework Alignment

- no_trade: D1 and host-symbol guard, parameter guard, spread caps, monthly
  rebalance gate, and energy-leg requirement.
- trade_entry: monthly long-loser/short-winner commodity basket package.
- trade_management: monthly package flattening, broken-package repair, and
  max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial market-neutral commodity reversal basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
