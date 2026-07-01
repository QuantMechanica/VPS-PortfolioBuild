---
ea_id: QM5_12854
slug: brent-dec-fade
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_BRENT_S03
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
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "December-only D1 Brent month-of-year weakness sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS single research-paper source URL; R2 PASS deterministic December D1 short/time-flat rule with ATR stop; R3 PASS XBRUSD.DWX locally routed by prior Brent builds with Q02 validating current history; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent December Calendar Fade

## Source

- Source: [[sources/KHAN-WTI-BRENT-SEASON-2023]]
- Primary citation: Khan, Z., Saha, T. R. and Ekundayo, T.,
  "Understanding the Seasonality in Crude Oil Returns for WTI and Brent",
  Research Square posted content, DOI 10.21203/rs.3.rs-2569101/v1,
  URL https://www.researchsquare.com/article/rs-2569101/v1.pdf.

## Concept

The source studies crude-oil day-of-week and month-of-year seasonality across
WTI and Brent samples and reports November and December as the weakest months.
This card isolates the December weakness side as a clean Brent-only energy
sleeve: short-only exposure to `XBRUSD.DWX` during broker-calendar December D1
bars, with each position flattened on the next D1 bar unless the ATR hard stop,
month-end, stale guard, or framework Friday close acts first.

This is deliberately different from:

- `QM5_12777_wti-dec-fade`: same weak-month thesis, but WTI benchmark; this
  card targets Brent exposure.
- `QM5_12853_brent-may-prem`: Brent month-of-year logic, but positive May long
  premium instead of December weakness short.
- `QM5_12841_brent-thu-prem`: Brent weekday premium, not month-of-year
  seasonality.
- `QM5_12849_brent-tsmom12m`: monthly trailing-return momentum, not a fixed
  December calendar fade.
- `QM5_12843_wti-brent-spread` and `QM5_12848_wti-brent-brk`: Brent/WTI paired
  spread logic, not single-symbol Brent exposure.
- XTI/XNG, XNG, XAU/XAG, gas-metal, index, WTI event/calendar, and
  `QM5_12567_cum-rsi2-commodity`: different market, timing, or signal family.

## hypothesis

Brent crude carries a month-of-year weakness anomaly documented in the source's
WTI/Brent seasonality study. The QM hypothesis is intentionally narrow: a
one-bar short Brent exposure during broker-calendar December can add a structural
energy sleeve that is different from the current XAU, SP500, NDX, and XNG
portfolio exposures.

## rules

- Trade only `XBRUSD.DWX` on D1.
- Enter short only during broker-calendar December.
- Exit on the next D1 bar, on month-end, on max-hold expiry, or on the ATR hard
  stop.
- Use Darwinex MT5 OHLC and broker calendar only.

## risk

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live deployment is out of scope for this build.
- Friday close, news, kill-switch, and magic guards remain framework-managed.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no external feed.

`XBRUSD.DWX` has existing local routes through prior Brent builds. Current
history sufficiency is intentionally left to Q02 validation.

## 4. Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in December.
- Entry direction is short only: SELL `XBRUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## 5. Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in December.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## 6. Filters (No-Trade Module)

- Host chart must be `XBRUSD.DWX` on D1.
- Magic slot must be 0.
- Short-only; no long entries.
- No pyramiding, gridding, martingale, partial close, trailing stop, external
  feed, or ML.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## 7. Trade Management Rules

- No trailing stop in v1.
- No partial close.
- One open `XBRUSD.DWX` position per magic.
- Time exits are handled by the strategy management hook on new D1 bars.

## Parameters To Test

- name: strategy_entry_month
  default: 12
  sweep_range: [12]
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
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The source reports November and December as the weakest average-return months in
its WTI/Brent sample. No source performance number is imported into QM; Q02 and
later phases must validate the deterministic Brent CFD port on Darwinex
`XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium because XBR history sufficiency and costs need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 source lineage: existing research-paper source packet covering WTI and
  Brent seasonality.
- [x] R2 mechanical: fixed broker-calendar December, single D1 short entry, ATR
  stop, and next-bar/month-end time exit.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes; Q02 validates
  current history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: Brent December calendar fade is not WTI December, Brent
  May, Brent weekday, Brent TSMOM, Brent/WTI spread, XTI/XNG, XNG, XAU/XAG,
  gas-metal, index, WTI event, or commodity RSI logic.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: December broker-calendar short entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-01 | initial Brent December calendar-fade build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `D:\QM\reports\framework\21\build_check_20260701_120849.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `929ec001-e7c2-4cba-be28-dd45acb0d99c` |
