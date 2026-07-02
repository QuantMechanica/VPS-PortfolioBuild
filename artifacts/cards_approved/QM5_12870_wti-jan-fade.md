---
ea_id: QM5_12870
slug: wti-jan-fade
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_JAN_S01
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Chovancova, B. and Balaz, V. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
source_citations:
  - type: peer_reviewed_paper
    citation: "Arendas, P., Chovancova, B. and Balaz, V. Seasonal patterns in oil prices and their implications for investors."
    location: "https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/january-calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12870_XTI_JAN_FADE_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "January-only D1 WTI month-of-year negative-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil seasonality paper; R2 PASS deterministic January D1 short/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI January Calendar Fade

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Chovancova, B. and Balaz, V.,
  "Seasonal patterns in oil prices and their implications for investors",
  Journal of International Studies, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

The peer-reviewed crude-oil seasonality source reports that WTI January returns
were negative in all but two examined sub-periods. This card isolates that
January effect as a clean energy sleeve: short-only exposure to `XTIUSD.DWX`
during broker-calendar January D1 bars, with each position flattened on the
next D1 bar unless the ATR hard stop, month boundary, stale-position guard, or
framework Friday close acts first.

This is deliberately different from:

- `QM5_12727_wti-apr-prem`, `QM5_12729_wti-aug-prem`, and
  `QM5_12852_wti-may-prem`: positive-month long premiums, not a January fade.
- `QM5_12701_wti-oct-fade`, `QM5_12726_wti-nov-fade`, and
  `QM5_12777_wti-dec-fade`: same broad calendar-anomaly family, but different
  late-year months and separate source claims; this card isolates January.
- `QM5_12734_wti-febsep-prem`: broad February-September seasonal allocation,
  not a one-month January short.
- WTI weekday, WPSR, refinery, hurricane, OPEC, expiry, roll, Cushing,
  WTI/FX, WTI/Brent, XTI/XNG, oil/gold, oil/silver, gas-metal, XAU/XAG, and
  index cards: different trigger family and information set.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, broker calendar, spread, and ATR only. No
  futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst
  forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in January.
- Entry direction is short only: SELL `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in January.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_month
  default: 1
  sweep_range: [1]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around month-of-year seasonality in
crude-oil returns, specifically the reported persistent January weakness in
WTI. No source performance number is imported into QM; Q02 and later phases
must validate or reject the mechanical rule on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed crude-oil seasonality paper.
- [x] R2 mechanical: fixed broker-calendar January, single D1 short entry,
  ATR stop, and next-bar/month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, or more
  than one position per magic.
- [x] Non-duplicate: January month-of-year short is not the existing
  April/May/August long premiums, October/November/December fades,
  February-September broad season, WTI event/weekday/roll/inventory, WTI
  momentum/reversal, XNG, ratio-basket, or RSI commodity sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: January broker-calendar short entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial structural WTI January calendar-fade card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PENDING | `artifacts/qm5_12870_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | PENDING | `D:\QM\strategy_farm\state\farm_state.sqlite` |
