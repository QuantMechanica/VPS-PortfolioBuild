---
ea_id: QM5_12982
slug: brent-sep-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_BRENT_SEP_S04
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, D. and Bukoven, J. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192. DOI 10.14254/2071-8330.2018/11-2/12. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
source_citations:
  - type: paper
    citation: "Arendas, P., Tkacova, D. and Bukoven, J. (2018). Seasonal patterns in oil prices and their implications for investors. Journal of International Studies, 11(2), 180-192."
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
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency, energy]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12982_XBR_SEP_PREM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "September-only D1 Brent terminal-month seasonal sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.05
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed oil-seasonality paper covering Brent and WTI; R2 PASS deterministic September Brent D1 long/time-flat rule with ATR hard stop; R3 PASS XBRUSD.DWX local Brent route used by prior builds, with Q02 validating current history sufficiency; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate versus existing commodity sleeves because this isolates daily Brent September terminal-month exposure, not WTI September, broad Brent February-September first-month-bar exposure, Brent weak-month fades, WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, trend, carry, or commodity RSI logic."
---

# Brent September Calendar Premium

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Tkacova, D. and Bukoven, J.,
  "Seasonal patterns in oil prices and their implications for investors",
  Journal of International Studies, 11(2), 180-192, DOI
  10.14254/2071-8330.2018/11-2/12, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

The source describes crude-oil month-of-year effects and a February-September
seasonal allocation window. This card isolates the terminal September segment
on the Brent benchmark as a separate Darwinex-native energy sleeve:
long-only `XBRUSD.DWX` exposure during broker-calendar September D1 bars,
flattened on the next D1 bar unless the ATR hard stop or framework Friday close
acts first.

This adds crude-oil benchmark exposure that is distinct from the current
index/metal/XNG book. It is deliberately different from:

- `QM5_12961_wti-sep-prem`: same terminal-month concept on WTI, not Brent.
- `QM5_12981_brent-febsep-prem`: broad February-September Brent source window
  using only the first tradable D1 bar of each month, not daily September bars.
- `QM5_12871_brent-jan-fade`, `QM5_12854_brent-dec-fade`,
  `QM5_12855_brent-nov-fade`: separate Brent weak-month shorts.
- `QM5_12841_brent-thu-prem`, `QM5_12865_brent-fri-prem`,
  `QM5_12856_brent-mon-fade`: weekday effects, not month-of-year seasonality.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  driving-season, distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XAU/XAG, XNG, and gas-metal sleeves: no event data, ratio,
  storage, futures curve, or multi-leg basket is used.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 18-22 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No futures curve, inventory feed, EIA feed, CFTC data,
  CSV, API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new `XBRUSD.DWX` D1 bar.
- Current broker-calendar D1 bar must be in September.
- Entry direction is long only: BUY `XBRUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in September.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XBRUSD.DWX` on D1.
- Magic slot must be 0.
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

## Parameters To Test

- name: strategy_entry_month
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
  sweep_range: [800, 1200, 1600]

## Author Claims

The source is used for structural lineage around crude-oil month-of-year
seasonality and the February-September seasonal allocation window. No source
performance number is imported into QM; the Q02+ pipeline tests the rule on
Darwinex `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium for crude-oil overnight and month-end gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic crude-oil seasonality paper and one
  `source_id`.
- [x] R2 mechanical: fixed broker-calendar month, single D1 long entry, ATR
  stop, next-bar exit, and month-end time exit.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes in prior builds;
  Q02 validates current history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: Brent September terminal-month exposure is not WTI
  September, not the broad Brent February-September allocation, not Brent
  weak-month shorts, not Brent weekday effects, not WTI event/ratio/storage
  logic, and not the existing XNG RSI commodity sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XBRUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: September broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial structural Brent September calendar-premium build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
