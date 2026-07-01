---
ea_id: QM5_12852
slug: wti-may-prem
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_S01
source_id: KHAN-WTI-BRENT-SEASON-2023
source_citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent. Research Square posted content. DOI 10.21203/rs.3.rs-2569101/v1."
source_citations:
  - type: posted_research_paper
    citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent."
    location: "https://www.researchsquare.com/article/rs-2569101/v1.pdf"
    quality_tier: B
    role: primary
sources:
  - "[[sources/KHAN-WTI-BRENT-SEASON-2023]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "May-only D1 WTI month-of-year positive-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS single research-paper source URL; R2 PASS deterministic May D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
---

# WTI May Calendar Premium

## Source

- Source: [[sources/KHAN-WTI-BRENT-SEASON-2023]]
- Primary citation: Khan, Z., Saha, T. R. and Ekundayo, T.,
  "Understanding the Seasonality in Crude Oil Returns for WTI and Brent",
  Research Square posted content, DOI 10.21203/rs.3.rs-2569101/v1,
  URL https://www.researchsquare.com/article/rs-2569101/v1.pdf.

## Concept

The source studies crude-oil day-of-week and month-of-year seasonality across
WTI and Brent samples and reports May as the highest average-return month in
the sample. This card isolates that positive month as a clean WTI-only energy
sleeve: long-only exposure to `XTIUSD.DWX` during broker-calendar May D1 bars,
with each position flattened on the next D1 bar unless the ATR hard stop or
framework Friday close acts first.

This is deliberately different from:

- `QM5_12727_wti-apr-prem` and `QM5_12729_wti-aug-prem`: same structural
  family, but different source month and isolated May exposure.
- `QM5_12734_wti-febsep-prem`: broad seasonal allocation window; this card is
  a single May one-bar calendar premium.
- `QM5_12701_wti-oct-fade`, `QM5_12726_wti-nov-fade`, and
  `QM5_12777_wti-dec-fade`: late-year short month-of-year fades, opposite
  direction and season.
- WTI weekday, WPSR, refinery, hurricane, OPEC, expiry, roll, Cushing,
  WTI/FX, WTI/Brent, XTI/XNG, XAU/XAG, and gas-metal cards: different trigger
  family and information set.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in May.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in May.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_entry_month
  default: 5
  sweep_range: [5]
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
crude-oil returns, including the reported May positive-return peak. No source
performance number is imported into QM; the Q02+ pipeline tests the rule on
Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 source lineage: single research-paper source with URL.
- [x] R2 mechanical: fixed broker-calendar May, single D1 long entry, ATR
  stop, and next-bar/month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: May month-of-year long is not the existing April/August
  single-month cards, broad February-September season, WTI event/weekday,
  WTI momentum/reversal, XNG, ratio-basket, or RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: May broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-01 | initial structural WTI May calendar-premium build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
