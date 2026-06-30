---
ea_id: QM5_12828
slug: wti-cushing-brk
type: strategy
strategy_id: EIA-CUSHING-STORAGE-2021_S01
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
  - "[[concepts/cushing-storage-draws]]"
indicators:
  - "[[indicators/rolling-high-low]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-breakout, structural-energy, weekly-gate, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly-gated WTI Cushing tightness breakout proxy on D1; estimate 4-10 entries/year after channel, trend, and spread filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
expected_pf: 1.06
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS single official EIA source; R2 PASS deterministic weekly D1 breakout, SMA trend, ATR stop, fast-SMA and time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI Cushing Tightness Breakout

## Source

- Source: [[sources/EIA-CUSHING-STORAGE-2021]]
- Primary citation: U.S. Energy Information Administration, "Crude oil
  inventories at Cushing, Oklahoma, remain low after summer draws", Today in
  Energy, October 21, 2021.

## Concept

EIA identifies Cushing, Oklahoma as the NYMEX WTI delivery point and discusses
periods when Cushing inventories remain low after sustained draws. This card
does not import Cushing inventories into MT5. It uses a narrow Darwinex-native
proxy: a weekly-gated D1 `XTIUSD.DWX` upside breakout with slow-trend
confirmation, expressing possible WTI delivery-hub tightness through price.

This is deliberately different from:

- `QM5_12577_cme-xauxag-ratio` and `QM5_12724_cme-xauxag-brk`: no metal basket,
  no XAU/XAG ratio, and no market-neutral metal exposure.
- `QM5_12576_eia-wti-season`, `QM5_12737_eia-wti-drive`,
  `QM5_12740_eia-wti-postdrive`, and distillate/gasoline/jet-fuel sleeves:
  no fixed product-demand month window.
- WTI WPSR, OPEC, hurricane, SPR, expiry, ETF-roll, CAD/USD, oil-metal, and
  XTI/XNG sleeves: no event feed, no cross-asset leg, no calendar meeting, no
  ratio package.
- `QM5_12780_wti-52w-anchor`: this is not a monthly 252-D1 high/low anchor
  momentum rule; it is long-only, weekly gated, and uses a shorter delivery-hub
  tightness breakout proxy.
- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.

## Hypothesis

WTI upside breakouts should have better persistence when price behavior is
consistent with crude-delivery-hub tightness: the prior closed D1 bar breaks a
multi-month closing channel, the short trend is above the slow trend, and the
move has already shown medium-term positive pressure without becoming an
extreme blow-off.

## Rules

- Host/traded symbol: `XTIUSD.DWX` D1, magic slot 0.
- Evaluate entries only on the first D1 bar of a new broker-calendar week.
- Build a `strategy_breakout_lookback_d1` closing-channel from completed D1
  bars excluding the most recent completed bar.
- Long entry only:
  - prior D1 close exceeds the prior channel high by at least
    `strategy_min_breakout_margin_pct`;
  - prior D1 close is above the slow D1 SMA;
  - fast D1 SMA is above the slow D1 SMA;
  - `strategy_return_lookback_d1` return is at least
    `strategy_min_return_pct` and no more than `strategy_max_return_pct`.
- Exit on close below the fast SMA, `strategy_max_hold_days`, Friday close, or
  ATR hard stop.
- No shorting, pyramiding, grid, martingale, partial close, runtime inventory
  data, external files, APIs, or ML.

## Risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Hard stop: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- One open XTI position per magic.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Parameters To Test

- name: strategy_breakout_lookback_d1
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
- name: strategy_min_breakout_margin_pct
  default: 0.25
  sweep_range: [0.10, 0.25, 0.50]
- name: strategy_min_return_pct
  default: 2.0
  sweep_range: [1.0, 2.0, 3.5]
- name: strategy_max_return_pct
  default: 18.0
  sweep_range: [12.0, 18.0, 25.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 28
  sweep_range: [14, 28, 42]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA source with URL.
- [x] R2 mechanical: fixed weekly gate, fixed channel/return/SMA thresholds,
  ATR hard stop, SMA close, and time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in the Darwinex symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or multiple positions per magic.
- [x] Portfolio intent: adds a structural crude-oil sleeve distinct from the
  current XAU/SP500/NDX/XNG book and not a duplicate of existing WTI event,
  calendar, roll, ratio, petro-FX, or generic RSI commodity logic.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "D1/XTIUSD.DWX guard, one magic slot, parameter sanity, spread cap."
  trade_entry:
    used: true
    notes: "Weekly D1 long-only Cushing tightness breakout proxy."
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
  Friday close can interrupt multi-day WTI holds; re-entry is allowed only when
  the next weekly breakout gate fires again. P3 may tune thresholds, but the
  source-authorized logic remains a weekly D1 Cushing tightness breakout proxy.
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial EIA Cushing tightness breakout build | G0 | APPROVED |
