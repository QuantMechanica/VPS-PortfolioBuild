---
ea_id: QM5_12981
slug: brent-febsep-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_FEBSEP_S01
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
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "First tradable D1 bar of February through September on Brent; estimate 8 entries/year before framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed oil-seasonality paper covering Brent and WTI; R2 PASS deterministic February-September Brent source-window rule, first-trading-day entry, next-D1-bar exit, and ATR hard stop; R3 PASS XBRUSD.DWX local Brent route; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus existing commodity sleeves because this is a low-frequency Brent seasonal source-window sleeve, not a single Brent month, WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, trend, carry, or commodity RSI rule."
expected_pf: 1.05
expected_dd_pct: 14.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent February-September Seasonal Premium

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Tkacova, D. and Bukoven, J.,
  "Seasonal patterns in oil prices and their implications for investors",
  Journal of International Studies, 11(2), 180-192, DOI
  10.14254/2071-8330.2018/11-2/12, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

The source studies monthly seasonal patterns in crude-oil returns. This card
tests the broader February-September positive seasonal allocation window on the
Brent benchmark rather than another isolated month. The EA goes long
`XBRUSD.DWX` only on the first tradable D1 bar of each broker-calendar month
from February through September, then flattens on the next D1 bar unless the
ATR hard stop or framework Friday close acts first.

This is deliberately different from:

- `QM5_12976_brent-mar-prem`, `QM5_12866_brent-apr-prem`,
  `QM5_12853_brent-may-prem`, and `QM5_12911_brent-aug-prem`: those test
  single Brent months; this card tests the source-window start-of-month effect
  across February through September.
- `QM5_12854_brent-dec-fade`, `QM5_12855_brent-nov-fade`, and
  `QM5_12871_brent-jan-fade`: those test separate Brent weak-month shorts.
- `QM5_12841_brent-thu-prem`, `QM5_12856_brent-mon-fade`, and
  `QM5_12865_brent-fri-prem`: weekday effects, not month-of-year source-window
  seasonality.
- `QM5_12849_brent-tsmom12m`, `QM5_12859_brent-52w-anchor`, and
  `QM5_12980_brent-6m-rev`: trend, anchor, or reversal rules, not calendar
  entry timing.
- WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, and
  `QM5_12567_cum-rsi2-commodity`: different market, timing, or signal family.

## Hypothesis

Brent crude may carry a broad month-of-year return premium during the
February-September source window. A first-trading-day monthly expression keeps
the test low-frequency and avoids turning the broad seasonal thesis into a
high-turnover daily month filter.

## Rules

- Trade only `XBRUSD.DWX` on D1.
- Enter long only on the first tradable D1 bar of broker-calendar February
  through September.
- Exit on the next D1 bar, outside the source window, after the max-hold guard,
  or on the ATR hard stop.
- Use Darwinex MT5 OHLC and broker calendar only.

## Risk

- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live deployment is out of scope for this build.
- Friday close, news, kill-switch, and magic guards remain framework-managed.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no external feed.

`XBRUSD.DWX` has existing local routes through prior Brent builds. Current
history sufficiency is intentionally left to Q02 validation.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be the first tradable D1 bar of a month.
- Current broker-calendar month must be February through September.
- Entry direction is long only: BUY `XBRUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is outside February through September.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XBRUSD.DWX` on D1.
- Magic slot must be 0.
- Long-only; no short entries.
- No pyramiding, gridding, martingale, partial close, trailing stop, external
  feed, or ML.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_start_month
  default: 2
  sweep_range: [2]
- name: strategy_end_month
  default: 9
  sweep_range: [9]
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

The source supports crude-oil month-of-year seasonality; no source performance
number is imported into QM. Q02 and later phases must validate the deterministic
Brent CFD port on Darwinex `XBRUSD.DWX` bars.

## Strategy Allowability Check

- [x] R1 source lineage: peer-reviewed oil-seasonality paper covering Brent and
  WTI seasonality.
- [x] R2 mechanical: fixed broker-calendar source window, first-trading-day
  monthly entry, ATR stop, and next-bar time exit.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes; Q02 validates
  current history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: Brent February-September source-window premium is not any
  existing single-month Brent card, Brent weak-month fade, Brent weekday,
  Brent TSMOM, Brent/WTI spread, WTI event/calendar, XTI/XNG, XNG, XAU/XAG,
  gas-metal, or commodity RSI sleeve.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: February-September first-trading-day long entry.
- trade_management: first post-entry D1 bar, source-window, and max-hold exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial Brent February-September seasonal build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12981_build_result.json`; `C:/QM/repo/framework/build/compile/20260703_025209/QM5_12981_brent-febsep-prem.compile.log`; `D:/QM/reports/framework/21/build_check_20260703_025359.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | `D:/QM/strategy_farm/state/farm_state.sqlite` work_item `3f669727-d83b-4b15-b633-364240ef2aef` |
