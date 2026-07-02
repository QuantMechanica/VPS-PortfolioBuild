---
ea_id: QM5_12961
slug: wti-sep-prem
type: strategy
strategy_id: ARENDAS-OIL-SEASON-2018_S08
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
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12961_XTI_SEP_PREM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "September-only D1 WTI terminal-month seasonal sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.06
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS academic oil-seasonality paper; R2 PASS deterministic September D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI September Calendar Premium

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
of that source-defined window as a separate Darwinex-native WTI sleeve:
long-only `XTIUSD.DWX` exposure during broker-calendar September D1 bars,
flattened on the next D1 bar unless the ATR hard stop or framework Friday close
acts first.

This is deliberately different from:

- `QM5_12734_wti-febsep-prem`: broad February-September seasonal allocation;
  this card tests only the September terminal month.
- `QM5_12727_wti-apr-prem`, `QM5_12729_wti-aug-prem`, and
  `QM5_12730_wti-mar-prem`: single spring/summer month cards from the same
  source, not September.
- `QM5_12599_wti-feb-prem`: February premium from a separate Gorska-Krawiec
  source.
- `QM5_12701_wti-oct-fade`, `QM5_12726_wti-nov-fade`, and
  `QM5_12777_wti-dec-fade`: late-year short/fade sleeves, opposite direction
  or different source.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  driving-season, distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold,
  oil/silver, XAU/XAG, and XNG sleeves: no event data, ratio, season map,
  storage, futures curve, or multi-leg basket is used.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: `D1`.
- Expected trade frequency: about 18-22 trades/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No futures curve, inventory feed, EIA feed, CFTC data,
  CSV, API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Current broker-calendar D1 bar must be in September.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in September.
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
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around crude-oil month-of-year
seasonality and the February-September seasonal allocation window. No source
performance number is imported into QM; the Q02+ pipeline tests the rule on
Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium for crude-oil overnight and month-end gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic crude-oil seasonality paper.
- [x] R2 mechanical: fixed broker-calendar month, single D1 long entry, ATR
  stop, next-bar exit, and month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: September terminal-month exposure is not the broad
  February-September allocation, not the existing March/April/August WTI
  single-month cards, not late-year short/fade months, not WTI event/ratio
  logic, and not the existing XNG RSI commodity sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: September broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial structural WTI September calendar-premium build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build | 2026-07-02 | PASS | artifacts/qm5_12961_build_result.json |
| Q02 Baseline Backtest | 2026-07-02 | ENQUEUED | D:\QM\strategy_farm\state\farm_state.sqlite work_item a3571b1d-4af3-4a06-a7e5-dc39b5614ac3 |
