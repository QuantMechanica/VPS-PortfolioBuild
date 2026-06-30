---
ea_id: QM5_12825
slug: wti-eurusd-spread
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
  - "[[concepts/commodity-fx-relative-value]]"
  - "[[concepts/spread-mean-reversion]]"
indicators:
  - "[[indicators/log-spread-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, spread-mean-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, EURUSD.DWX]
basket_symbols: [XTIUSD.DWX, EURUSD.DWX]
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 z-score gate on a 120-day XTIUSD/EURUSD log spread; estimate 7 entries per year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS single official EIA working paper on oil prices and exchange rates; R2 PASS deterministic D1 XTIUSD/EURUSD log-spread z-score entries, z-score/time exits, ATR stops; R3 PASS DWX XTIUSD/EURUSD symbols; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 24.0
---

# WTI EURUSD Spread Mean Reversion

## Source

- Source: [[sources/EIA-OIL-USD-FX-2017]]
- Primary citation: Beckmann, J., Czudaj, R. L., and Arora, V.,
  "The Relationship between Oil Prices and Exchange Rates", U.S. Energy
  Information Administration working paper, June 2017, URL
  https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.

## Concept

The source studies the structural relationship between oil prices and exchange
rates, including the common channel where U.S. dollar weakness supports USD
commodity prices and dollar strength pressures them. This card turns that
relationship into a Darwinex-native relative-value basket: compare closed D1
`XTIUSD.DWX` oil prices with closed D1 `EURUSD.DWX` prices as a broad USD
weakness proxy, then fade extreme deviations in the pair.

This is deliberately different from:

- `QM5_12814_wti-usd-confirm`: that card trades only XTI and uses EURUSD as a
  read-only confirmation filter; this card opens both XTI and EURUSD legs.
- `QM5_12609_wti-cad-spread-mr` and `QM5_12722_wti-cad-brk`: those cards use
  USDCAD and petro-currency mechanics; this card uses EURUSD as a broad dollar
  proxy and opposite leg directions.
- WTI calendar, weekday, month, WPSR, OPEC, refinery, hurricane, ETF-roll,
  expiry, driving-season, distillate, and SPR sleeves: no event or calendar
  window is used.
- XTI/XNG, oil/gold, oil/silver, gas/gold, XAU/XAG, and XNG RSI sleeves: this
  is an oil-dollar FX relative-value basket, not a metal/energy ratio or RSI
  pullback.

## hypothesis

Oil and EURUSD should often move in the same direction through the dollar
channel. When WTI is rich versus EURUSD, the basket shorts the spread by selling
XTI and buying EURUSD. When WTI is cheap versus EURUSD, the basket buys the
spread by buying XTI and selling EURUSD. The expected cadence is 7 entries per
year, with holds measured in days to several weeks.

## rules

- Host symbol: `XTIUSD.DWX` D1, magic slot 0.
- Second basket symbol: `EURUSD.DWX` D1, magic slot 1.
- Logical basket symbol: `QM5_12825_XTI_EURUSD_SPREAD_D1`.
- Entry evaluation runs once per D1 broker bar after the configured broker
  entry time, using closed D1 bars only.
- Compute the spread as `ln(XTI close[1]) - beta * ln(EURUSD close[1])`.
- Compute a z-score against the prior `strategy_z_lookback_d1` closed spreads.
- Long spread entry: z-score below `-strategy_entry_z`; buy XTI and sell EURUSD.
- Short spread entry: z-score above `strategy_entry_z`; sell XTI and buy EURUSD.
- Exit when the spread z-score reverts inside `strategy_exit_z`, either leg is
  missing from the package, `strategy_max_hold_days` expires, Friday close
  triggers, or a per-leg ATR hard stop is reached.
- No pyramiding, grid, martingale, partial close, runtime source data, or ML.

## risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Position sizing: split fixed risk across the two ATR-stopped legs.
- Hard stop: ATR(`strategy_atr_period_d1`) times `strategy_atr_sl_mult` on each
  leg.
- One open position per registered magic slot.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [90, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]

## Strategy Allowability Check

- [x] R1 reputable source: single official EIA working paper with URL.
- [x] R2 mechanical: fixed D1 spread definition, z-score Entry and Exit
  thresholds, ATR hard stops, max-hold exit, and Friday close.
- [x] R3 testable: `XTIUSD.DWX` and `EURUSD.DWX` exist in the Darwinex symbol
  matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic slot.
- [x] Portfolio intent: a crude-oil/dollar relative-value sleeve distinct from
  the current XAU/SP500/NDX/XNG book and not a duplicate of the WTI/CAD or
  WTI-dollar-confirmation families.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial EIA oil-dollar relative-value basket build | G0 | APPROVED |
