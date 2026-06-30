---
ea_id: QM5_12829
slug: wti-cushing-fade
type: strategy
strategy_id: EIA-CUSHING-STORAGE-2021_S02
source_id: EIA-CUSHING-STORAGE-2021
source_citation: "U.S. Energy Information Administration. Crude oil inventories at Cushing, Oklahoma, remain low after summer draws. Today in Energy, October 21, 2021. URL https://www.eia.gov/todayinenergy/detail.php?id=49636"
source_citations:
  - type: official_energy_statistics
    citation: "U.S. Energy Information Administration. Crude oil inventories at Cushing, Oklahoma, remain low after summer draws. Today in Energy, October 21, 2021."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=49636"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-CUSHING-STORAGE-2021]]"
concepts:
  - "[[concepts/wti-delivery-hub-tightness]]"
  - "[[concepts/failed-breakout-mean-reversion]]"
indicators:
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-mean-reversion, structural-energy, weekly-gate, failed-breakout, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly-gated WTI Cushing tightness failed-spike fade on D1; estimate 3-8 entries/year after channel, reversal, trend, and spread filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
expected_pf: 1.06
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS single official EIA source; R2 PASS deterministic weekly D1 failed-breakout fade, SMA trend, ATR stop, fast-SMA and time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI Cushing Failed-Spike Fade

## Source

- Source: [[sources/EIA-CUSHING-STORAGE-2021]]
- Primary citation: U.S. Energy Information Administration, "Crude oil
  inventories at Cushing, Oklahoma, remain low after summer draws", Today in
  Energy, October 21, 2021.

## Concept

EIA identifies Cushing, Oklahoma as the NYMEX WTI delivery point and discusses
periods when Cushing inventories remain low after sustained draws. This card
does not import Cushing inventories into MT5. It uses a Darwinex-native D1
price proxy for the opposite side of `QM5_12828_wti-cushing-brk`: when a WTI
upside tightness spike pierces a multi-month channel but fails by the close,
short the relief move back toward a fast mean.

This is deliberately different from:

- `QM5_12828_wti-cushing-brk`: that card is long-only continuation after a
  confirmed upside breakout; this card is short-only failed-breakout relief.
- WTI product-demand, WPSR, OPEC, hurricane, SPR, expiry, ETF-roll, CAD/USD,
  oil-metal, XTI/XNG, and month-of-year sleeves: no event feed, cross-asset
  leg, fixed meeting date, futures roll, ratio package, or broad seasonality.
- `QM5_12780_wti-52w-anchor`: this is not monthly 252-D1 high/low momentum.
- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.

## Hypothesis

Failed WTI upside spikes should revert when the market briefly prices a
tightness shock but cannot hold the breakout close. The rule waits for a
weekly D1 exhaustion bar inside an existing uptrend, then shorts only if the
signal bar pierces the prior channel high and closes weakly back inside it.

## Rules

- Host/traded symbol: `XTIUSD.DWX` D1, magic slot 0.
- Evaluate entries only on the first D1 bar of a new broker-calendar week.
- Build a `strategy_channel_lookback_d1` high channel from completed D1 bars
  excluding the most recent completed signal bar.
- Short entry only:
  - signal high pierces the prior channel high by at least
    `strategy_min_pierce_margin_pct`;
  - signal close is below signal open;
  - signal close is back below the prior channel high;
  - signal close is in the lower `strategy_reversal_close_ratio` of the signal
    bar's range;
  - prior close is above the slow D1 SMA and fast D1 SMA is above slow D1 SMA;
  - `strategy_return_lookback_d1` return is at least
    `strategy_min_return_pct` and no more than `strategy_max_return_pct`.
- Exit on close below the fast SMA, `strategy_max_hold_days`, Friday close, or
  ATR hard stop.
- No long entries, pyramiding, grid, martingale, partial close, runtime
  inventory data, external files, APIs, or ML.

## Risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Hard stop: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- One open XTI position per magic.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Parameters To Test

- name: strategy_channel_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_return_lookback_d1
  default: 21
  sweep_range: [14, 21, 42]
- name: strategy_fast_sma_period
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_slow_sma_period
  default: 126
  sweep_range: [84, 126, 168]
- name: strategy_min_pierce_margin_pct
  default: 0.50
  sweep_range: [0.25, 0.50, 0.75]
- name: strategy_min_return_pct
  default: 4.0
  sweep_range: [2.0, 4.0, 6.0]
- name: strategy_max_return_pct
  default: 22.0
  sweep_range: [14.0, 22.0, 30.0]
- name: strategy_min_bar_range_atr
  default: 0.80
  sweep_range: [0.60, 0.80, 1.10]
- name: strategy_reversal_close_ratio
  default: 0.45
  sweep_range: [0.35, 0.45, 0.55]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 14
  sweep_range: [7, 14, 21]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA source with URL.
- [x] R2 mechanical: fixed weekly gate, fixed channel/reversal/SMA/return
  thresholds, ATR hard stop, SMA close, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the Darwinex symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or multiple positions per magic.
- [x] Portfolio intent: adds a structural crude-oil relief sleeve distinct
  from the current XAU/SP500/NDX/XNG book and not a duplicate of existing WTI
  event, calendar, roll, ratio, petro-FX, or generic RSI commodity logic.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "D1/XTIUSD.DWX guard, one magic slot, parameter sanity, spread cap."
  trade_entry:
    used: true
    notes: "Weekly D1 short-only failed Cushing tightness-spike fade proxy."
  trade_management:
    used: true
    notes: "Close below fast SMA or max hold; ATR hard stop on entry."
  trade_close:
    used: true
    notes: "Managed through Strategy_ManageOpenPosition plus framework Friday close."
hard_rules_at_risk:
  - friday_close
  - enhancement_doctrine
at_risk_explanation: |
  Friday close can interrupt multi-day WTI relief holds. P3 may tune thresholds,
  but the source-authorized logic remains a weekly D1 failed tightness-spike
  fade proxy.
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial EIA Cushing failed-spike fade build; Q02 work item 4c84fa95-7b39-4b22-894f-64d55b7db128 enqueued | Q02 | ENQUEUED |
