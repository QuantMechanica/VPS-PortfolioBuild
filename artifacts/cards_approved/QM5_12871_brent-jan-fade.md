---
ea_id: QM5_12871
slug: brent-jan-fade
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_JAN_S02
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, D. and Bukoven, J. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12."
source_citations:
  - type: paper
    citation: "Arendas, P., Tkacova, D. and Bukoven, J. (2018). Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12."
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
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
logical_symbol: QM5_12871_XBR_JAN_FADE_D1
expected_trade_frequency: "January-only D1 Brent month-of-year weakness sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
g0_approval_reasoning: "R1 PASS peer-reviewed oil-seasonality paper covering Brent and WTI month-of-year structure; R2 PASS deterministic January D1 short/time-flat rule with ATR stop; R3 PASS XBRUSD.DWX is locally routed by prior Brent builds with Q02 validating current history sufficiency; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent January Calendar Fade

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Tkacova, D. and Bukoven, J.,
  "Seasonal patterns in oil prices and their implications for investors",
  Journal of International Studies, 11(2), 180-192, DOI
  10.14254/2071-8330.2018/11-2/12, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

The source studies month-of-year seasonal structure in Brent and WTI crude-oil
returns. This card isolates a Brent January weakness hypothesis as a clean
energy sleeve: short-only exposure to `XBRUSD.DWX` during broker-calendar
January D1 bars, with each position flattened on the next D1 bar unless the ATR
hard stop, month-end, stale guard, or framework Friday close acts first.

This is deliberately different from:

- `QM5_12870_wti-jan-fade`: same January calendar thesis, but WTI benchmark;
  this card targets Brent exposure and Brent-specific history.
- `QM5_12866_brent-apr-prem`, `QM5_12853_brent-may-prem`,
  `QM5_12854_brent-dec-fade`, and `QM5_12855_brent-nov-fade`: Brent calendar
  cards, but different months and seasonal direction or source lineage.
- `QM5_12841_brent-thu-prem`, `QM5_12856_brent-mon-fade`, and
  `QM5_12865_brent-fri-prem`: Brent weekday effects, not month-of-year
  seasonality.
- `QM5_12849_brent-tsmom12m` and `QM5_12859_brent-52w-anchor`: Brent trend or
  anchor logic, not a fixed January calendar fade.
- `QM5_12843_wti-brent-spread`, `QM5_12848_wti-brent-brk`, and
  `QM5_12860_wti-brent-rshock`: paired WTI/Brent spread logic, not single-symbol
  Brent exposure.
- WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, and
  `QM5_12567_cum-rsi2-commodity`: different market, timing, or signal family.

## Hypothesis

Brent crude carries month-of-year return effects documented in the source's
crude-oil seasonality study. The QM hypothesis is intentionally narrow: a
one-bar short Brent exposure during broker-calendar January can add a
low-frequency energy sleeve that differs from the current index, metal, XNG,
WTI, and paired-spread book.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC feed, CSV, API, analyst forecast, or ML model.

`XBRUSD.DWX` has existing local routes through prior Brent builds. Current
history sufficiency is intentionally left to Q02 validation.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in January.
- Entry direction is short only: SELL `XBRUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in January.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XBRUSD.DWX` on D1.
- Magic slot must be 0.
- Short-only; no long entries.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open `XBRUSD.DWX` position per magic.

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
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The source is used for structural lineage around month-of-year seasonality in
Brent and WTI crude-oil returns. No source performance number is imported into
QM; Q02 and later phases must validate or reject this deterministic Brent CFD
port on Darwinex `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium because XBR history sufficiency and costs need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 source lineage: peer-reviewed oil-seasonality paper covering Brent and
  WTI month-of-year seasonality.
- [x] R2 mechanical: fixed broker-calendar January, single D1 short entry, ATR
  stop, and next-bar/month-end time exit.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes; Q02 validates
  current history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: Brent January calendar fade is not WTI January, Brent
  April/May/November/December calendar logic, Brent weekday, Brent TSMOM,
  Brent/WTI spread, XTI/XNG, XNG, XAU/XAG, gas-metal, WTI event, or commodity
  RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XBRUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: January broker-calendar short entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-02 | initial Brent January calendar-fade build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build Validation | 2026-07-02 | PENDING | `artifacts/qm5_12871_build_result.json` |
| Q02 Baseline Screening | 2026-07-02 | PENDING | `D:\QM\strategy_farm\state\farm_state.sqlite` |
