---
ea_id: QM5_12814
slug: wti-usd-confirm
type: strategy
source_id: EIA-OIL-USD-FX-2017
source_citation: "Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
source_citations:
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "EIA working paper PDF"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-OIL-USD-FX-2017]]"
concepts:
  - "[[concepts/oil-dollar-linkage]]"
  - "[[concepts/commodity-trend-confirmation]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-trend, cross-asset-confirmation, weekly-gate, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
read_only_symbols: [EURUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly-gated WTI trend package confirmed by EURUSD.DWX dollar-proxy direction; estimate 6-14 entries/year after thresholds."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS single official EIA working paper on oil prices and exchange rates; R2 PASS deterministic weekly D1 oil return plus EURUSD dollar-proxy confirmation, SMA trend filter, ATR stop, signal-flip and time exits; R3 PASS XTIUSD.DWX and EURUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 22.0
---

# WTI Dollar Confirmation Trend

## Source

- Source: [[sources/EIA-OIL-USD-FX-2017]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017.

## Concept

The source studies the oil-price and exchange-rate relationship, including the
frequently discussed tendency for U.S. dollar strength to pressure oil and U.S.
dollar weakness to support oil. This card turns that structural linkage into a
Darwinex-native WTI sleeve: trade `XTIUSD.DWX` only when its own D1 trend agrees
with a broad USD proxy from closed `EURUSD.DWX` bars.

This is deliberately different from:

- `QM5_12607_wti-cad-confirm`: uses USDCAD petro-currency confirmation; this
  card uses EURUSD as a broad dollar proxy and does not depend on CAD/oil export
  linkage.
- `QM5_12609_wti-cad-spread-mr` and `QM5_12722_wti-cad-brk`: no USDCAD traded
  leg, no basket, and no WTI/CAD spread.
- WTI calendar, weekday, month, WPSR, OPEC, refinery, hurricane, ETF-roll,
  expiry, driving-season, distillate, and SPR sleeves: no event or calendar
  window is used.
- XTI/XNG, oil/gold, oil/silver, and XAU/XAG ratio baskets: this is one traded
  WTI leg with read-only FX confirmation, not a market-neutral package.
- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.

## hypothesis

WTI trends should have better persistence when the oil move is confirmed by the
U.S. dollar direction. EURUSD rising is treated as USD weakness and confirms
long WTI setups; EURUSD falling is treated as USD strength and confirms short
WTI setups.

## rules

- Host/traded symbol: `XTIUSD.DWX` D1, magic slot 0.
- Read-only confirmation symbol: `EURUSD.DWX` D1.
- Evaluate entries only on the first D1 bar of a new broker-calendar week.
- Compute oil momentum as `ln(XTI close[1] / XTI close[1+lookback])`.
- Compute USD-proxy momentum as `ln(EURUSD close[1] / EURUSD close[1+lookback])`.
- Long entry: oil return above `strategy_min_oil_return_pct`, EURUSD return
  above `strategy_min_usd_proxy_return_pct`, and XTI close above its D1 SMA.
- Short entry: oil return below `-strategy_min_oil_return_pct`, EURUSD return
  below `-strategy_min_usd_proxy_return_pct`, and XTI close below its D1 SMA.
- Exit on weekly signal flip/loss, `strategy_max_hold_days`, Friday close, or
  ATR hard stop.
- No pyramiding, grid, martingale, partial close, runtime source data, or ML.

## risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Hard stop: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- One open XTI position per magic.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Parameters To Test

- name: strategy_usd_proxy_symbol
  default: EURUSD.DWX
  sweep_range: [EURUSD.DWX]
- name: strategy_oil_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_usd_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_min_oil_return_pct
  default: 3.0
  sweep_range: [2.0, 3.0, 5.0]
- name: strategy_min_usd_proxy_return_pct
  default: 1.0
  sweep_range: [0.5, 1.0, 1.5]
- name: strategy_trend_period
  default: 84
  sweep_range: [63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 21
  sweep_range: [14, 21, 31]

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA working paper with URL.
- [x] R2 mechanical: fixed weekly gate, fixed return thresholds, SMA trend
  filter, ATR hard stop, signal-flip exit, and time exit.
- [x] R3 testable: `XTIUSD.DWX` and `EURUSD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or multiple positions per magic.
- [x] Portfolio intent: a crude-oil sleeve distinct from the current
  XAU/SP500/NDX/XNG book and not a duplicate of the existing WTI/CAD family.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial EIA oil-dollar confirmation WTI build | G0 | APPROVED |
