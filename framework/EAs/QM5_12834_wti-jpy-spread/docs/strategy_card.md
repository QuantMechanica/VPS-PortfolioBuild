---
ea_id: QM5_12834
slug: wti-jpy-spread
type: strategy
strategy_id: EIA-BOJ-WTI-JPY-2026_S02
source_id: EIA-BOJ-WTI-JPY-2026
source_citation: "U.S. Energy Information Administration. Japan Country Analysis Brief. URL https://www.eia.gov/international/analysis/country/JPN; Bank of Japan, Uchida, S. Recent Developments in Economic Activity, Prices, and Monetary Policy. 2026-06-03. URL https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm; Beckmann, J., Czudaj, R. L., and Arora, V. The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration Working Paper, June 2017. URL https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
source_citations:
  - type: official_energy_country_analysis
    citation: "U.S. Energy Information Administration. Japan Country Analysis Brief."
    location: "https://www.eia.gov/international/analysis/country/JPN"
    quality_tier: A
    role: primary
  - type: central_bank_speech
    citation: "Uchida, S. (2026). Recent Developments in Economic Activity, Prices, and Monetary Policy. Bank of Japan."
    location: "https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm"
    quality_tier: A
    role: primary
  - type: working_paper
    citation: "Beckmann, J., Czudaj, R. L., and Arora, V. (2017). The Relationship between Oil Prices and Exchange Rates. U.S. Energy Information Administration."
    location: "https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-BOJ-WTI-JPY-2026]]"
concepts:
  - "[[concepts/oil-importer-fx]]"
  - "[[concepts/cross-asset-relative-value]]"
indicators:
  - "[[indicators/z-score]]"
  - "[[indicators/atr]]"
strategy_type_flags: [mean-reversion, cross-asset-relative-value, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, USDJPY.DWX]
basket_symbols: [XTIUSD.DWX, USDJPY.DWX]
read_only_symbols: []
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 z-score gate on a 120-day XTIUSD/USDJPY log spread; estimate 4-10 basket packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA Japan energy source plus official BOJ macro source and EIA oil/exchange-rate supplement; R2 PASS deterministic D1 XTIUSD/USDJPY log-spread z-score entries, z-score/time exits, and ATR stops; R3 PASS XTIUSD.DWX and USDJPY.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.07
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [friday_close, magic_schema, dwx_suffix_discipline]
---

# WTI JPY Oil-Importer Spread Mean Reversion

## Source

- Source: [[sources/EIA-BOJ-WTI-JPY-2026]]
- Primary citation: U.S. Energy Information Administration, "Japan", Country
  Analysis Brief.
- Primary citation: Bank of Japan, Uchida, S., "Recent Developments in
  Economic Activity, Prices, and Monetary Policy", 2026-06-03.
- Supplement: Beckmann, J., Czudaj, R. L., and Arora, V., "The Relationship
  between Oil Prices and Exchange Rates", U.S. Energy Information
  Administration working paper, June 2017.

## Concept

Japan is structurally exposed to imported energy costs, and crude-oil price
moves can feed through the terms-of-trade channel into yen-sensitive macro
pricing. This card converts that mechanism into a Darwinex-native two-leg
relative-value basket: fade large D1 dislocations between `XTIUSD.DWX` and
`USDJPY.DWX` while judging the package as one spread.

This is deliberately different from:

- `QM5_12833_wti-jpy-confirm`: trades only WTI and uses USDJPY as read-only
  confirmation; this card opens and manages both legs as a basket.
- `QM5_12814_wti-usd-confirm`: uses `EURUSD.DWX` as a broad USD proxy and
  trades only WTI.
- `QM5_12607_wti-cad-confirm`, `QM5_12609_wti-cad-spread-mr`, and
  `QM5_12722_wti-cad-brk`: this is not a petro-exporter CAD setup.
- `QM5_12831_wti-audusd-brk`: AUDUSD breakout basket, not USDJPY z-score
  mean reversion.
- WTI calendar, weekday, month, WPSR, OPEC, refinery, hurricane, Cushing, SPR,
  ETF-roll, expiry, driving-season, distillate, jet-fuel, and RBOB sleeves:
  no event or calendar window is used.
- XTI/XNG, oil/gold, oil/silver, gas/metal, XAU/XAG, and XNG RSI sleeves:
  no gas or metals leg is used.

## Hypothesis

The oil/yen macro link should not be a fixed linear trade at all times, but
large deviations in the D1 `ln(XTIUSD) - beta * ln(USDJPY)` spread can mean
temporary terms-of-trade or FX overreaction. The EA fades those extremes and
exits when the spread normalizes or the package ages out.

## rules

- Host symbol: `XTIUSD.DWX` D1, magic slot 0.
- Second basket leg: `USDJPY.DWX` D1, magic slot 1.
- Compute spread as `ln(XTI close[1]) - beta * ln(USDJPY close[1])`.
- Compute z-score over the prior `strategy_z_lookback_d1` closed D1 bars.
- Rich spread entry: SELL `XTIUSD.DWX`, BUY `USDJPY.DWX`.
- Cheap spread entry: BUY `XTIUSD.DWX`, SELL `USDJPY.DWX`.
- Exit on spread z-score reversion to `strategy_exit_z`, `strategy_max_hold_days`,
  broken package repair, Friday close, or per-leg ATR hard stop.
- No pyramiding, grid, martingale, partial close, runtime source data, or ML.

## risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Per-leg hard stop: ATR(`strategy_atr_period_d1`) times
  `strategy_atr_sl_mult`.
- One open basket package: one position per magic slot.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Markets And Timeframe

- Host/traded symbol: `XTIUSD.DWX`.
- Basket leg symbol: `USDJPY.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA, BOJ,
  exchange-rate-index, oil-import, futures-curve, macro CSV, API, or analyst
  feed.

## Entry Rules

- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(USDJPY.DWX close)` over
  closed D1 bars.
- If spread z-score > `strategy_entry_z`, SELL `XTIUSD.DWX` and BUY
  `USDJPY.DWX`.
- If spread z-score < `-strategy_entry_z`, BUY `XTIUSD.DWX` and SELL
  `USDJPY.DWX`.
- No entry if either basket leg already has an open position for this EA.
- No entry if either leg exceeds its configured spread cap.

## Exit Rules

- Stop loss: fixed per-leg hard SL at ATR(`strategy_atr_period_d1`) times
  `strategy_atr_sl_mult`.
- Exit when spread z-score reverts inside `strategy_exit_z`.
- Exit after `strategy_max_hold_days`.
- If only one leg remains open, close the broken package immediately.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- `qm_magic_slot_offset` must be 0.
- Skip when required close/ATR history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open two-leg package at a time.

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
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_usdjpy_max_spread_pts
  default: 60
  sweep_range: [30, 60, 100]

## Author Claims

No performance claim is imported from any source. The sources are used only for
structural lineage around Japan's oil-import exposure, oil terms-of-trade
pressure, and oil/exchange-rate linkage. The Q02+ pipeline tests the
deterministic Darwinex `XTIUSD.DWX` / `USDJPY.DWX` basket.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 4-10 basket packages/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA Japan energy source, official BOJ
  policy speech, and official EIA oil/exchange-rate working paper supplement.
- [x] R2 mechanical: fixed z-score lookback, fixed spread coefficients, ATR
  hard stops, z-score reversion exit, and time exit.
- [x] R3 testable: `XTIUSD.DWX` and `USDJPY.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data.
- [x] Non-duplicate: not `QM5_12833` single-leg WTI/JPY confirmation, not broad
  USD EURUSD confirmation, not CAD/AUD commodity-FX logic, not WTI
  event/calendar logic, not XTI/XNG or metal logic, and not `QM5_12567` RSI
  commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` host guard, magic-slot guard, parameter guard,
  spread cap, framework news, kill-switch, and Friday close.
- trade_entry: D1 XTI/USDJPY log-spread z-score mean-reversion basket entry.
- trade_management: broken-package repair and max-hold control.
- trade_close: ATR hard stop, Friday close, framework kill-switch, and
  deterministic z-score/time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial WTI/JPY oil-importer spread basket build | Q01 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Backtest | TBD | TBD | TBD |
