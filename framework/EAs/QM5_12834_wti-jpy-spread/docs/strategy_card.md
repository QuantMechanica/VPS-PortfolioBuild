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
  - "[[concepts/commodity-trend-confirmation]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity-trend, cross-asset-confirmation, weekly-gate, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
read_only_symbols: [USDJPY.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly-gated WTI trend package confirmed by USDJPY.DWX oil-importer FX direction; estimate 5-12 entries/year after thresholds."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS official EIA Japan energy source plus official BOJ macro source and EIA oil/exchange-rate supplement; R2 PASS deterministic weekly D1 oil return plus USDJPY oil-importer FX confirmation, SMA trend filter, ATR stop, signal-flip and time exits; R3 PASS XTIUSD.DWX and USDJPY.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
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
pricing. This card converts that mechanism into a Darwinex-native WTI sleeve:
trade `XTIUSD.DWX` only when its own D1 trend agrees with closed `USDJPY.DWX`
direction as an oil-importer FX confirmation proxy.

This is deliberately different from:

- `QM5_12814_wti-usd-confirm`: uses `EURUSD.DWX` as a broad USD proxy; this
  card uses `USDJPY.DWX` as an oil-importer/yen proxy.
- `QM5_12607_wti-cad-confirm`, `QM5_12609_wti-cad-spread-mr`, and
  `QM5_12722_wti-cad-brk`: this is not a petro-exporter CAD setup.
- `QM5_12831_wti-audusd-brk`: no AUDUSD traded leg and no two-leg basket.
- WTI calendar, weekday, month, WPSR, OPEC, refinery, hurricane, Cushing, SPR,
  ETF-roll, expiry, driving-season, distillate, jet-fuel, and RBOB sleeves:
  no event or calendar window is used.
- XTI/XNG, oil/gold, oil/silver, gas/metal, XAU/XAG, and XNG RSI sleeves:
  this is one traded WTI leg with read-only FX confirmation.

## Hypothesis

WTI trend persistence should improve when the direction of oil is confirmed by
the yen oil-importer channel. `USDJPY.DWX` rising is treated as yen weakness and
confirms long WTI setups; `USDJPY.DWX` falling is treated as yen strength and
confirms short WTI setups.

## rules

- Host/traded symbol: `XTIUSD.DWX` D1, magic slot 0.
- Read-only confirmation symbol: `USDJPY.DWX` D1.
- Evaluate entries only on the first D1 bar of a new broker-calendar week.
- Compute oil momentum as `ln(XTI close[1] / XTI close[1+lookback])`.
- Compute JPY proxy momentum as
  `ln(USDJPY close[1] / USDJPY close[1+lookback])`.
- Long entry: oil return above `strategy_min_oil_return_pct`, USDJPY return
  above `strategy_min_jpy_proxy_return_pct`, and XTI close above its D1 SMA.
- Short entry: oil return below `-strategy_min_oil_return_pct`, USDJPY return
  below `-strategy_min_jpy_proxy_return_pct`, and XTI close below its D1 SMA.
- Exit on weekly signal flip/loss, `strategy_max_hold_days`, Friday close, or
  ATR hard stop.
- No pyramiding, grid, martingale, partial close, runtime source data, or ML.

## risk

- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Hard stop: ATR(`strategy_atr_period`) times `strategy_atr_sl_mult`.
- One open XTI position per magic.
- Live risk is intentionally not configured here; any future live allocation
  must come from the portfolio process.

## Markets And Timeframe

- Host/traded symbol: `XTIUSD.DWX`.
- Read-only confirmation symbol: `USDJPY.DWX`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no EIA, BOJ,
  exchange-rate-index, oil-import, futures-curve, macro CSV, API, or analyst
  feed.

## Entry Rules

- Evaluate entries only on the first D1 bar of a new broker-calendar week.
- Compute oil momentum as `ln(XTI close[1] / XTI close[1+lookback])`.
- Compute JPY proxy momentum as
  `ln(USDJPY close[1] / USDJPY close[1+lookback])`.
- Long entry: oil return above `strategy_min_oil_return_pct`, USDJPY return
  above `strategy_min_jpy_proxy_return_pct`, and XTI close above its D1 SMA.
- Short entry: oil return below `-strategy_min_oil_return_pct`, USDJPY return
  below `-strategy_min_jpy_proxy_return_pct`, and XTI close below its D1 SMA.
- No entry if an XTI position is already open for this EA magic.
- No entry if XTI's current spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) times
  `strategy_atr_sl_mult`.
- Exit on weekly signal flip or loss of confirmation.
- Exit after `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- `qm_magic_slot_offset` must be 0.
- `strategy_jpy_proxy_symbol` must be `USDJPY.DWX`.
- Skip when required close/SMA/ATR history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open traded XTI position at a time.

## Parameters To Test

- name: strategy_jpy_proxy_symbol
  default: USDJPY.DWX
  sweep_range: [USDJPY.DWX]
- name: strategy_oil_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_jpy_lookback_d1
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_min_oil_return_pct
  default: 3.0
  sweep_range: [2.0, 3.0, 5.0]
- name: strategy_min_jpy_proxy_return_pct
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
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from any source. The sources are used only for
structural lineage around Japan's oil-import exposure, oil terms-of-trade
pressure, and oil/exchange-rate linkage. The Q02+ pipeline tests the
deterministic Darwinex `XTIUSD.DWX` strategy.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 22
- expected_trade_frequency: approximately 5-12 entries/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA Japan energy source, official BOJ
  policy speech, and official EIA oil/exchange-rate working paper supplement.
- [x] R2 mechanical: fixed weekly gate, fixed return thresholds, SMA trend
  filter, ATR hard stop, signal-flip exit, and time exit.
- [x] R3 testable: `XTIUSD.DWX` and `USDJPY.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data.
- [x] Non-duplicate: not broad USD EURUSD confirmation, not CAD/AUD
  commodity-FX logic, not WTI event/calendar logic, not XTI/XNG or metal logic,
  and not `QM5_12567` RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` host guard, magic-slot guard, parameter guard,
  spread cap, framework news, kill-switch, and Friday close.
- trade_entry: weekly XTI momentum and SMA trend entry confirmed by closed
  `USDJPY.DWX` direction.
- trade_management: weekly signal-flip/loss exit and max-hold control.
- trade_close: ATR hard stop, Friday close, framework kill-switch, and
  deterministic time/signal exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial WTI/JPY oil-importer confirmation build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q01 Build Validation | 2026-06-30 | PASS | `artifacts/QM5_12834_build_result.json` |
| Q02 Backtest | 2026-06-30 | ENQUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` |
