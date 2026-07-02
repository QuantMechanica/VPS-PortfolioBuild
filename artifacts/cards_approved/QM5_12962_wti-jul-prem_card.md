---
ea_id: QM5_12962
slug: wti-jul-prem
type: strategy
strategy_id: EIA-WTI-SEASON-2024_JUL_S02
source_id: EIA-WTI-SEASON-2024
source_citation: "U.S. Energy Information Administration. Gasoline price fluctuations. Energy Explained. URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php"
source_citations:
  - type: official_energy_statistics
    citation: "U.S. Energy Information Administration. Gasoline price fluctuations. Energy Explained."
    location: "https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-WTI-SEASON-2024]]"
concepts:
  - "[[concepts/crude-oil-product-demand-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12962_XTI_JUL_PREM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "July-only D1 WTI driving-season seasonal sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.05
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "R1 PASS official EIA product-demand seasonality source; R2 PASS deterministic July D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
---

# WTI July Calendar Premium

## Source

- Source: [[sources/EIA-WTI-SEASON-2024]]
- Primary citation: U.S. Energy Information Administration, "Gasoline price
  fluctuations", Energy Explained, URL
  https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.

## Concept

The source packet records an official EIA product-demand seasonality claim:
gasoline prices tend to rise in spring and peak in late summer as driving
frequency increases. This card isolates July as a clean peak driving-season
WTI sleeve: long-only `XTIUSD.DWX` exposure during broker-calendar July D1
bars, flattened on the next D1 bar unless the ATR hard stop or framework
Friday close acts first.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad May, June, July, August, December, and
  January season map with monthly SMA/ROC confirmation; this card tests only
  July and uses a one-D1-bar calendar premium contract.
- `QM5_12917_xti-driving-season-swing`: April-to-June driving-season swing
  entry with a later seasonal exit; this card opens only on July D1 bars and
  flattens on the next D1 bar.
- Existing WTI February, March, April, May, August, September, October,
  November, December, and January month cards: this card is the unbuilt July
  driving-season month from the EIA source packet.
- WTI WPSR, Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll,
  distillate, jet-fuel, Brent/WTI, XTI/XNG, oil/gold, oil/silver, XAU/XAG,
  and XNG sleeves: no event data, ratio, storage, futures curve, or multi-leg
  basket is used.
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
- Current broker-calendar D1 bar must be in July.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in July.
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
  default: 7
  sweep_range: [7]
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

The source packet is used for structural lineage around official EIA petroleum
product demand seasonality and the late-summer driving-season peak. No source
performance number is imported into QM; the Q02+ pipeline tests the rule on
Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.05.
- expected_dd_pct: 16.
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium for crude-oil overnight and month-end gap risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA product-demand seasonality page.
- [x] R2 mechanical: fixed broker-calendar month, single D1 long entry, ATR
  stop, next-bar exit, and month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: July peak driving-season exposure is not the broad EIA
  WTI season map, not the April-to-June driving-season swing card, not the
  existing single-month WTI cards, not WTI event/ratio/storage/roll logic, and
  not the existing XNG RSI commodity sleeve.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX`
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: July broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-02 | initial structural WTI July calendar-premium build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-02 | APPROVED | this card |
| Q01 Build | 2026-07-02 | PASS | artifacts/qm5_12962_build_result.json |
| Q02 Baseline Backtest | 2026-07-02 | ENQUEUED | D:\QM\strategy_farm\state\farm_state.sqlite work_item cebf1765-60b2-4d60-b395-29a98a36c3b2 |
